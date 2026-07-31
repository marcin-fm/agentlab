# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"
require "yaml"
require_relative "../scripts/lib/agentlab"
load File.expand_path("../scripts/audit-openchamber-lock-closure", __dir__)
load File.expand_path("../scripts/audit-xberg-proof-receipts", __dir__)
load File.expand_path("../scripts/write-xberg-cargo-license-receipts", __dir__)
load File.expand_path("../scripts/prepare-headroom-fixture-source", __dir__)

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

  def prepare_bun_fixture_repository(source_package, directory, copy_package: false)
    repository = File.join(directory, "repo")
    package_directory = File.join(repository, "packages", "bun")
    scripts_directory = File.join(repository, "scripts")
    FileUtils.mkdir_p([package_directory, scripts_directory])
    FileUtils.cp_r("#{source_package.directory}/.", package_directory) if copy_package

    source_repository = File.expand_path("../..", source_package.directory)
    %w[acquire-bun-release-local-sources prove-bun-npm-offline-install prove-bun-webkit-source-build prove-bun-zig-bootstrap].each do |name|
      FileUtils.cp(File.join(source_repository, "scripts", name), File.join(scripts_directory, name))
    end
    package_directory
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

  def test_identifies_only_an_invoked_unavailable_rpm_macro
    Dir.mktmpdir do |directory|
      spec = File.join(directory, "fixture.spec")
      File.write(spec, "%gometa -L -f\nName: fixture\n")
      assert_equal("gometa", Agentlab.unavailable_rpm_macro_parse_failure(spec, "error: line 1: Unknown tag: %gometa -L -f", macro_available: false))
      assert_nil(Agentlab.unavailable_rpm_macro_parse_failure(spec, "error: line 1: Unknown tag: %gometa -L -f", macro_available: true))
      assert_nil(Agentlab.unavailable_rpm_macro_parse_failure(spec, "error: line 1: Unknown tag: %other", macro_available: false))
      assert_nil(Agentlab.unavailable_rpm_macro_parse_failure(spec, "error: unrelated parse failure", macro_available: false))
    end
  end

  def test_extracts_spec_patch_files_in_declaration_order
    spec = <<~SPEC
      Patch2: third.patch
      # Commented Patch8: ignored.patch
      Patch0: first.patch
      Patch11: final.patch
    SPEC

    assert_equal(%w[third.patch first.patch final.patch], Agentlab.spec_patch_files(spec))
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

  def test_openchamber_source_graph_resolves_aliases_packages_and_globs
    Dir.mktmpdir do |directory|
      FileUtils.mkdir_p(File.join(directory, "src", "assets"))
      File.write(File.join(directory, "src", "entry.ts"), <<~SOURCE)
        import { helper } from '@app/helper';
        import 'pkg/subpath';
        void import('lazy-package');
        const assets = import.meta.glob('./assets/*.svg', { eager: true });
      SOURCE
      File.write(File.join(directory, "src", "helper.ts"), "export { value as helper } from 'mapped/subpath';\n")
      File.write(File.join(directory, "src", "assets", "a.svg"), "<svg/>\n")
      File.write(File.join(directory, "src", "assets", "b.svg"), "<svg/>\n")

      graph = OpenChamberLockAudit::SourceGraph.new(
        source_dir: directory,
        configuration: {
          "schema" => "openchamber-source-import-graph/v1",
          "entrypoints" => ["src/entry.ts"],
          "aliases" => { "@app" => "src" },
          "package_aliases" => { "mapped" => "mapped-package" },
          "extensions" => %w[.ts .svg]
        }
      ).run

      assert_equal(%w[lazy-package mapped-package pkg], graph.fetch("package_roots").map { |record| record.fetch("name") })
      assert_equal(4, graph.fetch("files").length)
      assert_equal(%w[src/assets/a.svg src/assets/b.svg], graph.dig("globs", 0, "matches"))
      assert_equal(true, graph.dig("validation", "literal_dynamic_imports_only"))
    end
  end

  def test_openchamber_source_graph_rejects_nonliteral_dynamic_import
    Dir.mktmpdir do |directory|
      File.write(File.join(directory, "entry.ts"), "const name = 'module'; void import(name);\n")
      graph = OpenChamberLockAudit::SourceGraph.new(
        source_dir: directory,
        configuration: {
          "schema" => "openchamber-source-import-graph/v1",
          "entrypoints" => ["entry.ts"],
          "aliases" => {},
          "extensions" => [".ts"]
        }
      )

      error = assert_raises(Agentlab::Error) { graph.run }
      assert_match(/nonliteral dynamic import in entry\.ts/, error.message)
    end
  end

  def test_openchamber_selected_lock_validator_rejects_reachability_overclaim
    package = Agentlab.package_named("openchamber")
    dependencies = Agentlab.load_yaml(File.join(package.directory, "dependencies.yml"))
    receipt_path = File.join(package.directory, dependencies.dig("source_closure_files", "selected_lock_audit"))
    receipt = JSON.parse(File.read(receipt_path))

    Dir.mktmpdir do |directory|
      receipt.dig("validation")["source_import_reachability_verified"] = false
      temporary_receipt = File.join(directory, "receipt.json")
      File.write(temporary_receipt, JSON.pretty_generate(receipt) + "\n")
      temporary_dependencies = Marshal.load(Marshal.dump(dependencies))
      temporary_dependencies.fetch("source_closure_files")["selected_lock_audit"] = "receipt.json"
      temporary_dependencies.fetch("selected_lock_receipt")["sha256"] = Digest::SHA256.file(temporary_receipt).hexdigest
      temporary_package = Struct.new(:name, :directory, :upstream, :data).new(
        package.name,
        directory,
        package.upstream,
        package.data
      )

      errors = Agentlab.validate_openchamber_selected_lock(temporary_package, temporary_dependencies)
      assert_includes(errors, "openchamber: selected lock validation source_import_reachability_verified is not true")
    end
  end

  def test_openchamber_source_acquisition_validator_rejects_package_path_drift
    package = Agentlab.package_named("openchamber")
    dependencies = Agentlab.load_yaml(File.join(package.directory, "dependencies.yml"))
    receipt_path = File.join(package.directory, dependencies.dig("source_closure_files", "source_audit"))
    receipt = JSON.parse(File.read(receipt_path))

    Dir.mktmpdir do |directory|
      receipt.fetch("sources").first.fetch("package_paths") << "unexpected/path"
      temporary_receipt = File.join(directory, "source-audit.json")
      File.write(temporary_receipt, JSON.pretty_generate(receipt) + "\n")
      FileUtils.cp(File.join(package.directory, dependencies.dig("source_closure_files", "selected_lock_audit")), directory)
      temporary_dependencies = Marshal.load(Marshal.dump(dependencies))
      temporary_dependencies.fetch("source_closure_files")["source_audit"] = "source-audit.json"
      temporary_dependencies.fetch("source_acquisition_receipt")["sha256"] = Digest::SHA256.file(temporary_receipt).hexdigest
      temporary_package = Struct.new(:name, :directory, :upstream, :data).new(
        package.name,
        directory,
        package.upstream,
        package.data
      )

      errors = Agentlab.validate_openchamber_source_acquisition(temporary_package, temporary_dependencies)
      assert(errors.any? { |error| error.include?("acquired package paths mismatch") }, errors.inspect)
    end
  end

  def test_openchamber_source_materialization_validator_rejects_member_count_drift
    package = Agentlab.package_named("openchamber")
    dependencies = Agentlab.load_yaml(File.join(package.directory, "dependencies.yml"))
    receipt_path = File.join(package.directory, dependencies.dig("source_closure_files", "source_materialization"))
    receipt = JSON.parse(File.read(receipt_path))

    Dir.mktmpdir do |directory|
      receipt.dig("archives", "production_build")["member_count"] += 1
      temporary_receipt = File.join(directory, "closure.json")
      File.write(temporary_receipt, JSON.pretty_generate(receipt) + "\n")
      FileUtils.cp(File.join(package.directory, dependencies.dig("source_closure_files", "source_audit")), directory)
      temporary_dependencies = Marshal.load(Marshal.dump(dependencies))
      temporary_dependencies.fetch("source_closure_files")["source_materialization"] = "closure.json"
      temporary_dependencies.fetch("source_materialization_receipt")["sha256"] = Digest::SHA256.file(temporary_receipt).hexdigest
      temporary_data = Marshal.load(Marshal.dump(package.data))
      temporary_data.fetch("source_policy")["source_materialization_receipt"] = "closure.json"
      temporary_data.fetch("source_policy")["source_materialization_sha256"] = Digest::SHA256.file(temporary_receipt).hexdigest
      temporary_package = Struct.new(:name, :directory, :upstream, :data).new(
        package.name,
        directory,
        package.upstream,
        temporary_data
      )

      errors = Agentlab.validate_openchamber_source_materialization(temporary_package, temporary_dependencies)
      assert_includes(errors, "openchamber: source materialization production_build member_count mismatch")
    end
  end

  def test_openchamber_source_license_inventory_rejects_license_text_hash_drift
    package = Agentlab.package_named("openchamber")
    dependencies = Agentlab.load_yaml(File.join(package.directory, "dependencies.yml"))
    inventory_path = File.join(package.directory, dependencies.dig("source_closure_files", "source_license_inventory"))
    inventory = JSON.parse(File.read(inventory_path))

    Dir.mktmpdir do |directory|
      inventory.fetch("archives").first.fetch("license_files").first["sha256"] = "0" * 64
      temporary_inventory = File.join(directory, "source-license-inventory.json")
      File.write(temporary_inventory, JSON.pretty_generate(inventory) + "\n")
      %w[selected_lock_audit source_audit].each do |key|
        FileUtils.cp(File.join(package.directory, dependencies.dig("source_closure_files", key)), directory)
      end
      temporary_dependencies = Marshal.load(Marshal.dump(dependencies))
      temporary_dependencies.fetch("source_closure_files")["source_license_inventory"] = "source-license-inventory.json"
      temporary_dependencies.fetch("source_license_inventory_receipt")["sha256"] = Digest::SHA256.file(temporary_inventory).hexdigest
      temporary_data = Marshal.load(Marshal.dump(package.data))
      temporary_data.fetch("source_policy")["source_license_inventory_receipt"] = "source-license-inventory.json"
      temporary_data.fetch("source_policy")["source_license_inventory_sha256"] = Digest::SHA256.file(temporary_inventory).hexdigest
      temporary_package = Struct.new(:name, :directory, :upstream, :data).new(
        package.name,
        directory,
        package.upstream,
        temporary_data
      )

      errors = Agentlab.validate_openchamber_source_license_inventory(temporary_package, temporary_dependencies)
      assert_includes(errors, "openchamber: source-license inventory archive evidence mismatch")
    end
  end

  def test_openchamber_native_review_validator_rejects_path_digest_drift
    package = Agentlab.package_named("openchamber")
    dependencies = Agentlab.load_yaml(File.join(package.directory, "dependencies.yml"))
    review_path = File.join(package.directory, dependencies.dig("source_closure_files", "native_review"))
    review = Agentlab.load_yaml(review_path)

    Dir.mktmpdir do |directory|
      review.fetch("components").first.dig("audit", "executable_payloads")["paths_sha256"] = "0" * 64
      temporary_review = File.join(directory, "native-review.yml")
      File.write(temporary_review, YAML.dump(review))
      %w[selected_lock_audit source_audit source_materialization better_sqlite3_proof node_pty_proof esbuild_proof rollup_proof tailwind_oxide_proof source_map_wasm_proof shiki_wasm_proof ghostty_wasm_proof lightningcss_proof sherpa_onnx_proof].each do |key|
        FileUtils.cp(File.join(package.directory, review.dig("receipts", key, "path")), directory)
      end
      FileUtils.cp(File.join(package.directory, "openchamber-better-sqlite3-system-sqlite.patch"), directory)
      temporary_dependencies = Marshal.load(Marshal.dump(dependencies))
      temporary_dependencies.fetch("source_closure_files")["native_review"] = "native-review.yml"
      temporary_dependencies.fetch("native_review_receipt")["sha256"] = Digest::SHA256.file(temporary_review).hexdigest
      temporary_data = Marshal.load(Marshal.dump(package.data))
      temporary_data.fetch("source_policy")["native_review"] = "native-review.yml"
      temporary_data.fetch("source_policy")["native_review_sha256"] = Digest::SHA256.file(temporary_review).hexdigest
      temporary_package = Struct.new(:name, :directory, :upstream, :data).new(
        package.name,
        directory,
        package.upstream,
        temporary_data
      )

      errors = Agentlab.validate_openchamber_native_review(temporary_package, temporary_dependencies)
      assert_includes(errors, "openchamber: native review executable_payloads digest mismatch for @capacitor/android@8.4.1")
    end
  end

  def test_openchamber_native_review_validator_rejects_esbuild_build_hash_drift
    package = Agentlab.package_named("openchamber")
    dependencies = Agentlab.load_yaml(File.join(package.directory, "dependencies.yml"))
    review = Agentlab.load_yaml(File.join(package.directory, dependencies.dig("source_closure_files", "native_review")))
    proof_name = dependencies.dig("source_closure_files", "esbuild_proof")
    proof = JSON.parse(File.read(File.join(package.directory, proof_name)))

    Dir.mktmpdir do |directory|
      proof.fetch("build")["second_sha256"] = "0" * 64
      temporary_proof = File.join(directory, proof_name)
      File.write(temporary_proof, JSON.pretty_generate(proof) + "\n")
      review.dig("receipts", "esbuild_proof")["sha256"] = Digest::SHA256.file(temporary_proof).hexdigest
      temporary_review = File.join(directory, "native-review.yml")
      File.write(temporary_review, YAML.dump(review))
      %w[selected_lock_audit source_audit source_materialization better_sqlite3_proof node_pty_proof rollup_proof tailwind_oxide_proof source_map_wasm_proof shiki_wasm_proof ghostty_wasm_proof lightningcss_proof sherpa_onnx_proof].each do |key|
        FileUtils.cp(File.join(package.directory, review.dig("receipts", key, "path")), directory)
      end
      FileUtils.cp(File.join(package.directory, "openchamber-better-sqlite3-system-sqlite.patch"), directory)
      temporary_dependencies = Marshal.load(Marshal.dump(dependencies))
      temporary_dependencies.fetch("source_closure_files")["native_review"] = "native-review.yml"
      temporary_dependencies.fetch("native_review_receipt")["sha256"] = Digest::SHA256.file(temporary_review).hexdigest
      temporary_data = Marshal.load(Marshal.dump(package.data))
      temporary_data.fetch("source_policy")["native_review"] = "native-review.yml"
      temporary_data.fetch("source_policy")["native_review_sha256"] = Digest::SHA256.file(temporary_review).hexdigest
      temporary_package = Struct.new(:name, :directory, :upstream, :data).new(
        package.name,
        directory,
        package.upstream,
        temporary_data
      )

      errors = Agentlab.validate_openchamber_native_review(temporary_package, temporary_dependencies)
      assert_includes(errors, "openchamber: esbuild proof build contract mismatch")
    end
  end

  def test_openchamber_native_review_validator_rejects_rollup_timestamp_drift
    package = Agentlab.package_named("openchamber")
    dependencies = Agentlab.load_yaml(File.join(package.directory, "dependencies.yml"))
    review = Agentlab.load_yaml(File.join(package.directory, dependencies.dig("source_closure_files", "native_review")))
    proof_name = dependencies.dig("source_closure_files", "rollup_proof")
    proof = JSON.parse(File.read(File.join(package.directory, proof_name)))

    Dir.mktmpdir do |directory|
      proof.fetch("build")["source_date_epoch"] = 0
      temporary_proof = File.join(directory, proof_name)
      File.write(temporary_proof, JSON.pretty_generate(proof) + "\n")
      review.dig("receipts", "rollup_proof")["sha256"] = Digest::SHA256.file(temporary_proof).hexdigest
      temporary_review = File.join(directory, "native-review.yml")
      File.write(temporary_review, YAML.dump(review))
      %w[selected_lock_audit source_audit source_materialization better_sqlite3_proof node_pty_proof esbuild_proof tailwind_oxide_proof source_map_wasm_proof shiki_wasm_proof ghostty_wasm_proof lightningcss_proof sherpa_onnx_proof].each do |key|
        FileUtils.cp(File.join(package.directory, review.dig("receipts", key, "path")), directory)
      end
      FileUtils.cp(File.join(package.directory, "openchamber-better-sqlite3-system-sqlite.patch"), directory)
      temporary_dependencies = Marshal.load(Marshal.dump(dependencies))
      temporary_dependencies.fetch("source_closure_files")["native_review"] = "native-review.yml"
      temporary_dependencies.fetch("native_review_receipt")["sha256"] = Digest::SHA256.file(temporary_review).hexdigest
      temporary_data = Marshal.load(Marshal.dump(package.data))
      temporary_data.fetch("source_policy")["native_review"] = "native-review.yml"
      temporary_data.fetch("source_policy")["native_review_sha256"] = Digest::SHA256.file(temporary_review).hexdigest
      temporary_package = Struct.new(:name, :directory, :upstream, :data).new(
        package.name,
        directory,
        package.upstream,
        temporary_data
      )

      errors = Agentlab.validate_openchamber_native_review(temporary_package, temporary_dependencies)
      assert_includes(errors, "openchamber: rollup proof build contract mismatch")
    end
  end

  def test_openchamber_native_review_validator_rejects_tailwind_oxide_timestamp_drift
    package = Agentlab.package_named("openchamber")
    dependencies = Agentlab.load_yaml(File.join(package.directory, "dependencies.yml"))
    review = Agentlab.load_yaml(File.join(package.directory, dependencies.dig("source_closure_files", "native_review")))
    proof_name = dependencies.dig("source_closure_files", "tailwind_oxide_proof")
    proof = JSON.parse(File.read(File.join(package.directory, proof_name)))

    Dir.mktmpdir do |directory|
      proof.fetch("build")["source_date_epoch"] = 0
      temporary_proof = File.join(directory, proof_name)
      File.write(temporary_proof, JSON.pretty_generate(proof) + "\n")
      review.dig("receipts", "tailwind_oxide_proof")["sha256"] = Digest::SHA256.file(temporary_proof).hexdigest
      temporary_review = File.join(directory, "native-review.yml")
      File.write(temporary_review, YAML.dump(review))
      %w[selected_lock_audit source_audit source_materialization better_sqlite3_proof node_pty_proof esbuild_proof rollup_proof source_map_wasm_proof shiki_wasm_proof ghostty_wasm_proof lightningcss_proof sherpa_onnx_proof].each do |key|
        FileUtils.cp(File.join(package.directory, review.dig("receipts", key, "path")), directory)
      end
      FileUtils.cp(File.join(package.directory, "openchamber-better-sqlite3-system-sqlite.patch"), directory)
      temporary_dependencies = Marshal.load(Marshal.dump(dependencies))
      temporary_dependencies.fetch("source_closure_files")["native_review"] = "native-review.yml"
      temporary_dependencies.fetch("native_review_receipt")["sha256"] = Digest::SHA256.file(temporary_review).hexdigest
      temporary_data = Marshal.load(Marshal.dump(package.data))
      temporary_data.fetch("source_policy")["native_review"] = "native-review.yml"
      temporary_data.fetch("source_policy")["native_review_sha256"] = Digest::SHA256.file(temporary_review).hexdigest
      temporary_package = Struct.new(:name, :directory, :upstream, :data).new(package.name, directory, package.upstream, temporary_data)

      errors = Agentlab.validate_openchamber_native_review(temporary_package, temporary_dependencies)
      assert_includes(errors, "openchamber: tailwind oxide proof build contract mismatch")
    end
  end

  def test_openchamber_native_review_validator_rejects_source_map_subordinate_commit_drift
    package = Agentlab.package_named("openchamber")
    dependencies = Agentlab.load_yaml(File.join(package.directory, "dependencies.yml"))
    review = Agentlab.load_yaml(File.join(package.directory, dependencies.dig("source_closure_files", "native_review")))
    proof_name = dependencies.dig("source_closure_files", "source_map_wasm_proof")
    proof = JSON.parse(File.read(File.join(package.directory, proof_name)))

    Dir.mktmpdir do |directory|
      proof.fetch("source_correspondence")["subordinate_commit"] = "0" * 40
      temporary_proof = File.join(directory, proof_name)
      File.write(temporary_proof, JSON.pretty_generate(proof) + "\n")
      review.dig("receipts", "source_map_wasm_proof")["sha256"] = Digest::SHA256.file(temporary_proof).hexdigest
      temporary_review = File.join(directory, "native-review.yml")
      File.write(temporary_review, YAML.dump(review))
      %w[selected_lock_audit source_audit source_materialization better_sqlite3_proof node_pty_proof esbuild_proof rollup_proof tailwind_oxide_proof shiki_wasm_proof ghostty_wasm_proof lightningcss_proof sherpa_onnx_proof].each do |key|
        FileUtils.cp(File.join(package.directory, review.dig("receipts", key, "path")), directory)
      end
      FileUtils.cp(File.join(package.directory, "openchamber-better-sqlite3-system-sqlite.patch"), directory)
      temporary_dependencies = Marshal.load(Marshal.dump(dependencies))
      temporary_dependencies.fetch("source_closure_files")["native_review"] = "native-review.yml"
      temporary_dependencies.fetch("native_review_receipt")["sha256"] = Digest::SHA256.file(temporary_review).hexdigest
      temporary_data = Marshal.load(Marshal.dump(package.data))
      temporary_data.fetch("source_policy")["native_review"] = "native-review.yml"
      temporary_data.fetch("source_policy")["native_review_sha256"] = Digest::SHA256.file(temporary_review).hexdigest
      temporary_package = Struct.new(:name, :directory, :upstream, :data).new(package.name, directory, package.upstream, temporary_data)

      errors = Agentlab.validate_openchamber_native_review(temporary_package, temporary_dependencies)
      assert_includes(errors, "openchamber: source-map WASM correspondence mismatch")
    end
  end

  def test_openchamber_native_review_validator_rejects_ghostty_wasm_build_hash_drift
    package = Agentlab.package_named("openchamber")
    dependencies = Agentlab.load_yaml(File.join(package.directory, "dependencies.yml"))
    review = Agentlab.load_yaml(File.join(package.directory, dependencies.dig("source_closure_files", "native_review")))
    proof_name = dependencies.dig("source_closure_files", "ghostty_wasm_proof")
    proof = JSON.parse(File.read(File.join(package.directory, proof_name)))

    Dir.mktmpdir do |directory|
      proof.fetch("build")["second_sha256"] = "0" * 64
      temporary_proof = File.join(directory, proof_name)
      File.write(temporary_proof, JSON.pretty_generate(proof) + "\n")
      review.dig("receipts", "ghostty_wasm_proof")["sha256"] = Digest::SHA256.file(temporary_proof).hexdigest
      temporary_review = File.join(directory, "native-review.yml")
      File.write(temporary_review, YAML.dump(review))
      %w[selected_lock_audit source_audit source_materialization better_sqlite3_proof node_pty_proof esbuild_proof rollup_proof tailwind_oxide_proof source_map_wasm_proof shiki_wasm_proof lightningcss_proof sherpa_onnx_proof].each do |key|
        FileUtils.cp(File.join(package.directory, review.dig("receipts", key, "path")), directory)
      end
      FileUtils.cp(File.join(package.directory, "openchamber-better-sqlite3-system-sqlite.patch"), directory)
      temporary_dependencies = Marshal.load(Marshal.dump(dependencies))
      temporary_dependencies.fetch("source_closure_files")["native_review"] = "native-review.yml"
      temporary_dependencies.fetch("native_review_receipt")["sha256"] = Digest::SHA256.file(temporary_review).hexdigest
      temporary_data = Marshal.load(Marshal.dump(package.data))
      temporary_data.fetch("source_policy")["native_review"] = "native-review.yml"
      temporary_data.fetch("source_policy")["native_review_sha256"] = Digest::SHA256.file(temporary_review).hexdigest
      temporary_package = Struct.new(:name, :directory, :upstream, :data).new(package.name, directory, package.upstream, temporary_data)

      errors = Agentlab.validate_openchamber_native_review(temporary_package, temporary_dependencies)
      assert_includes(errors, "openchamber: Ghostty WASM build mismatch")
    end
  end

  def test_openchamber_native_review_validator_rejects_lightningcss_legal_hold_drift
    package = Agentlab.package_named("openchamber")
    dependencies = Agentlab.load_yaml(File.join(package.directory, "dependencies.yml"))
    review = Agentlab.load_yaml(File.join(package.directory, dependencies.dig("source_closure_files", "native_review")))
    proof_name = dependencies.dig("source_closure_files", "lightningcss_proof")
    proof = JSON.parse(File.read(File.join(package.directory, proof_name)))

    Dir.mktmpdir do |directory|
      proof.fetch("legal_hold")["license_payload_complete"] = true
      temporary_proof = File.join(directory, proof_name)
      File.write(temporary_proof, JSON.pretty_generate(proof) + "\n")
      review.dig("receipts", "lightningcss_proof")["sha256"] = Digest::SHA256.file(temporary_proof).hexdigest
      temporary_review = File.join(directory, "native-review.yml")
      File.write(temporary_review, YAML.dump(review))
      %w[selected_lock_audit source_audit source_materialization better_sqlite3_proof node_pty_proof esbuild_proof rollup_proof tailwind_oxide_proof source_map_wasm_proof shiki_wasm_proof ghostty_wasm_proof sherpa_onnx_proof].each do |key|
        FileUtils.cp(File.join(package.directory, review.dig("receipts", key, "path")), directory)
      end
      FileUtils.cp(File.join(package.directory, "openchamber-better-sqlite3-system-sqlite.patch"), directory)
      temporary_dependencies = Marshal.load(Marshal.dump(dependencies))
      temporary_dependencies.fetch("source_closure_files")["native_review"] = "native-review.yml"
      temporary_dependencies.fetch("native_review_receipt")["sha256"] = Digest::SHA256.file(temporary_review).hexdigest
      temporary_data = Marshal.load(Marshal.dump(package.data))
      temporary_data.fetch("source_policy")["native_review"] = "native-review.yml"
      temporary_data.fetch("source_policy")["native_review_sha256"] = Digest::SHA256.file(temporary_review).hexdigest
      temporary_package = Struct.new(:name, :directory, :upstream, :data).new(package.name, directory, package.upstream, temporary_data)

      errors = Agentlab.validate_openchamber_native_review(temporary_package, temporary_dependencies)
      assert_includes(errors, "openchamber: Lightning CSS legal hold mismatch")
    end
  end

  def test_openchamber_native_review_validator_rejects_sherpa_runpath_drift
    package = Agentlab.package_named("openchamber")
    dependencies = Agentlab.load_yaml(File.join(package.directory, "dependencies.yml"))
    review = Agentlab.load_yaml(File.join(package.directory, dependencies.dig("source_closure_files", "native_review")))
    proof_name = dependencies.dig("source_closure_files", "sherpa_onnx_proof")
    proof = JSON.parse(File.read(File.join(package.directory, proof_name)))

    Dir.mktmpdir do |directory|
      proof.fetch("blockers")["absolute_runner_runpath_present"] = false
      temporary_proof = File.join(directory, proof_name)
      File.write(temporary_proof, JSON.pretty_generate(proof) + "\n")
      review.dig("receipts", "sherpa_onnx_proof")["sha256"] = Digest::SHA256.file(temporary_proof).hexdigest
      temporary_review = File.join(directory, "native-review.yml")
      File.write(temporary_review, YAML.dump(review))
      %w[selected_lock_audit source_audit source_materialization better_sqlite3_proof node_pty_proof esbuild_proof rollup_proof tailwind_oxide_proof source_map_wasm_proof shiki_wasm_proof ghostty_wasm_proof lightningcss_proof].each do |key|
        FileUtils.cp(File.join(package.directory, review.dig("receipts", key, "path")), directory)
      end
      FileUtils.cp(File.join(package.directory, "openchamber-better-sqlite3-system-sqlite.patch"), directory)
      temporary_dependencies = Marshal.load(Marshal.dump(dependencies))
      temporary_dependencies.fetch("source_closure_files")["native_review"] = "native-review.yml"
      temporary_dependencies.fetch("native_review_receipt")["sha256"] = Digest::SHA256.file(temporary_review).hexdigest
      temporary_data = Marshal.load(Marshal.dump(package.data))
      temporary_data.fetch("source_policy")["native_review"] = "native-review.yml"
      temporary_data.fetch("source_policy")["native_review_sha256"] = Digest::SHA256.file(temporary_review).hexdigest
      temporary_package = Struct.new(:name, :directory, :upstream, :data).new(package.name, directory, package.upstream, temporary_data)

      errors = Agentlab.validate_openchamber_native_review(temporary_package, temporary_dependencies)
      assert_includes(errors, "openchamber: sherpa-onnx blocker mismatch")
    end
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

  def test_normalizes_npm_prereleases_for_rpm_capabilities
    assert_equal("1.0.0~alpha.1", Agentlab.rpm_node_version("1.0.0-alpha.1"))
    assert_equal("4.0.0~beta.83", Agentlab.rpm_node_version("4.0.0-beta.83"))
    assert_equal("3.24.2", Agentlab.rpm_node_version("3.24.2"))
  end

  def test_rejects_npm_build_metadata_for_rpm_capabilities
    error = assert_raises(Agentlab::Error) { Agentlab.rpm_node_version("1.0.0+build.1") }

    assert_match(/build metadata is not supported/, error.message)
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

  def test_copr_package_build_supports_timeout_and_omits_cli_progress_callback
    Dir.mktmpdir do |directory|
      config_path = File.join(directory, "copr")
      File.write(config_path, <<~CONFIG)
        [copr-cli]
        login = api-login
        token = api-token
        copr_url = https://copr.example.test/
      CONFIG
      File.chmod(0o600, config_path)

      previous_config = ENV["COPR_CONFIG"]
      original_start = Net::HTTP.method(:start)
      captured_request = nil
      response = Object.new
      response.define_singleton_method(:body) { JSON.generate("id" => 1234, "state" => "pending") }
      response.define_singleton_method(:is_a?) do |type|
        type == Net::HTTPSuccess || Object.instance_method(:is_a?).bind_call(self, type)
      end
      http = Object.new
      http.define_singleton_method(:request) do |request|
        captured_request = request
        response
      end
      Net::HTTP.singleton_class.send(:define_method, :start) do |*_arguments, **_keywords, &block|
        block.call(http)
      end
      ENV["COPR_CONFIG"] = config_path

      result = Agentlab.copr_package_build(
        owner: "marcin",
        project: "agentlab",
        package_name: "python-headroom-ai",
        chroots: %w[fedora-44-x86_64 fedora-44-aarch64],
        timeout: 28_800
      )

      assert_equal(1234, result.fetch("id"))
      assert_equal("/api_3/package/build", captured_request.path)
      assert_match(/\ABasic /, captured_request["Authorization"])
      assert_equal("application/json", captured_request["Content-Type"])
      assert_equal(
        {
          "ownername" => "marcin",
          "projectname" => "agentlab",
          "package_name" => "python-headroom-ai",
          "chroots" => %w[fedora-44-x86_64 fedora-44-aarch64],
          "background" => false,
          "enable_net" => false,
          "timeout" => 28_800
        },
        JSON.parse(captured_request.body)
      )
      refute_includes(captured_request.body, "progress_callback")
    ensure
      Net::HTTP.singleton_class.send(:define_method, :start, original_start)
      ENV["COPR_CONFIG"] = previous_config
    end
  end

  def test_build_current_dry_run_skips_release_discovery
    script = File.expand_path("../scripts/update-and-build", __dir__)
    stdout, stderr, status = Open3.capture3(
      script,
      "--build-current",
      "--package", "python-headroom-ai"
    )

    assert(status.success?, stderr)
    assert_includes(stdout, "Dry run: no files changed and no builds submitted.")
    refute_includes(stderr, "unsupported release provider")
  end

  def test_blocked_proof_build_dry_run_requires_explicit_flag
    script = File.expand_path("../scripts/update-and-build", __dir__)
    stdout, stderr, status = Open3.capture3(
      script,
      "--build-current",
      "--proof-build",
      "--timeout", "28800",
      "--chroot", "fedora-43-x86_64",
      "--chroot", "fedora-44-x86_64",
      "--chroot", "fedora-rawhide-x86_64",
      "--package", "codex-cli"
    )

    assert(status.success?, stderr)
    assert_includes(stdout, "Dry run: no files changed and no builds submitted.")
    refute_includes(stdout, "No enabled packages selected.")
  end

  def test_current_build_rejects_unknown_chroot
    script = File.expand_path("../scripts/update-and-build", __dir__)
    _stdout, stderr, status = Open3.capture3(
      script,
      "--build-current",
      "--proof-build",
      "--chroot", "fedora-99-x86_64",
      "--package", "codex-cli"
    )

    refute(status.success?)
    assert_includes(stderr, "unknown configured chroot(s): fedora-99-x86_64")
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
    assert_includes(makefile, "scripts/build-mermaid-cli-closure")
  end

  def test_copr_makefile_materializes_the_audited_mermaid_closure
    makefile = File.read(File.expand_path("../.copr/Makefile", __dir__))
    generator = File.read(File.expand_path("../scripts/build-mermaid-cli-closure", __dir__))

    assert_includes(makefile, "mermaid-cli.spec)")
    assert_includes(makefile, "nodejs22-npm")
    assert_includes(makefile, "ruby-bundled-gems")
    assert_includes(makefile, "/srv/tmp/agentlab-mermaid-cli-srpm.XXXXXX")
    assert_includes(makefile, '--source "$$specdir/$$version.tar.gz"')
    assert_includes(makefile, "node-closure.tar.zst closure.json bundled-licenses.txt native.json third-party-notices.txt closure-receipt.json")
    assert_includes(generator, 'dependencies.dig("lockfile", "generator_npm_version")')
    assert_includes(generator, 'dependencies.fetch("source_closure_sha256")')
    assert_includes(generator, "does not match audited SHA-256")
  end

  def test_copr_makefile_materializes_the_audited_opencode_sources
    makefile = File.read(File.expand_path("../.copr/Makefile", __dir__))

    assert_includes(makefile, "opencode.spec)")
    assert_includes(makefile, "scripts/acquire-opencode-sources")
    assert_includes(makefile, "scripts/materialize-opencode-sources")
    assert_includes(makefile, "scripts/prepare-opencode-bun-pty-sources")
    assert_includes(makefile, "scripts/prepare-opencode-photon-sources")
    assert_includes(makefile, "scripts/prepare-opencode-closure-evidence")
    assert_includes(makefile, "scripts/audit-opencode-final-licenses")
    assert_includes(makefile, "scripts/materialize-opencode-node-modules")
    assert_includes(makefile, 'cmp "$$tempdir/source-audit.json"')
    assert_includes(makefile, 'cmp "$$tempdir/source-materialization.json"')
    assert_includes(makefile, "opencode-$$version-nm-prod-build.tar.zst")
    assert_includes(makefile, "opencode-$$version-nm-dev-test.tar.zst")
    assert_includes(makefile, "opencode-$$version-bun-pty-cargo-vendor.tar.zst")
    assert_includes(makefile, "for suffix in photon-cargo-vendor.tar.zst wasm-bindgen-cli-cargo-vendor.tar.zst")
    assert_includes(makefile, '"$$specdir/opencode-$$version-$$suffix"')
    assert_includes(makefile, "closure.json bundled-licenses.txt native.json")
    assert_includes(makefile, "packages/bun/bun-1.3.14-final-linked-license-closure.json")
    assert_includes(makefile, 'opencode-$$version-final-license-closure.json')
  end

  def test_copr_makefile_materializes_the_tree_sitter_parser_subset
    makefile = File.read(File.expand_path("../.copr/Makefile", __dir__))
    generator_path = File.expand_path(
      "../packages/rust-tree-sitter-language-pack1/prepare_subset.py",
      __dir__
    )
    inventory = JSON.parse(File.read(File.expand_path(
      "../packages/rust-tree-sitter-language-pack1/licensed-parser-subset-inventory.json",
      __dir__
    )))
    generator = File.read(generator_path)
    evidence_generator = File.read(File.expand_path(
      "../packages/rust-tree-sitter-language-pack1/generate_parser_inventory.py",
      __dir__
    ))

    assert_includes(makefile, "rust-tree-sitter-language-pack1.spec)")
    assert_includes(makefile, "parser-source-license-evidence-$$version.tar.zst")
    assert_includes(makefile, "--verify-tracked-contract")
    assert_includes(makefile, "packages/rust-tree-sitter-language-pack1/prepare_subset.py")
    assert_includes(generator, '"vb": "upstream issue 7 confirms')
    assert_includes(generator, '"pgn": "BSD-2-Clause text is absent')
    assert_includes(generator, "generated subset manifest differs from tracked SHA256SUMS")
    assert_includes(evidence_generator, '("LICENSE", "LICENCE", "COPYING", "NOTICE")')
    assert_includes(evidence_generator, '"do what the fuck you want to public license"')
    assert_equal(293, inventory.fetch("included_count"))
    assert_equal(13, inventory.fetch("excluded_count"))
    assert_equal(
      "84835d8fd1ced163b65bbf560c9fe9b3bd4d0753d1c1c96d85d8e5dd77f7a55b",
      inventory.fetch("closure_archive_sha256")
    )
  end

  def test_rtk_current_static_contract
    rtk = Agentlab.package_named("rtk")
    spec = File.read(rtk.spec_path)
    contract_path = File.join(rtk.directory, rtk.data.dig("source_contract", "file"))
    contract = JSON.parse(File.read(contract_path))
    reproducibility = Agentlab.load_yaml(File.join(rtk.directory, "reproducibility.yml"))
    validator = File.read(File.expand_path("../scripts/check-packages", __dir__))

    assert_equal("0.44.1", rtk.upstream.fetch("current_version"))
    assert_equal("735623ee670483216bc5fe7ca0885f1f1358d8f9facf22782a6ea8e8a44f3b3a", rtk.upstream.fetch("source_sha256"))
    assert_equal("0.44.1-0.1", rtk.data.dig("build_validation", "release"))
    assert_equal("116106bef8d568217ca25f986912b1a2b75818288efac02c548addbec8e568ae", Digest::SHA256.file(contract_path).hexdigest)
    assert_equal("agentlab-rtk-source-contract/v1", contract.fetch("schema"))
    assert_equal({ "name" => "rtk", "version" => "0.44.1", "tag" => "v0.44.1", "commit" => "36591fb00d650bf987b57483c0b3a395a35a8dc1" }, contract.fetch("release").slice("name", "version", "tag", "commit"))
    assert_equal("8f31137e18556611e1ad93fa6f551899f3533aa7b38fd9413fe0157519a558f9", contract.dig("release", "source_archive_tree_sha256"))
    assert_equal(contract.dig("release", "source_archive_tree_sha256"), contract.dig("release", "tag_commit_tree_sha256"))
    assert_equal("0e360b52a271c90275a73d56f016abdf60d80096a6cfdfb2767228b054b8fd45", contract.dig("upstream_lock", "sha256"))
    assert_equal(%w[rtk-use-system-sqlite.patch rtk-use-dirs6.patch], contract.fetch("fedora_patches").map { |patch| patch.fetch("file") })
    assert_equal(%w[2496b4395840cc4ed84ba4e39124250336b10d03b321fbda2c62d7601b16f080 826e2cd42dd4b70e6f8b50a178e5305c6946d81e219f1dd17e0cabe4d0e839b5], contract.fetch("fedora_patches").map { |patch| patch.fetch("sha256") })
    assert_equal({ "version" => "0.31", "default_features" => true, "features" => [] }, contract.dig("post_patch_manifest", "rusqlite"))
    assert_equal("6", contract.dig("post_patch_manifest", "dirs"))
    assert_equal("Apache-2.0 AND BSD-3-Clause AND CDLA-Permissive-2.0 AND ISC AND MIT AND MPL-2.0 AND Unicode-3.0 AND Unicode-DFS-2016 AND Zlib", contract.dig("license_candidate", "expression"))
    assert_equal(false, contract.dig("license_candidate", "final_linked_license"))
    assert_equal(%w[commands parse_failures], contract.dig("runtime_contract", "tables"))
    assert_equal(%w[id timestamp original_cmd rtk_cmd input_tokens output_tokens saved_tokens savings_pct exec_time_ms project_path], contract.dig("runtime_contract", "columns", "commands"))
    assert_equal(%w[id timestamp raw_command error_message fallback_succeeded], contract.dig("runtime_contract", "columns", "parse_failures"))
    assert_equal(%w[idx_pf_timestamp idx_project_path_timestamp idx_timestamp], contract.dig("runtime_contract", "indexes"))
    assert_equal({ "command" => "true", "expected_total_records" => 1, "expected_matching_records" => 1, "input_tokens" => 0, "output_tokens" => 0, "saved_tokens" => 0 }, contract.dig("runtime_contract", "proxy_smoke"))
    assert(contract.fetch("target_validation").except("matrix").values.all? { |value| value == false })
    assert_equal(6, contract.dig("target_validation", "matrix").length)
    assert(contract.dig("target_validation", "matrix").values.all? { |value| value == false })
    assert(rtk.data.dig("build_validation", "target").values.all? { |value| value == false })
    assert(%w[fedora_43 fedora_44 rawhide].all? { |family| rtk.data.dig("dependency_status", family, "current_release_verified") == false })
    assert_equal([false, false], rtk.data.dig("dependency_status", "system_sqlite").values_at("target_linkage_verified", "target_schema_verified"))
    assert_equal(["pending target LICENSE.dependencies verification", false], rtk.data.fetch("license_audit").values_at("final_target_expression", "target_inventory_verified"))
    assert_equal(false, rtk.data.dig("license_audit", "target_inventory_verified"))
    assert_equal(false, rtk.data.dig("architecture_audit", "current_matrix_verified"))
    assert_equal({ "release" => "0.43.0-0.6", "build_id" => 10749341, "status" => "succeeded", "scope" => "Fedora 43, Fedora 44, and Rawhide on x86_64 and aarch64" }, rtk.data.fetch("historical_build"))
    assert_equal(Digest::SHA256.file(rtk.spec_path).hexdigest, reproducibility.fetch("current_spec_sha256"))
    assert_equal("116106bef8d568217ca25f986912b1a2b75818288efac02c548addbec8e568ae", reproducibility.dig("source_inputs", "source_contract", "sha256"))
    assert_equal("immutable historical result; not current 0.44.1 proof", reproducibility.dig("validation", "historical_0_43_0", "evidence_role"))

    assert_includes(spec, "Source1:        rtk-%{version}-source-contract.json")
    assert_includes(spec, "%global source_contract_sha256 116106bef8d568217ca25f986912b1a2b75818288efac02c548addbec8e568ae")
    assert_includes(spec, "%global rtk_source_license_expression Apache-2.0 AND BSD-3-Clause AND CDLA-Permissive-2.0 AND ISC AND MIT AND MPL-2.0 AND Unicode-3.0 AND Unicode-DFS-2016 AND Zlib")
    assert_includes(spec, "License:        %{rtk_source_license_expression}")
    assert_includes(spec, "%autosetup -n %{crate}-%{version} -N")
    assert_includes(spec, "%autopatch -p1")
    assert_includes(spec, "%cargo_test")
    assert_includes(spec, "test -s LICENSE.dependencies")
    assert_includes(spec, 'target_license_expression="$(%cargo_license_summary)"')
    assert_includes(spec, 'test "$target_license_expression" = "%{rtk_source_license_expression}"')
    assert_includes(spec, "grep -Eq '\\(NEEDED\\).*\\[libsqlite3\\.so\\.0\\]' rtk-smoke.dynamic")
    assert_includes(spec, "! grep -Eq '\\((RPATH|RUNPATH)\\)' rtk-smoke.dynamic")
    assert_includes(spec, "select name from sqlite_master where type = 'table' order by name")
    assert_includes(spec, "printf '%s\\n' commands parse_failures")
    assert_includes(spec, "cmp -s rtk-smoke.expected-tables rtk-smoke.tables")
    assert_includes(spec, "pragma_table_info('commands')")
    assert_includes(spec, "id timestamp original_cmd rtk_cmd input_tokens output_tokens saved_tokens savings_pct exec_time_ms project_path")
    assert_includes(spec, "pragma_table_info('parse_failures')")
    assert_includes(spec, "id timestamp raw_command error_message fallback_succeeded")
    assert_includes(spec, "idx_pf_timestamp idx_project_path_timestamp idx_timestamp")
    assert_includes(spec, "select count(*) from commands")
    assert_includes(spec, 'test "$command_records" = "1"')
    assert_includes(spec, "trim(original_cmd) = 'true'")
    assert_includes(spec, 'test "$proxy_records" = "1"')
    assert_operator(spec.index("Patch0:         rtk-use-system-sqlite.patch"), :<, spec.index("Patch1:         rtk-use-dirs6.patch"))

    assert_includes(validator, 'if package.name == "rtk"')
    assert_includes(validator, 'source_env: "AGENTLAB_RTK_SOURCE0"')
    assert_includes(validator, 'patches: %w[rtk-use-system-sqlite.patch rtk-use-dirs6.patch]')
    assert_includes(validator, 'errors << "rtk: source contract SHA-256 differs"')
    assert_includes(validator, 'errors << "rtk: target validation gates are not fail-closed"')
  end

  def test_headroom_mcp_and_jwt_current_static_contracts
    targets = Agentlab.config.fetch("chroots")
    headroom = Agentlab.package_named("python-headroom-ai")
    headroom_spec = File.read(headroom.spec_path)
    audit_path = File.join(
      headroom.directory,
      headroom.data.dig("build_validation", "selected_license_audit_file")
    )
    audit = JSON.parse(File.read(audit_path))
    contract_path = File.join(
      headroom.directory,
      headroom.data.dig("build_validation", "fedora_license_contract_file")
    )
    contract = JSON.parse(File.read(contract_path))
    reproducibility = Agentlab.load_yaml(File.join(headroom.directory, "reproducibility.yml"))

    assert_equal("0.33.0", headroom.upstream.fetch("current_version"))
    assert_equal(targets, headroom.chroots(targets))
    assert_equal(
      headroom.data.dig("build_validation", "selected_license_audit_sha256"),
      Digest::SHA256.file(audit_path).hexdigest
    )
    assert_equal("agentlab-headroom-selected-cargo-license-audit/v1", audit.fetch("schema"))
    assert_equal(391, audit.dig("selection", "normal_tree_entries"))
    assert_equal(217, audit.dig("selection", "unique_package_versions"))
    assert_equal(217, audit.fetch("records").length)
    assert_equal(audit.fetch("records").uniq, audit.fetch("records"))
    assert_equal(contract.dig("source_audit", "candidate_binary_spdx"), audit.fetch("candidate_binary_spdx"))
    assert_equal(headroom_spec[/^%global headroom_binary_license\s+(.+)$/, 1], contract.fetch("target_binary_spdx"))
    assert_equal(
      "3f8a0af6f859a553b6619b531c000dc805a4a8ba785e60768d1343faad2b2d71",
      reproducibility.dig("current_draft", "selected_license_audit", "sha256")
    )
    assert_equal("74db5baf44a41b1000312c673544b3374e4198af5605c7f9080a402cec42cfa3", audit.dig("supplemental_license_texts", 0, "sha256"))
    assert_equal(true, audit.dig("validation", "target_license_dependencies_comparison_implemented"))
    assert_equal("4dbc7e06524b52b997d74cbbcf847e2988c807630544ffb42301b704eae27738", Digest::SHA256.file(contract_path).hexdigest)
    assert_equal("agentlab-headroom-fedora-linked-license-contract/v2", contract.fetch("schema"))
    common_records = contract.fetch("common_records")
    assert_equal(166, common_records.length)
    assert_equal(common_records.uniq.sort, common_records)
    assert_equal({ "43" => 172, "44" => 172, "45" => 172 }, contract.fetch("families").transform_values { |family| family.fetch("record_count") })
    assert_equal({ "43" => "261fff0ffc64c0704b89a3e95daa89380a519bc53682f07a4c89b326934c7b45", "44" => "405798ed561507c67423ebb6227faaf973a054f267b8c01e7d868b1019aadd96", "45" => "b490d0f022f657589341c881e46c22b8305e3109fe4c82a7379a3fa700ea8119" }, contract.fetch("families").transform_values { |family| family.fetch("canonical_sha256") })
    contract.fetch("families").each_value do |family|
      additional_records = family.fetch("additional_records")
      assert_equal(6, additional_records.length)
      assert_equal(additional_records.uniq.sort, additional_records)
      linked_records = (common_records + additional_records).uniq.sort
      assert_equal(family.fetch("record_count"), linked_records.length)
      assert_equal(family.fetch("canonical_sha256"), Digest::SHA256.hexdigest(linked_records.join("\n") + "\n"))
    end
    assert_equal("Zlib", contract.dig("target_only_records", 0, "cargo_license_expression"))
    assert_includes(headroom_spec, "Source1:        headroom-%{version}-selected-cargo-license-audit.json")
    assert_includes(headroom_spec, "Source2:        headroom-%{version}-fedora-license-contract.json")
    assert_includes(headroom_spec, "Source3:        headroom-%{version}-code-compressor-fixtures.tar.gz")
    assert_includes(headroom_spec, '%{python3} - "%{SOURCE1}" "%{SOURCE2}" LICENSE.dependencies "%{headroom_binary_license}" "%{fedora}"')
    assert_includes(headroom_spec, 'expected = sorted(set(common_records + additional_records))')
    assert_includes(headroom_spec, 'Fedora linked-license records differ')
    assert_includes(headroom_spec, 'hashlib.sha256(payload.encode("utf-8")).hexdigest()')
    assert_includes(headroom_spec, 'headroom-core v0\\.1\\.0')
    assert_includes(headroom_spec, "LICENSE.regex-syntax-unicode")
    assert_includes(headroom_spec, "Requires:       python3dist(mcp) >= 1.28.1")
    assert_includes(headroom_spec, "Requires:       python3dist(mcp) < 2")
    assert_equal("0.33.0-0.6", headroom.data.dig("build_validation", "release"))
    assert_equal("28aa53dc7ca51e687cc719c3fe160f3be50c6570", headroom.data.dig("build_validation", "released_test_source_commit"))
    assert_equal("fd83d0f65f8c729a7b0f78c54a767bfb467a4c8d6d2edce89125677475f4a82a", headroom.data.dig("build_validation", "released_test_source_sha256"))
    assert_equal("headroom-0.33.0-code-compressor-fixtures.tar.gz", headroom.data.dig("build_validation", "generated_fixture_source_file"))
    assert_equal("bd9fd41b61a7041743ac23ad6fdb4d26cb7547c29deb4ba88d4f6c2828c289e1", headroom.data.dig("build_validation", "generated_fixture_source_sha256"))
    assert_equal(15_420, headroom.data.dig("build_validation", "generated_fixture_source_bytes"))
    fixture_generator = File.join(Agentlab::ROOT, headroom.data.dig("build_validation", "fixture_source_generator"))
    assert_equal("ca62bc11715067fb90ea0bfc34cd8eca39536aeec92b1d41d32904c6fe87ecbb", Digest::SHA256.file(fixture_generator).hexdigest)
    assert_equal(30, headroom.data.dig("build_validation", "code_compressor_fixture_count"))
    assert_equal(84_202, headroom.data.dig("build_validation", "code_compressor_fixture_bytes"))
    assert_equal("f5fef19e35104e7bcca2c89d604ca5288d6da7045386f07f3998ffc37e63a5e8", headroom.data.dig("build_validation", "code_compressor_fixture_manifest_sha256"))
    ml_test_patch_path = File.join(headroom.directory, "headroom-gate-ml-integration-test.patch")
    ml_test_patch = File.read(ml_test_patch_path)
    assert_equal("27f3b96007451511b3157e278c3c3ab79f9ed2e6ddb124f19f7c99c8cdbf3a35", Digest::SHA256.file(ml_test_patch_path).hexdigest)
    assert_includes(ml_test_patch, '+name = "kompress_parity"')
    assert_includes(ml_test_patch, '+path = "tests/kompress_parity.rs"')
    assert_includes(ml_test_patch, '+required-features = ["ml"]')
    assert_includes(headroom_spec, "Patch4:         headroom-gate-ml-integration-test.patch")
    sqlite_test_patch_path = File.join(headroom.directory, "headroom-stabilize-sqlite-ttl-test.patch")
    sqlite_test_patch = File.read(sqlite_test_patch_path)
    assert_equal("4cbf2a1c55ce5533f6090dd5a682c8720642f394b69858aef1e73efb263faf38", Digest::SHA256.file(sqlite_test_patch_path).hexdigest)
    assert_includes(sqlite_test_patch, "-    std::thread::sleep(Duration::from_millis(1_500));")
    assert_includes(sqlite_test_patch, "+    std::thread::sleep(Duration::from_millis(500));")
    refute_includes(sqlite_test_patch, "Duration::from_millis(2_600)")
    assert_includes(headroom_spec, "Patch5:         headroom-stabilize-sqlite-ttl-test.patch")
    assert_includes(headroom_spec, "%autosetup -n headroom_ai-%{version} -N")
    assert_includes(headroom_spec, "headroom-%{version}-code-compressor-fixtures/tests/parity/fixtures/code_aware_compressor")
    assert_includes(headroom_spec, "agentlab-headroom-code-compressor-fixture-source/v1")
    assert_includes(headroom_spec, "code-compressor fixture acquisition provenance differs")
    assert_includes(headroom_spec, "code-compressor fixture manifest differs")
    headroom_makefile = File.read(File.join(Agentlab::ROOT, ".copr", "Makefile"))
    assert_includes(headroom_makefile, "scripts/prepare-headroom-fixture-source")
    assert_includes(headroom_makefile, "headroom-$$version-code-compressor-fixtures.tar.gz")
    assert_equal(Digest::SHA256.file(headroom.spec_path).hexdigest, reproducibility.dig("current_draft", "spec_sha256"))
    assert_includes(headroom_spec, "%cargo_test -n")
    headroom_dependencies = Agentlab.load_yaml(File.join(headroom.directory, "dependencies.yml"))
    assert_includes(headroom_dependencies.dig("build_runtime", "local_packages"), "rust-tree-sitter0.25.2 = 0.25.2")
    assert_includes(headroom_dependencies.dig("build_runtime", "local_packages"), "rust-tokenizers0.22 = 0.22.2")
    refute(reproducibility.fetch("current_static_validation").keys.any? { |key| key.match?(/remote|copr|build_id/) })
    refute_match(/\b(?:copr|build)\s+\d+\b/i, headroom.data.fetch("build_validation").values.grep(String).join(" "))
    refute_match(/\b(?:copr|build)\s+\d+\b/i, reproducibility.fetch("current_static_validation").values.grep(String).join(" "))

    mcp = Agentlab.package_named("python-mcp")
    mcp_spec = File.read(mcp.spec_path)
    mcp_reproducibility = Agentlab.load_yaml(File.join(mcp.directory, "reproducibility.yml"))
    mcp_dependencies = Agentlab.load_yaml(File.join(mcp.directory, "dependencies.yml"))
    assert_equal(targets, mcp.chroots(targets))
    assert_equal(
      "ef60c72690bca5b1afa11ac9c3e5a7ef490740061c79dd02a4a849108a16ac1c",
      mcp_reproducibility.dig("patches", "replace-uv-dynamic-version-with-hatchling-vcs.diff")
    )
    assert_includes(mcp.data.dig("validation", "fedora_43_backend_proof"), "mcp-1.28.1-py3-none-any.whl")
    assert_includes(mcp_spec, "%if 0%{?fedora} == 43")
    assert_includes(mcp_dependencies["runtime"], "python3dist(pyjwt) >= 2.10.1")
    fedora_44, fedora_44_error, fedora_44_status = Agentlab.capture(["rpmspec", "-P", mcp.spec_path])
    fedora_43, fedora_43_error, fedora_43_status = Agentlab.capture(["rpmspec", "--define", "fedora 43", "--define", "dist .fc43", "-P", mcp.spec_path])
    assert(fedora_44_status.success?, fedora_44_error)
    assert(fedora_43_status.success?, fedora_43_error)
    backend_patch = 'echo "Patch #0 (replace-uv-dynamic-version-with-hatchling-vcs.diff):"'
    pythonpath_patch = 'echo "Patch #1 (pass-pythonpath-for-subprocess.diff):"'
    refute_includes(fedora_44, backend_patch)
    assert_includes(fedora_44, pythonpath_patch)
    assert_operator(fedora_43.index(backend_patch), :<, fedora_43.index(pythonpath_patch))

    jwt = Agentlab.package_named("python-jwt")
    assert_equal(%w[fedora-43-x86_64 fedora-43-aarch64], jwt.chroots(targets))
    assert_equal(%w[fedora_44 rawhide], jwt.data.dig("copr", "omitted_target_families").keys.sort)
    applicability = Agentlab.load_yaml(File.join(Agentlab::ROOT, "config", "target-applicability.yml"))
    assert_equal("python3-jwt 2.10.1-3.fc44", applicability.dig("overrides", "python-jwt", "omitted", "44", "provider"))
    assert_equal("python3-jwt 2.13.0-2.fc45", applicability.dig("overrides", "python-jwt", "omitted", "rawhide", "provider"))

    tree_sitter = Agentlab.package_named("rust-tree-sitter0.25.2")
    tree_sitter_spec = File.read(tree_sitter.spec_path)
    assert_equal("0.25.2", tree_sitter.upstream.fetch("current_version"))
    assert_equal(targets, tree_sitter.chroots(targets))
    assert_includes(tree_sitter_spec, "License:        MIT AND Unicode-DFS-2016 AND BSD-2-Clause AND BSD-3-Clause AND LicenseRef-Fedora-Public-Domain")
    assert_includes(tree_sitter_spec, "Patch0:         tree-sitter-fix-metadata.diff")
    assert_includes(tree_sitter_spec, "Provides:       bundled(tree-sitter) = %{version}")
    assert_includes(tree_sitter_spec, "Provides:       bundled(icu) = 65.1")
    assert_includes(tree_sitter_spec, "%license %{crate_instdir}/src/unicode/LICENSE")
    assert_includes(tree_sitter_spec, "install -pm0644 %{SOURCE1} %{buildroot}%{crate_instdir}/LICENSE")
    assert_equal(1, tree_sitter_spec.scan("%global debug_package %{nil}").length)
    assert_equal(3, tree_sitter_spec.scan("BuildArch:      noarch").length)
    assert_includes(tree_sitter_spec, "%package     -n %{name}+default-devel")
    assert_includes(tree_sitter_spec, "%package     -n %{name}+std-devel")
    assert_equal(%w[default std], tree_sitter.data.dig("validation", "feature_subpackages"))
    assert_equal(["crate(tree-sitter/default) = 0.25.2", "crate(tree-sitter/std) = 0.25.2"], tree_sitter.data.dig("validation", "generated_cargo_provides"))
    assert_equal(["bundled(tree-sitter) = 0.25.2", "bundled(icu) = 65.1"], tree_sitter.data.dig("validation", "bundled_provides"))
    assert_equal(["LICENSE", "src/unicode/LICENSE"], tree_sitter.data.dig("validation", "license_payload"))
    assert_equal("disabled for the noarch source-only payload", tree_sitter.data.dig("validation", "debug_package"))
    assert_equal(1, tree_sitter_spec.scan("%cargo_generate_buildrequires").length)
    assert_operator(tree_sitter_spec.index("%cargo_generate_buildrequires"), :>, tree_sitter_spec.index("%generate_buildrequires"))
    assert_includes(tree_sitter_spec, 'test "$(cargo2rpm --path Cargo.toml provides --feature default)" = "crate(tree-sitter/default) = %{version}"')
    assert_includes(tree_sitter_spec, 'test "$(cargo2rpm --path Cargo.toml provides --feature std)" = "crate(tree-sitter/std) = %{version}"')
    assert_equal(Digest::SHA256.file(tree_sitter.spec_path).hexdigest, tree_sitter.data.dig("validation", "spec_sha256"))
    tree_sitter_expanded, tree_sitter_error, tree_sitter_status = Agentlab.capture(["rpmspec", "--define", "_sourcedir #{tree_sitter.directory}", "-P", tree_sitter.spec_path])
    assert(tree_sitter_status.success?, tree_sitter_error)
    tree_sitter_patch_markers = [
      'echo "Patch #0 (tree-sitter-fix-metadata.diff):"',
      'echo "Patch #1 (tree-sitter-build-bindings-unconditionally.patch):"',
      'echo "Patch #2 (tree-sitter-bindgen-rust-version.patch):"'
    ]
    tree_sitter_patch_offsets = tree_sitter_patch_markers.map { |marker| tree_sitter_expanded.index(marker) }
    assert(tree_sitter_patch_offsets.all?)
    assert_equal(tree_sitter_patch_offsets.sort, tree_sitter_patch_offsets)
    assert_operator(tree_sitter_expanded.scan("--fuzz=0").length, :>=, 3)
    assert_includes(tree_sitter_spec, "%bcond check 0")

    tokenizers = Agentlab.package_named("rust-tokenizers0.22")
    tokenizers_spec = File.read(tokenizers.spec_path)
    tokenizers_features = %w[default esaxx_fast fancy-regex hf-hub http indicatif onig progressbar rustls-tls]
    assert_equal("0.22.2", tokenizers.upstream.fetch("current_version"))
    assert_equal(%w[fedora-rawhide-x86_64 fedora-rawhide-aarch64], tokenizers.chroots(targets))
    assert_equal("b238e22d44a15349529690fb07bd645cf58149a1b1e44d6cb5bd1641ff1a6223", tokenizers.upstream.fetch("source_sha256"))
    assert_equal("7f730f9d509caa800e5a40ce763577141e363f40fb4d9f17a61bc0eec0aa482a", Digest::SHA256.file(File.join(tokenizers.directory, "tokenizers-fix-metadata.diff")).hexdigest)
    assert_equal(tokenizers_features, tokenizers.data.dig("validation", "feature_subpackages"))
    assert_equal(1, tokenizers_spec.scan("%global debug_package %{nil}").length)
    assert_equal(10, tokenizers_spec.scan("BuildArch:      noarch").length)
    tokenizers_features.each do |feature|
      assert_includes(tokenizers_spec, "%package     -n %{name}+#{feature}-devel")
      assert_includes(tokenizers_spec, "test \"$(cargo2rpm --path Cargo.toml provides --feature #{feature})\" = \"crate(tokenizers/#{feature}) = %{version}\"")
    end
    assert_includes(tokenizers_spec, "%patch -P 0 -p1")
    assert_equal(Digest::SHA256.file(tokenizers.spec_path).hexdigest, tokenizers.data.dig("validation", "spec_sha256"))
    tokenizers_override = applicability.dig("overrides", "rust-tokenizers0.22")
    assert_equal(["rawhide"], tokenizers_override.fetch("releases"))
    assert_equal(%w[43 44], tokenizers_override.fetch("omitted").keys.sort)
  end

  def test_docling_core_and_slim_current_static_contracts
    targets = Agentlab.config.fetch("chroots")
    core = Agentlab.package_named("python-docling-core")
    core_spec = File.read(core.spec_path)
    core_reproducibility = Agentlab.load_yaml(File.join(core.directory, "reproducibility.yml"))
    assert_equal("2.88.0", core.upstream.fetch("current_version"))
    assert_equal("ffc67cb863f6f93a875dfcc3dd3ac109fff68abcadcb4c951036fae777d82796", core.upstream.fetch("source_sha256"))
    assert_equal("2.88.0-0.2", core_reproducibility.fetch("version"))
    assert_equal("required", core.data.dig("validation", "patches_zero_fuzz"))
    refute(core.data.fetch("validation").key?("current_release_copr"))
    assert_equal(targets, core_reproducibility.dig("validation", "required_copr_targets"))
    refute(core.data.key?("artifacts"))
    refute(core.data.key?("historical_validation"))
    refute(core_reproducibility.key?("historical_validation"))
    %w[
      docling-core-setuptools-backend.patch
      docling-core-add-requests.patch
      docling-core-typer-0.26.patch
      test/test_base.py
      test/test_data_gen_flag.py
      test/test_doc_base.py
      test/test_otsl_table_export.py
      test/test_page.py
      test/test_regions_to_table.py
    ].each { |fragment| assert_includes(core_spec, fragment) }
    assert_includes(core_spec, "DocLangDocSerializer")
    assert_includes(core_spec, "docling-serialize --help")
    assert_includes(core_spec, "docling-view --help")

    slim = Agentlab.package_named("python-docling-slim")
    slim_spec = File.read(slim.spec_path)
    slim_reproducibility = Agentlab.load_yaml(File.join(slim.directory, "reproducibility.yml"))
    assert_equal("2.117.0", slim.upstream.fetch("current_version"))
    assert_equal("7c2b8ce1700b7dcc235b9839d85e83e21d89cbb43b593a3e2fdb4e880e56c483", slim.upstream.fetch("source_sha256"))
    assert_equal("2.117.0-0.1", slim_reproducibility.fetch("version"))
    assert_equal("required", slim.data.dig("validation", "patch_zero_fuzz"))
    refute(slim.data.fetch("validation").key?("current_release_copr"))
    assert_equal(targets, slim_reproducibility.dig("validation", "required_copr_targets"))
    refute(slim.data.key?("historical_validation"))
    refute(slim_reproducibility.key?("historical_validation"))
    refute_path_exists(File.join(slim.directory, "docling-slim-guard-scipy-import.patch"))
    refute_includes(slim_spec, "docling-slim-guard-scipy-import.patch")
    %w[
      docling-slim-service-client-api-only.patch
      BatchSourceRequestInput
      BatchTargetRequestInput
      GenericSourceRequest
      GenericTargetRequest
      ChunkingOptionType
      inspect.signature(DoclingServiceClient.submit_batch)
      inspect.signature(AsyncDoclingServiceClient.submit_batch)
    ].each { |fragment| assert_includes(slim_spec, fragment) }
    assert_includes(slim_spec, "%pyproject_buildrequires -x service-client")
    assert_includes(slim_spec, "DoclingServiceClient(f\"http://127.0.0.1:{port}\").health()")
  end

  def test_docling_mcp_provider_refresh_remains_blocked
    package = Agentlab.package_named("python-docling-mcp")
    spec = File.read(package.spec_path)
    dependencies = Agentlab.load_yaml(File.join(package.directory, "dependencies.yml"))
    reproducibility = Agentlab.load_yaml(File.join(package.directory, "reproducibility.yml"))
    providers = [
      "python-docling-core 2.88.0",
      "python-docling-slim 2.117.0 service-client API",
      "python-doclang 0.7.3",
      "python-latex2mathml 3.81.0"
    ]

    assert_equal("blocked", package.status)
    assert_equal(false, package.data.dig("copr", "enabled"))
    assert_equal(providers, package.data.dig("dependency_status", "completed_reusable_packages"))
    assert_equal(providers, dependencies.fetch("completed_reusable_packages"))
    assert_equal("2.1.0-0.6", package.data.dig("build_validation", "release"))
    assert_equal("blocked-source-review-validated", package.data.dig("build_validation", "status"))
    assert_equal("2.1.0-0.6", reproducibility.fetch("version"))
    assert_equal("prohibited", reproducibility.dig("validation", "binary_build"))
    refute(package.data.key?("historical_validation"))
    refute(reproducibility.key?("historical_validation"))
    assert_includes(spec, "python-docling-mcp is blocked: see package.yml and dependencies.yml")
    assert_includes(spec, "exit 1")
    refute_match(/^%build\b|^%install\b/m, spec)
  end

  def test_xberg_is_blocked_and_kreuzberg_is_not_wired_for_source_generation
    makefile = File.read(File.expand_path("../.copr/Makefile", __dir__))
    package = Agentlab.package_named("xberg")
    spec = File.read(File.join(package.directory, "xberg.spec"))
    receipt_path = File.join(package.directory, package.data.dig("source_audit_receipt", "file"))
    receipt = JSON.parse(File.read(receipt_path))
    system_ort_receipt_path = File.join(package.directory, package.data.dig("system_ort_audit_receipt", "file"))
    system_ort_receipt = JSON.parse(File.read(system_ort_receipt_path))
    provider_proof_path = File.join(package.directory, package.data.dig("cargo_source_contract", "source_evidence", "provider_proof", "file"))
    provider_proof = JSON.parse(File.read(provider_proof_path))
    assert_equal("a698e53ae96f1a944e74afce5a39f54ffe59830130422cc330f52c61c1dcef15", package.data.dig("source_audit_receipt", "sha256"))
    assert_equal("baf0efc96f735fbda22cad3fb22d08a79dc9a8e9286aa1f150972dbc3bbc5a0d", package.data.dig("source_link_filter", "sha256"))
    assert_equal("68327b502bfc978d754aa75c99ddd2e7b378fe1fdcee601fe3837df3f18a59f7", package.data.dig("system_ort_audit_receipt", "sha256"))
    assert_equal("a8e11cce6425868975b00b13db98acf21a7bc2cb8e7fe143a80aa5ebfeddf667", package.data.dig("cargo_source_contract", "cargo_lock_sha256"))
    assert_equal("3882ffdd756c9d65921934afb59c8c546abc5da1753fbfa378fc42c2df5f7907", package.data.dig("cargo_source_contract", "source_evidence", "closure", "sha256"))
    assert_equal("8980a1d9bb4a1123b2cbdc6dcc082993226c3d0eca09facc59c39124896f2819", package.data.dig("cargo_source_contract", "source_evidence", "vendor_receipt", "sha256"))
    assert_equal("99b5a7f6d2f1f3d5b2559f784b3d729a21743e14eee89721b5c0c24ab4fed691", package.data.dig("cargo_source_contract", "source_evidence", "license_text_presence", "sha256"))
    assert_equal("5d571bb5bc923c855a1e75f335d32187fda5cbb6f9d64b20af960b8c5a7ba544", package.data.dig("cargo_source_contract", "source_evidence", "vendor_manifest", "sha256"))
    assert_equal("151db6184d9e3bab63aa60a8976345b3d6bf29f3f4483564ebc01ea67a4cce32", package.data.dig("cargo_source_contract", "source_evidence", "source_license_receipt", "sha256"))
    assert_equal("d69fca803d1b6c654af3d6ae8c0bab16f08f016f372851383bf2812b5e6394dd", package.data.dig("cargo_source_contract", "source_evidence", "provider_proof", "sha256"))
    assert_equal("9594bfb8b0426fe8f0329606d0fcbf6a2a744ce7a4099c60887491b4dc5619c0", package.data.dig("cargo_source_contract", "source_evidence", "fedora_allowlist", "sha256"))
    assert_equal({ "xberg-dynamic-tesseract.patch" => "4e710a29f273b2cfa542ed8d6ee1f93a57c21168d49e7aa8b2cf5835ae297634", "xberg-selected-workspace.patch" => "054d4fa336f1a823babaa26eaad3c223fc0d54e6d4e898009aeec77e0301f0b2", "xberg-fedora-system-tessdata.patch" => "a27928a78f6f51296c0af68e82e9481e972a17c7e004b320d4bda600af9bcc20" }, package.data.dig("cargo_source_contract", "patches"))

    refute_includes(makefile, "kreuzberg.spec)")
    assert_equal("blocked", package.status)
    assert_equal(false, package.data.dig("copr", "enabled"))
    assert_includes(spec, "Name:           xberg")
    assert_includes(spec, "Version:        1.0.3")
    assert_includes(spec, "%global source_sha256 238b8087a398b7753562b341abf082c8305a0359786424976909dc59b251058e")
    assert_includes(spec, "Release:        0.7%{?dist}")
    assert_includes(spec, "# Select the six-member Fedora workspace")
    assert_includes(spec, "Source1:        %{name}-%{version}-source-audit.json")
    assert_includes(spec, "Source2:        %{name}-%{version}-system-ort-audit.json")
    assert_includes(spec, "Source9:        %{name}-%{version}-source-filter.json")
    assert_includes(spec, "Source10:       %{name}-%{version}-fedora-Cargo.lock")
    assert_includes(spec, "Source11:       %{name}-%{version}-provider-proof.json")
    assert_includes(spec, "Source12:       %{name}-%{version}-source-license-receipt.json")
    assert_includes(spec, "Source13:       %{name}-%{version}-fedora-license-allowlist.json")
    assert_includes(spec, "Source14:       audit-xberg-proof-receipts")
    assert_includes(spec, "Source15:       write-xberg-cargo-license-receipts")
    assert_includes(spec, "Source16:       %{name}-%{version}-native-source-contract.json")
    assert_includes(spec, "Source17:       audit-xberg-native-source")
    assert_includes(spec, "Source18:       LICENSE.boost-1.0")
    assert_includes(spec, "%setup -q -n xberg-%{version}")
    assert_includes(spec, "--sanitize-only --source . --filter %{SOURCE9}")
    dynamic_tesseract_check = 'echo "%{dynamic_tesseract_patch_sha256}  %{PATCH2}" | sha256sum -c -'
    selected_workspace_check = 'echo "%{selected_workspace_patch_sha256}  %{PATCH3}" | sha256sum -c -'
    fedora_tessdata_check = 'echo "%{fedora_tessdata_patch_sha256}  %{PATCH4}" | sha256sum -c -'
    assert_includes(spec, dynamic_tesseract_check)
    assert_includes(spec, selected_workspace_check)
    assert_includes(spec, fedora_tessdata_check)
    assert_includes(spec, "%autopatch -p1")
    assert_operator(spec.index(dynamic_tesseract_check), :<, spec.index("%autopatch -p1"))
    assert_operator(spec.index(selected_workspace_check), :<, spec.index("%autopatch -p1"))
    assert_operator(spec.index(fedora_tessdata_check), :<, spec.index("%autopatch -p1"))
    assert_includes(spec, "BuildRequires:  pkgconfig(libonnxruntime) >= 1.18")
    assert_includes(spec, "Requires:       onnxruntime%{?_isa} >= 1.18")
    assert_includes(spec, "Requires:       tesseract-langpack-eng")
    contract = package.data.fetch("cargo_source_contract")
    assert_equal("agentlab-xberg-cargo-closure/v2", contract.fetch("closure_schema"))
    assert_equal("UTF-8 sorted unique name\\tversion\\n lines", contract.fetch("graph_identity_serialization"))
    source_filter = package.data.fetch("source_link_filter")
    source_filter_path = File.join(package.directory, source_filter.fetch("file"))
    assert_equal(source_filter.fetch("sha256"), Digest::SHA256.file(source_filter_path).hexdigest)
    filter_receipt = JSON.parse(File.read(source_filter_path))
    assert_equal("agentlab-xberg-source-filter/v1", filter_receipt.fetch("schema"))
    assert_equal({ "symlinks" => 50, "hardlinks" => 0, "safe_in_root_links" => 49, "unsafe_links" => 1 }, filter_receipt.fetch("archive_link_inventory"))
    assert_equal({ "tag" => "v1.0.3", "commit" => "37b9fee5762450351e9303243a00e51184a1f24b", "tree" => "2a5341953d531c886f8713c6f86c6aac2836ac82", "archive_sha256" => "238b8087a398b7753562b341abf082c8305a0359786424976909dc59b251058e" }, filter_receipt.fetch("source"))
    assert_equal("xberg-1.0.3/e2e/test_documents", filter_receipt.fetch("unsafe_links").first.fetch("path"))
    selected_features = %w[formats analysis core-cli embeddings html url-ingestion liter-llm ocr paddle-ocr layout-detection chunking-tokenizers]
    assert_equal([597, 1_034, 437, 603, 622, 0, -2, 437], contract.values_at("selected_registry_identities", "vendor_registry_identities", "resolver_only_registry_identities", "normal_packages", "normal_build_dev_packages", "git_dependencies", "ort_download_delta", "resolver_only_additions"))
    assert_equal(false, contract.dig("license_text_presence", "final_linked_license_complete"))
    assert_equal(
      {
        "package" => "xberg-cli",
        "no_default_features" => true,
        "features" => selected_features,
        "cargo_build" => "%cargo_build -- --package xberg-cli --no-default-features --features %{xberg_cli_features} --locked",
        "license_writer" => "scripts/write-xberg-cargo-license-receipts",
        "license_output" => "LICENSE.dependencies",
        "license_scope" => "cargo2rpm-equivalent target-all static dependency inventory; not final Linux linked-license evidence",
        "configured_scm_source_required" => true,
        "checked_vendor_required" => true,
        "offline_required" => true,
        "cli_smoke_required" => true,
        "dynamic_link_checks_required" => true,
        "deliberate_post_build_gate_required" => true,
        "rpm_installation_out_of_scope" => true,
        "final_linked_license_proof_required" => true,
        "runtime_smoke_required" => true,
        "full_matrix_required" => true
      },
      package.data.fetch("compile_proof_contract")
    )
    assert_equal(contract.dig("source_evidence", "auditor", "sha256"), Digest::SHA256.file(File.expand_path("../scripts/audit-xberg-cargo-closure", __dir__)).hexdigest)
    assert_equal("dd1eff01ff3c46cdde79291392b0069374f61497e9e99a3cdb158d347257dc0a", contract.dig("source_evidence", "auditor", "sha256"))
    assert_equal(contract.dig("source_evidence", "proof_auditor", "sha256"), Digest::SHA256.file(File.expand_path("../scripts/audit-xberg-proof-receipts", __dir__)).hexdigest)
    assert_equal("94005bcab4a60d17c65e1eee9f73e3a46a0bee60d3f70009081e46102b22eb74", contract.dig("source_evidence", "proof_auditor", "sha256"))
    native_source = contract.fetch("source_evidence")
    native_receipt = JSON.parse(File.read(File.join(package.directory, native_source.dig("native_source_contract", "file"))))
    assert_equal("agentlab-xberg-native-source-contract/v1", native_receipt.fetch("schema"))
    assert_equal(true, native_receipt.dig("claims", "native_source_inventory_complete"))
    assert_equal(false, native_receipt.dig("claims", "native_license_source_complete"))
    assert_equal("c9bff75738922193e67fa726fa225535870d2aa1059f91452c411736284ad566", native_receipt.dig("inputs", "boost_license", "sha256"))
    assert_equal(true, native_receipt.dig("xberg_libwpd", "boost_license_text_present"))
    boost_mapping = native_receipt.dig("xberg_libwpd", "archives").find { |archive| archive.fetch("path") == "boost-subset.tar.gz" }.fetch("license_mapping")
    assert_equal({ "spdx" => "BSL-1.0", "text_sha256" => "c9bff75738922193e67fa726fa225535870d2aa1059f91452c411736284ad566" }, boost_mapping.fetch("canonical_bsl_candidate"))
    assert_equal({ "path_prefix" => "boost/boost/", "count" => 9_599, "path_sha256" => "4c1dc888bc29f6cf9b8d812f54ad4dbecf4d08f9da37b66000e0a4dc45550d68" }, boost_mapping.fetch("source_files"))
    assert_equal({ "count" => 4_565, "path_sha256" => "9e762cb67bb492ebeed8fa8be45b877d9aef6cec4e30f4b1ee4ec094a35c545f" }, boost_mapping.fetch("embedded_bsl_markers"))
    assert_equal({ "count" => 5_034, "path_sha256" => "f9392b82ca4ce9a92f9340d7571a6c356b455cd6b2dbf35927f2555840e698e4" }, boost_mapping.fetch("without_detected_bsl_marker"))
    assert_equal({ "count" => 469, "path_sha256" => "fb5ce8f562e8ce62cfdfb63c1b3720e7676a7e3a53346c041f311a3240f52cc4" }, boost_mapping.dig("archive_structure", "directories"))
    assert_equal({ "count" => 5_035, "path_sha256" => "222daa7b535a58aca4c6edc042df8af9be5425e30484f7c99fcdf448bdf3642f" }, boost_mapping.dig("archive_structure", "pax_extended_headers"))
    assert_equal(0, boost_mapping.dig("archive_structure", "links_or_special_entries"))
    assert_equal(false, boost_mapping.fetch("additional_license_obligations_complete"))
    assert_equal(false, boost_mapping.fetch("bsl_only_complete"))
    assert_equal(false, boost_mapping.fetch("complete"))
    assert_equal(false, native_receipt.dig("claims", "final_link_observed"))
    assert_equal(native_source.dig("native_source_contract", "sha256"), Digest::SHA256.file(File.join(package.directory, native_source.dig("native_source_contract", "file"))).hexdigest)
    assert_equal(native_source.dig("native_source_auditor", "sha256"), Digest::SHA256.file(File.expand_path("../scripts/audit-xberg-native-source", __dir__)).hexdigest)
    closure = JSON.parse(File.read(File.join(package.directory, contract.dig("source_evidence", "closure", "file"))))
    assert_equal("agentlab-xberg-cargo-closure/v2", closure.fetch("schema"))
    assert_equal("selected-Fedora-workspace-lock-complete", closure.dig("resolver_model", "kind"))
    assert_equal([597, 1_034, 437, 603, 622], closure.fetch("counts").values_at("selected_registry_identities", "vendor_registry_identities", "resolver_only_registry_identities", "normal_packages", "normal_build_dev_packages"))
    assert_equal({ "package" => "xberg-cli", "target" => "x86_64-unknown-linux-gnu", "features" => selected_features, "no_default_features" => true, "registry_identities" => closure.dig("selection", "registry_identities") }, closure.fetch("selection"))
    assert_equal("UTF-8 sorted unique name\\tversion\\n lines", closure.dig("outputs", "identity_serialization"))
    assert(closure.dig("outputs", "normal_identity_sha256").match?(/\A[0-9a-f]{64}\z/))
    assert(closure.dig("outputs", "normal_build_dev_identity_sha256").match?(/\A[0-9a-f]{64}\z/))
    assert_equal("9f7b783531614c0a9460001ddae469dcd53ec02b37453db77f00896c72cb89fe", closure.dig("outputs", "normal_identity_sha256"))
    assert_equal("a49d533f5008678529641692a1951539120d35ccdb85197447c7aace5c954c91", closure.dig("outputs", "normal_build_dev_identity_sha256"))
    vendor_receipt = JSON.parse(File.read(File.join(package.directory, contract.dig("source_evidence", "vendor_receipt", "file"))))
    assert_equal("fb5abc63d34135752002719a3910f4ecacb049c5292b5e0f5776d7350eea2917", vendor_receipt.dig("vendor_tree", "sha256"))
    assert_equal([51_213, 9_444, 0, 1_099_639_051], vendor_receipt.fetch("vendor_tree").values_at("files", "directories", "symlinks", "bytes"))
    license = JSON.parse(File.read(File.join(package.directory, contract.dig("source_evidence", "license_text_presence", "file"))))
    assert_equal({ "present" => 959, "absent" => 75 }, license.fetch("counts"))
    assert_includes(spec, "%cargo_prep -v cargo-vendor")
    assert_includes(spec, "--prepared-source")
    assert_includes(spec, "--vendor-dir")
    assert_includes(spec, "%global cargo_license_writer_sha256 7dd6a505e65900dceded74405d586459180e2a701806b31ac24452e37acd1a51")
    assert_includes(spec, "%global xberg_cli_features #{selected_features.join(',')}")
    assert_includes(spec, "%cargo_build -- --package xberg-cli --no-default-features --features %{xberg_cli_features} --locked")
    assert_includes(spec, "ruby .agentlab-source/write-xberg-cargo-license-receipts --output LICENSE.dependencies")
    assert_includes(spec, "test \"$(find cargo-vendor -mindepth 1 -maxdepth 1 -type d | wc -l)\" -eq 1034")
    assert_includes(spec, "test \"$(wc -l < %{SOURCE7})\" -eq 1034")
    assert_includes(spec, "%cargo_prep -v cargo-vendor")
    assert_includes(spec, "target/rpm/xberg --help >/dev/null")
    assert_includes(spec, "readelf -d target/rpm/xberg >> .agentlab-ldd-r.txt")
    assert_includes(spec, "%global dynamic_tesseract_patch_sha256 4e710a29f273b2cfa542ed8d6ee1f93a57c21168d49e7aa8b2cf5835ae297634")
    assert_includes(spec, "%global selected_workspace_patch_sha256 054d4fa336f1a823babaa26eaad3c223fc0d54e6d4e898009aeec77e0301f0b2")
    assert_includes(spec, "%global fedora_tessdata_patch_sha256 a27928a78f6f51296c0af68e82e9481e972a17c7e004b320d4bda600af9bcc20")
    dynamic_patch = File.read(File.join(package.directory, "xberg-dynamic-tesseract.patch"))
    dynamic_cfg = '+#[cfg(any(feature = "build-tesseract", feature = "build-tesseract-wasm", feature = "dynamic-linking"))]'
    assert_equal(14, dynamic_patch.lines.count { |line| line.chomp == dynamic_cfg })
    %w[api.rs leptonica.rs lib.rs result_iterator.rs].each do |name|
      assert_includes(dynamic_patch, "crates/xberg-tesseract/src/#{name}")
    end
    refute_includes(dynamic_patch, "crates/xberg-tesseract/build.rs")
    %w[gcc gcc-c++ cmake clang perl binutils ruby rubypick rubygem-json tar zstd].each do |requirement|
      assert_includes(spec, requirement)
    end
    refute_includes(spec, "%cargo_build_crate -n")
    refute_includes(spec, "--features default")
    license_writer = contract.dig("source_evidence", "license_writer")
    assert_equal("scripts/write-xberg-cargo-license-receipts", license_writer.fetch("file"))
    assert_equal(license_writer.fetch("sha256"), Digest::SHA256.file(File.expand_path("../scripts/write-xberg-cargo-license-receipts", __dir__)).hexdigest)
    assert_equal("7dd6a505e65900dceded74405d586459180e2a701806b31ac24452e37acd1a51", license_writer.fetch("sha256"))
    assert_equal(
      ["/usr/bin/cargo", "tree", "-Zavoid-dev-deps", "--package=xberg-cli", "--offline", "--locked", "--edges=no-build,no-dev,no-proc-macro", "--target=all", "--prefix=none", "--format", "# {l}", "--no-default-features", "--features=#{selected_features.join(',')}"],
      XbergCargoLicenseReceipts.tree_command("# {l}")
    )
    assert_equal(["# Apache-2.0 OR MIT", "# MIT"], XbergCargoLicenseReceipts.normalize("# MIT\n# Apache-2.0 / MIT\n# MIT (*)\n", cwd: "/source"))
    assert_includes(spec, "target/rpm/xberg --version")
    assert_includes(spec, "ldd -r target/rpm/xberg")
    assert_includes(makefile, '--closure "$$specdir/xberg-$$version-cargo-closure.json"')
    assert_includes(makefile, '--filter "$$specdir/xberg-$$version-source-filter.json"')
    assert_includes(makefile, "cargo-rpm-macros curl ruby rubypick")
    assert_includes(makefile, "scripts/write-xberg-cargo-license-receipts")
    auditor = File.read(File.expand_path("../scripts/audit-xberg-cargo-closure", __dir__))
    assert_includes(auditor, "safe_symlink_target")
    assert_includes(auditor, "safe_hardlink_target")
    assert_includes(auditor, "gnu_extension_value!")
    assert_includes(auditor, "pax_records!")
    assert_includes(auditor, "verify_unsafe_links!")
    assert_includes(auditor, "sanitize_tree!")
    assert_includes(auditor, "File.symlink(linkname, target)")
    assert_includes(auditor, "File.link(source, target)")
    assert_includes(spec, "exit 1")
    assert_equal(package.data.dig("source_audit_receipt", "sha256"), Digest::SHA256.file(receipt_path).hexdigest)
    assert_equal("1.0.3-0.7", receipt.fetch("current_package_version"))
    assert_equal("v1.0.3", receipt.dig("source", "tag"))
    assert_equal("37b9fee5762450351e9303243a00e51184a1f24b", receipt.dig("source", "commit"))
    assert_equal("2a5341953d531c886f8713c6f86c6aac2836ac82", receipt.dig("source", "tree"))
    assert_equal("238b8087a398b7753562b341abf082c8305a0359786424976909dc59b251058e", receipt.dig("source", "archive", "sha256"))
    assert_equal({
      "source_filter" => { "filename" => "xberg-1.0.3-source-filter.json", "sha256" => "baf0efc96f735fbda22cad3fb22d08a79dc9a8e9286aa1f150972dbc3bbc5a0d" },
      "cargo_closure" => { "filename" => "xberg-1.0.3-cargo-closure.json", "sha256" => "3882ffdd756c9d65921934afb59c8c546abc5da1753fbfa378fc42c2df5f7907", "cargo_lock_sha256" => "a8e11cce6425868975b00b13db98acf21a7bc2cb8e7fe143a80aa5ebfeddf667" },
      "source_license" => { "filename" => "xberg-1.0.3-source-license-receipt.json", "sha256" => "151db6184d9e3bab63aa60a8976345b3d6bf29f3f4483564ebc01ea67a4cce32" },
      "provider_proof" => { "filename" => "xberg-1.0.3-provider-proof.json", "sha256" => "d69fca803d1b6c654af3d6ae8c0bab16f08f016f372851383bf2812b5e6394dd" },
      "native_source_contract" => { "filename" => "xberg-1.0.3-native-source-contract.json", "sha256" => "5452aea15ca061086f821e1688e20e9fb3b38226a88757660eb327e4ab384ab7" }
    }, receipt.fetch("source_receipts"))
    assert_equal({ "total" => 75, "selected_normal" => 22, "resolver_only" => 53, "distribution_text_required" => 74 }, receipt.dig("source_license_accounting", "missing_text_gaps"))
    assert_equal({ "fedora_xberg_provider_absent" => true, "rpm_fusion_duplicate_absence_established" => true }, receipt.fetch("distribution_duplicate_audit"))
    assert_equal(true, receipt.dig("validation", "manifest_review_complete"))
    assert_equal(true, receipt.dig("validation", "static_dependency_closure_complete"))
    assert_equal(true, receipt.dig("validation", "dependency_license_text_inventory_complete"))
    assert_equal(true, receipt.dig("validation", "native_source_inventory_complete"))
    assert_equal(false, receipt.dig("validation", "native_license_source_complete"))
    assert(receipt.fetch("validation").reject { |key, _| %w[manifest_review_complete static_dependency_closure_complete dependency_license_text_inventory_complete native_source_inventory_complete].include?(key) }.values.all? { |value| value == false })
    assert_equal(%w[xberg xberg-cli], receipt.dig("selected_root_surface", "workspace_members"))
    assert_equal(false, receipt.dig("selected_root_surface", "node_binding", "selected"))
    assert_equal(%w[formats analysis core-cli embeddings html url-ingestion liter-llm ocr paddle-ocr layout-detection chunking-tokenizers tree-sitter], receipt.fetch("default_cli_features"))
    assert_equal({ "package" => "xberg-cli", "no_default_features" => true, "features" => selected_features, "tree_sitter_included" => false }, receipt.fetch("packaged_feature_selection"))
    assert_equal(%w[xberg xberg-cli xberg-libheif xberg-libwpd xberg-paddle-ocr xberg-tesseract], receipt.fetch("selected_workspace_crates"))
    assert_equal("dynamic system ONNX Runtime", receipt.dig("native_boundaries", "onnx_runtime"))
    assert_equal("dynamic system Tesseract and Leptonica", receipt.dig("native_boundaries", "tesseract_leptonica"))
    assert_equal("dynamic system libheif", receipt.dig("native_boundaries", "libheif"))
    assert_equal("bundled source boundary; final link evidence is pending", receipt.dig("native_boundaries", "xberg_libwpd"))
    assert_equal("models are opt-in only; tessdata is Fedora-provided", receipt.dig("native_boundaries", "runtime_models_and_tessdata"))
    assert_equal([true, 597, 1_034, 437, 603, 622, 0], receipt.fetch("offline_cargo_metadata").values_at("complete", "selected_registry_identities", "vendor_registry_identities", "resolver_only_registry_identities", "normal_packages", "normal_build_dev_packages", "git_dependencies"))
    assert_equal(false, provider_proof.dig("tree_sitter", "selected"))
    assert_equal(true, provider_proof.dig("tree_sitter", "omitted_from_initial_rpm"))
    assert_equal(false, provider_proof.dig("tree_sitter", "runtime_parser_pack_download"))
    assert_equal("opt-in only for immutable checksum-verified content outside the RPM payload", provider_proof.dig("model_runtime_policy", "runtime_model_downloads"))
    assert_equal(false, provider_proof.dig("model_runtime_policy", "tessdata_runtime_download"))
    assert_equal("Fedora tesseract-langpack-* packages or an explicit local tessdata path", provider_proof.dig("model_runtime_policy", "tessdata_provider"))
    assert(%w[manifest_review_complete static_dependency_closure_complete dependency_license_text_inventory_complete].all? { |flag| receipt.dig("validation", flag) == true })
    assert(%w[native_integration_review_complete provider_audit_complete aggregate_license_complete target_source_build_complete runtime_smoke_complete target_matrix_complete enablement_complete copr_publication_complete retirements_complete retirements_authorized].all? { |flag| receipt.dig("validation", flag) == false })
    assert_equal(package.data.dig("system_ort_audit_receipt", "sha256"), Digest::SHA256.file(system_ort_receipt_path).hexdigest)
    assert_equal("agentlab-xberg-system-ort-audit/v3", system_ort_receipt.fetch("schema"))
    assert_equal(
      [
        [0, "xberg-system-onnxruntime.patch", "8b2e12741c26338aba679514262171fa2dfe2772a771255372df8d70144606ab", true],
        [1, "xberg-fedora-onnxruntime-path.patch", "b254d883cc4c0f15411eff83db7e0c072098b69fdd57e9aceaf99956e0e2121c", true],
        [2, "xberg-dynamic-tesseract.patch", "4e710a29f273b2cfa542ed8d6ee1f93a57c21168d49e7aa8b2cf5835ae297634", true],
        [3, "xberg-selected-workspace.patch", "054d4fa336f1a823babaa26eaad3c223fc0d54e6d4e898009aeec77e0301f0b2", true],
        [4, "xberg-fedora-system-tessdata.patch", "a27928a78f6f51296c0af68e82e9481e972a17c7e004b320d4bda600af9bcc20", true]
      ],
      system_ort_receipt.fetch("patches").map { |patch| patch.values_at("order", "file", "sha256", "zero_fuzz_applied") }
    )
    assert_equal(602, system_ort_receipt.dig("graph", "baseline", "normal_packages"))
    assert_equal(624, system_ort_receipt.dig("graph", "baseline", "normal_build_dev_packages"))
    assert_equal(603, system_ort_receipt.dig("graph", "patched", "normal_packages"))
    assert_equal(622, system_ort_receipt.dig("graph", "patched", "normal_build_dev_packages"))
    assert_equal(["libloading 0.9.0"], system_ort_receipt.dig("graph", "delta", "normal_added"))
    assert_equal([], system_ort_receipt.dig("graph", "delta", "normal_removed"))
    assert_equal(["hmac-sha256 1.1.14", "lzma-rust2 0.15.8", "socks 0.3.4"], system_ort_receipt.dig("graph", "delta", "normal_build_dev_removed"))
    assert_equal(%w[api-17 api-18 disable-linking std], system_ort_receipt.dig("ort_feature_resolution", "patched", "ort_sys_features"))
    assert_equal(%w[api-17 api-18 load-dynamic ndarray preload-dylibs std], system_ort_receipt.dig("ort_feature_resolution", "patched", "ort_features"))
    assert_equal(false, system_ort_receipt.dig("ort_feature_resolution", "patched", "download_binaries"))
    assert_equal("dynamic system library", system_ort_receipt.dig("system_provider_contract", "onnxruntime"))
    assert_equal("/usr/lib64/libonnxruntime.so", system_ort_receipt.dig("system_provider_contract", "runtime_library"))
    assert_equal(["onnxruntime%{?_isa} >= 1.18", "tesseract-langpack-eng"], system_ort_receipt.dig("system_provider_contract", "requires"))
    assert_equal({ "source_archive_verified" => true, "lock_checked" => true, "patches_zero_fuzz" => true, "locked_offline_metadata" => true, "locked_offline_tree" => true, "vendor_source_delivery" => true, "compilation" => false, "ort_runtime_smoke" => false, "models_licenses" => false, "aggregate_license" => false, "enablement" => false, "copr" => false, "retirements" => false }, system_ort_receipt.fetch("validation"))
    assert_equal("blocked", system_ort_receipt.dig("blocker", "status"))
    assert_equal(4, system_ort_receipt.dig("blocker", "findings").length)
    assert_equal(package.data.dig("cargo_source_contract", "source_evidence", "provider_proof", "sha256"), Digest::SHA256.file(provider_proof_path).hexdigest)
    assert_equal([597, 603, 622, 437], provider_proof.fetch("selected_graph").values_at("registry_identities", "normal_packages", "normal_build_dev_packages", "resolver_only_registry_identities"))
    assert_equal({ "source_tag" => "v1.0.3", "source_commit" => "37b9fee5762450351e9303243a00e51184a1f24b", "selected_workspace_patch" => "xberg-selected-workspace.patch", "selection" => { "package" => "xberg-cli", "no_default_features" => true, "features" => selected_features }, "dynamic_tesseract_patch" => { "sha256" => "4e710a29f273b2cfa542ed8d6ee1f93a57c21168d49e7aa8b2cf5835ae297634" }, "fedora_system_tessdata_patch" => { "sha256" => "a27928a78f6f51296c0af68e82e9481e972a17c7e004b320d4bda600af9bcc20" } }, provider_proof.fetch("source_contract"))
    assert_equal({ "xberg-system-onnxruntime.patch" => { "sha256" => "8b2e12741c26338aba679514262171fa2dfe2772a771255372df8d70144606ab" }, "xberg-fedora-onnxruntime-path.patch" => { "sha256" => "b254d883cc4c0f15411eff83db7e0c072098b69fdd57e9aceaf99956e0e2121c" } }, provider_proof.fetch("retained_ort_patches"))
    assert_equal(false, provider_proof.dig("tree_sitter", "selected"))
    assert_equal(true, provider_proof.dig("tree_sitter", "omitted_from_initial_rpm"))
    assert_equal(false, provider_proof.dig("tree_sitter", "runtime_parser_pack_download"))
    assert_equal("opt-in only for immutable checksum-verified content outside the RPM payload", provider_proof.dig("model_runtime_policy", "runtime_model_downloads"))
    assert_equal("Fedora tesseract-langpack-* packages or an explicit local tessdata path", provider_proof.dig("model_runtime_policy", "tessdata_provider"))
    assert_equal(false, provider_proof.dig("model_runtime_policy", "tessdata_runtime_download"))
    assert(provider_proof.fetch("validation").values.all? { |value| value == false })
    assert_equal("8b2e12741c26338aba679514262171fa2dfe2772a771255372df8d70144606ab", provider_proof.dig("retained_ort_patches", "xberg-system-onnxruntime.patch", "sha256"))
    assert_operator(spec.index("exit 1"), :>, spec.index("%check"))
    retirement = YAML.safe_load_file(File.expand_path("../archived/kreuzberg/retirement.yml", __dir__))
    assert_equal("kreuzberg", retirement.fetch("name"))
  end

  def test_xberg_proof_auditor_excludes_the_prepared_vendor_tree_from_source0
    Dir.mktmpdir do |source|
      File.write(File.join(source, "Cargo.toml"), <<~TOML)
        [package]
        name = "xberg"
        version = "1.0.1"
        license = "MIT"
      TOML
      nested_manifest = File.join(source, "crates", "xberg-cli")
      FileUtils.mkdir_p(nested_manifest)
      File.write(File.join(nested_manifest, "Cargo.toml"), <<~TOML)
        [package]
        name = "xberg-cli"
        version = "1.0.1"
        license.workspace = true
      TOML
      crate = File.join(source, "cargo-vendor", "model2vec-rs-0.2.1")
      FileUtils.mkdir_p(crate)
      File.write(File.join(crate, "Cargo.toml"), <<~TOML)
        [package]
        name = "model2vec-rs"
        version = "0.2.1"
        license-file = "LICENSE"
      TOML
      File.write(File.join(crate, "LICENSE"), <<~LICENSE)
        MIT License
        Permission is hereby granted, free of charge, to any person obtaining a copy.
        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
      LICENSE

      error = assert_raises(RuntimeError) { XbergProofReceipts.source_manifest_records(source) }
      assert_includes(error.message, "cargo-vendor/model2vec-rs-0.2.1/Cargo.toml")
      manifests = XbergProofReceipts.source_manifest_records(source, excluded_directory: File.join(source, "cargo-vendor"))
      assert_equal(["Cargo.toml", "crates/xberg-cli/Cargo.toml"], manifests.map { |record| record.fetch("path") })
      vendor_records = XbergProofReceipts.cargo_records(File.join(source, "cargo-vendor"))
      license_records = XbergProofReceipts.license_file_records(vendor_records, File.join(source, "cargo-vendor"))
      assert_equal(["MIT"], license_records.map { |record| record.fetch("normalized_license") })
    end
  end

  def test_agent_browser_has_complete_enabled_cargo_source_closure
    package = Agentlab.package_named("agent-browser")
    spec = File.read(File.join(package.directory, "agent-browser.spec"))

    assert_equal("enabled", package.status)
    assert_equal([], package.data.fetch("blockers"))
    assert_equal(true, package.data.dig("copr", "enabled"))
    assert_equal("0.33.1", package.upstream.fetch("current_version"))
    assert_includes(spec, "Version:        0.33.1")
    assert_includes(spec, "Release:        0.17%{?dist}")
    assert_includes(spec, "%global source_sha256 313e7706485c246b818a2138dabc6f8784f91bfa25cae7db445e6ca14c730022")
    dependencies = YAML.safe_load_file(File.join(package.directory, "dependencies.yml"))
    contract_path = File.join(package.directory, "agent-browser-0.33.1-fedora-contract.json")
    contract = JSON.parse(File.read(contract_path))
    assert_includes(spec, "npm postinstall prebuilt downloads")
    assert_includes(spec, "Chrome for Testing")
    assert_equal("forbidden", package.data.dig("source_policy", "npm_postinstall_prebuilt_downloads"))
    assert_equal("forbidden", package.data.dig("source_policy", "chrome_for_testing_downloads"))
    assert_equal(331, dependencies.dig("cargo", "source_closure_records"))
    assert_equal(256, dependencies.dig("cargo", "linux_x86_64_normal_build_candidates"))
    assert_equal(76, dependencies.dig("cargo", "resolver_only_records"))
    required_proofs = %w[production_compile cargo_tests linked_license installed_payload elf chromium_runtime target_matrix]
    assert_equal(required_proofs, dependencies.dig("cargo", "required_verification"))
    assert_equal(required_proofs, package.data.dig("dependency_status", "cargo", "required_proofs"))
    assert_equal(%w[auditor_sha256 closure_sha256 closure_verified fedora_contract_sha256 license_audit_sha256 linux_x86_64_normal_build_candidates lockfile lockfile_sha256 manifest package required_proofs resolver_only_records source_closure_records vendor_archive vendor_archive_tracked vendor_receipt_sha256 version], package.data.dig("dependency_status", "cargo").keys.sort)
    assert_equal(%w[executable package required_architectures required_runtime_smoke required_target_families], package.data.dig("dependency_status", "browser").keys.sort)
    assert_equal(%w[aggregate_binary_expression embedded_axe_core embedded_axe_third_party embedded_react_devtools selected_source_candidate_expression selected_source_metadata_complete upstream], package.data.fetch("license_audit").keys.sort)
    assert_equal(%w[cargo_license_audit cargo_vendor_manifest cargo_vendor_receipt fedora_provider_mapping generated_closure linux_x86_64_normal_build_candidates lockfile lockfile_sha256 offline_verified required_verification resolver_only_records source_closure_records source_evidence], dependencies.fetch("cargo").keys.sort)
    assert_equal(%w[compatibility_checks default_executable headed_override_executable headed_override_package required_architectures required_target_families source_downloads system_package], dependencies.fetch("browser").keys.sort)
    assert_equal(%w[intended_install_root required_payload source_directories], dependencies.fetch("skills").keys.sort)
    assert_equal(%w[cargo_expression embedded_axe_core embedded_axe_third_party embedded_react_devtools required_checks upstream], dependencies.fetch("license").keys.sort)
    assert_equal(true, dependencies.dig("cargo", "fedora_provider_mapping"))
    refute(dependencies.dig("cargo").key?("proof_builds"))
    assert_equal(%w[auditor closure fedora_contract license_audit vendor_manifest vendor_receipt], dependencies.dig("cargo", "source_evidence").keys.sort)
    dependencies.dig("cargo", "source_evidence").each_value do |item|
      assert_equal(%w[file sha256], item.keys.sort)
      path = item.fetch("file").start_with?("scripts/") ? File.expand_path("../#{item.fetch('file')}", __dir__) : File.join(package.directory, item.fetch("file"))
      assert_equal(item.fetch("sha256"), Digest::SHA256.file(path).hexdigest)
    end
    assert_includes(spec, "%cargo_prep -v cargo-vendor")
    assert_includes(spec, "%cargo_vendor_manifest")
    assert_includes(spec, "%cargo_build_crate")
    assert_includes(spec, "BuildRequires:  binutils")
    assert_includes(spec, "BuildRequires:  chromium-headless")
    refute_includes(spec, "BuildRequires:  chromium\n")
    assert_includes(spec, "BuildRequires:  file")
    assert_includes(spec, "BuildRequires:  zstd")
    assert_includes(spec, "BuildRequires:  ruby")
    assert_includes(spec, "BuildRequires:  rubypick")
    assert_includes(spec, "BuildRequires:  rubygem-json")
    assert_includes(spec, "install -d -m0700 .test-home")
    assert_includes(spec, "install -d -m0700 .test-home\nexport HOME=\"$PWD/.test-home\"\n%cargo_test")
    refute_includes(spec, "HOME=\"$PWD/.test-home\" %cargo_test")
    refute_includes(spec, "%cargo_test --skip")
    assert_includes(spec, "ruby .agentlab-source/audit-agent-browser-cargo-closure")
    refute_includes(spec, "fedora-proof")
    refute_includes(spec, "fedora_proof")
    refute_includes(spec, "fedora-contract")
    assert_includes(spec, "b232a66a487cfb5c45519501e9e7e7c5cc7dfbc879b181c8a0f2fc5e3a2e0e06")
    assert_includes(spec, "Requires:       chromium-headless")
    assert_includes(spec, "Suggests:       chromium")
    assert_includes(spec, "AGENT_BROWSER_EXECUTABLE_PATH=/usr/lib64/chromium-browser/headless_shell")
    assert_includes(spec, "AGENT_BROWSER_PRIVATE_BINARY")
    assert_includes(spec, "AGENT_BROWSER_ENGINE=lightpanda")
    assert_includes(spec, '"$public" --headed false)" = /usr/lib64/chromium-browser/headless_shell')
    assert_includes(spec, '"$public" --headed false --engine lightpanda)')
    assert_includes(spec, '"$public" --headed true)" = /usr/bin/chromium-browser')
    assert_includes(spec, "--headed requires the optional chromium package")
    wrapper_source = spec[/<<'AGENT_BROWSER_WRAPPER'\n(.*?)\nAGENT_BROWSER_WRAPPER/m, 1]
    refute_nil(wrapper_source)
    Dir.mktmpdir("agent-browser-wrapper-") do |directory|
      wrapper = File.join(directory, "agent-browser")
      probe = File.join(directory, "probe")
      File.write(wrapper, wrapper_source)
      File.write(probe, "#!/usr/bin/sh\nprintf '%s\\n' \"${AGENT_BROWSER_EXECUTABLE_PATH-}\"\n")
      FileUtils.chmod(0o755, [wrapper, probe])
      environment = { "AGENT_BROWSER_EXECUTABLE_PATH" => nil, "AGENT_BROWSER_PRIVATE_BINARY" => probe }

      stdout, stderr, status = Open3.capture3(environment, wrapper, "--headed", "false")
      assert(status.success?, stderr)
      assert_equal("/usr/lib64/chromium-browser/headless_shell\n", stdout)

      stdout, stderr, status = Open3.capture3(environment, wrapper, "--headed", "false", "--engine", "lightpanda")
      assert(status.success?, stderr)
      assert_equal("\n", stdout)
    end
    assert_includes(spec, "AGENT_BROWSER_HEADLESS_COMPATIBILITY_BEGIN")
    assert_includes(spec, 'browser_version=$(rpm -q --qf \'%%{VERSION}\' chromium-headless)')
    assert_includes(spec, "snapshot -i --json")
    assert_includes(spec, "eval 'navigator.userAgent'")
    assert_includes(spec, "fedora-headless-proof")
    assert_includes(spec, "readelf -d \"$binary\"")
    refute(package.data.dig("dependency_status", "cargo").key?("remote_proof_builds"))
    assert_includes(spec, "--verify --vendor-dir cli/cargo-vendor --receipt %{SOURCE2}")
    refute_path_exists(File.join(package.directory, "agent-browser-0.33.1-fedora-proof.json"))
    assert_equal("bound_to_agent-browser-0.33.1-fedora-contract.json", package.data.dig("license_audit", "aggregate_binary_expression"))
    assert_equal("bound_to_agent-browser-0.33.1-fedora-contract.json", dependencies.dig("license", "cargo_expression"))
    assert_equal("06e0e41027929da4bc25f9b5ef0803fdf9905e5fb269b6c305e487bd8748903f", Digest::SHA256.file(contract_path).hexdigest)
    assert_equal(Digest::SHA256.file(contract_path).hexdigest, dependencies.dig("cargo", "source_evidence", "fedora_contract", "sha256"))
    assert_equal(Digest::SHA256.file(contract_path).hexdigest, package.data.dig("dependency_status", "cargo", "fedora_contract_sha256"))
    assert_equal(%w[browser_contract build_contract forbidden_build_inputs license_contract release schema source_contract], contract.keys.sort)
    assert_equal("agentlab-agent-browser-fedora-contract/v1", contract.fetch("schema"))
    assert_equal({ "name" => "agent-browser", "version" => "0.33.1" }, contract.fetch("release"))
    assert_equal(
      {
        "source_sha256" => package.upstream.fetch("source_sha256"),
        "cargo_lock_sha256" => dependencies.dig("cargo", "lockfile_sha256"),
        "cargo_closure_sha256" => dependencies.dig("cargo", "source_evidence", "closure", "sha256"),
        "vendor_receipt_sha256" => dependencies.dig("cargo", "source_evidence", "vendor_receipt", "sha256"),
        "license_audit_sha256" => dependencies.dig("cargo", "source_evidence", "license_audit", "sha256"),
        "vendor_manifest_sha256" => dependencies.dig("cargo", "source_evidence", "vendor_manifest", "sha256"),
        "auditor_sha256" => dependencies.dig("cargo", "source_evidence", "auditor", "sha256")
      },
      contract.fetch("source_contract")
    )
    assert_equal(spec[/^License:\s+(.+)$/, 1], contract.dig("license_contract", "aggregate_spdx"))
    assert_equal({ "records" => 264, "sha256" => "b232a66a487cfb5c45519501e9e7e7c5cc7dfbc879b181c8a0f2fc5e3a2e0e06" }, contract.dig("license_contract", "generated_license_dependencies"))
    assert_equal(%w[LICENSE LICENSE-axe-core.txt LICENSE-axe-core-THIRD-PARTY.txt React-DevTools-MIT-notice.js cargo-vendor.txt LICENSE.dependencies], contract.dig("license_contract", "installed_license_files"))
    assert_equal(%w[pie no-rpath-or-runpath no-unresolved-dependencies], contract.dig("build_contract", "required_elf_checks"))
    assert_equal(%w[navigation snapshot runtime-eval url close-session], contract.dig("browser_contract", "required_smoke_steps"))
    assert_equal(%w[npm-postinstall-prebuilt-binary chrome-for-testing-download package-manager-mutation], contract.fetch("forbidden_build_inputs"))
    build_contract_fragments = [
      "%cargo_test",
      "target/rpm/agent-browser --help",
      "install -Dpm0755 cli/target/rpm/agent-browser %{buildroot}%{_libexecdir}/agent-browser/bin/agent-browser",
      "cat > %{buildroot}%{_bindir}/agent-browser",
      "cp -a skills skill-data %{buildroot}%{_libexecdir}/agent-browser/",
      "readelf -h \"$binary\" | grep -Eq 'Type:.*DYN'",
      "grep -Eq 'RPATH|RUNPATH'",
      "ldd -r \"$binary\"",
      "grep -Eq 'not found|undefined symbol' \"$PWD/.agentlab-ldd.txt\""
    ]
    assert(build_contract_fragments.all? { |fragment| spec.include?(fragment) })
    browser_contract_fragments = [
      "BuildRequires:  chromium-headless",
      "Requires:       chromium-headless",
      "Suggests:       chromium",
      "AGENT_BROWSER_EXECUTABLE_PATH=/usr/lib64/chromium-browser/headless_shell",
      "AGENT_BROWSER_EXECUTABLE_PATH=/usr/bin/chromium-browser",
      "AGENT_BROWSER_EXECUTABLE_PATH=/custom/browser",
      "AGENT_BROWSER_ENGINE=lightpanda",
      '"$public" --headed false)" = /usr/lib64/chromium-browser/headless_shell',
      '"$public" --headed false --engine lightpanda)',
      '"$public" --headed true)" = /usr/bin/chromium-browser',
      '"$public" --session copr-check --json open',
      '"$public" --session copr-check snapshot -i --json',
      '"$public" --session copr-check --json eval \'navigator.userAgent\'',
      '"$public" --session copr-check --json get url',
      '"$public" --session copr-check close',
      'grep -E "(HeadlessChrome|Chrome)/${browser_major}'
    ]
    assert(browser_contract_fragments.all? { |fragment| spec.include?(fragment) })
    duplicate_contract = {
      "required" => true,
      "repositories" => %w[fedora rpm_fusion_free rpm_fusion_nonfree],
      "target_families" => %w[fedora-43 fedora-44 fedora-rawhide],
      "queries" => ["agent-browser", "/usr/bin/agent-browser", "/usr/libexec/agent-browser/bin/agent-browser"]
    }
    assert_equal(duplicate_contract, package.data.fetch("duplicate_check"))
    assert_equal(duplicate_contract, dependencies.fetch("duplicate_availability"))
    readme = File.read(File.join(package.directory, "README.md"))
    refute_includes(readme, "10786218")
    refute_includes(readme, "/srv/tmp/")
    refute_includes(spec, "proof intentionally fails after compile/tests")
    assert_includes(spec, "%{_libexecdir}/agent-browser/bin/agent-browser")
    assert_includes(spec, "React-DevTools-MIT-notice.js")
    audit = JSON.parse(File.read(File.join(package.directory, "agent-browser-0.33.1-license-audit.json")))
    assert(audit.fetch("candidate_selected_source_expression").start_with?("("))
    assert_includes(audit.fetch("candidate_selected_source_expression"), ") AND (")
    assert_equal([], audit.fetch("missing_selected_normal_link_license_metadata"))
    assert_equal(true, audit.dig("validation", "selected_normal_link_license_metadata_complete"))
    receipt = JSON.parse(File.read(File.join(package.directory, "agent-browser-0.33.1-cargo-vendor-receipt.json")))
    assert_equal(%w[name root], receipt.fetch("vendor_archive").keys.sort)
    refute_includes(receipt.fetch("vendor_archive").keys, "sha256")
    assert_equal("sha256(sorted type,path,mode,link-target,size,content-sha256 records)", receipt.dig("vendor_tree", "algorithm"))
    makefile = File.read(File.expand_path("../.copr/Makefile", __dir__))
    assert_includes(makefile, "--output-dir \"$$tempdir/output\"")
    assert_includes(makefile, "cmp \"$$tempdir/output/agent-browser-$$version-$$suffix\"")
    assert_includes(makefile, "expected exactly one Source0: record")
    assert_includes(makefile, "/^Source0:\\s+(\\S+)/")
    refute_includes(makefile, "--output-dir \"$$specdir\"")
    refute_includes(makefile, "v0.33.1.tar.gz")
    assert_includes(makefile, "cargo-rpm-macros")
    auditor = File.read(File.expand_path("../scripts/audit-agent-browser-cargo-closure", __dir__))
    assert_includes(auditor, "cargo2rpm")
    assert_includes(auditor, "write-vendor-manifest")
    refute_includes(auditor, "write-vendor-manifest --path")
    expansion, _error, status = Agentlab.capture(["rpmspec", "-P", File.join(package.directory, "agent-browser.spec")])
    assert(status.success?)
    if expansion.match?(/cargo test/)
      assert_match(/export HOME="\$PWD\/.test-home"\n.*cargo test/m, expansion)
    else
      assert_includes(expansion, "%cargo_test")
    end
    source0 = expansion.lines.filter_map { |line| line[/^Source0:\s+(\S+)/, 1] }
    assert_equal(["https://github.com/vercel-labs/agent-browser/archive/refs/tags/v0.33.1.tar.gz"], source0)
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
      assert_equal("5.0.1", Agentlab.crates_io_latest_version("dirs", ">= 5.0, < 6.0"))
    ensure
      Agentlab.singleton_class.send(:define_method, :http_get, original_http_get)
    end
  end

  def test_crates_io_version_selection_honors_explicit_prerelease_requirement
    response = JSON.dump(
      "versions" => [
        { "num" => "2.0.0-rc.13", "yanked" => false },
        { "num" => "2.0.0-rc.12", "yanked" => false }
      ]
    )
    original_http_get = Agentlab.method(:http_get)
    Agentlab.singleton_class.send(:define_method, :http_get) do |_uri, json:|
      raise "expected JSON request" unless json

      response
    end
    begin
      assert_equal("2.0.0-rc.12", Agentlab.crates_io_latest_version("ort-sys", "= 2.0.0-rc.12"))
    ensure
      Agentlab.singleton_class.send(:define_method, :http_get, original_http_get)
    end
  end

  def test_pypi_release_selection_uses_exact_non_yanked_source_distribution
    response = JSON.dump(
      "info" => { "version" => "2.0.0" },
      "urls" => [
        {
          "filename" => "example-2.0.0-py3-none-any.whl",
          "packagetype" => "bdist_wheel",
          "yanked" => false,
          "url" => "https://files.pythonhosted.org/example.whl",
          "digests" => { "sha256" => "1" * 64 }
        },
        {
          "filename" => "example-2.0.0.tar.gz",
          "packagetype" => "sdist",
          "yanked" => true,
          "url" => "https://files.pythonhosted.org/yanked.tar.gz",
          "digests" => { "sha256" => "2" * 64 }
        },
        {
          "filename" => "example-2.0.0.zip",
          "packagetype" => "sdist",
          "yanked" => false,
          "url" => "https://files.pythonhosted.org/example.zip",
          "digests" => { "sha256" => "3" * 64 }
        },
        {
          "filename" => "example-2.0.0.tar.gz",
          "packagetype" => "sdist",
          "yanked" => false,
          "url" => "https://files.pythonhosted.org/example.tar.gz",
          "digests" => { "sha256" => "4" * 64 }
        }
      ]
    )
    original_http_get = Agentlab.method(:http_get)
    Agentlab.singleton_class.send(:define_method, :http_get) do |uri, json:|
      raise "expected PyPI project URL" unless uri.to_s == "https://pypi.org/pypi/example/json"
      raise "expected JSON request" unless json

      response
    end
    begin
      assert_equal(
        {
          version: "2.0.0",
          source_url: "https://files.pythonhosted.org/example.tar.gz",
          source_sha256: "4" * 64
        },
        Agentlab.pypi_latest_release("example")
      )
    ensure
      Agentlab.singleton_class.send(:define_method, :http_get, original_http_get)
    end
  end

  def test_pypi_release_selection_requires_stable_source_distribution
    prerelease = JSON.dump("info" => { "version" => "2.0.0rc1" }, "urls" => [])
    wheel_only = JSON.dump(
      "info" => { "version" => "2.0.0" },
      "urls" => [
        {
          "filename" => "example-2.0.0-py3-none-any.whl",
          "packagetype" => "bdist_wheel",
          "yanked" => false,
          "url" => "https://files.pythonhosted.org/example.whl",
          "digests" => { "sha256" => "5" * 64 }
        }
      ]
    )
    original_http_get = Agentlab.method(:http_get)
    responses = [prerelease, wheel_only]
    Agentlab.singleton_class.send(:define_method, :http_get) do |_uri, json:|
      raise "expected JSON request" unless json

      responses.shift
    end
    begin
      error = assert_raises(Agentlab::Error) { Agentlab.pypi_latest_release("example") }
      assert_equal("latest PyPI release for example is a prerelease: 2.0.0rc1", error.message)
      error = assert_raises(Agentlab::Error) { Agentlab.pypi_latest_release("example") }
      assert_equal("latest stable PyPI release for example 2.0.0 has no non-yanked sdist", error.message)
    ensure
      Agentlab.singleton_class.send(:define_method, :http_get, original_http_get)
    end
  end

  def test_update_package_files_persists_pypi_source_url
    Dir.mktmpdir do |directory|
      manifest_path = File.join(directory, "package.yml")
      spec_path = File.join(directory, "python-example.spec")
      data = {
        "name" => "python-example",
        "status" => "enabled",
        "upstream" => {
          "provider" => "pypi",
          "project" => "example",
          "current_version" => "1.0.0",
          "source_url" => "https://files.pythonhosted.org/example-1.0.0.tar.gz",
          "source_sha256" => "1" * 64
        },
        "copr" => { "enabled" => true, "spec" => "python-example.spec" }
      }
      File.write(manifest_path, YAML.dump(data))
      File.write(spec_path, <<~SPEC)
        %global source_sha256 #{"1" * 64}
        Name:           python-example
        Version:        1.0.0
        Release:        0.2%{?dist}

        %changelog
      SPEC
      package = Agentlab::Package.new(directory: directory, manifest_path: manifest_path, data: data)

      Agentlab.update_package_files(
        package,
        version: "2.0.0",
        sha256: "2" * 64,
        source_url: "https://files.pythonhosted.org/example-2.0.0.tar.gz",
        changelog_message: "Update the enabled package to released version 2.0.0."
      )

      manifest = YAML.safe_load_file(manifest_path)
      assert_equal("2.0.0", manifest.dig("upstream", "current_version"))
      assert_equal("2" * 64, manifest.dig("upstream", "source_sha256"))
      assert_equal(
        "https://files.pythonhosted.org/example-2.0.0.tar.gz",
        manifest.dig("upstream", "source_url")
      )
    end
  end

  def test_opencode_update_package_files_requires_upstream_release_audit
    package = Agentlab.package_named("opencode")

    error = assert_raises(Agentlab::Error) do
      Agentlab.update_package_files(
        package,
        version: "1.18.10",
        sha256: "3df0c573473d3492990bdeb69e6653eaab485394f95ad1c1a897329f4209f430",
        changelog_message: "Update the blocked draft to released version 1.18.10.",
      )
    end
    assert_equal("OpenCode update requires an audited upstream release receipt", error.message)
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

  def test_validates_pdfium_hosted_source
    source_package = Agentlab.package_named("pdfium")
    spec = File.read(File.join(source_package.directory, "pdfium.spec"))

    assert_empty(Agentlab.validate_pdfium_source(source_package, spec))

    data = Marshal.load(Marshal.dump(source_package.data))
    data.fetch("source_policy")["generated_archive_sha256"] = "0" * 64
    package = Agentlab::Package.new(directory: source_package.directory, manifest_path: "unused", data: data)
    errors = Agentlab.validate_pdfium_source(package, spec)
    assert_includes(errors, "pdfium: generated archive SHA-256 mismatch")

    errors = Agentlab.validate_pdfium_source(source_package, spec.sub("releases/download/%{source_tag}", "releases/download/wrong-tag"))
    assert_includes(errors, "pdfium: spec does not use the hosted Source0")
  end

  def test_validates_pdfium_source_release_request
    package = Agentlab.package_named("pdfium")
    closure = YAML.safe_load_file(File.join(package.directory, "source-closure.yml"))
    request = YAML.safe_load_file(File.join(Agentlab::ROOT, ".github", "source-release", "pdfium.yml"))

    assert_empty(Agentlab.validate_pdfium_source_release_request(package, closure, request))
    publish = request.merge("operation" => "publish", "generator_commit" => "1" * 40)
    assert_empty(Agentlab.validate_pdfium_source_release_request(package, closure, publish))
    {
      "archive_sha256" => "0" * 64,
      "tag" => "wrong-tag",
      "operation" => "invalid",
      "attempt" => 0
    }.each do |key, replacement|
      mutated = request.merge(key => replacement)
      assert_includes(
        Agentlab.validate_pdfium_source_release_request(package, closure, mutated),
        "source-release request mismatch"
      )
    end
    assert_includes(
      Agentlab.validate_pdfium_source_release_request(package, closure, publish.merge("generator_commit" => "bad")),
      "source-release request mismatch"
    )
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
        "historical_only" => true,
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
        "historical_only" => true,
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

  def test_validates_current_bun_seed_build_stage
    source_package = Agentlab.package_named("bun")
    Dir.mktmpdir do |directory|
      directory = prepare_bun_fixture_repository(source_package, directory, copy_package: true)
      data = Marshal.load(Marshal.dump(source_package.data))
      version = source_package.upstream.fetch("current_version").to_s
      source_inputs = data.dig("build_plan", "source_inputs")
      source_inputs.delete("final_linked_license_closure")
      stages = data.dig("build_plan", "stages")
      stages.fetch("source_delivery")["state"] = "blocked"
      stages.fetch("dependency_staging")["state"] = "blocked"
      dependency_stage = stages.fetch("dependency_closure")
      seed_stage = stages.fetch("seed_build")
      self_stage = stages.fetch("self_rebuild")
      relink_audit_metadata = Marshal.load(Marshal.dump(seed_stage.fetch("relink_materials_audit")))
      relink_kit_metadata = Marshal.load(Marshal.dump(seed_stage.fetch("relink_kit")))
      self_stage.delete("proof_receipt")
      self_stage.delete("zig_reproducibility_proof_receipt")
      self_stage.delete("zig_single_thread_control")
      seed_stage.delete("relink_materials_audit")
      seed_stage.delete("relink_kit")
      seed_stage.merge!(
        "state" => "verified",
        "historical_only" => false,
        "proof_date" => "2026-07-25",
        "proof_receipt" => "current-first-source-build-proof.json"
      )
      closure_path = File.join(directory, dependency_stage.fetch("proof_receipt"))
      closure = JSON.parse(File.read(closure_path))
      patch_sha256 = lambda do |metadata, key|
        Digest::SHA256.file(File.join(directory, metadata.fetch(key))).hexdigest
      end
      provider = source_inputs.fetch("lolhtml")
      receipt = {
        "schema" => "bun-first-source-build-proof/v2",
        "package" => "bun",
        "release" => version,
        "profile" => "release-local",
        "proof_date" => seed_stage.fetch("proof_date"),
        "source_closure" => {
          "path" => dependency_stage.fetch("proof_receipt"),
          "sha256" => dependency_stage.fetch("proof_receipt_sha256"),
          "source_archive_sha256" => closure.dig("source_tree", "source_sha256"),
          "source_commit" => source_package.upstream.fetch("source_commit")
        },
        "bootstrap_seed" => {
          "archive_sha256" => source_inputs.dig("bootstrap_seed", "sha256"),
          "binary_sha256" => source_inputs.dig("bootstrap_seed", "binary_sha256"),
          "size_bytes" => source_inputs.dig("bootstrap_seed", "binary_size_bytes"),
          "version" => version,
          "bootstrap_only" => true,
          "final_payload_allowed" => false,
          "final_runtime_dependency_allowed" => false
        },
        "inputs" => {
          "zig" => {
            "source_commit" => source_inputs.dig("zig", "commit"),
            "source_sha256" => source_inputs.dig("zig", "sha256"),
            "patch_sha256" => patch_sha256.call(source_inputs.fetch("zig"), "patch")
          },
          "webkit" => {
            "commit" => source_inputs.dig("webkit", "commit"),
            "archive_sha256" => source_inputs.dig("webkit", "sha256"),
            "patch_sha256" => patch_sha256.call(source_inputs.fetch("webkit"), "patch")
          },
          "source_patches" => {
            "system_lolhtml_sha256" => patch_sha256.call(provider, "patch"),
            "npm_lock_sha256" => patch_sha256.call(source_inputs.fetch("npm_lock"), "patch"),
            "zig_build_cwd_sha256" => patch_sha256.call(source_inputs.fetch("build_graph"), "patch"),
            "fedora_shared_cxx_runtime_sha256" => patch_sha256.call(source_inputs.fetch("build_graph"), "cxx_runtime_patch")
          },
          "npm_proof" => {
            "mode" => "historical_seed",
            "path" => dependency_stage.dig("historical_lolhtml_graph", "npm_install_proof_receipt"),
            "sha256" => dependency_stage.dig("historical_lolhtml_graph", "npm_install_proof_receipt_sha256"),
            "historical_seed_driven_install_only" => true
          },
          "offline_inputs" => {
            "native_archives" => 18,
            "node_header_archives" => 1,
            "npm_install_roots" => 3,
            "supplemental_npm_trees" => [{ "path" => "packages/@types/bun/node_modules", "tree" => { "sha256" => "a" * 64 } }],
            "cargo_source_archives" => 0,
            "system_lolhtml_provider" => provider.slice("package", "version", "c_api_version", "pkgconfig", "soname", "build_requirement").merge(
              "staged_payload" => {
                "root" => "/srv/tmp/agentlab-bun-lolhtml-provider/stage",
                "header" => { "path" => "usr/include/lol_html.h", "size_bytes" => 1, "sha256" => "b" * 64 },
                "pkgconfig_file" => { "path" => "usr/lib64/pkgconfig/lol-html.pc", "size_bytes" => 1, "sha256" => "c" * 64 },
                "shared_library" => { "path" => "usr/lib64/liblolhtml.so.1.4.0", "size_bytes" => 1, "sha256" => "d" * 64 },
                "critical_symbols_verified" => true
              }
            )
          }
        },
        "configure" => {
          "network_namespace" => true,
          "prepared_inputs_revalidated" => true,
          "bootstrap_seed_rule_scope_verified" => true,
          "bootstrap_seed_rules" => %w[codegen dep_build dep_cargo dep_cargo_cross dep_codegen dep_configure dep_fetch dep_fetch_prebuilt dep_prebuild dep_subst link regen smoke_test zig_build zig_check zig_fetch],
          "install_edges" => 3,
          "native_fetch_edges" => 18,
          "node_header_fetch_edges" => 1,
          "local_webkit_verified" => true,
          "zig_fetch_absent" => true,
          "zig_source_cwd_verified" => true,
          "fedora_shared_cxx_runtime_verified" => true,
          "system_lolhtml_provider_verified" => true,
          "unexpected_urls_absent" => true
        },
        "build" => {
          "network_namespace" => true,
          "bun_profile" => { "path" => "build/release-local/bun-profile", "size_bytes" => 200, "sha256" => "e" * 64 },
          "bun" => { "path" => "build/release-local/bun", "size_bytes" => 100, "sha256" => "f" * 64 },
          "linker_map" => { "path" => "build/release-local/bun-profile.linker-map", "size_bytes" => 50, "sha256" => "1" * 64 },
          "revision" => "#{version}-canary.1+#{source_package.upstream.fetch('source_commit')[0, 9]}",
          "version" => version,
          "smoke_verified" => true,
          "html_rewriter_smoke_verified" => true,
          "stripped_output_verified" => true,
          "fedora_shared_cxx_runtime_verified" => true,
          "system_lolhtml_provider_verified" => true,
          "shared_runtime_libraries" => %w[libgcc_s.so.1 libstdc++.so.6 liblolhtml.so.1]
        },
        "retained_relink_evidence" => { "complete_lgpl_relink_materials_verified" => false },
        "seed_contamination" => { "seed_hash_matches" => 0, "payload_absent_verified" => true, "runtime_dependency_absent_verified" => true },
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
      }
      receipt_path = File.join(directory, seed_stage.fetch("proof_receipt"))
      File.write(receipt_path, JSON.dump(receipt))
      seed_stage["proof_receipt_sha256"] = Digest::SHA256.file(receipt_path).hexdigest
      package = Agentlab::Package.new(directory: directory, manifest_path: "unused", data: data)
      spec = File.read(File.join(directory, "bun.spec"))

      assert_empty(Agentlab.validate_bun_build_plan(package, spec))

      relink_audit_path = File.join(directory, relink_audit_metadata.fetch("proof_receipt"))
      relink_audit = JSON.parse(File.read(relink_audit_path))
      relink_audit["schema"] = "bun-relink-materials-audit/v3"
      relink_audit["date"] = seed_stage.fetch("proof_date")
      relink_audit.fetch("final_link")["direct_archives"].reject! { |entry| entry.fetch("path").include?("/lolhtml/") }
      relink_audit.fetch("final_link")["direct_archive_count"] = 3
      relink_audit["source_build"] = {
        "proof_kind" => "first_build",
        "receipt" => seed_stage.fetch("proof_receipt"),
        "receipt_sha256" => seed_stage.fetch("proof_receipt_sha256"),
        "source_closure_sha256" => dependency_stage.fetch("proof_receipt_sha256")
      }
      relink_audit["system_lolhtml_provider"] = receipt.dig("inputs", "offline_inputs", "system_lolhtml_provider")
      File.write(relink_audit_path, JSON.dump(relink_audit))
      relink_audit_metadata.merge!(
        "proof_date" => seed_stage.fetch("proof_date"),
        "proof_receipt_sha256" => Digest::SHA256.file(relink_audit_path).hexdigest,
        "direct_archive_count" => 3
      )

      relink_kit_path = File.join(directory, relink_kit_metadata.fetch("proof_receipt"))
      relink_kit = JSON.parse(File.read(relink_kit_path))
      relink_kit["schema"] = "bun-relink-kit/v2"
      relink_kit["date"] = seed_stage.fetch("proof_date")
      relink_kit.fetch("source_audit").merge!(
        "schema" => relink_audit.fetch("schema"),
        "sha256" => relink_audit_metadata.fetch("proof_receipt_sha256")
      )
      relink_kit.dig("kit", "payload_summary")["archive_count"] = 3
      relink_kit.dig("kit", "payload_summary")["response_file_input_count"] = relink_audit_metadata.fetch("direct_object_count") + 3
      relink_kit.fetch("validation")["system_lolhtml_provider_verified"] = true
      relink_kit.fetch("validation")["html_rewriter_smoke_verified"] = true
      relink_kit.fetch("link_validation").merge!(
        "html_rewriter_smoke_verified" => true,
        "system_lolhtml_provider_verified" => true,
        "shared_runtime_libraries" => %w[libgcc_s.so.1 libstdc++.so.6 liblolhtml.so.1]
      )
      File.write(relink_kit_path, JSON.dump(relink_kit))
      relink_kit_metadata.merge!(
        "historical_only" => false,
        "proof_date" => seed_stage.fetch("proof_date"),
        "proof_receipt_sha256" => Digest::SHA256.file(relink_kit_path).hexdigest
      )
      seed_stage["relink_materials_audit"] = relink_audit_metadata
      seed_stage["relink_kit"] = relink_kit_metadata

      assert_empty(Agentlab.validate_bun_build_plan(package, spec))

      relink_kit.fetch("validation")["html_rewriter_smoke_verified"] = false
      File.write(relink_kit_path, JSON.dump(relink_kit))
      relink_kit_metadata["proof_receipt_sha256"] = Digest::SHA256.file(relink_kit_path).hexdigest
      errors = Agentlab.validate_bun_build_plan(package, spec)
      assert_includes(errors, "bun: relink-kit proof validation is incomplete")
      relink_kit.fetch("validation")["html_rewriter_smoke_verified"] = true
      File.write(relink_kit_path, JSON.dump(relink_kit))
      relink_kit_metadata["proof_receipt_sha256"] = Digest::SHA256.file(relink_kit_path).hexdigest

      receipt.dig("inputs", "npm_proof")["mode"] = "source_built"
      File.write(receipt_path, JSON.dump(receipt))
      seed_stage["proof_receipt_sha256"] = Digest::SHA256.file(receipt_path).hexdigest
      errors = Agentlab.validate_bun_build_plan(package, spec)
      assert_includes(errors, "bun: current seed-build historical npm input mismatch")
      receipt.dig("inputs", "npm_proof")["mode"] = "historical_seed"

      receipt.fetch("build")["html_rewriter_smoke_verified"] = false
      File.write(receipt_path, JSON.dump(receipt))
      seed_stage["proof_receipt_sha256"] = Digest::SHA256.file(receipt_path).hexdigest
      errors = Agentlab.validate_bun_build_plan(package, spec)
      assert_includes(errors, "bun: current seed-build runtime validation is incomplete")
      receipt.fetch("build")["html_rewriter_smoke_verified"] = true

      receipt.fetch("configure")["system_lolhtml_provider_verified"] = false
      File.write(receipt_path, JSON.dump(receipt))
      seed_stage["proof_receipt_sha256"] = Digest::SHA256.file(receipt_path).hexdigest
      errors = Agentlab.validate_bun_build_plan(package, spec)
      assert_includes(errors, "bun: current seed-build proof graph checks are incomplete")
    end
  end

  def test_validates_current_bun_self_rebuild_npm_input
    source_package = Agentlab.package_named("bun")
    Dir.mktmpdir do |directory|
      data = Marshal.load(Marshal.dump(source_package.data))
      version = source_package.upstream.fetch("current_version").to_s
      stages = data.dig("build_plan", "stages")
      dependency_stage = stages.fetch("dependency_closure")
      seed_stage = stages.fetch("seed_build")
      seed_stage.merge!("state" => "verified", "historical_only" => false, "proof_receipt" => "driver.json")

      driver_receipt = {
        "schema" => "bun-first-source-build-proof/v2",
        "package" => "bun",
        "release" => version,
        "profile" => "release-local",
        "source_closure" => {
          "path" => dependency_stage.fetch("proof_receipt"),
          "sha256" => dependency_stage.fetch("proof_receipt_sha256")
        },
        "build" => { "bun" => { "path" => "build/release-local/bun", "size_bytes" => 100, "sha256" => "a" * 64 } }
      }
      driver_path = File.join(directory, seed_stage.fetch("proof_receipt"))
      File.write(driver_path, JSON.dump(driver_receipt))
      seed_stage["proof_receipt_sha256"] = Digest::SHA256.file(driver_path).hexdigest
      driver = {
        "driver_proof_kind" => "first_build",
        "driver_receipt" => seed_stage.fetch("proof_receipt"),
        "driver_receipt_sha256" => seed_stage.fetch("proof_receipt_sha256")
      }

      staging = data.dig("build_plan", "source_inputs", "release_local_staging")
      seed = data.dig("build_plan", "source_inputs", "bootstrap_seed")
      npm_receipt = {
        "schema" => "bun-npm-offline-install-proof/v2",
        "package" => "bun",
        "release" => version,
        "target" => { "os" => "linux", "cpu" => "x64", "libc" => "glibc" },
        "source_closure" => {
          "path" => dependency_stage.fetch("proof_receipt"),
          "sha256" => dependency_stage.fetch("proof_receipt_sha256"),
          "bun_source_archive_sha256" => source_package.upstream.fetch("source_sha256")
        },
        "driver" => {
          "kind" => "source_built",
          "proof_kind" => driver.fetch("driver_proof_kind"),
          "receipt" => driver.fetch("driver_receipt"),
          "receipt_sha256" => driver.fetch("driver_receipt_sha256"),
          "proof_root" => "/srv/tmp/agentlab-bun-first-source-build-proof",
          "path" => "/srv/tmp/agentlab-bun-first-source-build-proof/build/release-local/bun",
          "version" => version,
          "size_bytes" => 100,
          "sha256" => "a" * 64
        },
        "forbidden_bootstrap_seed" => {
          "binary_sha256" => seed.fetch("binary_sha256"),
          "size_bytes" => seed.fetch("binary_size_bytes"),
          "payload_allowed" => false,
          "runtime_dependency_allowed" => false
        },
        "cache" => {
          "source_archives" => dependency_stage.fetch("unique_npm_source_archives"),
          "materialized_entries" => dependency_stage.fetch("unique_npm_source_archives"),
          "registry_archives" => dependency_stage.fetch("unique_npm_source_archives"),
          "github_archives" => 0,
          "tree" => { "sha256" => staging.fetch("npm_cache_tree_sha256") }
        },
        "install" => {
          "driver_kind" => "source_built",
          "network_namespace" => true,
          "frozen_lockfile" => true,
          "ignore_scripts" => true,
          "serialized" => true,
          "install_roots" => [[".", "bun"], ["packages/bun-error", "bun-error"], ["src/node-fallbacks", "fallbacks"]].map do |path, name|
            { "path" => path, "package_name" => name, "node_modules" => { "entries" => 1, "files" => 1, "sha256" => "b" * 64 } }
          end
        },
        "validation" => {
          "source_files_unchanged" => true,
          "seed_absent_from_node_modules" => true,
          "npm_cache_materialization_verified" => true,
          "npm_offline_install_verified" => true,
          "source_built_driver_verified" => true,
          "driver_receipt_bound" => true,
          "driver_version_verified" => true,
          "bootstrap_seed_not_used_for_install" => true,
          "complete_bun_offline_materialization_verified" => false,
          "dependency_resolution_performed" => false,
          "full_bun_build_performed" => false
        }
      }
      npm_path = File.join(directory, "source-built-npm-install-proof.json")
      File.write(npm_path, JSON.dump(npm_receipt))
      self_receipt = {
        "inputs" => {
          "npm_proof" => {
            "mode" => "source_built",
            "path" => File.basename(npm_path),
            "sha256" => Digest::SHA256.file(npm_path).hexdigest
          }
        }
      }
      package = Agentlab::Package.new(directory: directory, manifest_path: "unused", data: data)

      assert_empty(Agentlab.validate_bun_current_self_npm_proof(package, dependency_stage, self_receipt, driver, version))

      prior_receipt = driver_receipt.merge(
        "schema" => "bun-self-rebuild-proof/v2",
        "validation" => { "self_rebuild_performed" => true }
      )
      prior_path = File.join(directory, "prior-self-rebuild-proof.json")
      File.write(prior_path, JSON.dump(prior_receipt))
      driver.merge!(
        "driver_proof_kind" => "self_rebuild",
        "driver_receipt" => File.basename(prior_path),
        "driver_receipt_sha256" => Digest::SHA256.file(prior_path).hexdigest
      )
      npm_receipt.fetch("driver").merge!(
        "proof_kind" => driver.fetch("driver_proof_kind"),
        "receipt" => driver.fetch("driver_receipt"),
        "receipt_sha256" => driver.fetch("driver_receipt_sha256"),
        "proof_root" => "/srv/tmp/agentlab-bun-prior-self-build",
        "path" => "/srv/tmp/agentlab-bun-prior-self-build/build/release-local/bun"
      )
      File.write(npm_path, JSON.dump(npm_receipt))
      self_receipt.dig("inputs", "npm_proof")["sha256"] = Digest::SHA256.file(npm_path).hexdigest
      assert_empty(Agentlab.validate_bun_current_self_npm_proof(package, dependency_stage, self_receipt, driver, version))

      npm_receipt.fetch("driver")["receipt_sha256"] = "0" * 64
      File.write(npm_path, JSON.dump(npm_receipt))
      self_receipt.dig("inputs", "npm_proof")["sha256"] = Digest::SHA256.file(npm_path).hexdigest
      errors = Agentlab.validate_bun_current_self_npm_proof(package, dependency_stage, self_receipt, driver, version)
      assert_includes(errors, "bun: current self-rebuild npm proof driver mismatch")
    end
  end

  def test_validates_bun_dependency_closure_local_source_state
    Dir.mktmpdir do |directory|
      receipt_path = File.join(directory, "source-closure.json")
      receipt = {
        "schema" => "bun-release-local-source-closure/v3",
        "package" => "bun",
        "release" => "1.3.14",
        "native_github_sources" => [{ "name" => "fixture" }],
        "node_headers" => { "name" => "node" },
        "npm" => { "source_archives" => [{ "name" => "npm" }] },
        "existing_local_sources" => [
          { "symbol" => "webkit", "immutable_public_url" => nil }
        ],
        "validation" => {
          "immutable_public_hosting_verified" => false,
          "system_lolhtml_provider_selected" => true,
          "private_lolhtml_source_excluded" => true
        }
      }
      dependency_stage = {
        "proof_receipt" => File.basename(receipt_path),
        "selected_github_archives" => 1,
        "selected_node_header_archives" => 1,
        "unique_npm_source_archives" => 1,
        "selected_cargo_source_archives" => 0
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

      receipt["schema"] = "bun-release-local-source-closure/v3"
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
      receipt["cargo"] = { "crate_sources" => [] }
      write_receipt.call
      errors = Agentlab.validate_bun_dependency_closure(package, dependency_stage, webkit, "1.3.14")
      assert_includes(errors, "bun: dependency-closure proof retains a private Cargo graph")

      receipt.delete("cargo")
      receipt.fetch("validation")["immutable_public_hosting_verified"] = false
      receipt.fetch("existing_local_sources").first["immutable_public_url"] = "https://sources.example.invalid/WebKit.tar.gz"
      write_receipt.call
      errors = Agentlab.validate_bun_dependency_closure(package, dependency_stage, webkit, "1.3.14")
      assert_includes(errors, "bun: dependency-closure proof hosted local-source record")
    end
  end

  def test_validates_bun_aarch64_preflight
    source_package = Agentlab.package_named("bun")
    data = Marshal.load(Marshal.dump(source_package.data))
    package = Agentlab::Package.new(directory: source_package.directory, manifest_path: source_package.manifest_path, data: data)
    source_inputs = data.dig("build_plan", "source_inputs")
    preflight = source_inputs.fetch("aarch64_preflight")
    npm_lock = source_inputs.fetch("npm_lock")
    spec = File.read(File.join(source_package.directory, "bun.spec"))

    assert_empty(Agentlab.validate_bun_aarch64_preflight(package, preflight, npm_lock, "1.3.14", spec))

    preflight.fetch("source_closure")["sha256"] = "0" * 64
    errors = Agentlab.validate_bun_aarch64_preflight(package, preflight, npm_lock, "1.3.14", spec)
    assert_includes(errors, "bun: aarch64 source closure is missing or has wrong SHA-256")
    preflight.fetch("source_closure")["sha256"] = "d62881f573199d9e98cf0a5599c12d8bb54cbea79d3b20fe841fe35f993b3f5a"

    preflight.fetch("target")["cpu"] = "x64"
    errors = Agentlab.validate_bun_aarch64_preflight(package, preflight, npm_lock, "1.3.14", spec)
    assert_includes(errors, "bun: aarch64 preflight target mismatch")
    preflight.fetch("target")["cpu"] = "arm64"

    preflight.fetch("zig_source_bootstrap")["receipt_sha256"] = "0" * 64
    errors = Agentlab.validate_bun_aarch64_preflight(package, preflight, npm_lock, "1.3.14", spec)
    assert_includes(errors, "bun: aarch64 Zig proof is missing or has wrong SHA-256")
    preflight.fetch("zig_source_bootstrap")["receipt_sha256"] = "c045c2d6eb2bc5079bb48697dca3a4f8db57c22ba361998b591d4330e5d97e1e"

    preflight.dig("zig_source_bootstrap", "emulation")["guest_stack_size_bytes"] = 8_388_608
    errors = Agentlab.validate_bun_aarch64_preflight(package, preflight, npm_lock, "1.3.14", spec)
    assert_includes(errors, "bun: aarch64 Zig proof emulation mismatch")
    preflight.dig("zig_source_bootstrap", "emulation")["guest_stack_size_bytes"] = 67_108_864

    preflight.fetch("webkit_source_build")["receipt_sha256"] = "0" * 64
    errors = Agentlab.validate_bun_aarch64_preflight(package, preflight, npm_lock, "1.3.14", spec)
    assert_includes(errors, "bun: aarch64 WebKit proof is missing or has wrong SHA-256")
    preflight.fetch("webkit_source_build")["receipt_sha256"] = "ba05b7789d31035472c3bc09567c02b3d052a2867c53c44a6baf980d31f77987"

    preflight.dig("webkit_source_build", "toolchain")["cpu"] = "haswell"
    errors = Agentlab.validate_bun_aarch64_preflight(package, preflight, npm_lock, "1.3.14", spec)
    assert_includes(errors, "bun: aarch64 WebKit proof toolchain mismatch")
    preflight.dig("webkit_source_build", "toolchain")["cpu"] = "fedora-default"

    preflight.fetch("npm_offline_install")["receipt_sha256"] = "0" * 64
    errors = Agentlab.validate_bun_aarch64_preflight(package, preflight, npm_lock, "1.3.14", spec)
    assert_includes(errors, "bun: aarch64 npm proof is missing or has wrong SHA-256")

    missing_data = Marshal.load(Marshal.dump(source_package.data))
    missing_data.dig("build_plan", "source_inputs").delete("aarch64_preflight")
    missing_package = Agentlab::Package.new(directory: source_package.directory, manifest_path: source_package.manifest_path, data: missing_data)
    assert_includes(Agentlab.validate_bun_build_plan(missing_package, spec), "bun: aarch64 preflight metadata is missing")
  end

  def test_validates_bun_npm_offline_install_receipt
    source_package = Agentlab.package_named("bun")
    source_stage = source_package.data.fetch("build_plan").fetch("stages").fetch("dependency_closure")
    assert_empty(Agentlab.validate_bun_npm_offline_install(source_package, source_stage, "1.3.14"))

    Dir.mktmpdir do |directory|
      history = source_stage.fetch("historical_lolhtml_graph")
      receipt = JSON.parse(File.read(File.join(source_package.directory, history.fetch("npm_install_proof_receipt"))))
      receipt_path = File.join(directory, "npm-offline-install-proof.json")
      dependency_stage = Marshal.load(Marshal.dump(source_stage))
      dependency_stage.merge!(
        "proof_receipt" => "bun-1.3.14-release-local-source-closure.json",
        "proof_receipt_sha256" => history.fetch("proof_receipt_sha256"),
        "unique_npm_source_archives" => 236,
        "npm_cache_entries" => 236,
        "npm_cache_tree_sha256" => "50e66a5b8361735b2598a6be5d7d78f973db05104cbdf9b9addb01e9a113d214",
        "npm_cache_materialization_verified" => true,
        "npm_offline_install_verified" => true,
        "npm_frozen_lockfile_verified" => true,
        "npm_ignore_scripts_verified" => true,
        "npm_network_namespace_verified" => true
      )
      dependency_stage["npm_install_proof_receipt"] = File.basename(receipt_path)
      package = Agentlab::Package.new(
        directory: directory,
        manifest_path: "unused",
        data: {
          "name" => "bun",
          "status" => "blocked",
          "blockers" => ["The final package is incomplete."],
          "upstream" => {
            "current_version" => "1.3.14",
            "source_sha256" => source_package.upstream.fetch("source_sha256")
          },
          "copr" => { "enabled" => false }
        }
      )
      write_receipt = lambda do
        File.write(receipt_path, JSON.dump(receipt))
        dependency_stage["npm_install_proof_receipt_sha256"] = Digest::SHA256.file(receipt_path).hexdigest
      end
      write_receipt.call
      assert_empty(Agentlab.validate_bun_npm_offline_install(package, dependency_stage, "1.3.14"))

      receipt["schema"] = "bun-npm-offline-install-proof/v0"
      write_receipt.call
      errors = Agentlab.validate_bun_npm_offline_install(package, dependency_stage, "1.3.14")
      assert_includes(errors, "bun: unsupported npm-install proof receipt schema")

      receipt["schema"] = "bun-npm-offline-install-proof/v1"
      receipt.fetch("source_closure")["sha256"] = "0" * 64
      write_receipt.call
      errors = Agentlab.validate_bun_npm_offline_install(package, dependency_stage, "1.3.14")
      assert_includes(errors, "bun: npm-install proof source-closure SHA-256 mismatch")

      receipt.fetch("source_closure")["sha256"] = dependency_stage.fetch("proof_receipt_sha256")
      receipt.fetch("validation")["complete_bun_offline_materialization_verified"] = true
      write_receipt.call
      errors = Agentlab.validate_bun_npm_offline_install(package, dependency_stage, "1.3.14")
      assert_includes(errors, "bun: npm-install proof overclaims complete Bun materialization")

      receipt.fetch("validation")["complete_bun_offline_materialization_verified"] = false
      dependency_stage["npm_offline_install_verified"] = false
      write_receipt.call
      errors = Agentlab.validate_bun_npm_offline_install(package, dependency_stage, "1.3.14")
      assert_includes(errors, "bun: npm-install stage metadata is incomplete")
    end
  end

  def test_validates_bun_source_built_npm_offline_install_receipt
    source_package = Agentlab.package_named("bun")
    Dir.mktmpdir do |directory|
      data = Marshal.load(Marshal.dump(source_package.data))
      version = source_package.upstream.fetch("current_version")
      dependency_stage = data.dig("build_plan", "stages", "dependency_closure")
      seed_stage = data.dig("build_plan", "stages", "seed_build")
      source_inputs = data.dig("build_plan", "source_inputs")
      closure_name = dependency_stage.fetch("proof_receipt")
      FileUtils.cp(File.join(source_package.directory, closure_name), File.join(directory, closure_name))

      historical_name = dependency_stage.dig("historical_lolhtml_graph", "npm_install_proof_receipt")
      receipt = JSON.parse(File.read(File.join(source_package.directory, historical_name)))
      receipt["schema"] = "bun-npm-offline-install-proof/v2"
      receipt.fetch("source_closure").merge!(
        "path" => closure_name,
        "sha256" => dependency_stage.fetch("proof_receipt_sha256"),
        "bun_source_archive_sha256" => source_package.upstream.fetch("source_sha256")
      )
      receipt.fetch("install")["driver_kind"] = "source_built"
      receipt.fetch("validation").merge!(
        "source_built_driver_verified" => true,
        "driver_receipt_bound" => true,
        "driver_version_verified" => true,
        "bootstrap_seed_not_used_for_install" => true
      )

      driver_receipt_name = "current-first-source-build-proof.json"
      driver_output = {
        "path" => "build/release-local/bun",
        "size_bytes" => 100,
        "sha256" => "a" * 64
      }
      driver_receipt = {
        "schema" => "bun-first-source-build-proof/v2",
        "package" => "bun",
        "release" => version,
        "profile" => "release-local",
        "source_closure" => {
          "path" => closure_name,
          "sha256" => dependency_stage.fetch("proof_receipt_sha256")
        },
        "bootstrap_seed" => {
          "binary_sha256" => source_inputs.dig("bootstrap_seed", "binary_sha256"),
          "size_bytes" => source_inputs.dig("bootstrap_seed", "binary_size_bytes")
        },
        "build" => { "bun" => driver_output, "version" => version },
        "validation" => { "source_build_verified" => true }
      }
      driver_receipt_path = File.join(directory, driver_receipt_name)
      File.write(driver_receipt_path, JSON.dump(driver_receipt))
      driver_receipt_sha256 = Digest::SHA256.file(driver_receipt_path).hexdigest
      seed_stage.merge!(
        "state" => "verified",
        "historical_only" => false,
        "proof_receipt" => driver_receipt_name,
        "proof_receipt_sha256" => driver_receipt_sha256
      )
      receipt["driver"] = {
        "kind" => "source_built",
        "proof_kind" => "first_build",
        "receipt" => driver_receipt_name,
        "receipt_sha256" => driver_receipt_sha256,
        "proof_root" => "/srv/tmp/agentlab-bun-first-source-build-proof",
        "path" => "/srv/tmp/agentlab-bun-first-source-build-proof/#{driver_output.fetch('path')}",
        "size_bytes" => driver_output.fetch("size_bytes"),
        "sha256" => driver_output.fetch("sha256"),
        "version" => version
      }
      receipt["forbidden_bootstrap_seed"] = {
        "binary_sha256" => source_inputs.dig("bootstrap_seed", "binary_sha256"),
        "size_bytes" => source_inputs.dig("bootstrap_seed", "binary_size_bytes"),
        "payload_allowed" => false,
        "runtime_dependency_allowed" => false
      }

      proof_name = "source-built-npm-install-proof.json"
      proof_path = File.join(directory, proof_name)
      write_receipt = lambda do
        File.write(proof_path, JSON.dump(receipt))
        dependency_stage["npm_install_proof_receipt"] = proof_name
        dependency_stage["npm_install_proof_receipt_sha256"] = Digest::SHA256.file(proof_path).hexdigest
      end
      dependency_stage.merge!(
        "npm_cache_entries" => receipt.dig("cache", "materialized_entries"),
        "npm_cache_tree_sha256" => receipt.dig("cache", "tree", "sha256"),
        "npm_cache_materialization_verified" => true,
        "npm_offline_install_verified" => true,
        "npm_frozen_lockfile_verified" => true,
        "npm_ignore_scripts_verified" => true,
        "npm_network_namespace_verified" => true
      )
      write_receipt.call
      package = Agentlab::Package.new(directory: directory, manifest_path: "unused", data: data)

      assert_empty(Agentlab.validate_bun_npm_offline_install(package, dependency_stage, version))

      receipt.fetch("validation")["driver_receipt_bound"] = false
      write_receipt.call
      errors = Agentlab.validate_bun_npm_offline_install(package, dependency_stage, version)
      assert_includes(errors, "bun: current npm-install proof validation is incomplete")

      receipt.fetch("validation")["driver_receipt_bound"] = true
      receipt.fetch("forbidden_bootstrap_seed")["binary_sha256"] = "0" * 64
      write_receipt.call
      errors = Agentlab.validate_bun_npm_offline_install(package, dependency_stage, version)
      assert_includes(errors, "bun: current npm-install forbidden seed mismatch")
    end
  end

  def test_validates_bun_system_lolhtml_split
    source_package = Agentlab.package_named("bun")
    plan = source_package.data.fetch("build_plan")
    lolhtml = plan.fetch("source_inputs").fetch("lolhtml")
    stages = plan.fetch("stages")
    spec = File.read(File.join(source_package.directory, "bun.spec"))
    provider = Agentlab.package_named("lol-html")
    current_validation = provider.data.dig("build_validation", "current")
    historical_validation = provider.data.dig("build_validation", "historical")

    assert_equal("3.0.0", lolhtml.fetch("version"))
    assert_equal("3.0.1", provider.upstream.fetch("current_version"))
    assert_equal("3.0.1", current_validation.fetch("provider_version"))
    assert_equal("current_provider_pending", current_validation.fetch("evidence_role"))
    assert(current_validation.except("provider_version", "release", "evidence_role", "mock_matrix").values.all? { |value| value == false })
    assert_equal(["pending"], current_validation.fetch("mock_matrix").values.uniq)
    assert_equal("3.0.0", historical_validation.fetch("provider_version"))
    assert_equal("3.0.0-0.9", historical_validation.fetch("provider_release"))
    assert_equal("immutable_historical_provider_proof", historical_validation.fetch("evidence_role"))
    final_license_path = File.join(source_package.directory, "bun-1.3.14-final-linked-license-closure.json")
    final_license = JSON.parse(File.read(final_license_path))
    historical_input = final_license.dig("inputs", "lolhtml_package")
    snapshot = historical_validation.fetch("manifest_snapshot")
    snapshot_path = File.join(Agentlab::ROOT, snapshot.fetch("path"))
    assert_equal(historical_input.fetch("path"), snapshot.fetch("source_path"))
    assert_equal(historical_input.fetch("size_bytes"), File.size(snapshot_path))
    assert_equal(historical_input.fetch("sha256"), Digest::SHA256.file(snapshot_path).hexdigest)
    assert(Agentlab.valid_bun_lolhtml_historical_manifest_snapshot?(final_license, provider.data))

    live_input = Marshal.load(Marshal.dump(final_license))
    live_manifest_path = File.join(provider.directory, "package.yml")
    live_input.dig("inputs", "lolhtml_package")["size_bytes"] = File.size(live_manifest_path)
    live_input.dig("inputs", "lolhtml_package")["sha256"] = Digest::SHA256.file(live_manifest_path).hexdigest
    refute(Agentlab.valid_bun_lolhtml_historical_manifest_snapshot?(live_input, provider.data))
    assert_empty(Agentlab.validate_bun_system_lolhtml(source_package, lolhtml, stages, "1.3.14", spec))

    relabeled_data = Marshal.load(Marshal.dump(provider.data))
    relabeled_data.fetch("build_validation")["current"] = Marshal.load(Marshal.dump(historical_validation))
    relabeled_provider = Agentlab::Package.new(
      directory: provider.directory,
      manifest_path: "unused",
      data: relabeled_data
    )
    refute(Agentlab.valid_bun_lolhtml_provider_evidence_boundary?(relabeled_provider, lolhtml))

    invalid_lolhtml = Marshal.load(Marshal.dump(lolhtml))
    invalid_lolhtml["provider_matrix_verified"] = false
    assert_includes(
      Agentlab.validate_bun_system_lolhtml(source_package, invalid_lolhtml, stages, "1.3.14", spec),
      "bun: system lol-html provider metadata mismatch"
    )
    assert_includes(
      Agentlab.validate_bun_system_lolhtml(source_package, lolhtml, stages, "1.3.14", "#{spec}\n%cargo_build\n"),
      "bun: spec still builds the historical private lol-html library"
    )
    invalid_data = Marshal.load(Marshal.dump(source_package.data))
    invalid_data.dig("build_plan", "source_inputs", "source_license_inventory")["system_lolhtml_provider_external"] = false
    invalid_package = Agentlab::Package.new(
      directory: source_package.directory,
      manifest_path: "unused",
      data: invalid_data
    )
    assert_includes(
      Agentlab.validate_bun_system_lolhtml(
        invalid_package,
        invalid_data.dig("build_plan", "source_inputs", "lolhtml"),
        invalid_data.dig("build_plan", "stages"),
        "1.3.14",
        spec
      ),
      "bun: system lol-html source-license boundary mismatch"
    )

    Dir.mktmpdir do |directory|
      data = Marshal.load(Marshal.dump(source_package.data))
      patch_name = lolhtml.fetch("patch")
      patch = File.read(File.join(source_package.directory, patch_name)).sub(
        'process.platform === "linux" && familySync() !== "musl"',
        'process.platform === "linux"'
      )
      patch_path = File.join(directory, patch_name)
      File.write(patch_path, patch)
      data.fetch("build_plan").fetch("source_inputs").fetch("lolhtml")["patch_sha256"] = Digest::SHA256.file(patch_path).hexdigest
      package = Agentlab::Package.new(
        directory: directory,
        manifest_path: "unused",
        data: data
      )
      errors = Agentlab.validate_bun_system_lolhtml(
        package,
        data.fetch("build_plan").fetch("source_inputs").fetch("lolhtml"),
        data.fetch("build_plan").fetch("stages"),
        "1.3.14",
        spec
      )
      assert_includes(errors, "bun: system lol-html patch contract is incomplete")
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

    invalid_stage = stages.fetch("source_delivery").merge("state" => "verified", "proof_receipt_sha256" => "0" * 64)
    assert_equal(
      ["bun: source-delivery proof receipt is missing or has wrong SHA-256"],
      Agentlab.validate_bun_source_delivery(package, invalid_stage, stages.fetch("dependency_closure"), "1.3.14", spec)
    )

    data = Marshal.load(Marshal.dump(package.data))
    data.dig("build_plan", "source_inputs", "release_local_staging", "npm_union")["member_count"] = 238
    invalid_package = Agentlab::Package.new(directory: package.directory, manifest_path: "unused", data: data)
    errors = Agentlab.validate_bun_source_delivery(invalid_package, data.dig("build_plan", "stages", "source_delivery"), data.dig("build_plan", "stages", "dependency_closure"), "1.3.14", spec)
    assert_includes(errors, "bun: source-delivery npm union mismatch")
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
    assert_empty(
      Agentlab.validate_bun_lolhtml_rpm_cargo(
        package,
        invalid_stage,
        stages.fetch("dependency_closure"),
        plan.fetch("source_inputs").fetch("lolhtml"),
        "1.3.14",
        spec
      )
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

    invalid_stage = stages.fetch("dependency_staging").merge("state" => "verified", "proof_receipt_sha256" => "0" * 64)
    assert_equal(
      ["bun: dependency-staging proof receipt is missing or has wrong SHA-256"],
      Agentlab.validate_bun_dependency_staging(
        package,
        invalid_stage,
        stages.fetch("source_delivery"),
        stages.fetch("dependency_closure"),
        plan.fetch("source_inputs").fetch("release_local_staging"),
        "1.3.14",
        spec
      )
    )

    staging = Marshal.load(Marshal.dump(plan.fetch("source_inputs").fetch("release_local_staging")))
    staging.fetch("npm_union")["member_count"] = 238
    errors = Agentlab.validate_bun_dependency_staging(package, stages.fetch("dependency_staging"), stages.fetch("source_delivery"), stages.fetch("dependency_closure"), staging, "1.3.14", spec)
    assert_includes(errors, "bun: dependency-staging npm union mismatch")
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
        spec.sub("Source25:", "Removed25:")
      ),
      "bun: spec does not integrate the source-license inventory"
    )
    assert_includes(
      Agentlab.validate_bun_source_license_inventory(
        package,
        inventory,
        plan.fetch("stages").fetch("dependency_closure"),
        "1.3.14",
        spec.sub("--rpm-release 0.0.37", "--rpm-release 0.0.36")
      ),
      "bun: spec does not integrate the source-license inventory"
    )
    assert_includes(
      Agentlab.validate_bun_source_license_inventory(
        package,
        inventory,
        plan.fetch("stages").fetch("dependency_closure"),
        "1.3.14",
        spec.sub("--date 2026-07-28", "--date 2026-07-27")
      ),
      "bun: spec does not integrate the source-license inventory"
    )

    Dir.mktmpdir do |directory|
      data = Marshal.load(Marshal.dump(package.data))
      copied_inventory = data.fetch("build_plan").fetch("source_inputs").fetch("source_license_inventory")
      receipt_path = File.join(directory, copied_inventory.fetch("source"))
      FileUtils.cp(File.join(package.directory, copied_inventory.fetch("source")), receipt_path)
      closure_name = data.fetch("build_plan").fetch("stages").fetch("dependency_closure").fetch("proof_receipt")
      FileUtils.cp(File.join(package.directory, closure_name), File.join(directory, closure_name))
      mutated = JSON.parse(File.read(receipt_path))
      mutated.fetch("validation")["final_license_expression_verified"] = true
      mutated.fetch("webkit").fetch("candidate_license_files").first["path"] = "../escape"
      mutated.fetch("native").first["source_identity"] = "wrong-native-source"
      mutated.fetch("npm").fetch("records").first["version"] = "0.0.0"
      constants = mutated.fetch("npm").fetch("records").find { |record| record["name"] == "constants-browserify" }
      constants.fetch("license_text_resolution")["repository_license_sha256"] = "0" * 64
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
      assert_includes(errors, "bun: source-license native identities do not match the source closure")
      assert_includes(errors, "bun: source-license npm identities do not match the source closure")
      assert_includes(errors, "bun: source-license constants-browserify license text resolution mismatch")
    end
  end

  def test_validates_bun_final_linked_license_closure
    package = Agentlab.package_named("bun")
    plan = package.data.fetch("build_plan")
    metadata = plan.fetch("source_inputs").fetch("final_linked_license_closure")
    source_inventory = plan.fetch("source_inputs").fetch("source_license_inventory")
    spec = File.read(File.join(package.directory, "bun.spec"))

    assert_empty(
      Agentlab.validate_bun_final_linked_license_closure(
        package, metadata, source_inventory, plan.fetch("stages"), plan.fetch("source_inputs").fetch("lolhtml"), "1.3.14", spec
      )
    )
    assert_includes(
      Agentlab.validate_bun_final_linked_license_closure(
        package, metadata.merge("sha256" => "0" * 64), source_inventory, plan.fetch("stages"), plan.fetch("source_inputs").fetch("lolhtml"), "1.3.14", spec
      ),
      "bun: final linked-license closure is missing or has wrong SHA-256"
    )
    assert_includes(
      Agentlab.validate_bun_final_linked_license_closure(
        package, metadata, source_inventory, plan.fetch("stages"), plan.fetch("source_inputs").fetch("lolhtml"), "1.3.14", spec.sub("Source27:", "Removed27:")
      ),
      "bun: spec does not integrate the final linked-license closure"
    )

    Dir.mktmpdir do |directory|
      data = Marshal.load(Marshal.dump(package.data))
      copied_metadata = data.dig("build_plan", "source_inputs", "final_linked_license_closure")
      %w[
        bun-1.3.14-final-linked-license-closure.json bun-1.3.14-source-license-inventory.json
        self-rebuild-proof.json relink-materials-proof.json relink-kit-proof.json
      ].each do |name|
        FileUtils.cp(File.join(package.directory, name), File.join(directory, name))
      end
      receipt_path = File.join(directory, copied_metadata.fetch("source"))
      receipt = JSON.parse(File.read(receipt_path))
      receipt.fetch("components").first["linked_input_count"] -= 1
      receipt.fetch("validation")["final_license_expression_verified"] = true
      receipt.fetch("webkit")["archive_member_count"] -= 1
      receipt.fetch("validation")["webkit_member_source_mapping_verified"] = false
      receipt.dig("webkit", "transitive_dependencies")["unique_dependency_count"] -= 1
      receipt.fetch("validation")["webkit_transitive_dependency_mapping_verified"] = false
      receipt.dig("unresolved", "native_license_selections") << "libarchive"
      receipt.dig("unresolved", "native_license_details") << { "name" => "drifted" }
      File.write(receipt_path, JSON.pretty_generate(receipt) + "\n")
      copied_metadata["sha256"] = Digest::SHA256.file(receipt_path).hexdigest
      copied_package = Agentlab::Package.new(directory: directory, manifest_path: "unused", data: data)

      errors = Agentlab.validate_bun_final_linked_license_closure(
        copied_package,
        copied_metadata,
        data.dig("build_plan", "source_inputs", "source_license_inventory"),
        data.dig("build_plan", "stages"),
        data.dig("build_plan", "source_inputs", "lolhtml"),
        "1.3.14",
        spec
      )
      assert_includes(errors, "bun: final linked-license component counts mismatch")
      assert_includes(errors, "bun: final linked-license unresolved native details mismatch")
      assert_includes(errors, "bun: final linked-license WebKit mapping totals mismatch")
      assert_includes(errors, "bun: final linked-license WebKit transitive counts mismatch")
      assert_includes(errors, "bun: final linked-license mapping validation is incomplete")
      assert_includes(errors, "bun: final linked-license closure overclaims completion")
    end
  end

  def test_validates_bun_npm_code_generation_closure
    package = Agentlab.package_named("bun")
    plan = package.data.fetch("build_plan")
    metadata = plan.fetch("source_inputs").fetch("npm_code_generation_closure")
    source_inventory = plan.fetch("source_inputs").fetch("source_license_inventory")
    spec = File.read(File.join(package.directory, "bun.spec"))

    assert_empty(
      Agentlab.validate_bun_npm_code_generation_closure(
        package, metadata, source_inventory, plan.fetch("stages"), "1.3.14", spec
      )
    )
    assert_includes(
      Agentlab.validate_bun_npm_code_generation_closure(
        package, metadata.merge("sha256" => "0" * 64), source_inventory, plan.fetch("stages"), "1.3.14", spec
      ),
      "bun: npm code-generation closure is missing or has wrong SHA-256"
    )

    Dir.mktmpdir do |directory|
      data = Marshal.load(Marshal.dump(package.data))
      copied_metadata = data.dig("build_plan", "source_inputs", "npm_code_generation_closure")
      %w[
        bun-1.3.14-npm-code-generation-closure.json bun-1.3.14-source-license-inventory.json
        source-built-npm-install-proof.json source-built-self-npm-install-proof.json
      ].each do |name|
        FileUtils.cp(File.join(package.directory, name), File.join(directory, name))
      end
      receipt_path = File.join(directory, copied_metadata.fetch("source"))
      receipt = JSON.parse(File.read(receipt_path))
      receipt.fetch("final_link")["generated_output_count"] -= 1
      receipt.dig("inputs", "build_ninja")["sha256"] = "0" * 64
      receipt.dig("final_link", "undeclared_header_side_effects", "orchestrator")["sha256"] = "0" * 64
      receipt.dig("final_link", "undeclared_header_side_effects", "producers", 0)["side_effect_outputs"].reverse!
      undeclared = receipt.fetch("final_link").fetch("generated_outputs").find { |record| record["producer_edge_declared"] == false }
      undeclared["producer_edge_declared"] = true
      undeclared["rule"] = "codegen"
      receipt.fetch("npm")["packages_with_required_text"] -= 1
      constants = receipt.fetch("npm").fetch("selected_packages").find { |record| record["name"] == "constants-browserify" }
      constants.fetch("license_text_resolution")["repository_license_sha256"] = "0" * 64
      receipt.fetch("validation")["undeclared_header_generator_side_effects_verified"] = false
      receipt.fetch("validation")["final_npm_codegen_closure_verified"] = true
      File.write(receipt_path, JSON.pretty_generate(receipt) + "\n")
      copied_metadata["sha256"] = Digest::SHA256.file(receipt_path).hexdigest
      copied_package = Agentlab::Package.new(directory: directory, manifest_path: "unused", data: data)

      errors = Agentlab.validate_bun_npm_code_generation_closure(
        copied_package,
        copied_metadata,
        data.dig("build_plan", "source_inputs", "source_license_inventory"),
        data.dig("build_plan", "stages"),
        "1.3.14",
        spec
      )
      assert_includes(errors, "bun: npm code-generation final-link counts mismatch")
      assert_includes(errors, "bun: npm code-generation build graph mismatch")
      assert_includes(errors, "bun: npm code-generation side-effect provenance mismatch")
      assert_includes(errors, "bun: npm code-generation undeclared output semantics mismatch")
      assert_includes(errors, "bun: npm code-generation package counts mismatch")
      assert_includes(errors, "bun: npm code-generation constants-browserify license text resolution mismatch")
      assert_includes(errors, "bun: npm code-generation mapping validation is incomplete")
      assert_includes(errors, "bun: npm code-generation closure overclaims completion")
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

  def test_validates_bun_multi_architecture_source_delivery
    source_package = Agentlab.package_named("bun")
    spec = File.read(File.join(source_package.directory, "bun.spec"))
    staging = source_package.data.dig("build_plan", "source_inputs", "release_local_staging")

    assert_empty(Agentlab.validate_bun_multi_arch_source_delivery(source_package, staging, "1.3.14", spec))

    mutated = Marshal.load(Marshal.dump(staging))
    mutated.fetch("npm_union")["member_count"] = 238
    errors = Agentlab.validate_bun_multi_arch_source_delivery(source_package, mutated, "1.3.14", spec)
    assert_includes(errors, "bun: multi-architecture npm union metadata mismatch")

    errors = Agentlab.validate_bun_multi_arch_source_delivery(source_package, staging, "1.3.14", spec.sub("Source31:       bun", "Source32:       bun"))
    assert_includes(errors, "bun: spec does not declare the checked multi-architecture source delivery")
  end

  def test_validates_bun_self_rebuild_receipts
    source_package = Agentlab.package_named("bun")
    Dir.mktmpdir do |directory|
      directory = prepare_bun_fixture_repository(source_package, directory)
      data = Marshal.load(Marshal.dump(source_package.data))
      data.fetch("build_plan").fetch("stages").each_value { |stage| stage["state"] = "blocked" }
      data.dig("build_plan", "stages", "dependency_closure")["state"] = "verified"
      self_stage = data.dig("build_plan", "stages", "self_rebuild")
      %w[bun-1.3.14-final-linked-license-closure.json bun-1.3.14-npm-code-generation-closure.json bun-1.3.14-release-local-source-closure.json bun-1.3.14-release-local-source-closure-arm64.json bun-1.3.14-source-license-inventory.json bun-lightningcss-fedora-glibc-arm64-lock.patch bun-stage-release-local-sources bun-system-lolhtml.patch first-source-build-proof.json npm-offline-install-proof.json npm-offline-install-proof-arm64.json prior-self-rebuild-proof.json relink-materials-proof.json relink-kit-proof.json self-rebuild-proof.json source-built-npm-install-proof.json source-built-self-npm-install-proof.json webkit-minimized-source-proof.json webkit-minimized-source-build-proof.json webkit-minimized-source-build-proof-arm64.json zig-bootstrap-proof-arm64.json zig-fedora-lib64.patch].each do |name|
        FileUtils.cp(File.join(source_package.directory, name), File.join(directory, name))
      end
      package = Agentlab::Package.new(directory: directory, manifest_path: "unused", data: data)
      spec = File.read(File.join(source_package.directory, "bun.spec"))

      assert_empty(Agentlab.validate_bun_build_plan(package, spec))

      self_receipt_path = File.join(directory, "self-rebuild-proof.json")
      self_receipt = JSON.parse(File.read(self_receipt_path))
      driver_sha256 = self_receipt.dig("first_build", "sha256")
      self_receipt.fetch("first_build")["sha256"] = "0" * 64
      File.write(self_receipt_path, JSON.dump(self_receipt))
      self_stage["proof_receipt_sha256"] = Digest::SHA256.file(self_receipt_path).hexdigest

      errors = Agentlab.validate_bun_build_plan(package, spec)
      assert_includes(errors, "bun: self-rebuild proof driver binary mismatch")

      self_receipt.fetch("first_build")["sha256"] = driver_sha256
      self_receipt.fetch("validation")["offline_verified"] = false
      File.write(self_receipt_path, JSON.dump(self_receipt))
      self_stage["proof_receipt_sha256"] = Digest::SHA256.file(self_receipt_path).hexdigest

      errors = Agentlab.validate_bun_build_plan(package, spec)
      assert_includes(errors, "bun: self-rebuild proof validation is incomplete")
    end
  end

  def test_validates_bun_relink_materials_receipt
    source_package = Agentlab.package_named("bun")
    Dir.mktmpdir do |directory|
      directory = prepare_bun_fixture_repository(source_package, directory)
      data = Marshal.load(Marshal.dump(source_package.data))
      data.fetch("build_plan").fetch("stages").each_value { |stage| stage["state"] = "blocked" }
      data.dig("build_plan", "stages", "dependency_closure")["state"] = "verified"
      self_stage = data.dig("build_plan", "stages", "self_rebuild")
      receipt_name = data.dig("build_plan", "stages", "seed_build", "relink_materials_audit", "proof_receipt")
      FileUtils.cp(File.join(source_package.directory, receipt_name), File.join(directory, receipt_name))
      kit_receipt_name = data.dig("build_plan", "stages", "seed_build", "relink_kit", "proof_receipt")
      FileUtils.cp(File.join(source_package.directory, kit_receipt_name), File.join(directory, kit_receipt_name))
      closure_name = data.dig("build_plan", "stages", "dependency_closure", "proof_receipt")
      FileUtils.cp(File.join(source_package.directory, closure_name), File.join(directory, closure_name))
      inventory_name = data.dig("build_plan", "source_inputs", "source_license_inventory", "source")
      FileUtils.cp(File.join(source_package.directory, inventory_name), File.join(directory, inventory_name))
      final_license_name = data.dig("build_plan", "source_inputs", "final_linked_license_closure", "source")
      FileUtils.cp(File.join(source_package.directory, final_license_name), File.join(directory, final_license_name))
      npm_codegen_name = data.dig("build_plan", "source_inputs", "npm_code_generation_closure", "source")
      FileUtils.cp(File.join(source_package.directory, npm_codegen_name), File.join(directory, npm_codegen_name))
      patch_name = data.dig("build_plan", "source_inputs", "lolhtml", "patch")
      FileUtils.cp(File.join(source_package.directory, patch_name), File.join(directory, patch_name))
      webkit = data.dig("build_plan", "source_inputs", "webkit", "jsc_only")
      %w[proof_receipt source_build_proof_receipt].each do |key|
        name = webkit.fetch(key)
        FileUtils.cp(File.join(source_package.directory, name), File.join(directory, name))
      end
      %w[bun-1.3.14-release-local-source-closure-arm64.json bun-lightningcss-fedora-glibc-arm64-lock.patch bun-stage-release-local-sources npm-offline-install-proof-arm64.json prior-self-rebuild-proof.json self-rebuild-proof.json source-built-npm-install-proof.json source-built-self-npm-install-proof.json webkit-minimized-source-build-proof-arm64.json zig-bootstrap-proof-arm64.json zig-fedora-lib64.patch].each do |name|
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

    assert_empty(Agentlab.validate_opencode_review_evidence(package, dependencies, dependencies.fetch("target_release")))
  end

  def test_rejects_opencode_review_without_generated_source_closure
    source_package = Agentlab.package_named("opencode")
    dependencies = Agentlab.load_yaml(File.join(source_package.directory, "dependencies.yml"))
    Dir.mktmpdir do |directory|
      dependencies.fetch("source_closure_files").each do |key, filename|
        next if key == "closure_manifest"

        source = File.join(source_package.directory, filename)
        FileUtils.cp(source, File.join(directory, filename)) if File.file?(source)
      end
      %w[
        opencode.spec
        opencode-record-bundle-metafile.patch
        opencode-disable-fff.patch
        opencode-zig-fedora-lib64.patch
        opencode-build-web-tree-sitter-runtime.py
        opencode-validate-tree-sitter.mjs
         opencode-1.18.8-bun-pty-cargo-vendor.txt
      ].each do |filename|
        FileUtils.cp(File.join(source_package.directory, filename), File.join(directory, filename))
      end
      package = Agentlab::Package.new(
        directory: directory,
        manifest_path: "unused",
        data: source_package.data
      )

      errors = Agentlab.validate_opencode_review_evidence(package, dependencies, dependencies.fetch("target_release"))
      assert_includes(errors, "opencode: generated source closure is missing")

      closure_filename = dependencies.dig("source_closure_files", "closure_manifest")
      FileUtils.cp(File.join(source_package.directory, closure_filename), File.join(directory, closure_filename))
      assert_empty(Agentlab.validate_opencode_review_evidence(package, dependencies, dependencies.fetch("target_release")))

      spec_path = File.join(directory, "opencode.spec")
      remap = 'RUSTFLAGS="--remap-path-prefix=$PWD=/usr/src/debug/%{name}-%{version}/.photon-source"'
      File.write(spec_path, File.read(spec_path).sub(remap, 'RUSTFLAGS=""'))
      errors = Agentlab.validate_opencode_review_evidence(package, dependencies, dependencies.fetch("target_release"))
      assert(errors.any? { |error| error.include?("spec is missing Photon build requirement #{remap}") })
    end
  end

  def test_rejects_incomplete_opencode_source_delivery_proof
    package = Agentlab.package_named("opencode")
    dependencies = Marshal.load(Marshal.dump(Agentlab.load_yaml(File.join(package.directory, "dependencies.yml"))))
    dependencies.fetch("source_delivery_proof")["source_members"] -= 1

    errors = Agentlab.validate_opencode_review_evidence(package, dependencies, dependencies.fetch("target_release"))

    assert_includes(errors, "opencode: source delivery proof does not match")
  end

  def test_rejects_incomplete_opencode_node_modules_proof
    package = Agentlab.package_named("opencode")
    dependencies = Marshal.load(Marshal.dump(Agentlab.load_yaml(File.join(package.directory, "dependencies.yml"))))
    dependencies.fetch("node_modules_materialization_proof")["package_paths"] -= 1

    errors = Agentlab.validate_opencode_review_evidence(package, dependencies, dependencies.fetch("target_release"))

    assert_includes(errors, "opencode: node_modules materialization proof does not match")
  end

  def test_rejects_incomplete_opencode_final_license_preflight
    package = Agentlab.package_named("opencode")
    dependencies = Marshal.load(Marshal.dump(Agentlab.load_yaml(File.join(package.directory, "dependencies.yml"))))
    dependencies.fetch("final_license_preflight")["opencode_notice_holds"] -= 1

    errors = Agentlab.validate_opencode_review_evidence(package, dependencies, dependencies.fetch("target_release"))

    assert_includes(errors, "opencode: final-license preflight metadata does not match")
  end

  def test_rejects_inconsistent_opencode_models_snapshot_evidence
    package = Agentlab.package_named("opencode")
    dependencies = Marshal.load(Marshal.dump(Agentlab.load_yaml(File.join(package.directory, "dependencies.yml"))))
    dependencies.dig("selected_lock_audit", "models_snapshot")["immutable_source_recorded"] = true

    errors = Agentlab.validate_opencode_review_evidence(package, dependencies, dependencies.fetch("target_release"))

    assert(errors.any? { |error| error.include?("models snapshot policy does not match") })
    assert(errors.any? { |error| error.include?("models snapshot receipt does not match") })
  end

  def test_rejects_incomplete_opencode_models_snapshot_proof
    source_package = Agentlab.package_named("opencode")
    dependencies = Agentlab.load_yaml(File.join(source_package.directory, "dependencies.yml"))
    Dir.mktmpdir do |directory|
      dependencies.fetch("source_closure_files").each_value do |filename|
        source = File.join(source_package.directory, filename)
        FileUtils.cp(source, File.join(directory, filename)) if File.file?(source)
      end
      proof_path = File.join(directory, dependencies.dig("source_closure_files", "models_snapshot_proof"))
      proof = JSON.parse(File.read(proof_path))
      proof.dig("build", "output_sha256").replace("0" * 64)
      File.write(proof_path, JSON.pretty_generate(proof) + "\n")
      package = Agentlab::Package.new(directory: directory, manifest_path: "unused", data: { "name" => "opencode" })
      errors = Agentlab.validate_opencode_review_evidence(package, dependencies, dependencies.fetch("target_release"))
      assert(errors.any? { |error| error.include?("models snapshot proof does not match") })

      FileUtils.cp(File.join(source_package.directory, "opencode.spec"), File.join(directory, "opencode.spec"))
      spec_path = File.join(directory, "opencode.spec")
      spec = File.read(spec_path).sub(
        /%global models_dev_proof_sha256 \S+/,
        "%global models_dev_proof_sha256 #{'0' * 64}"
      )
      File.write(spec_path, spec)
      errors = Agentlab.validate_opencode_review_evidence(package, dependencies, dependencies.fetch("target_release"))
      assert(errors.any? { |error| error.include?("spec models snapshot proof SHA-256 does not match") })
    end
  end

  def test_rejects_incomplete_opencode_source_license_set
    source_package = Agentlab.package_named("opencode")
    dependencies = Agentlab.load_yaml(File.join(source_package.directory, "dependencies.yml"))
    Dir.mktmpdir do |directory|
      dependencies.fetch("source_closure_files").each_value do |filename|
        source = File.join(source_package.directory, filename)
        FileUtils.cp(source, File.join(directory, filename)) if File.file?(source)
      end
      proof_path = File.join(directory, dependencies.dig("source_closure_files", "source_license_set_proof"))
      proof = JSON.parse(File.read(proof_path))
      proof["validation"]["source_set_expression_verified"] = false
      File.write(proof_path, JSON.pretty_generate(proof) + "\n")
      package = Agentlab::Package.new(directory: directory, manifest_path: "unused", data: { "name" => "opencode" })
      errors = Agentlab.validate_opencode_review_evidence(package, dependencies, dependencies.fetch("target_release"))
      assert(errors.any? { |error| error.include?("source license-set validation flags do not match") })
    end
  end

  def test_rejects_incomplete_opencode_lifecycle_review
    package = Agentlab.package_named("opencode")
    dependencies = Marshal.load(Marshal.dump(Agentlab.load_yaml(File.join(package.directory, "dependencies.yml"))))
    dependencies.fetch("source_acquisition_findings").delete("lifecycle_script_review")

    errors = Agentlab.validate_opencode_review_evidence(package, dependencies, dependencies.fetch("target_release"))

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

      errors = Agentlab.validate_opencode_review_evidence(package, dependencies, dependencies.fetch("target_release"))

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

      errors = Agentlab.validate_opencode_review_evidence(package, dependencies, dependencies.fetch("target_release"))

      assert(errors.any? { |error| error.include?("subordinate source ids do not match for shiki@4.2.0") })
    end
  end

  def test_rejects_incomplete_opencode_shiki_rebuild
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
      shiki.dig("provenance", "current_rebuild")["output_sha256"] = "0" * 64
      File.write(native_path, YAML.dump(native_review))
      package = Agentlab::Package.new(directory: directory, manifest_path: "unused", data: { "name" => "opencode" })
      errors = Agentlab.validate_opencode_review_evidence(package, dependencies, dependencies.fetch("target_release"))
      assert(errors.any? { |error| error.include?("Shiki WASM rebuild evidence does not match") })
    end
  end

  def test_rejects_incomplete_opencode_undici_rebuild
    source_package = Agentlab.package_named("opencode")
    dependencies = Agentlab.load_yaml(File.join(source_package.directory, "dependencies.yml"))
    Dir.mktmpdir do |directory|
      %w[selected_lock_audit source_audit license_review native_review].each do |key|
        filename = dependencies.dig("source_closure_files", key)
        FileUtils.cp(File.join(source_package.directory, filename), File.join(directory, filename))
      end
      native_path = File.join(directory, dependencies.dig("source_closure_files", "native_review"))
      native_review = Agentlab.load_yaml(native_path)
      undici = native_review.fetch("components").find { |component| component["package"] == "undici@5.29.0" }
      undici.dig("provenance", "current_rebuild", "simd")["sha256"] = "0" * 64
      File.write(native_path, YAML.dump(native_review))
      package = Agentlab::Package.new(directory: directory, manifest_path: "unused", data: { "name" => "opencode" })
      errors = Agentlab.validate_opencode_review_evidence(package, dependencies, dependencies.fetch("target_release"))
      assert(errors.any? { |error| error.include?("Undici WASM rebuild evidence does not match") })
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

      errors = Agentlab.validate_opencode_review_evidence(package, dependencies, dependencies.fetch("target_release"))

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

      errors = Agentlab.validate_opencode_review_evidence(package, dependencies, dependencies.fetch("target_release"))

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

      errors = Agentlab.validate_opencode_review_evidence(package, dependencies, dependencies.fetch("target_release"))

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
        component["npm_name"] == "@opentui/core-linux-x64"
      end
      opentui.fetch("provenance").delete("source_build")
      File.write(native_path, YAML.dump(native_review))
      package = Agentlab::Package.new(directory: directory, manifest_path: "unused", data: { "name" => "opencode" })

      errors = Agentlab.validate_opencode_review_evidence(package, dependencies, dependencies.fetch("target_release"))

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

      errors = Agentlab.validate_opencode_review_evidence(package, dependencies, dependencies.fetch("target_release"))

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

      errors = Agentlab.validate_opencode_review_evidence(package, dependencies, dependencies.fetch("target_release"))

      assert(errors.any? { |error| error.include?("Tree-sitter source-build evidence does not match") })
    end
  end

  def rust_v8_receipt_names(dependencies)
    %w[source_closure license_audit archive_graph fedora_license_evidence dynamic_linking static_license consumer_rlib_license].map do |key|
      dependencies.dig(key, "receipt")
    end + [dependencies.dig("source_closure", "source_filter_receipt")]
  end

  def copy_rust_v8_receipts(source_package, dependencies, directory)
    rust_v8_receipt_names(dependencies).each do |name|
      FileUtils.cp(File.join(source_package.directory, name), File.join(directory, name))
    end
  end

  def test_validates_rust_v8_evidence
    package = Agentlab.package_named("rust-v8")
    dependencies = Agentlab.load_yaml(File.join(package.directory, "dependencies.yml"))
    spec = File.read(package.spec_path)
    source = JSON.parse(File.read(File.join(package.directory, dependencies.dig("source_closure", "receipt"))))
    license = JSON.parse(File.read(File.join(package.directory, dependencies.dig("license_audit", "receipt"))))
    archive_graph = JSON.parse(File.read(File.join(package.directory, dependencies.dig("archive_graph", "receipt"))))
    fedora_license = JSON.parse(File.read(File.join(package.directory, dependencies.dig("fedora_license_evidence", "receipt"))))
    dynamic_linking = JSON.parse(File.read(File.join(package.directory, dependencies.dig("dynamic_linking", "receipt"))))
    source_filter = JSON.parse(File.read(File.join(package.directory, dependencies.dig("source_closure", "source_filter_receipt"))))
    static_license = JSON.parse(File.read(File.join(package.directory, dependencies.dig("static_license", "receipt"))))

    assert_empty(Agentlab.validate_rust_v8_evidence(package, dependencies, spec))
    assert_includes(spec, "%ifarch aarch64\nis_clang = true\n%else\nis_clang = false\n%endif")
    assert_includes(spec, "BuildRequires:  compiler-rt")
    assert_includes(spec, "BuildRequires:  llvm")
    assert_includes(spec, 'clang_version="$(clang -dumpversion)"')
    assert_includes(spec, 'clang_version="${clang_version%%%%.*}"')
    system_patch = File.read(File.join(package.directory, "rust-v8-system-rust-toolchain.patch"))
    assert_includes(system_patch, '_dir = "aarch64-redhat-linux-gnu"')
    assert_equal(3, system_patch.scan("clang_base_path == default_clang_base_path").length)
    assert_includes(system_patch, 'import("//build/config/clang/clang.gni")')
    memcopy_patch = File.read(File.join(package.directory, "rust-v8-v8-memcopy-climits.patch"))
    assert_includes(memcopy_patch, "+#include <climits>")
    assert_includes(memcopy_patch, "https://issues.chromium.org/issues/512749476")
    assert_equal(4, source.fetch("patches").length)
    assert_includes(spec, "patch --batch --fuzz=0 -p1 < %{PATCH3}")
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
    assert_equal(136, fedora_license.dig("summary", "exact"))
    assert_equal(26, fedora_license.dig("summary", "version_different"))
    assert_equal(54, fedora_license.dig("summary", "absent"))
    assert_equal(fedora_license.fetch("summary"), license.dig("fedora_license_evidence", "summary"))
    assert(license.dig("validation", "vendored_rust_fedora_license_evidence_recorded"))
    assert_equal("static", dynamic_linking.dig("upstream_contract", "cargo_native_link_kind"))
    assert(dynamic_linking.dig("upstream_contract", "v8_component_build_available"))
    assert(dynamic_linking.dig("validation", "exact_relevant_source_files_verified"))
    assert(dynamic_linking.dig("validation", "single_static_root_target_verified"))
    assert(dynamic_linking.dig("validation", "single_static_cargo_link_directive_verified"))
    refute(dynamic_linking.dig("shared_provider", "upstream_supported"))
    refute(dynamic_linking.dig("decision", "package_shared_library"))
    assert(dynamic_linking.dig("decision", "retain_exact_static_provider"))
    clang_format = license.fetch("components").flat_map { |component| component.fetch("readme_chromium") }.find do |record|
      record["path"] == "buildtools/clang_format/README.chromium"
    end
    assert_equal("(Apache-2.0 WITH LLVM-exception) AND NCSA", clang_format.fetch("normalized_expression"))
    assert_equal("verified", clang_format.fetch("semantic_review_status"))
    assert_equal(2, license.fetch("scoped_parent_license_evidence").length)
    assert_equal("rust-v8-archive-graph-witness/v2", archive_graph.fetch("schema"))
    assert_equal(1_795, archive_graph.dig("archive", "object_input_count"))
    assert_equal(1_795, archive_graph.dig("archive", "member_count"))
    assert_equal(31, archive_graph.dig("archive", "implicit_rust_rlib_count"))
    refute(archive_graph.dig("archive", "implicit_rust_rlibs_embedded_in_archive"))
    refute(archive_graph.dig("archive", "member_contents_match_object_contents_verified"))
    assert_empty(archive_graph.dig("archive", "selected_googletest_inputs"))
    assert_empty(archive_graph.dig("archive", "selected_halfsiphash_inputs"))
    assert_equal(1_795, archive_graph.dig("architecture_expectations", "x86_64", "object_input_count"))
    assert_equal(1_803, archive_graph.dig("architecture_expectations", "aarch64", "object_input_count"))
    assert_equal(
      "c12202362607f81a15708a247a6251f14c5f56710ac41b836b6ee096a0529a00",
      archive_graph.dig("architecture_expectations", "aarch64", "object_input_paths_sha256")
    )
    assert_equal(
      "9c0f827a2e8dca6956452227bd316f3a6ad4cca957d82b55bad4a3acc174a471",
      archive_graph.dig("architecture_expectations", "aarch64", "member_names_sha256")
    )
    refute(archive_graph.dig("validation", "selected_build_dependency_closure_verified"))
    assert_equal(3, source_filter.fetch("excluded_paths").length)
    assert_equal("rust-v8-source-filter/v3", source_filter.fetch("schema"))
    refute(source_filter.fetch("output").key?("bytes"))
    refute(source_filter.fetch("output").key?("sha256"))
    refute(source_filter.dig("upstream", "transport_identity_required"))
    refute(source_filter.dig("validation", "generated_archive_transport_identity_required"))
    refute(source_filter.dig("validation", "cc0_executable_source_present"))
    filtered_archive = source.fetch("components").find { |component| component.fetch("path") == "v8" }.fetch("archive")
    refute(filtered_archive.fetch("transport_identity_required"))
    source.fetch("components").each do |component|
      refute(component.fetch("archive").fetch("transport_identity_required"))
    end
    assert_equal(1_795, static_license.dig("selected_graph", "archive_objects"))
    assert_equal(24, static_license.dig("static_archive", "required_license_texts").length)
    assert(static_license.dig("validation", "fedora_allowed_spdx_verified"))
    assert(static_license.dig("validation", "prototype_static_archive_license_complete"))
    refute(static_license.dig("validation", "production_static_archive_license_complete"))
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
      fedora_license_name = dependencies.dig("fedora_license_evidence", "receipt")
      dynamic_linking_name = dependencies.dig("dynamic_linking", "receipt")
      copy_rust_v8_receipts(source_package, dependencies, directory)
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

  def test_rejects_rust_v8_fedora_license_evidence_overclaim
    source_package = Agentlab.package_named("rust-v8")
    dependencies = Agentlab.load_yaml(File.join(source_package.directory, "dependencies.yml"))
    data = Marshal.load(Marshal.dump(source_package.data))
    spec = File.read(source_package.spec_path)

    Dir.mktmpdir do |directory|
      copy_rust_v8_receipts(source_package, dependencies, directory)
      fedora_name = dependencies.dig("fedora_license_evidence", "receipt")
      fedora_path = File.join(directory, fedora_name)
      fedora = JSON.parse(File.read(fedora_path))
      fedora.fetch("validation")["linked_archive_selection_verified"] = true
      File.write(fedora_path, JSON.pretty_generate(fedora) + "\n")
      fedora_sha256 = Digest::SHA256.file(fedora_path).hexdigest
      data.fetch("fedora_license_evidence")["receipt_sha256"] = fedora_sha256
      dependencies = Marshal.load(Marshal.dump(dependencies))
      dependencies.fetch("fedora_license_evidence")["receipt_sha256"] = fedora_sha256
      spec = spec.sub(
        /^%global fedora_license_evidence_sha256\s+\h{64}$/,
        "%global fedora_license_evidence_sha256 #{fedora_sha256}"
      )
      package = Agentlab::Package.new(directory: directory, manifest_path: "unused", data: data)

      errors = Agentlab.validate_rust_v8_evidence(package, dependencies, spec)

      assert_includes(errors, "rust-v8: Fedora license evidence overclaims linked_archive_selection_verified")
    end
  end

  def test_rejects_rust_v8_dynamic_linking_overclaim
    source_package = Agentlab.package_named("rust-v8")
    dependencies = Agentlab.load_yaml(File.join(source_package.directory, "dependencies.yml"))
    data = Marshal.load(Marshal.dump(source_package.data))
    spec = File.read(source_package.spec_path)

    Dir.mktmpdir do |directory|
      copy_rust_v8_receipts(source_package, dependencies, directory)
      dynamic_name = dependencies.dig("dynamic_linking", "receipt")
      dynamic_path = File.join(directory, dynamic_name)
      dynamic = JSON.parse(File.read(dynamic_path))
      dynamic.fetch("decision")["package_shared_library"] = true
      dynamic.fetch("validation")["shared_provider_packaged"] = true
      File.write(dynamic_path, JSON.pretty_generate(dynamic) + "\n")
      dynamic_sha256 = Digest::SHA256.file(dynamic_path).hexdigest
      data.fetch("dynamic_linking")["receipt_sha256"] = dynamic_sha256
      data.fetch("dynamic_linking")["package_shared_library"] = true
      dependencies = Marshal.load(Marshal.dump(dependencies))
      dependencies.fetch("dynamic_linking")["receipt_sha256"] = dynamic_sha256
      dependencies.fetch("dynamic_linking")["package_shared_library"] = true
      spec = spec.sub(
        /^%global dynamic_linking_sha256\s+\h{64}$/,
        "%global dynamic_linking_sha256 #{dynamic_sha256}"
      )
      package = Agentlab::Package.new(directory: directory, manifest_path: "unused", data: data)

      errors = Agentlab.validate_rust_v8_evidence(package, dependencies, spec)

      assert_includes(errors, "rust-v8: dynamic-linking package decision does not match")
      assert_includes(errors, "rust-v8: dynamic-linking validation state does not match")
    end
  end

  def test_rejects_rust_v8_static_license_overclaim
    source_package = Agentlab.package_named("rust-v8")
    dependencies = Agentlab.load_yaml(File.join(source_package.directory, "dependencies.yml"))
    data = Marshal.load(Marshal.dump(source_package.data))
    spec = File.read(source_package.spec_path)

    Dir.mktmpdir do |directory|
      copy_rust_v8_receipts(source_package, dependencies, directory)
      static_name = dependencies.dig("static_license", "receipt")
      static_path = File.join(directory, static_name)
      static_license = JSON.parse(File.read(static_path))
      static_license.fetch("validation")["production_static_archive_license_complete"] = true
      File.write(static_path, JSON.pretty_generate(static_license) + "\n")
      static_sha256 = Digest::SHA256.file(static_path).hexdigest
      data.fetch("static_license")["receipt_sha256"] = static_sha256
      data.fetch("static_license")["production_static_archive_license_complete"] = true
      dependencies = Marshal.load(Marshal.dump(dependencies))
      dependencies.fetch("static_license")["receipt_sha256"] = static_sha256
      dependencies.fetch("static_license")["production_static_archive_license_complete"] = true
      spec = spec.sub(/^%global static_license_sha256\s+\h{64}$/, "%global static_license_sha256 #{static_sha256}")
      package = Agentlab::Package.new(directory: directory, manifest_path: "unused", data: data)

      errors = Agentlab.validate_rust_v8_evidence(package, dependencies, spec)

      assert_includes(errors, "rust-v8: static-license receipt overclaims production closure")
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
      fedora_license_name = dependencies.dig("fedora_license_evidence", "receipt")
      dynamic_linking_name = dependencies.dig("dynamic_linking", "receipt")
      copy_rust_v8_receipts(source_package, dependencies, directory)
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
      fedora_license_name = dependencies.dig("fedora_license_evidence", "receipt")
      dynamic_linking_name = dependencies.dig("dynamic_linking", "receipt")
      copy_rust_v8_receipts(source_package, dependencies, directory)
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
    data.fetch("archive_graph").fetch("architecture_object_input_counts")["aarch64"] = 1_795
    data.fetch("archive_graph")["implicit_rust_rlibs_embedded_in_archive"] = true
    package = Agentlab::Package.new(directory: source_package.directory, manifest_path: "unused", data: data)

    errors = Agentlab.validate_rust_v8_evidence(package, dependencies, File.read(source_package.spec_path))

    assert_includes(errors, "rust-v8: archive-graph metadata scope does not match")
    assert_includes(errors, "rust-v8: archive-graph metadata architecture object counts do not match")
    assert_includes(errors, "rust-v8: archive-graph metadata overclaims embedded Rust rlibs")
  end

  def test_rejects_incomplete_rust_v8_production_build
    package = Agentlab.package_named("rust-v8")
    dependencies = Agentlab.load_yaml(File.join(package.directory, "dependencies.yml"))
    spec = File.read(package.spec_path)
               .sub("ExclusiveArch:  x86_64 aarch64", "ExclusiveArch:  x86_64")
               .sub("gn gen out/fedora", "# gn gen out/fedora")
               .sub("%{__ninja} -C out/fedora -j%{_smp_build_ncpus} obj/librusty_v8.a", "# missing Ninja build")
               .sub('assert lines_sha256(objects) == expected["object_input_paths_sha256"]', "# missing graph digest check")
               .sub("assert sorted(members) == sorted(os.path.basename(path) for path in objects)", "assert members")

    errors = Agentlab.validate_rust_v8_evidence(package, dependencies, spec)

    assert_includes(errors, "rust-v8: spec does not select both supported architectures")
    assert_includes(errors, "rust-v8: spec does not generate the GN build")
    assert_includes(errors, "rust-v8: spec does not build the exact Rusty V8 target")
    assert_includes(errors, "rust-v8: spec does not verify the production archive graph")
  end

  def test_rejects_incomplete_rust_v8_remote_matrix
    source_package = Agentlab.package_named("rust-v8")
    dependencies = Marshal.load(Marshal.dump(Agentlab.load_yaml(File.join(source_package.directory, "dependencies.yml"))))
    dependencies.dig("closure_audit")["aarch64_verified"] = false

    errors = Agentlab.validate_rust_v8_evidence(source_package, dependencies, File.read(source_package.spec_path))

    assert_includes(errors, "rust-v8: dependency production-build evidence aarch64_verified does not match")
  end

  def test_prepares_deterministic_headroom_fixture_source
    Dir.mktmpdir do |directory|
      version = "9.9.9"
      commit = "a" * 40
      source_root = File.join(directory, "headroom-#{commit}")
      fixture_root = File.join(source_root, HeadroomFixtureSource::FIXTURE_PATH)
      FileUtils.mkdir_p(fixture_root)
      File.write(File.join(source_root, "LICENSE"), "Apache fixture license\n")
      File.write(File.join(source_root, "NOTICE"), "Fixture notice\n")
      30.times do |index|
        File.write(File.join(fixture_root, format("%016x.json", index)), "{\"fixture\":#{index}}\n")
      end

      tar_path = File.join(directory, "source.tar")
      source = File.join(directory, "source.tar.gz")
      assert(system(
        { "LC_ALL" => "C", "TZ" => "UTC" },
        "tar", "--sort=name", "--mtime=@0", "--owner=0", "--group=0", "--numeric-owner",
        "--format=ustar", "--create", "--file", tar_path, "--directory", directory, File.basename(source_root)
      ))
      File.open(source, "wb") do |file|
        gzip = Zlib::GzipWriter.new(file, Zlib::BEST_COMPRESSION)
        gzip.mtime = 0
        File.open(tar_path, "rb") { |tar| IO.copy_stream(tar, gzip) }
        gzip.close
      end

      fixtures = Dir.glob(File.join(fixture_root, "*.json")).sort
      records = fixtures.map do |path|
        content = File.binread(path)
        "#{File.basename(path)}\t#{content.bytesize}\t#{Digest::SHA256.hexdigest(content)}\n"
      end
      fixture_bytes = fixtures.sum { |path| File.size(path) }
      fixture_manifest = Digest::SHA256.hexdigest(records.join)
      spec = File.join(directory, "python-headroom-ai.spec")
      File.write(spec, <<~SPEC)
        %global upstream_source_commit #{commit}
        %global upstream_source_sha256 #{Digest::SHA256.file(source).hexdigest}
        %global code_compressor_fixture_count 30
        %global code_compressor_fixture_bytes #{fixture_bytes}
        %global code_compressor_fixture_manifest_sha256 #{fixture_manifest}
        Version: #{version}
      SPEC

      first = File.join(directory, "first.tar.gz")
      second = File.join(directory, "second.tar.gz")
      digest = HeadroomFixtureSource.generate!(spec:, source:, output: first, verify_output_hash: false)
      File.write(
        spec,
        File.read(spec).sub(
          "Version: #{version}",
          "%global code_compressor_fixture_source_sha256 #{digest}\nVersion: #{version}"
        )
      )
      assert_equal(digest, HeadroomFixtureSource.generate!(spec:, source:, output: second))
      assert_equal(File.binread(first), File.binread(second))

      members = {}
      Zlib::GzipReader.open(first) do |gzip|
        Gem::Package::TarReader.new(gzip) do |tar|
          tar.each { |entry| members[entry.full_name] = entry.read if entry.file? }
        end
      end
      archive_root = "headroom-#{version}-code-compressor-fixtures"
      assert_equal(33, members.length)
      assert_equal(30, members.keys.count { |path| path.start_with?("#{archive_root}/#{HeadroomFixtureSource::FIXTURE_PATH}/") })
      provenance = JSON.parse(members.fetch("#{archive_root}/provenance.json"))
      assert_equal("agentlab-headroom-code-compressor-fixture-source/v1", provenance.fetch("schema"))
      assert_equal(commit, provenance.dig("release", "commit"))
      assert_equal(fixture_manifest, provenance.dig("fixture_contract", "manifest_sha256"))
      assert_equal(%w[LICENSE NOTICE], provenance.fetch("license_files").keys.sort)

      File.open(source, "ab") { |file| file.write("tampered") }
      error = assert_raises(HeadroomFixtureSource::Error) do
        HeadroomFixtureSource.generate!(spec:, source:, output: second)
      end
      assert_includes(error.message, "upstream source SHA-256 mismatch")
    end
  end
end
