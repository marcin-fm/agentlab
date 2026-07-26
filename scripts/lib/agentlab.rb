# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "net/http"
require "open3"
require "pathname"
require "rubygems/version"
require "shellwords"
require "tempfile"
require "uri"
require "yaml"
require_relative "openchamber_licenses"

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
    source_delivery
    lolhtml_rpm_cargo
    dependency_staging
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

  def copr_package_build(owner:, project:, package_name:, chroots:, timeout: nil)
    config_path = ENV["COPR_CONFIG"].to_s
    raise Error, "COPR_CONFIG is not set; activate the project identity before COPR mutation" if config_path.empty?

    values = copr_config_values(config_path)
    uri = URI("#{values.fetch('copr_url').sub(%r{/+\z}, '')}/api_3/package/build")
    raise Error, "refusing non-HTTPS COPR URL #{uri}" unless uri.is_a?(URI::HTTPS)

    request = Net::HTTP::Post.new(uri)
    request.basic_auth(values.fetch("login"), values.fetch("token"))
    request["Accept"] = "application/json"
    request["Content-Type"] = "application/json"
    request["User-Agent"] = "agentlab-packaging"
    payload = {
      "ownername" => owner,
      "projectname" => project,
      "package_name" => package_name,
      "chroots" => chroots,
      "background" => false,
      "enable_net" => false
    }
    payload["timeout"] = timeout if timeout
    request.body = JSON.generate(payload)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }

    unless response.is_a?(Net::HTTPSuccess)
      detail = response.body.to_s[0, 300]
      begin
        detail = JSON.parse(response.body).fetch("error", detail)
      rescue JSON::ParserError
        # Preserve the bounded response body when COPR does not return JSON.
      end
      raise Error, "COPR package build failed: #{detail}"
    end

    result = JSON.parse(response.body)
    raise Error, "COPR package build failed: #{result.fetch('error')}" if result.key?("error")
    raise Error, "COPR package build response did not identify a build" if result["id"].to_s.empty?

    result
  rescue JSON::ParserError, KeyError => e
    raise Error, "invalid COPR package build response: #{e.message}"
  rescue URI::InvalidURIError => e
    raise Error, "invalid COPR URL: #{e.message}"
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
    constraints = (requirement || ">= 0").split(",").map(&:strip)
    version_requirement = Gem::Requirement.new(*constraints)
    prerelease_allowed = version_requirement.requirements.any? { |_operator, version| version.prerelease? }
    response = http_get(URI("https://crates.io/api/v1/crates/#{crate_name}"), json: true)
    payload = JSON.parse(response)
    versions = payload.fetch("versions").filter_map do |release|
      next if release["yanked"] == true

      number = release.fetch("num")
      version = Gem::Version.new(number)
      next if version.prerelease? && !prerelease_allowed
      next unless version_requirement.satisfied_by?(version)

      [version, number]
    rescue ArgumentError
      nil
    end
    raise Error, "no stable crates.io release found for #{crate_name} matching #{version_requirement}" if versions.empty?

    versions.max_by(&:first).last
  rescue JSON::ParserError => e
    raise Error, "invalid crates.io response for #{crate_name}: #{e.message}"
  end

  def pypi_latest_release(project)
    uri = URI("https://pypi.org/pypi/#{URI.encode_www_form_component(project)}/json")
    payload = JSON.parse(http_get(uri, json: true))
    version = payload.fetch("info").fetch("version")
    parsed_version = Gem::Version.new(version)
    raise Error, "latest PyPI release for #{project} is a prerelease: #{version}" if parsed_version.prerelease?

    source = payload.fetch("urls").select do |file|
      file["packagetype"] == "sdist" && file["yanked"] != true
    end.min_by do |file|
      filename = file.fetch("filename")
      [filename.end_with?(".tar.gz") ? 0 : 1, filename, file.fetch("url")]
    end
    raise Error, "latest stable PyPI release for #{project} #{version} has no non-yanked sdist" unless source

    source_url = source.fetch("url")
    raise Error, "PyPI sdist URL must use HTTPS for #{project}" unless URI(source_url).is_a?(URI::HTTPS)

    sha256 = source.fetch("digests").fetch("sha256")
    raise Error, "invalid PyPI sdist SHA-256 for #{project} #{version}" unless sha256.match?(/\A[0-9a-f]{64}\z/)

    { version: version, source_url: source_url, source_sha256: sha256 }
  rescue JSON::ParserError, KeyError, URI::InvalidURIError => e
    raise Error, "invalid PyPI response for #{project}: #{e.message}"
  rescue ArgumentError => e
    raise Error, "invalid PyPI version for #{project}: #{e.message}"
  end

  def latest_upstream_release(package)
    return pypi_latest_release(package.upstream.fetch("project")) if package.upstream.fetch("provider") == "pypi"

    { version: latest_upstream_version(package) }
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
    when "pypi"
      pypi_latest_release(package.upstream.fetch("project")).fetch(:version)
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

  def validate_openchamber_selected_lock(package, dependencies)
    return [] unless package.name == "openchamber"

    errors = []
    metadata = dependencies.fetch("selected_lock_receipt")
    filename = dependencies.dig("source_closure_files", "selected_lock_audit")
    path = filename.is_a?(String) && File.join(package.directory, filename)
    unless path && File.file?(path)
      return ["openchamber: selected lock receipt is missing: #{filename.inspect}"]
    end

    expected_sha256 = metadata.fetch("sha256")
    actual_sha256 = Digest::SHA256.file(path).hexdigest
    errors << "openchamber: selected lock receipt SHA-256 mismatch" unless expected_sha256.to_s.match?(/\A[0-9a-f]{64}\z/) && actual_sha256 == expected_sha256

    receipt = JSON.parse(File.read(path))
    errors << "openchamber: selected lock receipt schema mismatch" unless receipt["schema"] == "openchamber-selected-lock-audit/v2" && metadata["schema"] == receipt["schema"]
    errors << "openchamber: selected lock receipt release mismatch" unless receipt["release"].to_s == package.upstream.fetch("current_version").to_s
    errors << "openchamber: selected lock receipt source tag mismatch" unless receipt["source_tag"] == package.upstream.fetch("source_tag")
    errors << "openchamber: selected lock receipt source commit mismatch" unless receipt["source_commit"] == package.upstream.fetch("source_commit")
    errors << "openchamber: selected lock receipt lock SHA-256 mismatch" unless receipt.dig("lockfile", "sha256") == metadata["lock_sha256"]

    expected_counts = {
      "selected_workspaces" => receipt.dig("selection", "selected_workspaces"),
      "selected_packages" => receipt.dig("selection", "selected_packages"),
      "runtime_packages" => receipt.dig("selection", "roles", "runtime"),
      "build_packages" => receipt.dig("selection", "roles", "build"),
      "test_packages" => receipt.dig("selection", "roles", "test"),
      "registry_packages" => receipt.dig("selection", "origins", "registry"),
      "github_packages" => receipt.dig("selection", "origins", "github"),
      "platform_excluded" => receipt.dig("selection", "platform_excluded"),
      "policy_excluded" => receipt.dig("selection", "policy_excluded"),
      "source_import_files" => Array(receipt.dig("source_import_graph", "files")).length,
      "source_import_package_roots" => Array(receipt.dig("source_import_graph", "package_roots")).length,
      "source_import_globs" => Array(receipt.dig("source_import_graph", "globs")).length
    }
    expected_counts.each do |field, value|
      errors << "openchamber: selected lock receipt #{field} mismatch" unless metadata[field] == value
    end

    source_policy = package.data.fetch("source_policy")
    errors << "openchamber: package selected-lock count mismatch" unless source_policy["selected_lock_packages"] == metadata["selected_packages"]
    errors << "openchamber: package runtime count mismatch" unless source_policy["selected_runtime_packages"] == metadata["runtime_packages"]
    errors << "openchamber: package build count mismatch" unless source_policy["selected_build_packages"] == metadata["build_packages"]
    errors << "openchamber: package test count mismatch" unless source_policy["selected_test_packages"] == metadata["test_packages"]
    errors << "openchamber: package source-import file count mismatch" unless source_policy["source_import_files"] == metadata["source_import_files"]
    errors << "openchamber: package source-import root count mismatch" unless source_policy["source_import_package_roots"] == metadata["source_import_package_roots"]
    errors << "openchamber: package does not mark selected lock authoritative" unless source_policy["selected_lock_authoritative"] == true

    normalization = receipt.fetch("workspace_version_normalization")
    errors << "openchamber: workspace version normalization method mismatch" unless normalization["method"] == "manifest_dependency_map_equivalence"
    errors << "openchamber: workspace version normalization rewrites lock values" unless normalization["original_lock_versions_preserved"] == true
    errors << "openchamber: workspace version normalization is not limited to package identity" unless normalization["accepted_for_selected_package_identity"] == true
    errors << "openchamber: workspace version normalization records mismatch" unless normalization["records"] == receipt["known_workspace_version_mismatches"]

    source_graph = receipt.fetch("source_import_graph")
    errors << "openchamber: source-import graph schema mismatch" unless source_graph["schema"] == "openchamber-source-import-graph/v1"
    files = Array(source_graph["files"])
    roots = Array(source_graph["package_roots"])
    errors << "openchamber: source-import files are not sorted or unique" unless files.map { |record| record["path"] } == files.map { |record| record["path"] }.sort.uniq
    errors << "openchamber: source-import package roots are not sorted or unique" unless roots.map { |record| record["name"] } == roots.map { |record| record["name"] }.sort.uniq
    files.each do |record|
      source_path = record["path"]
      errors << "openchamber: invalid source-import path #{source_path.inspect}" unless source_path.is_a?(String) && !source_path.empty? && !Pathname.new(source_path).absolute? && !Pathname.new(source_path).each_filename.include?("..")
      errors << "openchamber: invalid source-import SHA-256 for #{source_path.inspect}" unless record["sha256"].to_s.match?(/\A[0-9a-f]{64}\z/)
    end
    %w[entrypoints_resolved local_imports_resolved literal_dynamic_imports_only literal_globs_only glob_matches_recorded source_files_hashed].each do |flag|
      errors << "openchamber: source-import validation #{flag} is not true" unless source_graph.dig("validation", flag) == true
    end

    validation = receipt.fetch("validation")
    %w[source_identity_verified manifest_dependency_groups_match known_workspace_version_mismatches_match workspace_version_metadata_normalized node_runtime_exclusions_enforced source_import_reachability_verified authoritative_closure_verified].each do |flag|
      errors << "openchamber: selected lock validation #{flag} is not true" unless validation[flag] == true
    end
    errors << "openchamber: selected lock incorrectly claims matching workspace versions" unless validation["workspace_versions_match"] == false
    %w[source_archives_verified licenses_verified binary_inclusion_verified bundled_provides_generated].each do |flag|
      errors << "openchamber: selected lock overclaims #{flag}" unless validation[flag] == false
    end

    errors
  rescue JSON::ParserError, KeyError, TypeError => e
    ["openchamber: invalid selected lock evidence: #{e.message}"]
  end

  def validate_openchamber_source_acquisition(package, dependencies)
    return [] unless package.name == "openchamber"

    errors = []
    metadata = dependencies.fetch("source_acquisition_receipt")
    filename = dependencies.dig("source_closure_files", "source_audit")
    path = filename.is_a?(String) && File.join(package.directory, filename)
    return ["openchamber: source acquisition receipt is missing: #{filename.inspect}"] unless path && File.file?(path)

    actual_sha256 = Digest::SHA256.file(path).hexdigest
    errors << "openchamber: source acquisition receipt SHA-256 mismatch" unless metadata["sha256"] == actual_sha256

    receipt = JSON.parse(File.read(path))
    errors << "openchamber: source acquisition receipt schema mismatch" unless receipt["schema"] == "openchamber-source-acquisition/v1" && metadata["schema"] == receipt["schema"]
    errors << "openchamber: source acquisition package mismatch" unless receipt["package"] == package.name
    errors << "openchamber: source acquisition release mismatch" unless receipt["release"].to_s == package.upstream.fetch("current_version").to_s
    errors << "openchamber: source acquisition tag mismatch" unless receipt["source_tag"] == package.upstream.fetch("source_tag")
    errors << "openchamber: source acquisition commit mismatch" unless receipt["source_commit"] == package.upstream.fetch("source_commit")

    selected_filename = dependencies.dig("source_closure_files", "selected_lock_audit")
    selected_path = selected_filename.is_a?(String) && File.join(package.directory, selected_filename)
    return errors << "openchamber: selected lock receipt is unavailable for source acquisition validation" unless selected_path && File.file?(selected_path)

    selected_sha256 = Digest::SHA256.file(selected_path).hexdigest
    errors << "openchamber: source acquisition selected-lock SHA-256 mismatch" unless receipt["selected_lock_receipt_sha256"] == selected_sha256 && metadata["selected_lock_receipt_sha256"] == selected_sha256
    selected = JSON.parse(File.read(selected_path))

    expected = {}
    role_rank = { "test" => 0, "build" => 1, "runtime" => 2 }
    selected.fetch("packages").each do |record|
      key = [record.fetch("origin"), record.fetch("source_url"), record.fetch("integrity")]
      source = expected[key] ||= {
        "npm_name" => record.fetch("npm_name"),
        "version" => record.fetch("version"),
        "origin" => record.fetch("origin"),
        "source_url" => record.fetch("source_url"),
        "integrity" => record.fetch("integrity"),
        "package_paths" => [],
        "roles" => Set.new,
        "candidate_for_binary" => false
      }
      unless source.values_at("npm_name", "version") == record.values_at("npm_name", "version")
        errors << "openchamber: selected source identity maps to conflicting package identities"
      end
      source["package_paths"] << record.fetch("package_path")
      source["roles"] << record.fetch("role")
      source["candidate_for_binary"] ||= record.fetch("candidate_for_binary")
    end

    records = Array(receipt["sources"])
    errors << "openchamber: source acquisition records are not sorted" unless records == records.sort_by { |record| [record.fetch("origin"), record.fetch("npm_name"), record.fetch("version")] }
    errors << "openchamber: source acquisition source count mismatch" unless records.length == expected.length && metadata["unique_sources"] == expected.length
    actual = records.to_h { |record| [[record["origin"], record["source_url"], record["integrity"]], record] }
    errors << "openchamber: source acquisition identities are not unique" unless actual.length == records.length

    expected.each do |key, source|
      record = actual[key]
      unless record
        errors << "openchamber: acquired source is missing for #{source['npm_name']}@#{source['version']}"
        next
      end
      errors << "openchamber: acquired package identity mismatch for #{source['npm_name']}" unless record.values_at("npm_name", "version") == source.values_at("npm_name", "version")
      errors << "openchamber: acquired package paths mismatch for #{source['npm_name']}@#{source['version']}" unless record["package_paths"] == source["package_paths"].uniq.sort
      expected_roles = source["roles"].to_a.sort_by { |role| role_rank.fetch(role) }.reverse
      errors << "openchamber: acquired roles mismatch for #{source['npm_name']}@#{source['version']}" unless record["roles"] == expected_roles
      errors << "openchamber: acquired binary candidacy mismatch for #{source['npm_name']}@#{source['version']}" unless record["candidate_for_binary"] == source["candidate_for_binary"]
      errors << "openchamber: invalid acquired archive name for #{source['npm_name']}@#{source['version']}" unless record["archive"].to_s.match?(/\Asha512-[0-9a-f]{128}\.tgz\z/)
      errors << "openchamber: invalid acquired SHA-256 for #{source['npm_name']}@#{source['version']}" unless record["sha256"].to_s.match?(/\A[0-9a-f]{64}\z/)
      errors << "openchamber: invalid acquired size for #{source['npm_name']}@#{source['version']}" unless record["size"].is_a?(Integer) && record["size"].positive?
      errors << "openchamber: invalid acquired file count for #{source['npm_name']}@#{source['version']}" unless record["file_count"].is_a?(Integer) && record["file_count"].positive?
      errors << "openchamber: invalid acquired unpacked size for #{source['npm_name']}@#{source['version']}" unless record["unpacked_size"].is_a?(Integer) && record["unpacked_size"].positive?
    end

    validation = receipt.fetch("validation")
    %w[registry_integrity_verified archive_paths_verified source_sha256_recorded].each do |flag|
      errors << "openchamber: source acquisition validation #{flag} is not true" unless validation[flag] == true
    end
    %w[lifecycle_scripts_executed dependency_resolution_performed licenses_verified native_sources_verified generated_sources_verified].each do |flag|
      errors << "openchamber: source acquisition overclaims #{flag}" unless validation[flag] == false
    end

    source_policy = package.data.fetch("source_policy")
    errors << "openchamber: package source acquisition receipt mismatch" unless source_policy["source_acquisition_receipt"] == filename
    errors << "openchamber: package source acquisition SHA-256 mismatch" unless source_policy["source_acquisition_sha256"] == actual_sha256
    errors << "openchamber: package source acquisition count mismatch" unless source_policy["source_acquisition_unique_sources"] == expected.length
    errors
  rescue JSON::ParserError, KeyError, TypeError => e
    ["openchamber: invalid source acquisition evidence: #{e.message}"]
  end

  def validate_openchamber_source_materialization(package, dependencies)
    return [] unless package.name == "openchamber"

    errors = []
    metadata = dependencies.fetch("source_materialization_receipt")
    filename = dependencies.dig("source_closure_files", "source_materialization")
    path = filename.is_a?(String) && File.join(package.directory, filename)
    return ["openchamber: source materialization receipt is missing: #{filename.inspect}"] unless path && File.file?(path)

    actual_sha256 = Digest::SHA256.file(path).hexdigest
    errors << "openchamber: source materialization receipt SHA-256 mismatch" unless metadata["sha256"] == actual_sha256
    receipt = JSON.parse(File.read(path))
    errors << "openchamber: source materialization schema mismatch" unless receipt["schema"] == "openchamber-source-materialization/v1" && metadata["schema"] == receipt["schema"]
    errors << "openchamber: source materialization package mismatch" unless receipt["package"] == package.name
    errors << "openchamber: source materialization release mismatch" unless receipt["release"].to_s == package.upstream.fetch("current_version").to_s

    source_filename = dependencies.dig("source_closure_files", "source_audit")
    source_path = source_filename.is_a?(String) && File.join(package.directory, source_filename)
    return errors << "openchamber: source audit is unavailable for materialization validation" unless source_path && File.file?(source_path)

    source_sha256 = Digest::SHA256.file(source_path).hexdigest
    errors << "openchamber: source materialization source-audit SHA-256 mismatch" unless receipt.dig("source_audit", "sha256") == source_sha256 && metadata["source_audit_sha256"] == source_sha256
    errors << "openchamber: source materialization source-audit filename mismatch" unless receipt.dig("source_audit", "filename") == source_filename
    source_audit = JSON.parse(File.read(source_path))

    records = source_audit.fetch("sources").map do |source|
      {
        "archive" => source.fetch("archive"),
        "sha256" => source.fetch("sha256"),
        "size_bytes" => source.fetch("size"),
        "npm_name" => source.fetch("npm_name"),
        "version" => source.fetch("version"),
        "roles" => source.fetch("roles"),
        "package_paths" => source.fetch("package_paths")
      }
    end.sort_by { |record| record.fetch("archive") }
    grouped = {
      "production_build" => records.select { |record| !(record.fetch("roles") & %w[runtime build]).empty? },
      "test" => records
    }
    expected_filenames = {
      "production_build" => dependencies.dig("source_closure_files", "production_build_closure"),
      "test" => dependencies.dig("source_closure_files", "test_closure")
    }
    grouped.each do |role, members|
      archive = receipt.dig("archives", role)
      unless archive.is_a?(Hash)
        errors << "openchamber: source materialization archive #{role} is missing"
        next
      end
      expected_summary = {
        "filename" => expected_filenames.fetch(role),
        "member_count" => members.length,
        "input_bytes" => members.sum { |record| record.fetch("size_bytes") },
        "member_manifest_sha256" => Digest::SHA256.hexdigest(JSON.generate(members) + "\n")
      }
      expected_summary.each do |field, value|
        errors << "openchamber: source materialization #{role} #{field} mismatch" unless archive[field] == value && metadata.dig(role, field) == value
      end
      expected_static = {
        "role" => role == "production_build" ? "production-build-npm-source-bundle" : "test-capable-npm-source-bundle",
        "recipe" => "deterministic-archive-bundle/v1",
        "compression" => "zstd-10-single-thread",
        "archive_root" => role == "production_build" ? "openchamber-#{receipt.fetch('release')}-nm-prod-build" : "openchamber-#{receipt.fetch('release')}-nm-dev-test"
      }
      expected_static.each do |field, value|
        errors << "openchamber: source materialization #{role} #{field} mismatch" unless archive[field] == value
      end
      %w[size_bytes].each do |field|
        value = archive[field]
        errors << "openchamber: source materialization #{role} #{field} is invalid" unless value.is_a?(Integer) && value.positive? && metadata.dig(role, field) == value
      end
      %w[sha256].each do |field|
        value = archive[field]
        errors << "openchamber: source materialization #{role} #{field} is invalid" unless value.to_s.match?(/\A[0-9a-f]{64}\z/) && metadata.dig(role, field) == value
      end
    end

    errors << "openchamber: source materialization roles mismatch" unless receipt["selected_archive_roles"] == %w[production_build test]
    validation = receipt.fetch("validation")
    %w[source_audit_verified cached_member_sizes_verified cached_member_sha256_verified safe_archive_paths_verified archive_roots_verified production_role_selection_verified test_superset_verified deterministic_regeneration_verified].each do |flag|
      errors << "openchamber: source materialization validation #{flag} is not true" unless validation[flag] == true
    end
    %w[network_access_performed node_modules_materialized dependency_resolution_performed patches_applied lifecycle_scripts_executed package_build_performed rpm_integrated].each do |flag|
      errors << "openchamber: source materialization overclaims #{flag}" unless validation[flag] == false && metadata.dig("validation", flag) == false
    end

    source_policy = package.data.fetch("source_policy")
    errors << "openchamber: package source materialization receipt mismatch" unless source_policy["source_materialization_receipt"] == filename
    errors << "openchamber: package source materialization SHA-256 mismatch" unless source_policy["source_materialization_sha256"] == actual_sha256
    errors << "openchamber: package does not mark source bundles materialized" unless source_policy["source_bundles_materialized"] == true
    errors << "openchamber: package overclaims source bundle delivery" unless source_policy["source_bundle_delivery_verified"] == false
    errors
  rescue JSON::ParserError, KeyError, TypeError => e
    ["openchamber: invalid source materialization evidence: #{e.message}"]
  end

  def validate_openchamber_source_license_inventory(package, dependencies)
    return [] unless package.name == "openchamber"

    errors = []
    metadata = dependencies.fetch("source_license_inventory_receipt")
    filename = dependencies.dig("source_closure_files", "source_license_inventory")
    path = filename.is_a?(String) && File.join(package.directory, filename)
    return ["openchamber: source-license inventory is missing: #{filename.inspect}"] unless path && File.file?(path)

    actual_sha256 = Digest::SHA256.file(path).hexdigest
    errors << "openchamber: source-license inventory SHA-256 mismatch" unless metadata["sha256"] == actual_sha256
    receipt = JSON.parse(File.read(path))
    errors << "openchamber: source-license inventory schema mismatch" unless receipt["schema"] == "openchamber-source-license-inventory/v1" && metadata["schema"] == receipt["schema"]
    errors << "openchamber: source-license inventory package mismatch" unless receipt["package"] == package.name
    errors << "openchamber: source-license inventory release mismatch" unless receipt["release"].to_s == package.upstream.fetch("current_version").to_s

    bindings = {
      "selected_lock" => ["selected_lock_audit", "selected_lock_receipt_sha256"],
      "source_audit" => ["source_audit", "source_audit_sha256"]
    }
    bindings.each do |receipt_key, (source_key, metadata_key)|
      source_filename = dependencies.dig("source_closure_files", source_key)
      source_path = source_filename.is_a?(String) && File.join(package.directory, source_filename)
      unless source_path && File.file?(source_path)
        errors << "openchamber: source-license inventory #{receipt_key} is unavailable"
        next
      end
      source_sha256 = Digest::SHA256.file(source_path).hexdigest
      errors << "openchamber: source-license inventory #{receipt_key} filename mismatch" unless receipt.dig(receipt_key, "filename") == source_filename
      errors << "openchamber: source-license inventory #{receipt_key} SHA-256 mismatch" unless receipt.dig(receipt_key, "sha256") == source_sha256 && metadata[metadata_key] == source_sha256
    end

    source_filename = dependencies.dig("source_closure_files", "source_audit")
    source_path = source_filename.is_a?(String) && File.join(package.directory, source_filename)
    return errors << "openchamber: source audit is unavailable for source-license validation" unless source_path && File.file?(source_path)

    source_audit = JSON.parse(File.read(source_path))
    expected_archives = source_audit.fetch("sources").map do |source|
      source.slice("archive", "sha256", "size", "npm_name", "version", "package_paths", "roles", "package_json", "declared_license", "license_files")
    end.sort_by { |source| source.fetch("archive") }
    archives = receipt.fetch("archives")
    errors << "openchamber: source-license inventory archives are not sorted" unless archives == archives.sort_by { |source| source.fetch("archive") }
    errors << "openchamber: source-license inventory archive evidence mismatch" unless archives == expected_archives

    expected_findings = OpenChamberLicenses.findings_for(expected_archives)
    errors << "openchamber: source-license inventory findings mismatch" unless receipt["findings"] == expected_findings
    expected_summary = {
      "selected_package_records" => source_audit.dig("summary", "selected_package_records"),
      "unique_archives" => expected_archives.length,
      "license_file_count" => expected_archives.sum { |source| source.fetch("license_files").length },
      "sources_without_declared_license" => expected_findings.fetch("missing_declared_license").length,
      "sources_without_license_files" => expected_findings.fetch("missing_license_files").length,
      "ambiguous_declared_license_sources" => expected_findings.fetch("ambiguous_declared_license").length,
      "non_spdx_declared_license_sources" => expected_findings.fetch("non_spdx_declared_license").length
    }
    expected_summary.each do |field, value|
      errors << "openchamber: source-license inventory #{field} mismatch" unless receipt.dig("summary", field) == value && metadata[field] == value
    end

    validation = receipt.fetch("validation")
    %w[selected_lock_binding_verified source_audit_binding_verified archive_identity_verified package_manifest_license_recorded package_local_license_texts_hashed missing_evidence_isolated ambiguous_evidence_isolated non_spdx_evidence_isolated].each do |flag|
      errors << "openchamber: source-license inventory validation #{flag} is not true" unless validation[flag] == true
    end
    %w[aggregate_license_expression_verified rpm_license_payload_complete generated_asset_licenses_verified binary_inclusion_verified bundled_provides_verified offline_build_verified package_enabled copr_enabled].each do |flag|
      errors << "openchamber: source-license inventory overclaims #{flag}" unless validation[flag] == false && metadata.dig("validation", flag) == false
    end

    source_policy = package.data.fetch("source_policy")
    errors << "openchamber: package source-license inventory receipt mismatch" unless source_policy["source_license_inventory_receipt"] == filename
    errors << "openchamber: package source-license inventory SHA-256 mismatch" unless source_policy["source_license_inventory_sha256"] == actual_sha256
    errors << "openchamber: package source-license archive count mismatch" unless source_policy["source_license_inventory_archives"] == expected_archives.length
    errors << "openchamber: package overclaims source-license aggregate" unless source_policy["source_license_aggregate_verified"] == false
    errors << "openchamber: package overclaims source-license RPM payload" unless source_policy["source_license_rpm_payload_complete"] == false
    errors
  rescue JSON::ParserError, KeyError, TypeError => e
    ["openchamber: invalid source-license inventory evidence: #{e.message}"]
  end

  def validate_openchamber_native_review(package, dependencies)
    return [] unless package.name == "openchamber"

    errors = []
    metadata = dependencies.fetch("native_review_receipt")
    filename = dependencies.dig("source_closure_files", "native_review")
    path = filename.is_a?(String) && File.join(package.directory, filename)
    return ["openchamber: native review is missing: #{filename.inspect}"] unless path && File.file?(path)

    actual_sha256 = Digest::SHA256.file(path).hexdigest
    errors << "openchamber: native review SHA-256 mismatch" unless metadata["sha256"] == actual_sha256
    review = load_yaml(path)
    errors << "openchamber: native review schema mismatch" unless review["schema"] == "openchamber-native-review/v1" && metadata["schema"] == review["schema"]
    errors << "openchamber: native review release mismatch" unless review["release"].to_s == package.upstream.fetch("current_version").to_s

    receipt_files = {
      "selected_lock_audit" => dependencies.dig("source_closure_files", "selected_lock_audit"),
      "source_audit" => dependencies.dig("source_closure_files", "source_audit"),
      "source_materialization" => dependencies.dig("source_closure_files", "source_materialization")
    }
    receipt_files.each do |key, receipt_filename|
      receipt_path = receipt_filename.is_a?(String) && File.join(package.directory, receipt_filename)
      unless receipt_path && File.file?(receipt_path)
        errors << "openchamber: native review #{key} receipt is unavailable"
        next
      end
      errors << "openchamber: native review #{key} path mismatch" unless review.dig("receipts", key, "path") == receipt_filename
      errors << "openchamber: native review #{key} SHA-256 mismatch" unless review.dig("receipts", key, "sha256") == Digest::SHA256.file(receipt_path).hexdigest
    end

    source_path = File.join(package.directory, receipt_files.fetch("source_audit"))
    source_audit = JSON.parse(File.read(source_path))
    fields = %w[native_payloads wasm_payloads executable_payloads native_source_paths]
    sources = source_audit.fetch("sources").select { |source| fields.any? { |field| Array(source[field]).any? } }
    expected = sources.to_h { |source| ["#{source.fetch('npm_name')}@#{source.fetch('version')}", source] }
    components = Array(review["components"])
    component_names = components.map { |component| component["package"] }
    errors << "openchamber: native review contains duplicate components" unless component_names.uniq.length == component_names.length
    errors << "openchamber: native review source coverage mismatch" unless component_names.sort == expected.keys.sort

    allowed_actions = %w[exclude_mobile_source require_exact_source_build rebuild_same_archive require_subordinate_source retain_build_support]
    components.each do |component|
      identity = component["package"]
      source = expected[identity]
      next unless source

      fields.each do |field|
        values = Array(source[field])
        errors << "openchamber: native review #{field} count mismatch for #{identity}" unless component.dig("audit", field, "count") == values.length
        digest = Digest::SHA256.hexdigest(JSON.generate(values) + "\n")
        errors << "openchamber: native review #{field} digest mismatch for #{identity}" unless component.dig("audit", field, "paths_sha256") == digest
      end
      lifecycle_digest = Digest::SHA256.hexdigest(JSON.generate(source.fetch("lifecycle_scripts")) + "\n")
      errors << "openchamber: native review lifecycle digest mismatch for #{identity}" unless component.dig("audit", "lifecycle_scripts_sha256") == lifecycle_digest
      errors << "openchamber: native review action is invalid for #{identity}" unless allowed_actions.include?(component.dig("decision", "action"))
      errors << "openchamber: native review retains a prebuilt payload for #{identity}" unless component.dig("decision", "retain_prebuilt_payloads") == false
      errors << "openchamber: native review source mapping state is missing for #{identity}" unless [true, false].include?(component.dig("decision", "source_mapping_verified"))
      reproducible = component.dig("decision", "reproducible_build_verified")
      errors << "openchamber: native review reproducibility state is missing for #{identity}" unless [true, false].include?(reproducible)
      proven_rebuilds = %w[@esbuild/linux-x64@0.27.3 @rollup/rollup-linux-x64-gnu@4.59.0 @tailwindcss/oxide-linux-x64-gnu@4.2.1 better-sqlite3@12.10.0 ghostty-web@0.4.0 node-pty@1.2.0-beta.12]
      errors << "openchamber: native review overclaims a reproducible build for #{identity}" if reproducible == true && !proven_rebuilds.include?(identity)
    end

    expected_groups = {
      "target_excluded_mobile_source" => %w[@capacitor/android@8.4.1 @capacitor/ios@8.4.1 @capacitor/keyboard@8.0.5],
      "platform_companion" => %w[@esbuild/linux-x64@0.27.3 @rollup/rollup-linux-x64-gnu@4.59.0 @tailwindcss/oxide-linux-x64-gnu@4.2.1 lightningcss-linux-x64-gnu@1.31.1 sherpa-onnx-linux-x64@1.13.3],
      "same_archive_rebuild" => %w[better-sqlite3@12.10.0 node-pty@1.2.0-beta.12],
      "generated_wasm" => %w[ghostty-web@0.4.0 shiki@3.23.0 source-map@0.8.0-beta.0],
      "build_support_source" => %w[node-addon-api@7.1.1]
    }
    expected_groups.each do |kind, identities|
      actual = components.select { |component| component.dig("mapping", "kind") == kind }.map { |component| component["package"] }.sort
      errors << "openchamber: native review #{kind} classification mismatch" unless actual == identities.sort
    end
    source_packages = {
      "@esbuild/linux-x64@0.27.3" => "esbuild@0.27.3",
      "@rollup/rollup-linux-x64-gnu@4.59.0" => "rollup@4.59.0",
      "@tailwindcss/oxide-linux-x64-gnu@4.2.1" => "@tailwindcss/oxide@4.2.1",
      "lightningcss-linux-x64-gnu@1.31.1" => "lightningcss@1.31.1",
      "sherpa-onnx-linux-x64@1.13.3" => "sherpa-onnx-node@1.12.28"
    }
    source_packages.each do |identity, source_package|
      component = components.find { |entry| entry["package"] == identity }
      errors << "openchamber: native review source package mismatch for #{identity}" unless component&.dig("mapping", "source_package") == source_package
      expected_verified = %w[@esbuild/linux-x64@0.27.3 @rollup/rollup-linux-x64-gnu@4.59.0 @tailwindcss/oxide-linux-x64-gnu@4.2.1 lightningcss-linux-x64-gnu@1.31.1 sherpa-onnx-linux-x64@1.13.3].include?(identity)
      errors << "openchamber: native review platform mapping verification mismatch for #{identity}" unless component&.dig("decision", "source_mapping_verified") == expected_verified
    end
    esbuild = components.find { |component| component["package"] == "@esbuild/linux-x64@0.27.3" }
    errors << "openchamber: native review accepts a version-different esbuild provider" unless esbuild&.dig("mapping", "available_system_provider") == "golang-github-evanw-esbuild-0.28.1" && esbuild&.dig("mapping", "system_provider_exact") == false
    esbuild_filename = dependencies.dig("source_closure_files", "esbuild_proof")
    esbuild_path = esbuild_filename.is_a?(String) && File.join(package.directory, esbuild_filename)
    if esbuild_path && File.file?(esbuild_path)
      esbuild_sha256 = Digest::SHA256.file(esbuild_path).hexdigest
      esbuild_proof = JSON.parse(File.read(esbuild_path))
      errors << "openchamber: esbuild proof path mismatch" unless esbuild&.dig("proof", "path") == esbuild_filename && review.dig("receipts", "esbuild_proof", "path") == esbuild_filename
      errors << "openchamber: esbuild proof SHA-256 mismatch" unless review.dig("receipts", "esbuild_proof", "sha256") == esbuild_sha256
      errors << "openchamber: esbuild proof identity mismatch" unless esbuild_proof["schema"] == "openchamber-esbuild-proof/v1" && esbuild_proof["package"] == "@esbuild/linux-x64@0.27.3" && esbuild_proof.dig("source", "upstream_tag_commit") == "9129e00e6c36a3e374820cb5e3fc2cd319c8ab85"
      errors << "openchamber: esbuild proof source mismatch" unless esbuild_proof.dig("source", "archive_sha256") == "05d56070104b46d24c8921bfc4c83209d71cf583eb0396c13d0f359705bb5b61" && esbuild_proof.dig("go_dependency", "zip_sha256") == "3b180937216e93559f16b6076d09baf54a5707378f11b867b6eb914c56b09b91"
      errors << "openchamber: esbuild proof build contract mismatch" unless esbuild_proof.dig("build", "network_isolated") == true && esbuild_proof.dig("build", "jobs") == 4 && esbuild_proof.dig("build", "first_sha256") == esbuild_proof.dig("build", "second_sha256") && esbuild_proof.dig("build", "rpath_or_runpath") == false
      errors << "openchamber: esbuild runtime proof is incomplete" unless esbuild_proof.dig("validation", "published_companion_excluded") == true && esbuild_proof.dig("validation", "upstream_go_tests_passed") == true && esbuild_proof.dig("validation", "binary_version_verified") == true && esbuild_proof.dig("validation", "npm_wrapper_transform_verified") == true && esbuild_proof.dig("validation", "final_openchamber_inclusion_verified") == false
      errors << "openchamber: esbuild review state mismatch" unless esbuild.dig("decision", "reproducible_build_verified") == true
    else
      errors << "openchamber: esbuild proof is unavailable"
    end

    rollup = components.find { |component| component["package"] == "@rollup/rollup-linux-x64-gnu@4.59.0" }
    rollup_filename = dependencies.dig("source_closure_files", "rollup_proof")
    rollup_path = rollup_filename.is_a?(String) && File.join(package.directory, rollup_filename)
    if rollup_path && File.file?(rollup_path)
      rollup_sha256 = Digest::SHA256.file(rollup_path).hexdigest
      rollup_proof = JSON.parse(File.read(rollup_path))
      errors << "openchamber: rollup proof path mismatch" unless rollup&.dig("proof", "path") == rollup_filename && review.dig("receipts", "rollup_proof", "path") == rollup_filename
      errors << "openchamber: rollup proof SHA-256 mismatch" unless review.dig("receipts", "rollup_proof", "sha256") == rollup_sha256
      errors << "openchamber: rollup proof identity mismatch" unless rollup_proof["schema"] == "openchamber-rollup-proof/v1" && rollup_proof["package"] == "@rollup/rollup-linux-x64-gnu@4.59.0" && rollup_proof.dig("source", "upstream_tag_commit") == "ae846957f109690a866cc3e4c073613c338d3476"
      errors << "openchamber: rollup proof source mismatch" unless rollup_proof.dig("source", "archive_sha256") == "3891df7d50bf194c7ec54e8a2d6ac3a52c493c0a640d1496ef18ae8f8e8102ca" && rollup_proof.dig("cargo_source", "lock_sha256") == "6715a94534fc3af86a1fe69d0de5b8e3fb822a0e7b11ffda76b0df2239e54074" && rollup_proof.dig("cargo_source", "vendor_tree_sha256") == "6c270602d180cc46044739ee9970ff400581411ebb6504b00041ac0134e3521b"
      errors << "openchamber: rollup proof build contract mismatch" unless rollup_proof.dig("build", "network_isolated") == true && rollup_proof.dig("build", "jobs") == 4 && rollup_proof.dig("build", "source_date_epoch") == 1771744381 && rollup_proof.dig("build", "first_sha256") == rollup_proof.dig("build", "second_sha256") && rollup_proof.dig("build", "rpath_or_runpath") == false && rollup_proof.dig("build", "napi_register_module_v1_exported") == true
      errors << "openchamber: rollup runtime proof is incomplete" unless rollup_proof.dig("published_companion", "retained_in_package") == false && rollup_proof.dig("cargo_source", "immutable_delivery_verified") == false && rollup_proof.dig("validation", "cargo_workspace_tests_passed") == true && rollup_proof.dig("validation", "direct_napi_smoke_verified") == true && rollup_proof.dig("validation", "npm_wrapper_bundle_verified") == true && rollup_proof.dig("validation", "final_openchamber_inclusion_verified") == false
      errors << "openchamber: rollup review state mismatch" unless rollup.dig("decision", "reproducible_build_verified") == true
    else
      errors << "openchamber: rollup proof is unavailable"
    end

    tailwind = components.find { |component| component["package"] == "@tailwindcss/oxide-linux-x64-gnu@4.2.1" }
    tailwind_filename = dependencies.dig("source_closure_files", "tailwind_oxide_proof")
    tailwind_path = tailwind_filename.is_a?(String) && File.join(package.directory, tailwind_filename)
    if tailwind_path && File.file?(tailwind_path)
      tailwind_sha256 = Digest::SHA256.file(tailwind_path).hexdigest
      tailwind_proof = JSON.parse(File.read(tailwind_path))
      errors << "openchamber: tailwind oxide proof path mismatch" unless tailwind&.dig("proof", "path") == tailwind_filename && review.dig("receipts", "tailwind_oxide_proof", "path") == tailwind_filename
      errors << "openchamber: tailwind oxide proof SHA-256 mismatch" unless review.dig("receipts", "tailwind_oxide_proof", "sha256") == tailwind_sha256
      errors << "openchamber: tailwind oxide proof identity mismatch" unless tailwind_proof["schema"] == "openchamber-tailwind-oxide-proof/v1" && tailwind_proof["package"] == "@tailwindcss/oxide-linux-x64-gnu@4.2.1" && tailwind_proof.dig("source", "upstream_tag_commit") == "1dce64ee7ec2e414c845b4e268ac3b9b89aaf0c8"
      errors << "openchamber: tailwind oxide proof source mismatch" unless tailwind_proof.dig("source", "archive_sha256") == "c497193417a98a2de5a791cce64c0b00f6b561066a0e2734bdb584096de44c80" && tailwind_proof.dig("cargo_source", "lock_sha256") == "e4fbd56ae4218d5a731a635a038691aa8c0e46dabb91e35ac64ac1275a65fa3d" && tailwind_proof.dig("cargo_source", "vendor_tree_sha256") == "4132c430a94ba75baf33bd05c3606156d45eb5e3dcf5cede77c4ce84773e510c"
      errors << "openchamber: tailwind oxide proof build contract mismatch" unless tailwind_proof.dig("build", "network_isolated") == true && tailwind_proof.dig("build", "jobs") == 4 && tailwind_proof.dig("build", "source_date_epoch") == 1771843512 && tailwind_proof.dig("build", "first_sha256") == tailwind_proof.dig("build", "second_sha256") && tailwind_proof.dig("build", "rpath_or_runpath") == false && tailwind_proof.dig("build", "napi_register_module_v1_exported") == true
      errors << "openchamber: tailwind oxide runtime proof is incomplete" unless tailwind_proof.dig("published_companion", "retained_in_package") == false && tailwind_proof.dig("cargo_source", "immutable_delivery_verified") == false && tailwind_proof.dig("validation", "cargo_workspace_tests_passed") == true && tailwind_proof.dig("validation", "npm_wrapper_scanner_verified") == true && tailwind_proof.dig("validation", "final_openchamber_inclusion_verified") == false
      errors << "openchamber: tailwind oxide review state mismatch" unless tailwind.dig("decision", "reproducible_build_verified") == true
    else
      errors << "openchamber: tailwind oxide proof is unavailable"
    end

    lightningcss = components.find { |component| component["package"] == "lightningcss-linux-x64-gnu@1.31.1" }
    lightningcss_filename = dependencies.dig("source_closure_files", "lightningcss_proof")
    lightningcss_path = lightningcss_filename.is_a?(String) && File.join(package.directory, lightningcss_filename)
    if lightningcss_path && File.file?(lightningcss_path)
      lightningcss_sha256 = Digest::SHA256.file(lightningcss_path).hexdigest
      lightningcss_proof = JSON.parse(File.read(lightningcss_path))
      errors << "openchamber: Lightning CSS proof path mismatch" unless lightningcss&.dig("proof", "path") == lightningcss_filename && review.dig("receipts", "lightningcss_proof", "path") == lightningcss_filename
      errors << "openchamber: Lightning CSS proof SHA-256 mismatch" unless review.dig("receipts", "lightningcss_proof", "sha256") == lightningcss_sha256
      errors << "openchamber: Lightning CSS proof identity mismatch" unless lightningcss_proof["schema"] == "openchamber-lightningcss-proof/v1" && lightningcss_proof["package"] == "lightningcss-linux-x64-gnu@1.31.1"
      errors << "openchamber: Lightning CSS published payload mismatch" unless lightningcss_proof.dig("published_packages", "wrapper", "archive_sha256") == "253cad9321f18c817c7d3e06415cb60bf88e3c01ac08920652b3a1b2c6cabd52" && lightningcss_proof.dig("published_packages", "platform_companion", "archive_sha256") == "bd064ad4edd3f7308dca3216b14a0ad57115547e4499e3c46e0744335de6b335" && lightningcss_proof.dig("published_packages", "platform_companion", "native_sha256") == "751bc92429f1f1c70e330c01dcdc274d478def6f9a93ae0b14a98b6919f171a4"
      errors << "openchamber: Lightning CSS source mismatch" unless lightningcss_proof.dig("source", "tag") == "v1.31.1" && lightningcss_proof.dig("source", "commit") == "6993d9f1d3cd69030c5976cd8860361b7679f68d" && lightningcss_proof.dig("source", "archive_sha256") == "5b34735be7aa5bc672382a423b3cf0ddfa0ef54acf3340c9bb35faa0b0d7caa8"
      errors << "openchamber: Lightning CSS build contract mismatch" unless lightningcss_proof.dig("build_contract", "rust_version") == "1.92.0" && lightningcss_proof.dig("build_contract", "cargo_lock_sha256") == "a2b6600e820252af4709d65bd568d4f3dd121cfdc4df82ef9390e13377831b76" && lightningcss_proof.dig("build_contract", "napi_cli_version") == "2.18.4"
      errors << "openchamber: Lightning CSS legal hold mismatch" unless lightningcss_proof.dig("legal_hold", "crate") == "parcel_sourcemap@2.1.1" && lightningcss_proof.dig("legal_hold", "crate_sha256") == "485b74d7218068b2b7c0e3ff12fbc61ae11d57cb5d8224f525bd304c6be05bbb" && lightningcss_proof.dig("legal_hold", "direct_napi_dependency") == true && lightningcss_proof.dig("legal_hold", "license_payload_complete") == false && lightningcss_proof.dig("legal_hold", "downstream_notice_synthesis_permitted") == false
      errors << "openchamber: Lightning CSS validation state mismatch" unless lightningcss_proof.dig("validation", "exact_source_mapping_verified") == true && lightningcss_proof.dig("validation", "reproducible_build_verified") == false && lightningcss_proof.dig("validation", "license_accounting_verified") == false && lightningcss_proof.dig("validation", "final_openchamber_inclusion_verified") == false
      errors << "openchamber: Lightning CSS review state mismatch" unless lightningcss.dig("decision", "source_mapping_verified") == true && lightningcss.dig("decision", "reproducible_build_verified") == false
    else
      errors << "openchamber: Lightning CSS proof is unavailable"
    end

    sherpa = components.find { |component| component["package"] == "sherpa-onnx-linux-x64@1.13.3" }
    sherpa_filename = dependencies.dig("source_closure_files", "sherpa_onnx_proof")
    sherpa_path = sherpa_filename.is_a?(String) && File.join(package.directory, sherpa_filename)
    if sherpa_path && File.file?(sherpa_path)
      sherpa_sha256 = Digest::SHA256.file(sherpa_path).hexdigest
      sherpa_proof = JSON.parse(File.read(sherpa_path))
      errors << "openchamber: sherpa-onnx proof path mismatch" unless sherpa&.dig("proof", "path") == sherpa_filename && review.dig("receipts", "sherpa_onnx_proof", "path") == sherpa_filename
      errors << "openchamber: sherpa-onnx proof SHA-256 mismatch" unless review.dig("receipts", "sherpa_onnx_proof", "sha256") == sherpa_sha256
      errors << "openchamber: sherpa-onnx proof identity mismatch" unless sherpa_proof["schema"] == "openchamber-sherpa-onnx-proof/v1" && sherpa_proof["package"] == "sherpa-onnx-linux-x64@1.13.3"
      errors << "openchamber: sherpa-onnx wrapper selection mismatch" unless sherpa_proof.dig("published_packages", "wrapper", "package") == "sherpa-onnx-node@1.12.28" && sherpa_proof.dig("published_packages", "wrapper", "platform_requirement") == "^1.12.28" && sherpa_proof.dig("published_packages", "wrapper", "selected_platform_version_satisfies_requirement") == true
      errors << "openchamber: sherpa-onnx source mismatch" unless sherpa_proof.dig("release_source", "tag_commit") == "330609dab49be6ee8b30702918ca7abbbad1286a" && sherpa_proof.dig("release_source", "published_payload_commit") == "6206c9c0e96f54c9f04afe6c740e0dcafcf4d20a" && sherpa_proof.dig("release_source", "published_payload_commit_parent") == "330609dab49be6ee8b30702918ca7abbbad1286a" && sherpa_proof.dig("release_source", "published_payload_archive_sha256") == "b2a4d7c50afa80bb577ce2e06d171111c172a031e90cefdad13ff157a9d37213"
      errors << "openchamber: sherpa-onnx payload mismatch" unless sherpa_proof.dig("published_packages", "platform", "archive_sha256") == "6e2ab763715980c59eaac602165ce1aa00e33449e6c811fae6610e0d801a4f3c" && sherpa_proof.dig("published_packages", "platform", "payloads").map { |payload| payload["sha256"] } == %w[88468d42d3381c18a7bd3f99a01f07293ff8c9e38f71fd5bcc5fa08c101d31bf b7dae68f459d74f3fbe7584b6f93e28d669347f0116bd67e42737d50fb514f1b 562726a7c9e46a6259a5ec0e157fc218747417c08ba0eb2b3af4ad22f1c59d07 91f0c16a56578779167e02090d086c968df25bd33b254c534a694e30e5194acf]
      errors << "openchamber: sherpa-onnx blocker mismatch" unless sherpa_proof.dig("blockers", "onnxruntime_version") == "1.24.4" && sherpa_proof.dig("blockers", "precompiled_onnxruntime_consumed") == true && sherpa_proof.dig("blockers", "node_lockfile_present") == false && sherpa_proof.dig("blockers", "node_build_dependencies_exactly_pinned") == false && sherpa_proof.dig("blockers", "absolute_runner_runpath_present") == true && sherpa_proof.dig("blockers", "source_compliant_onnxruntime_provider_verified") == false
      errors << "openchamber: sherpa-onnx validation state mismatch" unless sherpa_proof.dig("validation", "exact_source_mapping_verified") == true && sherpa_proof.dig("validation", "reproducible_build_verified") == false && sherpa_proof.dig("validation", "published_payloads_accepted") == false && sherpa_proof.dig("validation", "final_openchamber_inclusion_verified") == false
      errors << "openchamber: sherpa-onnx review state mismatch" unless sherpa.dig("decision", "source_mapping_verified") == true && sherpa.dig("decision", "reproducible_build_verified") == false
    else
      errors << "openchamber: sherpa-onnx proof is unavailable"
    end

    source_map = components.find { |component| component["package"] == "source-map@0.8.0-beta.0" }
    source_map_filename = dependencies.dig("source_closure_files", "source_map_wasm_proof")
    source_map_path = source_map_filename.is_a?(String) && File.join(package.directory, source_map_filename)
    if source_map_path && File.file?(source_map_path)
      source_map_sha256 = Digest::SHA256.file(source_map_path).hexdigest
      source_map_proof = JSON.parse(File.read(source_map_path))
      errors << "openchamber: source-map WASM proof path mismatch" unless source_map&.dig("proof", "path") == source_map_filename && review.dig("receipts", "source_map_wasm_proof", "path") == source_map_filename
      errors << "openchamber: source-map WASM proof SHA-256 mismatch" unless review.dig("receipts", "source_map_wasm_proof", "sha256") == source_map_sha256
      errors << "openchamber: source-map WASM proof identity mismatch" unless source_map_proof["schema"] == "openchamber-source-map-wasm-proof/v1" && source_map_proof["package"] == "source-map@0.8.0-beta.0"
      errors << "openchamber: source-map WASM published payload mismatch" unless source_map_proof.dig("published_package", "archive_sha256") == "59228a9f94352af91e4600bd45c8b293979a87508c7e99c79d1f660e35b17295" && source_map_proof.dig("published_package", "wasm_sha256") == "be2dc7da3885e55013c8da58d7ba356705d932459db94ada37d5de2fa8733cfe"
      errors << "openchamber: source-map WASM release source mismatch" unless source_map_proof.dig("source_map_source", "upstream_tag_commit") == "11cecea2b64ead3f93cde37a5789dc7683685a7c" && source_map_proof.dig("source_map_source", "archive_sha256") == "c977525ce9d07d75d341613fbd476e8d405c0c1553fd7acf08f8c27674b9967e" && source_map_proof.dig("source_map_source", "tracked_tree_sha256") == "217ea42685f48f05fb2c151bda14ac85293226ac2567f09809cf5918a6493afb" && source_map_proof.dig("source_map_source", "wasm_sha256") == source_map_proof.dig("published_package", "wasm_sha256")
      errors << "openchamber: source-map WASM correspondence mismatch" unless source_map_proof.dig("source_correspondence", "source_map_update_commit") == "4ade41fd99eaea69f3f3bef7e7857a29da02a9d4" && source_map_proof.dig("source_correspondence", "subordinate_version") == "0.5.0" && source_map_proof.dig("source_correspondence", "subordinate_commit") == "12a2f8e5fb87a582abb05b3eda6740cf5778e503" && source_map_proof.dig("source_correspondence", "subordinate_archive_sha256") == "a65c24425fa2f45961ea7bc8d8fa5486d2684a27173d0372a27767e2fe522d11" && source_map_proof.dig("source_correspondence", "subordinate_tree_sha256") == "6bdb022b469e6f0d90f7e8e9c0da926db5389b1e41067c65ab575a3d00ac14a5"
      errors << "openchamber: source-map WASM historical build contract mismatch" unless source_map_proof.dig("historical_build_contract", "rust_target") == "wasm32-unknown-unknown" && source_map_proof.dig("historical_build_contract", "rust_toolchain_version_pinned") == false && source_map_proof.dig("historical_build_contract", "cargo_lock_present") == false && source_map_proof.dig("historical_build_contract", "post_processor_versions_pinned") == false && source_map_proof.dig("historical_build_contract", "generated_wasm_reproduced") == false
      errors << "openchamber: source-map WASM validation state mismatch" unless source_map_proof.dig("validation", "npm_and_tag_wasm_identical") == true && source_map_proof.dig("validation", "exact_source_mapping_verified") == true && source_map_proof.dig("validation", "reproducible_build_verified") == false && source_map_proof.dig("validation", "final_openchamber_inclusion_verified") == false
      errors << "openchamber: source-map WASM review state mismatch" unless source_map.dig("decision", "source_mapping_verified") == true && source_map.dig("decision", "reproducible_build_verified") == false
    else
      errors << "openchamber: source-map WASM proof is unavailable"
    end

    shiki = components.find { |component| component["package"] == "shiki@3.23.0" }
    shiki_filename = dependencies.dig("source_closure_files", "shiki_wasm_proof")
    shiki_path = shiki_filename.is_a?(String) && File.join(package.directory, shiki_filename)
    if shiki_path && File.file?(shiki_path)
      shiki_sha256 = Digest::SHA256.file(shiki_path).hexdigest
      shiki_proof = JSON.parse(File.read(shiki_path))
      errors << "openchamber: Shiki WASM proof path mismatch" unless shiki&.dig("proof", "path") == shiki_filename && review.dig("receipts", "shiki_wasm_proof", "path") == shiki_filename
      errors << "openchamber: Shiki WASM proof SHA-256 mismatch" unless review.dig("receipts", "shiki_wasm_proof", "sha256") == shiki_sha256
      errors << "openchamber: Shiki WASM proof identity mismatch" unless shiki_proof["schema"] == "openchamber-shiki-wasm-proof/v1" && shiki_proof["package"] == "shiki@3.23.0"
      errors << "openchamber: Shiki WASM release source mismatch" unless shiki_proof.dig("shiki_source", "commit") == "2b33c0cdcedf3e00f65cac7228c62f7f1bcbf86a" && shiki_proof.dig("shiki_source", "archive_sha256") == "f3e33e4f867d5e1983466d2ec7bdb1933bb8f2ced522691b2775b78cbac67ae2" && shiki_proof.dig("shiki_source", "inlined_dependency") == "vscode-oniguruma@1.7.0"
      errors << "openchamber: Shiki WASM subordinate source mismatch" unless shiki_proof.dig("subordinate_source", "commit") == "716aeaa229e4ae2e3b0057377b55743e9a3e995b" && shiki_proof.dig("subordinate_source", "archive_sha256") == "0e472a9d670d3301024435c04c09870bce2779c22a099185c2988d99b1cea190" && shiki_proof.dig("subordinate_source", "tracked_wasm_sha256") == "fd885c2d12e5951e59d761ebd4a006e06254b1491fd6f530c92b69fb4d8d77d9" && shiki_proof.dig("subordinate_source", "oniguruma_submodule_commit") == "08d36110c5670c815ad6d6f969e578049d209080" && shiki_proof.dig("subordinate_source", "emscripten_version") == "3.1.21"
      errors << "openchamber: Shiki WASM validation state mismatch" unless shiki_proof.dig("published_package", "wasm_sha256") == shiki_proof.dig("subordinate_source", "tracked_wasm_sha256") && shiki_proof.dig("validation", "shiki_copy_contract_verified") == true && shiki_proof.dig("validation", "exact_source_mapping_verified") == true && shiki_proof.dig("validation", "reproducible_build_verified") == false && shiki_proof.dig("validation", "final_openchamber_inclusion_verified") == false
      errors << "openchamber: Shiki WASM review state mismatch" unless shiki.dig("decision", "source_mapping_verified") == true && shiki.dig("decision", "reproducible_build_verified") == false
    else
      errors << "openchamber: Shiki WASM proof is unavailable"
    end

    ghostty = components.find { |component| component["package"] == "ghostty-web@0.4.0" }
    ghostty_filename = dependencies.dig("source_closure_files", "ghostty_wasm_proof")
    ghostty_path = ghostty_filename.is_a?(String) && File.join(package.directory, ghostty_filename)
    if ghostty_path && File.file?(ghostty_path)
      ghostty_sha256 = Digest::SHA256.file(ghostty_path).hexdigest
      ghostty_proof = JSON.parse(File.read(ghostty_path))
      errors << "openchamber: Ghostty WASM proof path mismatch" unless ghostty&.dig("proof", "path") == ghostty_filename && review.dig("receipts", "ghostty_wasm_proof", "path") == ghostty_filename
      errors << "openchamber: Ghostty WASM proof SHA-256 mismatch" unless review.dig("receipts", "ghostty_wasm_proof", "sha256") == ghostty_sha256
      errors << "openchamber: Ghostty WASM proof identity mismatch" unless ghostty_proof["schema"] == "openchamber-ghostty-wasm-proof/v1" && ghostty_proof["package"] == "ghostty-web@0.4.0"
      errors << "openchamber: Ghostty WASM source mismatch" unless ghostty_proof.dig("ghostty_web_source", "commit") == "9e4e126d89ac3537d2b2ebec075849851566de9f" && ghostty_proof.dig("ghostty_web_source", "archive_sha256") == "67c1f752cab0e100de31878bbcede03c898d831eed6cb88ea0f2bac68015e161" && ghostty_proof.dig("ghostty_web_source", "patch_sha256") == "ae5b1b034143885e130e5b795209c5bb52ce5987a62240bab1ac5ff4f99f430a" && ghostty_proof.dig("subordinate_source", "commit") == "5714ed07a1012573261b7b7e3ed2add9c1504496" && ghostty_proof.dig("subordinate_source", "archive_sha256") == "55cee28558945de6e984bc183cd51f28eefdbf805544da2e70d4635476178790"
      errors << "openchamber: Ghostty WASM toolchain mismatch" unless ghostty_proof.dig("toolchain", "zig_version") == "0.15.2" && ghostty_proof.dig("toolchain", "archive_sha256") == "02aa270f183da276e5b5920b1dac44a63f1a49e55050ebde3aecc9eb82f93239"
      errors << "openchamber: Ghostty WASM build mismatch" unless ghostty_proof.dig("build", "target") == "wasm32-freestanding" && ghostty_proof.dig("build", "optimize") == "ReleaseSmall" && ghostty_proof.dig("build", "jobs") == 4 && ghostty_proof.dig("build", "first_build_network_isolated") == true && ghostty_proof.dig("build", "second_build_network_isolated") == true && ghostty_proof.dig("build", "first_sha256") == ghostty_proof.dig("build", "second_sha256") && ghostty_proof.dig("build", "first_sha256") == ghostty_proof.dig("published_package", "wasm_sha256")
      errors << "openchamber: Ghostty WASM runtime proof is incomplete" unless ghostty_proof.dig("runtime_smoke", "wrapper_sha256") == "078b3fe37e4ef469d3f3d7772ee263070f8613e5a6f5ff305c85778907f45e72" && %w[network_isolated webassembly_compile_verified terminal_create_verified terminal_write_readback_verified cursor_state_verified].all? { |key| ghostty_proof.dig("runtime_smoke", key) == true } && ghostty_proof.dig("validation", "exact_source_mapping_verified") == true && ghostty_proof.dig("validation", "two_builds_byte_identical") == true && ghostty_proof.dig("validation", "published_wasm_reproduced") == true && ghostty_proof.dig("validation", "npm_wrapper_runtime_verified") == true && ghostty_proof.dig("validation", "dependency_cache_immutable_delivery_verified") == false && ghostty_proof.dig("validation", "final_openchamber_inclusion_verified") == false
      errors << "openchamber: Ghostty WASM review state mismatch" unless ghostty.dig("decision", "source_mapping_verified") == true && ghostty.dig("decision", "reproducible_build_verified") == true
    else
      errors << "openchamber: Ghostty WASM proof is unavailable"
    end

    better = components.find { |component| component["package"] == "better-sqlite3@12.10.0" }
    proof_filename = dependencies.dig("source_closure_files", "better_sqlite3_proof")
    proof_path = proof_filename.is_a?(String) && File.join(package.directory, proof_filename)
    if proof_path && File.file?(proof_path)
      proof_sha256 = Digest::SHA256.file(proof_path).hexdigest
      proof = JSON.parse(File.read(proof_path))
      errors << "openchamber: better-sqlite3 proof path mismatch" unless better&.dig("proof", "path") == proof_filename && review.dig("receipts", "better_sqlite3_proof", "path") == proof_filename
      errors << "openchamber: better-sqlite3 proof SHA-256 mismatch" unless review.dig("receipts", "better_sqlite3_proof", "sha256") == proof_sha256
      errors << "openchamber: better-sqlite3 proof identity mismatch" unless proof["schema"] == "openchamber-better-sqlite3-proof/v1" && proof["package"] == "better-sqlite3@12.10.0"
      errors << "openchamber: better-sqlite3 patch mismatch" unless proof.dig("patch", "sha256") == Digest::SHA256.file(File.join(package.directory, proof.dig("patch", "path"))).hexdigest
      errors << "openchamber: better-sqlite3 build contract mismatch" unless proof.dig("build", "node_module_abi") == "137" && proof.dig("build", "sqlite_version") == "3.51.2" && proof.dig("build", "system_sqlite") == true && proof.dig("build", "bundled_sqlite_compiled") == false && proof.dig("build", "first_sha256") == proof.dig("build", "second_sha256") && Array(proof.dig("build", "needed")).include?("libsqlite3.so.0")
      errors << "openchamber: better-sqlite3 runtime proof is incomplete" unless proof.fetch("runtime_smoke").values.all?(true) && proof.dig("validation", "two_builds_byte_identical") == true && proof.dig("validation", "final_openchamber_inclusion_verified") == false
      errors << "openchamber: better-sqlite3 review state mismatch" unless better.dig("decision", "reproducible_build_verified") == true
    else
      errors << "openchamber: better-sqlite3 proof is unavailable"
    end

    node_pty = components.find { |component| component["package"] == "node-pty@1.2.0-beta.12" }
    node_pty_filename = dependencies.dig("source_closure_files", "node_pty_proof")
    node_pty_path = node_pty_filename.is_a?(String) && File.join(package.directory, node_pty_filename)
    if node_pty_path && File.file?(node_pty_path)
      node_pty_sha256 = Digest::SHA256.file(node_pty_path).hexdigest
      node_pty_proof = JSON.parse(File.read(node_pty_path))
      errors << "openchamber: node-pty proof path mismatch" unless node_pty&.dig("proof", "path") == node_pty_filename && review.dig("receipts", "node_pty_proof", "path") == node_pty_filename
      errors << "openchamber: node-pty proof SHA-256 mismatch" unless review.dig("receipts", "node_pty_proof", "sha256") == node_pty_sha256
      errors << "openchamber: node-pty proof identity mismatch" unless node_pty_proof["schema"] == "openchamber-node-pty-proof/v1" && node_pty_proof["package"] == "node-pty@1.2.0-beta.12" && node_pty_proof.dig("source", "archive_sha256") == "45a012e37699bb70c9050cbf2e06e71b0b842de4cda58e938e3de973f6d5a36a"
      errors << "openchamber: node-pty build dependency mismatch" unless node_pty_proof.dig("build_dependency", "package") == "node-addon-api@7.1.1" && node_pty_proof.dig("build_dependency", "archive_sha256") == "b10455d15a977c0cd17a1cb0eb679e03d939f8ef8d4302eb33e1f78dacc71f82"
      errors << "openchamber: node-pty build contract mismatch" unless node_pty_proof.dig("build", "node_module_abi") == "137" && node_pty_proof.dig("build", "lifecycle_scripts_executed") == false && node_pty_proof.dig("build", "prebuild_selection_executed") == false && node_pty_proof.dig("build", "source_patch_required") == false && node_pty_proof.dig("build", "first_sha256") == node_pty_proof.dig("build", "second_sha256") && node_pty_proof.dig("build", "rpath_or_runpath") == false
      errors << "openchamber: node-pty runtime proof is incomplete" unless node_pty_proof.fetch("runtime_smoke").values.all?(true) && node_pty_proof.dig("validation", "published_prebuilds_excluded") == true && node_pty_proof.dig("validation", "final_openchamber_inclusion_verified") == false
      errors << "openchamber: node-pty review state mismatch" unless node_pty.dig("decision", "reproducible_build_verified") == true
    else
      errors << "openchamber: node-pty proof is unavailable"
    end

    expected_scope = {
      "component_identities" => sources.length,
      "native_source_records" => sources.count { |source| Array(source["native_source_paths"]).any? },
      "native_payload_records" => sources.count { |source| Array(source["native_payloads"]).any? },
      "native_payloads" => sources.sum { |source| Array(source["native_payloads"]).length },
      "wasm_source_records" => sources.count { |source| Array(source["wasm_payloads"]).any? },
      "wasm_payloads" => sources.sum { |source| Array(source["wasm_payloads"]).length },
      "executable_source_records" => sources.count { |source| Array(source["executable_payloads"]).any? },
      "executable_payloads" => sources.sum { |source| Array(source["executable_payloads"]).length }
    }
    expected_scope.each { |key, value| errors << "openchamber: native review scope #{key} mismatch" unless review.dig("scope", key) == value }
    expected_status = {
      "component_identities_classified" => sources.length,
      "target_excluded_sources" => 3,
      "platform_companions" => 5,
      "same_archive_rebuilds" => 2,
      "generated_wasm_sources" => 3,
      "build_support_sources" => 1,
      "retained_prebuilt_payloads" => 0,
      "source_mappings_verified" => components.count { |component| component.dig("decision", "source_mapping_verified") == true },
      "source_mappings_unresolved" => components.count { |component| component.dig("decision", "source_mapping_verified") == false },
      "reproducible_builds_completed" => components.count { |component| component.dig("decision", "reproducible_build_verified") == true }
    }
    expected_status.each do |key, value|
      errors << "openchamber: native review status #{key} mismatch" unless review.dig("status", key) == value && metadata[key] == value
    end
    %w[native_sources_verified wasm_sources_verified reproducible_builds_verified].each do |flag|
      errors << "openchamber: native review overclaims #{flag}" unless review.dig("status", flag) == false && metadata[flag] == false
    end
    %w[exact_source_audit_coverage exact_path_set_digests_verified lifecycle_scripts_accounted_for platform_companion_mappings_recorded target_exclusions_recorded raw_source_audit_unchanged].each do |flag|
      errors << "openchamber: native review validation #{flag} is not true" unless review.dig("validation", flag) == true
    end

    source_policy = package.data.fetch("source_policy")
    errors << "openchamber: package native review path mismatch" unless source_policy["native_review"] == filename
    errors << "openchamber: package native review SHA-256 mismatch" unless source_policy["native_review_sha256"] == actual_sha256
    errors << "openchamber: package native component count mismatch" unless source_policy["native_components_classified"] == sources.length
    errors << "openchamber: package unresolved native mapping count mismatch" unless source_policy["native_source_mappings_unresolved"] == expected_status["source_mappings_unresolved"]
    errors << "openchamber: package reproducible native build count mismatch" unless source_policy["native_reproducible_builds_completed"] == expected_status["reproducible_builds_completed"]
    errors
  rescue JSON::ParserError, KeyError, TypeError => e
    ["openchamber: invalid native review evidence: #{e.message}"]
  end

  def validate_rust_v8_evidence(package, dependencies, spec)
    return [] unless package.name == "rust-v8"

    errors = []
    version = package.upstream.fetch("current_version").to_s
    source_name = dependencies.dig("source_closure", "receipt")
    license_name = dependencies.dig("license_audit", "receipt")
    archive_graph_name = dependencies.dig("archive_graph", "receipt")
    fedora_license_name = dependencies.dig("fedora_license_evidence", "receipt")
    dynamic_linking_name = dependencies.dig("dynamic_linking", "receipt")
    source_filter_name = dependencies.dig("source_closure", "source_filter_receipt")
    static_license_name = dependencies.dig("static_license", "receipt")
    source_path = source_name.is_a?(String) && File.join(package.directory, source_name)
    license_path = license_name.is_a?(String) && File.join(package.directory, license_name)
    archive_graph_path = archive_graph_name.is_a?(String) && File.join(package.directory, archive_graph_name)
    fedora_license_path = fedora_license_name.is_a?(String) && File.join(package.directory, fedora_license_name)
    dynamic_linking_path = dynamic_linking_name.is_a?(String) && File.join(package.directory, dynamic_linking_name)
    source_filter_path = source_filter_name.is_a?(String) && File.join(package.directory, source_filter_name)
    static_license_path = static_license_name.is_a?(String) && File.join(package.directory, static_license_name)
    unless source_path && File.file?(source_path)
      return ["rust-v8: recursive-source receipt is missing"]
    end
    unless license_path && File.file?(license_path)
      return ["rust-v8: license-audit receipt is missing"]
    end
    unless archive_graph_path && File.file?(archive_graph_path)
      return ["rust-v8: archive-graph witness is missing"]
    end
    unless fedora_license_path && File.file?(fedora_license_path)
      return ["rust-v8: Fedora license-evidence receipt is missing"]
    end
    unless dynamic_linking_path && File.file?(dynamic_linking_path)
      return ["rust-v8: dynamic-linking receipt is missing"]
    end
    unless source_filter_path && File.file?(source_filter_path)
      return ["rust-v8: source-filter receipt is missing"]
    end
    unless static_license_path && File.file?(static_license_path)
      return ["rust-v8: static-license receipt is missing"]
    end

    source_sha256 = Digest::SHA256.file(source_path).hexdigest
    license_sha256 = Digest::SHA256.file(license_path).hexdigest
    archive_graph_sha256 = Digest::SHA256.file(archive_graph_path).hexdigest
    fedora_license_sha256 = Digest::SHA256.file(fedora_license_path).hexdigest
    dynamic_linking_sha256 = Digest::SHA256.file(dynamic_linking_path).hexdigest
    source_filter_sha256 = Digest::SHA256.file(source_filter_path).hexdigest
    static_license_sha256 = Digest::SHA256.file(static_license_path).hexdigest
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
    expected_archive_graph_hashes = [
      dependencies.dig("archive_graph", "receipt_sha256"),
      package.data.dig("archive_graph", "receipt_sha256")
    ]
    unless expected_archive_graph_hashes.all? { |value| value == archive_graph_sha256 }
      errors << "rust-v8: archive-graph witness SHA-256 does not match metadata"
    end
    expected_fedora_license_hashes = [
      dependencies.dig("fedora_license_evidence", "receipt_sha256"),
      package.data.dig("fedora_license_evidence", "receipt_sha256")
    ]
    unless expected_fedora_license_hashes.all? { |value| value == fedora_license_sha256 }
      errors << "rust-v8: Fedora license-evidence receipt SHA-256 does not match metadata"
    end
    expected_dynamic_linking_hashes = [
      dependencies.dig("dynamic_linking", "receipt_sha256"),
      package.data.dig("dynamic_linking", "receipt_sha256")
    ]
    unless expected_dynamic_linking_hashes.all? { |value| value == dynamic_linking_sha256 }
      errors << "rust-v8: dynamic-linking receipt SHA-256 does not match metadata"
    end
    expected_source_filter_hashes = [
      dependencies.dig("source_closure", "source_filter_receipt_sha256"),
      package.data.dig("source_policy", "source_filter_receipt_sha256")
    ]
    unless expected_source_filter_hashes.all? { |value| value == source_filter_sha256 }
      errors << "rust-v8: source-filter receipt SHA-256 does not match metadata"
    end
    expected_static_license_hashes = [
      dependencies.dig("static_license", "receipt_sha256"),
      package.data.dig("static_license", "receipt_sha256")
    ]
    unless expected_static_license_hashes.all? { |value| value == static_license_sha256 }
      errors << "rust-v8: static-license receipt SHA-256 does not match metadata"
    end
    errors << "rust-v8: spec recursive-source SHA-256 does not match" unless spec[/^%global closure_sha256\s+(\h{64})$/, 1] == source_sha256
    errors << "rust-v8: spec license-audit SHA-256 does not match" unless spec[/^%global license_audit_sha256\s+(\h{64})$/, 1] == license_sha256
    errors << "rust-v8: spec archive-graph SHA-256 does not match" unless spec[/^%global archive_graph_sha256\s+(\h{64})$/, 1] == archive_graph_sha256
    errors << "rust-v8: spec Fedora license-evidence SHA-256 does not match" unless spec[/^%global fedora_license_evidence_sha256\s+(\h{64})$/, 1] == fedora_license_sha256
    errors << "rust-v8: spec dynamic-linking SHA-256 does not match" unless spec[/^%global dynamic_linking_sha256\s+(\h{64})$/, 1] == dynamic_linking_sha256
    errors << "rust-v8: spec source-filter SHA-256 does not match" unless spec[/^%global source_filter_sha256\s+(\h{64})$/, 1] == source_filter_sha256
    errors << "rust-v8: spec static-license SHA-256 does not match" unless spec[/^%global static_license_sha256\s+(\h{64})$/, 1] == static_license_sha256

    source = JSON.parse(File.read(source_path))
    errors << "rust-v8: recursive-source schema is invalid" unless source["schema"] == "rust-v8-source-closure/v4"
    errors << "rust-v8: recursive-source release does not match" unless source.dig("release", "version").to_s == version
    closure_scope = source.fetch("closure_scope", {})
    unless closure_scope["kind"] == "git-submodule-closure-with-reviewed-source-filter"
      errors << "rust-v8: source receipt does not identify the reviewed filtered Git submodule closure"
    end
    errors << "rust-v8: source receipt overclaims a full DEPS checkout" unless closure_scope["full_deps_checkout_claimed"] == false
    unless closure_scope["selected_build_dependency_closure_claimed"] == false
      errors << "rust-v8: source receipt overclaims selected-build dependency closure"
    end
    components = source["components"]
    unless components.is_a?(Array) && components.length == 21
      return errors << "rust-v8: recursive-source receipt must contain 21 components"
    end
    errors << "rust-v8: source receipt Git component count does not match" unless closure_scope["git_components"] == components.length
    errors << "rust-v8: source receipt Git submodule count does not match" unless closure_scope["git_submodules"] == components.length - 1

    paths = components.map { |component| component["path"] }
    errors << "rust-v8: recursive-source component paths are not unique" unless paths.uniq.length == paths.length
    errors << "rust-v8: recursive-source root component is invalid" unless paths.first == "."
    archives = components.filter_map { |component| component["archive"] }
    errors << "rust-v8: recursive-source archive metadata is incomplete" unless archives.length == components.length
    components.each_with_index do |component, index|
      archive = component["archive"] || {}
      filtered_v8 = component["path"] == "v8"
      errors << "rust-v8: component #{component['path']} has invalid RPM source number" unless component["rpm_source"] == index
      errors << "rust-v8: component #{component['path']} has an invalid commit" unless component["commit"].to_s.match?(/\A[0-9a-f]{40}\z/)
      errors << "rust-v8: component #{component['path']} has an invalid tree SHA-256" unless archive["tree_sha256"].to_s.match?(/\A[0-9a-f]{64}\z/)
      errors << "rust-v8: component #{component['path']} requires archive transport identity" unless archive["transport_identity_required"] == false
      unless archive["content_modes_and_symlinks_match_git"] == !filtered_v8 &&
             archive["content_modes_and_symlinks_match_git_except_reviewed_exclusions"] == true
        errors << "rust-v8: component #{component['path']} archive tree verification state is invalid"
      end
      if filtered_v8
        unless archive["generated"] == true && archive["url"].nil? &&
               archive["transport_identity_required"] == false &&
               archive.dig("source_filter", "sha256") == source_filter_sha256
          errors << "rust-v8: generated V8 source metadata is invalid"
        end
      else
        begin
          errors << "rust-v8: component #{component['path']} archive URL must use HTTPS" unless URI(archive["url"]).is_a?(URI::HTTPS)
        rescue URI::InvalidURIError, TypeError
          errors << "rust-v8: component #{component['path']} archive URL is invalid"
        end
      end
    end

    summary = source.fetch("source_summary", {})
    errors << "rust-v8: recursive-source file total does not match" unless summary["archive_files"] == archives.sum { |archive| archive["file_count"] }
    errors << "rust-v8: recursive-source component tree total does not match" unless summary["component_tree_file_records"] == archives.sum { |archive| archive["tree_file_records"] }
    errors << "rust-v8: recursive-source combined tree count does not match" unless source.dig("reconstruction", "file_records") == summary["archive_files"]
    errors << "rust-v8: recursive-source combined tree SHA-256 is invalid" unless source.dig("reconstruction", "tree_sha256").to_s.match?(/\A[0-9a-f]{64}\z/)
    errors << "rust-v8: recursive-source direct-source count does not match" unless summary["direct_public_rpm_sources"] == 20
    errors << "rust-v8: recursive-source generated-source count does not match" unless summary["generated_filtered_rpm_sources"] == 1
    unless source.dig("reconstruction", "content_modes_and_symlinks_match_recursive_git") == false &&
           source.dig("reconstruction", "content_modes_and_symlinks_match_recursive_git_except_reviewed_exclusions") == true
      errors << "rust-v8: recursive-source filtered reconstruction state is invalid"
    end
    %w[
      root_archive_identity_verified
      gitmodules_paths_and_urls_verified
      recursive_component_archives_verified
      recursive_source_tree_reconstructed
      immutable_recursive_rpm_source_verified
      recursive_component_archive_trees_match_git_except_reviewed_exclusions
      recursive_source_tree_matches_git_except_reviewed_exclusions
      reviewed_filtered_git_submodule_closure_verified
    ].each do |flag|
      errors << "rust-v8: recursive-source validation #{flag} is not true" unless source.dig("validation", flag) == true
    end
    %w[
      recursive_component_archive_trees_match_git
      recursive_source_tree_matches_git
      exact_git_submodule_closure_verified
      full_deps_checkout_verified
      selected_build_dependency_closure_verified
    ].each do |flag|
      errors << "rust-v8: recursive-source validation overclaims #{flag}" unless source.dig("validation", flag) == false
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
      expected = archive["generated"] ? archive.fetch("filename") : "#{archive.fetch('url')}#/#{archive.fetch('filename')}"
      errors << "rust-v8: spec Source#{component.fetch('rpm_source')} does not match the receipt" unless spec_sources[component.fetch("rpm_source")] == expected
      extraction = archive.fetch("layout") == "github-wrapper" ? "extract_wrapped" : "extract_flat"
      unless component.fetch("path") == "."
        expected_line = "#{extraction} #{component.fetch('path')} %{SOURCE#{component.fetch('rpm_source')}}"
        errors << "rust-v8: spec extraction does not match #{component.fetch('path')}" unless spec.lines.map(&:strip).include?(expected_line)
      end
    end
    errors << "rust-v8: spec Source21 does not select the recursive-source receipt" unless spec_sources[21] == source_name
    errors << "rust-v8: spec Source22 does not select the license-audit receipt" unless spec_sources[22] == license_name
    errors << "rust-v8: spec Source23 does not select the archive-graph witness" unless spec_sources[23] == archive_graph_name
    errors << "rust-v8: spec Source24 does not select the Fedora license-evidence receipt" unless spec_sources[24] == fedora_license_name
    errors << "rust-v8: spec Source25 does not select the dynamic-linking receipt" unless spec_sources[25] == dynamic_linking_name
    errors << "rust-v8: spec Source26 does not select the source-filter receipt" unless spec_sources[26] == source_filter_name
    errors << "rust-v8: spec Source27 does not select the static-license receipt" unless spec_sources[27] == static_license_name
    errors << "rust-v8: spec Source28 does not select the allocator license" unless spec_sources[28] == "rust-v8-stable-system-allocator-license.txt"
    errors << "rust-v8: spec Source29 does not select the source preparer" unless spec_sources[29] == "prepare-rust-v8-srpm-sources"
    errors << "rust-v8: spec Source30 does not select the package README" unless spec_sources[30] == "README.md"
    unless spec.include?('TMPDIR="%{_tmppath}" ruby "%{SOURCE29}"') &&
           spec.include?('--output "%{SOURCE20}" --receipt "%{SOURCE26}" --check') &&
           spec.include?('--closure "%{SOURCE21}"') &&
           spec.include?('--source "%{SOURCE0}"') && spec.include?('--source "%{SOURCE20}"')
      errors << "rust-v8: spec does not verify the generated V8 source semantically"
    end
    flat_helper = spec[/extract_flat\(\) \{\n(.*?)\n\}/m, 1].to_s
    wrapped_helper = spec[/extract_wrapped\(\) \{\n(.*?)\n\}/m, 1].to_s
    errors << "rust-v8: flat archive extraction helper is invalid" unless flat_helper.include?('tar -xzf "$2" -C "$1" --no-same-owner') && !flat_helper.include?("--strip-components")
    errors << "rust-v8: wrapped archive extraction helper is invalid" unless wrapped_helper.include?('tar -xzf "$2" -C "$1" --no-same-owner --strip-components=1')
    patch_lines = [
      "patch --batch --fuzz=0 -p1 < %{PATCH0}",
      "patch --batch --fuzz=0 -p1 < %{PATCH1}",
      "patch --batch --fuzz=0 -p1 < %{PATCH2}",
      "patch --batch --fuzz=0 -p1 < %{PATCH3}"
    ]
    patch_lines.each do |line|
      errors << "rust-v8: spec does not apply #{line.split.last}" unless spec.lines.map(&:strip).include?(line)
    end
    expected_gn_args = <<~GN.chomp
      is_debug = false
      %ifarch aarch64
      is_clang = true
      %else
      is_clang = false
      %endif
      use_lld = true
      use_custom_libcxx = false
      symbol_level = 1
      line_tables_only = false
      no_inline_line_tables = false
      clang_base_path = "/usr"
      v8_enable_sandbox = false
      v8_enable_pointer_compression = false
      v8_enable_v8_checks = false
      rusty_v8_enable_simdutf = false
      treat_warnings_as_errors = false
      rust_sysroot_absolute = "/usr"
      rust_bindgen_root = "/usr"
      toolchain_supports_rust_thin_lto = false
    GN
    actual_gn_args = spec[/cat > out\/fedora\/args\.gn <<'GN'\n(.*?)\nGN$/m, 1]
    errors << "rust-v8: spec GN arguments do not match the retained graph" unless actual_gn_args == expected_gn_args
    errors << "rust-v8: spec does not require the Fedora Clang compiler" unless spec.lines.map(&:strip).include?("BuildRequires:  clang >= 19")
    errors << "rust-v8: spec does not require the Fedora Clang runtime" unless spec.lines.map(&:strip).include?("BuildRequires:  compiler-rt")
    errors << "rust-v8: spec does not require the LLVM archiver" unless spec.lines.map(&:strip).include?("BuildRequires:  llvm")
    unless spec.lines.map(&:strip).include?('clang_version="$(clang -dumpversion)"') &&
           spec.lines.map(&:strip).include?('clang_version="${clang_version%%%%.*}"') &&
           spec.lines.map(&:strip).include?('printf \'clang_version = "%s"\\n\' "$clang_version" >> out/fedora/args.gn')
      errors << "rust-v8: spec does not bind the buildroot Clang resource version"
    end
    errors << "rust-v8: spec does not select both supported architectures" unless spec.lines.map(&:strip).include?("ExclusiveArch:  x86_64 aarch64")
    errors << "rust-v8: spec does not generate the GN build" unless spec.lines.map(&:strip).include?("gn gen out/fedora")
    errors << "rust-v8: spec does not retain static archive debug sections" unless spec.lines.map(&:strip).include?("%global debug_package %{nil}")
    unless spec.lines.map(&:strip).include?('rustc_version="$(rpm -q --qf \'%{VERSION}-Fedora-%{VERSION}-%{RELEASE}\' rust)"') &&
           spec.lines.map(&:strip).include?('printf \'rustc_version = "%s"\\n\' "$rustc_version" >> out/fedora/args.gn')
      errors << "rust-v8: spec does not bind the buildroot rustc version"
    end
    unless spec.lines.map(&:strip).include?("%{__ninja} -C out/fedora -j%{_smp_build_ncpus} obj/librusty_v8.a")
      errors << "rust-v8: spec does not build the exact Rusty V8 target"
    end
    errors << "rust-v8: spec retains a pre-build stop" if spec.lines.map(&:strip).include?("exit 1")
    unless spec.include?('python3 - "%{SOURCE23}" "%{_arch}"') &&
           spec.include?('["ninja", "-C", "out/fedora", "-t", "query", "obj/librusty_v8.a"]') &&
           spec.include?('expected = receipt["architecture_expectations"][sys.argv[2]]') &&
           spec.include?('lines_sha256(objects) == expected["object_input_paths_sha256"]') &&
           spec.include?('lines_sha256(rlibs) == expected["implicit_rust_rlib_paths_sha256"]') &&
           spec.include?('lines_sha256(members) == expected["member_names_sha256"]') &&
           spec.include?('sorted(members) == sorted(os.path.basename(path) for path in objects)')
      errors << "rust-v8: spec does not verify the production archive graph"
    end

    source_filter = JSON.parse(File.read(source_filter_path))
    unless source_filter["schema"] == "rust-v8-source-filter/v3" && source_filter["release"].to_s == version
      errors << "rust-v8: source-filter receipt identity is invalid"
    end
    expected_filtered_paths = %w[
      third_party/siphash/LICENSE
      third_party/siphash/halfsiphash.cc
      third_party/siphash/halfsiphash.h
    ]
    errors << "rust-v8: source-filter exclusions do not match" unless source_filter.fetch("excluded_paths", []).map { |record| record["path"] } == expected_filtered_paths
    filtered_component = components.find { |component| component["path"] == "v8" }
    unless source_filter["output"] == filtered_component&.dig("archive")&.slice("filename", "archive_root", "tree_file_records", "tree_sha256")
      errors << "rust-v8: source-filter output does not match the generated V8 source"
    end
    if source_filter.fetch("output", {}).key?("bytes") || source_filter.fetch("output", {}).key?("sha256") ||
       source_filter.dig("upstream", "transport_identity_required") != false ||
       source_filter.dig("validation", "generated_archive_transport_identity_required") != false
      errors << "rust-v8: source-filter receipt requires generated transport identity"
    end
    source_preparer_path = File.expand_path("../../scripts/prepare-rust-v8-srpm-sources", package.directory)
    source_preparer_sha256 = if File.file?(source_preparer_path)
                               Digest::SHA256.file(source_preparer_path).hexdigest
                             else
                               spec[/^%global source_preparer_sha256\s+(\h{64})$/, 1]
                             end
    unless source_filter.dig("generator", "path") == "prepare-rust-v8-srpm-sources" &&
           source_filter.dig("generator", "sha256") == source_preparer_sha256
      errors << "rust-v8: source-filter generator identity does not match"
    end
    errors << "rust-v8: spec source-preparer SHA-256 does not match" unless spec[/^%global source_preparer_sha256\s+(\h{64})$/, 1] == source_preparer_sha256
    errors << "rust-v8: source-filter validation does not reject CC0 executable source" unless source_filter.dig("validation", "cc0_executable_source_present") == false

    archive_graph = JSON.parse(File.read(archive_graph_path))
    errors << "rust-v8: archive-graph schema is invalid" unless archive_graph["schema"] == "rust-v8-archive-graph-witness/v2"
    errors << "rust-v8: archive-graph release does not match" unless archive_graph["release"].to_s == version
    source_reference = archive_graph.fetch("source_closure_reference", {})
    unless source_reference["path"] == source_name && source_reference["sha256"] == source_sha256
      errors << "rust-v8: archive-graph source-closure reference does not match"
    end
    unless source_reference["provenance_verified"] == false
      errors << "rust-v8: archive-graph source reference overclaims provenance"
    end

    static_license = JSON.parse(File.read(static_license_path))
    errors << "rust-v8: static-license schema is invalid" unless static_license["schema"] == "rust-v8-static-license/v1"
    errors << "rust-v8: static-license release does not match" unless static_license["release"].to_s == version
    unless static_license.dig("source_closure_reference", "path") == source_name &&
           static_license.dig("source_closure_reference", "sha256") == source_sha256 &&
           static_license.dig("archive_graph_reference", "path") == archive_graph_name &&
           static_license.dig("archive_graph_reference", "sha256") == archive_graph_sha256 &&
           static_license.dig("source_filter_reference", "path") == source_filter_name &&
           static_license.dig("source_filter_reference", "sha256") == source_filter_sha256
      errors << "rust-v8: static-license receipt references do not match"
    end
    expected_static_expression = "Apache-2.0 AND BSD-2-Clause AND BSD-3-Clause AND BSD-Protection AND LicenseRef-Fedora-Public-Domain AND LicenseRef-Fedora-UltraPermissive AND MIT AND NAIST-2003 AND Python-2.0.1 AND Unicode-3.0 AND Unicode-DFS-2016 AND Unlicense AND (Apache-2.0 OR BSL-1.0 OR MIT) AND (Apache-2.0 WITH LLVM-exception OR BSL-1.0)"
    errors << "rust-v8: static-license expression does not match" unless static_license.dig("static_archive", "expression") == expected_static_expression
    errors << "rust-v8: spec License expression does not match" unless spec[/^License:\s+(.+)$/, 1] == expected_static_expression
    static_components = Array(static_license.dig("static_archive", "components"))
    static_texts = Array(static_license.dig("static_archive", "required_license_texts"))
    errors << "rust-v8: static-license component count does not match" unless static_components.length == 17
    errors << "rust-v8: static-license text count does not match" unless static_texts.length == 24
    errors << "rust-v8: static-license installed filenames are duplicated" unless static_texts.map { |record| record["install_name"] }.uniq.length == static_texts.length
    static_texts.each do |record|
      errors << "rust-v8: static-license text SHA-256 is invalid for #{record['path']}" unless record["sha256"].to_s.match?(/\A[0-9a-f]{64}\z/)
    end
    expected_static_metadata = {
      "receipt" => static_license_name,
      "receipt_sha256" => static_license_sha256,
      "expression" => expected_static_expression,
      "selected_archive_objects" => 1_795,
      "required_license_texts" => 24,
      "implicit_rust_rlibs" => 31,
      "implicit_rust_rlibs_embedded" => false,
      "fedora_allowed_spdx_verified" => true,
      "required_license_texts_verified" => true,
      "prototype_static_archive_license_complete" => true,
      "production_static_archive_license_complete" => false
    }
    errors << "rust-v8: package static-license metadata does not match" unless package.data["static_license"] == expected_static_metadata
    errors << "rust-v8: dependency static-license metadata does not match" unless dependencies["static_license"] == expected_static_metadata
    %w[
      selected_archive_graph_bound
      selected_component_evidence_verified
      required_license_texts_verified
      fedora_allowed_spdx_verified
      reviewed_siphash_exclusion_verified
      prototype_static_archive_license_complete
      nonembedded_rust_rlibs_excluded
      system_library_texts_excluded
    ].each do |flag|
      errors << "rust-v8: static-license validation #{flag} is not true" unless static_license.dig("validation", flag) == true
    end
    unless static_license.dig("validation", "production_static_archive_license_complete") == false
      errors << "rust-v8: static-license receipt overclaims production closure"
    end
    errors << "rust-v8: spec does not install the static license map" unless spec.include?('receipt["static_archive"]["required_license_texts"]')
    errors << "rust-v8: spec does not mark the static license payload" unless spec.include?("%license %{_licensedir}/%{name}-static/*")
    errors << "rust-v8: spec does not install package documentation" unless spec.include?("%doc %{_docdir}/%{name}-static/README.md")
    unless spec.include?('os.path.getsize(source) != record["bytes"]') && spec.include?('hashlib.file_digest(stream, "sha256")')
      errors << "rust-v8: spec does not verify installed license text identities"
    end
    expected_witness = {
      "scope" => "fedora-44-x86_64-prototype-with-x86_64-and-aarch64-graph-expectations",
      "production" => false,
      "network_isolated" => false,
      "isolated_buildroot" => false,
      "patched_source_provenance_verified" => false
    }
    errors << "rust-v8: archive-graph witness scope is invalid" unless archive_graph["witness"] == expected_witness
    expected_gn_args = {
      "is_debug" => false,
      "is_clang" => false,
      "use_lld" => true,
      "use_custom_libcxx" => false,
      "symbol_level" => 0,
      "line_tables_only" => false,
      "no_inline_line_tables" => false,
      "clang_base_path" => "/usr",
      "clang_version" => "22",
      "v8_enable_sandbox" => false,
      "v8_enable_pointer_compression" => false,
      "v8_enable_v8_checks" => false,
      "rusty_v8_enable_simdutf" => false,
      "treat_warnings_as_errors" => false,
      "rust_sysroot_absolute" => "/usr",
      "rustc_version" => "1.96.1-Fedora-1.96.1-1.fc44",
      "rust_bindgen_root" => "/usr",
      "toolchain_supports_rust_thin_lto" => false
    }
    graph_gn = archive_graph.fetch("gn", {})
    errors << "rust-v8: archive-graph target is invalid" unless graph_gn["target"] == "//:rusty_v8" && graph_gn["ninja_target"] == "obj/librusty_v8.a"
    errors << "rust-v8: archive-graph GN arguments do not match the prototype" unless graph_gn["args"] == expected_gn_args
    expected_graph_files = {
      "args_file" => ["args.gn", 495, "6ff33d34c11a371c268ad9c6f0a357b5afa21449f80ea1e220f87cf5b0d87a28"],
      "build_ninja" => ["build.ninja", 110_416, "56563bdc7a689d381339f9927a062d1300f904d185b739cd92c21ef96e5fd916"],
      "target_ninja" => ["obj/rusty_v8.ninja", 105_604, "f146a59066b3faa3cc170e970b2a40402db7316808a2eb744e683a61e7e68093"],
      "toolchain_ninja" => ["toolchain.ninja", 272_864, "49122a064a61df37a4762b9a96b053f73c5d3d4f44ef4f388f4efc2f7bde4f90"]
    }
    expected_graph_files.each do |key, (path, bytes, sha256)|
      record = graph_gn.fetch(key, {})
      errors << "rust-v8: archive-graph #{key} identity does not match" unless record == { "path" => path, "bytes" => bytes, "sha256" => sha256 }
    end
    expected_prefix_counts = {
      "rusty_v8" => 2,
      "src/deno_inspector" => 8,
      "third_party/abseil-cpp" => 137,
      "third_party/highway" => 7,
      "third_party/icu" => 456,
      "third_party/simdutf" => 1,
      "v8/cppgc_base" => 48,
      "v8/src" => 37,
      "v8/third_party" => 9,
      "v8/torque_generated_definitions" => 246,
      "v8/v8_base_without_compiler" => 585,
      "v8/v8_bigint" => 9,
      "v8/v8_compiler" => 186,
      "v8/v8_heap_base" => 7,
      "v8/v8_libbase" => 41,
      "v8/v8_libplatform" => 13,
      "v8/v8_snapshot" => 3
    }
    graph_archive = archive_graph.fetch("archive", {})
    expected_archive_identity = {
      "path" => "obj/librusty_v8.a",
      "bytes" => 160_314_390,
      "sha256" => "ea107f29106ef88a313b03bc6ff714fc4e1c1a5db822df646c8d5f0a82bca334"
    }
    expected_archive_identity.each do |key, value|
      errors << "rust-v8: archive-graph archive #{key} does not match" unless graph_archive[key] == value
    end
    errors << "rust-v8: archive-graph object count does not match" unless graph_archive["object_input_count"] == 1_795
    unless graph_archive["object_input_paths_sha256"] == "e513350fe3ef60dae9d6d88aee96e9e630c155337f8be3f9bf8edc161d7b3ba2"
      errors << "rust-v8: archive-graph object path digest does not match"
    end
    errors << "rust-v8: archive-graph prefix counts do not match" unless graph_archive["object_input_prefix_counts"] == expected_prefix_counts
    errors << "rust-v8: archive-graph prefix count total does not match" unless expected_prefix_counts.values.sum == graph_archive["object_input_count"]
    errors << "rust-v8: archive member count does not match" unless graph_archive["member_count"] == 1_795
    errors << "rust-v8: archive unique-member count does not match" unless graph_archive["unique_member_names"] == 1_776
    unless graph_archive["member_names_sha256"] == "8582cf86663b5e522a136821b7ec5069e8dce6a92f61f3e6829cf0cf805cf443"
      errors << "rust-v8: archive member digest does not match"
    end
    unless graph_archive["member_name_multiset_matches_object_basenames"] == true
      errors << "rust-v8: archive member names do not match selected object basenames"
    end
    unless graph_archive["member_contents_match_object_contents_verified"] == false
      errors << "rust-v8: archive-graph witness overclaims member-content equality"
    end
    errors << "rust-v8: implicit Rust rlib count does not match" unless graph_archive["implicit_rust_rlib_count"] == 31
    unless graph_archive["implicit_rust_rlib_paths_sha256"] == "1ffa1fc702d3720704cd4a772952b7283938f1cd83e5edd0e0a662e07978d4a0"
      errors << "rust-v8: implicit Rust rlib path digest does not match"
    end
    unless graph_archive["implicit_rust_rlibs_embedded_in_archive"] == false
      errors << "rust-v8: archive-graph witness incorrectly claims embedded Rust rlibs"
    end
    errors << "rust-v8: selected archive graph unexpectedly includes googletest" unless graph_archive["selected_googletest_inputs"] == []
    errors << "rust-v8: selected archive graph unexpectedly includes HalfSipHash" unless graph_archive["selected_halfsiphash_inputs"] == []

    expected_architecture_prefix_counts = {
      "x86_64" => expected_prefix_counts,
      "aarch64" => {
        "rusty_v8" => 2,
        "src/deno_inspector" => 8,
        "third_party/abseil-cpp" => 137,
        "third_party/highway" => 7,
        "third_party/icu" => 456,
        "third_party/simdutf" => 1,
        "v8/cppgc_base" => 48,
        "v8/libm" => 3,
        "v8/src" => 37,
        "v8/third_party" => 9,
        "v8/torque_generated_definitions" => 246,
        "v8/v8_base_without_compiler" => 594,
        "v8/v8_bigint" => 9,
        "v8/v8_compiler" => 182,
        "v8/v8_heap_base" => 7,
        "v8/v8_libbase" => 41,
        "v8/v8_libplatform" => 13,
        "v8/v8_snapshot" => 3
      }
    }
    expected_architecture_graphs = {
      "x86_64" => {
        "gn_target_cpu" => "x64",
        "is_clang" => false,
        "object_input_count" => 1_795,
        "object_input_paths_sha256" => "e513350fe3ef60dae9d6d88aee96e9e630c155337f8be3f9bf8edc161d7b3ba2",
        "object_input_prefix_counts" => expected_architecture_prefix_counts.fetch("x86_64"),
        "member_count" => 1_795,
        "unique_member_names" => 1_776,
        "member_names_sha256" => "8582cf86663b5e522a136821b7ec5069e8dce6a92f61f3e6829cf0cf805cf443",
        "implicit_rust_rlib_count" => 31,
        "implicit_rust_rlib_paths_sha256" => "1ffa1fc702d3720704cd4a772952b7283938f1cd83e5edd0e0a662e07978d4a0",
        "selected_googletest_inputs" => [],
        "selected_halfsiphash_inputs" => []
      },
      "aarch64" => {
        "gn_target_cpu" => "arm64",
        "is_clang" => true,
        "object_input_count" => 1_803,
        "object_input_paths_sha256" => "c12202362607f81a15708a247a6251f14c5f56710ac41b836b6ee096a0529a00",
        "object_input_prefix_counts" => expected_architecture_prefix_counts.fetch("aarch64"),
        "member_count" => 1_803,
        "unique_member_names" => 1_784,
        "member_names_sha256" => "9c0f827a2e8dca6956452227bd316f3a6ad4cca957d82b55bad4a3acc174a471",
        "implicit_rust_rlib_count" => 31,
        "implicit_rust_rlib_paths_sha256" => "1ffa1fc702d3720704cd4a772952b7283938f1cd83e5edd0e0a662e07978d4a0",
        "selected_googletest_inputs" => [],
        "selected_halfsiphash_inputs" => []
      }
    }
    unless archive_graph["architecture_expectations"] == expected_architecture_graphs
      errors << "rust-v8: architecture-specific archive graph expectations do not match"
    end
    expected_architecture_graphs.each do |architecture, expectation|
      unless expectation.fetch("object_input_prefix_counts").values.sum == expectation.fetch("object_input_count")
        errors << "rust-v8: #{architecture} archive graph prefix count total does not match"
      end
    end

    graph_consumer = archive_graph.fetch("consumer_witness", {})
    expected_consumer_files = {
      "binary" => ["target/debug/rust-v8-exact-consumer", 83_213_856, "7b4b406e4b2f3d13301346fae717b94ee244d70c6e1b4485600122813ff6a942"],
      "copied_archive" => ["target/debug/gn_out/obj/librusty_v8.a", 160_314_390, "ea107f29106ef88a313b03bc6ff714fc4e1c1a5db822df646c8d5f0a82bca334"],
      "cargo_fingerprint" => ["target/debug/.fingerprint/v8-00037795b4eafb5d/lib-v8.json", 741, "e48e5612813a7282b99f915c00dbcc2136068936314f25b893b1bb33b7987d6d"]
    }
    expected_consumer_files.each do |key, (path, bytes, sha256)|
      record = graph_consumer.fetch(key, {})
      errors << "rust-v8: archive-graph consumer #{key} identity does not match" unless record == { "path" => path, "bytes" => bytes, "sha256" => sha256 }
    end
    expected_build_output = {
      "path" => "target/debug/build/v8-08635ab291c7edc0/output",
      "normalized_bytes" => 1_417,
      "normalized_sha256" => "30e2b9ff2ebfc530834054520e1cc5ca3a386fbdae2983864e8caf2591289478",
      "transient_roots_normalized" => true
    }
    unless graph_consumer["cargo_build_output"] == expected_build_output
      errors << "rust-v8: archive-graph consumer cargo_build_output identity does not match"
    end
    errors << "rust-v8: archive copy witness does not match" unless graph_consumer["archive_copy_sha256_matches"] == true
    errors << "rust-v8: Cargo feature witness does not match" unless graph_consumer["cargo_features"] == ["use_custom_libcxx"]
    unless graph_consumer["cargo_dependencies_include_temporal_capi"] == true
      errors << "rust-v8: Cargo temporal_capi dependency witness is missing"
    end
    expected_elf_needed = %w[ld-linux-x86-64.so.2 libc.so.6 libgcc_s.so.1 libm.so.6 libstdc++.so.6]
    errors << "rust-v8: consumer ELF dependency witness does not match" unless graph_consumer["elf_needed"] == expected_elf_needed
    %w[link_map_available link_response_file_available final_link_command_available archive_member_extraction_verified].each do |flag|
      errors << "rust-v8: archive-graph consumer witness overclaims #{flag}" unless graph_consumer[flag] == false
    end
    %w[
      prototype_selected_archive_graph_captured
      architecture_graph_expectations_captured
      archive_member_basenames_match_selected_object_basenames
      implicit_rust_rlib_dependencies_classified
      selected_graph_excludes_googletest
    ].each do |flag|
      errors << "rust-v8: archive-graph validation #{flag} is not true" unless archive_graph.dig("validation", flag) == true
    end
    %w[
      production_selected_archive_graph_verified
      archive_member_contents_match_selected_object_contents_verified
      selected_build_dependency_closure_verified
      network_isolated_build_verified
      final_consumer_link_closure_verified
    ].each do |flag|
      errors << "rust-v8: archive-graph validation overclaims #{flag}" unless archive_graph.dig("validation", flag) == false
    end

    dynamic_linking = JSON.parse(File.read(dynamic_linking_path))
    unless dynamic_linking["schema"] == "rust-v8-dynamic-linking-feasibility/v1"
      errors << "rust-v8: dynamic-linking schema is invalid"
    end
    errors << "rust-v8: dynamic-linking package does not match" unless dynamic_linking["package"] == package.name
    errors << "rust-v8: dynamic-linking release does not match" unless dynamic_linking["release"].to_s == version
    expected_dynamic_source_reference = {
      "path" => source_name,
      "sha256" => source_sha256,
      "commit" => package.upstream.fetch("source_commit")
    }
    unless dynamic_linking["source_closure_reference"] == expected_dynamic_source_reference
      errors << "rust-v8: dynamic-linking source-closure reference does not match"
    end
    expected_dynamic_source_files = [
      ["BUILD.gn", 1_622, "d791ceb9d77a0094fdf9209fa3bf3152051b9a6d113641703be287e9bc039334"],
      [".gn", 3_351, "bfc1665eed0764923e2a47f367bc8d9b2e7d48f13c3c9a963092e8e5bdafe8de"],
      ["build.rs", 39_002, "2a87a11db76f10c358d751cd3abed0f8e6f9945804ac599c3dc1698e951be5b4"],
      ["Cargo.toml", 3_750, "b2e08fc9d277cd79811e87105861ba61b07ab20d1fbaf9c0be91fddd1f68bb4b"],
      ["v8/BUILD.gn", 298_906, "accee889632544c7d88be264715694727d22c644cac0a3874b3f4e26d2f29c28"],
      ["build/config/BUILDCONFIG.gn", 33_848, "e6bf43e2f5f6ddefa1a10f796a8dbe3a4bf28d39a9e61781e75803760829f5de"],
      ["build/config/gcc/BUILD.gn", 4_333, "b31b0ca78798f37c316e3ae6e16b0aa34ce297c997a5b9b56d324370c3aa2ddf"],
      ["v8/include/v8config.h", 37_232, "4c550bbbf16f31881fccaa2d694b12d157d27bdcba4ad885a9ad557830eaf171"],
      ["src/binding.cc", 173_851, "ad157eb49bee6a0e3c62b63a8f8a04c3c1d405f0ccca0ced752048457c7a169a"],
      ["src/cppgc.rs", 22_952, "c0e210c8f1365d1fb85e5f994d592afbd051e8685e05c260a549c5d0bfddc15f"]
    ].map { |path, bytes, sha256| { "path" => path, "bytes" => bytes, "sha256" => sha256 } }
    unless dynamic_linking["source_files"] == expected_dynamic_source_files
      errors << "rust-v8: dynamic-linking exact-source file identities do not match"
    end
    expected_upstream_contract = {
      "rusty_v8_gn_target_type" => "static_library",
      "rusty_v8_complete_static_lib" => true,
      "rusty_v8_shared_target_declared" => false,
      "cargo_archive_override" => "RUSTY_V8_ARCHIVE",
      "cargo_archive_filename" => "librusty_v8.a",
      "cargo_native_link_kind" => "static",
      "rust_shared_crate_type_declared" => false,
      "v8_component_build_available" => true,
      "v8_component_mode_target_type" => "shared_library",
      "v8_component_build_default" => false,
      "posix_default_symbol_visibility" => "hidden",
      "v8_shared_visibility_macro_available" => true,
      "v8_monolithic_for_shared_library_argument_available" => true,
      "rust_callbacks_demonstrating_cross_language_boundary" => %w[
        rusty_v8_RustObj_drop
        rusty_v8_RustObj_get_name
        rusty_v8_RustObj_trace
      ]
    }
    unless dynamic_linking["upstream_contract"] == expected_upstream_contract
      errors << "rust-v8: dynamic-linking upstream contract does not match"
    end
    expected_shared_provider = {
      "upstream_supported" => false,
      "existing_rust_consumers_supported" => false,
      "rusty_v8_soname_defined" => false,
      "rusty_v8_symbol_export_policy_defined" => false,
      "rusty_v8_symbol_version_policy_defined" => false,
      "rusty_v8_runtime_loader_contract_defined" => false,
      "requires_downstream_consumer_interface_change" => true,
      "requires_downstream_abi_design" => true
    }
    errors << "rust-v8: dynamic-linking shared-provider boundary does not match" unless dynamic_linking["shared_provider"] == expected_shared_provider
    expected_dynamic_decision = {
      "package_shared_library" => false,
      "retain_exact_static_provider" => true,
      "v8_component_dsos_are_not_rusty_v8_shared_abi" => true,
      "relinking_static_objects_is_not_a_supported_shared_contract" => true,
      "revisit_when_upstream_defines_shared_consumer_contract" => true
    }
    errors << "rust-v8: dynamic-linking package decision does not match" unless dynamic_linking["decision"] == expected_dynamic_decision
    expected_dynamic_validation = {
      "exact_relevant_source_files_verified" => true,
      "exact_upstream_static_contract_verified" => true,
      "single_static_root_target_verified" => true,
      "single_static_cargo_link_directive_verified" => true,
      "v8_component_mode_distinguished" => true,
      "cross_language_callback_boundary_recorded" => true,
      "existing_consumer_dynamic_linking_verified" => false,
      "shared_provider_packaged" => false
    }
    unless dynamic_linking["validation"] == expected_dynamic_validation
      errors << "rust-v8: dynamic-linking validation state does not match"
    end
    expected_dynamic_metadata = {
      "receipt" => dynamic_linking_name,
      "receipt_sha256" => dynamic_linking_sha256,
      "v8_component_build_available" => true,
      "upstream_supported" => false,
      "existing_rust_consumers_supported" => false,
      "package_shared_library" => false,
      "retain_exact_static_provider" => true
    }
    errors << "rust-v8: package dynamic-linking metadata does not match" unless package.data["dynamic_linking"] == expected_dynamic_metadata
    errors << "rust-v8: dependency dynamic-linking metadata does not match" unless dependencies["dynamic_linking"] == expected_dynamic_metadata

    fedora_license = JSON.parse(File.read(fedora_license_path))
    unless fedora_license["schema"] == "rust-v8-fedora-license-evidence/v1"
      errors << "rust-v8: Fedora license-evidence schema is invalid"
    end
    errors << "rust-v8: Fedora license-evidence package does not match" unless fedora_license["package"] == package.name
    errors << "rust-v8: Fedora license-evidence release does not match" unless fedora_license["release"].to_s == version
    expected_fedora_target = { "fedora_release" => "44", "repositories" => %w[fedora updates] }
    errors << "rust-v8: Fedora license-evidence target does not match" unless fedora_license["target"] == expected_fedora_target
    fedora_records = fedora_license["records"]
    unless fedora_records.is_a?(Array)
      return errors << "rust-v8: Fedora license-evidence crate records are missing"
    end
    fedora_keys = fedora_records.map { |record| [record["crate"], record["version"]] }
    errors << "rust-v8: Fedora license-evidence crate records are not sorted" unless fedora_keys == fedora_keys.sort
    errors << "rust-v8: Fedora license-evidence crate records are duplicated" unless fedora_keys.uniq.length == fedora_keys.length
    fedora_records.each do |record|
      exact_providers = Array(record["exact_providers"])
      other_providers = Array(record["other_providers"])
      case record["status"]
      when "exact"
        unless exact_providers.any? && exact_providers.all? { |provider| provider["version"] == record["version"] }
          errors << "rust-v8: Fedora exact-version provider evidence is invalid for #{record['crate']} #{record['version']}"
        end
      when "version-different"
        unless exact_providers.empty? && other_providers.any? && other_providers.none? { |provider| provider["version"] == record["version"] }
          errors << "rust-v8: Fedora version-different provider evidence is invalid for #{record['crate']} #{record['version']}"
        end
      when "absent"
        unless exact_providers.empty? && other_providers.empty?
          errors << "rust-v8: Fedora absent-provider evidence is invalid for #{record['crate']} #{record['version']}"
        end
      else
        errors << "rust-v8: Fedora provider status is invalid for #{record['crate']} #{record['version']}"
      end
      (exact_providers + other_providers).each do |provider|
        unless provider["license"].to_s.length.positive? && provider["source_rpm"].to_s.end_with?(".src.rpm")
          errors << "rust-v8: Fedora provider metadata is incomplete for #{record['crate']} #{record['version']}"
        end
      end
    end
    expected_fedora_summary = {
      "vendored_rust_source_packages" => fedora_records.length,
      "exact" => fedora_records.count { |record| record["status"] == "exact" },
      "version_different" => fedora_records.count { |record| record["status"] == "version-different" },
      "absent" => fedora_records.count { |record| record["status"] == "absent" }
    }
    errors << "rust-v8: Fedora license-evidence summary is inconsistent" unless fedora_license["summary"] == expected_fedora_summary
    errors << "rust-v8: Fedora exact-version package count does not match" unless expected_fedora_summary["exact"] == 136
    errors << "rust-v8: Fedora version-different package count does not match" unless expected_fedora_summary["version_different"] == 26
    errors << "rust-v8: Fedora absent package count does not match" unless expected_fedora_summary["absent"] == 54
    %w[crate_inventory_matches_license_audit exact_matches_include_fedora_license_metadata].each do |flag|
      errors << "rust-v8: Fedora license-evidence validation #{flag} is not true" unless fedora_license.dig("validation", flag) == true
    end
    %w[linked_archive_selection_verified fedora_allowed_spdx_verified final_static_archive_license_complete].each do |flag|
      errors << "rust-v8: Fedora license evidence overclaims #{flag}" unless fedora_license.dig("validation", flag) == false
    end
    expected_fedora_metadata = {
      "receipt" => fedora_license_name,
      "receipt_sha256" => fedora_license_sha256,
      "fedora_release" => "44",
      "repositories" => %w[fedora updates],
      "vendored_rust_source_packages" => 216,
      "exact" => 136,
      "version_different" => 26,
      "absent" => 54,
      "exact_matches_include_fedora_license_metadata" => true,
      "linked_archive_selection_verified" => false,
      "final_static_archive_license_complete" => false
    }
    errors << "rust-v8: package Fedora license-evidence metadata does not match" unless package.data["fedora_license_evidence"] == expected_fedora_metadata
    errors << "rust-v8: dependency Fedora license-evidence metadata does not match" unless dependencies["fedora_license_evidence"] == expected_fedora_metadata

    license = JSON.parse(File.read(license_path))
    errors << "rust-v8: license-audit schema is invalid" unless license["schema"] == "rust-v8-license-audit/v1"
    errors << "rust-v8: license-audit release does not match" unless license["release"].to_s == version
    errors << "rust-v8: license audit is not bound to the source receipt" unless license.dig("source_closure", "sha256") == source_sha256
    license_components = license["components"]
    errors << "rust-v8: license component paths do not match the source receipt" unless Array(license_components).map { |component| component["path"] } == paths
    license_files = Array(license_components).flat_map { |component| Array(component["license_files"]) }
    readme_records = Array(license_components).flat_map { |component| Array(component["readme_chromium"]) }
    recognized_syntax_classes = %w[
      missing
      legacy-bsd-label
      ambiguous-comma-list
      legacy-slash-alternative
      spdx-expression-syntax
      spdx-identifier-syntax
      unclassified
    ]
    expected_readme_normalizations = {
      "buildtools/clang_format/README.chromium" => [
        "(Apache-2.0 WITH LLVM-exception) AND NCSA",
        nil,
        "semantically-reviewed",
        "LLVM 547e3456660000a16fc5c2a2f819f1a2b5d35b5d llvm/LICENSE.TXT (SHA-256 8d85c1057d742e597985c7d4e6320b015a9139385cff4cbae06ffc0ebe89afee)",
        "verified"
      ],
      "third_party/rust/encoding_rs/v0_8/README.chromium" => [
        "(Apache-2.0 OR MIT) AND BSD-3-Clause",
        nil,
        "semantically-reviewed",
        "third_party/rust/chromium_crates_io/vendor/encoding_rs-v0_8/Cargo.toml license field plus the checked Apache-2.0, MIT, and BSD-3-Clause texts",
        "verified"
      ],
      "third_party/rust/unicode_ident/v1/README.chromium" => [
        "(MIT OR Apache-2.0) AND Unicode-3.0",
        nil,
        "semantically-reviewed",
        "third_party/rust/chromium_crates_io/vendor/unicode-ident-v1/Cargo.toml license field plus the checked MIT, Apache-2.0, and Unicode-3.0 texts",
        "verified"
      ],
      "v8/third_party/googletest/README.chromium" => [
        "BSD-3-Clause",
        nil,
        "semantically-reviewed",
        "googletest 4fe3307fb2d9f86d19777c7eb0e4809e9694dde7 LICENSE (SHA-256 9702de7e4117a8e2b20dafab11ffda58c198aede066406496bef670d40a22138)",
        "verified"
      ]
    }
    reviewed_declared_license_texts = {
      "third_party/rust/chromium_crates_io/vendor/encoding_rs-v0_8/LICENSE-APACHE" => "Apache-2.0",
      "third_party/rust/chromium_crates_io/vendor/unicode-ident-v1/LICENSE-APACHE" => "Apache-2.0",
      "third_party/rust/chromium_crates_io/vendor/unicode-ident-v1/LICENSE-UNICODE" => "Unicode-3.0"
    }
    expected_syntax = lambda do |raw, allow_slash|
      if raw.nil?
        ["missing", nil, nil, "missing", nil, "pending"]
      elsif raw == "BSD"
        ["legacy-bsd-label", nil, nil, "unresolved", nil, "pending"]
      elsif raw.include?(",")
        ["ambiguous-comma-list", nil, nil, "ambiguous", nil, "pending"]
      elsif allow_slash && raw.include?("/")
        operands = raw.split("/").map(&:strip)
        proposed = if operands.length > 1 && operands.all? { |operand| operand.match?(/\A[A-Za-z0-9][A-Za-z0-9.+-]*\z/) }
                     operands.join(" OR ")
                   end
        if raw == "MIT/Apache-2.0"
          [
            "legacy-slash-alternative",
            proposed,
            nil,
            "mechanically-normalized",
            "Fedora cargo2rpm license.py legacy slash-alternative conversion",
            "pending"
          ]
        else
          ["legacy-slash-alternative", nil, proposed, proposed ? "proposed" : "unresolved", nil, "pending"]
        end
      elsif raw.match?(/\b(?:AND|OR|WITH)\b|[()]/)
        ["spdx-expression-syntax", raw, nil, "syntax-only", nil, "pending"]
      elsif raw.match?(/\A[A-Za-z0-9][A-Za-z0-9.+-]*\z/)
        ["spdx-identifier-syntax", raw, nil, "syntax-only", nil, "pending"]
      else
        ["unclassified", nil, nil, "unresolved", nil, "pending"]
      end
    end
    validate_syntax = lambda do |record, raw, allow_slash, label|
      expected = expected_syntax.call(raw, allow_slash)
      if (normalization = expected_readme_normalizations[label])
        expected[1, 5] = normalization
      end
      actual = [
        record["syntax_class"],
        record["normalized_expression"],
        record["proposed_expression"],
        record["normalization_status"],
        record["normalization_basis"],
        record["semantic_review_status"]
      ]
      errors << "rust-v8: license syntax metadata is inconsistent for #{label}" unless actual == expected
      errors << "rust-v8: license syntax rationale is missing for #{label}" if record["normalization_reason"].to_s.empty?
    end
    readme_records.each do |record|
      errors << "rust-v8: README.chromium raw license does not match" unless record["raw_license"] == record["license"]
      errors << "rust-v8: README.chromium license syntax is unclassified" unless recognized_syntax_classes.include?(record["syntax_class"])
      validate_syntax.call(record, record["license"], false, record["path"])
      Array(record["license_file_records"]).each do |declared_path|
        expected_expression = reviewed_declared_license_texts[declared_path["path"]]
        expected_reviewed = !expected_expression.nil?
        unless declared_path["semantic_review_verified"] == expected_reviewed &&
               declared_path["semantic_review_expression"] == expected_expression
          errors << "rust-v8: declared license text semantic review does not match #{declared_path['path']}"
        end
      end
    end
    license_files.each do |record|
      errors << "rust-v8: license candidate #{record['path']} has an invalid SHA-256" unless record["sha256"].to_s.match?(/\A[0-9a-f]{64}\z/)
    end

    vendored = license.dig("vendored_rust", "packages")
    unless vendored.is_a?(Array)
      return errors << "rust-v8: vendored Rust package inventory is missing"
    end
    placeholders = vendored.select { |record| record["placeholder"] == true }
    source_packages = vendored.reject { |record| record["placeholder"] == true }
    expected_fedora_reference = {
      "path" => fedora_license_name,
      "sha256" => fedora_license_sha256,
      "target" => fedora_license.fetch("target"),
      "summary" => fedora_license.fetch("summary"),
      "scope" => fedora_license.dig("source", "scope")
    }
    unless license["fedora_license_evidence"] == expected_fedora_reference
      errors << "rust-v8: license audit is not bound to the Fedora license-evidence receipt"
    end
    fedora_records_by_key = fedora_records.to_h do |record|
      [[record["crate"], record["version"]], record]
    end
    source_package_keys = source_packages.map { |record| [record["name"], record["version"]] }
    unless fedora_records_by_key.keys.sort == source_package_keys.sort
      errors << "rust-v8: Fedora license-evidence inventory does not match vendored Rust source packages"
    end
    errors << "rust-v8: vendored Rust source declaration inventory is incomplete" unless source_packages.all? { |record| record["manifest_license"] || record["manifest_license_file"] }
    errors << "rust-v8: vendored Rust candidate-text inventory is incomplete" unless source_packages.all? { |record| record["license_file_count"].to_i.positive? }
    errors << "rust-v8: vendored Rust license syntax inventory is incomplete" unless source_packages.all? { |record| recognized_syntax_classes.include?(record["syntax_class"]) }
    vendored.each do |record|
      errors << "rust-v8: vendored Rust raw license does not match #{record['path']}" unless record["raw_license"] == record["manifest_license"]
      validate_syntax.call(record, record["manifest_license"], true, record["path"])
      license_paths = Array(record["license_files"]).map { |license_file| license_file["path"] }
      errors << "rust-v8: vendored Rust license files are not sorted for #{record['path']}" unless license_paths == license_paths.sort
      if record["manifest_license"] == "MIT/Apache-2.0"
        license_basenames = license_paths.map { |path| File.basename(path).upcase }
        unless license_basenames.include?("LICENSE-MIT") && license_basenames.include?("LICENSE-APACHE")
          errors << "rust-v8: mechanical slash normalization lacks both texts for #{record['path']}"
        end
      end
      if record["placeholder"] == true
        errors << "rust-v8: vendored Rust placeholder has Fedora package evidence" if record.key?("fedora_license_evidence")
      else
        fedora_record = fedora_records_by_key[[record["name"], record["version"]]] || {}
        expected = {
          "status" => fedora_record["status"],
          "exact_providers" => Array(fedora_record["exact_providers"]),
          "other_providers" => Array(fedora_record["other_providers"])
        }
        unless record["fedora_license_evidence"] == expected
          errors << "rust-v8: vendored Rust Fedora evidence does not match #{record['path']}"
        end
      end
    end
    unmaterialized_deps = Array(license["unmaterialized_deps_declarations"])
    expected_unmaterialized_deps = [
      {
        "source_path" => "v8/third_party/googletest/src",
        "declared_license_path" => "v8/third_party/googletest/src/LICENSE",
        "readme_chromium" => "v8/third_party/googletest/README.chromium",
        "archive_url" => "https://chromium.googlesource.com/external/github.com/google/googletest/+archive/4fe3307fb2d9f86d19777c7eb0e4809e9694dde7.tar.gz",
        "commit" => "4fe3307fb2d9f86d19777c7eb0e4809e9694dde7",
        "readme_shipped" => "no",
        "source_materialized" => false,
        "declared_text_resolvable" => false
      }
    ]
    errors << "rust-v8: unmaterialized DEPS declaration inventory does not match" unless unmaterialized_deps == expected_unmaterialized_deps
    chromium_parent_license = {
      "repository" => "https://chromium.googlesource.com/chromium/src",
      "commit" => "605c904774a4e2204ef7ca2dbc93ac16f526c085",
      "path" => "LICENSE",
      "url" => "https://chromium.googlesource.com/chromium/src/+/605c904774a4e2204ef7ca2dbc93ac16f526c085/LICENSE",
      "sha256" => "368cca1106be99d39ecd32a38d8305585d802a475effb66380b91ffc9bcf709b",
      "expression" => "BSD-3-Clause"
    }
    expected_parent_evidence = [
      {
        "path" => "tools/clang",
        "source_commit" => "61150a5f1ddf6460bad3d896c1502c6a56e15311",
        "source_archive_url" => "https://chromium.googlesource.com/chromium/src/tools/clang/+archive/61150a5f1ddf6460bad3d896c1502c6a56e15311.tar.gz",
        "component_local_texts_present" => false,
        "parent_license" => chromium_parent_license,
        "chromium_header_evidence" => {
          "path" => "tools/clang/v8_handle_migrate/tests/with-prototypes-original.cc",
          "sha256" => "c50c13e9b9cfd28d7b6e45002b000f85a74c92bce34c4f4311f762d75cf74858"
        },
        "applies_to_chromium_authored_files_only" => true,
        "whole_component_license_verified" => false,
        "embedded_third_party_reviewed" => false
      },
      {
        "path" => "tools/win",
        "source_commit" => "d16e6b55b2bd699735919d8a13a55ff284086603",
        "source_archive_url" => "https://chromium.googlesource.com/chromium/src/tools/win/+archive/d16e6b55b2bd699735919d8a13a55ff284086603.tar.gz",
        "component_local_texts_present" => false,
        "parent_license" => chromium_parent_license,
        "chromium_header_evidence" => {
          "path" => "tools/win/sizeviewer/sizeviewer.py",
          "sha256" => "2d75f52c309ab9d546f7a5453396772c75972d6b406c28d5bbbbf02d86388b9e"
        },
        "applies_to_chromium_authored_files_only" => true,
        "whole_component_license_verified" => false,
        "embedded_third_party_reviewed" => false,
        "directory_declares_not_shipped" => true,
        "embedded_third_party_assets" => {
          "declaration_path" => "tools/win/sizeviewer/README.chromium",
          "declaration_sha256" => "ff117457ee3fb3c3015a1e8aa73849eb52314ba525196651029d5a75242b1c64",
          "assets" => [
            {
              "path" => "tools/win/sizeviewer/codemirror.js",
              "sha256" => "6ec18dff438553ebebd9f33b86c387d16783ca6b64576810daafc123e60bd1fd",
              "proposed_expression" => "MIT",
              "semantic_review_status" => "pending"
            },
            {
              "path" => "tools/win/sizeviewer/clike.js",
              "sha256" => "76cd8a83c47592f454350df6bea616330d925acff9544fade8d97792384086ab",
              "proposed_expression" => "MIT",
              "semantic_review_status" => "pending"
            },
            {
              "path" => "tools/win/sizeviewer/favicon.png",
              "sha256" => "c4be8cf22cedfe22ca5a0691640c47ae5308aba65eb9949c246b53bcc86070bc",
              "proposed_expression" => nil,
              "semantic_review_status" => "pending"
            }
          ]
        }
      }
    ]
    unless license["scoped_parent_license_evidence"] == expected_parent_evidence
      errors << "rust-v8: scoped parent-license evidence does not match"
    end
    license_summary = license.fetch("summary", {})
    expected_license_summary = {
      "components" => components.length,
      "components_with_license_files" => Array(license_components).count { |record| record["license_file_count"].to_i.positive? },
      "components_without_license_files" => Array(license_components).count { |record| record["license_file_count"].to_i.zero? },
      "license_candidate_files" => license_files.length,
      "readme_chromium_records" => readme_records.length,
      "readme_chromium_with_license" => readme_records.count { |record| record.key?("license") },
      "readme_chromium_without_license" => readme_records.count { |record| record["raw_license"].nil? },
      "readme_chromium_ambiguous_comma_licenses" => readme_records.count { |record| record["syntax_class"] == "ambiguous-comma-list" },
      "readme_chromium_legacy_bsd_licenses" => readme_records.count { |record| record["syntax_class"] == "legacy-bsd-label" },
      "readme_chromium_proposed_normalizations" => readme_records.count { |record| record["normalization_status"].to_s.start_with?("proposed", "external-proposed") },
      "readme_chromium_semantically_reviewed_normalizations" => readme_records.count { |record| record["normalization_status"] == "semantically-reviewed" },
      "readme_chromium_with_declared_license_file" => readme_records.count { |record| record["license_file"] },
      "readme_chromium_with_verified_declared_license_file" => readme_records.count { |record| record["license_file_verified"] == true },
      "readme_chromium_declared_license_paths" => readme_records.sum { |record| Array(record["license_file_records"]).length },
      "readme_chromium_verified_declared_license_paths" => readme_records.sum { |record| Array(record["license_file_records"]).count { |path| path["verified"] == true } },
      "readme_chromium_unmaterialized_declared_license_paths" => readme_records.sum { |record| Array(record["license_file_records"]).count { |path| path["declared_text_scope"] == "unmaterialized-deps-source" } },
      "readme_chromium_semantically_verified_declared_license_paths" => readme_records.sum { |record| Array(record["license_file_records"]).count { |path| path["semantic_review_verified"] == true } },
      "vendored_rust_packages" => vendored.length,
      "vendored_rust_source_packages" => source_packages.length,
      "vendored_rust_placeholders" => placeholders.length,
      "vendored_rust_source_packages_with_manifest_license" => source_packages.count { |record| record["manifest_license"] },
      "vendored_rust_source_packages_with_manifest_license_file" => source_packages.count { |record| record["manifest_license_file"] },
      "vendored_rust_source_packages_with_verified_manifest_license_file" => source_packages.count { |record| record["manifest_license_file_verified"] == true },
      "vendored_rust_source_packages_with_candidate_texts" => source_packages.count { |record| record["license_file_count"].to_i.positive? },
      "vendored_rust_legacy_slash_license_expressions" => source_packages.count { |record| record["syntax_class"] == "legacy-slash-alternative" },
      "vendored_rust_mechanically_normalized_license_expressions" => source_packages.count { |record| record["normalization_status"] == "mechanically-normalized" },
      "vendored_rust_fedora_exact_version_matches" => expected_fedora_summary["exact"],
      "vendored_rust_fedora_version_different_matches" => expected_fedora_summary["version_different"],
      "vendored_rust_fedora_absent" => expected_fedora_summary["absent"]
    }
    errors << "rust-v8: license-audit summary is inconsistent" unless license_summary == expected_license_summary
    unmaterialized_declared_license_paths = readme_records.flat_map do |record|
      Array(record["license_file_records"]).select do |path|
        path["declared_text_scope"] == "unmaterialized-deps-source"
      end.map { |path| path["path"] }
    end.sort
    unresolved_declared_license_paths = readme_records.flat_map do |record|
      Array(record["license_file_records"]).select { |path| path["declared_text_scope"] == "unresolved" }.map { |path| path["path"] }
    end.sort
    errors << "rust-v8: unresolved materialized declared-license paths remain" unless unresolved_declared_license_paths.empty?
    package_license = package.data.fetch("license_audit", {})
    dependency_license = dependencies.fetch("license_audit", {})
    {
      "candidate_license_files" => "license_candidate_files",
      "vendored_rust_entries" => "vendored_rust_packages",
      "vendored_rust_source_packages" => "vendored_rust_source_packages",
      "vendored_rust_placeholders" => "vendored_rust_placeholders",
      "readme_chromium_declared_license_paths" => "readme_chromium_declared_license_paths",
      "readme_chromium_verified_declared_license_paths" => "readme_chromium_verified_declared_license_paths",
      "readme_chromium_ambiguous_comma_licenses" => "readme_chromium_ambiguous_comma_licenses",
      "readme_chromium_legacy_bsd_licenses" => "readme_chromium_legacy_bsd_licenses",
      "readme_chromium_proposed_normalizations" => "readme_chromium_proposed_normalizations",
      "readme_chromium_semantically_reviewed_normalizations" => "readme_chromium_semantically_reviewed_normalizations",
      "readme_chromium_unmaterialized_declared_license_paths" => "readme_chromium_unmaterialized_declared_license_paths",
      "readme_chromium_semantically_verified_declared_license_paths" => "readme_chromium_semantically_verified_declared_license_paths",
      "vendored_rust_legacy_slash_license_expressions" => "vendored_rust_legacy_slash_license_expressions",
      "vendored_rust_mechanically_normalized_license_expressions" => "vendored_rust_mechanically_normalized_license_expressions",
      "vendored_rust_fedora_exact_version_matches" => "vendored_rust_fedora_exact_version_matches",
      "vendored_rust_fedora_version_different_matches" => "vendored_rust_fedora_version_different_matches",
      "vendored_rust_fedora_absent" => "vendored_rust_fedora_absent"
    }.each do |metadata_key, summary_key|
      errors << "rust-v8: package license metadata #{metadata_key} does not match" unless package_license[metadata_key] == license_summary[summary_key]
      errors << "rust-v8: dependency license metadata #{metadata_key} does not match" unless dependency_license[metadata_key] == license_summary[summary_key]
    end
    errors << "rust-v8: package unmaterialized declared-license paths do not match" unless package_license["unmaterialized_declared_license_paths"] == unmaterialized_declared_license_paths
    errors << "rust-v8: dependency unmaterialized declared-license paths do not match" unless dependency_license["unmaterialized_declared_license_paths"] == unmaterialized_declared_license_paths
    component_text_gaps = Array(license_components).select { |record| record["license_file_count"].to_i.zero? }.map { |record| record["path"] }
    errors << "rust-v8: package component-local text gaps do not match" unless package_license["component_local_text_gaps"] == component_text_gaps
    errors << "rust-v8: dependency component-local text gaps do not match" unless dependency_license["components_without_local_license_files"] == component_text_gaps
    unless package_license["scoped_parent_license_evidence_recorded"] == true &&
           dependency_license["scoped_parent_license_evidence_recorded"] == true
      errors << "rust-v8: scoped parent-license metadata is incomplete"
    end
    %w[
      source_closure_verified
      source_tree_verified
      all_source_components_inventoried
      candidate_license_files_hashed
      readme_chromium_metadata_inventoried
      declared_license_file_paths_inventoried
      declared_license_syntax_classified
      known_license_normalization_evidence_recorded
      scoped_parent_license_evidence_recorded
      unmaterialized_deps_declarations_classified
      vendored_rust_manifests_inventoried
      vendored_rust_placeholders_classified
      vendored_rust_fedora_license_evidence_recorded
      vendored_rust_source_package_declarations_complete
      vendored_rust_source_package_candidate_texts_present
    ].each do |flag|
      errors << "rust-v8: license-audit validation #{flag} is not true" unless license.dig("validation", flag) == true
    end
    %w[
      license_expressions_normalized
      declared_license_text_semantic_review_complete
      required_license_texts_verified
      fedora_allowed_spdx_verified
      source_package_license_complete
      final_static_archive_license_complete
    ].each do |flag|
      errors << "rust-v8: license audit overclaims #{flag}" unless license.dig("validation", flag) == false
    end

    patch_metadata = Array(dependencies["patches"])
    expected_source_patches = patch_metadata.map do |patch|
      record = {
        "name" => patch.fetch("file"),
        "sha256" => patch.fetch("sha256"),
        "zero_fuzz_dry_run" => patch["zero_fuzz_dry_run"] == "passed",
        "upstream_status" => patch.fetch("upstream_status")
      }
      record["upstream_url"] = patch["upstream_url"] if patch["upstream_url"]
      record
    end
    unless source["patches"] == expected_source_patches
      errors << "rust-v8: source and dependency patch metadata do not match"
    end
    patch_metadata.each do |patch|
      patch_path = File.join(package.directory, patch.fetch("file"))
      actual = File.file?(patch_path) && Digest::SHA256.file(patch_path).hexdigest
      errors << "rust-v8: patch SHA-256 does not match #{patch.fetch('file')}" unless actual == patch["sha256"]
    end
    system_patch_path = File.join(package.directory, "rust-v8-system-rust-toolchain.patch")
    if File.file?(system_patch_path)
      system_patch = File.read(system_patch_path)
      unless system_patch.scan("clang_base_path == default_clang_base_path").length == 3 &&
             system_patch.include?('import("//build/config/clang/clang.gni")') &&
             system_patch.include?('_dir = "aarch64-redhat-linux-gnu"')
        errors << "rust-v8: system-toolchain patch does not guard bundled-Clang-only flags"
      end
    end
    memcopy_patch_path = File.join(package.directory, "rust-v8-v8-memcopy-climits.patch")
    if File.file?(memcopy_patch_path)
      memcopy_patch = File.read(memcopy_patch_path)
      unless memcopy_patch.include?("+#include <climits>") &&
             memcopy_patch.include?("https://issues.chromium.org/issues/512749476")
        errors << "rust-v8: V8 memcopy patch does not retain the upstream-tracked header fix"
      end
    end
    unless package.data.dig("source_policy", "archive_transport_identity_required") == false &&
           dependencies.dig("source_closure", "archive_transport_identity_required") == false &&
           source.dig("validation", "archive_transport_identity_required") == false
      errors << "rust-v8: generated source transport policy does not match"
    end
    errors << "rust-v8: package reconstructed file count does not match" unless package.data.dig("source_policy", "reconstructed_file_records") == source.dig("reconstruction", "file_records")
    errors << "rust-v8: dependency reconstructed tree SHA-256 does not match" unless dependencies.dig("source_closure", "reconstructed_tree_sha256") == source.dig("reconstruction", "tree_sha256")
    errors << "rust-v8: package source closure kind does not match" unless package.data.dig("source_policy", "closure_kind") == closure_scope["kind"]
    errors << "rust-v8: dependency source closure kind does not match" unless dependencies.dig("source_closure", "closure_kind") == closure_scope["kind"]
    errors << "rust-v8: package metadata overclaims a full DEPS checkout" unless package.data.dig("source_policy", "full_deps_checkout_verified") == false
    errors << "rust-v8: dependency metadata overclaims a full DEPS checkout" unless dependencies.dig("source_closure", "full_deps_checkout_verified") == false
    errors << "rust-v8: package metadata overclaims selected-build dependency closure" unless package.data.dig("source_policy", "selected_build_dependency_closure_verified") == false
    errors << "rust-v8: dependency metadata overclaims selected-build dependency closure" unless dependencies.dig("source_closure", "selected_build_dependency_closure_verified") == false
    package_archive_graph = package.data.fetch("archive_graph", {})
    dependency_archive_graph = dependencies.fetch("archive_graph", {})
    expected_architecture_object_counts = expected_architecture_graphs.transform_values { |record| record.fetch("object_input_count") }
    expected_architecture_member_counts = expected_architecture_graphs.transform_values { |record| record.fetch("member_count") }
    [package_archive_graph, dependency_archive_graph].each do |metadata|
      errors << "rust-v8: archive-graph metadata schema does not match" unless metadata["schema"] == archive_graph["schema"]
      errors << "rust-v8: archive-graph metadata receipt does not match" unless metadata["receipt"] == archive_graph_name
      errors << "rust-v8: archive-graph metadata SHA-256 does not match" unless metadata["receipt_sha256"] == archive_graph_sha256
      errors << "rust-v8: archive-graph metadata scope does not match" unless metadata["scope"] == archive_graph.dig("witness", "scope")
      errors << "rust-v8: archive-graph metadata target does not match" unless metadata["target"] == archive_graph.dig("gn", "target")
      errors << "rust-v8: archive-graph metadata object count does not match" unless metadata["object_input_count"] == graph_archive["object_input_count"]
      errors << "rust-v8: archive-graph metadata member count does not match" unless metadata["member_count"] == graph_archive["member_count"]
      unless metadata["architecture_object_input_counts"] == expected_architecture_object_counts
        errors << "rust-v8: archive-graph metadata architecture object counts do not match"
      end
      unless metadata["architecture_member_counts"] == expected_architecture_member_counts
        errors << "rust-v8: archive-graph metadata architecture member counts do not match"
      end
      errors << "rust-v8: archive-graph metadata Rust rlib count does not match" unless metadata["implicit_rust_rlib_count"] == graph_archive["implicit_rust_rlib_count"]
      unless metadata["implicit_rust_rlibs_embedded_in_archive"] == false
        errors << "rust-v8: archive-graph metadata overclaims embedded Rust rlibs"
      end
      unless metadata["prototype_selected_archive_graph_captured"] == true
        errors << "rust-v8: archive-graph metadata does not record the prototype witness"
      end
      unless metadata["selected_build_dependency_closure_verified"] == false
        errors << "rust-v8: archive-graph metadata overclaims selected-build dependency closure"
      end
      unless metadata["final_consumer_link_closure_verified"] == false
        errors << "rust-v8: archive-graph metadata overclaims final consumer link closure"
      end
    end
    unless dependencies.dig("closure_audit", "prototype_selected_archive_graph_captured") == true
      errors << "rust-v8: dependency closure metadata omits the prototype archive graph"
    end
    unless dependencies.dig("closure_audit", "prototype_selected_build_sources_verified") == false
      errors << "rust-v8: dependency closure metadata overclaims prototype selected-build sources"
    end
    expected_production_build = {
      "configured_scm_build" => 10_757_049,
      "nvr" => "rust-v8-149.2.0-0.24",
      "package_build_networking" => false,
      "fedora_43_x86_64" => "succeeded",
      "fedora_43_aarch64" => "succeeded",
      "fedora_44_x86_64" => "succeeded",
      "fedora_44_aarch64" => "succeeded",
      "rawhide_x86_64" => "succeeded",
      "rawhide_aarch64" => "succeeded",
      "architecture_and_source_bound_build_verified" => true,
      "consumer_link_closure_verified" => false
    }
    errors << "rust-v8: package production-build evidence does not match" unless package.data["production_build"] == expected_production_build
    expected_closure_audit = {
      "configured_scm_build" => 10_757_049,
      "production_build_sources_verified" => true,
      "network_isolated_build_verified" => true,
      "fedora_43_verified" => true,
      "fedora_44_verified" => true,
      "rawhide_verified" => true,
      "aarch64_verified" => true,
      "consumer_link_closure_verified" => false,
      "package_ready" => false
    }
    expected_closure_audit.each do |key, value|
      errors << "rust-v8: dependency production-build evidence #{key} does not match" unless dependencies.dig("closure_audit", key) == value
    end

    reproducibility_path = File.join(package.directory, "reproducibility.yml")
    if File.file?(reproducibility_path)
      reproducibility = load_yaml(reproducibility_path)
      errors << "rust-v8: reproducibility source receipt SHA-256 does not match" unless reproducibility.dig("recursive_source", "receipt_sha256") == source_sha256
      errors << "rust-v8: reproducibility license receipt SHA-256 does not match" unless reproducibility.dig("licenses", "receipt_sha256") == license_sha256
      unless reproducibility.dig("licenses", "fedora_evidence_receipt") == fedora_license_name &&
             reproducibility.dig("licenses", "fedora_evidence_receipt_sha256") == fedora_license_sha256
        errors << "rust-v8: reproducibility Fedora license-evidence receipt does not match"
      end
      errors << "rust-v8: reproducibility Fedora release does not match" unless reproducibility.dig("licenses", "fedora_release") == "44"
      errors << "rust-v8: reproducibility archive-graph receipt SHA-256 does not match" unless reproducibility.dig("archive_graph", "receipt_sha256") == archive_graph_sha256
      errors << "rust-v8: reproducibility archive-graph schema does not match" unless reproducibility.dig("archive_graph", "schema") == archive_graph["schema"]
      errors << "rust-v8: reproducibility archive-graph scope does not match" unless reproducibility.dig("archive_graph", "scope") == archive_graph.dig("witness", "scope")
      errors << "rust-v8: reproducibility archive-graph target does not match" unless reproducibility.dig("archive_graph", "target") == archive_graph.dig("gn", "target")
      errors << "rust-v8: reproducibility archive-graph object count does not match" unless reproducibility.dig("archive_graph", "object_input_count") == graph_archive["object_input_count"]
      unless reproducibility.dig("archive_graph", "architecture_object_input_counts") == expected_architecture_object_counts
        errors << "rust-v8: reproducibility architecture object counts do not match"
      end
      unless reproducibility.dig("archive_graph", "architecture_member_counts") == expected_architecture_member_counts
        errors << "rust-v8: reproducibility architecture member counts do not match"
      end
      unless reproducibility.dig("archive_graph", "implicit_rust_rlibs_embedded_in_archive") == false
        errors << "rust-v8: reproducibility metadata overclaims embedded Rust rlibs"
      end
      unless reproducibility.dig("archive_graph", "prototype_selected_archive_graph_captured") == true
        errors << "rust-v8: reproducibility metadata omits the prototype archive graph"
      end
      unless reproducibility.dig("archive_graph", "selected_build_dependency_closure_verified") == false
        errors << "rust-v8: reproducibility metadata overclaims selected-build dependency closure"
      end
      unless reproducibility.dig("archive_graph", "final_consumer_link_closure_verified") == false
        errors << "rust-v8: reproducibility metadata overclaims final consumer link closure"
      end
      errors << "rust-v8: reproducibility tree SHA-256 does not match" unless reproducibility.dig("recursive_source", "reconstructed_tree_sha256") == source.dig("reconstruction", "tree_sha256")
      errors << "rust-v8: reproducibility source closure kind does not match" unless reproducibility.dig("recursive_source", "closure_kind") == closure_scope["kind"]
      errors << "rust-v8: reproducibility metadata overclaims a full DEPS checkout" unless reproducibility.dig("recursive_source", "full_deps_checkout_verified") == false
      unless reproducibility.dig("recursive_source", "selected_build_dependency_closure_verified") == false
        errors << "rust-v8: reproducibility metadata overclaims selected-build dependency closure"
      end
      errors << "rust-v8: reproducibility metadata omits the generated filtered source" unless reproducibility.dig("recursive_source", "recursive_rpm_source_generated") == true
      errors << "rust-v8: reproducibility direct-source count does not match" unless reproducibility.dig("recursive_source", "direct_public_rpm_sources") == 20
      errors << "rust-v8: reproducibility generated-source count does not match" unless reproducibility.dig("recursive_source", "generated_filtered_rpm_sources") == 1
      unless reproducibility.dig("recursive_source", "archive_transport_identity_required") == false
        errors << "rust-v8: reproducibility metadata requires generated transport identity"
      end
      unless reproducibility.dig("recursive_source", "source_filter_receipt") == source_filter_name &&
             reproducibility.dig("recursive_source", "source_filter_receipt_sha256") == source_filter_sha256
        errors << "rust-v8: reproducibility source-filter receipt does not match"
      end
      errors << "rust-v8: reproducibility license candidate count does not match" unless reproducibility.dig("licenses", "candidate_license_files") == license_summary["license_candidate_files"]
      errors << "rust-v8: reproducibility vendored Rust source count does not match" unless reproducibility.dig("licenses", "vendored_rust_source_packages") == license_summary["vendored_rust_source_packages"]
      errors << "rust-v8: reproducibility vendored Rust placeholder count does not match" unless reproducibility.dig("licenses", "vendored_rust_placeholders") == license_summary["vendored_rust_placeholders"]
      errors << "rust-v8: reproducibility declared license-path count does not match" unless reproducibility.dig("licenses", "readme_chromium_declared_license_paths") == license_summary["readme_chromium_declared_license_paths"]
      errors << "rust-v8: reproducibility verified license-path count does not match" unless reproducibility.dig("licenses", "readme_chromium_verified_declared_license_paths") == license_summary["readme_chromium_verified_declared_license_paths"]
      errors << "rust-v8: reproducibility ambiguous-license count does not match" unless reproducibility.dig("licenses", "readme_chromium_ambiguous_comma_licenses") == license_summary["readme_chromium_ambiguous_comma_licenses"]
      errors << "rust-v8: reproducibility legacy-BSD count does not match" unless reproducibility.dig("licenses", "readme_chromium_legacy_bsd_licenses") == license_summary["readme_chromium_legacy_bsd_licenses"]
      errors << "rust-v8: reproducibility unmaterialized license-path count does not match" unless reproducibility.dig("licenses", "readme_chromium_unmaterialized_declared_license_paths") == license_summary["readme_chromium_unmaterialized_declared_license_paths"]
      errors << "rust-v8: reproducibility legacy-slash count does not match" unless reproducibility.dig("licenses", "vendored_rust_legacy_slash_license_expressions") == license_summary["vendored_rust_legacy_slash_license_expressions"]
      errors << "rust-v8: reproducibility proposed-normalization count does not match" unless reproducibility.dig("licenses", "readme_chromium_proposed_normalizations") == license_summary["readme_chromium_proposed_normalizations"]
      errors << "rust-v8: reproducibility mechanical-normalization count does not match" unless reproducibility.dig("licenses", "vendored_rust_mechanically_normalized_license_expressions") == license_summary["vendored_rust_mechanically_normalized_license_expressions"]
      errors << "rust-v8: reproducibility Fedora exact-version count does not match" unless reproducibility.dig("licenses", "vendored_rust_fedora_exact_version_matches") == license_summary["vendored_rust_fedora_exact_version_matches"]
      errors << "rust-v8: reproducibility Fedora version-different count does not match" unless reproducibility.dig("licenses", "vendored_rust_fedora_version_different_matches") == license_summary["vendored_rust_fedora_version_different_matches"]
      errors << "rust-v8: reproducibility Fedora absent count does not match" unless reproducibility.dig("licenses", "vendored_rust_fedora_absent") == license_summary["vendored_rust_fedora_absent"]
      errors << "rust-v8: reproducibility Git-component license inventory is incomplete" unless reproducibility.dig("licenses", "git_component_inventory_complete") == true
      errors << "rust-v8: reproducibility Fedora license metadata is incomplete" unless reproducibility.dig("licenses", "fedora_exact_version_license_metadata_recorded") == true
      errors << "rust-v8: reproducibility metadata overclaims selected linkage" unless reproducibility.dig("licenses", "linked_archive_selection_verified") == false
      unless reproducibility.dig("licenses", "static_receipt") == static_license_name &&
             reproducibility.dig("licenses", "static_receipt_sha256") == static_license_sha256
        errors << "rust-v8: reproducibility static-license receipt does not match"
      end
      errors << "rust-v8: reproducibility static object count does not match" unless reproducibility.dig("licenses", "selected_archive_objects") == 1_795
      errors << "rust-v8: reproducibility static text count does not match" unless reproducibility.dig("licenses", "required_license_texts") == 24
      errors << "rust-v8: reproducibility required texts are not verified" unless reproducibility.dig("licenses", "required_texts_verified") == true
      errors << "rust-v8: reproducibility Fedora SPDX status is incomplete" unless reproducibility.dig("licenses", "fedora_allowed_spdx_verified") == true
      errors << "rust-v8: reproducibility prototype static license is incomplete" unless reproducibility.dig("licenses", "prototype_static_archive_license_complete") == true
      unless reproducibility.dig("licenses", "production_static_archive_license_complete") == false
        errors << "rust-v8: reproducibility overclaims production static licensing"
      end
      expected_builds = %w[
        fedora_43_x86_64 fedora_43_aarch64 fedora_44_x86_64
        fedora_44_aarch64 rawhide_x86_64 rawhide_aarch64
      ].to_h { |target| [target, { "status" => "passed-copr-build-10757049" }] }
      errors << "rust-v8: reproducibility build matrix does not match" unless reproducibility["builds"] == expected_builds
      expected_copr = {
        "package_definition" => 3_178_860,
        "build" => 10_757_049,
        "enabled" => false,
        "package_build_networking" => false,
        "all_targets_succeeded" => true
      }
      errors << "rust-v8: reproducibility COPR evidence does not match" unless reproducibility["copr"] == expected_copr
    else
      errors << "rust-v8: reproducibility metadata is missing"
    end

    errors
  rescue JSON::ParserError, KeyError => e
    errors << "rust-v8: invalid evidence receipt: #{e.message}"
  end

  def validate_bun_dependency_closure(package, dependency_stage, webkit, version)
    return [] unless package.name == "bun" && dependency_stage.is_a?(Hash)
    return [] if dependency_stage["historical_only"] == true

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
    errors << "bun: unsupported dependency-closure proof receipt schema" unless receipt["schema"] == "bun-release-local-source-closure/v3"
    errors << "bun: dependency-closure proof package mismatch" unless receipt["package"] == "bun"
    errors << "bun: dependency-closure proof release mismatch" unless receipt["release"].to_s == version

    hosting_verified = receipt.dig("validation", "immutable_public_hosting_verified")
    local_webkit = Array(receipt["existing_local_sources"]).find { |source| source.is_a?(Hash) && source["symbol"] == "webkit" }
    # This receipt covers the canonical full WebKit source and local dependency
    # closure. The separately hosted minimized WebKit source has its own validator.
    errors << "bun: dependency-closure proof incorrectly claims immutable public hosting" unless hosting_verified == false
    errors << "bun: dependency-closure proof has hosted WebKit archive" unless webkit.is_a?(Hash) && webkit["archive_url"].nil?
    errors << "bun: dependency-closure proof hosted local-source record" unless local_webkit.is_a?(Hash) && local_webkit["immutable_public_url"].nil?
    errors << "bun: dependency-closure proof retains a private Cargo graph" if receipt.key?("cargo")
    errors << "bun: dependency-closure system lol-html selection is missing" unless receipt.dig("validation", "system_lolhtml_provider_selected") == true
    errors << "bun: dependency-closure private lol-html source is not excluded" unless receipt.dig("validation", "private_lolhtml_source_excluded") == true
    expected_counts = {
      "selected_github_archives" => Array(receipt["native_github_sources"]).length,
      "selected_node_header_archives" => receipt["node_headers"].is_a?(Hash) ? 1 : 0,
      "unique_npm_source_archives" => Array(receipt.dig("npm", "source_archives")).length,
      "selected_cargo_source_archives" => 0
    }
    errors << "bun: dependency-closure source counts mismatch" unless expected_counts.all? { |key, value| dependency_stage[key] == value }

    errors
  rescue JSON::ParserError => e
    errors << "bun: invalid dependency-closure proof receipt: #{e.message}"
  end

  def validate_bun_npm_offline_install(package, dependency_stage, version)
    return [] unless package.name == "bun" && dependency_stage.is_a?(Hash)
    return [] if dependency_stage["historical_only"] == true
    return [] unless dependency_stage.key?("npm_install_proof_receipt")

    receipt_name = dependency_stage["npm_install_proof_receipt"]
    receipt_path = receipt_name.is_a?(String) && File.join(package.directory, receipt_name)
    expected_sha256 = dependency_stage["npm_install_proof_receipt_sha256"]
    unless receipt_path && File.file?(receipt_path) && expected_sha256.to_s.match?(/\A[0-9a-f]{64}\z/) &&
           Digest::SHA256.file(receipt_path).hexdigest == expected_sha256
      return ["bun: npm-install proof receipt is missing or has wrong SHA-256"]
    end

    errors = []
    receipt = JSON.parse(File.read(receipt_path))
    current_source_driver = receipt["schema"] == "bun-npm-offline-install-proof/v2"
    errors << "bun: unsupported npm-install proof receipt schema" unless %w[bun-npm-offline-install-proof/v1 bun-npm-offline-install-proof/v2].include?(receipt["schema"])
    errors << "bun: npm-install proof package mismatch" unless receipt["package"] == "bun"
    errors << "bun: npm-install proof release mismatch" unless receipt["release"].to_s == version
    errors << "bun: npm-install proof target mismatch" unless receipt["target"] == { "os" => "linux", "cpu" => "x64", "libc" => "glibc" }

    closure = receipt["source_closure"] || {}
    errors << "bun: npm-install proof source-closure path mismatch" unless closure["path"] == dependency_stage["proof_receipt"]
    errors << "bun: npm-install proof source-closure SHA-256 mismatch" unless closure["sha256"] == dependency_stage["proof_receipt_sha256"]
    errors << "bun: npm-install proof Bun source mismatch" unless closure["bun_source_archive_sha256"] == package.upstream["source_sha256"]

    cache = receipt["cache"] || {}
    errors << "bun: npm-install proof source count mismatch" unless cache["source_archives"] == dependency_stage["unique_npm_source_archives"]
    errors << "bun: npm-install proof cache count mismatch" unless cache["materialized_entries"] == dependency_stage["npm_cache_entries"]
    errors << "bun: npm-install proof cache source split mismatch" unless cache["registry_archives"].to_i + cache["github_archives"].to_i == cache["source_archives"]
    errors << "bun: npm-install proof cache tree mismatch" unless cache.dig("tree", "sha256") == dependency_stage["npm_cache_tree_sha256"]

    install = receipt["install"] || {}
    install_controls = %w[network_namespace frozen_lockfile ignore_scripts serialized]
    errors << "bun: npm-install proof install controls are incomplete" unless install_controls.all? { |key| install[key] == true }
    errors << "bun: current npm-install proof driver kind mismatch" if current_source_driver && install["driver_kind"] != "source_built"
    expected_roots = [[".", "bun"], ["packages/bun-error", "bun-error"], ["src/node-fallbacks", "fallbacks"]]
    install_roots = Array(install["install_roots"])
    errors << "bun: npm-install proof root set mismatch" unless install_roots.map { |root| root.is_a?(Hash) ? [root["path"], root["package_name"]] : nil } == expected_roots
    valid_roots = install_roots.all? do |root|
      node_modules = root.is_a?(Hash) && root["node_modules"]
      node_modules.is_a?(Hash) && node_modules["entries"].is_a?(Integer) && node_modules["entries"].positive? &&
        node_modules["files"].is_a?(Integer) && node_modules["files"].positive? &&
        node_modules["sha256"].to_s.match?(/\A[0-9a-f]{64}\z/)
    end
    errors << "bun: npm-install proof root inventories are invalid" unless valid_roots

    stage_claims = %w[
      npm_cache_materialization_verified npm_offline_install_verified
      npm_frozen_lockfile_verified npm_ignore_scripts_verified
      npm_network_namespace_verified
    ]
    errors << "bun: npm-install stage metadata is incomplete" unless stage_claims.all? { |key| dependency_stage[key] == true }
    validation = receipt["validation"] || {}
    required_validation = %w[source_files_unchanged seed_absent_from_node_modules npm_cache_materialization_verified npm_offline_install_verified]
    errors << "bun: npm-install proof validation is incomplete" unless required_validation.all? { |key| validation[key] == true }
    errors << "bun: npm-install proof overclaims complete Bun materialization" unless validation["complete_bun_offline_materialization_verified"] == false
    errors << "bun: npm-install proof incorrectly claims dependency resolution" unless validation["dependency_resolution_performed"] == false
    errors << "bun: npm-install proof incorrectly claims a full Bun build" unless validation["full_bun_build_performed"] == false
    if current_source_driver
      errors << "bun: current npm-install proof validation is incomplete" unless %w[source_built_driver_verified driver_receipt_bound driver_version_verified bootstrap_seed_not_used_for_install].all? { |key| validation[key] == true }
      driver = receipt["driver"]
      proof_kind = driver.is_a?(Hash) && driver["proof_kind"]
      stage_name = proof_kind == "self_rebuild" ? "self_rebuild" : "seed_build"
      stages = package.data.dig("build_plan", "stages")
      build_stage = stages.is_a?(Hash) && stages[stage_name]
      valid_kind = %w[first_build self_rebuild].include?(proof_kind)
      valid_stage = build_stage.is_a?(Hash) && build_stage["state"] == "verified" && build_stage["historical_only"] != true
      errors << "bun: current npm-install proof driver stage mismatch" unless valid_kind && valid_stage &&
        driver["kind"] == "source_built" && driver["receipt"] == build_stage["proof_receipt"] &&
        driver["receipt_sha256"] == build_stage["proof_receipt_sha256"] && driver["version"] == version

      driver_receipt_name = driver.is_a?(Hash) && driver["receipt"]
      driver_receipt_path = driver_receipt_name.is_a?(String) && File.join(package.directory, driver_receipt_name)
      if driver_receipt_path && File.file?(driver_receipt_path)
        driver_receipt_sha256 = Digest::SHA256.file(driver_receipt_path).hexdigest
        errors << "bun: current npm-install driver receipt SHA-256 mismatch" unless driver["receipt_sha256"] == driver_receipt_sha256
        driver_receipt = JSON.parse(File.read(driver_receipt_path))
        expected_schema = proof_kind == "self_rebuild" ? "bun-self-rebuild-proof/v2" : "bun-first-source-build-proof/v2"
        errors << "bun: current npm-install driver receipt schema mismatch" unless driver_receipt["schema"] == expected_schema
        errors << "bun: current npm-install driver receipt identity mismatch" unless driver_receipt["package"] == "bun" && driver_receipt["release"] == version && driver_receipt["profile"] == "release-local"
        errors << "bun: current npm-install driver source closure mismatch" unless driver_receipt.dig("source_closure", "path") == dependency_stage["proof_receipt"] && driver_receipt.dig("source_closure", "sha256") == dependency_stage["proof_receipt_sha256"]
        output = driver_receipt.dig("build", "bun")
        errors << "bun: current npm-install driver binary mismatch" unless output.is_a?(Hash) && driver["size_bytes"] == output["size_bytes"] && driver["sha256"] == output["sha256"]
        output_path = output.is_a?(Hash) && output["path"]
        proof_root = driver["proof_root"]
        driver_path = driver["path"]
        valid_paths = output_path.is_a?(String) && !Pathname.new(output_path).absolute? && !Pathname.new(output_path).each_filename.include?("..") &&
                      proof_root.is_a?(String) && Pathname.new(proof_root).absolute? && proof_root.start_with?("/srv/tmp/") && Pathname.new(proof_root).cleanpath.to_s == proof_root &&
                      driver_path.is_a?(String) && Pathname.new(driver_path).absolute? && Pathname.new(driver_path).cleanpath.to_s == driver_path &&
                      driver_path.start_with?("#{proof_root}/") && driver_path.end_with?("/#{output_path}")
        errors << "bun: current npm-install driver paths are invalid" unless valid_paths
      else
        errors << "bun: current npm-install driver receipt is missing: #{driver_receipt_name.inspect}"
      end

      seed = package.data.dig("build_plan", "source_inputs", "bootstrap_seed")
      forbidden_seed = receipt["forbidden_bootstrap_seed"]
      valid_forbidden_seed = seed.is_a?(Hash) && forbidden_seed.is_a?(Hash) &&
                             forbidden_seed["binary_sha256"] == seed["binary_sha256"] &&
                             forbidden_seed["size_bytes"] == seed["binary_size_bytes"] &&
                             forbidden_seed["payload_allowed"] == false && forbidden_seed["runtime_dependency_allowed"] == false
      errors << "bun: current npm-install forbidden seed mismatch" unless valid_forbidden_seed
    end
    errors
  rescue JSON::ParserError, TypeError => e
    ["bun: invalid npm-install proof receipt: #{e.message}"]
  end

  def validate_bun_system_lolhtml(package, lolhtml, stages, version, spec)
    return [] unless package.name == "bun"
    return [] unless lolhtml.is_a?(Hash) && lolhtml["relationship"] == "fedora_system_provider"

    errors = []
    expected = {
      "relationship" => "fedora_system_provider",
      "release_pin" => "bun-v#{version}",
      "repository" => "cloudflare/lol-html",
      "package" => "lol-html",
      "version" => "3.0.0",
      "c_api_version" => "1.4.0",
      "commit" => "02f139c4437b2da666a50d32e11d9158cbe0a393",
      "source_sha256" => "41ed4231fd05b1c73c0664f1f05f18b0d96a34aabf488e6cb601c3bdc7306af9",
      "header_sha256" => "7fe574ddaad36931ee4d72a43c0cf375e3b697b94ab4c137fe58d8643c402293",
      "pkgconfig" => "lol-html",
      "soname" => "liblolhtml.so.1",
      "build_requirement" => "pkgconfig(lol-html) >= 1.4.0",
      "provider_matrix_verified" => true,
      "static_library_shipped" => false,
      "glibc_system_link" => true,
      "non_glibc_bundled_path_preserved" => true,
      "memory_settings_abi_updated" => true,
      "take_last_error_prototype_updated" => true,
      "graceful_bail_out_default" => false,
      "patch_applies_zero_fuzz" => true
    }
    errors << "bun: system lol-html provider metadata mismatch" unless expected.all? { |key, value| lolhtml[key] == value }

    historical = lolhtml["historical_bundled_source"]
    expected_historical = {
      "commit" => "77127cd2b8545998756e8d64e36ee2313c4bb312",
      "source_archive" => "lolhtml-929339b1d898e66b.tar.gz",
      "source_sha256" => "2c53161edf633fa99acfc4eafddbafd5d9b8199f0918a1cc9152cb6c2c9bf379",
      "source_identity" => "712928b3736f4aad",
      "manifest_sha256" => "feebef6f9b726f63b58bfad3bbc0a8a81667fbaf4e4111dc1a4e8f79b83e9f03",
      "lockfile_sha256" => "02d28352293be00f05be457e59e60d5b9d7e84a4cdc43bd40236a12bf8d1e53d",
      "source_commit" => "ed1cc04702f7b609a8a735edf0a1cc7c33ec22c5",
      "source_receipt_path_at_commit" => "packages/bun/bun-1.3.14-release-local-source-closure.json",
      "source_receipt_sha256" => "ee3ed17e495779441326d10cd8d7f07a21b856285abc0f41ef9e5be6f99abbe0"
    }
    errors << "bun: historical lol-html source metadata mismatch" unless historical.is_a?(Hash) && expected_historical.all? { |key, value| historical[key] == value }

    patch_name = lolhtml["patch"]
    patch_path = patch_name.is_a?(String) && File.join(package.directory, patch_name)
    patch_sha256 = lolhtml["patch_sha256"]
    valid_patch = patch_path && File.file?(patch_path) && patch_sha256.to_s.match?(/\A[0-9a-f]{64}\z/) &&
                  Digest::SHA256.file(patch_path).hexdigest == patch_sha256
    errors << "bun: system lol-html patch is missing or has wrong SHA-256" unless valid_patch
    if valid_patch
      patch = File.read(patch_path)
      required_patch_fragments = [
        'return cfg.linux && cfg.abi !== "android" && cfg.abi !== "musl";',
        'libs.push("-llolhtml")',
        'versions.push(["LOLHTML", "3.0.0"])',
        'graceful_bail_out_on_memory_limit_exceeded: bool',
        '.graceful_bail_out_on_memory_limit_exceeded = false',
        'pub extern fn lol_html_take_last_error() HTMLString;',
        'process.platform === "linux" && familySync() !== "musl"'
      ]
      errors << "bun: system lol-html patch contract is incomplete" unless required_patch_fragments.all? { |fragment| patch.include?(fragment) }
    end

    provider = package_named("lol-html")
    valid_provider = provider.enabled? && provider.upstream["current_version"] == "3.0.0" &&
                     provider.data.dig("c_api", "crate_version") == "1.4.0" &&
                     provider.data.dig("c_api", "soname") == "liblolhtml.so.1" &&
                     provider.data.dig("c_api", "static_library_shipped") == false &&
                     provider.data.dig("build_validation", "mock_matrix", "fedora_43_x86_64") == "passed" &&
                     provider.data.dig("build_validation", "mock_matrix", "fedora_43_aarch64") == "passed" &&
                     provider.data.dig("build_validation", "mock_matrix", "fedora_44_x86_64") == "passed" &&
                     provider.data.dig("build_validation", "mock_matrix", "fedora_44_aarch64") == "passed" &&
                     provider.data.dig("build_validation", "mock_matrix", "fedora_rawhide_x86_64") == "passed" &&
                     provider.data.dig("build_validation", "mock_matrix", "fedora_rawhide_aarch64") == "passed"
    errors << "bun: system lol-html provider package contract mismatch" unless valid_provider

    source_license_inventory = package.data.dig("build_plan", "source_inputs", "source_license_inventory")
    valid_license_boundary = source_license_inventory.is_a?(Hash) &&
                              source_license_inventory["historical_lolhtml_graph_retained"] == false &&
                              source_license_inventory["system_lolhtml_provider_external"] == true &&
                             source_license_inventory["final_linked_closure_verified"] == false &&
                             source_license_inventory["final_license_expression_verified"] == false
    errors << "bun: system lol-html source-license boundary mismatch" unless valid_license_boundary

    required_spec_fragments = [
      "Patch2:         bun-system-lolhtml.patch",
      "BuildRequires:  pkgconfig(lol-html) >= 1.4.0",
      "pkg-config --exact-version=1.4.0 lol-html",
      "grep -Fq 'pub extern fn lol_html_take_last_error() HTMLString;'"
    ]
    errors << "bun: spec does not integrate the system lol-html split" unless required_spec_fragments.all? { |fragment| spec.include?(fragment) }
    forbidden_spec_fragments = ["lolhtml-929339b1d898e66b.tar.gz", "lolhtml-cargo-vendor.tar.gz", "%cargo_build", "%cargo_vendor_manifest", "target/release/liblolhtml.a"]
    errors << "bun: spec still builds the historical private lol-html library" if forbidden_spec_fragments.any? { |fragment| spec.include?(fragment) }

    current_graph_valid = stages.is_a?(Hash) && stages.dig("dependency_closure", "state") == "verified" &&
                          %w[blocked verified].include?(stages.dig("source_delivery", "state")) &&
                          stages.dig("source_delivery", "historical_only") != true &&
                          %w[blocked verified].include?(stages.dig("dependency_staging", "state")) &&
                          stages.dig("dependency_staging", "historical_only") != true
    errors << "bun: system lol-html current source stages are inconsistent" unless current_graph_valid
    historical_stage = lambda do |stage|
      stage.is_a?(Hash) && stage["state"] == "blocked" && stage["historical_only"] == true &&
        stage["invalidated_by"].is_a?(String) && !stage["invalidated_by"].empty?
    end
    current_or_historical_stage = lambda do |stage|
      historical_stage.call(stage) || (stage.is_a?(Hash) && %w[blocked verified].include?(stage["state"]) && stage["historical_only"] != true)
    end
    valid_invalidation = stages.is_a?(Hash) && historical_stage.call(stages["lolhtml_rpm_cargo"]) &&
                           current_or_historical_stage.call(stages["seed_build"]) && current_or_historical_stage.call(stages["self_rebuild"])
    errors << "bun: system lol-html split did not invalidate historical build stages" unless valid_invalidation
    errors << "bun: system lol-html source closure is not regenerated" unless package.data.dig("build_plan", "system_lolhtml_source_closure_regenerated") == true

    errors
  rescue KeyError => e
    errors << "bun: invalid system lol-html provider metadata: #{e.message}"
  end

  def validate_bun_source_delivery(package, stage, dependency_stage, version, spec)
    return [] unless package.name == "bun" && stage.is_a?(Hash) && stage["state"] == "verified"

    errors = []
    receipt_name = stage["proof_receipt"]
    receipt_path = receipt_name.is_a?(String) && File.join(package.directory, receipt_name)
    expected_sha256 = stage["proof_receipt_sha256"]
    unless receipt_path && File.file?(receipt_path) && expected_sha256.to_s.match?(/\A[0-9a-f]{64}\z/) &&
           Digest::SHA256.file(receipt_path).hexdigest == expected_sha256
      return ["bun: source-delivery proof receipt is missing or has wrong SHA-256"]
    end

    receipt = JSON.parse(File.read(receipt_path))
    errors << "bun: unsupported source-delivery proof schema" unless receipt["schema"] == "bun-srpm-source-delivery/v2"
    errors << "bun: source-delivery proof package mismatch" unless receipt["package"] == "bun"
    errors << "bun: source-delivery proof release mismatch" unless receipt["release"].to_s == version
    spec_release = spec[/^Release:\s+([^%\s]+)/, 1]
    errors << "bun: source-delivery proof RPM release mismatch" unless receipt["rpm_release"] == spec_release
    errors << "bun: source-delivery proof platform mismatch" unless receipt["proof_platform"] == "fedora-44-x86_64"
    errors << "bun: source-delivery spec SHA-256 mismatch" unless receipt.dig("spec", "sha256") == Digest::SHA256.hexdigest(spec)
    errors << "bun: source-delivery spec size mismatch" unless receipt.dig("spec", "size_bytes") == spec.bytesize

    generation = receipt.fetch("source_generation", {})
    errors << "bun: source-delivery method mismatch" unless generation["method"] == "copr-git-scm-make_srpm"
    errors << "bun: source-delivery network scope mismatch" unless generation["network_scope"] == "srpm-generation-only"
    expected_counts = {
      "direct_sources" => 22,
      "generated_sources" => 1,
      "packaging_sources" => 6,
      "declared_sources" => 29,
      "patches" => 6
    }
    errors << "bun: source-delivery source counts mismatch" unless generation.slice(*expected_counts.keys) == expected_counts
    errors << "bun: source-delivery closure count mismatch" unless generation["canonical_closure_inputs"] == 255
    errors << "bun: source-delivery closure SHA-256 mismatch" unless generation["canonical_closure_sha256"] == dependency_stage["proof_receipt_sha256"]
    expected_npm = {
      "filename" => dependency_stage["npm_source_archive_filename"],
      "size_bytes" => dependency_stage["npm_source_archive_bytes"],
      "sha256" => dependency_stage["npm_source_archive_sha256"]
    }
    errors << "bun: source-delivery npm archive mismatch" unless generation["npm_archive"] == expected_npm
    errors << "bun: source-delivery proof retains a Cargo archive" if generation.key?("cargo_archive")
    errors << "bun: source-delivery proof retains retired lol-html inputs" unless generation["retired_lolhtml_inputs_absent"] == true
    license_inventory = package.data.dig("build_plan", "source_inputs", "source_license_inventory") || {}
    expected_license_inventory = {
      "filename" => license_inventory["source"],
      "size_bytes" => File.file?(File.join(package.directory, license_inventory["source"].to_s)) ? File.size(File.join(package.directory, license_inventory["source"])) : nil,
      "sha256" => license_inventory["sha256"]
    }
    errors << "bun: source-delivery license inventory mismatch" unless generation["source_license_inventory"] == expected_license_inventory
    expected_license_audit_script = {
      "filename" => license_inventory["audit_script_source"],
      "size_bytes" => File.file?(script_path = File.join(ROOT, license_inventory["audit_script"].to_s)) ? File.size(script_path) : nil,
      "sha256" => license_inventory["audit_script_sha256"]
    }
    errors << "bun: source-delivery license audit script mismatch" unless generation["source_license_audit_script"] == expected_license_audit_script
    final_license = package.data.dig("build_plan", "source_inputs", "final_linked_license_closure") || {}
    expected_final_license = {
      "filename" => final_license["source"],
      "size_bytes" => File.file?(File.join(package.directory, final_license["source"].to_s)) ? File.size(File.join(package.directory, final_license["source"])) : nil,
      "sha256" => final_license["sha256"]
    }
    errors << "bun: source-delivery final linked-license closure mismatch" unless generation["final_linked_license_closure"] == expected_final_license
    expected_final_audit_script = {
      "filename" => final_license["audit_script_source"],
      "size_bytes" => File.file?(script_path = File.join(ROOT, final_license["audit_script"].to_s)) ? File.size(script_path) : nil,
      "sha256" => final_license["audit_script_sha256"]
    }
    errors << "bun: source-delivery final linked-license audit script mismatch" unless generation["final_linked_license_audit_script"] == expected_final_audit_script

    srpm = receipt.fetch("srpm", {})
    errors << "bun: source-delivery SRPM filename mismatch" unless srpm["filename"] == "bun-#{version}-#{spec_release}.fc44.src.rpm"
    errors << "bun: source-delivery SRPM size is invalid" unless srpm["size_bytes"].is_a?(Integer) && srpm["size_bytes"].positive?
    errors << "bun: source-delivery SRPM SHA-256 is invalid" unless srpm["sha256"].to_s.match?(/\A[0-9a-f]{64}\z/)
    errors << "bun: source-delivery SRPM digest check failed" unless srpm["digest_check"] == "ok"
    errors << "bun: source-delivery SRPM inventory mismatch" unless srpm["inventory_members"] == 36
    %w[inventory_sha256 member_manifest_sha256].each do |key|
      errors << "bun: source-delivery #{key} is invalid" unless srpm[key].to_s.match?(/\A[0-9a-f]{64}\z/)
    end

    required_validation = %w[
      direct_source_checksums_verified
      canonical_closure_regenerated_verified
      canonical_closure_byte_identity_verified
      generated_source_checksums_verified
      packaging_source_checksums_verified
      deterministic_materialization_verified
      retired_lolhtml_inputs_absent
      srpm_built
      srpm_inventory_verified
      source_members_byte_identical
    ]
    errors << "bun: source-delivery validation is incomplete" unless required_validation.all? { |key| receipt.dig("validation", key) == true }
    errors << "bun: source-delivery proof incorrectly claims an RPM build" unless receipt.dig("validation", "rpm_build_executed") == false
    errors << "bun: source-delivery proof incorrectly claims RPM installation" unless receipt.dig("validation", "rpm_installed") == false

    source_indexes = spec.scan(/^Source(?<index>\d*):\s+/).map { |match| match.first.empty? ? 0 : Integer(match.first, 10) }
    errors << "bun: spec does not declare the complete Source0-Source28 layout" unless source_indexes == (0..28).to_a
    npm_spec_filename = expected_npm["filename"].sub(version, "%{version}")
    errors << "bun: spec npm source filename mismatch" unless spec.match?(/^Source22:\s+#{Regexp.escape(npm_spec_filename)}$/)
    staging = package.data.dig("build_plan", "source_inputs", "release_local_staging") || {}
    errors << "bun: spec closure source filename mismatch" unless spec.match?(/^Source23:\s+#{Regexp.escape(staging["closure_source"].to_s.gsub(version, "%{version}"))}$/)
    errors << "bun: spec staging helper filename mismatch" unless spec.match?(/^Source24:\s+#{Regexp.escape(staging["helper_source"].to_s)}$/)
    errors << "bun: spec source-license inventory filename mismatch" unless spec.match?(/^Source25:\s+#{Regexp.escape(license_inventory["source"].to_s.gsub(version, "%{version}"))}$/)
    errors << "bun: spec source-license audit script mismatch" unless spec.match?(/^Source26:\s+#{Regexp.escape(license_inventory["audit_script_source"].to_s)}$/)
    errors << "bun: spec final linked-license closure filename mismatch" unless spec.match?(/^Source27:\s+#{Regexp.escape(final_license["source"].to_s.gsub(version, "%{version}"))}$/)
    errors << "bun: spec final linked-license audit script mismatch" unless spec.match?(/^Source28:\s+#{Regexp.escape(final_license["audit_script_source"].to_s)}$/)
    errors
  rescue JSON::ParserError, KeyError => e
    errors << "bun: invalid source-delivery proof receipt: #{e.message}"
  end

  def validate_bun_lolhtml_rpm_cargo(package, stage, dependency_stage, lolhtml, version, spec)
    return [] unless package.name == "bun" && stage.is_a?(Hash) && stage["state"] == "verified"

    receipt_name = stage["proof_receipt"]
    receipt_path = receipt_name.is_a?(String) && File.join(package.directory, receipt_name)
    expected_sha256 = stage["proof_receipt_sha256"]
    unless receipt_path && File.file?(receipt_path) && expected_sha256.to_s.match?(/\A[0-9a-f]{64}\z/) &&
           Digest::SHA256.file(receipt_path).hexdigest == expected_sha256
      return ["bun: lol-html RPM Cargo proof receipt is missing or has wrong SHA-256"]
    end

    errors = []
    receipt = JSON.parse(File.read(receipt_path))
    errors << "bun: unsupported lol-html RPM Cargo proof schema" unless receipt["schema"] == "bun-lolhtml-rpm-cargo-proof/v1"
    errors << "bun: lol-html RPM Cargo proof package mismatch" unless receipt["package"] == "bun"
    errors << "bun: lol-html RPM Cargo proof release mismatch" unless receipt["release"].to_s == version
    spec_release = spec[/^Release:\s+([^%\s]+)/, 1]
    errors << "bun: lol-html RPM Cargo proof RPM release mismatch" unless receipt["rpm_release"] == spec_release
    errors << "bun: lol-html RPM Cargo proof platform mismatch" unless receipt["proof_platform"] == "fedora-44-x86_64"
    errors << "bun: lol-html RPM Cargo production spec SHA-256 mismatch" unless receipt.dig("production_spec", "sha256") == Digest::SHA256.hexdigest(spec)
    errors << "bun: lol-html RPM Cargo production spec size mismatch" unless receipt.dig("production_spec", "size_bytes") == spec.bytesize

    source = receipt.dig("inputs", "lolhtml_source") || {}
    expected_source = {
      "filename" => lolhtml["source_archive"],
      "sha256" => lolhtml["source_sha256"],
      "source_identity" => lolhtml["source_identity"],
      "manifest_sha256" => lolhtml["manifest_sha256"],
      "lockfile_sha256" => lolhtml["lockfile_sha256"]
    }
    expected_source.each do |key, value|
      errors << "bun: lol-html RPM Cargo source #{key} mismatch" unless source[key] == value
    end
    vendor = receipt.dig("inputs", "cargo_vendor") || {}
    errors << "bun: lol-html RPM Cargo vendor filename mismatch" unless vendor["filename"] == dependency_stage["cargo_vendor_archive_filename"]
    errors << "bun: lol-html RPM Cargo vendor size mismatch" unless vendor["size_bytes"] == dependency_stage["cargo_vendor_archive_bytes"]
    errors << "bun: lol-html RPM Cargo vendor SHA-256 mismatch" unless vendor["sha256"] == dependency_stage["cargo_vendor_archive_sha256"]
    errors << "bun: lol-html RPM Cargo vendor directory count mismatch" unless vendor["directory_count"] == stage["vendor_directory_count"]

    build = receipt["build"] || {}
    errors << "bun: lol-html RPM Cargo job count mismatch" unless build["jobs"] == 4
    %w[network_namespace cargo_offline cargo_prep_vendor_mode cargo_build_macro cargo_vendor_manifest_macro].each do |key|
      errors << "bun: lol-html RPM Cargo proof lacks #{key}" unless build[key] == true
    end
    library = build["static_library"] || {}
    errors << "bun: lol-html RPM Cargo static library path mismatch" unless library["path"] == "vendor/lolhtml/c-api/target/release/liblolhtml.a"
    errors << "bun: lol-html RPM Cargo static library size is invalid" unless library["size_bytes"].is_a?(Integer) && library["size_bytes"].positive?
    errors << "bun: lol-html RPM Cargo static library SHA-256 is invalid" unless library["sha256"].to_s.match?(/\A[0-9a-f]{64}\z/)
    symbols = build["exported_c_api_symbols"] || {}
    errors << "bun: lol-html RPM Cargo C API symbol count mismatch" unless symbols["count"] == 97
    errors << "bun: lol-html RPM Cargo C API symbol SHA-256 mismatch" unless symbols["sha256"] == "e27bce50176d5cd8a6861a760adcc324101b1eaec087027fa48691380df2cd70"
    manifest = build["vendor_manifest"] || {}
    errors << "bun: lol-html RPM Cargo linked vendor count mismatch" unless manifest["linked_package_count"] == stage["linked_vendor_package_count"]
    errors << "bun: lol-html RPM Cargo linked vendor manifest mismatch" unless manifest["sha256"] == stage["linked_vendor_manifest_sha256"]
    errors << "bun: lol-html RPM Cargo local path normalization mismatch" unless manifest["local_path_records_normalized"] == 1

    required_validation = %w[
      source_checksums_verified
      manifest_and_lock_verified
      vendor_directory_count_verified
      fedora_cargo_prep_verified
      fedora_cargo_build_verified
      fedora_vendor_manifest_verified
      network_isolation_verified
      static_library_verified
      exported_c_api_verified
      production_spec_integration_verified
    ]
    errors << "bun: lol-html RPM Cargo validation is incomplete" unless required_validation.all? { |key| receipt.dig("validation", key) == true }
    errors << "bun: lol-html RPM Cargo proof incorrectly claims an RPM build" unless receipt.dig("validation", "rpm_build_executed") == false
    errors << "bun: lol-html RPM Cargo proof incorrectly claims RPM installation" unless receipt.dig("validation", "rpm_installed") == false

    required_spec_fragments = [
      "BuildRequires:  cargo-rpm-macros >= 24",
      "tar --extract --gzip --file %{SOURCE13} --strip-components=1 --directory vendor/lolhtml",
      "printf '%s\\n' '%{lolhtml_source_identity}' > vendor/lolhtml/.ref",
      "tar --extract --gzip --file %{SOURCE24} --directory vendor/lolhtml/c-api",
      "%cargo_prep -v cargo-vendor",
      "%cargo_build",
      "%cargo_vendor_manifest",
      "test \"$(wc -l < cargo-vendor.txt)\" -eq 41",
      "grep 'lol_html_'"
    ]
    errors << "bun: spec does not integrate the verified lol-html RPM Cargo stage" unless required_spec_fragments.all? { |fragment| spec.include?(fragment) }
    errors
  rescue JSON::ParserError => e
    ["bun: invalid lol-html RPM Cargo proof receipt: #{e.message}"]
  end

  def validate_bun_dependency_staging(package, stage, source_delivery_stage, dependency_stage, staging, version, spec)
    return [] unless package.name == "bun" && stage.is_a?(Hash) && stage["state"] == "verified"

    receipt_name = stage["proof_receipt"]
    receipt_path = receipt_name.is_a?(String) && File.join(package.directory, receipt_name)
    expected_sha256 = stage["proof_receipt_sha256"]
    unless receipt_path && File.file?(receipt_path) && expected_sha256.to_s.match?(/\A[0-9a-f]{64}\z/) &&
           Digest::SHA256.file(receipt_path).hexdigest == expected_sha256
      return ["bun: dependency-staging proof receipt is missing or has wrong SHA-256"]
    end

    errors = []
    receipt = JSON.parse(File.read(receipt_path))
    errors << "bun: unsupported dependency-staging proof schema" unless receipt["schema"] == "bun-release-local-source-staging-proof/v2"
    errors << "bun: dependency-staging proof package mismatch" unless receipt["package"] == "bun"
    errors << "bun: dependency-staging proof release mismatch" unless receipt["release"].to_s == version
    spec_release = spec[/^Release:\s+([^%\s]+)/, 1]
    errors << "bun: dependency-staging proof RPM release mismatch" unless receipt["rpm_release"] == spec_release
    errors << "bun: dependency-staging proof platform mismatch" unless receipt["proof_platform"] == "fedora-44-x86_64"
    errors << "bun: dependency-staging spec SHA-256 mismatch" unless receipt.dig("production_spec", "sha256") == Digest::SHA256.hexdigest(spec)
    errors << "bun: dependency-staging spec size mismatch" unless receipt.dig("production_spec", "size_bytes") == spec.bytesize

    closure = receipt.dig("inputs", "closure") || {}
    errors << "bun: dependency-staging closure filename mismatch" unless closure["filename"] == staging["closure_source"]
    errors << "bun: dependency-staging closure SHA-256 mismatch" unless closure["sha256"] == dependency_stage["proof_receipt_sha256"] && closure["sha256"] == staging["closure_sha256"]
    helper = receipt.dig("inputs", "helper") || {}
    errors << "bun: dependency-staging helper filename mismatch" unless helper["filename"] == staging["helper_source"]
    errors << "bun: dependency-staging helper SHA-256 mismatch" unless helper["sha256"] == staging["helper_sha256"]
    errors << "bun: dependency-staging helper size is invalid" unless helper["size_bytes"].is_a?(Integer) && helper["size_bytes"].positive?
    npm_bundle = receipt.dig("inputs", "npm_bundle") || {}
    errors << "bun: dependency-staging npm filename mismatch" unless npm_bundle["filename"] == dependency_stage["npm_source_archive_filename"]
    errors << "bun: dependency-staging npm size mismatch" unless npm_bundle["size_bytes"] == dependency_stage["npm_source_archive_bytes"]
    errors << "bun: dependency-staging npm SHA-256 mismatch" unless npm_bundle["sha256"] == dependency_stage["npm_source_archive_sha256"]

    source_delivery_name = source_delivery_stage["proof_receipt"]
    source_delivery_path = source_delivery_name.is_a?(String) && File.join(package.directory, source_delivery_name)
    if source_delivery_path && File.file?(source_delivery_path)
      source_delivery = JSON.parse(File.read(source_delivery_path))
      errors << "bun: dependency-staging SRPM does not match source delivery" unless receipt["srpm"]&.slice("filename", "size_bytes", "sha256", "digest_check") == source_delivery["srpm"]&.slice("filename", "size_bytes", "sha256", "digest_check")
    else
      errors << "bun: dependency-staging source-delivery receipt is missing"
    end

    prep = receipt["prep"] || {}
    errors << "bun: dependency-staging prep is not network isolated" unless prep["network_namespace"] == true
    %w[log_sha256].each do |key|
      errors << "bun: dependency-staging #{key} is invalid" unless prep[key].to_s.match?(/\A[0-9a-f]{64}\z/)
    end
    errors << "bun: dependency-staging prep log size is invalid" unless prep["log_size_bytes"].is_a?(Integer) && prep["log_size_bytes"].positive?
    errors << "bun: dependency-staging source-license inventory was not checked" unless prep["source_license_inventory_check"] == true
    errors << "bun: dependency-staging final linked-license closure was not checked" unless prep["final_linked_license_closure_check"] == true
    staged_receipt = prep["staging_receipt"] || {}
    errors << "bun: dependency-staging transient receipt SHA-256 is invalid" unless staged_receipt["sha256"].to_s.match?(/\A[0-9a-f]{64}\z/)
    errors << "bun: dependency-staging transient receipt size is invalid" unless staged_receipt["size_bytes"].is_a?(Integer) && staged_receipt["size_bytes"].positive?

    native = prep["native"] || {}
    errors << "bun: dependency-staging native source count mismatch" unless native["source_count"] == stage["native_source_count"] && native["staged_count"] == stage["native_source_count"]
    errors << "bun: dependency-staging native cache count mismatch" unless native["tarball_cache_count"] == stage["native_tarball_cache_count"]
    errors << "bun: dependency-staging prefetch count mismatch" unless native["prefetch_entry_count"] == stage["prefetch_entry_count"]
    errors << "bun: dependency-staging native identity manifest is invalid" unless native["source_identity_manifest_sha256"].to_s.match?(/\A[0-9a-f]{64}\z/)
    node = prep["node_headers"] || {}
    errors << "bun: dependency-staging Node version mismatch" unless node["version"] == "24.3.0"
    errors << "bun: dependency-staging Node ABI mismatch" unless node["abi"] == "137"
    errors << "bun: dependency-staging Node identity mismatch" unless node["identity"] == "24.3.0"

    npm = prep["npm_cache"] || {}
    errors << "bun: dependency-staging npm cache count mismatch" unless npm["cache_entries"] == stage["npm_cache_entries"]
    errors << "bun: dependency-staging npm cache tree mismatch" unless npm["tree_sha256"] == stage["npm_cache_tree_sha256"] && npm["tree_sha256"] == staging["npm_cache_tree_sha256"]
    %w[entries files directories file_bytes].each do |key|
      expected = staging["npm_cache_#{key}"]
      errors << "bun: dependency-staging npm #{key} mismatch" unless npm[key] == expected
    end
    errors << "bun: dependency-staging npm cache contains symlinks" unless npm["symlinks"] == 0
    errors << "bun: dependency-staging npm manifest mismatch" unless npm["manifest_sha256"] == npm["tree_sha256"] && npm["manifest_lines"] == npm["entries"]

    required_validation = %w[
      production_spec_integration_verified
      srpm_inputs_verified
      direct_source_checksums_verified
      native_sources_staged_verified
      native_source_identities_verified
      node_headers_staged_verified
      node_headers_abi_verified
      npm_cache_materialized_verified
      npm_cache_tree_verified
      network_isolation_verified
      deterministic_staging_verified
    ]
    errors << "bun: dependency-staging validation is incomplete" unless required_validation.all? { |key| receipt.dig("validation", key) == true }
    errors << "bun: dependency-staging receipt reproduction mismatch" unless receipt.dig("reproduction", "staging_receipt_byte_identical") == true
    errors << "bun: dependency-staging npm reproduction mismatch" unless receipt.dig("reproduction", "npm_cache_manifest_byte_identical") == true
    errors << "bun: dependency-staging second prep log SHA-256 is invalid" unless receipt.dig("reproduction", "second_network_isolated_prep_log_sha256").to_s.match?(/\A[0-9a-f]{64}\z/)
    %w[bootstrap_seed_used npm_install_run final_bun_build_run rpm_build_executed rpm_installed].each do |key|
      errors << "bun: dependency-staging proof incorrectly claims #{key}" unless receipt.dig("validation", key) == false
    end

    required_spec_fragments = [
      "BuildRequires:  git-core",
      "Source23:       bun-%{version}-release-local-source-closure.json",
      "Source24:       bun-stage-release-local-sources",
      "ruby %{SOURCE24}",
      "--expected-npm-tree-sha256 \"%{npm_cache_tree_sha256}\"",
      "--expected-npm-entries \"%{npm_cache_entries}\"",
      "--expected-npm-file-bytes \"%{npm_cache_file_bytes}\""
    ]
    errors << "bun: spec does not integrate the verified dependency-staging step" unless required_spec_fragments.all? { |fragment| spec.include?(fragment) }
    errors
  rescue JSON::ParserError, KeyError => e
    ["bun: invalid dependency-staging proof receipt: #{e.message}"]
  end

  def validate_bun_source_license_inventory(package, inventory, dependency_stage, version, spec)
    return [] unless package.name == "bun" && inventory.is_a?(Hash)

    receipt_name = inventory["source"]
    receipt_path = receipt_name.is_a?(String) && File.join(package.directory, receipt_name)
    expected_sha256 = inventory["sha256"]
    unless receipt_path && File.file?(receipt_path) && expected_sha256.to_s.match?(/\A[0-9a-f]{64}\z/) &&
           Digest::SHA256.file(receipt_path).hexdigest == expected_sha256
      return ["bun: source-license inventory is missing or has wrong SHA-256"]
    end

    errors = []
    receipt = JSON.parse(File.read(receipt_path))
    valid_file_record = lambda do |record|
      next false unless record.is_a?(Hash) && record["path"].is_a?(String) && !record["path"].empty?

      path = Pathname(record["path"])
      path.relative? && path.each_filename.none? { |part| [".", ".."].include?(part) } &&
        record["size_bytes"].is_a?(Integer) && record["size_bytes"].positive? &&
        record["sha256"].to_s.match?(/\A[0-9a-f]{64}\z/)
    end
    errors << "bun: unsupported source-license inventory schema" unless receipt["schema"] == "bun-source-license-inventory/v2"
    errors << "bun: source-license inventory package mismatch" unless receipt["package"] == "bun"
    errors << "bun: source-license inventory release mismatch" unless receipt["release"].to_s == version
    spec_release = spec[/^Release:\s+([^%\s]+)/, 1]
    errors << "bun: source-license inventory RPM release mismatch" unless receipt["rpm_release"] == spec_release
    closure = receipt["source_closure"] || {}
    errors << "bun: source-license inventory closure filename mismatch" unless closure["path"] == dependency_stage["proof_receipt"]
    errors << "bun: source-license inventory closure SHA-256 mismatch" unless closure["sha256"] == dependency_stage["proof_receipt_sha256"]
    closure_path = File.join(package.directory, closure["path"].to_s)
    valid_closure = File.file?(closure_path) && closure["sha256"].to_s.match?(/\A[0-9a-f]{64}\z/) &&
                    Digest::SHA256.file(closure_path).hexdigest == closure["sha256"]
    errors << "bun: source-license inventory closure is missing or has wrong SHA-256" unless valid_closure
    return errors unless valid_closure

    closure_receipt = JSON.parse(File.read(closure_path))
    errors << "bun: source-license inventory closure schema mismatch" unless closure_receipt["schema"] == "bun-release-local-source-closure/v3"
    errors << "bun: source-license inventory closure package mismatch" unless closure_receipt["package"] == "bun"
    errors << "bun: source-license inventory closure release mismatch" unless closure_receipt["release"].to_s == version
    errors << "bun: source-license Bun license record is invalid" unless valid_file_record.call(receipt["bun_license"])

    script_path = File.join(ROOT, inventory["audit_script"].to_s)
    unless File.file?(script_path) && inventory["audit_script_sha256"].to_s.match?(/\A[0-9a-f]{64}\z/) &&
           Digest::SHA256.file(script_path).hexdigest == inventory["audit_script_sha256"]
      errors << "bun: source-license audit script is missing or has wrong SHA-256"
    end

    errors << "bun: source-license inventory retains a current private Cargo payload" if receipt.key?("cargo")
    expected_history = {
      "source_commit" => "ed1cc04702f7b609a8a735edf0a1cc7c33ec22c5",
      "source_closure" => {
        "path" => "packages/bun/bun-1.3.14-release-local-source-closure.json",
        "sha256" => "ee3ed17e495779441326d10cd8d7f07a21b856285abc0f41ef9e5be6f99abbe0"
      },
      "source_license_inventory" => {
        "path" => "packages/bun/bun-1.3.14-source-license-inventory.json",
        "sha256" => "ea8fa634cb896eb1ba5376992e4f1001042d39836071d50ec9879b7fbd905bec"
      },
      "cargo_build_receipt" => {
        "path" => "packages/bun/lolhtml-offline-build-proof.json",
        "sha256" => "05785f79c560ce5953500acc7c9dea283a53b18240e59b62c84f57ab02eb5cce"
      },
      "cargo_rpm_receipt" => {
        "path" => "packages/bun/lolhtml-rpm-cargo-proof.json",
        "sha256" => "c7d08e312c359363a40ebe0fd24b91245f2fca369a60a1dc71d86e72c29ff164"
      },
      "active_provider" => "packages/lol-html/package.yml"
    }
    errors << "bun: source-license historical lol-html evidence mismatch" unless receipt.dig("historical_evidence", "private_lolhtml_cargo_graph") == expected_history

    npm = receipt["npm"] || {}
    errors << "bun: source-license npm cache count mismatch" unless npm["cache_entries"] == inventory["npm_cache_entries"]
    errors << "bun: source-license npm text count mismatch" unless npm["entries_with_supplied_license_text"] == inventory["npm_entries_with_license_text"]
    errors << "bun: source-license npm missing-text count mismatch" unless npm["entries_without_supplied_license_text"] == inventory["npm_entries_without_license_text"]
    expected_declarations = {
      "(MIT AND BSD-3-Clause)" => 1,
      "(MIT AND Zlib)" => 1,
      "0BSD" => 1,
      "<missing>" => 2,
      "Apache-2.0" => 5,
      "Artistic-2.0" => 1,
      "BSD-2-Clause" => 1,
      "BSD-3-Clause" => 5,
      "ISC" => 10,
      "MIT" => 207,
      "MPL-2.0" => 2
    }
    errors << "bun: source-license npm declaration inventory mismatch" unless npm["license_declarations"] == expected_declarations
    npm_records = Array(npm["records"])
    errors << "bun: source-license npm record count mismatch" unless npm_records.length == inventory["npm_cache_entries"]
    errors << "bun: source-license npm cache identities are not unique" unless npm_records.map { |record| record["cache_name"] }.uniq.length == npm_records.length
    expected_npm_identities = Array(closure_receipt.dig("npm", "source_archives")).map do |source|
      [source["package_name"], source["package_version"]]
    end.sort_by { |name, source_version| [name.to_s, source_version.to_s] }
    actual_npm_identities = npm_records.map do |record|
      [record["name"], record["version"]]
    end.sort_by { |name, source_version| [name.to_s, source_version.to_s] }
    errors << "bun: source-license npm identities do not match the source closure" unless actual_npm_identities == expected_npm_identities
    npm_file_records = npm_records.flat_map { |record| Array(record["license_files"]) }
    errors << "bun: source-license npm file record is invalid" unless npm_file_records.all? { |record| valid_file_record.call(record) && record["path"].start_with?(".build-tools/bun-install-cache/") }
    errors << "bun: source-license npm declaration-gap count mismatch" unless Array(npm["missing_license_field"]).length == inventory["npm_missing_license_fields"]
    errors << "bun: source-license npm declaration gaps lack supplied texts" unless Array(npm["missing_license_field"]).all? { |record| Array(record["license_files"]).any? }
    errors << "bun: source-license npm declaration gaps mismatch" unless Array(npm["missing_license_field"]).map { |record| record["name"] }.sort == %w[bun-tracestrings console-browserify]
    native = Array(receipt["native"])
    errors << "bun: source-license native component count mismatch" unless native.length == inventory["native_components"]
    errors << "bun: source-license native component lacks evidence" unless native.all? { |record| Array(record["license_files"]).any? && Array(record["license_files"]).all? { |file| valid_file_record.call(file) } }
    errors << "bun: source-license native component identities are not unique" unless native.map { |record| record["name"] }.uniq.length == native.length
    expected_native_identities = Array(closure_receipt["native_github_sources"]).map do |source|
      [source["name"], source["upstream_source_identity"]]
    end.sort
    actual_native_identities = native.map do |record|
      [record["name"], record["source_identity"]]
    end.sort
    errors << "bun: source-license native identities do not match the source closure" unless actual_native_identities == expected_native_identities
    pico = native.find { |record| record["name"] == "picohttpparser" }
    errors << "bun: source-license picohttpparser selection mismatch" unless pico&.dig("license_selection", "selected_expression") == inventory["picohttpparser_selected_license"]
    webkit = receipt["webkit"] || {}
    errors << "bun: source-license WebKit candidate count mismatch" unless webkit["candidate_license_file_count"] == inventory["webkit_candidate_license_files"]
    webkit_files = Array(webkit["candidate_license_files"])
    errors << "bun: source-license WebKit file records mismatch" unless webkit_files.length == inventory["webkit_candidate_license_files"] && webkit_files.all? { |record| valid_file_record.call(record) && record["path"].start_with?("vendor/WebKit/") }
    errors << "bun: source-license WebKit required files mismatch" unless webkit["required_files_present"] == %w[vendor/WebKit/Source/JavaScriptCore/COPYING.LIB vendor/WebKit/Source/ThirdParty/capstone/Source/LICENSE.TXT]

    true_validation = %w[
      source_closure_verified
      system_lolhtml_provider_external_to_bun_inventory
      npm_source_declarations_inventoried
      npm_supplied_license_texts_inventoried
      native_license_files_inventoried
      webkit_license_files_inventoried
    ]
    errors << "bun: source-license inventory validation is incomplete" unless true_validation.all? { |key| receipt.dig("validation", key) == true }
    false_validation = %w[
      network_used
      final_npm_installed_closure_verified
      final_linked_native_components_verified
      webkit_linked_file_semantic_review_verified
      fedora_allowed_spdx_verified
      required_license_texts_verified
      final_license_expression_verified
      rpm_payload_license_verified
    ]
    errors << "bun: source-license inventory overclaims completion" unless false_validation.all? { |key| receipt.dig("validation", key) == false }
    errors << "bun: source-license inventory metadata overclaims final closure" unless inventory["final_linked_closure_verified"] == false
    errors << "bun: source-license inventory metadata overclaims final expression" unless inventory["final_license_expression_verified"] == false
    errors << "bun: source-license inventory metadata overclaims required texts" unless inventory["required_license_texts_verified"] == false

    required_spec_fragments = [
      "%global source_license_inventory_sha256 #{expected_sha256}",
      "%global source_license_audit_script_sha256 #{inventory['audit_script_sha256']}",
      "Source25:       #{receipt_name.sub(version, "%{version}")}",
      "Source26:       #{inventory['audit_script_source']}",
      "echo \"%{source_license_inventory_sha256}  %{SOURCE25}\" | sha256sum -c -",
      "echo \"%{source_license_audit_script_sha256}  %{SOURCE26}\" | sha256sum -c -",
      "ruby %{SOURCE26}",
      "--rpm-release #{spec_release}",
      "--date #{receipt['audit_date']}",
      "--check",
      "--receipt \"%{SOURCE25}\""
    ]
    errors << "bun: spec does not integrate the source-license inventory" unless required_spec_fragments.all? { |fragment| spec.include?(fragment) }
    errors
  rescue JSON::ParserError, KeyError => e
    ["bun: invalid source-license inventory: #{e.message}"]
  end

  def validate_bun_final_linked_license_closure(package, metadata, source_inventory, stages, lolhtml, version, spec)
    return [] unless package.name == "bun" && metadata.is_a?(Hash)

    receipt_name = metadata["source"]
    receipt_path = receipt_name.is_a?(String) && File.join(package.directory, receipt_name)
    expected_sha256 = metadata["sha256"]
    unless receipt_path && File.file?(receipt_path) && expected_sha256.to_s.match?(/\A[0-9a-f]{64}\z/) &&
           Digest::SHA256.file(receipt_path).hexdigest == expected_sha256
      return ["bun: final linked-license closure is missing or has wrong SHA-256"]
    end

    errors = []
    receipt = JSON.parse(File.read(receipt_path))
    errors << "bun: unsupported final linked-license closure schema" unless receipt["schema"] == "bun-final-linked-license-closure/v3"
    errors << "bun: final linked-license closure package mismatch" unless receipt["package"] == "bun"
    errors << "bun: final linked-license closure release mismatch" unless receipt["version"] == version
    errors << "bun: final linked-license closure target mismatch" unless receipt["target"] == "fedora-44-x86_64-glibc-system-lolhtml"

    script_path = File.join(ROOT, metadata["audit_script"].to_s)
    unless File.file?(script_path) && metadata["audit_script_sha256"].to_s.match?(/\A[0-9a-f]{64}\z/) &&
           Digest::SHA256.file(script_path).hexdigest == metadata["audit_script_sha256"]
      errors << "bun: final linked-license audit script is missing or has wrong SHA-256"
    end

    seed_stage = stages.fetch("seed_build")
    self_stage = stages.fetch("self_rebuild")
    expected_inputs = {
      "self_rebuild" => [self_stage["proof_receipt"], self_stage["proof_receipt_sha256"], package.directory],
      "source_license_inventory" => [source_inventory["source"], source_inventory["sha256"], package.directory],
      "relink_audit" => [seed_stage.dig("relink_materials_audit", "proof_receipt"), seed_stage.dig("relink_materials_audit", "proof_receipt_sha256"), package.directory],
      "relink_kit" => [seed_stage.dig("relink_kit", "proof_receipt"), seed_stage.dig("relink_kit", "proof_receipt_sha256"), package.directory],
      "lolhtml_package" => ["package.yml", nil, File.join(ROOT, "packages", "lol-html")]
    }
    parsed_inputs = {}
    expected_inputs.each do |key, (name, sha, directory)|
      path = name.is_a?(String) && File.join(directory, name)
      record = receipt.dig("inputs", key)
      valid = path && File.file?(path) && record.is_a?(Hash) &&
              record["sha256"] == Digest::SHA256.file(path).hexdigest &&
              record["size_bytes"] == File.size(path)
      valid &&= record["sha256"] == sha if sha
      errors << "bun: final linked-license #{key.tr('_', ' ')} input mismatch" unless valid
      parsed_inputs[key] = JSON.parse(File.read(path)) if valid && File.extname(path) == ".json"
    end

    relink = parsed_inputs["relink_audit"] || {}
    self_receipt = parsed_inputs["self_rebuild"] || {}
    source_receipt = parsed_inputs["source_license_inventory"] || {}
    final_link = receipt["final_link"] || {}
    errors << "bun: final linked-license object count mismatch" unless final_link["direct_object_count"] == metadata["direct_object_count"] && final_link["direct_object_count"] == relink.dig("final_link", "direct_object_count")
    errors << "bun: final linked-license archive count mismatch" unless final_link["direct_archive_count"] == metadata["direct_archive_count"] && final_link["direct_archive_count"] == relink.dig("final_link", "direct_archive_count")
    errors << "bun: final linked-license input count mismatch" unless final_link["linked_input_count"] == metadata["linked_input_count"] && final_link["linked_input_count"] == final_link["direct_object_count"].to_i + final_link["direct_archive_count"].to_i
    errors << "bun: final linked-license link manifest mismatch" unless final_link["link_manifest_sha256"] == relink.dig("final_link", "link_manifest_sha256")
    errors << "bun: final linked-license object inventory mismatch" unless final_link["direct_object_inventory_sha256"] == relink.dig("final_link", "direct_object_inventory_sha256")
    errors << "bun: final linked-license archive inventory mismatch" unless final_link["direct_archives"] == relink.dig("final_link", "direct_archives")
    expected_system_libraries = %w[-l:libatomic.a -lc -ldl -lgcc_s -licudata -licui18n -licuuc -llolhtml -lpthread -lstdc++]
    errors << "bun: final linked-license system library set mismatch" unless final_link["system_link_libraries"] == expected_system_libraries

    components = Array(receipt["components"])
    component_counts = components.to_h { |component| [component["name"], component["linked_input_count"]] }
    errors << "bun: final linked-license component counts mismatch" unless component_counts == metadata["component_object_counts"]
    errors << "bun: final linked-license component object total mismatch" unless component_counts.values.sum == metadata["direct_object_count"]
    errors << "bun: final linked-license component set is not unique" unless components.map { |component| component["name"] }.uniq.length == components.length
    errors << "bun: final linked-license component path digest is invalid" unless components.all? { |component| component["linked_inputs_sha256"].to_s.match?(/\A[0-9a-f]{64}\z/) }

    native_inventory = Array(source_receipt["native"]).to_h { |component| [component["name"], component] }
    expected_native_names = native_inventory.keys.sort
    actual_native_names = components.reject { |component| component["name"] == "bun" }.map { |component| component["name"] }.sort
    errors << "bun: final linked-license native component set mismatch" unless actual_native_names == expected_native_names && actual_native_names.length == metadata["linked_native_components"]
    components.each do |component|
      if component["name"] == "bun"
        errors << "bun: final linked-license Bun selection mismatch" unless component["source_identity"] == self_receipt.dig("source_closure", "source_commit") && component.dig("license_selection", "selected_expression") == "MIT" && component["license_selection_verified"] == true
      else
        source = native_inventory[component["name"]]
        errors << "bun: final linked-license native evidence mismatch" unless source && component["source_identity"] == source["source_identity"] && component["license_files"] == source["license_files"] && component["license_selection"] == source["license_selection"]
      end
    end
    unresolved_native = components.reject { |component| component["license_selection_verified"] == true }.map { |component| component["name"] }.sort
    errors << "bun: final linked-license unresolved native set mismatch" unless receipt.dig("unresolved", "native_license_selections") == unresolved_native
    unresolved_reasons = {}
    expected_unresolved_details = unresolved_native.map do |name|
      source = native_inventory.fetch(name)
      { "name" => name, "reason" => unresolved_reasons[name], "license_files" => source["license_files"] }
    end
    errors << "bun: final linked-license unresolved native details mismatch" unless unresolved_native == unresolved_reasons.keys.sort && receipt.dig("unresolved", "native_license_details") == expected_unresolved_details

    webkit = receipt["webkit"] || {}
    errors << "bun: final linked-license WebKit source mismatch" unless webkit["source_commit"] == self_receipt.dig("inputs", "webkit", "commit") && webkit["source_archive_sha256"] == self_receipt.dig("inputs", "webkit", "archive_sha256")
    errors << "bun: final linked-license WebKit evidence mismatch" unless webkit["direct_archives"] == final_link["direct_archives"] && webkit["candidate_license_files"] == source_receipt.dig("webkit", "candidate_license_files") && webkit["semantic_license_selection_verified"] == false
    webkit_archives = Array(webkit["archives"])
    webkit_member_counts = webkit_archives.to_h { |archive| [archive["name"], archive["member_count"]] }
    webkit_source_counts = webkit_archives.to_h { |archive| [archive["name"], archive["source_count"]] }
    webkit_marker_counts = webkit_archives.to_h { |archive| [archive["name"], archive["license_marker_count"]] }
    errors << "bun: final linked-license WebKit archive counts mismatch" unless webkit["archive_count"] == webkit_archives.length && webkit_member_counts == metadata["webkit_archive_member_counts"] && webkit_source_counts == metadata["webkit_resolved_source_counts"] && webkit_marker_counts == metadata["webkit_license_marker_counts"]
    errors << "bun: final linked-license WebKit mapping totals mismatch" unless webkit["archive_member_count"] == metadata["webkit_archive_member_count"] && webkit["archive_member_count"] == webkit_member_counts.values.sum && webkit["resolved_source_count"] == metadata["webkit_resolved_source_count"] && webkit["resolved_source_count"] == webkit_source_counts.values.sum
    candidate_markers = Array(source_receipt.dig("webkit", "candidate_license_files")).to_h { |record| [record["path"], record] }
    path_set_digest = ->(paths) { Digest::SHA256.hexdigest(paths.sort.join("\n") + "\n") }
    ordered_digest = ->(values) { Digest::SHA256.hexdigest(values.join("\n") + "\n") }
    webkit_archives.each do |archive|
      members = Array(archive["members"])
      member_names = members.map { |member| member["member"] }
      object_paths = members.map { |member| member["object_path"] }
      source_records = members.flat_map { |member| Array(member["sources"]) }.uniq { |record| record["path"] }
      source_paths = source_records.map { |record| record["path"] }
      linked_archive = Array(final_link["direct_archives"]).find { |record| record["path"] == archive["archive_path"] }
      mapping_valid = linked_archive && archive["archive_sha256"] == linked_archive["sha256"] &&
        archive["member_count"] == members.length && archive["member_list_sha256"] == ordered_digest.call(member_names) &&
        archive["object_path_set_sha256"] == path_set_digest.call(object_paths) && object_paths.uniq.length == object_paths.length &&
        archive["source_count"] == source_records.length && archive["source_path_set_sha256"] == path_set_digest.call(source_paths) &&
        source_records.all? { |record| record["path"].to_s.match?(%r{\A(?:source|generated)/}) && record["sha256"].to_s.match?(/\A[0-9a-f]{64}\z/) && record["size_bytes"].is_a?(Integer) }
      errors << "bun: final linked-license WebKit member mapping mismatch" unless mapping_valid

      markers = Array(archive["license_markers"])
      marker_valid = archive["license_marker_count"] == markers.length && markers.all? { |record| candidate_markers[record["path"]] == record }
      errors << "bun: final linked-license WebKit marker inventory mismatch" unless marker_valid
    end
    webkit_proof_records_valid = %w[build_ninja compile_commands].all? do |key|
      record = webkit[key]
      record.is_a?(Hash) && record["path"].to_s.start_with?("generated/") && record["sha256"].to_s.match?(/\A[0-9a-f]{64}\z/) && record["size_bytes"].is_a?(Integer)
    end
    errors << "bun: final linked-license WebKit proof records mismatch" unless webkit_proof_records_valid && webkit["member_source_mapping_verified"] == true && webkit["license_marker_inventory_verified"] == true

    transitive = webkit["transitive_dependencies"] || {}
    dependency_archives = Array(transitive["archive_dependencies"])
    dependency_counts = dependency_archives.to_h { |archive| [archive["name"], archive["dependency_count"]] }
    errors << "bun: final linked-license WebKit transitive counts mismatch" unless transitive["object_count"] == metadata["webkit_archive_member_count"] && transitive["archive_dependency_counts"] == metadata["webkit_archive_dependency_counts"] && dependency_counts == metadata["webkit_archive_dependency_counts"] && transitive["unique_dependency_count"] == metadata["webkit_transitive_dependency_count"] && transitive["source_dependency_count"] == metadata["webkit_transitive_source_dependency_count"] && transitive["generated_dependency_count"] == metadata["webkit_transitive_generated_dependency_count"]
    dependency_records = dependency_archives.flat_map do |archive|
      records = Array(archive["dependencies"])
      valid = archive["dependency_count"] == records.length && archive["dependency_path_set_sha256"] == path_set_digest.call(records.map { |record| record["path"] }) && records.all? { |record| record["path"].to_s.match?(%r{\A(?:source|generated)/}) && record["sha256"].to_s.match?(/\A[0-9a-f]{64}\z/) && record["size_bytes"].is_a?(Integer) }
      errors << "bun: final linked-license WebKit transitive archive mismatch" unless valid
      records
    end
    unique_dependencies = dependency_records.uniq { |record| record["path"] }
    errors << "bun: final linked-license WebKit transitive path set mismatch" unless transitive["unique_dependency_count"] == unique_dependencies.length && transitive["dependency_path_set_sha256"] == path_set_digest.call(unique_dependencies.map { |record| record["path"] }) && transitive["source_dependency_count"].to_i + transitive["generated_dependency_count"].to_i == unique_dependencies.length

    headerless = Array(transitive["headerless_source_code"])
    resolved_headerless = headerless.select { |record| record["status"].to_s.start_with?("resolved_") }
    unresolved_headerless = headerless.select { |record| record["status"].to_s.start_with?("unresolved_") }
    unresolved_paths = unresolved_headerless.map { |record| record["path"] }
    unresolved_commits = unresolved_headerless.to_h { |record| [record["path"], record["introducing_commit"]] }
    errors << "bun: final linked-license WebKit headerless counts mismatch" unless transitive["headerless_source_code_count"] == metadata["webkit_headerless_source_code_count"] && transitive["headerless_source_code_count"] == headerless.length && transitive["resolved_headerless_source_code_count"] == metadata["webkit_resolved_headerless_source_code_count"] && transitive["resolved_headerless_source_code_count"] == resolved_headerless.length && transitive["unresolved_headerless_source_code_count"] == metadata["webkit_unresolved_headerless_source_code_count"] && transitive["unresolved_headerless_source_code_count"] == unresolved_headerless.length
    errors << "bun: final linked-license WebKit unresolved headerless set mismatch" unless unresolved_paths == metadata["webkit_unresolved_headerless_files"] && unresolved_commits == metadata["webkit_unresolved_headerless_commits"] && receipt.dig("unresolved", "webkit_headerless_files") == unresolved_paths
    resolved_valid = resolved_headerless.all? { |record| record["selected_expression"] == "MIT" && record["license_evidence"].is_a?(Hash) && record.dig("license_evidence", "sha256").to_s.match?(/\A[0-9a-f]{64}\z/) }
    unresolved_valid = unresolved_headerless.all? { |record| record["selected_expression"].nil? && record["introducing_commit"].to_s.match?(/\A[0-9a-f]{40}\z/) && record["introducing_author"].to_s.include?("<") && record["introducing_date"].to_s.match?(/\A\d{4}-\d{2}-\d{2}T/) && record["introducing_subject"].to_s != "" && record["upstream_repository"] == "https://github.com/oven-sh/WebKit" && record["upstream_issue_tracker_enabled"] == false }
    errors << "bun: final linked-license WebKit headerless review mismatch" unless resolved_valid && unresolved_valid && transitive["mapping_verified"] == true && transitive["headerless_review_verified"] == true && transitive["semantic_license_selection_verified"] == false

    lolhtml_data = YAML.safe_load(File.read(File.join(ROOT, "packages", "lol-html", "package.yml")), aliases: false)
    provider = receipt["external_lolhtml_provider"] || {}
    expected_provider = self_receipt.dig("inputs", "offline_inputs", "system_lolhtml_provider") || {}
    provider_license = lolhtml_data["license_audit"] || {}
    errors << "bun: final linked-license lol-html provider mismatch" unless provider["package"] == expected_provider["package"] && provider["version"] == expected_provider["version"] && provider["c_api_version"] == expected_provider["c_api_version"] && provider["soname"] == expected_provider["soname"] && provider["link_flag"] == "-llolhtml"
    errors << "bun: final linked-license lol-html license boundary mismatch" unless provider["aggregate_expression"] == provider_license["aggregate_expression"] && provider["linked_license_entries"] == provider_license["linked_license_entries"] && provider["license_dependencies_sha256"] == provider_license["license_dependencies_sha256"] && provider["fedora_spdx_review_complete"] == true && provider["excluded_from_bun_bundled_aggregate"] == true

    true_validation = %w[input_receipts_verified final_link_inputs_mapped all_native_components_linked webkit_archives_verified system_lolhtml_provider_verified native_license_selection_review_verified native_license_selections_verified webkit_member_source_mapping_verified webkit_license_marker_inventory_verified webkit_transitive_dependency_mapping_verified webkit_headerless_dependency_review_verified]
    false_validation = %w[network_used webkit_linked_file_semantic_review_verified final_npm_codegen_closure_verified fedora_allowed_spdx_verified required_license_texts_verified final_license_expression_verified rpm_payload_license_verified]
    errors << "bun: final linked-license mapping validation is incomplete" unless true_validation.all? { |key| receipt.dig("validation", key) == true }
    errors << "bun: final linked-license closure overclaims completion" unless false_validation.all? { |key| receipt.dig("validation", key) == false }
    metadata_false = %w[webkit_semantic_license_selection_verified final_npm_codegen_closure_verified final_license_expression_verified required_license_texts_verified rpm_payload_license_verified]
    errors << "bun: final linked-license native review counts mismatch" unless metadata["selected_native_license_components"] == components.count { |component| component["name"] != "bun" && component["license_selection_verified"] == true } && metadata["unresolved_native_license_components"] == unresolved_native.length && metadata["unresolved_native_license_component_names"] == unresolved_native
    errors << "bun: final linked-license metadata overclaims completion" unless metadata["all_link_inputs_mapped"] == true && metadata["system_lolhtml_provider_external"] == true && metadata["native_license_selection_review_verified"] == true && metadata["native_license_selections_verified"] == true && metadata["webkit_archive_member_source_mapping_verified"] == true && metadata["webkit_license_marker_inventory_verified"] == true && metadata["webkit_transitive_dependency_mapping_verified"] == true && metadata["webkit_headerless_dependency_review_verified"] == true && metadata_false.all? { |key| metadata[key] == false }

    required_spec_fragments = [
      "%global final_linked_license_closure_sha256 #{expected_sha256}",
      "%global final_linked_license_audit_script_sha256 #{metadata['audit_script_sha256']}",
      "Source27:       #{receipt_name.sub(version, "%{version}")}",
      "Source28:       #{metadata['audit_script_source']}",
      "echo \"%{final_linked_license_closure_sha256}  %{SOURCE27}\" | sha256sum -c -",
      "echo \"%{final_linked_license_audit_script_sha256}  %{SOURCE28}\" | sha256sum -c -"
    ]
    errors << "bun: spec does not integrate the final linked-license closure" unless required_spec_fragments.all? { |fragment| spec.include?(fragment) }
    errors
  rescue JSON::ParserError, KeyError => e
    ["bun: invalid final linked-license closure: #{e.message}"]
  end

  def validate_bun_minimized_webkit_source(package, webkit, version, spec)
    return [] unless package.name == "bun" && webkit.is_a?(Hash) && webkit.key?("jsc_only")

    errors = []
    source = webkit["jsc_only"]
    unless source.is_a?(Hash)
      return ["bun: minimized WebKit source metadata must be an object"]
    end

    expected_filename = "WebKit-#{webkit['commit']}-jsc.tar.gz"
    errors << "bun: minimized WebKit source is not verified" unless source["state"] == "verified"
    errors << "bun: minimized WebKit architecture scope mismatch" unless source["architectures"] == %w[x86_64 aarch64]
    build_architectures = package.data.dig("build_plan", "architectures")
    unless build_architectures.is_a?(Array) && (build_architectures - Array(source["architectures"])).empty?
      errors << "bun: minimized WebKit architecture does not cover the build plan"
    end
    errors << "bun: minimized WebKit acquisition method mismatch" unless source["acquisition"] == "deterministic_minimized_archive"
    errors << "bun: minimized WebKit source incorrectly claims a complete tree" unless source["source_tree_complete"] == false
    errors << "bun: minimized WebKit source is not marked JSC-only" unless source["jsc_only_source_subset"] == true
    errors << "bun: minimized WebKit aarch64 Capstone source scope is not verified" unless source["aarch64_capstone_source_scope_verified"] == true
    errors << "bun: minimized WebKit source does not retain Capstone" unless source["capstone_retained"] == true
    errors << "bun: minimized WebKit archive filename mismatch" unless source["archive_filename"] == expected_filename
    errors << "bun: minimized WebKit archive SHA-256 is invalid" unless source["sha256"].to_s.match?(/\A[0-9a-f]{64}\z/)
    errors << "bun: minimized WebKit tree SHA-256 is invalid" unless source["tree_sha256"].to_s.match?(/\A[0-9a-f]{64}\z/)
    %w[archive_size_bytes member_count regular_file_count symlink_count regular_file_bytes].each do |key|
      errors << "bun: minimized WebKit #{key} is invalid" unless source[key].is_a?(Integer) && source[key].positive?
    end
    if source["archive_hosted"] == false
      errors << "bun: minimized WebKit unhosted archive has a URL" unless source["archive_url"].nil?
    else
      release_tag = "bun-sources-#{version}-webkit-#{webkit.fetch('commit')[0, 12]}"
      errors.concat(validate_bun_hosted_webkit_release_metadata(source, webkit, version).map { |error| "bun: minimized WebKit #{error}" })
      request_path = File.join(ROOT, ".github", "source-release", "bun.yml")
      if File.file?(request_path)
        request = YAML.safe_load_file(request_path)
        errors.concat(validate_bun_source_release_request(source, webkit, version, request).map { |error| "bun: minimized WebKit #{error}" })
      else
        errors << "bun: minimized WebKit source-release request is missing"
      end
    end

    receipt_name = source["proof_receipt"]
    receipt_path = receipt_name.is_a?(String) && File.join(package.directory, receipt_name)
    expected_receipt_sha256 = source["proof_receipt_sha256"]
    unless receipt_path && File.file?(receipt_path) && expected_receipt_sha256.to_s.match?(/\A[0-9a-f]{64}\z/) && Digest::SHA256.file(receipt_path).hexdigest == expected_receipt_sha256
      errors << "bun: minimized WebKit source receipt is missing or has wrong SHA-256"
    else
      receipt = JSON.parse(File.read(receipt_path))
      errors << "bun: unsupported minimized WebKit source receipt schema" unless receipt["schema"] == "bun-webkit-minimized-source/v2"
      errors << "bun: minimized WebKit source receipt package mismatch" unless receipt["package"] == "bun"
      errors << "bun: minimized WebKit source receipt release mismatch" unless receipt["release_pin"] == "bun-v#{version}"
      errors << "bun: minimized WebKit source receipt commit mismatch" unless receipt.dig("source", "commit") == webkit["commit"]
      errors << "bun: minimized WebKit source receipt root mismatch" unless receipt.dig("source", "archive_root") == "WebKit-#{webkit['commit']}"
      errors << "bun: minimized WebKit source receipt canonical filename mismatch" unless receipt.dig("source", "complete_archive_filename") == webkit["archive_filename"]
      errors << "bun: minimized WebKit source receipt canonical SHA-256 mismatch" unless receipt.dig("source", "complete_archive_sha256") == webkit["sha256"]
      errors << "bun: minimized WebKit source receipt canonical size mismatch" unless receipt.dig("source", "complete_archive_size_bytes") == webkit["archive_size_bytes"]
      {
        "filename" => "archive_filename",
        "sha256" => "sha256",
        "size_bytes" => "archive_size_bytes",
        "tree_sha256" => "tree_sha256",
        "member_count" => "member_count",
        "regular_file_count" => "regular_file_count",
        "symlink_count" => "symlink_count",
        "regular_file_bytes" => "regular_file_bytes"
      }.each do |receipt_key, metadata_key|
        errors << "bun: minimized WebKit source receipt #{receipt_key} mismatch" unless receipt.dig("archive", receipt_key) == source[metadata_key]
      end
      required_paths = receipt.dig("retained_scope", "required_paths")
      excluded_paths = receipt.dig("retained_scope", "excluded_paths")
      errors << "bun: minimized WebKit retained architecture scope is invalid" unless receipt.dig("retained_scope", "architectures") == source["architectures"]
      errors << "bun: minimized WebKit receipt does not retain Capstone" unless receipt.dig("retained_scope", "capstone_retained") == true
      errors << "bun: minimized WebKit required-path scope is invalid" unless required_paths.is_a?(Array) && %w[CMakeLists.txt Source/JavaScriptCore/CMakeLists.txt Source/ThirdParty/capstone/CMakeLists.txt Source/ThirdParty/gtest/CMakeLists.txt].all? { |path| required_paths.include?(path) }
      errors << "bun: minimized WebKit excluded-path scope is invalid" unless excluded_paths.is_a?(Array) && %w[Source/WebCore LayoutTests].all? { |path| excluded_paths.include?(path) } && !excluded_paths.include?("Source/ThirdParty/capstone")
      # The v2 receipt key is frozen by the published asset; package metadata uses the clearer source-scope name.
      verified = %w[canonical_source_verified safe_single_root_verified required_paths_verified excluded_paths_absent git_mode_semantics_normalized modes_and_symlinks_manifested deterministic_regeneration_verified archive_size_reduced jsc_only_source_subset aarch64_capstone_scope_verified]
      errors << "bun: minimized WebKit source receipt validation is incomplete" unless verified.all? { |key| receipt.dig("validation", key) == true }
      errors << "bun: minimized WebKit source receipt incorrectly claims completeness" unless receipt.dig("validation", "source_tree_complete") == false
      errors << "bun: minimized WebKit identity receipt incorrectly claims a Bun build" unless receipt.dig("validation", "bun_source_build_verified") == false
    end

    build_name = source["source_build_proof_receipt"]
    build_path = build_name.is_a?(String) && File.join(package.directory, build_name)
    expected_build_sha256 = source["source_build_proof_receipt_sha256"]
    unless build_path && File.file?(build_path) && expected_build_sha256.to_s.match?(/\A[0-9a-f]{64}\z/) && Digest::SHA256.file(build_path).hexdigest == expected_build_sha256
      errors << "bun: minimized WebKit source-build receipt is missing or has wrong SHA-256"
    else
      build = JSON.parse(File.read(build_path))
      errors << "bun: unsupported minimized WebKit source-build receipt schema" unless build["schema"] == 1
      errors << "bun: minimized WebKit source-build release mismatch" unless build["package_release"] == "bun-v#{version}"
      errors << "bun: minimized WebKit source-build platform mismatch" unless build["proof_platform"] == "fedora-44-x86_64"
      errors << "bun: minimized WebKit source-build unexpectedly claims an isolated buildroot" unless build["isolated_buildroot"] == false
      expected_source = {
        "commit" => webkit["commit"],
        "archive_filename" => source["archive_filename"],
        "sha256" => source["sha256"],
        "source_tree_complete" => false,
        "minimized_jsc_only_source" => true,
        "source_receipt_sha256" => source["proof_receipt_sha256"],
        "tree_sha256" => source["tree_sha256"],
        "gitlink_count" => webkit["gitlink_count"],
        "embedded_gitmodules_count" => webkit["embedded_gitmodules_count"]
      }
      errors << "bun: minimized WebKit source-build input mismatch" unless build["source"] == expected_source
      errors << "bun: minimized WebKit source-build patch mismatch" unless build.dig("patch", "path") == webkit["patch"] && build.dig("patch", "sha256") == webkit["patch_sha256"]

      static_archives = build.dig("output", "static_archives")
      valid_file = lambda do |entry|
        entry.is_a?(Hash) && entry["path"].is_a?(String) && !entry["path"].empty? &&
          !Pathname.new(entry["path"]).absolute? && !Pathname.new(entry["path"]).each_filename.include?("..") &&
          entry["size_bytes"].is_a?(Integer) && entry["size_bytes"].positive? &&
          entry["sha256"].to_s.match?(/\A[0-9a-f]{64}\z/)
      end
      expected_archives = %w[libJavaScriptCore.a libWTF.a libbmalloc.a]
      errors << "bun: minimized WebKit static-archive proof is invalid" unless static_archives.is_a?(Hash) && static_archives.keys.sort == expected_archives && static_archives.values.all? { |entry| valid_file.call(entry) }
      jsc = build.dig("output", "jsc")
      errors << "bun: minimized WebKit jsc proof is invalid" unless valid_file.call(jsc) && jsc["runtime_probe_verified"] == true
      build_metadata = build.dig("output", "metadata")
      expected_metadata = %w[CMakeCache.txt compile_commands.json]
      errors << "bun: minimized WebKit retained build metadata is invalid" unless build_metadata.is_a?(Hash) && build_metadata.keys.sort == expected_metadata && build_metadata.values.all? { |entry| valid_file.call(entry) }
      expected_headers = {
        "JavaScriptCore/Headers" => 9,
        "JavaScriptCore/PrivateHeaders" => 1415,
        "WTF/Headers" => 510,
        "bmalloc/Headers" => 360
      }
      errors << "bun: minimized WebKit generated-header proof mismatch" unless build.dig("output", "generated_header_counts") == expected_headers
      errors << "bun: minimized WebKit source-build relink evidence is incomplete" unless %w[webkit_static_archives_verified generated_headers_retained compile_commands_retained].all? { |key| build.dig("relink_materials", key) == true }
      errors << "bun: minimized WebKit source-build incorrectly claims complete Bun relink materials" unless build.dig("relink_materials", "complete_bun_relink_materials_verified") == false
      errors << "bun: minimized WebKit source-build metadata is not verified" unless source["source_build_verified"] == true
    end

    errors << "bun: spec does not bind the minimized WebKit SHA-256" unless spec.to_s.match?(/^%global\s+webkit_sha256\s+#{Regexp.escape(source['sha256'].to_s)}$/)
    if source["archive_hosted"] == true
      source_tag = source.fetch("release_tag").gsub(version, "%{version}")
      errors << "bun: spec does not bind the minimized WebKit release tag" unless spec.to_s.match?(/^%global\s+webkit_source_tag\s+#{Regexp.escape(source_tag)}$/)
      source_filename = source.fetch("archive_filename").gsub(webkit.fetch("commit"), "%{webkit_commit}")
      expected_source2 = "https://github.com/marcin-fm/agentlab/releases/download/%{webkit_source_tag}/#{source_filename}"
    else
      expected_source2 = source["archive_filename"].gsub(webkit.fetch("commit"), "%{webkit_commit}")
    end
    errors << "bun: spec does not use the minimized WebKit Source2" unless spec.to_s.match?(/^Source2:\s+#{Regexp.escape(expected_source2)}$/)
    errors << "bun: spec architecture does not match the build plan" unless spec.to_s.match?(/^ExclusiveArch:\s+#{Regexp.escape(Array(build_architectures).join(" "))}$/)

    errors
  rescue JSON::ParserError, KeyError, Psych::SyntaxError => e
    errors << "bun: invalid minimized WebKit receipt: #{e.message}"
  end

  def validate_bun_hosted_webkit_release_metadata(source, webkit, version)
    commit = webkit.fetch("commit")
    filename = source.fetch("archive_filename")
    release_tag = "bun-sources-#{version}-webkit-#{commit[0, 12]}"
    archive_url = "https://github.com/marcin-fm/agentlab/releases/download/#{release_tag}/#{filename}"
    release_url = "https://github.com/marcin-fm/agentlab/releases/tag/#{release_tag}"
    valid_url = begin
      URI(source["archive_url"]).is_a?(URI::HTTPS)
    rescue URI::InvalidURIError, TypeError
      false
    end
    errors = []
    errors << "hosted archive URL is invalid" unless source["archive_hosted"] == true && valid_url
    errors << "hosted archive URL mismatch" unless source["archive_url"] == archive_url
    errors << "release tag mismatch" unless source["release_tag"] == release_tag
    errors << "release URL mismatch" unless source["release_url"] == release_url
    errors << "release ID is invalid" unless source["release_id"].is_a?(Integer) && source["release_id"].positive?
    errors << "release target commit is invalid" unless source["release_target_commit"].to_s.match?(/\A[0-9a-f]{40}\z/)
    errors << "release is not immutable" unless source["release_immutable"] == true
    errors << "artifact attestation URL is invalid" unless source["artifact_attestation_url"].to_s.match?(%r{\Ahttps://github\.com/marcin-fm/agentlab/attestations/[1-9][0-9]*\z})
    errors << "publication run URL is invalid" unless source["publication_run"].to_s.match?(%r{\Ahttps://github\.com/marcin-fm/agentlab/actions/runs/[1-9][0-9]*\z})
    errors << "source receipt SHA-256 is invalid" unless source["proof_receipt_sha256"].to_s.match?(/\A[0-9a-f]{64}\z/)
    errors << "tree SHA-256 is invalid" unless source["tree_sha256"].to_s.match?(/\A[0-9a-f]{64}\z/)
    errors
  rescue KeyError => e
    ["release metadata is incomplete: #{e.message}"]
  end

  def validate_bun_source_release_request(source, webkit, version, request)
    expected = {
      "schema" => "agentlab-source-release-request/v1",
      "package" => "bun",
      "version" => version,
      "webkit_commit" => webkit.fetch("commit"),
      "archive_sha256" => source.fetch("sha256"),
      "tag" => source.fetch("release_tag"),
      "generator_commit" => source.fetch("release_target_commit")
    }
    valid = request.is_a?(Hash) && expected.all? { |key, value| request[key] == value } &&
            request["operation"] == "publish" && request["attempt"].is_a?(Integer) && request["attempt"].positive?
    valid ? [] : ["source-release request mismatch"]
  rescue KeyError => e
    ["source-release request metadata is incomplete: #{e.message}"]
  end

  def validate_pdfium_source_release_request(package, closure, request)
    version = package.upstream.fetch("current_version").to_s
    policy = package.data.fetch("source_policy")
    source = package.data.fetch("source_closure")
    expected = {
      "schema" => "agentlab-source-release-request/v1",
      "package" => "pdfium",
      "version" => version,
      "chromium_commit" => closure.fetch("chromium").fetch("commit"),
      "pdfium_commit" => closure.fetch("pdfium").fetch("commit"),
      "upstream_archive_sha256" => closure.fetch("chromium").fetch("archive").fetch("sha256"),
      "archive_sha256" => source.fetch("output_sha256"),
      "archive_size_bytes" => source.fetch("output_size_bytes"),
      "tree_sha256" => source.fetch("output_tree_sha256"),
      "tag" => policy.fetch("release_tag")
    }
    valid = request.is_a?(Hash) && request["attempt"].is_a?(Integer) && request["attempt"].positive? &&
            %w[stage publish].include?(request["operation"])
    return ["source-release request mismatch"] unless valid

    expected["attempt"] = request.fetch("attempt")
    expected["operation"] = request.fetch("operation")
    if request["operation"] == "publish"
      generator_commit = request["generator_commit"]
      return ["source-release request mismatch"] unless generator_commit.to_s.match?(/\A[0-9a-f]{40}\z/)

      expected["generator_commit"] = generator_commit
    end
    request == expected ? [] : ["source-release request mismatch"]
  rescue KeyError => e
    ["source-release request metadata is incomplete: #{e.message}"]
  end

  def validate_pdfium_source(package, spec)
    return [] unless package.name == "pdfium"

    errors = []
    version = package.upstream.fetch("current_version").to_s
    policy = package.data.fetch("source_policy")
    source = package.data.fetch("source_closure")
    policy_path = File.join(package.directory, "source-closure.yml")
    receipt_name = "pdfium-#{version}-source-receipt.json"
    receipt_path = File.join(package.directory, receipt_name)
    generator_path = File.join(ROOT, "scripts", "prepare-pdfium-srpm-sources")
    request_path = File.join(ROOT, ".github", "source-release", "pdfium.yml")
    makefile_path = File.join(ROOT, ".copr", "Makefile")
    closure = YAML.safe_load_file(policy_path)
    receipt = JSON.parse(File.read(receipt_path))
    prepared = closure.fetch("source_preparation")
    pdfium_commit = closure.fetch("pdfium").fetch("commit")
    tag = "pdfium-sources-#{version}-pdfium-#{pdfium_commit[0, 12]}"
    filename = "pdfium-#{version}-source.tar.gz"
    archive_url = "https://github.com/marcin-fm/agentlab/releases/download/#{tag}/#{filename}"
    release_url = "https://github.com/marcin-fm/agentlab/releases/tag/#{tag}"

    errors << "pdfium: generated archive transport identity is not required" unless policy["generated_archive_transport_identity_required"] == true
    errors << "pdfium: remote generated source asset is not required" unless policy["remote_generated_asset_required"] == true
    errors << "pdfium: source closure method mismatch" unless source["method"] == "github-actions-immutable-release"
    errors << "pdfium: source release tag mismatch" unless policy["release_tag"] == tag
    errors << "pdfium: source archive URL mismatch" unless policy["archive_url"] == archive_url
    errors << "pdfium: source release URL mismatch" unless policy["release_url"] == release_url
    errors << "pdfium: immutable release is not required" unless policy["immutable_release_required"] == true
    errors << "pdfium: artifact attestation is not required" unless policy["artifact_attestation_required"] == true

    expected_archive_sha256 = source.fetch("output_sha256")
    expected_archive_size = source.fetch("output_size_bytes")
    expected_tree_sha256 = source.fetch("output_tree_sha256")
    errors << "pdfium: generated archive SHA-256 mismatch" unless policy["generated_archive_sha256"] == expected_archive_sha256 && prepared["output_sha256"] == expected_archive_sha256 && receipt.dig("output", "sha256") == expected_archive_sha256
    errors << "pdfium: generated archive size mismatch" unless policy["generated_archive_size_bytes"] == expected_archive_size && prepared["output_size_bytes"] == expected_archive_size && receipt.dig("output", "size_bytes") == expected_archive_size
    errors << "pdfium: generated tree SHA-256 mismatch" unless prepared["output_tree_sha256"] == expected_tree_sha256 && receipt.dig("output", "tree_sha256") == expected_tree_sha256
    errors << "pdfium: source archive filename mismatch" unless prepared["output"] == filename && receipt.dig("output", "filename") == filename
    errors << "pdfium: source archive release metadata mismatch" unless prepared["release_tag"] == tag && prepared["archive_url"] == archive_url && receipt.dig("release", "tag") == tag && receipt.dig("release", "archive_url") == archive_url
    errors << "pdfium: source archive release controls are incomplete" unless prepared["immutable_release_required"] == true && prepared["artifact_attestation_required"] == true && receipt.dig("release", "immutable_required") == true && receipt.dig("release", "artifact_attestation_required") == true

    {
      policy_path => source.fetch("policy_sha256"),
      receipt_path => source.fetch("receipt_sha256"),
      generator_path => source.fetch("generator_sha256")
    }.each do |path, sha256|
      unless sha256.to_s.match?(/\A[0-9a-f]{64}\z/) && File.file?(path) && Digest::SHA256.file(path).hexdigest == sha256
        errors << "pdfium: checked source metadata hash mismatch: #{File.basename(path)}"
      end
    end
    errors << "pdfium: source policy receipt hash mismatch" unless receipt.dig("source_policy", "sha256") == source["policy_sha256"]
    errors << "pdfium: source generator receipt hash mismatch" unless receipt.dig("generator", "sha256") == source["generator_sha256"]
    errors << "pdfium: unsupported source receipt schema" unless receipt["schema"] == "pdfium-source-preparation/v1"
    errors << "pdfium: source receipt transport controls are incomplete" unless receipt.dig("output", "transport_identity_required") == true && receipt.dig("validation", "generated_archive_transport_identity_required") == true && receipt.dig("validation", "remote_generated_asset_required") == true

    errors << "pdfium: spec source tag mismatch" unless spec.match?(/^%global source_tag #{Regexp.escape(tag.gsub(version, "%{version}"))}$/)
    errors << "pdfium: spec source SHA-256 mismatch" unless spec.match?(/^%global source_sha256 #{Regexp.escape(expected_archive_sha256)}$/)
    errors << "pdfium: spec source size mismatch" unless spec.match?(/^%global source_size #{expected_archive_size}$/)
    expected_source0 = "https://github.com/marcin-fm/agentlab/releases/download/%{source_tag}/pdfium-%{version}-source.tar.gz"
    errors << "pdfium: spec does not use the hosted Source0" unless spec.match?(/^Source0:\s+#{Regexp.escape(expected_source0)}$/)
    errors << "pdfium: spec does not verify Source0 bytes" unless spec.include?('echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -') && spec.include?('test "$(stat -c %%s %{SOURCE0})" = "%{source_size}"')
    errors << "pdfium: spec does not verify the hosted Source0 tree" unless spec.include?("ruby %{SOURCE3} --output %{SOURCE0} --receipt %{SOURCE1} --check")

    makefile = File.read(makefile_path)
    errors << "pdfium: COPR source builder still generates Source0" if makefile.include?("prepare-pdfium-srpm-sources\" --spec")
    expected_generator_copy = 'install -pm0755 "$(repo_root)/scripts/prepare-pdfium-srpm-sources" "$$(dirname "$(spec)")/prepare-pdfium-srpm-sources";'
    errors << "pdfium: COPR source builder does not retain the Source3 verifier" unless makefile.include?(expected_generator_copy)
    if File.file?(request_path)
      request = YAML.safe_load_file(request_path)
      errors.concat(validate_pdfium_source_release_request(package, closure, request).map { |error| "pdfium: #{error}" })
    else
      errors << "pdfium: source-release request is missing"
    end

    errors
  rescue JSON::ParserError, KeyError, Psych::SyntaxError, Errno::ENOENT => e
    ["pdfium: invalid source release metadata: #{e.message}"]
  end

  def valid_bun_staged_lolhtml_provider?(provider, expected)
    return false unless provider.is_a?(Hash) && provider.slice(*expected.keys) == expected

    staged = provider["staged_payload"]
    root = staged.is_a?(Hash) && staged["root"]
    valid_root = root.is_a?(String) && Pathname.new(root).absolute? && root.start_with?("/srv/tmp/") && Pathname.new(root).cleanpath.to_s == root
    valid_records = %w[header pkgconfig_file shared_library].all? do |key|
      record = staged.is_a?(Hash) && staged[key]
      path = record.is_a?(Hash) && record["path"]
      path.is_a?(String) && !path.empty? && !Pathname.new(path).absolute? && !Pathname.new(path).each_filename.include?("..") &&
        record["size_bytes"].is_a?(Integer) && record["size_bytes"].positive? &&
        record["sha256"].to_s.match?(/\A[0-9a-f]{64}\z/)
    end
    valid_root && valid_records && staged["critical_symbols_verified"] == true
  end

  def validate_bun_current_self_npm_proof(package, dependency_stage, self_receipt, driver, version)
    npm_input = self_receipt.dig("inputs", "npm_proof")
    receipt_name = npm_input.is_a?(Hash) && npm_input["path"]
    expected_sha256 = npm_input.is_a?(Hash) && npm_input["sha256"]
    valid_name = receipt_name.is_a?(String) && File.basename(receipt_name) == receipt_name
    receipt_path = valid_name && File.join(package.directory, receipt_name)
    unless npm_input.is_a?(Hash) && npm_input["mode"] == "source_built" && receipt_path && File.file?(receipt_path) &&
           expected_sha256.to_s.match?(/\A[0-9a-f]{64}\z/) && Digest::SHA256.file(receipt_path).hexdigest == expected_sha256
      return ["bun: current self-rebuild npm proof input is missing or invalid"]
    end

    proof = JSON.parse(File.read(receipt_path))
    driver_kind = driver.is_a?(Hash) && driver["driver_proof_kind"]
    valid_driver = proof.dig("driver", "proof_kind") == driver_kind &&
                   proof.dig("driver", "receipt") == driver["driver_receipt"] &&
                   proof.dig("driver", "receipt_sha256") == driver["driver_receipt_sha256"]
    errors = []
    errors << "bun: current self-rebuild npm proof driver mismatch" unless valid_driver

    staging = package.data.dig("build_plan", "source_inputs", "release_local_staging") || {}
    npm_stage = dependency_stage.merge(
      "npm_install_proof_receipt" => receipt_name,
      "npm_install_proof_receipt_sha256" => expected_sha256,
      "npm_cache_entries" => dependency_stage["unique_npm_source_archives"],
      "npm_cache_tree_sha256" => staging["npm_cache_tree_sha256"],
      "npm_cache_materialization_verified" => true,
      "npm_offline_install_verified" => true,
      "npm_frozen_lockfile_verified" => true,
      "npm_ignore_scripts_verified" => true,
      "npm_network_namespace_verified" => true
    )

    validation_data = Marshal.load(Marshal.dump(package.data))
    selected_stage_name = driver_kind == "self_rebuild" ? "self_rebuild" : "seed_build"
    selected_stage = validation_data.dig("build_plan", "stages", selected_stage_name)
    if selected_stage.is_a?(Hash)
      selected_stage.merge!(
        "state" => "verified",
        "historical_only" => false,
        "proof_receipt" => driver["driver_receipt"],
        "proof_receipt_sha256" => driver["driver_receipt_sha256"]
      )
    end
    validation_package = Package.new(directory: package.directory, manifest_path: package.manifest_path, data: validation_data)
    errors.concat(validate_bun_npm_offline_install(validation_package, npm_stage, version))
    errors
  rescue JSON::ParserError, TypeError => e
    ["bun: invalid current self-rebuild npm proof: #{e.message}"]
  end

  def validate_bun_current_first_build_receipt(package, receipt, seed_stage, stages, source_inputs, version)
    errors = []
    seed = source_inputs.fetch("bootstrap_seed")
    zig = source_inputs.fetch("zig")
    webkit = source_inputs.fetch("webkit")
    lolhtml = source_inputs.fetch("lolhtml")
    npm_lock = source_inputs.fetch("npm_lock")
    build_graph = source_inputs.fetch("build_graph")
    dependency_stage = stages.fetch("dependency_closure")

    errors << "bun: unsupported current seed-build proof receipt schema" unless receipt["schema"] == "bun-first-source-build-proof/v2"
    errors << "bun: current seed-build proof package mismatch" unless receipt["package"] == "bun"
    errors << "bun: current seed-build proof release mismatch" unless receipt["release"] == version
    errors << "bun: current seed-build proof profile mismatch" unless receipt["profile"] == "release-local"
    errors << "bun: current seed-build proof date mismatch" unless receipt["proof_date"] == seed_stage["proof_date"]
    closure_name = dependency_stage.fetch("proof_receipt")
    closure_sha256 = dependency_stage.fetch("proof_receipt_sha256")
    closure_path = File.join(package.directory, closure_name)
    errors << "bun: current seed-build proof source-closure path mismatch" unless receipt.dig("source_closure", "path") == closure_name
    errors << "bun: current seed-build proof source-closure SHA-256 mismatch" unless receipt.dig("source_closure", "sha256") == closure_sha256
    unless File.file?(closure_path) && closure_sha256.to_s.match?(/\A[0-9a-f]{64}\z/) && Digest::SHA256.file(closure_path).hexdigest == closure_sha256
      errors << "bun: current dependency-closure proof receipt is missing or has the wrong SHA-256"
    end
    errors << "bun: current seed-build proof source commit mismatch" unless receipt.dig("source_closure", "source_commit") == package.upstream["source_commit"]
    errors << "bun: current seed-build proof source SHA-256 mismatch" unless receipt.dig("source_closure", "source_archive_sha256") == package.upstream["source_sha256"]
    errors << "bun: current seed-build proof seed archive mismatch" unless receipt.dig("bootstrap_seed", "archive_sha256") == seed["sha256"]
    errors << "bun: current seed-build proof seed binary mismatch" unless receipt.dig("bootstrap_seed", "binary_sha256") == seed["binary_sha256"]
    errors << "bun: current seed-build proof seed size mismatch" unless receipt.dig("bootstrap_seed", "size_bytes") == seed["binary_size_bytes"]
    errors << "bun: current seed-build proof seed version mismatch" unless receipt.dig("bootstrap_seed", "version") == version
    errors << "bun: current seed-build proof seed is not bootstrap-only" unless receipt.dig("bootstrap_seed", "bootstrap_only") == true
    errors << "bun: current seed-build proof permits the seed in the payload" unless receipt.dig("bootstrap_seed", "final_payload_allowed") == false
    errors << "bun: current seed-build proof permits a seed runtime dependency" unless receipt.dig("bootstrap_seed", "final_runtime_dependency_allowed") == false

    patch_sha256 = lambda do |metadata, path_key, sha_key|
      path = metadata[path_key].is_a?(String) && File.join(package.directory, metadata[path_key])
      next nil unless path && File.file?(path)

      actual = Digest::SHA256.file(path).hexdigest
      expected = sha_key && metadata[sha_key]
      errors << "bun: current seed-build input patch SHA-256 mismatch" if expected && expected != actual
      actual
    end
    errors << "bun: current seed-build proof Zig commit mismatch" unless receipt.dig("inputs", "zig", "source_commit") == zig["commit"]
    errors << "bun: current seed-build proof Zig source SHA-256 mismatch" unless receipt.dig("inputs", "zig", "source_sha256") == zig["sha256"]
    errors << "bun: current seed-build proof Zig patch SHA-256 mismatch" unless receipt.dig("inputs", "zig", "patch_sha256") == patch_sha256.call(zig, "patch", nil)
    errors << "bun: current seed-build proof WebKit commit mismatch" unless receipt.dig("inputs", "webkit", "commit") == webkit["commit"]
    expected_webkit_sha256 = if receipt.dig("inputs", "webkit", "minimized_jsc_only_source") == true
                               webkit.dig("jsc_only", "sha256")
                             else
                               webkit["sha256"]
                             end
    errors << "bun: current seed-build proof WebKit source SHA-256 mismatch" unless receipt.dig("inputs", "webkit", "archive_sha256") == expected_webkit_sha256
    errors << "bun: current seed-build proof WebKit patch SHA-256 mismatch" unless receipt.dig("inputs", "webkit", "patch_sha256") == patch_sha256.call(webkit, "patch", "patch_sha256")
    errors << "bun: current seed-build proof lol-html patch SHA-256 mismatch" unless receipt.dig("inputs", "source_patches", "system_lolhtml_sha256") == patch_sha256.call(lolhtml, "patch", "patch_sha256")
    errors << "bun: current seed-build proof npm-lock patch SHA-256 mismatch" unless receipt.dig("inputs", "source_patches", "npm_lock_sha256") == patch_sha256.call(npm_lock, "patch", "patch_sha256")
    errors << "bun: current seed-build proof Zig-cwd patch SHA-256 mismatch" unless receipt.dig("inputs", "source_patches", "zig_build_cwd_sha256") == patch_sha256.call(build_graph, "patch", "patch_sha256")
    errors << "bun: current seed-build proof shared-runtime patch SHA-256 mismatch" unless receipt.dig("inputs", "source_patches", "fedora_shared_cxx_runtime_sha256") == patch_sha256.call(build_graph, "cxx_runtime_patch", "cxx_runtime_patch_sha256")

    historical_npm = dependency_stage.fetch("historical_lolhtml_graph")
    npm_proof_mode = receipt.dig("inputs", "npm_proof", "mode")
    errors << "bun: current seed-build historical npm input mismatch" unless [nil, "historical_seed"].include?(npm_proof_mode) && receipt.dig("inputs", "npm_proof", "path") == historical_npm["npm_install_proof_receipt"] && receipt.dig("inputs", "npm_proof", "sha256") == historical_npm["npm_install_proof_receipt_sha256"] && receipt.dig("inputs", "npm_proof", "historical_seed_driven_install_only") == true
    offline = receipt.dig("inputs", "offline_inputs")
    expected_provider = lolhtml.slice("package", "version", "c_api_version", "pkgconfig", "soname", "build_requirement")
    actual_provider = offline.is_a?(Hash) && offline["system_lolhtml_provider"]
    errors << "bun: current seed-build offline input counts mismatch" unless offline.is_a?(Hash) && offline["native_archives"] == dependency_stage["selected_github_archives"] && offline["node_header_archives"] == dependency_stage["selected_node_header_archives"] && offline["npm_install_roots"] == 3 && offline["cargo_source_archives"] == 0
    errors << "bun: current seed-build system lol-html provider mismatch" unless valid_bun_staged_lolhtml_provider?(actual_provider, expected_provider)
    supplemental_npm = offline.is_a?(Hash) && offline["supplemental_npm_trees"]
    errors << "bun: current seed-build supplemental npm inputs are invalid" unless supplemental_npm.is_a?(Array) && supplemental_npm.all? { |entry| entry.is_a?(Hash) && entry["path"].is_a?(String) && entry.dig("tree", "sha256").to_s.match?(/\A[0-9a-f]{64}\z/) }

    expected_rules = %w[codegen dep_build dep_cargo dep_cargo_cross dep_codegen dep_configure dep_fetch dep_fetch_prebuilt dep_prebuild dep_subst link regen smoke_test zig_build zig_check zig_fetch]
    errors << "bun: current seed-build proof was not network isolated" unless receipt.dig("configure", "network_namespace") == true && receipt.dig("build", "network_namespace") == true
    errors << "bun: current seed-build proof did not revalidate prepared inputs" unless receipt.dig("configure", "prepared_inputs_revalidated") == true
    errors << "bun: current seed-build proof bootstrap-seed rule set mismatch" unless receipt.dig("configure", "bootstrap_seed_rule_scope_verified") == true && receipt.dig("configure", "bootstrap_seed_rules") == expected_rules
    errors << "bun: current seed-build proof graph mismatch" unless receipt.dig("configure", "install_edges") == 3 && receipt.dig("configure", "native_fetch_edges") == dependency_stage["selected_github_archives"] && receipt.dig("configure", "node_header_fetch_edges") == dependency_stage["selected_node_header_archives"]
    errors << "bun: current seed-build proof graph checks are incomplete" unless %w[local_webkit_verified zig_fetch_absent zig_source_cwd_verified fedora_shared_cxx_runtime_verified system_lolhtml_provider_verified unexpected_urls_absent].all? { |key| receipt.dig("configure", key) == true }
    errors << "bun: current seed-build proof output version mismatch" unless receipt.dig("build", "version") == version
    errors << "bun: current seed-build proof revision mismatch" unless receipt.dig("build", "revision") == "#{version}-canary.1+#{package.upstream['source_commit'].to_s[0, 9]}"
    outputs = %w[bun_profile bun linker_map].map { |key| receipt.dig("build", key) }
    valid_outputs = outputs.all? { |output| output.is_a?(Hash) && output["path"].is_a?(String) && !Pathname.new(output["path"]).absolute? && !Pathname.new(output["path"]).each_filename.include?("..") && output["size_bytes"].is_a?(Integer) && output["size_bytes"].positive? && output["sha256"].to_s.match?(/\A[0-9a-f]{64}\z/) }
    errors << "bun: current seed-build output receipts are invalid" unless valid_outputs
    errors << "bun: current seed-build stripped output is not smaller than bun-profile" unless receipt.dig("build", "bun", "size_bytes").is_a?(Integer) && receipt.dig("build", "bun_profile", "size_bytes").is_a?(Integer) && receipt.dig("build", "bun", "size_bytes") < receipt.dig("build", "bun_profile", "size_bytes")
    errors << "bun: current seed-build runtime validation is incomplete" unless receipt.dig("build", "smoke_verified") == true && receipt.dig("build", "html_rewriter_smoke_verified") == true && receipt.dig("build", "stripped_output_verified") == true && receipt.dig("build", "fedora_shared_cxx_runtime_verified") == true && receipt.dig("build", "system_lolhtml_provider_verified") == true && receipt.dig("build", "shared_runtime_libraries") == %w[libgcc_s.so.1 libstdc++.so.6 liblolhtml.so.1]
    errors << "bun: current seed-build found a seed payload" unless receipt.dig("seed_contamination", "payload_absent_verified") == true && receipt.dig("seed_contamination", "seed_hash_matches") == 0
    errors << "bun: current seed-build found a seed runtime dependency" unless receipt.dig("seed_contamination", "runtime_dependency_absent_verified") == true
    errors << "bun: current seed-build validation is incomplete" unless %w[bootstrap_seed_verified seed_isolated_verified source_build_verified].all? { |key| receipt.dig("validation", key) == true }
    errors << "bun: current seed-build overclaims later gates" unless receipt.dig("validation", "self_rebuild_performed") == false && receipt.dig("validation", "reproducibility_compared") == false && receipt.dig("validation", "complete_lgpl_relink_materials_verified") == false && receipt.dig("validation", "final_license_audit_verified") == false && receipt.dig("validation", "final_rpm_verified") == false
    errors
  rescue KeyError, TypeError => e
    ["bun: invalid current seed-build proof receipt: #{e.message}"]
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
    release_local_staging = source_inputs.is_a?(Hash) && source_inputs["release_local_staging"]
    source_license_inventory = source_inputs.is_a?(Hash) && source_inputs["source_license_inventory"]
    final_linked_license_closure = source_inputs.is_a?(Hash) && source_inputs["final_linked_license_closure"]
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
    errors.concat(validate_bun_minimized_webkit_source(package, webkit, version, spec))

    errors.concat(validate_bun_dependency_closure(package, stages["dependency_closure"], webkit, version))
    errors.concat(validate_bun_npm_offline_install(package, stages["dependency_closure"], version))
    errors.concat(validate_bun_system_lolhtml(package, lolhtml, stages, version, spec))
    errors.concat(validate_bun_source_delivery(package, stages["source_delivery"], stages["dependency_closure"], version, spec))
    errors.concat(validate_bun_lolhtml_rpm_cargo(package, stages["lolhtml_rpm_cargo"], stages["dependency_closure"], lolhtml, version, spec))
    errors.concat(validate_bun_dependency_staging(package, stages["dependency_staging"], stages["source_delivery"], stages["dependency_closure"], release_local_staging, version, spec))
    errors.concat(validate_bun_source_license_inventory(package, source_license_inventory, stages["dependency_closure"], version, spec))
    errors.concat(validate_bun_final_linked_license_closure(package, final_linked_license_closure, source_license_inventory, stages, lolhtml, version, spec))

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
          if seed_stage["historical_only"] != true
            errors.concat(validate_bun_current_first_build_receipt(package, receipt, seed_stage, stages, source_inputs, version))
          else
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
              !Pathname.new(output["path"]).absolute? && !Pathname.new(output["path"]).each_filename.include?("..") &&
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
          end
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
            historical_relink = seed_stage["historical_only"] == true
            expected_relink_schema = historical_relink ? "bun-relink-materials-audit/v2" : "bun-relink-materials-audit/v3"
            errors << "bun: unsupported relink-materials proof receipt schema" unless receipt["schema"] == expected_relink_schema
            errors << "bun: relink-materials proof package mismatch" unless receipt["package"] == "bun"
            errors << "bun: relink-materials proof release mismatch" unless receipt["version"] == version
            errors << "bun: relink-materials proof date mismatch" unless receipt["date"] == (audit["proof_date"] || seed_stage["proof_date"])
            unless historical_relink
              dependency_stage = stages.fetch("dependency_closure")
              proof_kind = receipt.dig("source_build", "proof_kind")
              build_stage = proof_kind == "self_rebuild" ? stages["self_rebuild"] : seed_stage
              valid_build_kind = %w[first_build self_rebuild].include?(proof_kind)
              errors << "bun: current relink-materials source build mismatch" unless valid_build_kind && build_stage.is_a?(Hash) &&
                receipt.dig("source_build", "receipt") == build_stage["proof_receipt"] &&
                receipt.dig("source_build", "receipt_sha256") == build_stage["proof_receipt_sha256"] &&
                receipt.dig("source_build", "source_closure_sha256") == dependency_stage["proof_receipt_sha256"]
              expected_provider = lolhtml.slice("package", "version", "c_api_version", "pkgconfig", "soname", "build_requirement")
              provider = receipt["system_lolhtml_provider"]
              errors << "bun: current relink-materials system lol-html provider mismatch" unless valid_bun_staged_lolhtml_provider?(provider, expected_provider)
            end

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
              path.is_a?(String) && !path.empty? && !Pathname.new(path).absolute? && !Pathname.new(path).each_filename.include?("..") &&
                entry["size_bytes"].is_a?(Integer) && entry["size_bytes"].positive? &&
                entry["sha256"].to_s.match?(/\A[0-9a-f]{64}\z/) && entry["kind"] == "archive"
            end
            errors << "bun: relink-materials proof archive inventory is invalid" unless valid_archives
            expected_archive_count = historical_relink ? 4 : 3
            errors << "bun: relink-materials proof archive count mismatch" unless audit["direct_archive_count"] == expected_archive_count
            errors << "bun: current relink-materials proof retains private lol-html" if !historical_relink && archives.is_a?(Array) && archives.any? { |entry| entry["path"].to_s.include?("/lolhtml/") }

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
            expected_bootstrap_wrapper = historical_relink
            errors << "bun: relink-materials proof bootstrap-wrapper result mismatch" unless receipt.dig("final_link", "bootstrap_seed_wrapper_invoked") == audit["bootstrap_seed_wrapper_invoked"] && receipt.dig("final_link", "bootstrap_seed_wrapper_invoked") == expected_bootstrap_wrapper
            errors << "bun: relink-materials proof presence checks are incomplete" unless %w[direct_objects_present direct_archives_present link_scripts_present linker_map_present build_ninja_present compile_commands_present configure_present generated_webkit_headers_present].all? { |key| receipt.dig("presence", key) == true }
            errors << "bun: relink-materials proof response-file blocker mismatch" unless receipt.dig("blockers", "response_files_not_retained") == true
            errors << "bun: relink-materials proof bootstrap-wrapper blocker mismatch" unless receipt.dig("blockers", "bootstrap_seed_wrapper_invoked") == expected_bootstrap_wrapper
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

    if seed_stage.is_a?(Hash) && seed_stage.key?("relink_kit")
      metadata = seed_stage["relink_kit"]
      unless metadata.is_a?(Hash)
        errors << "bun: relink-kit metadata must be an object"
      else
        receipt_name = metadata["proof_receipt"]
        receipt_path = receipt_name.is_a?(String) && File.join(package.directory, receipt_name)
        unless receipt_path && File.file?(receipt_path)
          errors << "bun: relink-kit proof receipt is missing: #{receipt_name.inspect}"
        else
          begin
            receipt = JSON.parse(File.read(receipt_path))
            expected_sha256 = metadata["proof_receipt_sha256"]
            errors << "bun: relink-kit proof receipt SHA-256 mismatch" unless expected_sha256.to_s.match?(/\A[0-9a-f]{64}\z/) && Digest::SHA256.file(receipt_path).hexdigest == expected_sha256
            historical_relink = seed_stage["historical_only"] == true
            expected_kit_schema = historical_relink ? "bun-relink-kit/v1" : "bun-relink-kit/v2"
            expected_audit_schema = historical_relink ? "bun-relink-materials-audit/v2" : "bun-relink-materials-audit/v3"
            errors << "bun: unsupported relink-kit proof receipt schema" unless receipt["schema"] == expected_kit_schema
            errors << "bun: relink-kit proof package mismatch" unless receipt["package"] == "bun"
            errors << "bun: relink-kit proof release mismatch" unless receipt["version"] == version
            errors << "bun: relink-kit proof date mismatch" unless receipt["date"] == (metadata["proof_date"] || seed_stage["proof_date"])

            audit = seed_stage["relink_materials_audit"]
            errors << "bun: relink-kit source audit mismatch" unless audit.is_a?(Hash) &&
              receipt.dig("source_audit", "schema") == expected_audit_schema &&
              receipt.dig("source_audit", "sha256") == audit["proof_receipt_sha256"] &&
              receipt.dig("source_audit", "link_manifest_sha256") == audit["link_manifest_sha256"] &&
              receipt.dig("source_audit", "direct_object_inventory_sha256") == audit["direct_object_inventory_sha256"]

            kit = receipt["kit"]
            errors << "bun: relink-kit archive metadata mismatch" unless kit.is_a?(Hash) &&
              kit["root_name"] == "bun-#{version}-relink-kit" &&
              kit["archive"] == metadata["archive"] &&
              kit["archive_size_bytes"] == metadata["archive_bytes"] &&
              kit["archive_sha256"] == metadata["archive_sha256"] &&
              metadata["archive_hosted"] == false

            summary = kit.is_a?(Hash) && kit["payload_summary"]
            if historical_relink
              expected_summary = {
                "object_count" => 1162,
                "archive_count" => 4,
                "linker_script_count" => 2,
                "generated_header_entry_count" => 2294,
                "generated_header_target_count" => 1415,
                "response_file_input_count" => 1166
              }
              errors << "bun: relink-kit payload summary mismatch" unless summary.is_a?(Hash) && expected_summary.all? { |key, value| summary[key] == value }
            else
              valid_summary = summary.is_a?(Hash) && summary["object_count"] == audit["direct_object_count"] &&
                              summary["archive_count"] == audit["direct_archive_count"] && summary["linker_script_count"] == 2 &&
                              summary["generated_header_entry_count"] == audit["generated_webkit_header_count"] &&
                              summary["generated_header_target_count"].is_a?(Integer) && summary["generated_header_target_count"].positive? &&
                              summary["response_file_input_count"] == audit["direct_object_count"] + audit["direct_archive_count"]
              errors << "bun: current relink-kit payload summary mismatch" unless valid_summary
            end

            errors << "bun: relink-kit payload manifest mismatch" unless kit.is_a?(Hash) && kit.dig("payload_manifest", "sha256") == metadata["payload_manifest_sha256"]
            errors << "bun: relink-kit response file mismatch" unless kit.is_a?(Hash) && kit.dig("response_file", "sha256") == metadata["response_file_sha256"]
            valid_records = %w[payload_manifest link_command relink_script readme response_file].all? do |key|
              record = kit.is_a?(Hash) && kit[key]
              path = record.is_a?(Hash) && record["path"]
              path.is_a?(String) && !path.empty? && !Pathname.new(path).absolute? && !Pathname.new(path).each_filename.include?("..") &&
                record["size_bytes"].is_a?(Integer) && record["size_bytes"].positive? &&
                record["sha256"].to_s.match?(/\A[0-9a-f]{64}\z/)
            end
            errors << "bun: relink-kit payload records are invalid" unless valid_records

            validation_keys = %w[
              archive_generated payload_manifest_generated response_file_reconstructed
              wrapper_free_link_command_generated proof_root_paths_removed_from_link_command
              archive_extraction_verified network_isolated_link_verified relinked_output_verified
              retained_profile_sha256_equal retained_linker_map_sha256_equal smoke_verified
              fedora_shared_cxx_runtime_verified seed_payload_absent_verified
              seed_runtime_dependency_absent_verified
            ]
            validation_keys.concat(%w[system_lolhtml_provider_verified html_rewriter_smoke_verified]) unless historical_relink
            errors << "bun: relink-kit proof validation is incomplete" unless validation_keys.all? { |key| receipt.dig("validation", key) == true }

            link = receipt["link_validation"]
            errors << "bun: relink-kit output proof mismatch" unless link.is_a?(Hash) &&
              link["network_namespace"] == true && link["version"] == version &&
              link.dig("output", "path") == "build/release-local/bun-profile" &&
              link.dig("output", "sha256") == metadata["relinked_output_sha256"] &&
              link.dig("output", "retained_profile_sha256") == metadata["relinked_output_sha256"] &&
              link.dig("output", "retained_profile_sha256_equal") == true &&
              link.dig("linker_map", "path") == "build/release-local/bun-profile.linker-map" &&
              link.dig("linker_map", "sha256") == metadata["linker_map_sha256"] &&
              link.dig("linker_map", "retained_linker_map_sha256") == metadata["linker_map_sha256"] &&
              link.dig("linker_map", "retained_linker_map_sha256_equal") == true
            expected_runtime_libraries = historical_relink ? %w[libgcc_s.so.1 libstdc++.so.6] : %w[libgcc_s.so.1 libstdc++.so.6 liblolhtml.so.1]
            errors << "bun: relink-kit runtime proof is incomplete" unless link.is_a?(Hash) &&
              link["smoke_verified"] == true && (historical_relink || link["html_rewriter_smoke_verified"] == true) && link["fedora_shared_cxx_runtime_verified"] == true &&
              link["shared_runtime_libraries"] == expected_runtime_libraries &&
              (historical_relink || link["system_lolhtml_provider_verified"] == true) &&
              link["seed_payload_absent_verified"] == true && link["seed_runtime_dependency_absent_verified"] == true

            errors << "bun: relink-kit completeness mismatch" unless receipt["complete_lgpl_relink_materials_verified"] == metadata["complete_lgpl_relink_materials_verified"] && receipt["complete_lgpl_relink_materials_verified"] == true
            errors << "bun: relink-kit proof incorrectly claims a final license audit" unless receipt["final_license_audit_verified"] == false
            errors << "bun: relink-kit proof incorrectly claims a final RPM" unless receipt["final_rpm_verified"] == false
          rescue JSON::ParserError => e
            errors << "bun: invalid relink-kit proof receipt: #{e.message}"
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
          driver_kind = driver.is_a?(Hash) && driver["driver_proof_kind"]
          errors << "bun: self-rebuild proof driver kind mismatch" unless %w[first_build self_rebuild].include?(driver_kind)
          driver_receipt_name = driver.is_a?(Hash) && driver["driver_receipt"]
          driver_receipt_path = driver_receipt_name.is_a?(String) && File.join(package.directory, driver_receipt_name)
          if driver_receipt_path && File.file?(driver_receipt_path)
            driver_receipt_sha256 = Digest::SHA256.file(driver_receipt_path).hexdigest
            errors << "bun: self-rebuild proof driver receipt SHA-256 mismatch" unless driver["driver_receipt_sha256"] == driver_receipt_sha256
            driver_receipt = JSON.parse(File.read(driver_receipt_path))
            expected_driver_schema = driver_kind == "self_rebuild" ? "bun-self-rebuild-proof/v2" : (self_stage["historical_only"] == true ? "bun-first-source-build-proof/v1" : "bun-first-source-build-proof/v2")
            errors << "bun: self-rebuild proof driver receipt schema mismatch" unless driver_receipt["schema"] == expected_driver_schema
            if driver_kind == "first_build"
              errors << "bun: self-rebuild proof driver receipt mismatch" unless driver_receipt_name == seed_stage["proof_receipt"] && driver["driver_receipt_sha256"] == seed_stage["proof_receipt_sha256"]
            else
              errors << "bun: self-rebuild proof driver receipt is recursive" if driver_receipt_name == receipt_name
              errors << "bun: self-rebuild proof driver is not verified" unless driver_receipt.dig("validation", "self_rebuild_performed") == true
            end
            driver_output = driver_receipt.dig("build", "bun")
            valid_driver_binary = driver.is_a?(Hash) && driver_output.is_a?(Hash) &&
                                  driver["sha256"] == driver_output["sha256"] &&
                                  driver["size_bytes"] == driver_output["size_bytes"]
            errors << "bun: self-rebuild proof driver binary mismatch" unless valid_driver_binary
            valid_driver_path = driver.is_a?(Hash) && driver_output.is_a?(Hash) &&
                                driver["path"].to_s.end_with?("/#{driver_output['path']}")
            errors << "bun: self-rebuild proof driver path mismatch" unless valid_driver_path
          else
            errors << "bun: self-rebuild proof driver receipt is missing: #{driver_receipt_name.inspect}"
          end

          dependency_stage = stages.fetch("dependency_closure")
          historical_self_rebuild = self_stage["historical_only"] == true
          closure_contract = if historical_self_rebuild
                               dependency_stage.fetch("historical_lolhtml_graph")
                             else
                               dependency_stage
                             end
          expected_closure_path = closure_contract["proof_receipt"] || File.basename(closure_contract.fetch("proof_receipt_path_at_commit"))
          errors << "bun: self-rebuild proof source-closure path mismatch" unless receipt.dig("source_closure", "path") == expected_closure_path
          errors << "bun: self-rebuild proof source-closure SHA-256 mismatch" unless receipt.dig("source_closure", "sha256") == closure_contract["proof_receipt_sha256"]
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
          errors << "bun: self-rebuild proof native-fetch count mismatch" unless receipt.dig("configure", "native_fetch_edges") == closure_contract["selected_github_archives"]
          errors << "bun: self-rebuild proof Node-header fetch count mismatch" unless receipt.dig("configure", "node_header_fetch_edges") == closure_contract["selected_node_header_archives"]
          errors << "bun: self-rebuild proof did not use local WebKit" unless receipt.dig("configure", "local_webkit_verified") == true
          errors << "bun: self-rebuild proof retained a Zig fetch edge" unless receipt.dig("configure", "zig_fetch_absent") == true
          errors << "bun: self-rebuild proof did not verify the Zig source cwd" unless receipt.dig("configure", "zig_source_cwd_verified") == true
          if historical_self_rebuild
            errors << "bun: self-rebuild proof did not verify stable lol-html Cargo" unless receipt.dig("configure", "stable_lolhtml_cargo_verified") == true
          else
            errors.concat(validate_bun_current_self_npm_proof(package, dependency_stage, receipt, driver, version))
            provider = receipt.dig("inputs", "offline_inputs", "system_lolhtml_provider")
            expected_provider = lolhtml.slice("package", "version", "c_api_version", "pkgconfig", "soname", "build_requirement")
            errors << "bun: current self-rebuild proof did not verify system lol-html" unless receipt.dig("configure", "system_lolhtml_provider_verified") == true &&
              receipt.dig("inputs", "offline_inputs", "cargo_source_archives") == 0 && valid_bun_staged_lolhtml_provider?(provider, expected_provider)
          end
          errors << "bun: self-rebuild proof contains unexpected URLs" unless receipt.dig("configure", "unexpected_urls_absent") == true
          errors << "bun: self-rebuild proof output version mismatch" unless receipt.dig("build", "version") == version
          errors << "bun: self-rebuild proof revision mismatch" unless receipt.dig("build", "revision") == "#{version}-canary.1+#{package.upstream['source_commit'].to_s[0, 9]}"
          output_receipts = %w[bun_profile bun linker_map].map { |key| [key, receipt.dig("build", key)] }
          output_receipts.each do |key, output|
            valid_output = output.is_a?(Hash) && output["path"].is_a?(String) && !output["path"].empty? &&
              !Pathname.new(output["path"]).absolute? && !Pathname.new(output["path"]).each_filename.include?("..") &&
              output["size_bytes"].is_a?(Integer) && output["size_bytes"].positive? &&
              output["sha256"].to_s.match?(/\A[0-9a-f]{64}\z/)
            errors << "bun: self-rebuild proof has an invalid #{key} receipt" unless valid_output
          end
          profile_size = receipt.dig("build", "bun_profile", "size_bytes")
          bun_size = receipt.dig("build", "bun", "size_bytes")
          errors << "bun: self-rebuild proof stripped output is not smaller than bun-profile" unless profile_size.is_a?(Integer) && bun_size.is_a?(Integer) && bun_size < profile_size
          errors << "bun: self-rebuild proof smoke failed" unless receipt.dig("build", "smoke_verified") == true
          errors << "bun: current self-rebuild proof HTMLRewriter smoke failed" if !historical_self_rebuild && receipt.dig("build", "html_rewriter_smoke_verified") != true
          errors << "bun: self-rebuild proof did not verify stripped output" unless receipt.dig("build", "stripped_output_verified") == true
          errors << "bun: self-rebuild proof did not verify Fedora's shared C++ runtime" unless receipt.dig("build", "fedora_shared_cxx_runtime_verified") == true
          expected_shared_libraries = historical_self_rebuild ? %w[libgcc_s.so.1 libstdc++.so.6] : %w[libgcc_s.so.1 libstdc++.so.6 liblolhtml.so.1]
          errors << "bun: self-rebuild proof shared-runtime library set mismatch" unless receipt.dig("build", "shared_runtime_libraries") == expected_shared_libraries
          errors << "bun: current self-rebuild proof did not verify system lol-html runtime" if !historical_self_rebuild && receipt.dig("build", "system_lolhtml_provider_verified") != true
          errors << "bun: self-rebuild proof found a seed payload" unless receipt.dig("seed_contamination", "payload_absent_verified") == true && receipt.dig("seed_contamination", "seed_hash_matches") == 0
          errors << "bun: self-rebuild proof found a seed runtime dependency" unless receipt.dig("seed_contamination", "runtime_dependency_absent_verified") == true
          errors << "bun: self-rebuild proof did not compare reproducibility" unless receipt.dig("reproducibility", "compared") == true
          errors << "bun: self-rebuild proof reproducibility driver mismatch" unless receipt.dig("reproducibility", "driver_proof_kind") == driver_kind && receipt.dig("reproducibility", "driver_receipt_sha256") == driver["driver_receipt_sha256"]
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
        errors << "bun: Zig reproducibility proof receipt is missing: #{zig_receipt_name.inspect}" if self_stage["historical_only"] == true || zig_receipt_name
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

      control = self_stage["zig_single_thread_control"]
      if control
        unless control.is_a?(Hash)
          errors << "bun: Zig single-thread control metadata must be an object"
        else
          control_name = control["proof_receipt"]
          control_path = control_name.is_a?(String) && File.join(package.directory, control_name)
          unless control_path && File.file?(control_path)
            errors << "bun: Zig single-thread control receipt is missing: #{control_name.inspect}"
          else
            begin
              control_receipt = JSON.parse(File.read(control_path))
              control_sha256 = control["proof_receipt_sha256"]
              errors << "bun: Zig single-thread control receipt SHA-256 mismatch" unless control_sha256.to_s.match?(/\A[0-9a-f]{64}\z/) && Digest::SHA256.file(control_path).hexdigest == control_sha256
              errors << "bun: unsupported Zig single-thread control receipt schema" unless control_receipt["schema"] == "bun-zig-single-thread-control/v1"
              errors << "bun: Zig single-thread control package mismatch" unless control_receipt["package"] == "bun"
              errors << "bun: Zig single-thread control release mismatch" unless control_receipt["release"] == version
              errors << "bun: Zig single-thread control date mismatch" unless control_receipt["proof_date"] == self_stage["proof_date"]
              errors << "bun: Zig single-thread control platform mismatch" unless control_receipt["proof_platform"] == self_stage["proof_platform"]
              errors << "bun: Zig single-thread control source mismatch" unless zig.is_a?(Hash) && control_receipt.dig("source", "zig_commit") == zig["commit"]
              errors << "bun: Zig single-thread control compiler mismatch" unless control_receipt.dig("compiler", "single_threaded_sha256") == control["compiler_sha256"]

              experiment = control_receipt["experiment"]
              errors << "bun: Zig single-thread control execution mismatch" unless experiment.is_a?(Hash) &&
                experiment["network_namespace"] == true && experiment["top_level_jobs"] == 1 &&
                experiment["parallel_sema_environment_present"] == false && experiment["llvm_codegen_threads"] == 32
              runs = experiment.is_a?(Hash) && experiment["runs"]
              valid_runs = runs.is_a?(Array) && runs.length == 2 && runs.all? do |run|
                run.is_a?(Hash) && run["object_count"] == control["object_count"] &&
                  run["object_aggregate_sha256"] == control["object_aggregate_sha256"] &&
                  run["trace_count"] == control["trace_count"] && run["trace_sha256"] == control["trace_sha256"] &&
                  run["sorted_trace_sha256"].to_s.match?(/\A[0-9a-f]{64}\z/) && run["log_sha256"].to_s.match?(/\A[0-9a-f]{64}\z/)
              end
              errors << "bun: Zig single-thread control run inventory mismatch" unless valid_runs

              comparison = control_receipt["comparison"]
              errors << "bun: Zig single-thread control comparison mismatch" unless comparison.is_a?(Hash) &&
                comparison["object_aggregates_equal"] == control["combined_single_thread_control_reproducible"] &&
                comparison["object_aggregates_equal"] == true && comparison["changed_object_count"] == 0 &&
                comparison["raw_traces_equal"] == true && comparison["sorted_traces_equal"] == true
              validation = control_receipt["validation"]
              errors << "bun: Zig single-thread control overclaims a production fix" unless validation.is_a?(Hash) &&
                validation["combined_single_thread_control_reproducible"] == true &&
                validation["intern_pool_only_isolation_verified"] == false &&
                validation["production_fix_verified"] == control["production_fix_verified"] &&
                validation["production_fix_verified"] == false &&
                validation["canonical_package_sources_modified"] == false
            rescue JSON::ParserError => e
              errors << "bun: invalid Zig single-thread control receipt: #{e.message}"
            end
          end
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

  def update_package_files(package, version:, sha256:, source_url: nil, changelog_message:)
    manifest_data = Marshal.load(Marshal.dump(package.data))
    manifest_data.fetch("upstream")["current_version"] = version
    manifest_data.fetch("upstream")["source_sha256"] = sha256
    manifest_data.fetch("upstream")["source_url"] = source_url if source_url
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

    selected_audit = JSON.parse(File.read(selected_path))
    source_audit = JSON.parse(File.read(source_path))
    sources = Array(source_audit["sources"])
    expected_models_snapshot = {
      "required" => true,
      "source_url" => "https://models.dev/api.json",
      "immutable_source_recorded" => false,
      "supplied_to_audit" => false
    }
    models_snapshot = dependencies.dig("selected_lock_audit", "models_snapshot")
    errors << "#{prefix} models snapshot policy does not match" unless models_snapshot == expected_models_snapshot
    errors << "#{prefix} models snapshot receipt does not match" unless selected_audit["models_snapshot"] == models_snapshot
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
      "source_audit_sha256" => dependencies.dig("source_acquisition_receipt", "sha256"),
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

      opentui_version = dependencies.dig("current_sensitive_versions", "@opentui/core").to_s
      required_subordinate_sources = {
        "@opentui/core@#{opentui_version}" => {
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

      opentui_identity = "@opentui/core-linux-x64@#{opentui_version}"
      opentui = components.find { |component| component["package"] == opentui_identity }
      expected_opentui_build = {
        "source_url" => "https://github.com/anomalyco/opentui/archive/refs/tags/v0.4.5.tar.gz",
        "source_sha256" => "a87acc1af6d5f62ee48905176965514b06c7b6e8f9c1fe869604e5933825ca50",
        "source_commit" => "0c8c4f7cff2927e3df63a9757a45eff9a343611c",
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
        "platform_package" => "@opentui/core-linux-x64@0.4.5",
        "platform_payload" => "libopentui.so",
        "published_payload_sha256" => "0c557e6f59b397c35d25eaa28d874a054f7bffecaf90c521a2a0307ede45bd1f",
        "previous_release_proof" => {
          "release" => "0.4.3",
          "local_recipe_output_sha256" => "1ce4b92b1a075602837c361c6423b7b54298d0c402e3801cbeb27e4e7d935baa",
          "ffi_exports" => %w[bufferDrawBox createRenderer destroyRenderer render yogaNodeCreate],
          "dynamic_libraries" => %w[libm.so.6 libpthread.so.0 libc.so.6 libdl.so.2 ld-linux-x86-64.so.2],
          "max_glibc" => "GLIBC_2.17",
          "offline_build_verified" => true,
          "ctypes_dlopen_verified" => true
        },
        "byte_reproducible" => false,
        "reproducibility_required_by_fedora" => false,
        "linked_source_licenses" => %w[opentui-LICENSE opentui-uucode-LICENSE.md opentui-yoga-LICENSE],
        "offline_build_verified" => false,
        "ctypes_dlopen_verified" => false,
        "bun_ffi_smoke_in_spec" => true,
        "published_payload_discarded" => true,
        "final_bun_embedding_verified" => false,
        "f43_f44_builds_verified" => false,
        "local_proof_only" => false
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
        "Release:        0.1%{?dist}",
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
        "cargo_vendor_archive" => "opencode-#{release}-bun-pty-cargo-vendor.tar.zst",
        "cargo_vendor_sha256" => "5c22d4bd79109a3460f3a3d3840d2541da9a6c4c91513c39065a1f4611b7ec5e",
        "cargo_vendor_crates" => 43,
        "cargo_vendor_manifest" => "opencode-#{release}-bun-pty-cargo-vendor.txt",
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
