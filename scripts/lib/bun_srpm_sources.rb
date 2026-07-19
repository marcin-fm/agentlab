# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "pathname"
require "rubygems/package"
require "set"
require "tempfile"
require "uri"
require "zlib"
require_relative "agentlab"

module Agentlab
  module BunSrpmSources
    SCHEMA = "bun-srpm-source-bundles/v1"
    CLOSURE_SCHEMA = "bun-release-local-source-closure/v2"
    SHA256 = /\A[0-9a-f]{64}\z/
    ARCHIVE_ROLES = %w[native_node npm cargo].freeze
    CARGO_EXTRA_FIELDS = %w[
      archive_root
      file_count
      unpacked_size_bytes
      symlink_count
      hardlink_count
      manifest
      manifest_sha256
    ].freeze

    module_function

    def materialize!(closure_path:, expected_closure_sha256:, expected_source_sha256:, expected_counts:,
                     cache_dir:, output_dir:, receipt_path:, workdir:, cargo_manifest_path:,
                     cargo_archive_filename:, roles: ARCHIVE_ROLES, expected_npm_archive: nil,
                     expected_cargo_archive: nil, check: false)
      closure_path = File.expand_path(closure_path)
      cache_dir = File.realpath(cache_dir)
      output_dir = File.expand_path(output_dir)
      receipt_path = File.expand_path(receipt_path)
      workdir = File.expand_path(workdir)
      cargo_manifest_path = File.expand_path(cargo_manifest_path)
      unless valid_archive_name?(cargo_archive_filename)
        raise Agentlab::Error, "lol-html Cargo vendor archive filename is invalid"
      end
      roles = Array(roles).map(&:to_s)
      unless roles.any? && roles.uniq.length == roles.length && (roles - ARCHIVE_ROLES).empty?
        raise Agentlab::Error, "Bun source archive roles are invalid"
      end

      closure_bytes = File.binread(closure_path)
      closure_sha256 = Digest::SHA256.hexdigest(closure_bytes)
      unless expected_closure_sha256.to_s.match?(SHA256) && closure_sha256 == expected_closure_sha256
        raise Agentlab::Error, "Bun source-closure receipt SHA-256 does not match package metadata"
      end

      closure = JSON.parse(closure_bytes)
      validate_closure!(
        closure,
        expected_source_sha256: expected_source_sha256,
        expected_counts: expected_counts
      )
      records = source_records(closure)
      reject_duplicate_archives!(records)
      reject_bootstrap_seed!(records)

      generated_dir = File.join(workdir, "generated")
      comparison_dir = File.join(workdir, "comparison")
      staging_dir = File.join(workdir, "staging")
      [generated_dir, comparison_dir, staging_dir].each do |path|
        FileUtils.rm_rf(path)
        FileUtils.mkdir_p(path)
      end

      version = closure.fetch("release").to_s
      native_root = "bun-#{version}-native-node-sources"
      npm_root = "bun-#{version}-npm-sources"
      cargo_root = "cargo-vendor"
      native_filename = "#{native_root}.tar.gz"
      npm_filename = "#{npm_root}.tar.gz"

      if roles.include?("native_node")
        stage_raw_bundle!(
          cache_dir: cache_dir,
          cache_subdir: "archives",
          destination: File.join(staging_dir, native_root, "archives"),
          records: records.fetch("native") + records.fetch("node")
        )
      end
      if roles.include?("npm")
        stage_raw_bundle!(
          cache_dir: cache_dir,
          cache_subdir: "npm",
          destination: File.join(staging_dir, npm_root, "npm"),
          records: records.fetch("npm")
        )
      end
      cargo_result = if roles.include?("cargo")
                       stage_cargo_vendor!(
                         cache_dir: cache_dir,
                         destination: File.join(staging_dir, cargo_root),
                         records: records.fetch("cargo"),
                         checked_manifest_path: cargo_manifest_path
                       )
                     end

      archive_specs = []
      archive_specs << ["native_node", native_filename, native_root] if roles.include?("native_node")
      archive_specs << ["npm", npm_filename, npm_root] if roles.include?("npm")
      archive_specs << ["cargo", cargo_archive_filename, cargo_root] if roles.include?("cargo")
      generated_archives = archive_specs.to_h do |role, filename, root|
        generated = File.join(generated_dir, filename)
        comparison = File.join(comparison_dir, filename)
        create_archive!(staging_dir, root, generated)
        create_archive!(staging_dir, root, comparison)
        unless FileUtils.compare_file(generated, comparison)
          raise Agentlab::Error, "Bun #{role.tr('_', '/')} source archive regeneration is not deterministic"
        end
        [role, generated]
      end

      summaries = records.transform_values { |members| manifest_summary(members) }
      archives = {}
      if roles.include?("native_node")
        archives["native_node"] = {
          "role" => "native-node-source-bundle",
          "recipe" => "deterministic-archive-bundle/v1",
          "compression" => "gzip-n",
          "archive_root" => native_root
        }.merge(manifest_summary(records.fetch("native") + records.fetch("node"))).merge(
          file_receipt(generated_archives.fetch("native_node"))
        )
      end
      if roles.include?("npm")
        archives["npm"] = {
          "role" => "npm-source-bundle",
          "recipe" => "deterministic-archive-bundle/v1",
          "compression" => "gzip-n",
          "archive_root" => npm_root
        }.merge(summaries.fetch("npm")).merge(file_receipt(generated_archives.fetch("npm")))
      end
      if roles.include?("cargo")
        archives["cargo"] = {
          "role" => "lolhtml-cargo-vendor",
          "recipe" => "lolhtml-cargo-vendor/v1",
          "compression" => "gzip-n",
          "archive_root" => cargo_root,
          "tree_sha256" => cargo_result.fetch("tree_sha256"),
          "cargo_checksums_generated" => cargo_result.fetch("cargo_checksums_generated"),
          "vendor_manifest" => cargo_result.fetch("vendor_manifest")
        }.merge(summaries.fetch("cargo")).merge(file_receipt(generated_archives.fetch("cargo")))
      end
      expected_npm_verified = verify_expected_archive!(
        archives["npm"], expected_npm_archive, "npm source"
      )
      expected_cargo_verified = verify_expected_archive!(
        archives["cargo"], expected_cargo_archive, "lol-html Cargo vendor"
      )
      receipt = {
        "schema" => SCHEMA,
        "package" => "bun",
        "release" => version,
        "source_closure" => {
          "filename" => File.basename(closure_path),
          "sha256" => closure_sha256,
          "source_sha256" => closure.dig("source_tree", "source_sha256"),
          "target" => closure.fetch("target")
        },
        "selected_archive_roles" => roles,
        "archives" => archives,
        "scope" => {
          "archive_generation_architecture_independent" => true,
          "closure_target" => closure.fetch("target"),
          "complete_multi_architecture_closure_verified" => false,
          "aarch64_build_verified" => false
        },
        "validation" => {
          "closure_receipt_verified" => true,
          "source_tree_binding_verified" => true,
          "source_counts_verified" => true,
          "cached_member_sizes_verified" => true,
          "cached_member_sha256_verified" => true,
          "safe_archive_paths_verified" => true,
          "cargo_archive_contents_verified" => roles.include?("cargo"),
          "cargo_checksums_generated" => roles.include?("cargo"),
          "cargo_vendor_manifest_verified" => roles.include?("cargo"),
          "expected_npm_archive_verified" => expected_npm_verified,
          "expected_cargo_archive_verified" => expected_cargo_verified,
          "bootstrap_seed_excluded" => true,
          "deterministic_regeneration_verified" => true,
          "immutable_public_hosting_verified" => false,
          "bun_spec_integrated" => false,
          "srpm_built" => false
        }
      }
      content = JSON.pretty_generate(receipt) + "\n"

      output_paths = generated_archives.to_h do |role, _path|
        [role, File.join(output_dir, archives.fetch(role).fetch("filename"))]
      end
      if check
        output_paths.each do |role, path|
          raise Agentlab::Error, "missing checked Bun source archive #{path}" unless File.file?(path)
          unless FileUtils.compare_file(path, generated_archives.fetch(role))
            raise Agentlab::Error, "checked Bun #{role.tr('_', '/')} source archive is stale: #{path}"
          end
        end
        raise Agentlab::Error, "missing checked Bun source receipt #{receipt_path}" unless File.file?(receipt_path)
        unless File.binread(receipt_path) == content
          raise Agentlab::Error, "checked Bun source receipt is stale: #{receipt_path}"
        end
      else
        FileUtils.mkdir_p(output_dir)
        output_paths.each do |role, path|
          atomic_copy(generated_archives.fetch(role), path)
        end
        Agentlab.atomic_write(receipt_path, content)
      end

      receipt
    rescue JSON::ParserError => e
      raise Agentlab::Error, "invalid Bun source-closure receipt: #{e.message}"
    rescue Errno::ENOENT => e
      raise Agentlab::Error, "missing Bun source materializer input: #{e.message}"
    end

    def validate_closure!(closure, expected_source_sha256:, expected_counts:)
      raise Agentlab::Error, "unsupported Bun source-closure schema" unless closure["schema"] == CLOSURE_SCHEMA
      raise Agentlab::Error, "Bun source-closure package mismatch" unless closure["package"] == "bun"
      raise Agentlab::Error, "Bun source-closure release is missing" if closure["release"].to_s.empty?
      unless expected_source_sha256.to_s.match?(SHA256) && closure.dig("source_tree", "source_sha256") == expected_source_sha256
        raise Agentlab::Error, "Bun source closure does not match Source0"
      end
      target = closure["target"]
      unless target.is_a?(Hash) && %w[os cpu libc].all? { |key| target[key].is_a?(String) && !target[key].empty? }
        raise Agentlab::Error, "Bun source-closure target is invalid"
      end

      actual_counts = {
        "native" => Array(closure["native_github_sources"]).length,
        "node" => closure["node_headers"].is_a?(Hash) ? 1 : 0,
        "npm" => Array(closure.dig("npm", "source_archives")).length,
        "cargo" => Array(closure.dig("cargo", "crate_sources")).length
      }
      unless expected_counts == actual_counts
        raise Agentlab::Error, "Bun source-closure counts do not match package metadata"
      end
    end

    def verify_expected_archive!(actual, expected, label)
      return false unless expected
      raise Agentlab::Error, "materialized #{label} archive was not selected" unless actual
      unless expected.fetch("filename").is_a?(String) &&
             expected.fetch("sha256").to_s.match?(SHA256) &&
             expected.fetch("size_bytes").is_a?(Integer) &&
             expected.fetch("size_bytes").positive? &&
             actual.slice("filename", "sha256", "size_bytes") == expected
        raise Agentlab::Error, "materialized #{label} archive does not match package metadata"
      end

      true
    end

    def source_records(closure)
      native = Array(closure["native_github_sources"]).map do |source|
        source_member(source, label: "native source #{source['name']}", url_key: "url").merge(
          "name" => source.fetch("name"),
          "symbol" => source.fetch("symbol")
        )
      end.sort_by { |record| [record.fetch("name"), record.fetch("archive")] }
      node_source = closure.fetch("node_headers")
      node = [
        source_member(node_source, label: "Node.js headers", url_key: "url").merge(
          "name" => node_source.fetch("name"),
          "version" => node_source.fetch("version"),
          "abi" => node_source.fetch("abi")
        )
      ]
      npm = Array(closure.dig("npm", "source_archives")).map do |source|
        source_member(source, label: "npm source #{source['npm_name']}", url_key: "source_url").merge(
          "origin" => source.fetch("origin"),
          "npm_name" => source.fetch("npm_name"),
          "source_name" => source["source_name"],
          "source_version" => source["source_version"],
          "source_commit" => source["source_commit"],
          "integrity" => source["integrity"]
        )
      end.sort_by { |record| [record.fetch("npm_name"), record["source_version"].to_s, record.fetch("archive")] }
      cargo = Array(closure.dig("cargo", "crate_sources")).map do |source|
        record = source_member(source, label: "Cargo source #{source['name']} #{source['version']}", url_key: "source_url").merge(
          "name" => source.fetch("name"),
          "version" => source.fetch("version"),
          "checksum" => source.fetch("checksum"),
          "archive_root" => source.fetch("archive_root"),
          "file_count" => source.fetch("file_count"),
          "unpacked_size_bytes" => source.fetch("unpacked_size_bytes"),
          "symlink_count" => source.fetch("symlink_count"),
          "hardlink_count" => source.fetch("hardlink_count"),
          "manifest" => source.fetch("manifest"),
          "manifest_sha256" => source.fetch("manifest_sha256")
        )
        unless record.fetch("checksum") == record.fetch("sha256")
          raise Agentlab::Error, "Cargo source checksum identity mismatch: #{record.fetch('name')} #{record.fetch('version')}"
        end
        record
      end.sort_by { |record| [record.fetch("name"), record.fetch("version")] }

      { "native" => native, "node" => node, "npm" => npm, "cargo" => cargo }
    end

    def source_member(record, label:, url_key:)
      archive = record["archive"]
      sha256 = record["sha256"]
      size_bytes = record["size_bytes"]
      unless valid_archive_name?(archive)
        raise Agentlab::Error, "#{label} archive filename is invalid"
      end
      raise Agentlab::Error, "#{label} SHA-256 is invalid" unless sha256.to_s.match?(SHA256)
      raise Agentlab::Error, "#{label} size is invalid" unless size_bytes.is_a?(Integer) && size_bytes.positive?

      {
        "archive" => archive,
        "url" => https_url!(record[url_key], "#{label} URL"),
        "sha256" => sha256,
        "size_bytes" => size_bytes
      }
    end

    def valid_archive_name?(archive)
      archive.is_a?(String) && !archive.empty? && !archive.include?("\0") &&
        archive != "." && archive != ".." && File.basename(archive) == archive
    end

    def https_url!(value, label)
      uri = URI(value)
      raise Agentlab::Error, "#{label} must use HTTPS" unless uri.is_a?(URI::HTTPS)

      value
    rescue URI::InvalidURIError, TypeError
      raise Agentlab::Error, "#{label} is invalid"
    end

    def reject_duplicate_archives!(records)
      [records.fetch("native") + records.fetch("node"), records.fetch("npm"), records.fetch("cargo")].each do |members|
        archives = members.map { |record| record.fetch("archive") }
        unless archives.uniq.length == archives.length
          raise Agentlab::Error, "Bun source materializer contains duplicate archive filenames"
        end
      end
      cargo_roots = records.fetch("cargo").map { |record| record.fetch("archive_root") }
      unless cargo_roots.uniq.length == cargo_roots.length && cargo_roots.all? { |root| safe_relative_path(root) == root && !root.include?("/") }
        raise Agentlab::Error, "Bun Cargo source materializer contains invalid or duplicate archive roots"
      end
    end

    def reject_bootstrap_seed!(records)
      archives = records.values.flatten.map { |record| record.fetch("archive") }
      if archives.any? { |archive| archive.include?("bun-seed") }
        raise Agentlab::Error, "Bun source materializer must not include the bootstrap seed"
      end
    end

    def manifest_summary(records)
      manifest_records = records.map { |record| record.reject { |key, _value| CARGO_EXTRA_FIELDS.include?(key) } }
      content = JSON.generate(manifest_records) + "\n"
      {
        "member_count" => records.length,
        "input_bytes" => records.sum { |record| record.fetch("size_bytes") },
        "member_manifest_sha256" => Digest::SHA256.hexdigest(content)
      }
    end

    def stage_raw_bundle!(cache_dir:, cache_subdir:, destination:, records:)
      FileUtils.mkdir_p(destination)
      File.chmod(0o755, destination)
      records.each do |record|
        source = checked_cache_file!(cache_dir, cache_subdir, record)
        target = File.join(destination, record.fetch("archive"))
        FileUtils.copy_file(source, target)
        File.chmod(0o644, target)
      end
    end

    def stage_cargo_vendor!(cache_dir:, destination:, records:, checked_manifest_path:)
      FileUtils.mkdir_p(destination)
      File.chmod(0o755, destination)
      records.each do |record|
        unless record.fetch("symlink_count").zero? && record.fetch("hardlink_count").zero?
          raise Agentlab::Error, "Cargo archive contains links: #{record.fetch('name')} #{record.fetch('version')}"
        end
        archive = checked_cache_file!(cache_dir, "cargo", record)
        extracted = extract_checked_tar!(archive, destination, record.fetch("archive_root"))
        unless extracted.fetch("file_count") == record.fetch("file_count") &&
               extracted.fetch("unpacked_size_bytes") == record.fetch("unpacked_size_bytes")
          raise Agentlab::Error, "Cargo archive content count mismatch: #{record.fetch('name')} #{record.fetch('version')}"
        end
        crate_root = File.join(destination, record.fetch("archive_root"))
        manifest = File.join(crate_root, record.fetch("manifest"))
        unless File.file?(manifest) && Digest::SHA256.file(manifest).hexdigest == record.fetch("manifest_sha256")
          raise Agentlab::Error, "Cargo manifest mismatch: #{record.fetch('name')} #{record.fetch('version')}"
        end
        files = regular_files(crate_root)
        checksum = {
          "files" => files.to_h { |path| [path.delete_prefix("#{crate_root}/"), Digest::SHA256.file(path).hexdigest] },
          "package" => record.fetch("checksum")
        }
        checksum_path = File.join(crate_root, ".cargo-checksum.json")
        File.write(checksum_path, JSON.generate(checksum) + "\n")
        File.chmod(0o644, checksum_path)
      end

      expected_roots = records.map { |record| record.fetch("archive_root") }.sort
      actual_roots = Dir.children(destination).select { |entry| File.directory?(File.join(destination, entry)) }.sort
      raise Agentlab::Error, "materialized Cargo vendor roots do not match the checked closure" unless actual_roots == expected_roots

      manifest_content = records.map { |record| "#{record.fetch('name')} v#{record.fetch('version')}" }.sort.join("\n") + "\n"
      unless File.file?(checked_manifest_path) && File.binread(checked_manifest_path) == manifest_content
        raise Agentlab::Error, "checked lol-html Cargo vendor manifest is stale: #{checked_manifest_path}"
      end
      {
        "tree_sha256" => vendor_tree_digest(destination),
        "cargo_checksums_generated" => records.length,
        "vendor_manifest" => {
          "filename" => File.basename(checked_manifest_path),
          "size_bytes" => File.size(checked_manifest_path),
          "sha256" => Digest::SHA256.file(checked_manifest_path).hexdigest
        }
      }
    end

    def checked_cache_file!(cache_dir, subdir, record)
      path = File.join(cache_dir, subdir, record.fetch("archive"))
      raise Agentlab::Error, "missing cached Bun source #{path}" unless File.file?(path)
      raise Agentlab::Error, "refusing symlinked cached Bun source #{path}" if File.symlink?(path)
      resolved = File.realpath(path)
      unless resolved.start_with?("#{cache_dir}/")
        raise Agentlab::Error, "cached Bun source resolves outside the checked cache: #{path}"
      end
      unless File.size(resolved) == record.fetch("size_bytes")
        raise Agentlab::Error, "cached Bun source size mismatch: #{record.fetch('archive')}"
      end
      unless Digest::SHA256.file(resolved).hexdigest == record.fetch("sha256")
        raise Agentlab::Error, "cached Bun source checksum mismatch: #{record.fetch('archive')}"
      end
      resolved
    end

    def extract_checked_tar!(archive, destination, expected_root)
      roots = []
      paths = Set.new
      long_name = nil
      local_pax = {}
      global_pax = {}
      file_count = 0
      unpacked_size_bytes = 0
      Zlib::GzipReader.open(archive) do |gzip|
        Gem::Package::TarReader.new(gzip) do |tar|
          tar.each do |entry|
            case entry.header.typeflag
            when "L"
              long_name = entry.read.delete_suffix("\0")
              next
            when "K"
              entry.read
              next
            when "x"
              local_pax = parse_pax_headers(entry.read)
              next
            when "g"
              global_pax.merge!(parse_pax_headers(entry.read))
              next
            end

            entry_name = local_pax["path"] || global_pax["path"] || long_name || tar_header_path(entry.header)
            path = safe_relative_path(entry_name)
            raise Agentlab::Error, "archive path escapes root: #{entry_name}" unless path
            root = path.split("/", 2).first
            roots << root unless root.nil? || root.empty? || root == "."
            unless root == expected_root
              raise Agentlab::Error, "unexpected archive root #{root.inspect}, expected #{expected_root}"
            end
            raise Agentlab::Error, "archive contains duplicate path: #{path}" unless paths.add?(path)

            target = File.join(destination, path)
            if entry.directory?
              FileUtils.mkdir_p(target)
            elsif entry.file?
              FileUtils.mkdir_p(File.dirname(target))
              File.open(target, "wb", entry.header.mode & 0o777) { |file| IO.copy_stream(entry, file) }
              file_count += 1
              unpacked_size_bytes += File.size(target)
            else
              raise Agentlab::Error, "unsupported archive entry #{entry.header.typeflag.inspect}: #{path}"
            end
            long_name = nil
            local_pax = {}
          end
        end
      end
      raise Agentlab::Error, "archive root mismatch for #{archive}" unless roots.uniq == [expected_root]

      { "file_count" => file_count, "unpacked_size_bytes" => unpacked_size_bytes }
    rescue Zlib::GzipFile::Error, Gem::Package::TarInvalidError => e
      raise Agentlab::Error, "cannot extract #{archive}: #{e.message}"
    end

    def parse_pax_headers(data)
      offset = 0
      headers = {}
      while offset < data.bytesize
        space = data.index(" ", offset)
        raise Agentlab::Error, "invalid PAX header length" unless space
        length = data.byteslice(offset, space - offset).to_i
        unless length.positive? && offset + length <= data.bytesize
          raise Agentlab::Error, "invalid PAX header record"
        end
        record = data.byteslice(space + 1, length - (space - offset) - 1).delete_suffix("\n")
        key, value = record.split("=", 2)
        raise Agentlab::Error, "invalid PAX header value" unless key && value
        headers[key] = value
        offset += length
      end
      headers
    end

    def tar_header_path(header)
      name = header.name.to_s.split("\0", 2).first.to_s
      prefix = header.prefix.to_s.split("\0", 2).first.to_s
      prefix.empty? ? name : "#{prefix}/#{name}"
    end

    def safe_relative_path(path)
      return nil unless path.is_a?(String) && !path.empty? && !path.include?("\0")
      pathname = Pathname.new(path)
      clean = pathname.cleanpath.to_s
      return nil if pathname.absolute? || clean == ".." || clean.start_with?("../")

      clean.delete_prefix("./")
    end

    def regular_files(root)
      Dir.glob(File.join(root, "**", "*"), File::FNM_DOTMATCH).select do |path|
        File.file?(path) && !File.symlink?(path) && ![".", ".."].include?(File.basename(path))
      end.sort
    end

    def vendor_tree_digest(root)
      digest = Digest::SHA256.new
      regular_files(root).each do |path|
        digest.update(path.delete_prefix("#{root}/"))
        digest.update("\0")
        digest.update(Digest::SHA256.file(path).hexdigest)
        digest.update("\0")
      end
      digest.hexdigest
    end

    def create_archive!(source_parent, root_name, output)
      FileUtils.mkdir_p(File.dirname(output))
      tar_path = "#{output}.tar"
      FileUtils.rm_f([output, tar_path])
      argv = [
        "tar", "--sort=name", "--mtime=@0", "--owner=0", "--group=0", "--numeric-owner",
        "--format=gnu", "-cf", tar_path, "-C", source_parent, root_name
      ]
      unless system(*argv, chdir: source_parent)
        raise Agentlab::Error, "command failed: #{Agentlab.command_string(argv)}"
      end
      Zlib::GzipWriter.open(output) do |gzip|
        gzip.mtime = 0
        File.open(tar_path, "rb") { |tar| IO.copy_stream(tar, gzip) }
      end
    ensure
      FileUtils.rm_f(tar_path) if tar_path
    end

    def file_receipt(path)
      {
        "filename" => File.basename(path),
        "size_bytes" => File.size(path),
        "sha256" => Digest::SHA256.file(path).hexdigest
      }
    end

    def atomic_copy(source, destination)
      FileUtils.mkdir_p(File.dirname(destination))
      Tempfile.create([".bun-srpm-source-", ".tmp"], File.dirname(destination)) do |file|
        file.binmode
        File.open(source, "rb") { |input| IO.copy_stream(input, file) }
        file.flush
        file.fsync
        File.chmod(0o644, file.path)
        File.rename(file.path, destination)
      end
    end
  end
end
