# frozen_string_literal: true

require "digest"
require "fileutils"
require "find"
require "json"
require "open3"
require "pathname"
require_relative "agentlab"

module Agentlab
  module BunWebKitSource
    SCHEMA = "bun-webkit-minimized-source/v2"
    SOURCE_ARCHITECTURES = %w[x86_64 aarch64].freeze
    EXCLUDED_PATHS = %w[
      .claude
      .codex
      .gemini
      .github
      JSTests
      LayoutTests
      ManualTests
      PerformanceTests
      WebDriverTests
      WebKit.xcworkspace
      Websites
      Source/WebCore
      Source/WebDriver
      Source/WebGPU
      Source/WebInspectorUI
      Source/WebKit
      Source/WebKitLegacy
      Source/ThirdParty/ANGLE
      Source/ThirdParty/d3flamegraphjs
      Source/ThirdParty/d3js
      Source/ThirdParty/dav1d
      Source/ThirdParty/gmock
      Source/ThirdParty/libsysprof-capture
      Source/ThirdParty/libwebrtc
      Source/ThirdParty/pdfjs
      Source/ThirdParty/qunit
      Source/ThirdParty/skia
      Source/ThirdParty/xdgmime
    ].freeze
    REQUIRED_PATHS = %w[
      CMakeLists.txt
      Source/CMakeLists.txt
      Source/JavaScriptCore/CMakeLists.txt
      Source/JavaScriptCore/runtime/TypedArrayAdaptors.h
      Source/WTF/CMakeLists.txt
      Source/bmalloc/CMakeLists.txt
      Source/cmake/OptionsJSCOnly.cmake
      Source/ThirdParty/capstone/CMakeLists.txt
      Source/ThirdParty/gtest/CMakeLists.txt
      Source/ThirdParty/unifdef/CMakeLists.txt
      Tools/CMakeLists.txt
      Tools/Scripts/rewrite-compile-commands
    ].freeze

    module_function

    def package!(source_archive:, output:, receipt_path:, workdir:, commit:, release_pin:, canonical_sha256:)
      source_archive = File.expand_path(source_archive)
      output = File.expand_path(output)
      receipt_path = File.expand_path(receipt_path)
      workdir = File.expand_path(workdir)
      root = "WebKit-#{commit}"

      raise Agentlab::Error, "missing complete WebKit source archive #{source_archive}" unless File.file?(source_archive)
      actual_source_sha256 = Digest::SHA256.file(source_archive).hexdigest
      unless actual_source_sha256 == canonical_sha256
        raise Agentlab::Error, "complete WebKit source SHA-256 #{actual_source_sha256} does not match #{canonical_sha256}"
      end

      validate_archive_paths!(source_archive, root)
      staging = File.join(workdir, "staging")
      FileUtils.mkdir_p(staging)
      extract = ["tar", "--extract", "--gzip", "--file", source_archive, "--directory", staging, "--no-same-owner"]
      EXCLUDED_PATHS.each { |path| extract << "--exclude=#{root}/#{path}" }
      run!(extract)

      source_root = File.join(staging, root)
      raise Agentlab::Error, "minimized WebKit root is missing: #{source_root}" unless Dir.exist?(source_root)
      normalize_git_modes!(source_root)
      REQUIRED_PATHS.each do |path|
        required = File.join(source_root, path)
        raise Agentlab::Error, "minimized WebKit source is missing #{path}" unless File.exist?(required) || File.symlink?(required)
      end
      EXCLUDED_PATHS.each do |path|
        excluded = File.join(source_root, path)
        raise Agentlab::Error, "excluded WebKit path remains: #{path}" if File.exist?(excluded) || File.symlink?(excluded)
      end

      manifest = tree_manifest(staging, root)
      FileUtils.mkdir_p(File.dirname(output))
      create_archive!(staging, root, output)
      comparison = File.join(workdir, "determinism.tar.gz")
      create_archive!(staging, root, comparison)
      output_sha256 = Digest::SHA256.file(output).hexdigest
      unless Digest::SHA256.file(comparison).hexdigest == output_sha256 && File.binread(comparison) == File.binread(output)
        raise Agentlab::Error, "minimized WebKit archive regeneration is not deterministic"
      end

      output_size = File.size(output)
      source_size = File.size(source_archive)
      raise Agentlab::Error, "minimized WebKit archive did not reduce source size" unless output_size < source_size

      receipt = {
        "schema" => SCHEMA,
        "package" => "bun",
        "release_pin" => release_pin,
        "source" => {
          "commit" => commit,
          "archive_root" => root,
          "complete_archive_filename" => File.basename(source_archive),
          "complete_archive_sha256" => actual_source_sha256,
          "complete_archive_size_bytes" => source_size
        },
        "archive" => {
          "filename" => File.basename(output),
          "sha256" => output_sha256,
          "size_bytes" => output_size,
          "saved_bytes" => source_size - output_size,
          "saved_percent" => (((source_size - output_size) * 100.0) / source_size).round(4),
          "tree_sha256" => manifest.fetch("tree_sha256"),
          "member_count" => manifest.fetch("member_count"),
          "regular_file_count" => manifest.fetch("regular_file_count"),
          "symlink_count" => manifest.fetch("symlink_count"),
          "regular_file_bytes" => manifest.fetch("regular_file_bytes")
        },
        "retained_scope" => {
          "architectures" => SOURCE_ARCHITECTURES,
          "capstone_retained" => true,
          "required_paths" => REQUIRED_PATHS,
          "excluded_paths" => EXCLUDED_PATHS
        },
        "validation" => {
          "canonical_source_verified" => true,
          "safe_single_root_verified" => true,
          "required_paths_verified" => true,
          "excluded_paths_absent" => true,
          "git_mode_semantics_normalized" => true,
          "modes_and_symlinks_manifested" => true,
          "deterministic_regeneration_verified" => true,
          "archive_size_reduced" => true,
          "source_tree_complete" => false,
          "jsc_only_source_subset" => true,
          "aarch64_capstone_scope_verified" => true,
          "bun_source_build_verified" => false
        }
      }
      Agentlab.atomic_write(receipt_path, JSON.pretty_generate(receipt) + "\n")
      receipt
    end

    def verify_receipt!(receipt_path:, archive_path:, webkit_metadata:, release_pin:)
      receipt_path = File.expand_path(receipt_path)
      archive_path = File.expand_path(archive_path)
      receipt = JSON.parse(File.read(receipt_path))
      expected_root = "WebKit-#{webkit_metadata.fetch('commit')}"
      unless receipt["schema"] == SCHEMA &&
             receipt["package"] == "bun" &&
             receipt["release_pin"] == release_pin &&
             receipt.dig("source", "commit") == webkit_metadata.fetch("commit") &&
             receipt.dig("source", "archive_root") == expected_root &&
             receipt.dig("source", "complete_archive_sha256") == webkit_metadata.fetch("sha256")
        raise Agentlab::Error, "minimized WebKit receipt does not match the pinned complete source identity"
      end
      unless receipt.dig("retained_scope", "architectures") == SOURCE_ARCHITECTURES &&
             receipt.dig("retained_scope", "capstone_retained") == true &&
             receipt.dig("retained_scope", "required_paths") == REQUIRED_PATHS &&
             receipt.dig("retained_scope", "excluded_paths") == EXCLUDED_PATHS
        raise Agentlab::Error, "minimized WebKit receipt source scope does not match the packager"
      end

      validation = receipt.fetch("validation")
      %w[
        canonical_source_verified
        safe_single_root_verified
        required_paths_verified
        excluded_paths_absent
        git_mode_semantics_normalized
        modes_and_symlinks_manifested
        deterministic_regeneration_verified
        archive_size_reduced
        jsc_only_source_subset
        aarch64_capstone_scope_verified
      ].each do |key|
        raise Agentlab::Error, "minimized WebKit receipt has not verified #{key}" unless validation[key] == true
      end
      raise Agentlab::Error, "minimized WebKit receipt incorrectly claims a complete source tree" unless validation["source_tree_complete"] == false
      raise Agentlab::Error, "minimized WebKit archive filename mismatch" unless receipt.dig("archive", "filename") == File.basename(archive_path)
      actual_sha256 = Digest::SHA256.file(archive_path).hexdigest
      raise Agentlab::Error, "minimized WebKit archive checksum mismatch" unless receipt.dig("archive", "sha256") == actual_sha256
      raise Agentlab::Error, "minimized WebKit archive size mismatch" unless receipt.dig("archive", "size_bytes") == File.size(archive_path)
      complete_size = receipt.dig("source", "complete_archive_size_bytes")
      saved_bytes = complete_size.to_i - File.size(archive_path)
      unless complete_size.is_a?(Integer) && saved_bytes.positive? && receipt.dig("archive", "saved_bytes") == saved_bytes
        raise Agentlab::Error, "minimized WebKit receipt does not record a valid size reduction"
      end
      validate_archive_paths!(archive_path, expected_root)

      receipt
    rescue Errno::ENOENT => e
      raise Agentlab::Error, "missing minimized WebKit receipt input: #{e.message}"
    rescue JSON::ParserError => e
      raise Agentlab::Error, "invalid minimized WebKit receipt: #{e.message}"
    end

    def verify_tree!(staging:, receipt:)
      root = receipt.dig("source", "archive_root")
      raise Agentlab::Error, "minimized WebKit receipt archive root is missing" unless root.is_a?(String) && !root.empty?

      source_root = File.join(staging, root)
      REQUIRED_PATHS.each do |path|
        required = File.join(source_root, path)
        raise Agentlab::Error, "minimized WebKit source is missing #{path}" unless File.exist?(required) || File.symlink?(required)
      end
      EXCLUDED_PATHS.each do |path|
        excluded = File.join(source_root, path)
        raise Agentlab::Error, "excluded WebKit path remains: #{path}" if File.exist?(excluded) || File.symlink?(excluded)
      end

      manifest = tree_manifest(staging, root)
      archive = receipt.fetch("archive")
      expected = {
        "tree_sha256" => archive.fetch("tree_sha256"),
        "member_count" => archive.fetch("member_count"),
        "regular_file_count" => archive.fetch("regular_file_count"),
        "symlink_count" => archive.fetch("symlink_count"),
        "regular_file_bytes" => archive.fetch("regular_file_bytes")
      }
      raise Agentlab::Error, "minimized WebKit extracted tree does not match its receipt" unless manifest == expected

      manifest
    end

    def extract_verified_tree!(archive_path:, staging:, receipt:)
      archive_path = File.expand_path(archive_path)
      staging = File.expand_path(staging)
      root = receipt.dig("source", "archive_root")
      raise Agentlab::Error, "minimized WebKit receipt archive root is missing" unless root.is_a?(String) && !root.empty?

      FileUtils.rm_rf(File.join(staging, root))
      FileUtils.mkdir_p(staging)
      run!(["tar", "--extract", "--gzip", "--file", archive_path, "--directory", staging, "--no-same-owner"])
      verify_tree!(staging: staging, receipt: receipt)
    end

    def validate_archive_paths!(archive, expected_root)
      stdout, stderr, status = Open3.capture3("tar", "--list", "--gzip", "--file", archive)
      raise Agentlab::Error, "cannot list WebKit source archive: #{stderr.strip}" unless status.success?

      roots = stdout.lines.filter_map do |line|
        entry = line.strip.delete_suffix("/")
        next if entry.empty?

        path = safe_relative_path(entry)
        raise Agentlab::Error, "unsafe WebKit source archive path: #{entry}" unless path

        path.split("/", 2).first
      end.uniq
      raise Agentlab::Error, "WebKit source archive root mismatch: #{roots.inspect}" unless roots == [expected_root]
    end

    def tree_manifest(staging, root)
      records = []
      root_path = File.join(staging, root)
      Find.find(root_path) do |path|
        relative = Pathname(path).relative_path_from(Pathname(staging)).to_s
        stat = File.lstat(path)
        record = { "path" => relative, "mode" => format("%04o", stat.mode & 0o7777) }
        if stat.file?
          record.merge!("type" => "file", "size_bytes" => stat.size, "sha256" => Digest::SHA256.file(path).hexdigest)
        elsif stat.directory?
          record["type"] = "directory"
        elsif stat.symlink?
          target = File.readlink(path)
          resolved = Pathname(File.dirname(relative)).join(target).cleanpath.to_s
          unless !Pathname(target).absolute? && (resolved == root || resolved.start_with?("#{root}/"))
            raise Agentlab::Error, "unsafe WebKit source symlink #{relative} -> #{target}"
          end
          record.merge!("type" => "symlink", "target" => target)
        else
          raise Agentlab::Error, "unsupported WebKit source entry type: #{relative}"
        end
        records << record
      end
      records.sort_by! { |record| record.fetch("path") }
      serialized = records.map { |record| JSON.generate(record) }.join("\n") + "\n"
      {
        "tree_sha256" => Digest::SHA256.hexdigest(serialized),
        "member_count" => records.length,
        "regular_file_count" => records.count { |record| record["type"] == "file" },
        "symlink_count" => records.count { |record| record["type"] == "symlink" },
        "regular_file_bytes" => records.sum { |record| record["type"] == "file" ? record.fetch("size_bytes") : 0 }
      }
    end

    def normalize_git_modes!(root)
      Find.find(root) do |path|
        stat = File.lstat(path)
        if stat.directory?
          File.chmod(0o755, path)
        elsif stat.file?
          File.chmod((stat.mode & 0o111).zero? ? 0o644 : 0o755, path)
        end
      end
    end

    def create_archive!(staging, root, output)
      FileUtils.rm_f(output)
      File.open(output, "wb") do |file|
        statuses = Open3.pipeline(
          [
            "tar", "--sort=name", "--mtime=@0", "--owner=0", "--group=0", "--numeric-owner",
            "--format=gnu", "--create", "--file=-", "--directory", staging, root
          ],
          ["gzip", "-n", "-9"],
          out: file
        )
        raise Agentlab::Error, "failed to create minimized WebKit archive" unless statuses.all?(&:success?)
      end
    end

    def safe_relative_path(path)
      pathname = Pathname(path)
      clean = pathname.cleanpath.to_s
      return nil if pathname.absolute? || clean == ".." || clean.start_with?("../")

      clean
    end

    def run!(argv)
      return if system(*argv, chdir: Agentlab::ROOT)

      raise Agentlab::Error, "command failed: #{Agentlab.command_string(argv)}"
    end
  end
end
