# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "open3"

class PlanBunSrpmSourcesTest < Minitest::Test
  SCRIPT = File.expand_path("../scripts/plan-bun-srpm-sources", __dir__)

  def run_script(*arguments)
    stdout, stderr, status = Open3.capture3(SCRIPT, *arguments)
    assert(status.success?, stderr)
    stdout
  end

  def test_emits_a_deterministic_host_independent_plan
    first = run_script
    second = run_script
    assert_equal(first, second)

    plan = JSON.parse(first)
    assert_equal("bun-srpm-source-plan/v1", plan["schema"])
    assert_equal("1.3.14", plan["release"])
    assert_equal("copr-git-scm-make_srpm", plan.dig("delivery", "planned_method"))
    assert_equal("planned", plan.dig("delivery", "implementation_state"))
    assert_equal("srpm-generation-only", plan.dig("delivery", "planned_network_scope"))
    refute(plan.dig("delivery", "target_build_network_allowed"))
    refute(plan.dig("delivery", "external_generated_artifact_host_required_by_design"))
    refute(plan.dig("delivery", "make_srpm_materializer_integrated"))
    refute(plan.dig("delivery", "make_srpm_checksum_verification_integrated"))
    assert_equal({ "native" => 19, "node" => 1, "npm" => 236, "cargo" => 43 }, plan.fetch("input_summary").slice("native", "node", "npm", "cargo"))
    assert_equal(%w[bun-release zig-source], plan.fetch("direct_sources").map { |source| source.fetch("role") })
    assert_equal(
      %w[lolhtml-cargo-vendor native-node-source-bundle npm-source-bundle webkit-source],
      plan.fetch("generated_sources").map { |source| source.fetch("role") }
    )
    webkit = plan.fetch("generated_sources").find { |source| source.fetch("role") == "webkit-source" }
    assert_equal("WebKit-5488984d20e0dbfe4be2c3ba8fb18eb81a5e0e8b-jsc-only.tar.gz", webkit.fetch("filename"))
    assert_equal("bun-webkit-minimized-source/v1", webkit.fetch("recipe"))
    assert_equal("909d4b08612356159103fec95190b629754e460196404fa3fb3bd14e706eaa3b", webkit.fetch("expected_sha256"))
    assert_equal(93_056_181, webkit.fetch("expected_size_bytes"))
    refute(plan.dig("delivery", "architecture_independent_outputs_required"))
    assert_equal(
      [{ "role" => "webkit-source", "architectures" => ["x86_64"] }],
      plan.dig("delivery", "architecture_scoped_outputs")
    )
    assert(plan.dig("validation", "webkit_spec_integrated"))
    refute(plan.dig("validation", "generated_sources_materialized"))
    refute(plan.dig("validation", "delivery_implementation_verified"))
    refute(plan.dig("validation", "bun_spec_integrated"))
    refute(plan.dig("validation", "srpm_built"))
  end

  def test_check_mode_reports_the_bound_closure
    output = run_script("--check")

    assert_includes(output, "Verified Bun 1.3.14 SRPM source plan")
    assert_includes(output, "2 direct sources")
    assert_includes(output, "4 generated sources")
    assert_includes(output, "299 checked closure inputs")
  end
end
