# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "yaml"

class ProveBunFirstSourceBuildTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  SCRIPT = File.join(ROOT, "scripts", "prove-bun-first-source-build")
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

    refute_includes(source, "--cargo-vendor")
    refute_includes(source, "cargo_receipt_path")
    refute_includes(source, "stable_lolhtml_cargo_verified")
    refute_includes(source, "expected 19 native source archives")
  end
end
