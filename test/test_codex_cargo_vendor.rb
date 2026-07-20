# frozen_string_literal: true

require "digest"
require "json"
require "minitest/autorun"
require "yaml"
require "tmpdir"
load File.expand_path("../scripts/prepare-codex-cargo-license-sources", __dir__)

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

  def test_checked_cargo_license_text_inventory
    package = YAML.safe_load_file(File.join(PACKAGE, "package.yml"))
    policy = package.fetch("source_policy")
    receipt_path = File.join(PACKAGE, policy.fetch("cargo_license_text_inventory"))
    receipt = JSON.parse(File.read(receipt_path))

    assert_equal(policy.fetch("cargo_license_text_inventory_sha256"), Digest::SHA256.file(receipt_path).hexdigest)
    assert_equal("agentlab-codex-cargo-license-text-inventory/v1", receipt.fetch("schema"))
    assert_equal(1_124, receipt.dig("counts", "vendor_directories"))
    assert_equal(1_020, receipt.dig("counts", "directories_with_package_local_license_texts"))
    assert_equal(104, receipt.dig("counts", "directories_without_package_local_license_texts"))
    assert_equal(51, receipt.dig("counts", "linked_linux_directories_without_package_local_license_texts"))
    assert_equal(1_016, receipt.dig("counts", "directories_with_top_level_license_texts"))
    assert_equal(108, receipt.dig("counts", "directories_without_top_level_license_texts"))
    assert_equal(54, receipt.dig("counts", "linked_linux_directories_without_top_level_license_texts"))
    assert(receipt.dig("validation", "all_vendor_directories_accounted"))
    refute(receipt.dig("validation", "all_vendor_directories_have_package_local_license_texts"))
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
    assert_includes(spec, "%cargo_build -- --package codex-cli --bin codex")
    assert_includes(spec, "install -Dpm0755 codex-rs/target/rpm/codex")
    assert_includes(spec, "%license %{_licensedir}/%{name}/cargo-vendor.txt")
    assert_includes(spec, "CODEX_HOME=\"$PWD/.codex-home\" codex-rs/target/rpm/codex doctor")
    assert_includes(makefile, "codex-cli.spec)")
    assert_includes(makefile, 'scripts/prepare-codex-cargo-srpm-sources" --spec "$(spec)"')
    assert_includes(makefile, 'scripts/prepare-codex-cargo-license-sources" --spec "$(spec)"')
  end

  def test_checked_supplemental_license_sources
    package = YAML.safe_load_file(File.join(PACKAGE, "package.yml"))
    policy = package.fetch("source_policy")
    path = File.join(PACKAGE, policy.fetch("cargo_supplemental_license_sources"))
    receipt = JSON.parse(File.read(path))

    assert_equal(policy.fetch("cargo_supplemental_license_sources_sha256"), Digest::SHA256.file(path).hexdigest)
    assert_equal(33, receipt.fetch("mappings").length)
    assert_equal(17, receipt.fetch("unresolved").length)
    assert_equal(15, receipt.dig("archive", "installable_texts"))
    assert_equal("resolved-icu-data-comparison", receipt.dig("icu_mapping", "status"))
    assert_equal("1cf67874b5a87a8363a86fb3f81e3cbbed54d389062dab8fb52308d5cf8c8612", receipt.fetch("sources").find { |source| source.fetch("id") == "icu-data-payload" }.fetch("expected_extracted_sha256"))
    assert(receipt.fetch("policy_holds").one? { |hold| hold.fetch("directory") == "notify-8.2.0" })
  end

  def test_supplemental_contract_rejects_stale_transport_and_bad_spec_order
    receipt = JSON.parse(File.read(File.join(PACKAGE, "codex-cli-0.144.5-cargo-supplemental-license-sources.json")))
    icu_sources = receipt.fetch("sources").select { |source| source.fetch("kind") == "archive_member" }
    assert_equal([nil], icu_sources.map { |source| source.fetch("expected_transport_sha256") }.uniq)
    assert_equal(17, receipt.fetch("unresolved").map { |item| item.fetch("directory") }.uniq.length)
    refute(receipt.fetch("unresolved").any? { |item| item.fetch("crate_checksum") == "" })
    hold = receipt.fetch("policy_holds").fetch(0)
    assert_equal("CC0-1.0", hold.fetch("declared_expression"))
    spec = File.read(File.join(PACKAGE, "codex-cli.spec"))
    assert_operator(spec.index("ruby .agentlab-codex-source-tools/prepare-codex-cargo-license-sources"), :<, spec.index("tar --extract --gzip --file %{SOURCE15}"))
  end

  def test_supplemental_rejection_helpers
    inventory = {
      "missing-1" => { "linked_linux" => true, "license_texts" => [] },
      "notify-8.2.0" => { "license_texts" => [{ "path" => "LICENSE-CC0", "sha256" => "text", "size_bytes" => 7 }] }
    }
    audit = {
      "missing-1" => { "checksum" => "good", "normalized_spdx_candidate" => "MIT" },
      "notify-8.2.0" => { "checksum" => "notify", "normalized_spdx_candidate" => "CC0-1.0" }
    }
    unresolved = Array.new(17) { { "directory" => "missing-1", "crate_checksum" => "good", "declared_expression" => "MIT" } }
    unresolved[0] = unresolved[0].merge("crate_checksum" => "bad")
    assert_raises(CodexCargoVendor::Error) { CodexSupplementalLicenses.validate_unresolved!(unresolved, inventory, audit) }
    assert_raises(CodexCargoVendor::Error) { CodexSupplementalLicenses.validate_unresolved!(unresolved.take(16), inventory, audit) }
    hold = { "crate_checksum" => "notify", "declared_expression" => "MIT", "license_text_sha256" => "text", "license_text_size_bytes" => 7 }
    assert_raises(CodexCargoVendor::Error) { CodexSupplementalLicenses.validate_notify_hold!(hold, inventory, audit) }
    Dir.mktmpdir do |dir|
      path = File.join(dir, "transport")
      File.binwrite(path, "not-the-expected-transport")
      assert_raises(CodexCargoVendor::Error) { CodexSupplementalLicenses.verify_transport!(path, { "id" => "icu", "expected_transport_sha256" => "0" * 64 }) }
    end
  end
end
