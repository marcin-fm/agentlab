# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"
require "pathname"
require "rubygems/package"
require "set"
require "tmpdir"
require "zlib"

module CodexCargoVendor
  class Error < StandardError; end

  LICENSE_BASENAME = /\A(?:licen[cs]e|copying|unlicense)(?:[._-].*)?\z/i
  NOTICE_BASENAME = /\A(?:notice|copyright|credits|authors|patents)(?:[._-].*)?\z/i

  module_function

  def run!(environment, *command, chdir: nil)
    options = {}
    options[:chdir] = chdir if chdir
    stdout, stderr, status = Open3.capture3(environment, *command, **options)
    return stdout if status.success?

    detail = stderr.lines.last(20).join.strip
    detail = stdout.lines.last(20).join.strip if detail.empty?
    raise Error, "command failed: #{command.join(' ')}#{detail.empty? ? '' : ":\n#{detail}"}"
  end

  def apply_lock_updates(content, updates)
    updates.reduce(content) do |lock, update|
      matches = 0
      updated = lock.split(/(?=^\[\[package\]\]$)/).map do |block|
        next block unless block.start_with?("[[package]]\n")
        next block unless block[/^name = "([^"]+)"$/, 1] == update.fetch("name")
        next block unless block[/^version = "([^"]+)"$/, 1] == update.fetch("from_version")
        next block unless block[/^source = "([^"]+)"$/, 1] == update.fetch("source")
        next block unless block[/^checksum = "([^"]+)"$/, 1] == update.fetch("from_checksum")

        matches += 1
        block
          .sub(/^version = "[^"]+"$/, "version = \"#{update.fetch('to_version')}\"")
          .sub(/^checksum = "[^"]+"$/, "checksum = \"#{update.fetch('to_checksum')}\"")
      end.join
      raise Error, "expected one Cargo.lock record for #{update.fetch('name')} #{update.fetch('from_version')}, found #{matches}" unless matches == 1

      updated
    end
  end

  def safe_archive_path(path)
    pathname = Pathname(path)
    clean = pathname.cleanpath.to_s
    return nil if pathname.absolute? || clean == ".." || clean.start_with?("../")

    clean
  end

  def tar_header_path(header)
    name = header.name.to_s.split("\0", 2).first.to_s
    prefix = header.prefix.to_s.split("\0", 2).first.to_s
    prefix.empty? ? name : "#{prefix}/#{name}"
  end

  def parse_pax_headers(data)
    offset = 0
    headers = {}
    while offset < data.bytesize
      space = data.index(" ", offset)
      raise Error, "invalid PAX header length" unless space

      length = data.byteslice(offset, space - offset).to_i
      raise Error, "invalid PAX header record" unless length.positive? && offset + length <= data.bytesize

      record = data.byteslice(space + 1, length - (space - offset) - 1).delete_suffix("\n")
      key, value = record.split("=", 2)
      raise Error, "invalid PAX header value" unless key && value

      headers[key] = value
      offset += length
    end
    headers
  end

  def extract_archive!(archive, destination, expected_root)
    paths = Set.new
    roots = Set.new
    long_name = nil
    local_pax = {}
    global_pax = {}

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
          path = safe_archive_path(entry_name)
          raise Error, "archive path escapes root: #{entry_name}" unless path
          raise Error, "archive contains duplicate path: #{path}" unless paths.add?(path)

          root = path.split("/", 2).first
          roots << root unless root.empty? || root == "."
          raise Error, "unexpected archive root #{root.inspect}, expected #{expected_root}" unless root == expected_root

          target = File.join(destination, path)
          if entry.directory?
            FileUtils.mkdir_p(target)
          elsif entry.file?
            FileUtils.mkdir_p(File.dirname(target))
            File.open(target, "wb", entry.header.mode & 0o777) { |file| IO.copy_stream(entry, file) }
          else
            raise Error, "archive contains unsafe entry type #{entry.header.typeflag.inspect}: #{path}"
          end
          long_name = nil
          local_pax = {}
        end
      end
    end
    raise Error, "archive root mismatch for #{archive}" unless roots == Set[expected_root]
  rescue Zlib::GzipFile::Error, Gem::Package::TarInvalidError => e
    raise Error, "cannot extract #{archive}: #{e.message}"
  end

  def regular_files(root)
    Dir.glob(File.join(root, "**", "*"), File::FNM_DOTMATCH).select do |path|
      File.file?(path) && !File.symlink?(path) && ![".", ".."].include?(File.basename(path))
    end.sort
  end

  def legal_files(package_root, basename_pattern, license_directories: false)
    regular_files(package_root).filter_map do |path|
      relative = path.delete_prefix("#{package_root}/")
      next unless File.basename(path).match?(basename_pattern) || (license_directories && relative.split("/").include?("LICENSES"))
      next unless File.size(path).positive?

      {
        "path" => relative,
        "sha256" => Digest::SHA256.file(path).hexdigest,
        "size_bytes" => File.size(path)
      }
    end
  end

  def cargo_license_text_receipt(vendor_root, vendor_receipt, vendor_receipt_path, license_audit, license_audit_path)
    raise Error, "unsupported Codex license audit schema" unless license_audit.fetch("schema") == "agentlab-codex-selected-cargo-license-audit/v1"
    unless license_audit.dig("authoritative_closure", "sha256") == vendor_receipt.dig("closure_receipt", "sha256") &&
           license_audit.dig("resolver_supplement", "sha256") == vendor_receipt.dig("resolver_supplement", "sha256")
      raise Error, "Codex license audit input identity mismatch"
    end

    selected = license_audit.fetch("selected_packages").reject { |package| package.fetch("workspace_path_package") }
    resolver = license_audit.fetch("resolver_only_packages")
    packages = selected.map do |package|
      package.merge("source_scope" => "selected", "vendor_role" => package.fetch("role"))
    end + resolver.map do |package|
      package.merge("source_scope" => "resolver-only", "vendor_role" => "resolver-only")
    end
    records = packages.map do |package|
      directory = "#{package.fetch('name')}-#{package.fetch('version')}"
      package_root = File.join(vendor_root, directory)
      raise Error, "missing vendored package directory #{directory}" unless File.directory?(package_root)

      texts = legal_files(package_root, LICENSE_BASENAME, license_directories: true)
      notices = legal_files(package_root, NOTICE_BASENAME)
      top_level_texts = texts.select do |text|
        path = text.fetch("path")
        !path.include?("/") || path.split("/").first == "LICENSES"
      end
      {
        "directory" => directory,
        "name" => package.fetch("name"),
        "version" => package.fetch("version"),
        "origin" => package.fetch("origin"),
        "source_scope" => package.fetch("source_scope"),
        "role" => package.fetch("vendor_role"),
        "linked_linux" => package.fetch("linked_linux"),
        "fedora_all_target_linked" => package.fetch("fedora_all_target_linked"),
        "normalized_spdx_candidate" => package.fetch("normalized_spdx_candidate"),
        "license_texts" => texts,
        "top_level_license_texts" => top_level_texts,
        "notice_files" => notices
      }
    end.sort_by { |record| record.fetch("directory") }
    raise Error, "Codex license inventory has duplicate package directories" unless records.map { |record| record.fetch("directory") }.uniq.length == records.length

    actual_directories = Dir.children(vendor_root).select do |entry|
      File.directory?(File.join(vendor_root, entry))
    end.sort
    raise Error, "Codex license inventory does not cover the vendor directory set" unless actual_directories == records.map { |record| record.fetch("directory") }

    missing = records.select { |record| record.fetch("license_texts").empty? }
    missing_top_level = records.select { |record| record.fetch("top_level_license_texts").empty? }
    {
      "schema" => "agentlab-codex-cargo-license-text-inventory/v1",
      "release" => license_audit.fetch("release"),
      "inputs" => {
        "resolver_vendor_receipt" => {
          "name" => File.basename(vendor_receipt_path),
          "sha256" => Digest::SHA256.file(vendor_receipt_path).hexdigest,
          "vendor_tree_sha256" => vendor_receipt.dig("vendor_tree", "sha256")
        },
        "selected_cargo_license_audit" => {
          "name" => File.basename(license_audit_path),
          "sha256" => Digest::SHA256.file(license_audit_path).hexdigest
        }
      },
      "counts" => {
        "vendor_directories" => records.length,
        "selected_vendor_directories" => records.count { |record| record.fetch("source_scope") == "selected" },
        "resolver_only_vendor_directories" => records.count { |record| record.fetch("source_scope") == "resolver-only" },
        "directories_with_package_local_license_texts" => records.length - missing.length,
        "directories_without_package_local_license_texts" => missing.length,
        "license_text_files" => records.sum { |record| record.fetch("license_texts").length },
        "directories_with_top_level_license_texts" => records.length - missing_top_level.length,
        "directories_without_top_level_license_texts" => missing_top_level.length,
        "notice_files" => records.sum { |record| record.fetch("notice_files").length },
        "linked_linux_directories_without_package_local_license_texts" => missing.count { |record| record.fetch("linked_linux") },
        "linked_linux_directories_without_top_level_license_texts" => missing_top_level.count { |record| record.fetch("linked_linux") },
        "selected_compile_only_directories_without_package_local_license_texts" => missing.count do |record|
          record.fetch("source_scope") == "selected" && !record.fetch("linked_linux")
        end,
        "resolver_only_directories_without_package_local_license_texts" => missing.count do |record|
          record.fetch("source_scope") == "resolver-only"
        end,
        "fedora_all_target_directories_without_package_local_license_texts" => missing.count do |record|
          record.fetch("fedora_all_target_linked")
        end
      },
      "packages" => records,
      "validation" => {
        "all_vendor_directories_accounted" => true,
        "package_local_license_text_inventory_verified" => true,
        "cargo_manifest_license_metadata_complete" => license_audit.dig("validation", "selected_cargo_license_metadata_complete") &&
          license_audit.dig("validation", "resolver_cargo_license_metadata_complete"),
        "all_vendor_directories_have_package_local_license_texts" => missing.empty?,
        "fedora_allowed_spdx_verified" => false,
        "native_static_licenses_verified" => false,
        "final_binary_license_complete" => false
      },
      "scope" => "Exact package-local license-text inventory for the resolver-complete Cargo vendor source; missing texts require upstream mapping, and Rusty V8/native static plus final Fedora legal approval remain separate"
    }
  end

  def verify_cargo_checksum!(root, package_checksum)
    checksum_path = File.join(root, ".cargo-checksum.json")
    raise Error, "missing Cargo checksum metadata in #{root}" unless File.file?(checksum_path)

    checksum = JSON.parse(File.read(checksum_path))
    raise Error, "Cargo package checksum mismatch in #{root}" unless checksum["package"] == package_checksum

    files = regular_files(root).reject { |path| path == checksum_path }.to_h do |path|
      [path.delete_prefix("#{root}/"), Digest::SHA256.file(path).hexdigest]
    end
    raise Error, "Cargo file checksums mismatch in #{root}" unless checksum.fetch("files") == files
  end

  def vendor_tree_receipt(root)
    digest = Digest::SHA256.new
    files = 0
    directories = 0
    bytes = 0
    paths = Dir.glob(File.join(root, "**", "*"), File::FNM_DOTMATCH).reject do |path|
      [".", ".."].include?(File.basename(path))
    end.sort

    paths.each do |path|
      stat = File.lstat(path)
      relative = path.delete_prefix("#{root}/")
      mode = stat.mode & 0o777
      if stat.directory?
        directories += 1
        digest.update(["directory", relative, format("%04o", mode)].join("\0") + "\0")
      elsif stat.file?
        files += 1
        bytes += stat.size
        digest.update(["file", relative, format("%04o", mode), stat.size, Digest::SHA256.file(path).hexdigest].join("\0") + "\0")
      else
        raise Error, "unsupported vendor-tree entry: #{relative}"
      end
    end

    {
      "sha256" => digest.hexdigest,
      "files" => files,
      "directories" => directories,
      "file_bytes" => bytes
    }
  end

  def cargo_vendor_manifest(packages)
    manifest = packages.select { |package| %w[registry git].include?(package.fetch("origin")) }.map do |package|
      if package.fetch("origin") == "git"
        "#{package.fetch('name')} v#{package.fetch('version')} (#{package.fetch('source').delete_prefix('git+')})"
      else
        "#{package.fetch('name')} v#{package.fetch('version')}"
      end
    end.sort
    raise Error, "vendor plan has duplicate source entries" unless manifest.uniq.length == manifest.length

    manifest.join("\n") + "\n"
  end

  def cargo_resolver_vendor_config(receipt, vendor_root_name)
    git_sources = receipt.fetch("packages").select { |package| package.fetch("origin") == "git" }.group_by do |package|
      package.fetch("source").split("#", 2).first
    end
    source_blocks = git_sources.sort.map do |source, packages|
      commits = packages.map { |package| package.fetch("source").split("#", 2).last }.uniq
      raise Error, "Git source has multiple commits: #{source}" unless commits.one?

      url = source.delete_prefix("git+").split("?", 2).first
      <<~TOML
        [source.#{source.dump}]
        git = #{url.dump}
        rev = #{commits.first.dump}
        replace-with = "vendored-sources"

      TOML
    end
    <<~TOML
      # Authoritative selected Linux sources plus a separately recorded
      # resolver-only all-target normal/build supplement.
      [source.crates-io]
      replace-with = "vendored-sources"

      #{source_blocks.join}
      [source.vendored-sources]
      directory = #{vendor_root_name.dump}
    TOML
  end

  def verify_resolution!(source_dir, vendor_root, config, receipt, workdir)
    cargo_home = File.join(workdir, "cargo-home")
    FileUtils.mkdir_p(cargo_home)
    proof_config = File.join(workdir, File.basename(config))
    portable = "directory = #{File.basename(vendor_root).dump}"
    content = File.read(config)
    raise Error, "resolver Cargo configuration directory is not portable" unless content.scan(portable).length == 1

    File.write(proof_config, content.sub(portable, "directory = #{vendor_root.dump}"))
    manifest = File.join(source_dir, "codex-rs", "Cargo.toml")
    command = [
      "cargo", "tree", "--manifest-path", manifest, "--locked", "--package", "codex-cli",
      "-Z", "avoid-dev-deps", "--edges", "normal,build", "--offline", "--config", proof_config
    ]
    environment = { "CARGO_HOME" => cargo_home, "RUSTC_BOOTSTRAP" => "1" }
    run!(environment, *(command + ["--target", receipt.dig("selection", "target_triple")]))
    run!(environment, *(command + ["--target", "all"]))
  end

  def verify!(source_dir:, archive:, manifest:, config:, receipt_path:, closure_path:, supplement_path:, work_dir_root:, license_audit_path: nil, license_text_receipt_path: nil)
    receipt = JSON.parse(File.read(receipt_path))
    closure = JSON.parse(File.read(closure_path))
    supplement = JSON.parse(File.read(supplement_path))
    raise Error, "unsupported resolver-vendor receipt schema" unless receipt.fetch("schema") == "agentlab-codex-resolver-cargo-vendor/v2"
    unless receipt.dig("closure_receipt", "sha256") == Digest::SHA256.file(closure_path).hexdigest &&
           receipt.dig("resolver_supplement", "sha256") == Digest::SHA256.file(supplement_path).hexdigest
      raise Error, "resolver-vendor input receipt identity mismatch"
    end
    unless receipt.dig("release", "normalized_cargo_lock_sha256") == Digest::SHA256.file(File.join(source_dir, "codex-rs", "Cargo.lock")).hexdigest
      raise Error, "resolver-vendor normalized Cargo.lock mismatch"
    end

    { manifest => receipt.fetch("vendor_manifest"), config => receipt.fetch("cargo_config") }.each do |path, identity|
      raise Error, "resolver-vendor filename mismatch: #{path}" unless File.basename(path) == identity.fetch("name")
      raise Error, "resolver-vendor file SHA-256 mismatch: #{path}" unless Digest::SHA256.file(path).hexdigest == identity.fetch("sha256")
    end
    archive_identity = receipt.fetch("archive")
    raise Error, "resolver-vendor archive filename mismatch" unless File.basename(archive) == archive_identity.fetch("name")
    raise Error, "resolver-vendor archive unexpectedly requires transport identity" unless archive_identity.fetch("transport_identity_required") == false

    packages = closure.fetch("packages") + supplement.fetch("packages")
    external = packages.select { |package| %w[registry git].include?(package.fetch("origin")) }
    expected_directories = external.map { |package| "#{package.fetch('name')}-#{package.fetch('version')}" }.sort
    raise Error, "resolver-vendor package directory collision" unless expected_directories.uniq.length == expected_directories.length
    expected_by_directory = external.to_h do |package|
      ["#{package.fetch('name')}-#{package.fetch('version')}", package]
    end

    license_text_receipt = Dir.mktmpdir("agentlab-codex-vendor-check-", work_dir_root) do |temporary|
      root_name = receipt.dig("vendor_tree", "root")
      extract_archive!(archive, temporary, root_name)
      vendor_root = File.join(temporary, root_name)
      actual_directories = Dir.children(vendor_root).select do |entry|
        File.directory?(File.join(vendor_root, entry))
      end.sort
      raise Error, "resolver-vendor directory set mismatch" unless actual_directories == expected_directories

      expected_by_directory.each do |directory, package|
        checksum = package.fetch("origin") == "registry" ? package.fetch("checksum") : nil
        verify_cargo_checksum!(File.join(vendor_root, directory), checksum)
      end
      expected_tree = receipt.fetch("vendor_tree").slice("sha256", "files", "directories", "file_bytes")
      raise Error, "resolver-vendor tree identity mismatch" unless vendor_tree_receipt(vendor_root) == expected_tree
      raise Error, "resolver-vendor manifest content mismatch" unless File.read(manifest) == cargo_vendor_manifest(packages)
      raise Error, "resolver-vendor Cargo configuration mismatch" unless File.read(config) == cargo_resolver_vendor_config(closure, root_name)
      verify_resolution!(source_dir, vendor_root, config, receipt, temporary)
      if license_audit_path
        license_audit = JSON.parse(File.read(license_audit_path))
        cargo_license_text_receipt(vendor_root, receipt, receipt_path, license_audit, license_audit_path)
      end
    end

    if license_text_receipt_path
      expected = JSON.pretty_generate(license_text_receipt) + "\n"
      raise Error, "Codex Cargo license-text receipt is stale: #{license_text_receipt_path}" unless File.binread(license_text_receipt_path) == expected
    end

    puts "Verified Codex resolver-complete Cargo source tree #{receipt.dig('vendor_tree', 'sha256')}."
    license_text_receipt
  rescue JSON::ParserError, KeyError, Errno::ENOENT => e
    raise Error, e.message
  end
end
