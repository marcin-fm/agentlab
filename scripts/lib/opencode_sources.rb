# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require_relative "openchamber_sources"

module Agentlab
  module OpenCodeSources
    SCHEMA = "opencode-source-materialization/v1"
    SOURCE_SCHEMA = "opencode-source-acquisition/v1"
    SHA256 = /\A[0-9a-f]{64}\z/

    module_function

    def materialize!(source_audit_path:, expected_source_audit_sha256:, cache_dir:, output_dir:,
                     receipt_path:, workdir:, expected_filenames:, check: false)
      source_audit_path = File.expand_path(source_audit_path)
      cache_dir = File.realpath(cache_dir)
      output_dir = File.expand_path(output_dir)
      receipt_path = File.expand_path(receipt_path)
      workdir = File.expand_path(workdir)
      raise Agentlab::Error, "OpenCode source materializer workdir must be below /srv/tmp" unless workdir.start_with?("/srv/tmp/")

      source_bytes = File.binread(source_audit_path)
      source_sha256 = Digest::SHA256.hexdigest(source_bytes)
      unless expected_source_audit_sha256.to_s.match?(SHA256) && source_sha256 == expected_source_audit_sha256
        raise Agentlab::Error, "OpenCode source-audit SHA-256 does not match package metadata"
      end
      source_audit = JSON.parse(source_bytes)
      validate_source_audit!(source_audit)
      records = Agentlab::OpenChamberSources.source_records(source_audit)
      production_records = records.select { |record| !(record.fetch("roles") & %w[runtime build]).empty? }
      test_records = records

      version = source_audit.fetch("release").to_s
      roots = {
        "production_build" => "opencode-#{version}-nm-prod-build",
        "test" => "opencode-#{version}-nm-dev-test"
      }
      filenames = roots.transform_values { |root| "#{root}.tar.zst" }
      raise Agentlab::Error, "OpenCode source bundle filenames do not match package metadata" unless expected_filenames == filenames

      generated_dir = File.join(workdir, "generated")
      comparison_dir = File.join(workdir, "comparison")
      staging_dir = File.join(workdir, "staging")
      [generated_dir, comparison_dir, staging_dir].each do |path|
        FileUtils.rm_rf(path)
        FileUtils.mkdir_p(path)
      end

      grouped = { "production_build" => production_records, "test" => test_records }
      grouped.each do |role, members|
        Agentlab::OpenChamberSources.stage_bundle!(cache_dir, File.join(staging_dir, roots.fetch(role), "npm"), members)
      end
      generated = grouped.to_h do |role, _members|
        first = File.join(generated_dir, filenames.fetch(role))
        second = File.join(comparison_dir, filenames.fetch(role))
        Agentlab::OpenChamberSources.create_archive!(staging_dir, roots.fetch(role), first)
        Agentlab::OpenChamberSources.create_archive!(staging_dir, roots.fetch(role), second)
        raise Agentlab::Error, "OpenCode #{role.tr('_', '/')} source bundle regeneration is not deterministic" unless FileUtils.compare_file(first, second)
        [role, first]
      end

      archives = grouped.to_h do |role, members|
        [role, {
          "role" => role == "production_build" ? "production-build-npm-source-bundle" : "test-capable-npm-source-bundle",
          "recipe" => "deterministic-archive-bundle/v1",
          "compression" => "zstd-10-single-thread",
          "filename" => filenames.fetch(role),
          "archive_root" => roots.fetch(role)
        }.merge(Agentlab::OpenChamberSources.manifest_summary(members))
          .merge(Agentlab::OpenChamberSources.file_receipt(generated.fetch(role)))]
      end
      receipt = {
        "schema" => SCHEMA,
        "package" => "opencode",
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
          raise Agentlab::Error, "missing checked OpenCode #{role.tr('_', '/')} source bundle #{path}" unless File.file?(path)
          raise Agentlab::Error, "checked OpenCode #{role.tr('_', '/')} source bundle is stale" unless FileUtils.compare_file(path, generated.fetch(role))
        end
        raise Agentlab::Error, "missing checked OpenCode source materialization receipt #{receipt_path}" unless File.file?(receipt_path)
        raise Agentlab::Error, "checked OpenCode source materialization receipt is stale" unless File.binread(receipt_path) == content
      else
        FileUtils.mkdir_p(output_dir)
        output_paths.each { |role, path| Agentlab::OpenChamberSources.atomic_copy(generated.fetch(role), path) }
        Agentlab.atomic_write(receipt_path, content)
      end
      receipt
    rescue JSON::ParserError => e
      raise Agentlab::Error, "invalid OpenCode source-audit receipt: #{e.message}"
    rescue Errno::ENOENT => e
      raise Agentlab::Error, "missing OpenCode source materializer input: #{e.message}"
    end

    def validate_source_audit!(receipt)
      raise Agentlab::Error, "unsupported OpenCode source-audit schema" unless receipt["schema"] == SOURCE_SCHEMA
      raise Agentlab::Error, "OpenCode source-audit package mismatch" unless receipt["package"] == "opencode"
      raise Agentlab::Error, "OpenCode source-audit release is missing" if receipt["release"].to_s.empty?
      validation = receipt.fetch("validation")
      %w[registry_integrity_verified archive_paths_verified source_sha256_recorded].each do |flag|
        raise Agentlab::Error, "OpenCode source-audit lacks #{flag}" unless validation[flag] == true
      end
      %w[lifecycle_scripts_executed dependency_resolution_performed].each do |flag|
        raise Agentlab::Error, "OpenCode source-audit overclaims #{flag}" unless validation[flag] == false
      end
    end
  end
end
