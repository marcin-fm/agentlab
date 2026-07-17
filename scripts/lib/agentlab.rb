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

  def load_yaml(path)
    YAML.safe_load(File.read(path), aliases: false) || {}
  rescue Psych::Exception => e
    raise Error, "invalid YAML in #{path}: #{e.message}"
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
    mode = File.stat(path).mode & 0o777
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
