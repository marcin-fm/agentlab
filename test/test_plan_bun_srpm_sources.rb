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
    assert_equal("verified", plan.dig("delivery", "implementation_state"))
    assert_equal("srpm-generation-only", plan.dig("delivery", "planned_network_scope"))
    refute(plan.dig("delivery", "target_build_network_allowed"))
    refute(plan.dig("delivery", "external_generated_artifact_host_required_by_design"))
    assert_equal(
      {
        "native_node" => "direct-upstream-source-tags",
        "npm" => "generated-original-archive-bundle",
        "cargo" => "generated-cargo-vendor-archive",
        "relink" => "generated-build-output-payload"
      },
      plan.dig("delivery", "source_layout")
    )
    assert(plan.dig("delivery", "make_srpm_materializer_integrated"))
    assert(plan.dig("delivery", "make_srpm_checksum_verification_integrated"))
    assert_equal({ "native" => 19, "node" => 1, "npm" => 236, "cargo" => 43 }, plan.fetch("input_summary").slice("native", "node", "npm", "cargo"))
    assert_equal(23, plan.fetch("direct_sources").length)
    assert_equal(19, plan.fetch("direct_sources").count { |source| source.fetch("role") == "native-source" })
    assert_equal(1, plan.fetch("direct_sources").count { |source| source.fetch("role") == "node-headers" })
    assert_equal(%w[bun-release webkit-source zig-source], plan.fetch("direct_sources").filter_map { |source| source.fetch("role") unless %w[native-source node-headers].include?(source.fetch("role")) })
    assert_equal(
      %w[lolhtml-cargo-vendor npm-source-bundle],
      plan.fetch("generated_sources").map { |source| source.fetch("role") }
    )
    native_sources = plan.fetch("direct_sources").select { |source| source.fetch("role") == "native-source" }
    assert(native_sources.all? { |source| source.fetch("url").start_with?("https://") })
    assert(native_sources.all? { |source| source.fetch("sha256").match?(/\A[0-9a-f]{64}\z/) })
    node_headers = plan.fetch("direct_sources").find { |source| source.fetch("role") == "node-headers" }
    assert_equal("24.3.0", node_headers.fetch("version"))
    assert_equal("137", node_headers.fetch("abi"))
    webkit = plan.fetch("direct_sources").find { |source| source.fetch("role") == "webkit-source" }
    assert_equal("WebKit-5488984d20e0dbfe4be2c3ba8fb18eb81a5e0e8b-jsc.tar.gz", webkit.fetch("filename"))
    assert_equal("https://github.com/marcin-fm/agentlab/releases/download/bun-sources-1.3.14-webkit-5488984d20e0/WebKit-5488984d20e0dbfe4be2c3ba8fb18eb81a5e0e8b-jsc.tar.gz", webkit.fetch("url"))
    assert_equal("38253c470959d729a196a543d6fce9e8aacc378ffc492790ded2b69598d7213d", webkit.fetch("sha256"))
    assert_equal(95_923_474, webkit.fetch("size_bytes"))
    assert_equal("dcf7d67f6bced499d961d20c29a1dc12cead88650c7d9f79a830082969e744d8", webkit.fetch("tree_sha256"))
    assert_equal("webkit-minimized-source-proof.json", webkit.fetch("source_receipt"))
    assert_equal("01b4549178b6469c4969b46dc1a5e31c17efdfb84d684d5ca192935227c89680", webkit.fetch("source_receipt_sha256"))
    assert_equal("bun-sources-1.3.14-webkit-5488984d20e0", webkit.fetch("release_tag"))
    assert_equal(356_148_272, webkit.fetch("release_id"))
    assert_equal("https://github.com/marcin-fm/agentlab/releases/tag/bun-sources-1.3.14-webkit-5488984d20e0", webkit.fetch("release_url"))
    assert_equal("e5a37cdf6eedddc449d62fc327dd6860638d03e8", webkit.fetch("release_target_commit"))
    assert_equal(true, webkit.fetch("release_immutable"))
    assert_equal("https://github.com/marcin-fm/agentlab/attestations/35973789", webkit.fetch("artifact_attestation_url"))
    assert_equal("https://github.com/marcin-fm/agentlab/actions/runs/29670935833", webkit.fetch("publication_run"))
    assert(plan.dig("delivery", "architecture_independent_outputs_required"))
    assert_equal([], plan.dig("delivery", "architecture_scoped_outputs"))
    assert(plan.dig("validation", "webkit_spec_integrated"))
    assert(plan.dig("validation", "fedora_source_layout_selected"))
    assert(plan.dig("validation", "generated_sources_materialized"))
    assert(plan.dig("validation", "delivery_implementation_verified"))
    assert(plan.dig("validation", "bun_spec_integrated"))
    assert(plan.dig("validation", "srpm_built"))
  end

  def test_check_mode_reports_the_bound_closure
    output = run_script("--check")

    assert_includes(output, "Verified Bun 1.3.14 SRPM source plan")
    assert_includes(output, "23 direct sources")
    assert_includes(output, "2 generated sources")
    assert_includes(output, "299 checked closure inputs")
  end
end
