# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require "tmpdir"
require "yaml"
require_relative "../scripts/lib/agentlab"
load File.expand_path("../scripts/audit-openchamber-lock-closure", __dir__)

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

  def test_openchamber_lock_selector_preserves_role_precedence_and_platform_filters
    integrity = "sha512-fixture"
    workspaces = {
      "packages/web" => {
        "name" => "@openchamber/web",
        "dependencies" => { "runtime-root" => "1", "bun-pty" => "1" },
        "devDependencies" => { "build-root" => "1", "test-root" => "1" }
      },
      "packages/ui" => {
        "name" => "@openchamber/ui",
        "dependencies" => { "ui-root" => "1" }
      }
    }
    packages = {
      "runtime-root" => ["runtime-root@1.0.0", "", { "dependencies" => { "shared" => "1" } }, integrity],
      "build-root" => [
        "build-root@1.0.0",
        "",
        { "dependencies" => { "shared" => "1", "platform-addon" => "1", "musl-addon" => "1" } },
        integrity
      ],
      "test-root" => [
        "test-root@1.0.0",
        "",
        {
          "dependencies" => { "shared" => "1" },
          "peerDependencies" => { "missing-optional" => "*" },
          "peerDependenciesMeta" => { "missing-optional" => { "optional" => true } }
        },
        integrity
      ],
      "ui-root" => ["ui-root@1.0.0", "", {}, integrity],
      "shared" => ["shared@1.0.0", "", {}, integrity],
      "platform-addon" => ["platform-addon@1.0.0", "", { "os" => "darwin" }, integrity],
      "musl-addon" => ["@img/sharp-linuxmusl-x64@0.35.2", "", { "os" => "linux", "cpu" => "x64" }, integrity],
      "bun-pty" => ["bun-pty@0.4.8", "", {}, integrity]
    }
    selector = OpenChamberLockAudit::Selector.new(
      workspaces: workspaces,
      packages: packages,
      target: { "os" => "linux", "cpu" => "x64", "libc" => "glibc" },
      forbidden_names: ["bun-pty"]
    )

    selector.select_root(workspace_path: "packages/web", dependency_group: "devDependencies", dependency_name: "test-root", role: "test")
    selector.select_root(workspace_path: "packages/web", dependency_group: "devDependencies", dependency_name: "build-root", role: "build")
    selector.select_root(workspace_path: "packages/ui", dependency_group: "dependencies", dependency_name: "ui-root", role: "build")
    selector.select_root(workspace_path: "packages/web", dependency_group: "dependencies", dependency_name: "runtime-root", role: "runtime")
    selector.run

    assert_equal("runtime", selector.package_roles.fetch("shared"))
    assert_equal("build", selector.package_roles.fetch("build-root"))
    assert_equal("test", selector.package_roles.fetch("test-root"))
    assert_equal("build", selector.workspace_roles.fetch("packages/ui"))
    assert_equal("runtime", selector.workspace_roles.fetch("packages/web"))
    assert_equal("os", selector.platform_excluded.dig("platform-addon", "reason"))
    assert_equal("musl", selector.platform_excluded.dig("musl-addon", "reason"))
    refute(selector.package_roles.key?("platform-addon"))
    refute(selector.package_roles.key?("musl-addon"))
  end

  def test_openchamber_source_identity_rejects_another_commit
    error = assert_raises(Agentlab::Error) do
      OpenChamberLockAudit.verify_source_identity(File.expand_path("..", __dir__), "0" * 40, "unused-tag")
    end

    assert_match(/source checkout commit .* does not match/, error.message)
  end

  def test_openchamber_source_identity_rejects_missing_tag
    repository = File.expand_path("..", __dir__)
    commit, status = Open3.capture2("git", "-C", repository, "rev-parse", "HEAD")
    assert(status.success?)

    error = assert_raises(Agentlab::Error) do
      OpenChamberLockAudit.verify_source_identity(repository, commit.strip, "agentlab-missing-test-tag")
    end

    assert_match(/source tag .* cannot be resolved/, error.message)
  end

  def test_openchamber_source_identity_does_not_accept_branch_as_tag
    Dir.mktmpdir do |directory|
      File.write(File.join(directory, "fixture"), "content\n")
      _stdout, stderr, status = Open3.capture3("git", "init", "--quiet", directory)
      assert(status.success?, stderr)
      _stdout, stderr, status = Open3.capture3("git", "-C", directory, "add", "fixture")
      assert(status.success?, stderr)
      _stdout, stderr, status = Open3.capture3(
        "git", "-C", directory,
        "-c", "user.name=Agentlab Test",
        "-c", "user.email=agentlab-test@example.invalid",
        "commit", "--quiet", "-m", "fixture"
      )
      assert(status.success?, stderr)
      commit, stderr, status = Open3.capture3("git", "-C", directory, "rev-parse", "HEAD")
      assert(status.success?, stderr)
      _stdout, stderr, status = Open3.capture3("git", "-C", directory, "branch", "v1.16.1")
      assert(status.success?, stderr)

      error = assert_raises(Agentlab::Error) do
        OpenChamberLockAudit.verify_source_identity(directory, commit.strip, "v1.16.1")
      end

      assert_match(/source tag .* cannot be resolved/, error.message)
    end
  end

  def test_openchamber_lock_selector_rejects_bun_pty_on_selected_node_path
    workspaces = {
      "packages/web" => {
        "name" => "@openchamber/web",
        "dependencies" => { "bun-pty" => "^0.4.5" }
      }
    }
    packages = {
      "bun-pty" => ["bun-pty@0.4.8", "", {}, "sha512-fixture"]
    }
    selector = OpenChamberLockAudit::Selector.new(
      workspaces: workspaces,
      packages: packages,
      target: { "os" => "linux", "cpu" => "x64", "libc" => "glibc" },
      forbidden_names: ["bun-pty"]
    )

    error = assert_raises(Agentlab::Error) do
      selector.select_root(
        workspace_path: "packages/web",
        dependency_group: "dependencies",
        dependency_name: "bun-pty",
        role: "runtime"
      )
    end

    assert_match(/forbidden package bun-pty selected through packages\/web -> bun-pty/, error.message)
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
    assert_includes(makefile, "scripts/prepare-bun-srpm-sources")
    assert_includes(makefile, "scripts/audit-bun-source-licenses")
    assert_includes(makefile, "dnf -y install ruby ruby-bundled-gems")
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
    defaults = Agentlab::DEFAULT_COPR_CHROOTS

    assert_equal(defaults, package.chroots(defaults))
  end

  def test_default_copr_chroot_matrix_covers_stable_and_rawhide_architectures
    assert_equal(
      %w[
        fedora-43-x86_64
        fedora-43-aarch64
        fedora-44-x86_64
        fedora-44-aarch64
        fedora-rawhide-x86_64
        fedora-rawhide-aarch64
      ],
      Agentlab::DEFAULT_COPR_CHROOTS
    )
    assert_empty(
      Agentlab.copr_chroot_matrix_errors(
        Agentlab::DEFAULT_COPR_CHROOTS,
        require_all_stable_releases: true
      )
    )
  end

  def test_copr_chroot_override_allows_one_stable_release_with_rawhide
    chroots = %w[
      fedora-44-x86_64
      fedora-44-aarch64
      fedora-rawhide-x86_64
      fedora-rawhide-aarch64
    ]

    assert_empty(Agentlab.copr_chroot_matrix_errors(chroots, require_all_stable_releases: false))
  end

  def test_copr_chroot_override_rejects_missing_architecture_and_rawhide
    errors = Agentlab.copr_chroot_matrix_errors(
      ["fedora-44-x86_64", "fedora-rawhide-x86_64"],
      require_all_stable_releases: false
    )

    assert(errors.any? { |error| error.include?("fedora-44-aarch64") })
    assert(errors.any? { |error| error.include?("fedora-rawhide-aarch64") })
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

  def test_validates_verified_bun_seed_build_stage
    Dir.mktmpdir do |directory|
      version = "1.3.14"
      source_commit = "a" * 40
      source_sha256 = "b" * 64
      seed_sha256 = "c" * 64
      seed_binary_sha256 = "d" * 64
      zig_commit = "e" * 40
      zig_sha256 = "f" * 64
      webkit_commit = "1" * 40
      webkit_sha256 = "2" * 64
      patch_files = {
        "zig.patch" => "zig patch\n",
        "webkit.patch" => "webkit patch\n",
        "lolhtml.patch" => "lolhtml patch\n",
        "npm-lock.patch" => "npm lock patch\n",
        "zig-cwd.patch" => "zig cwd patch\n",
        "shared-runtime.patch" => "shared runtime patch\n"
      }
      patch_files.each { |name, content| File.write(File.join(directory, name), content) }
      patch_sha256 = patch_files.to_h { |name, _content| [name, Digest::SHA256.file(File.join(directory, name)).hexdigest] }
      closure_path = File.join(directory, "source-closure.json")
      npm_proof_path = File.join(directory, "npm-proof.json")
      cargo_proof_path = File.join(directory, "cargo-proof.json")
      File.write(closure_path, JSON.dump(
        "schema" => "bun-release-local-source-closure/v2",
        "package" => "bun",
        "release" => version,
        "existing_local_sources" => [
          { "symbol" => "webkit", "immutable_public_url" => nil }
        ],
        "validation" => { "immutable_public_hosting_verified" => false }
      ))
      File.write(npm_proof_path, "{}\n")
      File.write(cargo_proof_path, "{}\n")
      closure_sha256 = Digest::SHA256.file(closure_path).hexdigest
      npm_proof_sha256 = Digest::SHA256.file(npm_proof_path).hexdigest
      cargo_proof_sha256 = Digest::SHA256.file(cargo_proof_path).hexdigest
      seed_rules = %w[codegen dep_build dep_cargo dep_cargo_cross dep_codegen dep_configure dep_fetch dep_fetch_prebuilt dep_prebuild dep_subst link regen smoke_test zig_build zig_check zig_fetch]
      receipt_path = File.join(directory, "first-source-build-proof.json")
      File.write(receipt_path, JSON.dump(
        "schema" => "bun-first-source-build-proof/v1",
        "package" => "bun",
        "release" => version,
        "profile" => "release-local",
        "proof_date" => "2026-07-18",
        "source_closure" => {
          "path" => File.basename(closure_path),
          "sha256" => closure_sha256,
          "source_commit" => source_commit,
          "source_archive_sha256" => source_sha256
        },
        "bootstrap_seed" => {
          "archive_sha256" => seed_sha256,
          "binary_sha256" => seed_binary_sha256,
          "size_bytes" => 123,
          "version" => version,
          "bootstrap_only" => true,
          "final_payload_allowed" => false,
          "final_runtime_dependency_allowed" => false
        },
        "inputs" => {
          "zig" => {
            "source_commit" => zig_commit,
            "source_sha256" => zig_sha256,
            "patch_sha256" => patch_sha256.fetch("zig.patch")
          },
          "webkit" => {
            "commit" => webkit_commit,
            "archive_sha256" => webkit_sha256,
            "patch_sha256" => patch_sha256.fetch("webkit.patch")
          },
          "source_patches" => {
            "lolhtml_sha256" => patch_sha256.fetch("lolhtml.patch"),
            "npm_lock_sha256" => patch_sha256.fetch("npm-lock.patch"),
            "zig_build_cwd_sha256" => patch_sha256.fetch("zig-cwd.patch"),
            "fedora_shared_cxx_runtime_sha256" => patch_sha256.fetch("shared-runtime.patch")
          },
          "offline_inputs" => {
            "native_archives" => 19,
            "node_header_archives" => 1,
            "npm_install_roots" => 3,
            "supplemental_npm_trees" => [
              {
                "path" => "packages/@types/bun/node_modules",
                "tree" => { "sha256" => "3" * 64 }
              }
            ]
          },
          "npm_proof" => {
            "path" => File.basename(npm_proof_path),
            "sha256" => npm_proof_sha256
          },
          "cargo_proof" => {
            "path" => File.basename(cargo_proof_path),
            "sha256" => cargo_proof_sha256
          }
        },
        "configure" => {
          "network_namespace" => true,
          "install_edges" => 3,
          "native_fetch_edges" => 19,
          "node_header_fetch_edges" => 1,
          "prepared_inputs_revalidated" => true,
          "bootstrap_seed_rule_scope_verified" => true,
          "bootstrap_seed_rules" => seed_rules,
          "local_webkit_verified" => true,
          "zig_fetch_absent" => true,
          "zig_source_cwd_verified" => true,
          "stable_lolhtml_cargo_verified" => true,
          "unexpected_urls_absent" => true
        },
        "build" => {
          "network_namespace" => true,
          "bun_profile" => { "path" => "build/bun-profile", "size_bytes" => 200, "sha256" => "4" * 64 },
          "bun" => { "path" => "build/bun", "size_bytes" => 100, "sha256" => "5" * 64 },
          "linker_map" => { "path" => "build/bun.map", "size_bytes" => 50, "sha256" => "6" * 64 },
          "revision" => "#{version}-canary.1+#{source_commit[0, 9]}",
          "version" => version,
          "smoke_verified" => true,
          "stripped_output_verified" => true,
          "fedora_shared_cxx_runtime_verified" => true,
          "shared_runtime_libraries" => %w[libgcc_s.so.1 libstdc++.so.6]
        },
        "retained_relink_evidence" => {
          "complete_lgpl_relink_materials_verified" => false
        },
        "seed_contamination" => {
          "seed_hash_matches" => 0,
          "payload_absent_verified" => true,
          "runtime_dependency_absent_verified" => true
        },
        "validation" => {
          "bootstrap_seed_verified" => true,
          "seed_isolated_verified" => true,
          "source_build_verified" => true,
          "self_rebuild_performed" => false,
          "reproducibility_compared" => false,
          "complete_lgpl_relink_materials_verified" => false,
          "final_license_audit_verified" => false,
          "final_rpm_verified" => false
        }
      ))
      stages = Agentlab::BUN_BUILD_STAGES.to_h { |stage| [stage, { "state" => "blocked" }] }
      stages.fetch("dependency_closure").merge!(
        "proof_receipt" => File.basename(closure_path),
        "proof_receipt_sha256" => closure_sha256,
        "cargo_vendor_archive_hosted" => false,
        "npm_install_proof_receipt" => File.basename(npm_proof_path),
        "npm_install_proof_receipt_sha256" => npm_proof_sha256,
        "cargo_build_proof_receipt" => File.basename(cargo_proof_path),
        "cargo_build_proof_receipt_sha256" => cargo_proof_sha256,
        "selected_github_archives" => 19,
        "selected_node_header_archives" => 1
      )
      stages.fetch("seed_build").merge!(
        "state" => "verified",
        "bootstrap_seed_verified" => true,
        "seed_isolated_verified" => true,
        "source_build_verified" => true,
        "proof_date" => "2026-07-18",
        "proof_receipt" => File.basename(receipt_path),
        "proof_receipt_sha256" => Digest::SHA256.file(receipt_path).hexdigest
      )
      data = {
        "name" => "bun",
        "status" => "blocked",
        "blockers" => ["The checked dependency archives still need immutable public hosting."],
        "upstream" => {
          "current_version" => version,
          "source_commit" => source_commit,
          "source_sha256" => source_sha256
        },
        "copr" => { "enabled" => false },
        "build_plan" => {
          "target_release" => "1.3.14",
          "source_inputs_reconciled" => true,
          "architectures" => ["x86_64"],
          "source_inputs" => {
            "zig" => {
              "release_pin" => "bun-v#{version}",
              "commit" => zig_commit,
              "url" => "https://example.com/zig.tar.gz",
              "sha256" => zig_sha256,
              "patch" => "zig.patch"
            },
            "webkit" => {
              "release_pin" => "bun-v#{version}",
              "commit" => webkit_commit,
              "repository_url" => "https://example.com/WebKit.git",
              "acquisition" => "deterministic_git_archive",
              "submodules" => false,
              "source_tree_complete" => true,
              "archive_url" => nil,
              "sha256" => webkit_sha256,
              "patch" => "webkit.patch",
              "patch_sha256" => patch_sha256.fetch("webkit.patch")
            },
            "lolhtml" => {
              "patch" => "lolhtml.patch",
              "patch_sha256" => patch_sha256.fetch("lolhtml.patch")
            },
            "npm_lock" => {
              "patch" => "npm-lock.patch",
              "patch_sha256" => patch_sha256.fetch("npm-lock.patch")
            },
            "build_graph" => {
              "patch" => "zig-cwd.patch",
              "patch_sha256" => patch_sha256.fetch("zig-cwd.patch"),
              "cxx_runtime_patch" => "shared-runtime.patch",
              "cxx_runtime_patch_sha256" => patch_sha256.fetch("shared-runtime.patch")
            },
            "bootstrap_seed" => {
              "release_pin" => "bun-v#{version}",
              "architecture" => "x86_64",
              "url" => "https://example.com/bun.zip",
              "sha256" => seed_sha256,
              "binary_sha256" => seed_binary_sha256,
              "binary_size_bytes" => 123,
              "bootstrap_only" => true,
              "final_payload_allowed" => false,
              "final_runtime_dependency_allowed" => false
            }
          },
          "stages" => stages
        }
      }
      package = Agentlab::Package.new(directory: directory, manifest_path: "unused", data: data)

      assert_empty(Agentlab.validate_bun_build_plan(package, "exit 1\n"))

      invalid_receipt = JSON.parse(File.read(receipt_path))
      invalid_receipt.fetch("configure")["prepared_inputs_revalidated"] = false
      File.write(receipt_path, JSON.dump(invalid_receipt))
      stages.fetch("seed_build")["proof_receipt_sha256"] = Digest::SHA256.file(receipt_path).hexdigest
      errors = Agentlab.validate_bun_build_plan(package, "exit 1\n")
      assert_includes(errors, "bun: seed-build proof did not revalidate prepared inputs")
    end
  end

  def test_validates_bun_dependency_closure_local_source_state
    Dir.mktmpdir do |directory|
      receipt_path = File.join(directory, "source-closure.json")
      receipt = {
        "schema" => "bun-release-local-source-closure/v2",
        "package" => "bun",
        "release" => "1.3.14",
        "existing_local_sources" => [
          { "symbol" => "webkit", "immutable_public_url" => nil }
        ],
        "validation" => { "immutable_public_hosting_verified" => false }
      }
      dependency_stage = {
        "proof_receipt" => File.basename(receipt_path),
        "cargo_vendor_archive_hosted" => false
      }
      write_receipt = lambda do
        File.write(receipt_path, JSON.dump(receipt))
        dependency_stage["proof_receipt_sha256"] = Digest::SHA256.file(receipt_path).hexdigest
      end
      write_receipt.call
      package = Agentlab::Package.new(
        directory: directory,
        manifest_path: "unused",
        data: {
          "name" => "bun",
          "status" => "blocked",
          "blockers" => ["The dependency sources are not integrated into the SRPM."],
          "upstream" => { "current_version" => "1.3.14" },
          "copr" => { "enabled" => false }
        }
      )
      webkit = { "archive_url" => nil }

      assert_empty(Agentlab.validate_bun_dependency_closure(package, dependency_stage, webkit, "1.3.14"))

      dependency_stage["proof_receipt_sha256"] = "0" * 64
      assert_equal(
        ["bun: dependency-closure proof receipt is missing or has wrong SHA-256"],
        Agentlab.validate_bun_dependency_closure(package, dependency_stage, webkit, "1.3.14")
      )

      receipt["schema"] = "bun-release-local-source-closure/v1"
      write_receipt.call
      errors = Agentlab.validate_bun_dependency_closure(package, dependency_stage, webkit, "1.3.14")
      assert_includes(errors, "bun: unsupported dependency-closure proof receipt schema")

      receipt["schema"] = "bun-release-local-source-closure/v2"
      { "package" => "other", "release" => "1.3.15" }.each do |field, value|
        original = receipt.fetch(field)
        receipt[field] = value
        write_receipt.call
        errors = Agentlab.validate_bun_dependency_closure(package, dependency_stage, webkit, "1.3.14")
        assert_includes(errors, "bun: dependency-closure proof #{field} mismatch")
        receipt[field] = original
      end

      receipt.fetch("validation")["immutable_public_hosting_verified"] = true
      write_receipt.call
      errors = Agentlab.validate_bun_dependency_closure(package, dependency_stage, webkit, "1.3.14")
      assert_includes(errors, "bun: dependency-closure proof incorrectly claims immutable public hosting")

      receipt.fetch("validation")["immutable_public_hosting_verified"] = false
      write_receipt.call
      dependency_stage["cargo_vendor_archive_hosted"] = true
      errors = Agentlab.validate_bun_dependency_closure(package, dependency_stage, webkit, "1.3.14")
      assert_includes(errors, "bun: dependency-closure Cargo vendor archive hosting state is invalid")

      receipt.fetch("validation")["immutable_public_hosting_verified"] = false
      receipt.fetch("existing_local_sources").first["immutable_public_url"] = "https://sources.example.invalid/WebKit.tar.gz"
      write_receipt.call
      errors = Agentlab.validate_bun_dependency_closure(package, dependency_stage, webkit, "1.3.14")
      assert_includes(errors, "bun: dependency-closure proof hosted local-source record")
    end
  end

  def test_validates_bun_source_delivery_receipt
    package = Agentlab.package_named("bun")
    stages = package.data.fetch("build_plan").fetch("stages")
    spec = File.read(File.join(package.directory, "bun.spec"))

    assert_empty(
      Agentlab.validate_bun_source_delivery(
        package,
        stages.fetch("source_delivery"),
        stages.fetch("dependency_closure"),
        "1.3.14",
        spec
      )
    )

    invalid_stage = stages.fetch("source_delivery").merge("proof_receipt_sha256" => "0" * 64)
    assert_includes(
      Agentlab.validate_bun_source_delivery(package, invalid_stage, stages.fetch("dependency_closure"), "1.3.14", spec),
      "bun: source-delivery proof receipt is missing or has wrong SHA-256"
    )
  end

  def test_validates_bun_lolhtml_rpm_cargo_receipt
    package = Agentlab.package_named("bun")
    plan = package.data.fetch("build_plan")
    stages = plan.fetch("stages")
    spec = File.read(File.join(package.directory, "bun.spec"))

    assert_empty(
      Agentlab.validate_bun_lolhtml_rpm_cargo(
        package,
        stages.fetch("lolhtml_rpm_cargo"),
        stages.fetch("dependency_closure"),
        plan.fetch("source_inputs").fetch("lolhtml"),
        "1.3.14",
        spec
      )
    )

    invalid_stage = stages.fetch("lolhtml_rpm_cargo").merge("proof_receipt_sha256" => "0" * 64)
    assert_includes(
      Agentlab.validate_bun_lolhtml_rpm_cargo(
        package,
        invalid_stage,
        stages.fetch("dependency_closure"),
        plan.fetch("source_inputs").fetch("lolhtml"),
        "1.3.14",
        spec
      ),
      "bun: lol-html RPM Cargo proof receipt is missing or has wrong SHA-256"
    )
    assert_includes(
      Agentlab.validate_bun_lolhtml_rpm_cargo(
        package,
        stages.fetch("lolhtml_rpm_cargo"),
        stages.fetch("dependency_closure"),
        plan.fetch("source_inputs").fetch("lolhtml"),
        "1.3.14",
        spec.sub("%cargo_vendor_manifest", "# removed")
      ),
      "bun: spec does not integrate the verified lol-html RPM Cargo stage"
    )
  end

  def test_validates_bun_dependency_staging_receipt
    package = Agentlab.package_named("bun")
    plan = package.data.fetch("build_plan")
    stages = plan.fetch("stages")
    spec = File.read(File.join(package.directory, "bun.spec"))

    assert_empty(
      Agentlab.validate_bun_dependency_staging(
        package,
        stages.fetch("dependency_staging"),
        stages.fetch("source_delivery"),
        stages.fetch("dependency_closure"),
        plan.fetch("source_inputs").fetch("release_local_staging"),
        "1.3.14",
        spec
      )
    )

    invalid_stage = stages.fetch("dependency_staging").merge("proof_receipt_sha256" => "0" * 64)
    assert_includes(
      Agentlab.validate_bun_dependency_staging(
        package,
        invalid_stage,
        stages.fetch("source_delivery"),
        stages.fetch("dependency_closure"),
        plan.fetch("source_inputs").fetch("release_local_staging"),
        "1.3.14",
        spec
      ),
      "bun: dependency-staging proof receipt is missing or has wrong SHA-256"
    )
    assert_includes(
      Agentlab.validate_bun_dependency_staging(
        package,
        stages.fetch("dependency_staging"),
        stages.fetch("source_delivery"),
        stages.fetch("dependency_closure"),
        plan.fetch("source_inputs").fetch("release_local_staging"),
        "1.3.14",
        spec.sub("ruby %{SOURCE26}", "# removed")
      ),
      "bun: spec does not integrate the verified dependency-staging step"
    )
  end

  def test_validates_bun_source_license_inventory
    package = Agentlab.package_named("bun")
    plan = package.data.fetch("build_plan")
    inventory = plan.fetch("source_inputs").fetch("source_license_inventory")
    spec = File.read(File.join(package.directory, "bun.spec"))

    assert_empty(
      Agentlab.validate_bun_source_license_inventory(
        package,
        inventory,
        plan.fetch("stages").fetch("dependency_closure"),
        "1.3.14",
        spec
      )
    )

    invalid = inventory.merge("sha256" => "0" * 64)
    assert_includes(
      Agentlab.validate_bun_source_license_inventory(
        package,
        invalid,
        plan.fetch("stages").fetch("dependency_closure"),
        "1.3.14",
        spec
      ),
      "bun: source-license inventory is missing or has wrong SHA-256"
    )
    assert_includes(
      Agentlab.validate_bun_source_license_inventory(
        package,
        inventory,
        plan.fetch("stages").fetch("dependency_closure"),
        "1.3.14",
        spec.sub("Source27:", "Removed27:")
      ),
      "bun: spec does not integrate the source-license inventory"
    )

    Dir.mktmpdir do |directory|
      data = Marshal.load(Marshal.dump(package.data))
      copied_inventory = data.fetch("build_plan").fetch("source_inputs").fetch("source_license_inventory")
      receipt_path = File.join(directory, copied_inventory.fetch("source"))
      FileUtils.cp(File.join(package.directory, copied_inventory.fetch("source")), receipt_path)
      mutated = JSON.parse(File.read(receipt_path))
      mutated.fetch("validation")["final_license_expression_verified"] = true
      mutated.fetch("webkit").fetch("candidate_license_files").first["path"] = "../escape"
      File.write(receipt_path, JSON.pretty_generate(mutated) + "\n")
      copied_inventory["sha256"] = Digest::SHA256.file(receipt_path).hexdigest
      copied_package = Agentlab::Package.new(directory: directory, manifest_path: "unused", data: data)

      errors = Agentlab.validate_bun_source_license_inventory(
        copied_package,
        copied_inventory,
        data.fetch("build_plan").fetch("stages").fetch("dependency_closure"),
        "1.3.14",
        spec
      )
      assert_includes(errors, "bun: source-license inventory overclaims completion")
      assert_includes(errors, "bun: source-license WebKit file records mismatch")
    end
  end

  def test_validates_bun_minimized_webkit_source
    source_package = Agentlab.package_named("bun")
    Dir.mktmpdir do |directory|
      data = Marshal.load(Marshal.dump(source_package.data))
      webkit = data.dig("build_plan", "source_inputs", "webkit")
      minimized = webkit.fetch("jsc_only")
      %w[webkit-minimized-source-proof.json webkit-minimized-source-build-proof.json].each do |name|
        FileUtils.cp(File.join(source_package.directory, name), File.join(directory, name))
      end
      package = Agentlab::Package.new(directory: directory, manifest_path: "unused", data: data)
      spec = File.read(File.join(source_package.directory, "bun.spec"))

      assert_empty(Agentlab.validate_bun_minimized_webkit_source(package, webkit, "1.3.14", spec))

      original_tree_sha256 = minimized.fetch("tree_sha256")
      minimized["tree_sha256"] = "0" * 64
      errors = Agentlab.validate_bun_minimized_webkit_source(package, webkit, "1.3.14", spec)
      assert_includes(errors, "bun: minimized WebKit source receipt tree_sha256 mismatch")
      minimized["tree_sha256"] = original_tree_sha256

      hosted_mutations = {
        "archive_url" => ["https://sources.example.invalid/WebKit.tar.gz", "bun: minimized WebKit hosted archive URL mismatch"],
        "release_tag" => ["wrong-tag", "bun: minimized WebKit release tag mismatch"],
        "release_url" => ["https://sources.example.invalid/release", "bun: minimized WebKit release URL mismatch"],
        "release_id" => [0, "bun: minimized WebKit release ID is invalid"],
        "release_target_commit" => ["bad", "bun: minimized WebKit release target commit is invalid"],
        "release_immutable" => [false, "bun: minimized WebKit release is not immutable"],
        "artifact_attestation_url" => ["https://sources.example.invalid/attestation", "bun: minimized WebKit artifact attestation URL is invalid"],
        "publication_run" => ["https://sources.example.invalid/run", "bun: minimized WebKit publication run URL is invalid"]
      }
      hosted_mutations.each do |key, (replacement, message)|
        original = minimized.fetch(key)
        minimized[key] = replacement
        errors = Agentlab.validate_bun_minimized_webkit_source(package, webkit, "1.3.14", spec)
        assert_includes(errors, message)
        minimized[key] = original
      end

      original_url = minimized.fetch("archive_url")
      minimized["archive_hosted"] = false
      errors = Agentlab.validate_bun_minimized_webkit_source(package, webkit, "1.3.14", spec)
      assert_includes(errors, "bun: minimized WebKit unhosted archive has a URL")
      minimized["archive_hosted"] = true

      minimized["archive_url"] = "not-a-url"
      errors = Agentlab.validate_bun_minimized_webkit_source(package, webkit, "1.3.14", spec)
      assert_includes(errors, "bun: minimized WebKit hosted archive URL is invalid")
      minimized["archive_url"] = original_url

      original_release_id = minimized.delete("release_id")
      errors = Agentlab.validate_bun_minimized_webkit_source(package, webkit, "1.3.14", spec)
      assert_includes(errors, "bun: minimized WebKit release ID is invalid")
      minimized["release_id"] = original_release_id

      build_path = File.join(directory, minimized.fetch("source_build_proof_receipt"))
      build = JSON.parse(File.read(build_path))
      build.fetch("output").fetch("metadata").delete("compile_commands.json")
      File.write(build_path, JSON.dump(build))
      minimized["source_build_proof_receipt_sha256"] = Digest::SHA256.file(build_path).hexdigest
      errors = Agentlab.validate_bun_minimized_webkit_source(package, webkit, "1.3.14", spec)
      assert_includes(errors, "bun: minimized WebKit retained build metadata is invalid")

      FileUtils.cp(File.join(source_package.directory, minimized.fetch("source_build_proof_receipt")), build_path)
      minimized["source_build_proof_receipt_sha256"] = Digest::SHA256.file(build_path).hexdigest
      build = JSON.parse(File.read(build_path))
      build.fetch("output").fetch("jsc")["runtime_probe_verified"] = false
      File.write(build_path, JSON.dump(build))
      minimized["source_build_proof_receipt_sha256"] = Digest::SHA256.file(build_path).hexdigest
      errors = Agentlab.validate_bun_minimized_webkit_source(package, webkit, "1.3.14", spec)
      assert_includes(errors, "bun: minimized WebKit jsc proof is invalid")

      errors = Agentlab.validate_bun_minimized_webkit_source(package, webkit, "1.3.14", spec.sub("ExclusiveArch:  x86_64", "ExclusiveArch:  aarch64"))
      assert_includes(errors, "bun: spec architecture does not match the build plan")
    end
  end

  def test_validates_bun_source_release_request
    package = Agentlab.package_named("bun")
    webkit = package.data.dig("build_plan", "source_inputs", "webkit")
    source = webkit.fetch("jsc_only")
    request = YAML.safe_load_file(File.join(Agentlab::ROOT, ".github", "source-release", "bun.yml"))

    assert_empty(Agentlab.validate_bun_source_release_request(source, webkit, "1.3.14", request))
    {
      "archive_sha256" => "0" * 64,
      "tag" => "wrong-tag",
      "generator_commit" => "1" * 40,
      "operation" => "stage",
      "attempt" => 0
    }.each do |key, replacement|
      mutated = request.merge(key => replacement)
      assert_includes(
        Agentlab.validate_bun_source_release_request(source, webkit, "1.3.14", mutated),
        "source-release request mismatch"
      )
    end
    assert_includes(
      Agentlab.validate_bun_source_release_request(source, webkit, "1.3.14", nil),
      "source-release request mismatch"
    )
  end

  def test_validates_bun_self_rebuild_receipts
    source_package = Agentlab.package_named("bun")
    Dir.mktmpdir do |directory|
      data = Marshal.load(Marshal.dump(source_package.data))
      data.fetch("build_plan").fetch("stages").each_value { |stage| stage["state"] = "blocked" }
      self_stage = data.dig("build_plan", "stages", "self_rebuild")
      %w[bun-1.3.14-release-local-source-closure.json bun-1.3.14-source-license-inventory.json first-source-build-proof.json relink-materials-proof.json relink-kit-proof.json self-rebuild-proof.json webkit-minimized-source-proof.json webkit-minimized-source-build-proof.json zig-reproducibility-proof.json zig-single-thread-control-proof.json].each do |name|
        FileUtils.cp(File.join(source_package.directory, name), File.join(directory, name))
      end
      package = Agentlab::Package.new(directory: directory, manifest_path: "unused", data: data)
      spec = File.read(File.join(source_package.directory, "bun.spec"))

      assert_empty(Agentlab.validate_bun_build_plan(package, spec))

      control_metadata = data.dig("build_plan", "stages", "self_rebuild", "zig_single_thread_control")
      control_path = File.join(directory, control_metadata.fetch("proof_receipt"))
      control_receipt = JSON.parse(File.read(control_path))
      control_receipt.fetch("validation")["production_fix_verified"] = true
      File.write(control_path, JSON.dump(control_receipt))
      control_metadata["proof_receipt_sha256"] = Digest::SHA256.file(control_path).hexdigest
      errors = Agentlab.validate_bun_build_plan(package, spec)
      assert_includes(errors, "bun: Zig single-thread control overclaims a production fix")
      control_receipt.fetch("validation")["production_fix_verified"] = false
      File.write(control_path, JSON.dump(control_receipt))
      control_metadata["proof_receipt_sha256"] = Digest::SHA256.file(control_path).hexdigest

      self_receipt_path = File.join(directory, "self-rebuild-proof.json")
      self_receipt = JSON.parse(File.read(self_receipt_path))
      zig_receipt_path = File.join(directory, "zig-reproducibility-proof.json")
      zig_receipt = JSON.parse(File.read(zig_receipt_path))
      driver_sha256 = self_receipt.dig("first_build", "sha256")
      self_receipt.fetch("first_build")["sha256"] = "0" * 64
      File.write(self_receipt_path, JSON.dump(self_receipt))
      self_stage["proof_receipt_sha256"] = Digest::SHA256.file(self_receipt_path).hexdigest
      zig_receipt.fetch("self_rebuild_proof")["sha256"] = self_stage["proof_receipt_sha256"]
      File.write(zig_receipt_path, JSON.dump(zig_receipt))
      self_stage["zig_reproducibility_proof_receipt_sha256"] = Digest::SHA256.file(zig_receipt_path).hexdigest

      errors = Agentlab.validate_bun_build_plan(package, spec)
      assert_includes(errors, "bun: self-rebuild proof driver binary mismatch")

      self_receipt.fetch("first_build")["sha256"] = driver_sha256
      self_receipt.fetch("validation")["offline_verified"] = false
      File.write(self_receipt_path, JSON.dump(self_receipt))
      self_stage["proof_receipt_sha256"] = Digest::SHA256.file(self_receipt_path).hexdigest
      zig_receipt.fetch("self_rebuild_proof")["sha256"] = self_stage["proof_receipt_sha256"]
      File.write(zig_receipt_path, JSON.dump(zig_receipt))
      self_stage["zig_reproducibility_proof_receipt_sha256"] = Digest::SHA256.file(zig_receipt_path).hexdigest

      errors = Agentlab.validate_bun_build_plan(package, spec)
      assert_includes(errors, "bun: self-rebuild proof validation is incomplete")

      self_receipt.fetch("validation")["offline_verified"] = true
      File.write(self_receipt_path, JSON.dump(self_receipt))
      self_stage["proof_receipt_sha256"] = Digest::SHA256.file(self_receipt_path).hexdigest
      zig_receipt.fetch("self_rebuild_proof")["sha256"] = self_stage["proof_receipt_sha256"]
      zig_receipt.dig("experiment", "clean_cache")["reproducible"] = true
      File.write(zig_receipt_path, JSON.dump(zig_receipt))
      self_stage["zig_reproducibility_proof_receipt_sha256"] = Digest::SHA256.file(zig_receipt_path).hexdigest

      errors = Agentlab.validate_bun_build_plan(package, spec)
      assert_includes(errors, "bun: Zig reproducibility proof clean-cache result mismatch")
    end
  end

  def test_validates_bun_relink_materials_receipt
    source_package = Agentlab.package_named("bun")
    Dir.mktmpdir do |directory|
      data = Marshal.load(Marshal.dump(source_package.data))
      data.fetch("build_plan").fetch("stages").each_value { |stage| stage["state"] = "blocked" }
      self_stage = data.dig("build_plan", "stages", "self_rebuild")
      self_stage.delete("proof_receipt")
      self_stage.delete("zig_reproducibility_proof_receipt")
      self_stage.delete("zig_single_thread_control")
      receipt_name = data.dig("build_plan", "stages", "seed_build", "relink_materials_audit", "proof_receipt")
      FileUtils.cp(File.join(source_package.directory, receipt_name), File.join(directory, receipt_name))
      kit_receipt_name = data.dig("build_plan", "stages", "seed_build", "relink_kit", "proof_receipt")
      FileUtils.cp(File.join(source_package.directory, kit_receipt_name), File.join(directory, kit_receipt_name))
      closure_name = data.dig("build_plan", "stages", "dependency_closure", "proof_receipt")
      FileUtils.cp(File.join(source_package.directory, closure_name), File.join(directory, closure_name))
      inventory_name = data.dig("build_plan", "source_inputs", "source_license_inventory", "source")
      FileUtils.cp(File.join(source_package.directory, inventory_name), File.join(directory, inventory_name))
      webkit = data.dig("build_plan", "source_inputs", "webkit", "jsc_only")
      %w[proof_receipt source_build_proof_receipt].each do |key|
        name = webkit.fetch(key)
        FileUtils.cp(File.join(source_package.directory, name), File.join(directory, name))
      end
      package = Agentlab::Package.new(directory: directory, manifest_path: "unused", data: data)

      assert(File.executable?(File.expand_path("../scripts/audit-bun-relink-materials", __dir__)))
      assert_empty(Agentlab.validate_bun_build_plan(package, File.read(File.join(source_package.directory, "bun.spec"))))

      receipt_path = File.join(directory, receipt_name)
      receipt = JSON.parse(File.read(receipt_path))
      receipt.fetch("final_link")["response_file_count"] = 1
      File.write(receipt_path, JSON.dump(receipt))
      audit = data.dig("build_plan", "stages", "seed_build", "relink_materials_audit")
      audit["proof_receipt_sha256"] = Digest::SHA256.file(receipt_path).hexdigest

      errors = Agentlab.validate_bun_build_plan(package, File.read(File.join(source_package.directory, "bun.spec")))
      assert_includes(errors, "bun: relink-materials proof response-file retention mismatch")

      receipt.fetch("final_link")["response_file_count"] = 0
      File.write(receipt_path, JSON.dump(receipt))
      audit["proof_receipt_sha256"] = Digest::SHA256.file(receipt_path).hexdigest
      kit_receipt_path = File.join(directory, kit_receipt_name)
      kit_receipt = JSON.parse(File.read(kit_receipt_path))
      kit_receipt.fetch("validation")["retained_linker_map_sha256_equal"] = false
      File.write(kit_receipt_path, JSON.dump(kit_receipt))
      kit_metadata = data.dig("build_plan", "stages", "seed_build", "relink_kit")
      kit_metadata["proof_receipt_sha256"] = Digest::SHA256.file(kit_receipt_path).hexdigest

      errors = Agentlab.validate_bun_build_plan(package, File.read(File.join(source_package.directory, "bun.spec")))
      assert_includes(errors, "bun: relink-kit proof validation is incomplete")
    end
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

  def test_rejects_incomplete_opencode_lifecycle_review
    package = Agentlab.package_named("opencode")
    dependencies = Marshal.load(Marshal.dump(Agentlab.load_yaml(File.join(package.directory, "dependencies.yml"))))
    dependencies.fetch("source_acquisition_findings").delete("lifecycle_script_review")

    errors = Agentlab.validate_opencode_review_evidence(package, dependencies, "1.18.3")

    assert(errors.any? { |error| error.include?("lifecycle-script review does not match") })
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

  def test_rejects_incomplete_opencode_photon_mismatch_evidence
    source_package = Agentlab.package_named("opencode")
    dependencies = Agentlab.load_yaml(File.join(source_package.directory, "dependencies.yml"))

    Dir.mktmpdir do |directory|
      %w[selected_lock_audit source_audit license_review native_review].each do |key|
        filename = dependencies.dig("source_closure_files", key)
        FileUtils.cp(File.join(source_package.directory, filename), File.join(directory, filename))
      end
      native_path = File.join(directory, dependencies.dig("source_closure_files", "native_review"))
      native_review = Agentlab.load_yaml(native_path)
      photon = native_review.fetch("components").find do |component|
        component["package"] == "@silvia-odwyer/photon-node@0.3.4"
      end
      photon.fetch("provenance").delete("closest_generated_candidate")
      File.write(native_path, YAML.dump(native_review))
      package = Agentlab::Package.new(directory: directory, manifest_path: "unused", data: { "name" => "opencode" })

      errors = Agentlab.validate_opencode_review_evidence(package, dependencies, "1.18.3")

      assert(errors.any? { |error| error.include?("Photon generated candidate file evidence does not match") })
    end
  end

  def test_rejects_incomplete_opencode_fff_fallback_evidence
    source_package = Agentlab.package_named("opencode")
    dependencies = Agentlab.load_yaml(File.join(source_package.directory, "dependencies.yml"))

    Dir.mktmpdir do |directory|
      %w[selected_lock_audit source_audit license_review native_review].each do |key|
        filename = dependencies.dig("source_closure_files", key)
        FileUtils.cp(File.join(source_package.directory, filename), File.join(directory, filename))
      end
      native_path = File.join(directory, dependencies.dig("source_closure_files", "native_review"))
      native_review = Agentlab.load_yaml(native_path)
      fff = native_review.fetch("components").find do |component|
        component["package"] == "@ff-labs/fff-bin-linux-x64-gnu@0.9.4"
      end
      fff.fetch("provenance").delete("supported_disable")
      File.write(native_path, YAML.dump(native_review))
      package = Agentlab::Package.new(directory: directory, manifest_path: "unused", data: { "name" => "opencode" })

      errors = Agentlab.validate_opencode_review_evidence(package, dependencies, "1.18.3")

      assert(errors.any? { |error| error.include?("FFF supported-disable evidence does not match") })
    end
  end

  def test_rejects_incomplete_opencode_parcel_build_evidence
    source_package = Agentlab.package_named("opencode")
    dependencies = Agentlab.load_yaml(File.join(source_package.directory, "dependencies.yml"))

    Dir.mktmpdir do |directory|
      %w[selected_lock_audit source_audit license_review native_review].each do |key|
        filename = dependencies.dig("source_closure_files", key)
        FileUtils.cp(File.join(source_package.directory, filename), File.join(directory, filename))
      end
      native_path = File.join(directory, dependencies.dig("source_closure_files", "native_review"))
      native_review = Agentlab.load_yaml(native_path)
      parcel = native_review.fetch("components").find do |component|
        component["package"] == "@parcel/watcher-linux-x64-glibc@2.5.1"
      end
      parcel.fetch("provenance").delete("source_build")
      File.write(native_path, YAML.dump(native_review))
      package = Agentlab::Package.new(directory: directory, manifest_path: "unused", data: { "name" => "opencode" })

      errors = Agentlab.validate_opencode_review_evidence(package, dependencies, "1.18.3")

      assert(errors.any? { |error| error.include?("Parcel watcher source-build evidence does not match") })
    end
  end

  def test_rejects_incomplete_opencode_opentui_build_evidence
    source_package = Agentlab.package_named("opencode")
    dependencies = Agentlab.load_yaml(File.join(source_package.directory, "dependencies.yml"))

    Dir.mktmpdir do |directory|
      %w[selected_lock_audit source_audit license_review native_review].each do |key|
        filename = dependencies.dig("source_closure_files", key)
        FileUtils.cp(File.join(source_package.directory, filename), File.join(directory, filename))
      end
      native_path = File.join(directory, dependencies.dig("source_closure_files", "native_review"))
      native_review = Agentlab.load_yaml(native_path)
      opentui = native_review.fetch("components").find do |component|
        component["package"] == "@opentui/core-linux-x64@0.4.3"
      end
      opentui.fetch("provenance").delete("source_build")
      File.write(native_path, YAML.dump(native_review))
      package = Agentlab::Package.new(directory: directory, manifest_path: "unused", data: { "name" => "opencode" })

      errors = Agentlab.validate_opencode_review_evidence(package, dependencies, "1.18.3")

      assert(errors.any? { |error| error.include?("OpenTUI source-build evidence does not match") })
    end
  end

  def test_rejects_incomplete_opencode_bun_pty_build_evidence
    source_package = Agentlab.package_named("opencode")
    dependencies = Agentlab.load_yaml(File.join(source_package.directory, "dependencies.yml"))

    Dir.mktmpdir do |directory|
      %w[selected_lock_audit source_audit license_review native_review].each do |key|
        filename = dependencies.dig("source_closure_files", key)
        FileUtils.cp(File.join(source_package.directory, filename), File.join(directory, filename))
      end
      native_path = File.join(directory, dependencies.dig("source_closure_files", "native_review"))
      native_review = Agentlab.load_yaml(native_path)
      bun_pty = native_review.fetch("components").find { |component| component["package"] == "bun-pty@0.4.8" }
      bun_pty.fetch("provenance").delete("source_build")
      File.write(native_path, YAML.dump(native_review))
      package = Agentlab::Package.new(directory: directory, manifest_path: "unused", data: { "name" => "opencode" })

      errors = Agentlab.validate_opencode_review_evidence(package, dependencies, "1.18.3")

      assert(errors.any? { |error| error.include?("bun-pty source-build evidence does not match") })
    end
  end

  def test_rejects_incomplete_opencode_tree_sitter_build_evidence
    source_package = Agentlab.package_named("opencode")
    dependencies = Agentlab.load_yaml(File.join(source_package.directory, "dependencies.yml"))

    Dir.mktmpdir do |directory|
      %w[selected_lock_audit source_audit license_review native_review].each do |key|
        filename = dependencies.dig("source_closure_files", key)
        FileUtils.cp(File.join(source_package.directory, filename), File.join(directory, filename))
      end
      native_path = File.join(directory, dependencies.dig("source_closure_files", "native_review"))
      native_review = Agentlab.load_yaml(native_path)
      tree_sitter = native_review.fetch("components").find do |component|
        component["package"] == "web-tree-sitter@0.25.10"
      end
      tree_sitter.fetch("provenance").delete("source_build")
      File.write(native_path, YAML.dump(native_review))
      package = Agentlab::Package.new(directory: directory, manifest_path: "unused", data: { "name" => "opencode" })

      errors = Agentlab.validate_opencode_review_evidence(package, dependencies, "1.18.3")

      assert(errors.any? { |error| error.include?("Tree-sitter source-build evidence does not match") })
    end
  end

  def test_validates_rust_v8_evidence
    package = Agentlab.package_named("rust-v8")
    dependencies = Agentlab.load_yaml(File.join(package.directory, "dependencies.yml"))
    spec = File.read(package.spec_path)
    license = JSON.parse(File.read(File.join(package.directory, dependencies.dig("license_audit", "receipt"))))
    archive_graph = JSON.parse(File.read(File.join(package.directory, dependencies.dig("archive_graph", "receipt"))))

    assert_empty(Agentlab.validate_rust_v8_evidence(package, dependencies, spec))
    assert_equal(1, license.fetch("unmaterialized_deps_declarations").length)
    googletest = license.fetch("unmaterialized_deps_declarations").fetch(0)
    assert_equal("v8/third_party/googletest/src", googletest.fetch("source_path"))
    assert_equal("4fe3307fb2d9f86d19777c7eb0e4809e9694dde7", googletest.fetch("commit"))
    assert_equal("no", googletest.fetch("readme_shipped"))
    refute(googletest.fetch("source_materialized"))
    refute(googletest.fetch("declared_text_resolvable"))
    assert_equal(3, license.dig("summary", "readme_chromium_ambiguous_comma_licenses"))
    assert_equal(8, license.dig("summary", "vendored_rust_legacy_slash_license_expressions"))
    assert_equal(0, license.dig("summary", "readme_chromium_proposed_normalizations"))
    assert_equal(4, license.dig("summary", "readme_chromium_semantically_reviewed_normalizations"))
    assert_equal(3, license.dig("summary", "readme_chromium_semantically_verified_declared_license_paths"))
    assert_equal(8, license.dig("summary", "vendored_rust_mechanically_normalized_license_expressions"))
    clang_format = license.fetch("components").flat_map { |component| component.fetch("readme_chromium") }.find do |record|
      record["path"] == "buildtools/clang_format/README.chromium"
    end
    assert_equal("(Apache-2.0 WITH LLVM-exception) AND NCSA", clang_format.fetch("normalized_expression"))
    assert_equal("verified", clang_format.fetch("semantic_review_status"))
    assert_equal(2, license.fetch("scoped_parent_license_evidence").length)
    assert_equal(1_796, archive_graph.dig("archive", "object_input_count"))
    assert_equal(1_796, archive_graph.dig("archive", "member_count"))
    assert_equal(31, archive_graph.dig("archive", "implicit_rust_rlib_count"))
    refute(archive_graph.dig("archive", "implicit_rust_rlibs_embedded_in_archive"))
    refute(archive_graph.dig("archive", "member_contents_match_object_contents_verified"))
    assert_empty(archive_graph.dig("archive", "selected_googletest_inputs"))
    refute(archive_graph.dig("validation", "selected_build_dependency_closure_verified"))
    license.dig("vendored_rust", "packages").each do |record|
      paths = record.fetch("license_files").map { |license_file| license_file.fetch("path") }
      assert_equal(paths.sort, paths)
    end
  end

  def test_rejects_rust_v8_license_overclaim
    source_package = Agentlab.package_named("rust-v8")
    dependencies = Agentlab.load_yaml(File.join(source_package.directory, "dependencies.yml"))
    data = Marshal.load(Marshal.dump(source_package.data))
    spec = File.read(source_package.spec_path)

    Dir.mktmpdir do |directory|
      source_name = dependencies.dig("source_closure", "receipt")
      license_name = dependencies.dig("license_audit", "receipt")
      archive_graph_name = dependencies.dig("archive_graph", "receipt")
      FileUtils.cp(File.join(source_package.directory, source_name), File.join(directory, source_name))
      FileUtils.cp(File.join(source_package.directory, license_name), File.join(directory, license_name))
      FileUtils.cp(File.join(source_package.directory, archive_graph_name), File.join(directory, archive_graph_name))
      license_path = File.join(directory, license_name)
      license = JSON.parse(File.read(license_path))
      license.fetch("validation")["fedora_allowed_spdx_verified"] = true
      File.write(license_path, JSON.pretty_generate(license) + "\n")
      license_sha256 = Digest::SHA256.file(license_path).hexdigest
      data.fetch("license_audit")["receipt_sha256"] = license_sha256
      dependencies = Marshal.load(Marshal.dump(dependencies))
      dependencies.fetch("license_audit")["receipt_sha256"] = license_sha256
      spec = spec.sub(/^%global license_audit_sha256\s+\h{64}$/, "%global license_audit_sha256 #{license_sha256}")
      package = Agentlab::Package.new(directory: directory, manifest_path: "unused", data: data)

      errors = Agentlab.validate_rust_v8_evidence(package, dependencies, spec)

      assert_includes(errors, "rust-v8: license audit overclaims fedora_allowed_spdx_verified")

      license.fetch("validation")["fedora_allowed_spdx_verified"] = false
      license.fetch("validation")["declared_license_text_semantic_review_complete"] = true
      File.write(license_path, JSON.pretty_generate(license) + "\n")
      license_sha256 = Digest::SHA256.file(license_path).hexdigest
      data.fetch("license_audit")["receipt_sha256"] = license_sha256
      dependencies.fetch("license_audit")["receipt_sha256"] = license_sha256
      spec = spec.sub(/^%global license_audit_sha256\s+\h{64}$/, "%global license_audit_sha256 #{license_sha256}")
      package = Agentlab::Package.new(directory: directory, manifest_path: "unused", data: data)

      errors = Agentlab.validate_rust_v8_evidence(package, dependencies, spec)

      assert_includes(errors, "rust-v8: license audit overclaims declared_license_text_semantic_review_complete")
    end
  end

  def test_rejects_rust_v8_flat_archive_stripping
    package = Agentlab.package_named("rust-v8")
    dependencies = Agentlab.load_yaml(File.join(package.directory, "dependencies.yml"))
    spec = File.read(package.spec_path).sub(
      'tar -xzf "$2" -C "$1" --no-same-owner',
      'tar -xzf "$2" -C "$1" --no-same-owner --strip-components=1'
    )

    errors = Agentlab.validate_rust_v8_evidence(package, dependencies, spec)

    assert_includes(errors, "rust-v8: flat archive extraction helper is invalid")
  end

  def test_rejects_rust_v8_license_syntax_contradiction
    source_package = Agentlab.package_named("rust-v8")
    dependencies = Agentlab.load_yaml(File.join(source_package.directory, "dependencies.yml"))
    data = Marshal.load(Marshal.dump(source_package.data))
    spec = File.read(source_package.spec_path)

    Dir.mktmpdir do |directory|
      source_name = dependencies.dig("source_closure", "receipt")
      license_name = dependencies.dig("license_audit", "receipt")
      archive_graph_name = dependencies.dig("archive_graph", "receipt")
      FileUtils.cp(File.join(source_package.directory, source_name), File.join(directory, source_name))
      FileUtils.cp(File.join(source_package.directory, license_name), File.join(directory, license_name))
      FileUtils.cp(File.join(source_package.directory, archive_graph_name), File.join(directory, archive_graph_name))
      license_path = File.join(directory, license_name)
      license = JSON.parse(File.read(license_path))
      googletest = license.fetch("components").flat_map { |component| component.fetch("readme_chromium") }.find do |record|
        record["path"] == "v8/third_party/googletest/README.chromium"
      end
      googletest["syntax_class"] = "spdx-identifier-syntax"
      googletest["normalized_expression"] = "BSD"
      googletest["normalization_status"] = "syntax-only"
      File.write(license_path, JSON.pretty_generate(license) + "\n")
      license_sha256 = Digest::SHA256.file(license_path).hexdigest
      data.fetch("license_audit")["receipt_sha256"] = license_sha256
      dependencies = Marshal.load(Marshal.dump(dependencies))
      dependencies.fetch("license_audit")["receipt_sha256"] = license_sha256
      spec = spec.sub(/^%global license_audit_sha256\s+\h{64}$/, "%global license_audit_sha256 #{license_sha256}")
      package = Agentlab::Package.new(directory: directory, manifest_path: "unused", data: data)

      errors = Agentlab.validate_rust_v8_evidence(package, dependencies, spec)

      assert_includes(errors, "rust-v8: license syntax metadata is inconsistent for v8/third_party/googletest/README.chromium")

      googletest["syntax_class"] = "legacy-bsd-label"
      googletest["normalized_expression"] = nil
      googletest["normalization_status"] = "unresolved"
      vendor = license.dig("vendored_rust", "packages").find do |record|
        record["path"] == "third_party/rust/chromium_crates_io/vendor/android_system_properties-v0_1"
      end
      vendor["syntax_class"] = "spdx-expression-syntax"
      vendor["normalized_expression"] = "MIT OR Apache-2.0"
      vendor["proposed_expression"] = nil
      vendor["normalization_status"] = "syntax-only"
      File.write(license_path, JSON.pretty_generate(license) + "\n")
      license_sha256 = Digest::SHA256.file(license_path).hexdigest
      data.fetch("license_audit")["receipt_sha256"] = license_sha256
      dependencies.fetch("license_audit")["receipt_sha256"] = license_sha256
      spec = spec.sub(/^%global license_audit_sha256\s+\h{64}$/, "%global license_audit_sha256 #{license_sha256}")
      package = Agentlab::Package.new(directory: directory, manifest_path: "unused", data: data)

      errors = Agentlab.validate_rust_v8_evidence(package, dependencies, spec)

      assert_includes(
        errors,
        "rust-v8: license syntax metadata is inconsistent for third_party/rust/chromium_crates_io/vendor/android_system_properties-v0_1"
      )

      vendor.fetch("license_files").reject! { |record| File.basename(record.fetch("path")) == "LICENSE-MIT" }
      File.write(license_path, JSON.pretty_generate(license) + "\n")
      license_sha256 = Digest::SHA256.file(license_path).hexdigest
      data.fetch("license_audit")["receipt_sha256"] = license_sha256
      dependencies.fetch("license_audit")["receipt_sha256"] = license_sha256
      spec = spec.sub(/^%global license_audit_sha256\s+\h{64}$/, "%global license_audit_sha256 #{license_sha256}")
      package = Agentlab::Package.new(directory: directory, manifest_path: "unused", data: data)

      errors = Agentlab.validate_rust_v8_evidence(package, dependencies, spec)

      assert_includes(
        errors,
        "rust-v8: mechanical slash normalization lacks both texts for third_party/rust/chromium_crates_io/vendor/android_system_properties-v0_1"
      )

      license.fetch("scoped_parent_license_evidence").fetch(0)["whole_component_license_verified"] = true
      File.write(license_path, JSON.pretty_generate(license) + "\n")
      license_sha256 = Digest::SHA256.file(license_path).hexdigest
      data.fetch("license_audit")["receipt_sha256"] = license_sha256
      dependencies.fetch("license_audit")["receipt_sha256"] = license_sha256
      spec = spec.sub(/^%global license_audit_sha256\s+\h{64}$/, "%global license_audit_sha256 #{license_sha256}")
      package = Agentlab::Package.new(directory: directory, manifest_path: "unused", data: data)

      errors = Agentlab.validate_rust_v8_evidence(package, dependencies, spec)

      assert_includes(errors, "rust-v8: scoped parent-license evidence does not match")
    end
  end

  def test_rejects_rust_v8_archive_graph_overclaim
    source_package = Agentlab.package_named("rust-v8")
    dependencies = Agentlab.load_yaml(File.join(source_package.directory, "dependencies.yml"))
    data = Marshal.load(Marshal.dump(source_package.data))
    spec = File.read(source_package.spec_path)

    Dir.mktmpdir do |directory|
      source_name = dependencies.dig("source_closure", "receipt")
      license_name = dependencies.dig("license_audit", "receipt")
      archive_graph_name = dependencies.dig("archive_graph", "receipt")
      [source_name, license_name, archive_graph_name].each do |name|
        FileUtils.cp(File.join(source_package.directory, name), File.join(directory, name))
      end
      archive_graph_path = File.join(directory, archive_graph_name)
      archive_graph = JSON.parse(File.read(archive_graph_path))
      archive_graph.fetch("validation")["selected_build_dependency_closure_verified"] = true
      archive_graph.fetch("archive")["member_contents_match_object_contents_verified"] = true
      archive_graph.fetch("validation")["archive_member_contents_match_selected_object_contents_verified"] = true
      File.write(archive_graph_path, JSON.pretty_generate(archive_graph) + "\n")
      archive_graph_sha256 = Digest::SHA256.file(archive_graph_path).hexdigest
      data.fetch("archive_graph")["receipt_sha256"] = archive_graph_sha256
      dependencies = Marshal.load(Marshal.dump(dependencies))
      dependencies.fetch("archive_graph")["receipt_sha256"] = archive_graph_sha256
      spec = spec.sub(/^%global archive_graph_sha256\s+\h{64}$/, "%global archive_graph_sha256 #{archive_graph_sha256}")
      package = Agentlab::Package.new(directory: directory, manifest_path: "unused", data: data)

      errors = Agentlab.validate_rust_v8_evidence(package, dependencies, spec)

      assert_includes(errors, "rust-v8: archive-graph validation overclaims selected_build_dependency_closure_verified")
      assert_includes(errors, "rust-v8: archive-graph witness overclaims member-content equality")
      assert_includes(errors, "rust-v8: archive-graph validation overclaims archive_member_contents_match_selected_object_contents_verified")

      archive_graph.fetch("validation")["selected_build_dependency_closure_verified"] = false
      archive_graph.fetch("archive")["member_contents_match_object_contents_verified"] = false
      archive_graph.fetch("validation")["archive_member_contents_match_selected_object_contents_verified"] = false
      archive_graph.fetch("archive")["selected_googletest_inputs"] = ["obj/third_party/googletest/gtest-all.o"]
      File.write(archive_graph_path, JSON.pretty_generate(archive_graph) + "\n")
      archive_graph_sha256 = Digest::SHA256.file(archive_graph_path).hexdigest
      data.fetch("archive_graph")["receipt_sha256"] = archive_graph_sha256
      dependencies.fetch("archive_graph")["receipt_sha256"] = archive_graph_sha256
      spec = spec.sub(/^%global archive_graph_sha256\s+\h{64}$/, "%global archive_graph_sha256 #{archive_graph_sha256}")
      package = Agentlab::Package.new(directory: directory, manifest_path: "unused", data: data)

      errors = Agentlab.validate_rust_v8_evidence(package, dependencies, spec)

      assert_includes(errors, "rust-v8: selected archive graph unexpectedly includes googletest")
    end
  end

  def test_rejects_rust_v8_archive_graph_metadata_overclaim
    source_package = Agentlab.package_named("rust-v8")
    dependencies = Agentlab.load_yaml(File.join(source_package.directory, "dependencies.yml"))
    data = Marshal.load(Marshal.dump(source_package.data))
    data.fetch("archive_graph")["scope"] = "production"
    data.fetch("archive_graph")["implicit_rust_rlibs_embedded_in_archive"] = true
    package = Agentlab::Package.new(directory: source_package.directory, manifest_path: "unused", data: data)

    errors = Agentlab.validate_rust_v8_evidence(package, dependencies, File.read(source_package.spec_path))

    assert_includes(errors, "rust-v8: archive-graph metadata scope does not match")
    assert_includes(errors, "rust-v8: archive-graph metadata overclaims embedded Rust rlibs")
  end

  def test_rejects_rust_v8_nonterminal_fail_closed_stop
    package = Agentlab.package_named("rust-v8")
    dependencies = Agentlab.load_yaml(File.join(package.directory, "dependencies.yml"))
    spec = File.read(package.spec_path).sub("\nexit 1\n\n%build", "\n# exit 1\n\n%build")

    errors = Agentlab.validate_rust_v8_evidence(package, dependencies, spec)

    assert_includes(errors, "rust-v8: deliberate remaining-gates stop is missing")
  end
end
