# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "net/http"
require "open3"
require "rubygems/version"
require "shellwords"
require "tempfile"
require "uri"
require "yaml"

module Agentlab
  ROOT = File.expand_path("../..", __dir__)
  DEFAULT_CONFIG = File.join(ROOT, "config", "copr.yml")
  COPR_ARCHITECTURES = %w[x86_64 aarch64].freeze
  STABLE_COPR_RELEASES = %w[43 44].freeze
  STABLE_COPR_CHROOTS = STABLE_COPR_RELEASES.flat_map do |release|
    COPR_ARCHITECTURES.map { |architecture| "fedora-#{release}-#{architecture}" }
  end.freeze
  RAWHIDE_COPR_CHROOTS = COPR_ARCHITECTURES.map { |architecture| "fedora-rawhide-#{architecture}" }.freeze
  DEFAULT_COPR_CHROOTS = (STABLE_COPR_CHROOTS + RAWHIDE_COPR_CHROOTS).freeze
  BUN_BUILD_STAGES = %w[
    zig_source_bootstrap
    webkit_source_build
    dependency_closure
    seed_build
    self_rebuild
    final
  ].freeze

  class Error < StandardError; end

  Package = Struct.new(:directory, :manifest_path, :data, keyword_init: true) do
    def name
      data.fetch("name")
    end

    def status
      data.fetch("status")
    end

    def enabled?
      status == "enabled" && data.dig("copr", "enabled") == true
    end

    def spec_path
      File.join(directory, data.dig("copr", "spec") || "#{name}.spec")
    end

    def chroots(default_chroots)
      data.dig("copr", "chroots") || default_chroots
    end

    def upstream
      data.fetch("upstream")
    end
  end

  module_function

  def copr_chroot_matrix_errors(chroots, require_all_stable_releases:)
    errors = []
    duplicates = chroots.tally.select { |_chroot, count| count > 1 }.keys
    errors << "contains duplicate chroots: #{duplicates.join(', ')}" if duplicates.any?

    unknown = chroots - DEFAULT_COPR_CHROOTS
    errors << "contains unsupported chroots: #{unknown.join(', ')}" if unknown.any?

    missing_rawhide = RAWHIDE_COPR_CHROOTS - chroots
    errors << "must include Rawhide on both architectures; missing: #{missing_rawhide.join(', ')}" if missing_rawhide.any?

    stable_releases = if require_all_stable_releases
                        STABLE_COPR_RELEASES
                      else
                        STABLE_COPR_RELEASES.select do |release|
                          COPR_ARCHITECTURES.any? { |architecture| chroots.include?("fedora-#{release}-#{architecture}") }
                        end
                      end
    errors << "must include at least one stable Fedora release" if stable_releases.empty?

    stable_releases.each do |release|
      required = COPR_ARCHITECTURES.map { |architecture| "fedora-#{release}-#{architecture}" }
      missing = required - chroots
      errors << "Fedora #{release} must include both architectures; missing: #{missing.join(', ')}" if missing.any?
    end

    errors
  end

  def load_yaml(path)
    YAML.safe_load(File.read(path), aliases: false) || {}
  rescue Psych::Exception => e
    raise Error, "invalid YAML in #{path}: #{e.message}"
  end

  def parse_jsonc(content, source: "JSONC input")
    without_comments = +""
    index = 0
    in_string = false
    escaped = false
    line_comment = false
    block_comment = false

    while index < content.length
      character = content[index]
      following = content[index + 1]

      if line_comment
        if character == "\n"
          line_comment = false
          without_comments << character
        end
        index += 1
        next
      end

      if block_comment
        if character == "*" && following == "/"
          block_comment = false
          index += 2
        else
          without_comments << "\n" if character == "\n"
          index += 1
        end
        next
      end

      if in_string
        without_comments << character
        if escaped
          escaped = false
        elsif character == "\\"
          escaped = true
        elsif character == '"'
          in_string = false
        end
        index += 1
        next
      end

      if character == '"'
        in_string = true
        without_comments << character
        index += 1
      elsif character == "/" && following == "/"
        line_comment = true
        index += 2
      elsif character == "/" && following == "*"
        block_comment = true
        index += 2
      else
        without_comments << character
        index += 1
      end
    end

    raise Error, "invalid JSONC in #{source}: unterminated block comment" if block_comment

    without_trailing_commas = +""
    index = 0
    in_string = false
    escaped = false
    while index < without_comments.length
      character = without_comments[index]
      if in_string
        without_trailing_commas << character
        if escaped
          escaped = false
        elsif character == "\\"
          escaped = true
        elsif character == '"'
          in_string = false
        end
        index += 1
        next
      end

      if character == '"'
        in_string = true
        without_trailing_commas << character
        index += 1
        next
      end

      if character == ","
        following_index = index + 1
        following_index += 1 while without_comments[following_index]&.match?(/\s/)
        if ["]", "}"].include?(without_comments[following_index])
          index += 1
          next
        end
      end

      without_trailing_commas << character
      index += 1
    end

    JSON.parse(without_trailing_commas)
  rescue JSON::ParserError => e
    raise Error, "invalid JSONC in #{source}: #{e.message}"
  end

  def load_jsonc(path)
    parse_jsonc(File.read(path), source: path)
  end

  def config(path = DEFAULT_CONFIG)
    load_yaml(path)
  end

  def packages
    Dir.glob(File.join(ROOT, "packages", "*", "package.yml")).sort.map do |manifest_path|
      Package.new(
        directory: File.dirname(manifest_path),
        manifest_path: manifest_path,
        data: load_yaml(manifest_path)
      )
    end
  end

  def package_named(name)
    packages.find { |package| package.name == name } ||
      raise(Error, "unknown package: #{name}")
  end

  def command_available?(name)
    ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? do |directory|
      File.executable?(File.join(directory, name))
    end
  end

  def command_string(argv)
    Shellwords.join(argv)
  end

  def copr_command(*arguments)
    config_path = ENV["COPR_CONFIG"].to_s
    command = ["copr-cli"]
    command.concat(["--config", config_path]) unless config_path.empty?
    command.concat(arguments)
  end

  def copr_config_values(path)
    values = {}
    section = nil

    File.foreach(path) do |line|
      stripped = line.strip
      if (match = stripped.match(/\A\[([^\]]+)\]\z/))
        section = match[1]
        next
      end
      next unless section == "copr-cli"
      next if stripped.empty? || stripped.start_with?("#", ";")

      key, value = line.split("=", 2)
      values[key.strip] = value.strip if value
    end

    values
  end

  def copr_authenticated_owner(config_path)
    values = copr_config_values(config_path)
    missing = %w[login token copr_url].reject { |key| !values[key].to_s.empty? }
    raise Error, "COPR config is missing #{missing.join(', ')}: #{config_path}" unless missing.empty?

    uri = URI("#{values.fetch('copr_url').sub(%r{/+\z}, '')}/api_3/auth-check")
    raise Error, "refusing non-HTTPS COPR URL #{uri}" unless uri.is_a?(URI::HTTPS)

    request = Net::HTTP::Get.new(uri)
    request.basic_auth(values.fetch("login"), values.fetch("token"))
    request["Accept"] = "application/json"
    request["User-Agent"] = "agentlab-packaging"
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }

    unless response.is_a?(Net::HTTPSuccess)
      detail = response.body.to_s[0, 300]
      begin
        detail = JSON.parse(response.body).fetch("error", detail)
      rescue JSON::ParserError
        # Preserve the bounded response body when COPR does not return JSON.
      end
      raise Error, "COPR authentication failed: #{detail}"
    end

    owner = JSON.parse(response.body).fetch("name").to_s
    raise Error, "COPR authentication response did not identify an account" if owner.empty?

    owner
  rescue JSON::ParserError, KeyError => e
    raise Error, "invalid COPR authentication response: #{e.message}"
  rescue URI::InvalidURIError => e
    raise Error, "invalid COPR URL: #{e.message}"
  end

  def verify_copr_owner!(expected_owner)
    config_path = ENV["COPR_CONFIG"].to_s
    raise Error, "COPR_CONFIG is not set; activate the project identity before COPR mutation" if config_path.empty?
    raise Error, "COPR config does not exist: #{config_path}" unless File.file?(config_path)

    mode = File.stat(config_path).mode & 0o777
    unless [0o400, 0o600].include?(mode)
      raise Error, "COPR config has unsafe mode #{format('%03o', mode)}: #{config_path}"
    end
    raise Error, "copr-cli is not installed" unless command_available?("copr-cli")

    actual_owner = copr_authenticated_owner(config_path)
    return actual_owner if actual_owner == expected_owner

    raise Error, "COPR identity mismatch: expected #{expected_owner.inspect}, got #{actual_owner.inspect}"
  end

  def run!(argv, dry_run: false, chdir: ROOT)
    puts "$ #{command_string(argv)}"
    return if dry_run

    success = system(*argv, chdir: chdir)
    raise Error, "command failed: #{command_string(argv)}" unless success
  end

  def capture(argv, chdir: ROOT)
    stdout, stderr, status = Open3.capture3(*argv, chdir: chdir)
    [stdout, stderr, status]
  end

  def copr_resource_missing?(message)
    message.match?(/\b404\b|does not exist|not found|no (?:package|project|copr) with name/i)
  end

  def github_latest_release(repository)
    response = http_get(URI("https://api.github.com/repos/#{repository}/releases/latest"), json: true)
    release = JSON.parse(response)
    raise Error, "latest GitHub release for #{repository} is a draft" if release["draft"]
    raise Error, "latest GitHub release for #{repository} is a prerelease" if release["prerelease"]

    release
  rescue JSON::ParserError => e
    raise Error, "invalid GitHub response for #{repository}: #{e.message}"
  end

  def crates_io_latest_version(crate_name, requirement = nil)
    version_requirement = Gem::Requirement.new(requirement || ">= 0")
    response = http_get(URI("https://crates.io/api/v1/crates/#{crate_name}"), json: true)
    payload = JSON.parse(response)
    versions = payload.fetch("versions").filter_map do |release|
      next if release["yanked"] == true

      version = Gem::Version.new(release.fetch("num"))
      next if version.prerelease?
      next unless version_requirement.satisfied_by?(version)

      version
    rescue ArgumentError
      nil
    end
    raise Error, "no stable crates.io release found for #{crate_name} matching #{version_requirement}" if versions.empty?

    versions.max.to_s
  rescue JSON::ParserError => e
    raise Error, "invalid crates.io response for #{crate_name}: #{e.message}"
  end

  def latest_upstream_version(package)
    provider = package.upstream.fetch("provider")
    case provider
    when "github"
      release = github_latest_release(package.upstream.fetch("repository"))
      release_version(package, release.fetch("tag_name"))
    when "crates_io"
      crates_io_latest_version(
        package.upstream.fetch("crate"),
        package.upstream["version_requirement"]
      )
    when "static"
      package.upstream.fetch("current_version")
    else
      raise Error, "unsupported release provider #{provider.inspect} for #{package.name}"
    end
  end

  def download(url)
    http_get(URI(url), json: false)
  end

  def source_url(package, version)
    package.upstream.fetch("source_url_template").gsub("{version}", version)
  end

  def release_version(package, tag)
    prefix = package.upstream.fetch("tag_prefix", "")
    unless tag.start_with?(prefix)
      raise Error, "release tag #{tag.inspect} does not start with #{prefix.inspect} for #{package.name}"
    end

    version = tag.delete_prefix(prefix)
    Gem::Version.new(version)
    version
  rescue ArgumentError
    raise Error, "release tag #{tag.inspect} is not an RPM-compatible version for #{package.name}"
  end

  def node_bundled_provides(closure)
    packages = closure.is_a?(Array) ? closure : closure.fetch("packages")
    raise Error, "closure packages must be an array" unless packages.is_a?(Array)

    packages.each do |entry|
      raise Error, "closure package entries must be objects" unless entry.is_a?(Hash)

      name = entry.fetch("npm_name")
      version = entry.fetch("version")
      origin = entry.fetch("origin")
      role = entry.fetch("role")
      included_in_binary = entry.fetch("included_in_binary")
      source_url = entry.fetch("source_url")
      integrity = entry.fetch("integrity")
      sha256 = entry.fetch("sha256")
      license = entry.fetch("license")

      raise Error, "invalid npm package name: #{name.inspect}" unless name.is_a?(String) && name.match?(/\A(?:@[A-Za-z0-9_.-]+\/)?[A-Za-z0-9_.-]+\z/)
      raise Error, "invalid npm package version: #{version.inspect}" unless version.is_a?(String) && version.match?(/\A[^\s()]+\z/)
      raise Error, "unsupported source origin for #{name}: #{origin.inspect}" unless origin == "registry"
      raise Error, "invalid dependency role for #{name}: #{role.inspect}" unless %w[runtime build test].include?(role)
      raise Error, "included_in_binary must be boolean for #{name}" unless [true, false].include?(included_in_binary)
      raise Error, "only runtime dependencies may be marked included_in_binary for #{name}" if included_in_binary && role != "runtime"
      raise Error, "invalid npm source URL for #{name}" unless source_url.is_a?(String)
      raise Error, "npm source URL must use HTTPS for #{name}" unless URI(source_url).is_a?(URI::HTTPS)
      raise Error, "missing sha512 integrity for #{name}" unless integrity.is_a?(String) && integrity.start_with?("sha512-")
      raise Error, "invalid SHA-256 for #{name}" unless sha256.is_a?(String) && sha256.match?(/\A[0-9a-f]{64}\z/)
      raise Error, "missing license for #{name}" unless license.is_a?(String) && !license.strip.empty?
      raise Error, "source is not verified for #{name}" unless entry["source_verified"] == true
    end

    embedded = packages.select { |entry| entry["role"] == "runtime" && entry["included_in_binary"] == true }
    raise Error, "closure has no verified registry runtime packages included in the binary" if embedded.empty?

    embedded.map do |entry|
      name = entry.fetch("npm_name")
      version = entry.fetch("version")
      "Provides:       bundled(nodejs-#{name}) = #{version}"
    end.uniq.sort
  rescue URI::InvalidURIError => e
    raise Error, "invalid npm source URL: #{e.message}"
  end

  def node_bundled_provides_block(closure)
    (["# BEGIN GENERATED BUNDLED NODE PROVIDES"] + node_bundled_provides(closure) +
      ["# END GENERATED BUNDLED NODE PROVIDES"]).join("\n")
  end

  def validate_rust_v8_evidence(package, dependencies, spec)
    return [] unless package.name == "rust-v8"

    errors = []
    version = package.upstream.fetch("current_version").to_s
    source_name = dependencies.dig("source_closure", "receipt")
    license_name = dependencies.dig("license_audit", "receipt")
    source_path = source_name.is_a?(String) && File.join(package.directory, source_name)
    license_path = license_name.is_a?(String) && File.join(package.directory, license_name)
    unless source_path && File.file?(source_path)
      return ["rust-v8: recursive-source receipt is missing"]
    end
    unless license_path && File.file?(license_path)
      return ["rust-v8: license-audit receipt is missing"]
    end

    source_sha256 = Digest::SHA256.file(source_path).hexdigest
    license_sha256 = Digest::SHA256.file(license_path).hexdigest
    expected_source_hashes = [
      dependencies.dig("source_closure", "receipt_sha256"),
      package.data.dig("source_policy", "source_closure_receipt_sha256")
    ]
    errors << "rust-v8: recursive-source receipt SHA-256 does not match metadata" unless expected_source_hashes.all? { |value| value == source_sha256 }
    expected_license_hashes = [
      dependencies.dig("license_audit", "receipt_sha256"),
      package.data.dig("license_audit", "receipt_sha256")
    ]
    errors << "rust-v8: license-audit receipt SHA-256 does not match metadata" unless expected_license_hashes.all? { |value| value == license_sha256 }
    errors << "rust-v8: spec recursive-source SHA-256 does not match" unless spec[/^%global closure_sha256\s+(\h{64})$/, 1] == source_sha256
    errors << "rust-v8: spec license-audit SHA-256 does not match" unless spec[/^%global license_audit_sha256\s+(\h{64})$/, 1] == license_sha256

    source = JSON.parse(File.read(source_path))
    errors << "rust-v8: recursive-source schema is invalid" unless source["schema"] == "rust-v8-source-closure/v1"
    errors << "rust-v8: recursive-source release does not match" unless source.dig("release", "version").to_s == version
    components = source["components"]
    unless components.is_a?(Array) && components.length == 21
      return errors << "rust-v8: recursive-source receipt must contain 21 components"
    end

    paths = components.map { |component| component["path"] }
    errors << "rust-v8: recursive-source component paths are not unique" unless paths.uniq.length == paths.length
    errors << "rust-v8: recursive-source root component is invalid" unless paths.first == "."
    archives = components.filter_map { |component| component["archive"] }
    errors << "rust-v8: recursive-source archive metadata is incomplete" unless archives.length == components.length
    components.each_with_index do |component, index|
      archive = component["archive"] || {}
      errors << "rust-v8: component #{component['path']} has invalid RPM source number" unless component["rpm_source"] == index
      errors << "rust-v8: component #{component['path']} has an invalid commit" unless component["commit"].to_s.match?(/\A[0-9a-f]{40}\z/)
      errors << "rust-v8: component #{component['path']} has an invalid archive SHA-256" unless archive["sha256"].to_s.match?(/\A[0-9a-f]{64}\z/)
      errors << "rust-v8: component #{component['path']} has an invalid tree SHA-256" unless archive["tree_sha256"].to_s.match?(/\A[0-9a-f]{64}\z/)
      errors << "rust-v8: component #{component['path']} archive tree is unverified" unless archive["content_modes_and_symlinks_match_git"] == true
      errors << "rust-v8: component #{component['path']} archive size is invalid" unless archive["bytes"].to_i.positive?
      begin
        errors << "rust-v8: component #{component['path']} archive URL must use HTTPS" unless URI(archive["url"]).is_a?(URI::HTTPS)
      rescue URI::InvalidURIError, TypeError
        errors << "rust-v8: component #{component['path']} archive URL is invalid"
      end
    end

    summary = source.fetch("source_summary", {})
    errors << "rust-v8: recursive-source archive byte total does not match" unless summary["archive_bytes"] == archives.sum { |archive| archive["bytes"] }
    errors << "rust-v8: recursive-source file total does not match" unless summary["archive_files"] == archives.sum { |archive| archive["file_count"] }
    errors << "rust-v8: recursive-source component tree total does not match" unless summary["component_tree_file_records"] == archives.sum { |archive| archive["tree_file_records"] }
    errors << "rust-v8: recursive-source combined tree count does not match" unless source.dig("reconstruction", "file_records") == summary["archive_files"]
    errors << "rust-v8: recursive-source combined tree SHA-256 is invalid" unless source.dig("reconstruction", "tree_sha256").to_s.match?(/\A[0-9a-f]{64}\z/)
    %w[
      root_archive_identity_verified
      gitmodules_paths_and_urls_verified
      recursive_component_archives_verified
      recursive_component_archive_trees_match_git
      recursive_source_tree_reconstructed
      recursive_source_tree_matches_git
      immutable_recursive_rpm_source_verified
    ].each do |flag|
      errors << "rust-v8: recursive-source validation #{flag} is not true" unless source.dig("validation", flag) == true
    end

    macros = {
      "%{name}" => package.name,
      "%{version}" => version,
      "%{source_commit}" => source.dig("release", "commit")
    }
    spec_sources = spec.scan(/^Source(\d*):\s+(\S+)/).to_h do |number, value|
      expanded = macros.reduce(value) { |result, (macro, replacement)| result.gsub(macro, replacement.to_s) }
      [number.empty? ? 0 : number.to_i, expanded]
    end
    components.each do |component|
      archive = component.fetch("archive")
      expected = "#{archive.fetch('url')}#/#{archive.fetch('filename')}"
      errors << "rust-v8: spec Source#{component.fetch('rpm_source')} does not match the receipt" unless spec_sources[component.fetch("rpm_source")] == expected
      extraction = archive.fetch("layout") == "github-wrapper" ? "extract_wrapped" : "extract_flat"
      unless component.fetch("path") == "."
        expected_line = "#{extraction} #{component.fetch('path')} %{SOURCE#{component.fetch('rpm_source')}}"
        errors << "rust-v8: spec extraction does not match #{component.fetch('path')}" unless spec.lines.map(&:strip).include?(expected_line)
      end
    end
    errors << "rust-v8: spec Source21 does not select the recursive-source receipt" unless spec_sources[21] == source_name
    errors << "rust-v8: spec Source22 does not select the license-audit receipt" unless spec_sources[22] == license_name
    flat_helper = spec[/extract_flat\(\) \{\n(.*?)\n\}/m, 1].to_s
    wrapped_helper = spec[/extract_wrapped\(\) \{\n(.*?)\n\}/m, 1].to_s
    errors << "rust-v8: flat archive extraction helper is invalid" unless flat_helper.include?('tar -xzf "$2" -C "$1" --no-same-owner') && !flat_helper.include?("--strip-components")
    errors << "rust-v8: wrapped archive extraction helper is invalid" unless wrapped_helper.include?('tar -xzf "$2" -C "$1" --no-same-owner --strip-components=1')
    patch_lines = [
      "patch --batch --fuzz=0 -p1 < %{PATCH0}",
      "patch --batch --fuzz=0 -p1 < %{PATCH1}"
    ]
    patch_lines.each do |line|
      errors << "rust-v8: spec does not apply #{line.split.last}" unless spec.lines.map(&:strip).include?(line)
    end
    final_stop = spec.index("echo 'rust-v8 sources are complete")
    errors << "rust-v8: deliberate remaining-gates stop is missing" unless final_stop && spec.index("exit 1", final_stop)

    license = JSON.parse(File.read(license_path))
    errors << "rust-v8: license-audit schema is invalid" unless license["schema"] == "rust-v8-license-audit/v1"
    errors << "rust-v8: license-audit release does not match" unless license["release"].to_s == version
    errors << "rust-v8: license audit is not bound to the source receipt" unless license.dig("source_closure", "sha256") == source_sha256
    license_components = license["components"]
    errors << "rust-v8: license component paths do not match the source receipt" unless Array(license_components).map { |component| component["path"] } == paths
    license_files = Array(license_components).flat_map { |component| Array(component["license_files"]) }
    readme_records = Array(license_components).flat_map { |component| Array(component["readme_chromium"]) }
    license_files.each do |record|
      errors << "rust-v8: license candidate #{record['path']} has an invalid SHA-256" unless record["sha256"].to_s.match?(/\A[0-9a-f]{64}\z/)
    end

    vendored = license.dig("vendored_rust", "packages")
    unless vendored.is_a?(Array)
      return errors << "rust-v8: vendored Rust package inventory is missing"
    end
    placeholders = vendored.select { |record| record["placeholder"] == true }
    source_packages = vendored.reject { |record| record["placeholder"] == true }
    errors << "rust-v8: vendored Rust source declaration inventory is incomplete" unless source_packages.all? { |record| record["manifest_license"] || record["manifest_license_file"] }
    errors << "rust-v8: vendored Rust candidate-text inventory is incomplete" unless source_packages.all? { |record| record["license_file_count"].to_i.positive? }
    license_summary = license.fetch("summary", {})
    expected_license_summary = {
      "components" => components.length,
      "components_with_license_files" => Array(license_components).count { |record| record["license_file_count"].to_i.positive? },
      "components_without_license_files" => Array(license_components).count { |record| record["license_file_count"].to_i.zero? },
      "license_candidate_files" => license_files.length,
      "readme_chromium_records" => readme_records.length,
      "readme_chromium_with_license" => readme_records.count { |record| record.key?("license") },
      "readme_chromium_with_declared_license_file" => readme_records.count { |record| record["license_file"] },
      "readme_chromium_with_verified_declared_license_file" => readme_records.count { |record| record["license_file_verified"] == true },
      "readme_chromium_declared_license_paths" => readme_records.sum { |record| Array(record["license_file_records"]).length },
      "readme_chromium_verified_declared_license_paths" => readme_records.sum { |record| Array(record["license_file_records"]).count { |path| path["verified"] == true } },
      "vendored_rust_packages" => vendored.length,
      "vendored_rust_source_packages" => source_packages.length,
      "vendored_rust_placeholders" => placeholders.length,
      "vendored_rust_source_packages_with_manifest_license" => source_packages.count { |record| record["manifest_license"] },
      "vendored_rust_source_packages_with_manifest_license_file" => source_packages.count { |record| record["manifest_license_file"] },
      "vendored_rust_source_packages_with_verified_manifest_license_file" => source_packages.count { |record| record["manifest_license_file_verified"] == true },
      "vendored_rust_source_packages_with_candidate_texts" => source_packages.count { |record| record["license_file_count"].to_i.positive? }
    }
    errors << "rust-v8: license-audit summary is inconsistent" unless license_summary == expected_license_summary
    missing_declared_license_paths = readme_records.flat_map do |record|
      Array(record["license_file_records"]).reject { |path| path["verified"] == true }.map { |path| path["path"] }
    end.sort
    package_license = package.data.fetch("license_audit", {})
    dependency_license = dependencies.fetch("license_audit", {})
    {
      "candidate_license_files" => "license_candidate_files",
      "vendored_rust_entries" => "vendored_rust_packages",
      "vendored_rust_source_packages" => "vendored_rust_source_packages",
      "vendored_rust_placeholders" => "vendored_rust_placeholders",
      "readme_chromium_declared_license_paths" => "readme_chromium_declared_license_paths",
      "readme_chromium_verified_declared_license_paths" => "readme_chromium_verified_declared_license_paths"
    }.each do |metadata_key, summary_key|
      errors << "rust-v8: package license metadata #{metadata_key} does not match" unless package_license[metadata_key] == license_summary[summary_key]
      errors << "rust-v8: dependency license metadata #{metadata_key} does not match" unless dependency_license[metadata_key] == license_summary[summary_key]
    end
    errors << "rust-v8: package missing declared-license paths do not match" unless package_license["missing_declared_license_paths"] == missing_declared_license_paths
    errors << "rust-v8: dependency missing declared-license paths do not match" unless dependency_license["missing_declared_license_paths"] == missing_declared_license_paths
    component_text_gaps = Array(license_components).select { |record| record["license_file_count"].to_i.zero? }.map { |record| record["path"] }
    errors << "rust-v8: package component-local text gaps do not match" unless package_license["component_local_text_gaps"] == component_text_gaps
    errors << "rust-v8: dependency component-local text gaps do not match" unless dependency_license["components_without_local_license_files"] == component_text_gaps
    %w[
      source_closure_verified
      source_tree_verified
      all_source_components_inventoried
      candidate_license_files_hashed
      readme_chromium_metadata_inventoried
      declared_license_file_paths_inventoried
      vendored_rust_manifests_inventoried
      vendored_rust_placeholders_classified
      vendored_rust_source_package_declarations_complete
      vendored_rust_source_package_candidate_texts_present
    ].each do |flag|
      errors << "rust-v8: license-audit validation #{flag} is not true" unless license.dig("validation", flag) == true
    end
    %w[
      license_expressions_normalized
      required_license_texts_verified
      fedora_allowed_spdx_verified
      source_package_license_complete
      final_static_archive_license_complete
    ].each do |flag|
      errors << "rust-v8: license audit overclaims #{flag}" unless license.dig("validation", flag) == false
    end

    patch_metadata = Array(dependencies["patches"])
    patch_metadata.each do |patch|
      patch_path = File.join(package.directory, patch.fetch("file"))
      actual = File.file?(patch_path) && Digest::SHA256.file(patch_path).hexdigest
      errors << "rust-v8: patch SHA-256 does not match #{patch.fetch('file')}" unless actual == patch["sha256"]
    end
    errors << "rust-v8: package source archive total does not match" unless package.data.dig("source_policy", "source_archive_bytes") == summary["archive_bytes"]
    errors << "rust-v8: dependency source archive total does not match" unless dependencies.dig("source_closure", "archive_bytes") == summary["archive_bytes"]
    errors << "rust-v8: package reconstructed file count does not match" unless package.data.dig("source_policy", "reconstructed_file_records") == source.dig("reconstruction", "file_records")
    errors << "rust-v8: dependency reconstructed tree SHA-256 does not match" unless dependencies.dig("source_closure", "reconstructed_tree_sha256") == source.dig("reconstruction", "tree_sha256")

    reproducibility_path = File.join(package.directory, "reproducibility.yml")
    if File.file?(reproducibility_path)
      reproducibility = load_yaml(reproducibility_path)
      errors << "rust-v8: reproducibility source receipt SHA-256 does not match" unless reproducibility.dig("recursive_source", "receipt_sha256") == source_sha256
      errors << "rust-v8: reproducibility license receipt SHA-256 does not match" unless reproducibility.dig("licenses", "receipt_sha256") == license_sha256
      errors << "rust-v8: reproducibility archive total does not match" unless reproducibility.dig("recursive_source", "archive_bytes") == summary["archive_bytes"]
      errors << "rust-v8: reproducibility tree SHA-256 does not match" unless reproducibility.dig("recursive_source", "reconstructed_tree_sha256") == source.dig("reconstruction", "tree_sha256")
      errors << "rust-v8: reproducibility metadata incorrectly claims a generated recursive archive" unless reproducibility.dig("recursive_source", "recursive_rpm_source_generated") == false
      errors << "rust-v8: reproducibility license candidate count does not match" unless reproducibility.dig("licenses", "candidate_license_files") == license_summary["license_candidate_files"]
      errors << "rust-v8: reproducibility vendored Rust source count does not match" unless reproducibility.dig("licenses", "vendored_rust_source_packages") == license_summary["vendored_rust_source_packages"]
      errors << "rust-v8: reproducibility vendored Rust placeholder count does not match" unless reproducibility.dig("licenses", "vendored_rust_placeholders") == license_summary["vendored_rust_placeholders"]
      errors << "rust-v8: reproducibility declared license-path count does not match" unless reproducibility.dig("licenses", "readme_chromium_declared_license_paths") == license_summary["readme_chromium_declared_license_paths"]
      errors << "rust-v8: reproducibility verified license-path count does not match" unless reproducibility.dig("licenses", "readme_chromium_verified_declared_license_paths") == license_summary["readme_chromium_verified_declared_license_paths"]
      errors << "rust-v8: reproducibility recursive license inventory is incomplete" unless reproducibility.dig("licenses", "recursive_inventory_complete") == true
    else
      errors << "rust-v8: reproducibility metadata is missing"
    end

    errors
  rescue JSON::ParserError, KeyError => e
    errors << "rust-v8: invalid evidence receipt: #{e.message}"
  end

  def validate_bun_dependency_closure(package, dependency_stage, webkit, version)
    return [] unless package.name == "bun" && dependency_stage.is_a?(Hash)

    receipt_name = dependency_stage["proof_receipt"]
    return [] unless receipt_name.is_a?(String) && !receipt_name.empty?

    errors = []
    receipt_path = File.join(package.directory, receipt_name)
    expected_sha256 = dependency_stage["proof_receipt_sha256"]
    valid_receipt = File.file?(receipt_path) && expected_sha256.to_s.match?(/\A[0-9a-f]{64}\z/) &&
                    Digest::SHA256.file(receipt_path).hexdigest == expected_sha256
    errors << "bun: dependency-closure proof receipt is missing or has wrong SHA-256" unless valid_receipt
    return errors unless valid_receipt

    receipt = JSON.parse(File.read(receipt_path))
    errors << "bun: unsupported dependency-closure proof receipt schema" unless receipt["schema"] == "bun-release-local-source-closure/v2"
    errors << "bun: dependency-closure proof package mismatch" unless receipt["package"] == "bun"
    errors << "bun: dependency-closure proof release mismatch" unless receipt["release"].to_s == version

    immutable_hosting_blocked = Array(package.data["blockers"]).any? do |blocker|
      normalized = blocker.to_s.downcase
      normalized.include?("immutable") && normalized.include?("hosting")
    end
    hosting_verified = receipt.dig("validation", "immutable_public_hosting_verified")
    local_webkit = Array(receipt["existing_local_sources"]).find { |source| source.is_a?(Hash) && source["symbol"] == "webkit" }
    if immutable_hosting_blocked
      errors << "bun: dependency-closure proof incorrectly claims immutable public hosting" unless hosting_verified == false
      errors << "bun: dependency-closure proof has hosted WebKit archive" unless webkit.is_a?(Hash) && webkit["archive_url"].nil?
      errors << "bun: dependency-closure proof hosted local-source record" unless local_webkit.is_a?(Hash) && local_webkit["immutable_public_url"].nil?
      errors << "bun: dependency-closure Cargo vendor archive hosting state is invalid" unless dependency_stage["cargo_vendor_archive_hosted"] == false
    else
      errors << "bun: dependency-closure proof does not verify immutable public hosting" unless hosting_verified == true
      hosted_webkit_url = webkit.is_a?(Hash) && webkit["archive_url"]
      local_webkit_url = local_webkit.is_a?(Hash) && local_webkit["immutable_public_url"]
      valid_hosted_webkit = begin
        hosted_webkit_url == local_webkit_url && URI(hosted_webkit_url).is_a?(URI::HTTPS)
      rescue URI::InvalidURIError, TypeError
        false
      end
      errors << "bun: dependency-closure hosted WebKit source mapping is invalid" unless valid_hosted_webkit
      errors << "bun: dependency-closure Cargo vendor archive hosting state is invalid" unless dependency_stage["cargo_vendor_archive_hosted"] == true
    end

    errors
  rescue JSON::ParserError => e
    errors << "bun: invalid dependency-closure proof receipt: #{e.message}"
  end

  def validate_bun_build_plan(package, spec)
    return [] unless package.name == "bun"

    errors = []
    plan = package.data["build_plan"]
    unless plan.is_a?(Hash)
      return ["bun: build_plan must be an object"]
    end

    version = package.upstream["current_version"].to_s
    errors << "bun: build plan target does not match #{version}" unless plan["target_release"].to_s == version
    errors << "bun: enabled build plan has unreconciled source inputs" if package.enabled? && plan["source_inputs_reconciled"] != true
    architectures = plan["architectures"]
    errors << "bun: build plan architectures must be a non-empty array" unless architectures.is_a?(Array) && !architectures.empty?

    stages = plan["stages"]
    unless stages.is_a?(Hash)
      return errors << "bun: build_plan.stages must be an object"
    end

    BUN_BUILD_STAGES.each do |stage_name|
      stage = stages[stage_name]
      unless stage.is_a?(Hash)
        errors << "bun: missing build stage #{stage_name}"
        next
      end

      state = stage["state"]
      errors << "bun: invalid state #{state.inspect} for #{stage_name}" unless %w[blocked verified].include?(state)
      next unless state == "verified"

      stage.each do |key, value|
        if key.end_with?("_verified") && value != true
          errors << "bun: verified stage #{stage_name} has false #{key}"
        end
      end
    end

    final_verified = stages.dig("final", "state") == "verified"
    prerequisite_stages = BUN_BUILD_STAGES - ["final"]
    if final_verified
      prerequisite_stages.each do |stage_name|
        errors << "bun: final stage verified before #{stage_name}" unless stages.dig(stage_name, "state") == "verified"
      end
    end
    if stages.dig("self_rebuild", "state") == "verified" && stages.dig("self_rebuild", "reproducibility_compared") != true
      errors << "bun: verified self-rebuild stage has no reproducibility comparison"
    end
    errors << "bun: enabled package requires a verified final stage" if package.enabled? && !final_verified

    source_inputs = plan["source_inputs"]
    zig = source_inputs.is_a?(Hash) && source_inputs["zig"]
    webkit = source_inputs.is_a?(Hash) && source_inputs["webkit"]
    lolhtml = source_inputs.is_a?(Hash) && source_inputs["lolhtml"]
    npm_lock = source_inputs.is_a?(Hash) && source_inputs["npm_lock"]
    build_graph = source_inputs.is_a?(Hash) && source_inputs["build_graph"]
    seed = source_inputs.is_a?(Hash) && source_inputs["bootstrap_seed"]

    if webkit.is_a?(Hash)
      errors << "bun: WebKit source must be pinned by the Bun release" unless webkit["release_pin"] == "bun-v#{version}"
      errors << "bun: invalid WebKit commit" unless webkit["commit"].to_s.match?(/\A[0-9a-f]{40}\z/)
      errors << "bun: WebKit source must use deterministic git archive acquisition" unless webkit["acquisition"] == "deterministic_git_archive"
      errors << "bun: WebKit source unexpectedly declares submodules" unless webkit["submodules"] == false
      errors << "bun: WebKit source tree is not recorded as complete" unless webkit["source_tree_complete"] == true
      begin
        errors << "bun: WebKit repository URL must use HTTPS" unless URI(webkit["repository_url"]).is_a?(URI::HTTPS)
      rescue URI::InvalidURIError, TypeError
        errors << "bun: invalid WebKit repository URL"
      end
      if stages.dig("webkit_source_build", "state") == "verified"
        errors << "bun: verified WebKit stage lacks a source SHA-256" unless webkit["sha256"].to_s.match?(/\A[0-9a-f]{64}\z/)
      end
    elsif stages.dig("webkit_source_build", "state") == "verified"
      errors << "bun: verified WebKit stage requires source input metadata"
    end

    errors.concat(validate_bun_dependency_closure(package, stages["dependency_closure"], webkit, version))

    if seed.is_a?(Hash)
      errors << "bun: seed source must match the Bun release" unless seed["release_pin"] == "bun-v#{version}"
      errors << "bun: bootstrap seed must be x86_64 for the current proof" unless seed["architecture"] == "x86_64"
      errors << "bun: invalid bootstrap seed SHA-256" unless seed["sha256"].to_s.match?(/\A[0-9a-f]{64}\z/)
      errors << "bun: bootstrap seed is not marked bootstrap-only" unless seed["bootstrap_only"] == true
      errors << "bun: bootstrap seed is allowed in the final payload" unless seed["final_payload_allowed"] == false
      errors << "bun: bootstrap seed is allowed as a final runtime dependency" unless seed["final_runtime_dependency_allowed"] == false
      begin
        errors << "bun: bootstrap seed URL must use HTTPS" unless URI(seed["url"]).is_a?(URI::HTTPS)
      rescue URI::InvalidURIError, TypeError
        errors << "bun: invalid bootstrap seed URL"
      end
    elsif stages.dig("seed_build", "state") == "verified"
      errors << "bun: verified seed build requires bootstrap seed metadata"
    end

    if stages.dig("seed_build", "state") == "verified"
      seed_stage = stages.fetch("seed_build")
      receipt_name = seed_stage["proof_receipt"]
      receipt_path = receipt_name.is_a?(String) && File.join(package.directory, receipt_name)
      unless receipt_path && File.file?(receipt_path)
        errors << "bun: verified seed build is missing proof receipt #{receipt_name.inspect}"
      else
        begin
          receipt = JSON.parse(File.read(receipt_path))
          expected_receipt_sha256 = seed_stage["proof_receipt_sha256"]
          errors << "bun: seed-build proof receipt SHA-256 mismatch" unless expected_receipt_sha256.to_s.match?(/\A[0-9a-f]{64}\z/) && Digest::SHA256.file(receipt_path).hexdigest == expected_receipt_sha256
          errors << "bun: unsupported seed-build proof receipt schema" unless receipt["schema"] == "bun-first-source-build-proof/v1"
          errors << "bun: seed-build proof package mismatch" unless receipt["package"] == "bun"
          errors << "bun: seed-build proof release mismatch" unless receipt["release"] == version
          errors << "bun: seed-build proof profile mismatch" unless receipt["profile"] == "release-local"
          errors << "bun: seed-build proof date mismatch" unless receipt["proof_date"] == seed_stage["proof_date"]
          dependency_stage = stages.fetch("dependency_closure")
          closure_name = dependency_stage["proof_receipt"]
          closure_sha256 = dependency_stage["proof_receipt_sha256"]
          closure_path = closure_name.is_a?(String) && File.join(package.directory, closure_name)
          errors << "bun: seed-build proof source-closure path mismatch" unless receipt.dig("source_closure", "path") == closure_name
          errors << "bun: seed-build proof source-closure SHA-256 mismatch" unless receipt.dig("source_closure", "sha256") == closure_sha256
          unless closure_path && File.file?(closure_path) && closure_sha256.to_s.match?(/\A[0-9a-f]{64}\z/) && Digest::SHA256.file(closure_path).hexdigest == closure_sha256
            errors << "bun: dependency-closure proof receipt is missing or has the wrong SHA-256"
          end
          errors << "bun: seed-build proof source commit mismatch" unless receipt.dig("source_closure", "source_commit") == package.upstream["source_commit"]
          errors << "bun: seed-build proof source SHA-256 mismatch" unless receipt.dig("source_closure", "source_archive_sha256") == package.upstream["source_sha256"]
          errors << "bun: seed-build proof seed archive mismatch" unless receipt.dig("bootstrap_seed", "archive_sha256") == seed["sha256"]
          errors << "bun: seed-build proof seed binary mismatch" unless receipt.dig("bootstrap_seed", "binary_sha256") == seed["binary_sha256"]
          errors << "bun: seed-build proof seed size mismatch" unless receipt.dig("bootstrap_seed", "size_bytes") == seed["binary_size_bytes"]
          errors << "bun: seed-build proof seed version mismatch" unless receipt.dig("bootstrap_seed", "version") == version
          errors << "bun: seed-build proof seed is not bootstrap-only" unless receipt.dig("bootstrap_seed", "bootstrap_only") == true
          errors << "bun: seed-build proof permits the seed in the payload" unless receipt.dig("bootstrap_seed", "final_payload_allowed") == false
          errors << "bun: seed-build proof permits a seed runtime dependency" unless receipt.dig("bootstrap_seed", "final_runtime_dependency_allowed") == false

          patch_digest = lambda do |metadata, path_key, sha_key, label|
            unless metadata.is_a?(Hash)
              errors << "bun: seed-build proof lacks #{label} metadata"
              next nil
            end
            patch_name = metadata[path_key]
            patch_path = patch_name.is_a?(String) && File.join(package.directory, patch_name)
            unless patch_path && File.file?(patch_path)
              errors << "bun: seed-build proof input patch is missing: #{patch_name.inspect}"
              next nil
            end
            actual = Digest::SHA256.file(patch_path).hexdigest
            expected = sha_key && metadata[sha_key]
            errors << "bun: #{label} metadata SHA-256 mismatch" if expected && actual != expected
            actual
          end
          zig_patch_sha256 = patch_digest.call(zig, "patch", nil, "Zig patch")
          webkit_patch_sha256 = patch_digest.call(webkit, "patch", "patch_sha256", "WebKit patch")
          lolhtml_patch_sha256 = patch_digest.call(lolhtml, "patch", "patch_sha256", "lol-html patch")
          npm_lock_patch_sha256 = patch_digest.call(npm_lock, "patch", "patch_sha256", "npm lock patch")
          zig_cwd_patch_sha256 = patch_digest.call(build_graph, "patch", "patch_sha256", "Zig cwd patch")
          cxx_runtime_patch_sha256 = patch_digest.call(build_graph, "cxx_runtime_patch", "cxx_runtime_patch_sha256", "shared C++ runtime patch")
          errors << "bun: seed-build proof Zig commit mismatch" unless receipt.dig("inputs", "zig", "source_commit") == zig["commit"]
          errors << "bun: seed-build proof Zig source SHA-256 mismatch" unless receipt.dig("inputs", "zig", "source_sha256") == zig["sha256"]
          errors << "bun: seed-build proof Zig patch SHA-256 mismatch" unless receipt.dig("inputs", "zig", "patch_sha256") == zig_patch_sha256
          errors << "bun: seed-build proof WebKit commit mismatch" unless receipt.dig("inputs", "webkit", "commit") == webkit["commit"]
          errors << "bun: seed-build proof WebKit source SHA-256 mismatch" unless receipt.dig("inputs", "webkit", "archive_sha256") == webkit["sha256"]
          errors << "bun: seed-build proof WebKit patch SHA-256 mismatch" unless receipt.dig("inputs", "webkit", "patch_sha256") == webkit_patch_sha256
          errors << "bun: seed-build proof lol-html patch SHA-256 mismatch" unless receipt.dig("inputs", "source_patches", "lolhtml_sha256") == lolhtml_patch_sha256
          errors << "bun: seed-build proof npm-lock patch SHA-256 mismatch" unless receipt.dig("inputs", "source_patches", "npm_lock_sha256") == npm_lock_patch_sha256
          errors << "bun: seed-build proof Zig-cwd patch SHA-256 mismatch" unless receipt.dig("inputs", "source_patches", "zig_build_cwd_sha256") == zig_cwd_patch_sha256
          errors << "bun: seed-build proof shared-runtime patch SHA-256 mismatch" unless receipt.dig("inputs", "source_patches", "fedora_shared_cxx_runtime_sha256") == cxx_runtime_patch_sha256
          errors << "bun: seed-build proof npm input receipt mismatch" unless receipt.dig("inputs", "npm_proof", "path") == dependency_stage["npm_install_proof_receipt"] && receipt.dig("inputs", "npm_proof", "sha256") == dependency_stage["npm_install_proof_receipt_sha256"]
          errors << "bun: seed-build proof Cargo input receipt mismatch" unless receipt.dig("inputs", "cargo_proof", "path") == dependency_stage["cargo_build_proof_receipt"] && receipt.dig("inputs", "cargo_proof", "sha256") == dependency_stage["cargo_build_proof_receipt_sha256"]
          [
            [dependency_stage["npm_install_proof_receipt"], dependency_stage["npm_install_proof_receipt_sha256"], "npm"],
            [dependency_stage["cargo_build_proof_receipt"], dependency_stage["cargo_build_proof_receipt_sha256"], "Cargo"]
          ].each do |proof_name, proof_sha256, label|
            proof_path = proof_name.is_a?(String) && File.join(package.directory, proof_name)
            unless proof_path && File.file?(proof_path) && proof_sha256.to_s.match?(/\A[0-9a-f]{64}\z/) && Digest::SHA256.file(proof_path).hexdigest == proof_sha256
              errors << "bun: #{label} input proof receipt is missing or has the wrong SHA-256"
            end
          end
          errors << "bun: seed-build proof native input count mismatch" unless receipt.dig("inputs", "offline_inputs", "native_archives") == dependency_stage["selected_github_archives"]
          errors << "bun: seed-build proof Node-header input count mismatch" unless receipt.dig("inputs", "offline_inputs", "node_header_archives") == dependency_stage["selected_node_header_archives"]
          errors << "bun: seed-build proof npm-root input count mismatch" unless receipt.dig("inputs", "offline_inputs", "npm_install_roots") == 3
          supplemental_npm = receipt.dig("inputs", "offline_inputs", "supplemental_npm_trees")
          valid_supplemental_npm = supplemental_npm.is_a?(Array) && supplemental_npm.all? do |entry|
            entry.is_a?(Hash) && entry["path"].is_a?(String) && !entry["path"].empty? &&
              entry.dig("tree", "sha256").to_s.match?(/\A[0-9a-f]{64}\z/)
          end
          errors << "bun: seed-build proof supplemental npm inputs are invalid" unless valid_supplemental_npm
          errors << "bun: seed-build proof was not network isolated" unless receipt.dig("configure", "network_namespace") == true && receipt.dig("build", "network_namespace") == true
          errors << "bun: seed-build proof did not revalidate prepared inputs" unless receipt.dig("configure", "prepared_inputs_revalidated") == true
          errors << "bun: seed-build proof did not verify bootstrap-seed rule scope" unless receipt.dig("configure", "bootstrap_seed_rule_scope_verified") == true
          expected_seed_rules = %w[codegen dep_build dep_cargo dep_cargo_cross dep_codegen dep_configure dep_fetch dep_fetch_prebuilt dep_prebuild dep_subst link regen smoke_test zig_build zig_check zig_fetch]
          errors << "bun: seed-build proof bootstrap-seed rule set mismatch" unless receipt.dig("configure", "bootstrap_seed_rules") == expected_seed_rules
          errors << "bun: seed-build proof install-edge count mismatch" unless receipt.dig("configure", "install_edges") == 3
          errors << "bun: seed-build proof native-fetch count mismatch" unless receipt.dig("configure", "native_fetch_edges") == 19
          errors << "bun: seed-build proof Node-header fetch count mismatch" unless receipt.dig("configure", "node_header_fetch_edges") == 1
          errors << "bun: seed-build proof did not use local WebKit" unless receipt.dig("configure", "local_webkit_verified") == true
          errors << "bun: seed-build proof retained a Zig fetch edge" unless receipt.dig("configure", "zig_fetch_absent") == true
          errors << "bun: seed-build proof did not verify the Zig source cwd" unless receipt.dig("configure", "zig_source_cwd_verified") == true
          errors << "bun: seed-build proof did not verify stable lol-html Cargo" unless receipt.dig("configure", "stable_lolhtml_cargo_verified") == true
          errors << "bun: seed-build proof contains unexpected URLs" unless receipt.dig("configure", "unexpected_urls_absent") == true
          errors << "bun: seed-build proof output version mismatch" unless receipt.dig("build", "version") == version
          errors << "bun: seed-build proof revision mismatch" unless receipt.dig("build", "revision") == "#{version}-canary.1+#{package.upstream['source_commit'].to_s[0, 9]}"
          output_receipts = %w[bun_profile bun linker_map].map { |key| [key, receipt.dig("build", key)] }
          output_receipts.each do |key, output|
            valid_output = output.is_a?(Hash) && output["path"].is_a?(String) && !output["path"].empty? &&
              !Pathname(output["path"]).absolute? && !Pathname(output["path"]).each_filename.include?("..") &&
              output["size_bytes"].is_a?(Integer) && output["size_bytes"].positive? &&
              output["sha256"].to_s.match?(/\A[0-9a-f]{64}\z/)
            errors << "bun: seed-build proof has an invalid #{key} receipt" unless valid_output
          end
          profile_size = receipt.dig("build", "bun_profile", "size_bytes")
          bun_size = receipt.dig("build", "bun", "size_bytes")
          errors << "bun: seed-build proof stripped output is not smaller than bun-profile" unless profile_size.is_a?(Integer) && bun_size.is_a?(Integer) && bun_size < profile_size
          errors << "bun: seed-build proof smoke failed" unless receipt.dig("build", "smoke_verified") == true
          errors << "bun: seed-build proof did not verify stripped output" unless receipt.dig("build", "stripped_output_verified") == true
          errors << "bun: seed-build proof did not verify Fedora's shared C++ runtime" unless receipt.dig("build", "fedora_shared_cxx_runtime_verified") == true
          errors << "bun: seed-build proof shared-runtime library set mismatch" unless receipt.dig("build", "shared_runtime_libraries") == %w[libgcc_s.so.1 libstdc++.so.6]
          errors << "bun: seed-build proof found a seed payload" unless receipt.dig("seed_contamination", "payload_absent_verified") == true && receipt.dig("seed_contamination", "seed_hash_matches") == 0
          errors << "bun: seed-build proof found a seed runtime dependency" unless receipt.dig("seed_contamination", "runtime_dependency_absent_verified") == true
          errors << "bun: seed-build proof validation is incomplete" unless %w[bootstrap_seed_verified seed_isolated_verified source_build_verified].all? { |key| receipt.dig("validation", key) == true }
          errors << "bun: seed-build proof incorrectly claims a self-rebuild" unless receipt.dig("validation", "self_rebuild_performed") == false
          errors << "bun: seed-build proof incorrectly claims reproducibility" unless receipt.dig("validation", "reproducibility_compared") == false
          errors << "bun: seed-build proof retained relink evidence incorrectly claims completeness" unless receipt.dig("retained_relink_evidence", "complete_lgpl_relink_materials_verified") == false
          errors << "bun: seed-build proof incorrectly claims complete LGPL relink materials" unless receipt.dig("validation", "complete_lgpl_relink_materials_verified") == false
          errors << "bun: seed-build proof incorrectly claims a final license audit" unless receipt.dig("validation", "final_license_audit_verified") == false
          errors << "bun: seed-build proof incorrectly claims a final RPM" unless receipt.dig("validation", "final_rpm_verified") == false
        rescue JSON::ParserError => e
          errors << "bun: invalid seed-build proof receipt: #{e.message}"
        end
      end
    end

    seed_stage = stages["seed_build"]
    if seed_stage.is_a?(Hash) && seed_stage.key?("relink_materials_audit")
      audit = seed_stage["relink_materials_audit"]
      unless audit.is_a?(Hash)
        errors << "bun: relink-materials audit metadata must be an object"
      else
        receipt_name = audit["proof_receipt"]
        receipt_path = receipt_name.is_a?(String) && File.join(package.directory, receipt_name)
        unless receipt_path && File.file?(receipt_path)
          errors << "bun: relink-materials proof receipt is missing: #{receipt_name.inspect}"
        else
          begin
            receipt = JSON.parse(File.read(receipt_path))
            expected_sha256 = audit["proof_receipt_sha256"]
            errors << "bun: relink-materials proof receipt SHA-256 mismatch" unless expected_sha256.to_s.match?(/\A[0-9a-f]{64}\z/) && Digest::SHA256.file(receipt_path).hexdigest == expected_sha256
            errors << "bun: unsupported relink-materials proof receipt schema" unless receipt["schema"] == "bun-relink-materials-audit/v2"
            errors << "bun: relink-materials proof package mismatch" unless receipt["package"] == "bun"
            errors << "bun: relink-materials proof release mismatch" unless receipt["version"] == version
            errors << "bun: relink-materials proof date mismatch" unless receipt["date"] == seed_stage["proof_date"]

            scalar_fields = {
              ["final_link", "direct_object_count"] => "direct_object_count",
              ["final_link", "direct_object_bytes"] => "direct_object_bytes",
              ["final_link", "direct_object_inventory_sha256"] => "direct_object_inventory_sha256",
              ["final_link", "direct_archive_count"] => "direct_archive_count",
              ["final_link", "link_manifest_sha256"] => "link_manifest_sha256",
              ["object_roles", "zig_object_count"] => "zig_object_count",
              ["object_roles", "tinycc_object_count"] => "tinycc_object_count",
              ["generated_webkit_headers", "count"] => "generated_webkit_header_count"
            }
            scalar_fields.each do |receipt_keys, metadata_key|
              errors << "bun: relink-materials proof #{metadata_key} mismatch" unless receipt.dig(*receipt_keys) == audit[metadata_key]
            end

            archives = receipt.dig("final_link", "direct_archives")
            valid_archives = archives.is_a?(Array) && archives.length == audit["direct_archive_count"] && archives.all? do |entry|
              path = entry.is_a?(Hash) && entry["path"]
              path.is_a?(String) && !path.empty? && !Pathname(path).absolute? && !Pathname(path).each_filename.include?("..") &&
                entry["size_bytes"].is_a?(Integer) && entry["size_bytes"].positive? &&
                entry["sha256"].to_s.match?(/\A[0-9a-f]{64}\z/) && entry["kind"] == "archive"
            end
            errors << "bun: relink-materials proof archive inventory is invalid" unless valid_archives

            expected_headers = {
              "build/release-local/deps/WebKit/JavaScriptCore/Headers" => 9,
              "build/release-local/deps/WebKit/JavaScriptCore/PrivateHeaders" => 1415,
              "build/release-local/deps/WebKit/WTF/Headers" => 510,
              "build/release-local/deps/WebKit/bmalloc/Headers" => 360
            }
            header_trees = receipt.dig("generated_webkit_headers", "trees")
            actual_headers = header_trees.is_a?(Array) && header_trees.length == expected_headers.length && header_trees.to_h do |entry|
              [entry.is_a?(Hash) && entry["path"], entry.is_a?(Hash) && entry["count"]]
            end
            errors << "bun: relink-materials proof generated-header inventory mismatch" unless actual_headers == expected_headers
            valid_header_digests = header_trees.is_a?(Array) && header_trees.all? { |entry| entry.is_a?(Hash) && entry["tree_sha256"].to_s.match?(/\A[0-9a-f]{64}\z/) }
            errors << "bun: relink-materials proof generated-header digest is invalid" unless valid_header_digests

            errors << "bun: relink-materials proof rspfile declaration mismatch" unless receipt.dig("final_link", "rspfile_declared") == audit["rspfile_declared"] && receipt.dig("final_link", "rspfile_declared") == true
            errors << "bun: relink-materials proof response-file retention mismatch" unless receipt.dig("final_link", "response_file_count") == 0 && receipt.dig("final_link", "response_files_retained") == audit["response_files_retained"]
            errors << "bun: relink-materials proof bootstrap-wrapper result mismatch" unless receipt.dig("final_link", "bootstrap_seed_wrapper_invoked") == audit["bootstrap_seed_wrapper_invoked"] && receipt.dig("final_link", "bootstrap_seed_wrapper_invoked") == true
            errors << "bun: relink-materials proof presence checks are incomplete" unless %w[direct_objects_present direct_archives_present link_scripts_present linker_map_present build_ninja_present compile_commands_present configure_present generated_webkit_headers_present].all? { |key| receipt.dig("presence", key) == true }
            errors << "bun: relink-materials proof response-file blocker mismatch" unless receipt.dig("blockers", "response_files_not_retained") == true
            errors << "bun: relink-materials proof bootstrap-wrapper blocker mismatch" unless receipt.dig("blockers", "bootstrap_seed_wrapper_invoked") == true
            errors << "bun: relink-materials proof incorrectly claims a relink kit" unless receipt.dig("presence", "relink_kit_payload_present") == false
            errors << "bun: relink-materials proof incorrectly claims complete LGPL materials" unless receipt["complete_lgpl_relink_materials_verified"] == audit["complete_lgpl_relink_materials_verified"] && receipt["complete_lgpl_relink_materials_verified"] == false
            errors << "bun: relink-materials proof incorrectly claims a final license audit" unless receipt["final_license_audit_verified"] == false
            errors << "bun: relink-materials proof incorrectly claims a final RPM" unless receipt["final_rpm_verified"] == false
          rescue JSON::ParserError => e
            errors << "bun: invalid relink-materials proof receipt: #{e.message}"
          end
        end
      end
    end

    self_stage = stages["self_rebuild"]
    if self_stage.is_a?(Hash) && self_stage["proof_receipt"]
      self_receipt = nil
      receipt_name = self_stage["proof_receipt"]
      receipt_path = receipt_name.is_a?(String) && File.join(package.directory, receipt_name)
      unless receipt_path && File.file?(receipt_path)
        errors << "bun: self-rebuild proof receipt is missing: #{receipt_name.inspect}"
      else
        begin
          receipt = self_receipt = JSON.parse(File.read(receipt_path))
          expected_sha256 = self_stage["proof_receipt_sha256"]
          errors << "bun: self-rebuild proof receipt SHA-256 mismatch" unless expected_sha256.to_s.match?(/\A[0-9a-f]{64}\z/) && Digest::SHA256.file(receipt_path).hexdigest == expected_sha256
          errors << "bun: unsupported self-rebuild proof receipt schema" unless receipt["schema"] == "bun-self-rebuild-proof/v2"
          errors << "bun: self-rebuild proof package mismatch" unless receipt["package"] == "bun"
          errors << "bun: self-rebuild proof release mismatch" unless receipt["release"] == version
          errors << "bun: self-rebuild proof profile mismatch" unless receipt["profile"] == "release-local"
          errors << "bun: self-rebuild proof date mismatch" unless receipt["proof_date"] == self_stage["proof_date"]
          errors << "bun: self-rebuild proof root is invalid" unless receipt["proof_root"].to_s.start_with?("/srv/tmp/")

          driver = receipt["first_build"]
          seed_stage = stages.fetch("seed_build")
          errors << "bun: self-rebuild proof driver kind mismatch" unless driver.is_a?(Hash) && driver["driver_proof_kind"] == "first_build"
          errors << "bun: self-rebuild proof driver receipt mismatch" unless driver.is_a?(Hash) && driver["driver_receipt"] == seed_stage["proof_receipt"] && driver["driver_receipt_sha256"] == seed_stage["proof_receipt_sha256"]
          first_receipt_name = seed_stage["proof_receipt"]
          first_receipt_path = first_receipt_name.is_a?(String) && File.join(package.directory, first_receipt_name)
          if first_receipt_path && File.file?(first_receipt_path)
            first_receipt = JSON.parse(File.read(first_receipt_path))
            first_output = first_receipt.dig("build", "bun")
            valid_driver_binary = driver.is_a?(Hash) && first_output.is_a?(Hash) &&
                                  driver["sha256"] == first_output["sha256"] &&
                                  driver["size_bytes"] == first_output["size_bytes"]
            errors << "bun: self-rebuild proof driver binary mismatch" unless valid_driver_binary
            valid_driver_path = driver.is_a?(Hash) && first_output.is_a?(Hash) &&
                                driver["path"].to_s.end_with?("/#{first_output['path']}")
            errors << "bun: self-rebuild proof driver path mismatch" unless valid_driver_path
          else
            errors << "bun: self-rebuild proof driver receipt is missing: #{first_receipt_name.inspect}"
          end

          dependency_stage = stages.fetch("dependency_closure")
          errors << "bun: self-rebuild proof source-closure path mismatch" unless receipt.dig("source_closure", "path") == dependency_stage["proof_receipt"]
          errors << "bun: self-rebuild proof source-closure SHA-256 mismatch" unless receipt.dig("source_closure", "sha256") == dependency_stage["proof_receipt_sha256"]
          errors << "bun: self-rebuild proof source commit mismatch" unless receipt.dig("source_closure", "source_commit") == package.upstream["source_commit"]
          errors << "bun: self-rebuild proof source SHA-256 mismatch" unless receipt.dig("source_closure", "source_archive_sha256") == package.upstream["source_sha256"]
          errors << "bun: self-rebuild proof seed binary mismatch" unless receipt.dig("bootstrap_seed", "binary_sha256") == seed["binary_sha256"]
          errors << "bun: self-rebuild proof seed size mismatch" unless receipt.dig("bootstrap_seed", "size_bytes") == seed["binary_size_bytes"]
          errors << "bun: self-rebuild proof consumed the bootstrap seed" unless receipt.dig("bootstrap_seed", "consumed_by_self_rebuild") == false
          errors << "bun: self-rebuild proof permits the seed in the payload" unless receipt.dig("bootstrap_seed", "payload_allowed") == false
          errors << "bun: self-rebuild proof permits a seed runtime dependency" unless receipt.dig("bootstrap_seed", "runtime_dependency_allowed") == false

          expected_driver_rules = %w[codegen dep_build dep_cargo dep_cargo_cross dep_codegen dep_configure dep_fetch dep_fetch_prebuilt dep_prebuild dep_subst link regen smoke_test zig_build zig_check zig_fetch]
          errors << "bun: self-rebuild proof was not network isolated" unless receipt.dig("configure", "network_namespace") == true && receipt.dig("build", "network_namespace") == true
          errors << "bun: self-rebuild proof did not revalidate prepared inputs" unless receipt.dig("configure", "prepared_inputs_revalidated") == true
          errors << "bun: self-rebuild proof did not verify source-built driver scope" unless receipt.dig("configure", "source_built_driver_rule_scope_verified") == true
          errors << "bun: self-rebuild proof source-built driver rule set mismatch" unless receipt.dig("configure", "source_built_driver_rules") == expected_driver_rules
          errors << "bun: self-rebuild proof retained a bootstrap-seed identity" unless receipt.dig("configure", "bootstrap_seed_identity_absent") == true
          errors << "bun: self-rebuild proof install-edge count mismatch" unless receipt.dig("configure", "install_edges") == 3
          errors << "bun: self-rebuild proof native-fetch count mismatch" unless receipt.dig("configure", "native_fetch_edges") == dependency_stage["selected_github_archives"]
          errors << "bun: self-rebuild proof Node-header fetch count mismatch" unless receipt.dig("configure", "node_header_fetch_edges") == dependency_stage["selected_node_header_archives"]
          errors << "bun: self-rebuild proof did not use local WebKit" unless receipt.dig("configure", "local_webkit_verified") == true
          errors << "bun: self-rebuild proof retained a Zig fetch edge" unless receipt.dig("configure", "zig_fetch_absent") == true
          errors << "bun: self-rebuild proof did not verify the Zig source cwd" unless receipt.dig("configure", "zig_source_cwd_verified") == true
          errors << "bun: self-rebuild proof did not verify stable lol-html Cargo" unless receipt.dig("configure", "stable_lolhtml_cargo_verified") == true
          errors << "bun: self-rebuild proof contains unexpected URLs" unless receipt.dig("configure", "unexpected_urls_absent") == true
          errors << "bun: self-rebuild proof output version mismatch" unless receipt.dig("build", "version") == version
          errors << "bun: self-rebuild proof revision mismatch" unless receipt.dig("build", "revision") == "#{version}-canary.1+#{package.upstream['source_commit'].to_s[0, 9]}"
          output_receipts = %w[bun_profile bun linker_map].map { |key| [key, receipt.dig("build", key)] }
          output_receipts.each do |key, output|
            valid_output = output.is_a?(Hash) && output["path"].is_a?(String) && !output["path"].empty? &&
              !Pathname(output["path"]).absolute? && !Pathname(output["path"]).each_filename.include?("..") &&
              output["size_bytes"].is_a?(Integer) && output["size_bytes"].positive? &&
              output["sha256"].to_s.match?(/\A[0-9a-f]{64}\z/)
            errors << "bun: self-rebuild proof has an invalid #{key} receipt" unless valid_output
          end
          profile_size = receipt.dig("build", "bun_profile", "size_bytes")
          bun_size = receipt.dig("build", "bun", "size_bytes")
          errors << "bun: self-rebuild proof stripped output is not smaller than bun-profile" unless profile_size.is_a?(Integer) && bun_size.is_a?(Integer) && bun_size < profile_size
          errors << "bun: self-rebuild proof smoke failed" unless receipt.dig("build", "smoke_verified") == true
          errors << "bun: self-rebuild proof did not verify stripped output" unless receipt.dig("build", "stripped_output_verified") == true
          errors << "bun: self-rebuild proof did not verify Fedora's shared C++ runtime" unless receipt.dig("build", "fedora_shared_cxx_runtime_verified") == true
          errors << "bun: self-rebuild proof shared-runtime library set mismatch" unless receipt.dig("build", "shared_runtime_libraries") == %w[libgcc_s.so.1 libstdc++.so.6]
          errors << "bun: self-rebuild proof found a seed payload" unless receipt.dig("seed_contamination", "payload_absent_verified") == true && receipt.dig("seed_contamination", "seed_hash_matches") == 0
          errors << "bun: self-rebuild proof found a seed runtime dependency" unless receipt.dig("seed_contamination", "runtime_dependency_absent_verified") == true
          errors << "bun: self-rebuild proof did not compare reproducibility" unless receipt.dig("reproducibility", "compared") == true
          errors << "bun: self-rebuild proof fixed-point result mismatch" unless receipt.dig("reproducibility", "fixed_point_verified") == self_stage["source_rebuild_fixed_point_verified"]
          errors << "bun: self-rebuild proof validation is incomplete" unless %w[source_built_driver_verified self_rebuild_performed offline_verified seed_payload_absent_verified seed_runtime_dependency_absent_verified reproducibility_compared].all? { |key| receipt.dig("validation", key) == true }
          errors << "bun: self-rebuild proof fixed-point validation mismatch" unless receipt.dig("validation", "source_rebuild_fixed_point_verified") == self_stage["source_rebuild_fixed_point_verified"]
          errors << "bun: self-rebuild proof incorrectly claims complete LGPL relink materials" unless receipt.dig("validation", "complete_lgpl_relink_materials_verified") == false
          errors << "bun: self-rebuild proof incorrectly claims a final license audit" unless receipt.dig("validation", "final_license_audit_verified") == false
          errors << "bun: self-rebuild proof incorrectly claims a final RPM" unless receipt.dig("validation", "final_rpm_verified") == false
        rescue JSON::ParserError => e
          errors << "bun: invalid self-rebuild proof receipt: #{e.message}"
        end
      end

      zig_receipt_name = self_stage["zig_reproducibility_proof_receipt"]
      zig_receipt_path = zig_receipt_name.is_a?(String) && File.join(package.directory, zig_receipt_name)
      unless zig_receipt_path && File.file?(zig_receipt_path)
        errors << "bun: Zig reproducibility proof receipt is missing: #{zig_receipt_name.inspect}"
      else
        begin
          zig_receipt = JSON.parse(File.read(zig_receipt_path))
          expected_sha256 = self_stage["zig_reproducibility_proof_receipt_sha256"]
          errors << "bun: Zig reproducibility proof receipt SHA-256 mismatch" unless expected_sha256.to_s.match?(/\A[0-9a-f]{64}\z/) && Digest::SHA256.file(zig_receipt_path).hexdigest == expected_sha256
          errors << "bun: unsupported Zig reproducibility proof receipt schema" unless zig_receipt["schema"] == "bun-zig-reproducibility-proof/v1"
          errors << "bun: Zig reproducibility proof package mismatch" unless zig_receipt["package"] == "bun"
          errors << "bun: Zig reproducibility proof release mismatch" unless zig_receipt["release"] == version
          errors << "bun: Zig reproducibility proof date mismatch" unless zig_receipt["proof_date"] == self_stage["proof_date"]
          errors << "bun: Zig reproducibility proof platform mismatch" unless zig_receipt["platform"] == self_stage["proof_platform"]
          errors << "bun: Zig reproducibility proof source commit mismatch" unless zig_receipt["source_commit"] == package.upstream["source_commit"]
          valid_zig_identity = self_receipt && zig.is_a?(Hash) &&
                               zig_receipt.dig("zig", "source_commit") == zig["commit"] &&
                               zig_receipt.dig("zig", "executable_sha256") == self_receipt.dig("inputs", "zig", "executable_sha256")
          errors << "bun: Zig reproducibility proof source identity mismatch" unless valid_zig_identity
          errors << "bun: Zig reproducibility proof self-rebuild receipt mismatch" unless zig_receipt.dig("self_rebuild_proof", "path") == receipt_name && zig_receipt.dig("self_rebuild_proof", "sha256") == self_stage["proof_receipt_sha256"]
          errors << "bun: Zig reproducibility proof object count mismatch" unless zig_receipt.dig("experiment", "object_count") == self_stage["zig_object_count"]
          errors << "bun: Zig reproducibility proof retained-cache aggregate mismatch" unless zig_receipt.dig("experiment", "retained_cache", "before_aggregate_sha256") == self_stage["zig_retained_cache_aggregate_sha256"] && zig_receipt.dig("experiment", "retained_cache", "after_aggregate_sha256") == self_stage["zig_retained_cache_aggregate_sha256"]
          errors << "bun: Zig reproducibility proof clean-cache aggregate mismatch" unless zig_receipt.dig("experiment", "clean_cache", "before_aggregate_sha256") == self_stage["zig_retained_cache_aggregate_sha256"] && zig_receipt.dig("experiment", "clean_cache", "after_aggregate_sha256") == self_stage["zig_clean_cache_aggregate_sha256"]
          errors << "bun: Zig reproducibility proof retained-cache result mismatch" unless zig_receipt.dig("experiment", "retained_cache", "reproducible") == self_stage["zig_object_aggregate_reproducible_with_retained_cache"]
          errors << "bun: Zig reproducibility proof clean-cache result mismatch" unless zig_receipt.dig("experiment", "clean_cache", "reproducible") == self_stage["zig_object_aggregate_reproducible_from_clean_cache"]
          errors << "bun: Zig reproducibility proof did not serialize the target" unless zig_receipt.dig("experiment", "top_level_jobs") == 1 && zig_receipt.dig("experiment", "zig_parallel_sema") == 1
          errors << "bun: Zig reproducibility proof fixed-point result mismatch" unless zig_receipt.dig("validation", "source_rebuild_fixed_point_verified") == self_stage["source_rebuild_fixed_point_verified"]
        rescue JSON::ParserError => e
          errors << "bun: invalid Zig reproducibility proof receipt: #{e.message}"
        end
      end
    end

    if stages.dig("zig_source_bootstrap", "state") == "verified"
      unless zig.is_a?(Hash)
        errors << "bun: verified Zig stage requires source input metadata"
        return errors
      end

      errors << "bun: Zig source must be pinned by the Bun release" unless zig["release_pin"] == "bun-v#{version}"
      errors << "bun: verified Zig stage has unreconciled source inputs" unless plan["source_inputs_reconciled"] == true
      errors << "bun: invalid Zig commit" unless zig["commit"].to_s.match?(/\A[0-9a-f]{40}\z/)
      errors << "bun: invalid Zig SHA-256" unless zig["sha256"].to_s.match?(/\A[0-9a-f]{64}\z/)
      begin
        errors << "bun: Zig source URL must use HTTPS" unless URI(zig["url"]).is_a?(URI::HTTPS)
      rescue URI::InvalidURIError, TypeError
        errors << "bun: invalid Zig source URL"
      end
      errors << "bun: verified Zig stage used an external Zig binary" unless stages.dig("zig_source_bootstrap", "external_zig_binary_used") == false
      errors << "bun: spec Zig commit does not match build plan" unless spec[/^%global zig_commit\s+(\h{40})$/, 1] == zig["commit"]
      errors << "bun: spec Zig SHA-256 does not match build plan" unless spec[/^%global zig_sha256\s+(\h{64})$/, 1] == zig["sha256"]
      patch = zig["patch"]
      patch_path = patch.is_a?(String) && File.join(package.directory, patch)
      errors << "bun: missing Zig Fedora patch #{patch.inspect}" unless patch_path && File.file?(patch_path)
      errors << "bun: spec does not apply the Zig Fedora patch" unless spec.match?(/^Patch\d+:\s+#{Regexp.escape(patch.to_s)}$/)
      errors << "bun: spec does not build the Zig stage3 target" unless spec.include?("--target stage3")
      errors << "bun: spec does not materialize the Bun Zig root" unless spec.include?(".build-tools/bun-zig/zig")

      receipt_name = stages.dig("zig_source_bootstrap", "proof_receipt")
      receipt_path = receipt_name.is_a?(String) && File.join(package.directory, receipt_name)
      unless receipt_path && File.file?(receipt_path)
        errors << "bun: verified Zig stage is missing proof receipt #{receipt_name.inspect}"
        return errors
      end

      begin
        receipt = JSON.parse(File.read(receipt_path))
        errors << "bun: unsupported Zig proof receipt schema" unless receipt["schema"] == 1
        errors << "bun: proof receipt release mismatch" unless receipt["package_release"] == "bun-v#{version}"
        errors << "bun: proof receipt platform mismatch" unless receipt["proof_platform"] == stages.dig("zig_source_bootstrap", "proof_platform")
        errors << "bun: proof receipt date mismatch" unless receipt["proof_date"] == stages.dig("zig_source_bootstrap", "proof_date")
        errors << "bun: proof receipt source commit mismatch" unless receipt.dig("source", "commit") == zig["commit"]
        errors << "bun: proof receipt source SHA-256 mismatch" unless receipt.dig("source", "sha256") == zig["sha256"]
        errors << "bun: proof receipt patch path mismatch" unless receipt.dig("patch", "path") == patch
        if patch_path && File.file?(patch_path)
          errors << "bun: proof receipt patch SHA-256 mismatch" unless receipt.dig("patch", "sha256") == Digest::SHA256.file(patch_path).hexdigest
        end
        errors << "bun: proof receipt target mismatch" unless receipt.dig("toolchain", "target") == "native"
        errors << "bun: proof receipt CPU mismatch" unless receipt.dig("toolchain", "cpu") == "baseline"
        errors << "bun: proof receipt did not use shared LLVM" unless receipt.dig("toolchain", "shared_llvm") == true
        errors << "bun: proof receipt Zig version mismatch" unless receipt.dig("output", "version") == zig["version_metadata"]
        errors << "bun: proof receipt lacks a valid output SHA-256" unless receipt.dig("output", "executable_sha256").to_s.match?(/\A[0-9a-f]{64}\z/)
        errors << "bun: proof receipt did not verify the Bun tool layout" unless receipt.dig("output", "bun_layout_verified") == true
        errors << "bun: proof receipt used an external Zig binary" unless receipt.dig("output", "external_zig_binary_used") == false
        errors << "bun: proof receipt did not verify source execution" unless receipt.dig("output", "source_execution_verified") == true
      rescue JSON::ParserError => e
        errors << "bun: invalid Zig proof receipt: #{e.message}"
      end
    end

    if package.enabled? && (spec.match?(/^\s*exit 1\s*$/) || spec.include?("Remaining Bun source-build stages are incomplete"))
      errors << "bun: enabled spec still contains a deliberate build stop"
    end

    errors
  end

  def update_package_files(package, version:, sha256:, changelog_message:)
    manifest_data = Marshal.load(Marshal.dump(package.data))
    manifest_data.fetch("upstream")["current_version"] = version
    manifest_data.fetch("upstream")["source_sha256"] = sha256
    invalidate_bun_build_plan!(manifest_data, version) if package.name == "bun"

    spec = File.read(package.spec_path)
    replace_once!(spec, /^Version:\s+\S+$/, "Version:        #{version}", package.spec_path)
    replace_once!(spec, /^Release:\s+\S+$/, "Release:        0.1%{?dist}", package.spec_path)
    replace_once!(spec, /^%global source_sha256\s+\S+$/, "%global source_sha256 #{sha256}", package.spec_path)

    changelog = "* #{Time.now.utc.strftime('%a %b %d %Y')} Marcin FM <marcin@lgic.pl> - #{version}-0.1\n- #{changelog_message}\n"
    replace_once!(spec, /^%changelog\n/, "%changelog\n#{changelog}", package.spec_path)

    changes = {
      package.manifest_path => YAML.dump(manifest_data),
      package.spec_path => spec
    }
    dependency_change = updated_dependency_audit(package, version)
    changes[dependency_change.fetch(:path)] = dependency_change.fetch(:content) if dependency_change
    write_transaction(changes)
    package.data.replace(manifest_data)
  end

  def invalidate_bun_build_plan!(manifest_data, version)
    plan = manifest_data["build_plan"]
    return unless plan.is_a?(Hash)

    plan["target_release"] = version
    plan["source_inputs_reconciled"] = false
    plan.fetch("stages", {}).each_value do |stage|
      next unless stage.is_a?(Hash)

      stage["state"] = "blocked"
      stage.each_key do |key|
        stage[key] = false if key.end_with?("_verified") || key == "reproducibility_compared"
      end
      stage["proof_platform"] = nil if stage.key?("proof_platform")
      stage["proof_date"] = nil if stage.key?("proof_date")
    end
    plan.fetch("source_inputs", {}).each_value do |source|
      next unless source.is_a?(Hash)

      source["stale"] = true
    end
  end

  def validate_opencode_review_evidence(package, dependencies, release)
    return [] unless package.name == "opencode"

    errors = []
    prefix = "#{package.name}:"
    source_files = dependencies.fetch("source_closure_files", {})
    selected_filename = source_files["selected_lock_audit"]
    source_filename = source_files["source_audit"]
    selected_path = selected_filename.is_a?(String) && File.join(package.directory, selected_filename)
    source_path = source_filename.is_a?(String) && File.join(package.directory, source_filename)
    unless selected_path && File.file?(selected_path) && source_path && File.file?(source_path)
      errors << "#{prefix} review evidence requires selected-lock and source receipts"
      return errors
    end

    source_audit = JSON.parse(File.read(source_path))
    sources = Array(source_audit["sources"])
    validate_receipts = lambda do |label, review|
      {
        "selected_lock_audit" => [selected_filename, selected_path],
        "source_audit" => [source_filename, source_path]
      }.each do |key, (filename, path)|
        errors << "#{prefix} #{label} #{key} path does not match" unless review.dig("receipts", key, "path") == filename
        expected_sha256 = Digest::SHA256.file(path).hexdigest
        errors << "#{prefix} #{label} #{key} SHA-256 does not match" unless review.dig("receipts", key, "sha256") == expected_sha256
      end
    end

    expected_lifecycle_review = {
      "source_audit_sha256" => "0f067275e2513d5e2cb6658ba9b58fef42549f2fbeb650c3bd1c65fac1b8f179",
      "reviewed" => true,
      "selected_sources" => 73,
      "counts" => { "prepare" => 68, "install" => 4, "postinstall" => 1 },
      "dependency_reconstruction" => {
        "method" => "extract_reviewed_registry_archives",
        "lifecycle_scripts_executed" => false,
        "network_resolution" => false,
        "policy" => "skip_all_dependency_lifecycle_scripts"
      },
      "prepare" => {
        "action" => "skip",
        "count" => 68,
        "reason" => "Released registry archives already contain their publish-time outputs; generated-output correspondence remains a separate fail-closed review."
      },
      "install_phase" => [
        {
          "package" => "@parcel/watcher@2.5.1",
          "phase" => "install",
          "script" => "node scripts/build-from-source.js",
          "action" => "skip_and_rebuild_from_source",
          "reason" => "The spec explicitly rebuilds watcher.node and replaces the platform payload."
        },
        {
          "package" => "msgpackr-extract@3.0.4",
          "phase" => "install",
          "script" => "node-gyp-build-optional-packages",
          "action" => "skip_optional_native_acceleration",
          "reason" => "The selected runtime retains msgpackr's supported JavaScript fallback."
        },
        {
          "package" => "protobufjs@7.6.2",
          "phase" => "postinstall",
          "script" => "node scripts/postinstall",
          "action" => "skip_non_generating_warning",
          "reason" => "The script only warns about an incompatible parent dependency version scheme and creates no payload."
        },
        {
          "package" => "tree-sitter-bash@0.25.0",
          "phase" => "install",
          "script" => "node-gyp-build",
          "action" => "skip_native_loader_rebuild_wasm",
          "reason" => "Node prebuilds are omitted; the required grammar WASM is rebuilt offline and behavior-tested by the spec."
        },
        {
          "package" => "tree-sitter-powershell@0.25.10",
          "phase" => "install",
          "script" => "node-gyp-build",
          "action" => "skip_native_loader_rebuild_wasm",
          "reason" => "The selected shell parser consumes the grammar WASM, which is rebuilt offline and behavior-tested by the spec."
        }
      ]
    }
    lifecycle_review = dependencies.dig("source_acquisition_findings", "lifecycle_script_review")
    errors << "#{prefix} lifecycle-script review does not match" unless lifecycle_review == expected_lifecycle_review
    lifecycle_sources = sources.select { |source| source.fetch("lifecycle_scripts", {}).any? }
    lifecycle_counts = Hash.new(0)
    lifecycle_sources.each do |source|
      source.fetch("lifecycle_scripts").each_key { |phase| lifecycle_counts[phase] += 1 }
    end
    errors << "#{prefix} lifecycle-script source count does not match" unless lifecycle_sources.length == expected_lifecycle_review.fetch("selected_sources")
    errors << "#{prefix} lifecycle-script phase counts do not match" unless lifecycle_counts == expected_lifecycle_review.fetch("counts")
    actual_install_phase = lifecycle_sources.filter_map do |source|
      scripts = source.fetch("lifecycle_scripts")
      phase = scripts.key?("install") ? "install" : scripts.key?("postinstall") ? "postinstall" : nil
      next unless phase

      {
        "package" => "#{source.fetch('npm_name')}@#{source.fetch('version')}",
        "phase" => phase,
        "script" => scripts.fetch(phase)
      }
    end
    reviewed_install_phase = expected_lifecycle_review.fetch("install_phase").map do |entry|
      entry.slice("package", "phase", "script")
    end
    errors << "#{prefix} lifecycle install-phase coverage does not match" unless actual_install_phase == reviewed_install_phase

    license_filename = source_files["license_review"]
    license_finding = dependencies.dig("source_acquisition_findings", "license_review")
    errors << "#{prefix} license review path linkage is invalid" unless license_finding.is_a?(Hash) && license_finding["path"] == license_filename
    license_path = license_filename.is_a?(String) && File.join(package.directory, license_filename)
    if license_path && File.file?(license_path)
      license_review = load_yaml(license_path)
      errors << "#{prefix} license review schema is invalid" unless license_review["schema"] == "opencode-license-review/v1"
      errors << "#{prefix} license review release does not match" unless license_review["release"].to_s == release
      validate_receipts.call("license review", license_review)

      missing_declarations = sources.filter_map do |source|
        next unless source["declared_license"].to_s.empty?

        "#{source.fetch('npm_name')}@#{source.fetch('version')}"
      end.sort
      resolved_declarations = Array(license_review["declaration_resolutions"]).map { |entry| entry["package"] }.sort
      errors << "#{prefix} license review declaration coverage does not match source audit" unless resolved_declarations == missing_declarations
      errors << "#{prefix} license review declaration count does not match" unless license_review.dig("status", "absent_declarations_resolved") == missing_declarations.length
      errors << "#{prefix} dependency license declaration count does not match" unless license_finding["absent_declarations_resolved"] == missing_declarations.length

      text_groups = %w[software content].flat_map do |kind|
        license_review.dig("missing_package_local_texts", kind).to_h.values
      end
      reviewed_text_packages = text_groups.flat_map { |entry| Array(entry["packages"]) }.sort
      reviewed_text_count = text_groups.sum { |entry| entry["count"].to_i }
      missing_text_packages = sources.filter_map do |source|
        next unless Array(source["license_files"]).empty?

        "#{source.fetch('npm_name')}@#{source.fetch('version')}"
      end.sort
      errors << "#{prefix} license review text coverage does not match source audit" unless reviewed_text_packages == missing_text_packages
      errors << "#{prefix} license review text counts are internally inconsistent" unless reviewed_text_count == reviewed_text_packages.length
      errors << "#{prefix} license review text count does not match" unless license_review.dig("status", "package_local_text_gaps_classified") == missing_text_packages.length
      errors << "#{prefix} dependency license text count does not match" unless license_finding["package_local_text_gaps_classified"] == missing_text_packages.length
      %w[raw_source_audit_unchanged_by_resolution missing_text_count_matches_source_audit excluded_fsl_source_absent_from_selected_receipt].each do |flag|
        errors << "#{prefix} license review validation flag #{flag} is not true" unless license_review.dig("validation", flag) == true
      end
    else
      errors << "#{prefix} license review is missing"
    end

    native_filename = source_files["native_review"]
    native_finding = dependencies.dig("source_acquisition_findings", "native_review")
    errors << "#{prefix} native review path linkage is invalid" unless native_finding.is_a?(Hash) && native_finding["path"] == native_filename
    native_path = native_filename.is_a?(String) && File.join(package.directory, native_filename)
    if native_path && File.file?(native_path)
      native_review = load_yaml(native_path)
      errors << "#{prefix} native review schema is invalid" unless native_review["schema"] == "opencode-native-review/v1"
      errors << "#{prefix} native review release does not match" unless native_review["release"].to_s == release
      validate_receipts.call("native review", native_review)

      native_sources = sources.select { |source| Array(source["native_payloads"]).any? }
      wasm_sources = sources.select { |source| Array(source["wasm_payloads"]).any? }
      reviewed_sources = (native_sources + wasm_sources).uniq { |source| [source["npm_name"], source["version"]] }
      expected = reviewed_sources.to_h do |source|
        identity = "#{source.fetch('npm_name')}@#{source.fetch('version')}"
        roles = []
        roles << "native" if Array(source["native_payloads"]).any?
        roles << "wasm" if Array(source["wasm_payloads"]).any?
        [identity, {
          "roles" => roles,
          "native" => Array(source["native_payloads"]).length,
          "wasm" => Array(source["wasm_payloads"]).length
        }]
      end
      components = Array(native_review["components"])
      component_names = components.map { |component| component["package"] }
      errors << "#{prefix} native review contains duplicate components" unless component_names.uniq.length == component_names.length
      errors << "#{prefix} native review source coverage does not match source audit" unless component_names.sort == expected.keys.sort

      allowed_actions = %w[omit replace_with_system rebuild omit_native_rebuild_wasm pending_rebuild_or_supported_disable]
      components.each do |component|
        identity = component["package"]
        expected_component = expected[identity]
        next unless expected_component

        errors << "#{prefix} native review roles do not match for #{identity}" unless Array(component["roles"]) == expected_component["roles"]
        errors << "#{prefix} native payload count does not match for #{identity}" unless component.dig("payloads", "native") == expected_component["native"]
        errors << "#{prefix} WASM payload count does not match for #{identity}" unless component.dig("payloads", "wasm") == expected_component["wasm"]
        errors << "#{prefix} native review action is invalid for #{identity}" unless allowed_actions.include?(component.dig("decision", "action"))
        errors << "#{prefix} native review retains a prebuilt payload for #{identity}" unless component.dig("decision", "retain_prebuilt_payloads") == false
        errors << "#{prefix} native review source mapping state is missing for #{identity}" unless [true, false].include?(component.dig("decision", "source_mapping_verified"))
        errors << "#{prefix} native review reproducibility state is missing for #{identity}" unless [true, false].include?(component.dig("decision", "reproducible_build_verified"))
        errors << "#{prefix} native review source repository is missing for #{identity}" if component.dig("provenance", "source_repository").to_s.empty?
        %w[registry_git_head tag_object peeled_commit].each do |field|
          value = component.dig("provenance", field)
          errors << "#{prefix} native review #{field} is invalid for #{identity}" unless value.nil? || value.to_s.match?(/\A[0-9a-f]{40}\z/)
        end
      end

      required_subordinate_sources = {
        "@opentui/core@0.4.3" => {
          "ids" => %w[
            tree-sitter-javascript-0.25.0
            tree-sitter-typescript-0.23.2
            tree-sitter-markdown-0.5.1
            tree-sitter-zig-1.1.2
          ],
          "assets" => 5
        },
        "shiki@4.2.0" => {
          "ids" => %w[vscode-oniguruma-1.7.0 oniguruma-08d36110],
          "assets" => 1
        },
        "undici@5.29.0" => {
          "ids" => %w[llhttp-generator-8.1.0 llhttp-generated-release-8.1.0],
          "assets" => 2
        }
      }
      required_subordinate_sources.each do |identity, required|
        component = components.find { |entry| entry["package"] == identity }
        subordinate_sources = Array(component&.dig("provenance", "subordinate_sources"))
        subordinate_ids = subordinate_sources.map { |source| source["id"] }
        unless subordinate_ids.sort == required["ids"].sort
          errors << "#{prefix} native review subordinate source ids do not match for #{identity}"
        end
        subordinate_sources.each do |source|
          source_id = source["id"].to_s
          errors << "#{prefix} native review subordinate repository is missing for #{identity}/#{source_id}" if source["source_repository"].to_s.empty?
          errors << "#{prefix} native review subordinate URL is invalid for #{identity}/#{source_id}" unless source["source_url"].to_s.match?(%r{\Ahttps://})
          errors << "#{prefix} native review subordinate commit is invalid for #{identity}/#{source_id}" unless source["peeled_commit"].to_s.match?(/\A[0-9a-f]{40}\z/)
          errors << "#{prefix} native review subordinate SHA-256 is invalid for #{identity}/#{source_id}" unless source["source_sha256"].to_s.match?(/\A[0-9a-f]{64}\z/)
          tag_object = source["tag_object"]
          errors << "#{prefix} native review subordinate tag object is invalid for #{identity}/#{source_id}" unless tag_object.nil? || tag_object.to_s.match?(/\A[0-9a-f]{40}\z/)
          source.fetch("correspondence_files", {}).each do |path, sha256|
            errors << "#{prefix} native review subordinate correspondence path is empty for #{identity}/#{source_id}" if path.to_s.empty?
            errors << "#{prefix} native review subordinate correspondence SHA-256 is invalid for #{identity}/#{source_id}" unless sha256.to_s.match?(/\A[0-9a-f]{64}\z/)
          end
        end

        assets = Array(component&.dig("provenance", "asset_correspondence"))
        errors << "#{prefix} native review asset correspondence count does not match for #{identity}" unless assets.length == required["assets"]
        assets.each do |asset|
          errors << "#{prefix} native review asset path is missing for #{identity}" if asset["path"].to_s.empty?
          errors << "#{prefix} native review asset URL is invalid for #{identity}" unless asset["upstream_url"].to_s.match?(%r{\Ahttps://})
          errors << "#{prefix} native review asset SHA-256 is invalid for #{identity}" unless asset["sha256"].to_s.match?(/\A[0-9a-f]{64}\z/)
          errors << "#{prefix} native review asset correspondence is not verified for #{identity}" unless asset["verified"] == true
        end
      end

      fff_identity = "@ff-labs/fff-bin-linux-x64-gnu@0.9.4"
      fff = components.find { |component| component["package"] == fff_identity }
      expected_fff_disable = {
        "adapter" => "packages/core/src/filesystem/fff.node.ts",
        "selector" => "packages/core/src/filesystem/search.ts",
        "build_patch" => "opencode-disable-fff.patch",
        "patch_sha256" => "47b06ecf7652b4be11c194c96e81fcbddd1669f5e802d91dfc80228f989e5013",
        "system_binary" => "/usr/bin/rg",
        "runtime_requirement" => "ripgrep",
        "upstream_fallback_pr" => "https://github.com/anomalyco/opencode/pull/31566",
        "upstream_disable_commit" => "e4300e9b7433e068c3d57ac41fcb39bc5de3d32e",
        "native_payload_omitted" => true,
        "selected_cli_behavior_preserved" => true
      }
      unless fff&.dig("provenance", "supported_disable") == expected_fff_disable
        errors << "#{prefix} FFF supported-disable evidence does not match"
      end
      errors << "#{prefix} FFF native payload must be omitted" unless fff&.dig("decision", "action") == "omit"
      fff_patch = File.join(package.directory, expected_fff_disable.fetch("build_patch"))
      errors << "#{prefix} FFF disable patch is missing" unless File.file?(fff_patch)
      if File.file?(fff_patch)
        errors << "#{prefix} FFF disable patch SHA-256 does not match" unless Digest::SHA256.file(fff_patch).hexdigest == expected_fff_disable.fetch("patch_sha256")
      end
      opencode_spec = File.file?(package.spec_path) ? File.read(package.spec_path) : ""
      unless opencode_spec.match?(/^Patch\d+:\s+#{Regexp.escape(expected_fff_disable.fetch("build_patch"))}$/)
        errors << "#{prefix} spec does not apply the FFF disable patch"
      end

      opentui_identity = "@opentui/core-linux-x64@0.4.3"
      opentui = components.find { |component| component["package"] == opentui_identity }
      expected_opentui_build = {
        "source_url" => "https://github.com/anomalyco/opentui/archive/refs/tags/v0.4.3.tar.gz",
        "source_sha256" => "3a72427d6cc6c7dc1086d44037d4f4c499ebc38c2e3e67ecf998695e65c8337a",
        "source_commit" => "5803b2cfa2942c45a3aedbb3601754e27f2cdc68",
        "zig" => {
          "release_pin" => "bun-v1.3.14",
          "source_url" => "https://codeload.github.com/oven-sh/zig/tar.gz/04e7f6ac1e009525bc00934f20199c68f04e0a24",
          "source_commit" => "04e7f6ac1e009525bc00934f20199c68f04e0a24",
          "source_sha256" => "b094c5f806d053896de897023b6c8ccb56903fb994c6f86dd44d848e760fe44d",
          "version" => "0.15.2",
          "fedora_patch" => "opencode-zig-fedora-lib64.patch",
          "fedora_patch_sha256" => "77be015e0b2a83e6d287cfa832fa190dcfe7296320d111e0b129e11a418161fc",
          "external_zig_binary_used" => false
        },
        "uucode" => {
          "source_url" => "https://github.com/jacobsandlund/uucode/archive/84ceda8561a17ba4a9b96ac5c583f779660bbd4e.tar.gz",
          "source_commit" => "84ceda8561a17ba4a9b96ac5c583f779660bbd4e",
          "source_sha256" => "4a7f194ad1f583ffae00bf625986527df89ddd55309ff30314d2d17539a7b011",
          "zig_package_hash" => "uucode-0.1.0-ZZjBPtA_TQCWp5PIKmfm5tu1WOkKWFmBGFEMxircPfkA"
        },
        "yoga" => {
          "source_url" => "https://codeload.github.com/facebook/yoga/tar.gz/042f5013152eb81c1552dec945b88f7b95ca350f",
          "source_tag" => "v3.2.1",
          "source_commit" => "042f5013152eb81c1552dec945b88f7b95ca350f",
          "source_sha256" => "86b399ac31fd820d8ffa823c3fae31bb690b6fc45301b2a8a966c09b5a088b55",
          "zig_package_hash" => "N-V-__8AAOYl0gAU76B1VRPFD9AWvy2VkOef2jN0B3sISTeO"
        },
        "target" => "x86_64-linux-gnu.2.17",
        "optimize" => "ReleaseFast",
        "command" => ".build-tools/bun-zig/zig build --seed 0 --build-id=sha1 -fno-incremental -Dtarget=x86_64-linux-gnu.2.17 -Doptimize=ReleaseFast -j1",
        "strip_command" => "strip --strip-unneeded lib/x86_64-linux/libopentui.so",
        "output" => "packages/core/src/zig/lib/x86_64-linux/libopentui.so",
        "platform_package" => "@opentui/core-linux-x64@0.4.3",
        "platform_payload" => "libopentui.so",
        "published_payload_sha256" => "6a0ea52ab0408a7909f35565d4e204f2a6fd884e33ff6ec570fa9357126ead49",
        "local_recipe_output_sha256" => "1ce4b92b1a075602837c361c6423b7b54298d0c402e3801cbeb27e4e7d935baa",
        "byte_reproducible" => false,
        "reproducibility_required_by_fedora" => false,
        "ffi_exports" => %w[bufferDrawBox createRenderer destroyRenderer render yogaNodeCreate],
        "dynamic_libraries" => %w[libm.so.6 libpthread.so.0 libc.so.6 libdl.so.2 ld-linux-x86-64.so.2],
        "max_glibc" => "GLIBC_2.17",
        "linked_source_licenses" => %w[opentui-LICENSE opentui-uucode-LICENSE.md opentui-yoga-LICENSE],
        "offline_build_verified" => true,
        "ctypes_dlopen_verified" => true,
        "bun_ffi_smoke_in_spec" => true,
        "published_payload_discarded" => true,
        "final_bun_embedding_verified" => false,
        "f43_f44_builds_verified" => false,
        "local_proof_only" => true
      }
      unless opentui&.dig("provenance", "source_build") == expected_opentui_build
        errors << "#{prefix} OpenTUI source-build evidence does not match"
      end
      errors << "#{prefix} OpenTUI must be rebuilt" unless opentui&.dig("decision", "action") == "rebuild"
      opentui_zig_patch = File.join(package.directory, expected_opentui_build.dig("zig", "fedora_patch"))
      errors << "#{prefix} OpenTUI Zig patch is missing" unless File.file?(opentui_zig_patch)
      if File.file?(opentui_zig_patch)
        expected_sha256 = expected_opentui_build.dig("zig", "fedora_patch_sha256")
        errors << "#{prefix} OpenTUI Zig patch SHA-256 does not match" unless Digest::SHA256.file(opentui_zig_patch).hexdigest == expected_sha256
      end
      [
        "Release:        0.7%{?dist}",
        "Source9:        https://github.com/anomalyco/opentui/archive/refs/tags/v%{opentui_version}.tar.gz",
        "Source10:       https://github.com/jacobsandlund/uucode/archive/%{uucode_commit}.tar.gz",
        "Source11:       https://codeload.github.com/facebook/yoga/tar.gz/%{yoga_commit}",
        "Source12:       https://codeload.github.com/oven-sh/zig/tar.gz/%{zig_commit}",
        "Patch1:         opencode-zig-fedora-lib64.patch",
        "BuildRequires:  clang20-devel",
        "BuildRequires:  lld20-devel",
        "BuildRequires:  llvm20-devel",
        "\"$opentui_zig\" build",
        "-Dtarget=x86_64-linux-gnu.2.17",
        "strip --strip-unneeded \"$opentui_lib\"",
        "rm -f \"$opentui_platform/libopentui.so\"",
        "install -pm0755 \"$opentui_lib\" \"$opentui_platform/libopentui.so\"",
        "opentui-uucode-LICENSE.md",
        "opentui-yoga-LICENSE",
        "bun -e '",
        "resolveRenderLib"
      ].each do |snippet|
        errors << "#{prefix} spec is missing OpenTUI build requirement #{snippet}" unless opencode_spec.include?(snippet)
      end

      expected_tree_sitter_builds = {
        "tree-sitter-bash@0.25.0" => {
          "source_package" => "tree-sitter-bash@0.25.0",
          "source_url" => "https://registry.npmjs.org/tree-sitter-bash/-/tree-sitter-bash-0.25.0.tgz",
          "source_sha256" => "9c9460cebe00ec6859f9ba710f7c0bf00ad4fbd7ab72d74e666341491ae2b93d",
          "compiler" => "tree-sitter-cli-0.26.9",
          "wasi_headers" => "Bun-pinned Zig 0.15.2 source build",
          "command" => "TREE_SITTER_WASI_SDK_PATH=.build-tools/tree-sitter-wasi-sdk tree-sitter build --wasm",
          "published_payload_sha256" => "364f0a2cd385c792239423026ef442dbd073d34c396b7bc9e5932426b8e4aa5d",
          "local_recipe_output_sha256" => %w[
            1e50bfe57d9480c218bb67356faeb1cbbc9358b6918c411a50e76e1d386687c6
            4aa19addda7141b77caaa3465a74c1f5f7f9479f15d16dedfb1957a147321907
          ],
          "local_rebuilds" => 2,
          "local_rebuilds_byte_identical" => false,
          "offline_build_verified" => true,
          "parser_smoke_verified" => true,
          "published_payload_discarded" => true,
          "local_proof_only" => true
        },
        "tree-sitter-powershell@0.25.10" => {
          "source_package" => "tree-sitter-powershell@0.25.10",
          "source_url" => "https://registry.npmjs.org/tree-sitter-powershell/-/tree-sitter-powershell-0.25.10.tgz",
          "source_sha256" => "feb79f695aeda8e1835cac98e0b2eed76e2874b6ef1ea197f7cba4c535a6976f",
          "compiler" => "tree-sitter-cli-0.26.9",
          "wasi_headers" => "Bun-pinned Zig 0.15.2 source build",
          "command" => "TREE_SITTER_WASI_SDK_PATH=.build-tools/tree-sitter-wasi-sdk tree-sitter build --wasm",
          "published_payload_sha256" => "1d30b5a21866354aa2eb94845556f1e19126ff00e3335048719a0e6435b1c154",
          "local_recipe_output_sha256" => %w[
            00eb80611bfadcd9c617d79f581bad39f7594d7550210a50d1fddcfe73fa1a14
            2be91a5244d44b52616ca0810cfc98efe5e128fa4c9d2b98f412cde7760fe938
          ],
          "local_rebuilds" => 2,
          "local_rebuilds_byte_identical" => false,
          "offline_build_verified" => true,
          "parser_smoke_verified" => true,
          "published_payload_discarded" => true,
          "local_proof_only" => true
        },
        "web-tree-sitter@0.25.10" => {
          "runtime_source_url" => "https://github.com/tree-sitter/tree-sitter/archive/refs/tags/v0.25.10.tar.gz",
          "runtime_source_sha256" => "ad5040537537012b16ef6e1210a572b927c7cdc2b99d1ee88d44a7dcdc3ff44c",
          "emscripten_source_url" => "https://github.com/emscripten-core/emscripten/archive/refs/tags/4.0.4.tar.gz",
          "emscripten_source_sha256" => "02214fec16769fd5761585baf0038d08c3c1f33d2b7b179953c6fb7e4e04470e",
          "binaryen_source_url" => "https://github.com/WebAssembly/binaryen/archive/refs/tags/version_121.tar.gz",
          "binaryen_source_sha256" => "93f3b3d62def4aee6d09b11e6de75b955d29bc37878117e4ed30c3057a2ca4b4",
          "esbuild_source_url" => "https://github.com/evanw/esbuild/archive/refs/tags/v0.24.2.tar.gz",
          "esbuild_source_sha256" => "171e1b0cd4c64222a1953203f6b3dab3c7a3f95b8939a72b4ebbd024302513b4",
          "esbuild_x_sys_source_sha256" => "3b180937216e93559f16b6076d09baf54a5707378f11b867b6eb914c56b09b91",
          "acorn_source_sha256" => "04c1f5545e4e9140e288bb56b4cbbc4ffd730213e6331330e2bcefc649462104",
          "esbuild_npm_source_sha256" => "873e6170dc7f8bdd0e7a84daf2dfcec4744831271929bca044d6b7216ff86b47",
          "helper_sha256" => "2e143b7c1a115e2effef7d6fc3f282023b8e25fda8fe2a0cd947ffe14e5c952a",
          "validator_sha256" => "57a6b7e6c3b2e2322baf037369fb38012a76c47d3f251187678b13da05eccefc",
          "published_payload_sha256" => "f38dcc4b43b818f9a0785bc1c6d5611a75ac4cdd428ff3f02757c34ca4e46d7f",
          "local_recipe_output_sha256" => "d649036ed74633a1995b9409cb060aa3255a399b96085bfcc465dc8d5e8d8e31",
          "offline_build_verified" => true,
          "bash_and_powershell_parser_smoke_verified" => true,
          "published_payload_discarded" => true,
          "local_proof_only" => true
        }
      }
      expected_tree_sitter_builds.each do |identity, expected_build|
        component = components.find { |entry| entry["package"] == identity }
        unless component&.dig("provenance", "source_build") == expected_build
          errors << "#{prefix} Tree-sitter source-build evidence does not match for #{identity}"
        end
        expected_action = identity == "tree-sitter-bash@0.25.0" ? "omit_native_rebuild_wasm" : "rebuild"
        errors << "#{prefix} Tree-sitter source-build action does not match for #{identity}" unless component&.dig("decision", "action") == expected_action
        errors << "#{prefix} Tree-sitter reproducibility must remain false for #{identity}" unless component&.dig("decision", "reproducible_build_verified") == false
      end

      {
        "opencode-build-web-tree-sitter-runtime.py" => expected_tree_sitter_builds.dig("web-tree-sitter@0.25.10", "helper_sha256"),
        "opencode-validate-tree-sitter.mjs" => expected_tree_sitter_builds.dig("web-tree-sitter@0.25.10", "validator_sha256")
      }.each do |filename, expected_sha256|
        path = File.join(package.directory, filename)
        errors << "#{prefix} Tree-sitter helper #{filename} is missing" unless File.file?(path)
        if File.file?(path)
          errors << "#{prefix} Tree-sitter helper #{filename} SHA-256 does not match" unless Digest::SHA256.file(path).hexdigest == expected_sha256
        end
      end

      [
        "Source13:       https://github.com/tree-sitter/tree-sitter/archive/refs/tags/v%{tree_sitter_version}.tar.gz",
        "Source14:       https://github.com/emscripten-core/emscripten/archive/refs/tags/%{emscripten_version}.tar.gz",
        "Source15:       https://github.com/WebAssembly/binaryen/archive/refs/tags/version_%{binaryen_version}.tar.gz",
        "Source16:       https://github.com/evanw/esbuild/archive/refs/tags/v%{esbuild_version}.tar.gz",
        "Source17:       https://proxy.golang.org/golang.org/x/sys/@v/%{x_sys_version}.zip",
        "Source18:       https://registry.npmjs.org/acorn/-/acorn-8.14.0.tgz",
        "Source19:       https://registry.npmjs.org/esbuild/-/esbuild-%{esbuild_version}.tgz",
        "Source20:       opencode-build-web-tree-sitter-runtime.py",
        "Source21:       opencode-validate-tree-sitter.mjs",
        "BuildRequires:  lld20",
        "BuildRequires:  tree-sitter-cli >= 0.26.9",
        "rm -rf \"$bash_parser/prebuilds\"",
        "python3 %{SOURCE20}",
        "ESBUILD_BINARY_PATH=\"$esbuild_binary\" node-24 script/build.js",
        "TREE_SITTER_WASI_SDK_PATH=\"$wasi_sdk\" tree-sitter build --wasm",
        "node-24 %{SOURCE21}",
        "web-tree-sitter-LICENSE",
        "tree-sitter-bash-LICENSE",
        "tree-sitter-powershell-LICENSE"
      ].each do |snippet|
        errors << "#{prefix} spec is missing Tree-sitter build requirement #{snippet}" unless opencode_spec.include?(snippet)
      end

      parcel_identity = "@parcel/watcher-linux-x64-glibc@2.5.1"
      parcel = components.find { |component| component["package"] == parcel_identity }
      expected_parcel_build = {
        "source_package" => "@parcel/watcher@2.5.1",
        "source_url" => "https://registry.npmjs.org/@parcel/watcher/-/watcher-2.5.1.tgz",
        "source_sha256" => "bf7a6b5577a287153c9a6bf7be953556b998f2a57706eb7a5371ec7eb0088d41",
        "source_commit" => "119f1ff04bb41c2369929e37274900c61b0a9f49",
        "node_addon_api_package" => "node-addon-api@7.1.1",
        "node_addon_api_sha256" => "b10455d15a977c0cd17a1cb0eb679e03d939f8ef8d4302eb33e1f78dacc71f82",
        "command" => "node-24 /usr/lib/node_modules_24/npm/node_modules/node-gyp/bin/node-gyp.js rebuild --nodedir=/usr",
        "output" => "build/Release/watcher.node",
        "platform_package" => "@parcel/watcher-linux-x64-glibc@2.5.1",
        "platform_payload" => "watcher.node",
        "published_payload_sha256" => "e58979069d4f71d2e36f7dc130d6dbc671e63666fe3943fd2ed481519cbf374c",
        "local_output_sha256" => "35cfe2dd72ae617c39054653dcda7fd830485f193d01d20120b2897f8488c589",
        "local_rebuilds" => 2,
        "local_rebuilds_byte_identical" => true,
        "napi_exports" => %w[getEventsSince subscribe unsubscribe writeSnapshot],
        "dynamic_libraries" => %w[libstdc++.so.6 libm.so.6 libgcc_s.so.1 libc.so.6],
        "inotify_smoke_verified" => true,
        "platform_package_load_verified" => true,
        "final_bun_embedding_verified" => false,
        "local_proof_only" => true
      }
      expected_parcel_disable = {
        "flag" => "OPENCODE_EXPERIMENTAL_DISABLE_FILEWATCHER",
        "watcher_service_when_disabled" => "empty",
        "git_head_subscription_disabled" => true,
        "branch_update_events_preserved" => false
      }
      unless parcel&.dig("provenance", "source_build") == expected_parcel_build
        errors << "#{prefix} Parcel watcher source-build evidence does not match"
      end
      unless parcel&.dig("provenance", "disable_assessment") == expected_parcel_disable
        errors << "#{prefix} Parcel watcher disable assessment does not match"
      end
      errors << "#{prefix} Parcel watcher must be rebuilt" unless parcel&.dig("decision", "action") == "rebuild"
      [
        "BuildRequires:  nodejs24-devel",
        "BuildRequires:  nodejs24-npm",
        "node-gyp/bin/node-gyp.js rebuild --nodedir=/usr",
        "--skip-install --skip-embed-web-ui"
      ].each do |snippet|
        errors << "#{prefix} spec is missing Parcel watcher build requirement #{snippet}" unless opencode_spec.include?(snippet)
      end

      bun_pty_identity = "bun-pty@0.4.8"
      bun_pty = components.find { |component| component["package"] == bun_pty_identity }
      expected_bun_pty_build = {
        "npm_source_url" => "https://registry.npmjs.org/bun-pty/-/bun-pty-0.4.8.tgz",
        "npm_source_sha256" => "0d222ae7cab5b2a3e158cdda0461534f44edf08e5c5a72adb1c0b9144e21cedc",
        "npm_contains_rust_source" => false,
        "git_source_url" => "https://github.com/sursaone/bun-pty/archive/41dd5b887f3f47d7c307fd93f828a75dbee97d5a/bun-pty-41dd5b887f3f47d7c307fd93f828a75dbee97d5a.tar.gz",
        "git_source_sha256" => "d4731314a00c46d3810fa08b94ee0bcddb7a5026e47dbca88c83449d351bff9e",
        "git_source_contains_prebuilt_payloads" => false,
        "npm_git_package_json_sha256" => "df55f9b3f2559b66321021f8566b88d940b6ea300072dbb07898f0f957fa1ab9",
        "npm_git_terminal_ts_sha256" => "0c6cdf358568816ec96aef9b320239ef6f9552e9298f8609f0c94cfb12ad51f9",
        "npm_git_wrapper_byte_identical" => true,
        "cargo_vendor_archive" => "opencode-1.18.3-bun-pty-cargo-vendor.tar.zst",
        "cargo_vendor_sha256" => "5c22d4bd79109a3460f3a3d3840d2541da9a6c4c91513c39065a1f4611b7ec5e",
        "cargo_vendor_crates" => 43,
        "cargo_vendor_manifest" => "opencode-1.18.3-bun-pty-cargo-vendor.txt",
        "cargo_vendor_manifest_sha256" => "d57a66c2a1e90516e0b103b3074001f96cefcb4adb4ecc8c3a5532a2c884e500",
        "cargo_vendor_archive_reproducible" => true,
        "cargo_vendor_command" => "cargo vendor --locked --versioned-dirs",
        "cargo_vendor_archive_root" => "cargo-vendor",
        "cargo_vendor_source_date_epoch" => 1768507021,
        "cargo_vendor_archive_rebuilds" => 2,
        "immutable_public_hosting_verified" => false,
        "active_linux_registry_crates" => 37,
        "exact_fedora_provider_closure" => false,
        "macro_build" => "%cargo_prep -v cargo-vendor and %cargo_build",
        "output" => "rust-pty/target/release/librust_pty.so",
        "published_payloads" => {
          "rust-pty/target/release/librust_pty.so" => "a135c3d9f41d09a555e3e4609e0c80fa0ba035736c56791b9df3b55e6376438d",
          "rust-pty/target/release/librust_pty_arm64.so" => "c920f230370d0ea9393ac1311bda45db4c785fd92249b10ff8af67dc3d4b1bc5",
          "rust-pty/target/release/librust_pty.dylib" => "b8a27c3106b164f57472edc9266acc80c11c1b837dba5c397689d63a86e96b7c",
          "rust-pty/target/release/librust_pty_arm64.dylib" => "d61d60ed8348eadfb396418f85ff8dcee7428fe94feb1395c0ae9f68eba3868f",
          "rust-pty/target/release/rust_pty.dll" => "6a653ea742db3dfe37b27bfabcd905800d0bfce57dd60efcbf5a6b032ff5ad77"
        },
        "local_release_sha256" => "f0fb41201158d23541d858cf5d4df2697ebdfbe17f30b645ee1be4a51457ef2a",
        "local_fedora_profile_sha256" => "d389cec65b9d6f74135ebb2d449afabb97c65eb1cd7781ca40b78ab2ad5654de",
        "local_rebuilds" => 2,
        "local_rebuilds_byte_identical" => true,
        "ffi_exports" => %w[bun_pty_close bun_pty_get_exit_code bun_pty_get_pid bun_pty_kill bun_pty_read bun_pty_resize bun_pty_spawn bun_pty_write],
        "dynamic_libraries" => %w[libc.so.6 ld-linux-x86-64.so.2 libgcc_s.so.1],
        "final_bun_embedding_verified" => false,
        "f43_f44_macro_builds_verified" => false,
        "root_cargo_license_declared" => false,
        "authoritative_parent_license" => "MIT"
      }
      unless bun_pty&.dig("provenance", "source_build") == expected_bun_pty_build
        errors << "#{prefix} bun-pty source-build evidence does not match"
      end
      errors << "#{prefix} bun-pty must be rebuilt" unless bun_pty&.dig("decision", "action") == "rebuild"
      bun_pty_vendor_manifest = File.join(package.directory, expected_bun_pty_build.fetch("cargo_vendor_manifest"))
      errors << "#{prefix} bun-pty Cargo vendor manifest is missing" unless File.file?(bun_pty_vendor_manifest)
      if File.file?(bun_pty_vendor_manifest)
        errors << "#{prefix} bun-pty Cargo vendor manifest SHA-256 does not match" unless Digest::SHA256.file(bun_pty_vendor_manifest).hexdigest == expected_bun_pty_build.fetch("cargo_vendor_manifest_sha256")
        errors << "#{prefix} bun-pty Cargo vendor manifest count does not match" unless File.readlines(bun_pty_vendor_manifest, chomp: true).length == expected_bun_pty_build.fetch("cargo_vendor_crates")
      end
      [
        "BuildRequires:  cargo-rpm-macros >= 24",
        "Source6:        https://github.com/sursaone/bun-pty/archive/%{bun_pty_commit}",
        "Source7:        %{name}-%{version}-bun-pty-cargo-vendor.tar.zst",
        "Source8:        %{name}-%{version}-bun-pty-cargo-vendor.txt",
        "%cargo_prep -v cargo-vendor",
        "%cargo_build",
        "%cargo_vendor_manifest",
        "cmp cargo-vendor.txt %{SOURCE8}",
        "bun-pty-cargo-vendor.txt"
      ].each do |snippet|
        errors << "#{prefix} spec is missing bun-pty build requirement #{snippet}" unless opencode_spec.include?(snippet)
      end

      photon_identity = "@silvia-odwyer/photon-node@0.3.4"
      photon = components.find { |component| component["package"] == photon_identity }
      photon_source = sources.find do |source|
        source["npm_name"] == "@silvia-odwyer/photon-node" && source["version"].to_s == "0.3.4"
      end
      published = photon&.dig("provenance", "published_artifact")
      candidate = photon&.dig("provenance", "closest_generated_candidate")
      checks = photon&.dig("provenance", "correspondence_checks")
      errors << "#{prefix} Photon registry gitHead evidence does not match" unless photon&.dig("provenance", "registry_git_head") == "685f5b155b36c5611c08ca678bb78ddbab3edbac"
      errors << "#{prefix} Photon source package version evidence does not match" unless photon&.dig("provenance", "package_version_at_source").to_s == "0.3.3"
      if photon_source && published.is_a?(Hash)
        %w[source_url integrity sha256].each do |field|
          errors << "#{prefix} Photon published artifact #{field} does not match source audit" unless published[field] == photon_source[field]
        end
        errors << "#{prefix} Photon published package identity does not match" unless published["package_name"] == photon_source["npm_name"]
        errors << "#{prefix} Photon published package version does not match" unless published["package_version"].to_s == photon_source["version"].to_s
        errors << "#{prefix} Photon published timestamp evidence does not match" unless published["published_at"] == "2025-05-10T18:44:21.604Z"
      else
        errors << "#{prefix} Photon published artifact evidence is missing"
      end

      published_files = published.to_h.fetch("files", {}).to_h
      expected_published_files = {
        "package/photon_rs_bg.wasm" => "10468181565c56004c867f3a4af96f89a0ef5a63a72f2b5fb12c1f1992a3615c",
        "package/photon_rs.js" => "d60656705f0d59baa79e36b0381eb023f1864eeb57e92956cf21dcd9fb8f879f",
        "package/photon_rs_bg.js" => "02d724f9efb4c4b9a5f49dd83ff7ba0d83af14428059ba21372bad43cc8b2253",
        "package/photon_rs.d.ts" => "b3f7efb72280d1c32cf17dbe436fb783e3f04dc0da56e8c4eaa0ccab3da43d23"
      }
      unless published_files == expected_published_files
        errors << "#{prefix} Photon published artifact file evidence does not match"
      end
      published_files.each do |path, sha256|
        errors << "#{prefix} Photon published artifact SHA-256 is invalid for #{path}" unless sha256.to_s.match?(/\A[0-9a-f]{64}\z/)
      end

      expected_candidate_files = {
        "package.json" => "eaef1dedeb5187129e7044889eadf83322b0cd378be5747b76673bd200087d6a",
        "photon-node_bg.wasm" => "651870eb6466366b89ad46429aaba97e7cfc32992045cc97b9e54a2e63d4e980",
        "photon-node.js" => "c6d3594ee7f96c04417e809ed63b546f8a8a3f77bd307986bc2caf3c5688696b",
        "photon-node.d.ts" => "f672376bf32dba6b98ddc6259779e8f800aa1f01c63845176ff2a72c865a8fe2",
        "photon-node_bg.wasm.d.ts" => "36ea91bf5bf0874e40e842d018a7a062a8ae36a04a37152c71e36e28dd4c913e"
      }
      candidate_files = candidate.to_h.fetch("files", {}).to_h
      unless candidate_files == expected_candidate_files
        errors << "#{prefix} Photon generated candidate file evidence does not match"
      end
      expected_candidate_metadata = {
        "commit" => "232df2fe11218cac0856a56d94ab560b22d5b414",
        "generated_from_commit" => "8591d316252ede15d9f3ed5d3646c4c0c4a215fc",
        "committed_at" => "2025-05-10T18:20:50Z",
        "package_name" => "photon-rs",
        "package_version" => "0.3.2"
      }
      expected_candidate_metadata.each do |field, value|
        errors << "#{prefix} Photon generated candidate #{field} does not match" unless candidate.to_h[field].to_s == value
      end
      candidate_files.each do |path, sha256|
        errors << "#{prefix} Photon generated candidate SHA-256 is invalid for #{path}" unless sha256.to_s.match?(/\A[0-9a-f]{64}\z/)
      end

      required_failed_checks = %w[
        source_package_version_matches
        generated_package_identity_matches
        generated_package_version_matches
        generated_filenames_match
        generated_wasm_sha256_matches
        generated_js_sha256_matches
        generated_declarations_sha256_matches
        exact_local_ref_found
      ]
      required_failed_checks.each do |flag|
        errors << "#{prefix} Photon mismatch evidence flag #{flag} is not false" unless checks.to_h[flag] == false
      end
      {
        "WASM" => ["package/photon_rs_bg.wasm", "photon-node_bg.wasm"],
        "JavaScript" => ["package/photon_rs.js", "photon-node.js"],
        "declarations" => ["package/photon_rs.d.ts", "photon-node.d.ts"]
      }.each do |kind, (published_path, candidate_path)|
        if published_files[published_path] == candidate_files[candidate_path]
          errors << "#{prefix} Photon #{kind} mismatch evidence has equal hashes"
        end
      end
      errors << "#{prefix} Photon source mapping must remain unresolved" unless photon&.dig("decision", "source_mapping_verified") == false

      expected_counts = {
        "component_identities" => reviewed_sources.length,
        "native_sources" => native_sources.length,
        "native_payloads" => native_sources.sum { |source| Array(source["native_payloads"]).length },
        "wasm_sources" => wasm_sources.length,
        "wasm_payloads" => wasm_sources.sum { |source| Array(source["wasm_payloads"]).length }
      }
      expected_counts.each do |key, value|
        errors << "#{prefix} native review scope #{key} does not match" unless native_review.dig("scope", key) == value
      end
      status_counts = {
        "component_identities_classified" => expected_counts["component_identities"],
        "native_sources_classified" => expected_counts["native_sources"],
        "native_payloads_classified" => expected_counts["native_payloads"],
        "wasm_sources_classified" => expected_counts["wasm_sources"],
        "wasm_payloads_classified" => expected_counts["wasm_payloads"],
        "retained_prebuilt_payloads" => 0,
        "source_mappings_verified" => components.count { |component| component.dig("decision", "source_mapping_verified") == true },
        "source_mappings_unresolved" => components.count { |component| component.dig("decision", "source_mapping_verified") == false }
      }
      status_counts.each do |key, value|
        errors << "#{prefix} native review status #{key} does not match" unless native_review.dig("status", key) == value
        errors << "#{prefix} dependency native review #{key} does not match" unless native_finding[key] == value
      end
      %w[native_sources_verified wasm_sources_verified reproducible_builds_verified].each do |flag|
        errors << "#{prefix} native review must remain fail-closed for #{flag}" unless native_review.dig("status", flag) == false
      end
      %w[exact_native_wasm_source_coverage registry_git_heads_checked local_git_refs_checked raw_source_audit_unchanged].each do |flag|
        errors << "#{prefix} native review validation flag #{flag} is not true" unless native_review.dig("validation", flag) == true
      end
    else
      errors << "#{prefix} native review is missing"
    end

    errors
  rescue JSON::ParserError, Agentlab::Error, KeyError => e
    ["#{package.name}: invalid OpenCode review evidence: #{e.message}"]
  end

  def updated_dependency_audit(package, version)
    path = File.join(package.directory, "dependencies.yml")
    return unless File.file?(path)

    dependencies = load_yaml(path)
    return unless dependencies.key?("closure_audit")

    previous_version = dependencies["target_release"].to_s
    dependencies["target_release"] = version
    audit = dependencies.fetch("closure_audit")
    audit["audited_release"] = nil
    audit.each_key do |key|
      audit[key] = false if key.end_with?("_verified", "_recorded")
    end
    dependencies.fetch("source_closure_files", {}).transform_values! do |filename|
      filename.is_a?(String) && !previous_version.empty? ? filename.gsub(previous_version, version) : filename
    end
    { path: path, content: YAML.dump(dependencies) }
  end

  def write_transaction(changes)
    originals = changes.to_h { |path, _content| [path, File.binread(path)] }
    written = []

    changes.each do |path, content|
      atomic_write(path, content)
      written << path
    end
  rescue StandardError => e
    written.reverse_each do |path|
      atomic_write(path, originals.fetch(path))
    rescue StandardError
      # Preserve the original failure; the worktree exposes any rollback issue.
    end
    raise e
  end

  def atomic_write(path, content)
    mode = File.exist?(path) ? File.stat(path).mode & 0o777 : 0o644
    Tempfile.create([".agentlab-", ".tmp"], File.dirname(path)) do |file|
      file.binmode
      file.write(content)
      file.flush
      file.fsync
      File.chmod(mode, file.path)
      File.rename(file.path, path)
    end
  end

  def authorization_header(uri, authorization_host, token)
    return if token.nil? || token.empty?
    return unless authorization_host == "api.github.com" && uri.host == authorization_host

    "Bearer #{token}"
  end

  def replace_once!(content, pattern, replacement, path)
    count = content.scan(pattern).length
    raise Error, "expected one #{pattern.inspect} match in #{path}, found #{count}" unless count == 1

    content.sub!(pattern, replacement)
  end

  def http_get(uri, json:, redirects: 5, authorization_host: nil)
    raise Error, "too many redirects while fetching #{uri}" if redirects.zero?
    raise Error, "refusing non-HTTPS URL #{uri}" unless uri.is_a?(URI::HTTPS)

    authorization_host ||= uri.host

    request = Net::HTTP::Get.new(uri)
    request["Accept"] = json ? "application/vnd.github+json" : "application/octet-stream"
    request["User-Agent"] = "agentlab-packaging"
    token = ENV["GH_TOKEN"] || ENV["GITHUB_TOKEN"]
    authorization = authorization_header(uri, authorization_host, token)
    request["Authorization"] = authorization if authorization

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
      http.request(request)
    end

    case response
    when Net::HTTPSuccess
      response.body
    when Net::HTTPRedirection
      http_get(
        URI.join(uri, response.fetch("location")),
        json: json,
        redirects: redirects - 1,
        authorization_host: authorization_host
      )
    else
      raise Error, "HTTP #{response.code} while fetching #{uri}: #{response.body.to_s[0, 300]}"
    end
  end
end
