# frozen_string_literal: true

require "digest"
require "json"
require "minitest/autorun"
require "yaml"

class CodexCargoVendorTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  PACKAGE = File.join(ROOT, "packages", "codex-cli")

  def test_checked_resolver_source_contract
    package = YAML.safe_load_file(File.join(PACKAGE, "package.yml"))
    dependencies = YAML.safe_load_file(File.join(PACKAGE, "dependencies.yml"))
    policy = package.fetch("source_policy")
    resolver = dependencies.fetch("resolver_vendor_evidence")
    receipt_path = File.join(PACKAGE, policy.fetch("resolver_vendor_receipt"))
    receipt = JSON.parse(File.read(receipt_path))

    assert_equal(policy.fetch("resolver_vendor_receipt_sha256"), Digest::SHA256.file(receipt_path).hexdigest)
    assert_equal(policy.fetch("resolver_vendor_receipt_sha256"), resolver.fetch("receipt_sha256"))
    assert_equal("agentlab-codex-resolver-cargo-vendor/v2", receipt.fetch("schema"))
    assert_equal(1_124, receipt.dig("counts", "vendor_directories"))
    assert_equal(policy.fetch("resolver_vendor_tree_sha256"), receipt.dig("vendor_tree", "sha256"))
    assert_equal(policy.fetch("resolver_vendor_manifest_sha256"), receipt.dig("vendor_manifest", "sha256"))
    assert_equal(policy.fetch("resolver_vendor_config_sha256"), receipt.dig("cargo_config", "sha256"))
    refute(receipt.dig("archive", "transport_identity_required"))
    assert(receipt.dig("archive", "tree_identity_required"))
    refute(receipt.fetch("archive").key?("sha256"))
    refute(receipt.fetch("archive").key?("size_bytes"))
    assert(policy.fetch("resolver_vendor_production_build_input"))
    assert(resolver.fetch("production_build_input"))
  end

  def test_spec_and_source_builder_bind_checked_tools
    package = YAML.safe_load_file(File.join(PACKAGE, "package.yml"))
    policy = package.fetch("source_policy")
    spec = File.read(File.join(PACKAGE, "codex-cli.spec"))
    makefile = File.read(File.join(ROOT, ".copr", "Makefile"))
    scripts = {
      "cargo_audit_sha256" => ["audit-codex-cargo-closure", policy.fetch("cargo_audit_script_sha256")],
      "source_preparer_sha256" => ["prepare-codex-cargo-srpm-sources", policy.fetch("cargo_source_preparer_sha256")],
      "vendor_verifier_sha256" => ["lib/codex_cargo_vendor.rb", policy.fetch("cargo_vendor_verifier_sha256")]
    }

    scripts.each do |macro, (relative, expected_sha256)|
      assert_equal(expected_sha256, Digest::SHA256.file(File.join(ROOT, "scripts", relative)).hexdigest)
      assert_equal(expected_sha256, spec[/^%global #{macro}\s+(\h{64})$/, 1])
    end
    assert_includes(spec, "%cargo_prep -N")
    assert_includes(spec, "%{__cargo_to_rpm} -p %{SOURCE11} parse-vendor-manifest")
    assert_includes(spec, 'test "$(wc -l < cargo-bundled-provides.txt)" -eq 1124')
    assert_includes(spec, "cmp cargo-vendor.txt %{SOURCE11}")
    assert_includes(makefile, "codex-cli.spec)")
    assert_includes(makefile, 'scripts/prepare-codex-cargo-srpm-sources" --spec "$(spec)"')
  end
end
