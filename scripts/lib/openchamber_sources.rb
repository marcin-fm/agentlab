# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"
require "pathname"
require_relative "agentlab"

module Agentlab
  module OpenChamberSources
    SCHEMA = "openchamber-source-materialization/v1"
    SOURCE_SCHEMA = "openchamber-source-acquisition/v1"
    SHA256 = /\A[0-9a-f]{64}\z/
    ARCHIVE_NAME = /\Asha512-[0-9a-f]{128}\.tgz\z/

    module_function

    def materialize!(source_audit_path:, expected_source_audit_sha256:, cache_dir:, output_dir:,
                     receipt_path:, workdir:, expected_filenames:, check: false)
      source_audit_path = File.expand_path(source_audit_path)
      cache_dir = File.realpath(cache_dir)
      output_dir = File.expand_path(output_dir)
      receipt_path = File.expand_path(receipt_path)
      workdir = File.expand_path(workdir)
      raise Agentlab::Error, "OpenChamber source materializer workdir must be below /srv/tmp" unless workdir.start_with?("/srv/tmp/")

      source_bytes = File.binread(source_audit_path)
      source_sha256 = Digest::SHA256.hexdigest(source_bytes)
      unless expected_source_audit_sha256.to_s.match?(SHA256) && source_sha256 == expected_source_audit_sha256
        raise Agentlab::Error, "OpenChamber source-audit SHA-256 does not match package metadata"
      end
      source_audit = JSON.parse(source_bytes)
      validate_source_audit!(source_audit)
      records = source_records(source_audit)
      production_records = records.select { |record| !(record.fetch("roles") & %w[runtime build]).empty? }
      test_records = records

      version = source_audit.fetch("release").to_s
      roots = {
        "production_build" => "openchamber-#{version}-nm-prod-build",
        "test" => "openchamber-#{version}-nm-dev-test"
      }
      filenames = {
        "production_build" => "#{roots.fetch('production_build')}.tar.zst",
        "test" => "#{roots.fetch('test')}.tar.zst"
      }
      unless expected_filenames == filenames
        raise Agentlab::Error, "OpenChamber source bundle filenames do not match package metadata"
      end

      generated_dir = File.join(workdir, "generated")
      comparison_dir = File.join(workdir, "comparison")
      staging_dir = File.join(workdir, "staging")
      [generated_dir, comparison_dir, staging_dir].each do |path|
        FileUtils.rm_rf(path)
        FileUtils.mkdir_p(path)
      end

      grouped = { "production_build" => production_records, "test" => test_records }
      grouped.each do |role, members|
        stage_bundle!(cache_dir, File.join(staging_dir, roots.fetch(role), "npm"), members)
      end
      generated = grouped.to_h do |role, _members|
        first = File.join(generated_dir, filenames.fetch(role))
        second = File.join(comparison_dir, filenames.fetch(role))
        create_archive!(staging_dir, roots.fetch(role), first)
        create_archive!(staging_dir, roots.fetch(role), second)
        unless FileUtils.compare_file(first, second)
          raise Agentlab::Error, "OpenChamber #{role.tr('_', '/')} source bundle regeneration is not deterministic"
        end
        [role, first]
      end

      archives = grouped.to_h do |role, members|
        [role, {
          "role" => role == "production_build" ? "production-build-npm-source-bundle" : "test-capable-npm-source-bundle",
          "recipe" => "deterministic-archive-bundle/v1",
          "compression" => "zstd-10-single-thread",
          "filename" => filenames.fetch(role),
          "archive_root" => roots.fetch(role)
        }.merge(manifest_summary(members)).merge(file_receipt(generated.fetch(role)))]
      end
      receipt = {
        "schema" => SCHEMA,
        "package" => "openchamber",
        "release" => version,
        "source_audit" => {
          "filename" => File.basename(source_audit_path),
          "sha256" => source_sha256,
          "selected_lock_receipt_sha256" => source_audit.fetch("selected_lock_receipt_sha256")
        },
        "selected_archive_roles" => %w[production_build test],
        "archives" => archives,
        "validation" => {
          "source_audit_verified" => true,
          "cached_member_sizes_verified" => true,
          "cached_member_sha256_verified" => true,
          "safe_archive_paths_verified" => true,
          "archive_roots_verified" => true,
          "production_role_selection_verified" => true,
          "test_superset_verified" => true,
          "deterministic_regeneration_verified" => true,
          "network_access_performed" => false,
          "node_modules_materialized" => false,
          "dependency_resolution_performed" => false,
          "patches_applied" => false,
          "lifecycle_scripts_executed" => false,
          "package_build_performed" => false,
          "rpm_integrated" => false
        }
      }
      content = JSON.pretty_generate(receipt) + "\n"
      output_paths = generated.to_h { |role, _path| [role, File.join(output_dir, filenames.fetch(role))] }

      if check
        output_paths.each do |role, path|
          raise Agentlab::Error, "missing checked OpenChamber #{role.tr('_', '/')} source bundle #{path}" unless File.file?(path)
          raise Agentlab::Error, "checked OpenChamber #{role.tr('_', '/')} source bundle is stale" unless FileUtils.compare_file(path, generated.fetch(role))
        end
        raise Agentlab::Error, "missing checked OpenChamber source materialization receipt #{receipt_path}" unless File.file?(receipt_path)
        raise Agentlab::Error, "checked OpenChamber source materialization receipt is stale" unless File.binread(receipt_path) == content
      else
        FileUtils.mkdir_p(output_dir)
        output_paths.each { |role, path| atomic_copy(generated.fetch(role), path) }
        Agentlab.atomic_write(receipt_path, content)
      end
      receipt
    rescue JSON::ParserError => e
      raise Agentlab::Error, "invalid OpenChamber source-audit receipt: #{e.message}"
    rescue Errno::ENOENT => e
      raise Agentlab::Error, "missing OpenChamber source materializer input: #{e.message}"
    end

    def validate_source_audit!(receipt)
      raise Agentlab::Error, "unsupported OpenChamber source-audit schema" unless receipt["schema"] == SOURCE_SCHEMA
      raise Agentlab::Error, "OpenChamber source-audit package mismatch" unless receipt["package"] == "openchamber"
      raise Agentlab::Error, "OpenChamber source-audit release is missing" if receipt["release"].to_s.empty?
      validation = receipt.fetch("validation")
      %w[registry_integrity_verified archive_paths_verified source_sha256_recorded].each do |flag|
        raise Agentlab::Error, "OpenChamber source-audit lacks #{flag}" unless validation[flag] == true
      end
      %w[lifecycle_scripts_executed dependency_resolution_performed].each do |flag|
        raise Agentlab::Error, "OpenChamber source-audit overclaims #{flag}" unless validation[flag] == false
      end
    end

    def source_records(receipt)
      records = receipt.fetch("sources").map do |source|
        archive = source.fetch("archive")
        sha256 = source.fetch("sha256")
        size = source.fetch("size")
        raise Agentlab::Error, "invalid OpenChamber source archive name" unless archive.match?(ARCHIVE_NAME)
        raise Agentlab::Error, "invalid OpenChamber source SHA-256" unless sha256.match?(SHA256)
        raise Agentlab::Error, "invalid OpenChamber source size" unless size.is_a?(Integer) && size.positive?

        {
          "archive" => archive,
          "sha256" => sha256,
          "size_bytes" => size,
          "npm_name" => source.fetch("npm_name"),
          "version" => source.fetch("version"),
          "roles" => source.fetch("roles"),
          "package_paths" => source.fetch("package_paths")
        }
      end.sort_by { |record| record.fetch("archive") }
      archives = records.map { |record| record.fetch("archive") }
      raise Agentlab::Error, "duplicate OpenChamber source archive identity" unless archives.uniq.length == archives.length
      records
    end

    def stage_bundle!(cache_dir, destination, records)
      FileUtils.mkdir_p(destination)
      File.chmod(0o755, destination)
      records.each do |record|
        source = File.join(cache_dir, record.fetch("archive"))
        raise Agentlab::Error, "missing cached OpenChamber source #{source}" unless File.file?(source)
        raise Agentlab::Error, "cached OpenChamber source size mismatch: #{record.fetch('archive')}" unless File.size(source) == record.fetch("size_bytes")
        raise Agentlab::Error, "cached OpenChamber source SHA-256 mismatch: #{record.fetch('archive')}" unless Digest::SHA256.file(source).hexdigest == record.fetch("sha256")
        target = File.join(destination, record.fetch("archive"))
        FileUtils.copy_file(source, target)
        File.chmod(0o644, target)
      end
    end

    def manifest_summary(records)
      content = JSON.generate(records) + "\n"
      {
        "member_count" => records.length,
        "input_bytes" => records.sum { |record| record.fetch("size_bytes") },
        "member_manifest_sha256" => Digest::SHA256.hexdigest(content)
      }
    end

    def create_archive!(staging_dir, root, output)
      tar = [
        "tar", "--sort=name", "--mtime=@0", "--owner=0", "--group=0", "--numeric-owner",
        "--format=gnu", "-cf", "-", "-C", staging_dir, root
      ]
      statuses = Open3.pipeline(tar, ["zstd", "-10", "-T1", "-q", "-f"], out: output)
      raise Agentlab::Error, "failed to create deterministic OpenChamber source bundle" unless statuses.all?(&:success?)
    end

    def file_receipt(path)
      {
        "size_bytes" => File.size(path),
        "sha256" => Digest::SHA256.file(path).hexdigest
      }
    end

    def atomic_copy(source, destination)
      temporary = "#{destination}.tmp-#{Process.pid}-#{Thread.current.object_id}"
      FileUtils.copy_file(source, temporary)
      File.chmod(0o644, temporary)
      File.rename(temporary, destination)
    ensure
      FileUtils.rm_f(temporary) if temporary
    end
  end
end
