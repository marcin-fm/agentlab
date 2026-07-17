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
          "reason" => "Node prebuilds are omitted; the required grammar WASM remains a separate source-build gate."
        },
        {
          "package" => "tree-sitter-powershell@0.25.10",
          "phase" => "install",
          "script" => "node-gyp-build",
          "action" => "skip_native_loader_rebuild_wasm",
          "reason" => "The selected shell parser consumes the grammar WASM, whose source build remains a separate gate."
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
        "Release:        0.6%{?dist}",
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
