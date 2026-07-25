# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "open3"
require "yaml"

class ProveBunFirstSourceBuildTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  SCRIPT = File.join(ROOT, "scripts", "prove-bun-first-source-build")
  NPM_SCRIPT = File.join(ROOT, "scripts", "prove-bun-npm-offline-install")
  PACKAGE_DIR = File.join(ROOT, "packages", "bun")

  def test_helper_tracks_the_current_system_lolhtml_source_graph
    source = File.read(SCRIPT)
    closure = JSON.parse(File.read(File.join(PACKAGE_DIR, "bun-1.3.14-release-local-source-closure.json")))
    package = YAML.safe_load(File.read(File.join(PACKAGE_DIR, "package.yml")))
    lolhtml = closure.fetch("selection").fetch("excluded").find { |record| record.fetch("name") == "lolhtml" }

    assert_equal("bun-release-local-source-closure/v3", closure.fetch("schema"))
    assert_equal(18, closure.fetch("native_github_sources").length)
    assert_equal("fedora-system-provider", lolhtml.fetch("reason"))
    assert_equal("lol-html 3.0.0", lolhtml.fetch("provider"))
    assert_equal(0, package.dig("build_plan", "stages", "dependency_closure", "selected_cargo_source_archives"))

    assert_includes(source, 'closure["schema"] == "bun-release-local-source-closure/v3"')
    assert_includes(source, "expected 18 native source archives")
    assert_includes(source, "generated graph still builds Bun's private lol-html")
    assert_includes(source, "generated graph does not link Fedora's lol-html provider")
    assert_includes(source, '"system_lolhtml_provider_verified" => true')
    assert_includes(source, '"cargo_source_archives" => 0')
    assert_includes(source, "def verify_system_lolhtml_patch!(source_dir)")
    assert_includes(source, '--lolhtml-provider-root PATH')
    assert_includes(source, "def verify_lolhtml_provider!(provider_root, metadata)")
    assert_includes(source, '"LD_LIBRARY_PATH" => File.join(lolhtml_provider_root, "usr", "lib64")')
    assert_includes(source, '"system_lolhtml_provider_verified" => true')
    assert_includes(source, 'source-built Bun does not resolve the staged Fedora lol-html provider')
    assert_includes(source, "new HTMLRewriter()")
    assert_includes(source, '"html_rewriter_smoke_verified" => true')
    assert_equal(1, source.scan(/"scripts\/build\/deps\/index\.ts"\s*=>\s*closure\.dig/).length)

    refute_includes(source, "--cargo-vendor")
    refute_includes(source, "cargo_receipt_path")
    refute_includes(source, "stable_lolhtml_cargo_verified")
    refute_includes(source, "expected 19 native source archives")
  end

  def test_npm_helper_supports_a_receipt_bound_source_built_driver
    source = File.read(NPM_SCRIPT)

    assert_includes(source, '--source-built-driver PATH')
    assert_includes(source, '--driver-receipt PATH')
    assert_includes(source, '"bun-first-source-build-proof/v2"')
    assert_includes(source, '"bun-self-rebuild-proof/v2"')
    assert_includes(source, '"bun-npm-offline-install-proof/v2"')
    assert_includes(source, '"source_built_driver_verified" => true')
    assert_includes(source, '"bootstrap_seed_not_used_for_install" => true')
    assert_includes(source, '"forbidden_bootstrap_seed"')
    assert_includes(source, 'source_driver_mode ? "source-built-npm-install-proof.json" : "npm-offline-install-proof.json"')
    assert_includes(source, 'command = ["unshare", "--net", "--", install_driver, "install"')
  end

  def test_self_rebuild_requires_the_source_built_npm_receipt
    source = File.read(SCRIPT)

    assert_includes(source, '--npm-receipt PATH')
    assert_includes(source, 'npm_receipt["schema"] == "bun-npm-offline-install-proof/v2"')
    assert_includes(source, 'npm_receipt.dig("driver", "receipt_sha256") == Digest::SHA256.file(driver_receipt_path).hexdigest')
    assert_includes(source, 'raise Agentlab::Error, "self-rebuild npm proof does not match the selected source-built driver"')
    assert_includes(source, 'npm_proof_mode = "historical_seed"')
    assert_includes(source, 'npm_proof_mode = "source_built"')
    assert_includes(source, 'configure_receipt.slice("npm_proof", "zig", "webkit", "source_patches", "offline_inputs")')
  end

  def test_npm_helper_rejects_ambiguous_driver_options_before_proof_setup
    _stdout, stderr, status = Open3.capture3(NPM_SCRIPT, "--source-built-driver", "/srv/tmp/missing-bun")
    refute(status.success?)
    assert_includes(stderr, "--driver-receipt is required with --source-built-driver")

    _stdout, stderr, status = Open3.capture3(NPM_SCRIPT, "--driver-receipt", "/srv/tmp/missing-receipt.json")
    refute(status.success?)
    assert_includes(stderr, "--driver-receipt requires --source-built-driver")

    _stdout, stderr, status = Open3.capture3(
      NPM_SCRIPT,
      "--seed-archive", "/srv/tmp/missing-seed.zip",
      "--source-built-driver", "/srv/tmp/missing-bun",
      "--driver-receipt", "/srv/tmp/missing-receipt.json"
    )
    refute(status.success?)
    assert_includes(stderr, "--seed-archive and --source-built-driver are mutually exclusive")
  end
end
