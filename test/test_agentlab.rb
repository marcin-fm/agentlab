# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require "tmpdir"
require "yaml"
require_relative "../scripts/lib/agentlab"

class AgentlabTest < Minitest::Test
  def registry_entry(overrides = {})
    {
      "npm_name" => "zod",
      "version" => "3.24.2",
      "origin" => "registry",
      "role" => "runtime",
      "included_in_binary" => true,
      "source_url" => "https://registry.npmjs.org/zod/-/zod-3.24.2.tgz",
      "integrity" => "sha512-fixture",
      "sha256" => "a" * 64,
      "license" => "MIT",
      "source_verified" => true
    }.merge(overrides)
  end

  def test_parses_jsonc_comments_and_trailing_commas
    parsed = Agentlab.parse_jsonc(<<~JSONC, source: "fixture")
      {
        // Keep URLs inside strings intact.
        "url": "https://example.test/a//b",
        "items": [
          "one",
          "two",
        ],
        /* block comment */
        "nested": {
          "enabled": true,
        },
      }
    JSONC

    assert_equal("https://example.test/a//b", parsed.fetch("url"))
    assert_equal(%w[one two], parsed.fetch("items"))
    assert_equal(true, parsed.dig("nested", "enabled"))
  end

  def test_rejects_invalid_jsonc
    error = assert_raises(Agentlab::Error) do
      Agentlab.parse_jsonc("{ /* unfinished", source: "fixture")
    end

    assert_match(/invalid JSONC in fixture/, error.message)
  end

  def test_generates_fedora_node_bundled_provides
    closure = {
      "packages" => [
        registry_entry,
        registry_entry("npm_name" => "@anthropic-ai/sdk", "version" => "0.39.0", "sha256" => "b" * 64),
        registry_entry("npm_name" => "test-only", "role" => "test", "included_in_binary" => false)
      ]
    }

    assert_equal(
      [
        "Provides:       bundled(nodejs-@anthropic-ai/sdk) = 0.39.0",
        "Provides:       bundled(nodejs-zod) = 3.24.2"
      ],
      Agentlab.node_bundled_provides(closure)
    )
  end

  def test_rejects_unverified_sources
    error = assert_raises(Agentlab::Error) do
      Agentlab.node_bundled_provides("packages" => [registry_entry("source_verified" => false)])
    end

    assert_match(/source is not verified/, error.message)
  end

  def test_rejects_test_dependency_marked_as_embedded
    error = assert_raises(Agentlab::Error) do
      Agentlab.node_bundled_provides(
        "packages" => [registry_entry("role" => "test", "included_in_binary" => true)]
      )
    end

    assert_match(/only runtime dependencies/, error.message)
  end

  def test_release_change_invalidates_closure_audit
    Dir.mktmpdir do |directory|
      path = File.join(directory, "dependencies.yml")
      File.write(path, YAML.dump(
        "target_release" => "1.0.0",
        "closure_audit" => {
          "audited_release" => "1.0.0",
          "licenses_verified" => true,
          "upstream_contact_recorded" => true,
          "notes" => "preserve"
        },
        "source_closure_files" => {
          "closure_manifest" => "opencode-1.0.0-closure.json"
        }
      ))
      package = Agentlab::Package.new(directory: directory, manifest_path: "unused", data: {})

      change = Agentlab.updated_dependency_audit(package, "1.1.0")
      updated = YAML.safe_load(change.fetch(:content), aliases: false)

      assert_equal("1.1.0", updated["target_release"])
      assert_nil(updated.dig("closure_audit", "audited_release"))
      refute(updated.dig("closure_audit", "licenses_verified"))
      refute(updated.dig("closure_audit", "upstream_contact_recorded"))
      assert_equal("preserve", updated.dig("closure_audit", "notes"))
      assert_equal("opencode-1.1.0-closure.json", updated.dig("source_closure_files", "closure_manifest"))
    end
  end

  def test_write_transaction_rolls_back_completed_writes
    Dir.mktmpdir do |directory|
      first = File.join(directory, "first")
      second = File.join(directory, "second")
      File.write(first, "old first")
      File.write(second, "old second")
      original_writer = Agentlab.method(:atomic_write)
      calls = 0
      failing_writer = lambda do |path, content|
        calls += 1
        raise "simulated write failure" if calls == 2

        original_writer.call(path, content)
      end

      Agentlab.singleton_class.send(:define_method, :atomic_write, failing_writer)
      begin
        assert_raises(RuntimeError) do
          Agentlab.write_transaction(first => "new first", second => "new second")
        end
      ensure
        Agentlab.singleton_class.send(:define_method, :atomic_write, original_writer)
      end

      assert_equal("old first", File.read(first))
      assert_equal("old second", File.read(second))
    end
  end

  def test_atomic_write_creates_new_file
    Dir.mktmpdir do |directory|
      path = File.join(directory, "new-file")

      Agentlab.atomic_write(path, "content")

      assert_equal("content", File.read(path))
      assert_equal(0o644, File.stat(path).mode & 0o777)
    end
  end

  def test_authorization_is_limited_to_original_host
    token = "secret"

    assert_equal(
      "Bearer secret",
      Agentlab.authorization_header(URI("https://api.github.com/repos/example"), "api.github.com", token)
    )
    assert_nil(
      Agentlab.authorization_header(URI("https://objects.githubusercontent.com/archive"), "api.github.com", token)
    )
    assert_nil(
      Agentlab.authorization_header(URI("https://registry.npmjs.org/package"), "registry.npmjs.org", token)
    )
  end

  def test_copr_command_uses_explicit_identity_config
    previous = ENV["COPR_CONFIG"]
    ENV["COPR_CONFIG"] = "/srv/identities/example/copr"

    assert_equal(
      ["copr-cli", "--config", "/srv/identities/example/copr", "get", "owner/project"],
      Agentlab.copr_command("get", "owner/project")
    )
  ensure
    ENV["COPR_CONFIG"] = previous
  end

  def test_copr_owner_verification_rejects_another_account
    Dir.mktmpdir do |directory|
      config_path = File.join(directory, "copr")
      File.write(config_path, "[copr-cli]\n")
      File.chmod(0o600, config_path)
      previous = ENV["COPR_CONFIG"]
      original_authenticated_owner = Agentlab.method(:copr_authenticated_owner)
      original_command_available = Agentlab.method(:command_available?)
      ENV["COPR_CONFIG"] = config_path
      Agentlab.singleton_class.send(:define_method, :command_available?) do |name|
        name == "copr-cli"
      end
      Agentlab.singleton_class.send(:define_method, :copr_authenticated_owner) do |_path|
        "another-owner"
      end

      error = assert_raises(Agentlab::Error) { Agentlab.verify_copr_owner!("marcin") }
      assert_match(/expected "marcin", got "another-owner"/, error.message)
    ensure
      Agentlab.singleton_class.send(:define_method, :copr_authenticated_owner, original_authenticated_owner)
      Agentlab.singleton_class.send(:define_method, :command_available?, original_command_available)
      ENV["COPR_CONFIG"] = previous
    end
  end

  def test_reads_only_the_copr_cli_config_section
    Dir.mktmpdir do |directory|
      config_path = File.join(directory, "copr")
      File.write(config_path, <<~CONFIG)
        [ignored]
        token = wrong

        [copr-cli]
        login = api-login
        token = api-token
        copr_url = https://copr.example.test/
        # expiration date: 2026-12-31
      CONFIG

      assert_equal(
        {
          "login" => "api-login",
          "token" => "api-token",
          "copr_url" => "https://copr.example.test/"
        },
        Agentlab.copr_config_values(config_path)
      )
    end
  end

  def test_recognizes_copr_cli_missing_package_response
    message = "Something went wrong:\nError: No package with name ast-grep in copr agentlab\n"

    assert(Agentlab.copr_resource_missing?(message))
    refute(Agentlab.copr_resource_missing?("Login invalid/expired"))
  end

  def test_copr_makefile_uses_stock_source_builder_tools
    makefile = File.read(File.expand_path("../.copr/Makefile", __dir__))

    refute_match(/\bspectool\b/, makefile)
    assert_includes(makefile, 'rpmspec -P "$(spec)"')
    assert_includes(makefile, "curl --fail --location --retry 3")
    assert_includes(makefile, 'filename="$${fragment#/}"')
  end

  def test_crates_io_version_selection_rejects_yanked_and_prerelease_versions
    response = JSON.dump(
      "versions" => [
        { "num" => "6.0.0-beta.1", "yanked" => false },
        { "num" => "5.0.2", "yanked" => true },
        { "num" => "5.0.1", "yanked" => false }
      ]
    )
    original_http_get = Agentlab.method(:http_get)
    Agentlab.singleton_class.send(:define_method, :http_get) do |_uri, json:|
      raise "expected JSON request" unless json

      response
    end
    begin
      assert_equal("5.0.1", Agentlab.crates_io_latest_version("dirs"))
    ensure
      Agentlab.singleton_class.send(:define_method, :http_get, original_http_get)
    end
  end

  def test_crates_io_version_selection_honors_compatibility_requirement
    response = JSON.dump(
      "versions" => [
        { "num" => "6.0.0", "yanked" => false },
        { "num" => "5.0.1", "yanked" => false }
      ]
    )
    original_http_get = Agentlab.method(:http_get)
    Agentlab.singleton_class.send(:define_method, :http_get) do |_uri, json:|
      raise "expected JSON request" unless json

      response
    end
    begin
      assert_equal("5.0.1", Agentlab.crates_io_latest_version("dirs", "~> 5.0"))
    ensure
      Agentlab.singleton_class.send(:define_method, :http_get, original_http_get)
    end
  end

  def test_static_release_provider_uses_recorded_version
    package = Agentlab::Package.new(
      directory: Dir.tmpdir,
      manifest_path: "unused",
      data: {
        "name" => "pdfium",
        "upstream" => {
          "provider" => "static",
          "current_version" => "146.0.7678.0"
        }
      }
    )

    assert_equal("146.0.7678.0", Agentlab.latest_upstream_version(package))
  end

  def test_package_chroots_override_project_defaults
    package = Agentlab::Package.new(
      directory: Dir.tmpdir,
      manifest_path: "unused",
      data: { "copr" => { "chroots" => ["fedora-44-x86_64"] } }
    )

    assert_equal(["fedora-44-x86_64"], package.chroots(["fedora-43-x86_64", "fedora-44-x86_64"]))
  end

  def test_package_chroots_use_project_defaults
    package = Agentlab::Package.new(directory: Dir.tmpdir, manifest_path: "unused", data: { "copr" => {} })
    defaults = ["fedora-43-x86_64", "fedora-44-x86_64"]

    assert_equal(defaults, package.chroots(defaults))
  end

  def test_validates_verified_bun_zig_stage
    Dir.mktmpdir do |directory|
      patch_path = File.join(directory, "zig-fedora-lib64.patch")
      File.write(patch_path, "patch")
      File.write(File.join(directory, "zig-bootstrap-proof.json"), JSON.dump(
        "schema" => 1,
        "package_release" => "bun-v1.3.14",
        "proof_platform" => "fedora-44-x86_64",
        "proof_date" => "2026-07-15",
        "source" => { "commit" => "a" * 40, "sha256" => "b" * 64 },
        "patch" => { "path" => "zig-fedora-lib64.patch", "sha256" => Digest::SHA256.file(patch_path).hexdigest },
        "toolchain" => { "target" => "native", "cpu" => "baseline", "shared_llvm" => true },
        "output" => {
          "version" => "0.15.2",
          "executable_sha256" => "c" * 64,
          "bun_layout_verified" => true,
          "source_execution_verified" => true,
          "external_zig_binary_used" => false
        }
      ))
      data = {
        "name" => "bun",
        "status" => "blocked",
        "upstream" => { "current_version" => "1.3.14" },
        "copr" => { "enabled" => false },
        "build_plan" => {
          "target_release" => "1.3.14",
          "source_inputs_reconciled" => true,
          "architectures" => ["x86_64"],
          "source_inputs" => {
            "zig" => {
              "release_pin" => "bun-v1.3.14",
              "commit" => "a" * 40,
              "sha256" => "b" * 64,
              "url" => "https://example.com/zig.tar.gz",
              "version_metadata" => "0.15.2",
              "patch" => "zig-fedora-lib64.patch"
            }
          },
          "stages" => Agentlab::BUN_BUILD_STAGES.to_h do |stage|
            [stage, { "state" => stage == "zig_source_bootstrap" ? "verified" : "blocked" }]
          end
        }
      }
      data.dig("build_plan", "stages", "zig_source_bootstrap").merge!(
        "source_bootstrap_verified" => true,
        "bun_layout_verified" => true,
        "external_zig_binary_used" => false,
        "proof_platform" => "fedora-44-x86_64",
        "proof_date" => "2026-07-15",
        "proof_receipt" => "zig-bootstrap-proof.json"
      )
      package = Agentlab::Package.new(directory: directory, manifest_path: "unused", data: data)
      spec = <<~SPEC
        %global zig_commit #{"a" * 40}
        %global zig_sha256 #{"b" * 64}
        Patch0:         zig-fedora-lib64.patch
        cmake --build build --target stage3
        install .build-tools/bun-zig/zig
      SPEC

      assert_empty(Agentlab.validate_bun_build_plan(package, spec))
    end
  end

  def test_rejects_bun_final_stage_before_prerequisites
    data = {
      "name" => "bun",
      "status" => "enabled",
      "upstream" => { "current_version" => "1.3.14" },
      "copr" => { "enabled" => true },
      "build_plan" => {
        "target_release" => "1.3.14",
        "source_inputs_reconciled" => true,
        "architectures" => ["x86_64"],
        "source_inputs" => {},
        "stages" => Agentlab::BUN_BUILD_STAGES.to_h do |stage|
          [stage, { "state" => stage == "final" ? "verified" : "blocked" }]
        end
      }
    }
    package = Agentlab::Package.new(directory: Dir.tmpdir, manifest_path: "unused", data: data)

    errors = Agentlab.validate_bun_build_plan(package, "exit 1\n")

    assert(errors.any? { |error| error.include?("final stage verified before") })
    assert(errors.any? { |error| error.include?("deliberate build stop") })
  end

  def test_bun_release_change_invalidates_build_plan
    manifest = {
      "build_plan" => {
        "target_release" => "1.3.14",
        "source_inputs" => {
          "zig" => {
            "release_pin" => "bun-v1.3.14",
            "commit" => "a" * 40,
            "url" => "https://example.com/zig.tar.gz",
            "sha256" => "b" * 64
          }
        },
        "stages" => {
          "zig_source_bootstrap" => {
            "state" => "verified",
            "source_bootstrap_verified" => true,
            "proof_date" => "2026-07-15"
          }
        }
      }
    }

    Agentlab.invalidate_bun_build_plan!(manifest, "1.3.15")

    assert_equal("1.3.15", manifest.dig("build_plan", "target_release"))
    refute(manifest.dig("build_plan", "source_inputs_reconciled"))
    assert_equal("blocked", manifest.dig("build_plan", "stages", "zig_source_bootstrap", "state"))
    refute(manifest.dig("build_plan", "stages", "zig_source_bootstrap", "source_bootstrap_verified"))
    assert_nil(manifest.dig("build_plan", "stages", "zig_source_bootstrap", "proof_date"))
    assert_equal("bun-v1.3.14", manifest.dig("build_plan", "source_inputs", "zig", "release_pin"))
    assert_equal("a" * 40, manifest.dig("build_plan", "source_inputs", "zig", "commit"))
    assert(manifest.dig("build_plan", "source_inputs", "zig", "stale"))
  end

  def test_validates_opencode_review_evidence
    package = Agentlab.package_named("opencode")
    dependencies = Agentlab.load_yaml(File.join(package.directory, "dependencies.yml"))

    assert_empty(Agentlab.validate_opencode_review_evidence(package, dependencies, "1.18.3"))
  end

  def test_rejects_incomplete_opencode_native_review_coverage
    source_package = Agentlab.package_named("opencode")
    dependencies = Agentlab.load_yaml(File.join(source_package.directory, "dependencies.yml"))

    Dir.mktmpdir do |directory|
      %w[selected_lock_audit source_audit license_review native_review].each do |key|
        filename = dependencies.dig("source_closure_files", key)
        FileUtils.cp(File.join(source_package.directory, filename), File.join(directory, filename))
      end
      native_path = File.join(directory, dependencies.dig("source_closure_files", "native_review"))
      native_review = Agentlab.load_yaml(native_path)
      native_review.fetch("components").pop
      File.write(native_path, YAML.dump(native_review))
      package = Agentlab::Package.new(directory: directory, manifest_path: "unused", data: { "name" => "opencode" })

      errors = Agentlab.validate_opencode_review_evidence(package, dependencies, "1.18.3")

      assert(errors.any? { |error| error.include?("source coverage does not match") })
    end
  end

  def test_rejects_incomplete_opencode_subordinate_source_coverage
    source_package = Agentlab.package_named("opencode")
    dependencies = Agentlab.load_yaml(File.join(source_package.directory, "dependencies.yml"))

    Dir.mktmpdir do |directory|
      %w[selected_lock_audit source_audit license_review native_review].each do |key|
        filename = dependencies.dig("source_closure_files", key)
        FileUtils.cp(File.join(source_package.directory, filename), File.join(directory, filename))
      end
      native_path = File.join(directory, dependencies.dig("source_closure_files", "native_review"))
      native_review = Agentlab.load_yaml(native_path)
      shiki = native_review.fetch("components").find { |component| component["package"] == "shiki@4.2.0" }
      shiki.dig("provenance", "subordinate_sources").pop
      File.write(native_path, YAML.dump(native_review))
      package = Agentlab::Package.new(directory: directory, manifest_path: "unused", data: { "name" => "opencode" })

      errors = Agentlab.validate_opencode_review_evidence(package, dependencies, "1.18.3")

      assert(errors.any? { |error| error.include?("subordinate source ids do not match for shiki@4.2.0") })
    end
  end
end
