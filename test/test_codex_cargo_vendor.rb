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
    assert_includes(spec, "%cargo_build -- -vv --package codex-cli --bin codex")
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
    assert_equal("agentlab-codex-cargo-supplemental-license-sources/v6", receipt.fetch("schema"))
    assert_equal(50, receipt.fetch("mappings").length)
    assert_empty(receipt.fetch("unresolved"))
    assert_equal(25, receipt.dig("archive", "installable_texts"))
    assert_equal("resolved-icu-data-comparison", receipt.dig("icu_mapping", "status"))
    assert_equal("1cf67874b5a87a8363a86fb3f81e3cbbed54d389062dab8fb52308d5cf8c8612", receipt.fetch("sources").find { |source| source.fetch("id") == "icu-data-payload" }.fetch("expected_extracted_sha256"))
    refute(receipt.fetch("sources").find { |source| source.fetch("id") == "icu-data-payload" }.fetch("install"))
    assert_includes(receipt.dig("icu_mapping", "reason"), "byte-identical")
    lock_free = receipt.fetch("mappings").find { |mapping| mapping.fetch("directory") == "lock_free_hashtable-0.1.4" }
    assert_equal("48ae5c61c93c808e0831b27104d3bc7262f06bd4", lock_free.fetch("source_commit"))
    assert_equal("exact-byte-equality", lock_free.dig("manifest_relation", "kind"))
    assert_equal(lock_free.dig("manifest_relation", "upstream_sha256"), lock_free.dig("manifest_relation", "vendor_sha256"))
    display = receipt.fetch("mappings").find { |mapping| mapping.fetch("directory") == "display_container-0.9.0" }
    assert_equal("13efb6d415c4729178dfccc36fa9c87491f0813d", display.fetch("source_commit"))
    assert_equal(%w[buck2-lock-free-mit apache-2.0-50e675], display.fetch("install_source_ids"))
    strong = receipt.fetch("mappings").find { |mapping| mapping.fetch("directory") == "strong_hash-0.1.0" }
    assert_equal("7ef58762149c23402d89f13af2cb293481ef950e", strong.fetch("source_commit"))
    assert_equal(%w[buck2-lock-free-mit apache-2.0-50e675], strong.fetch("install_source_ids"))
    sorted = receipt.fetch("mappings").find { |mapping| mapping.fetch("directory") == "sorted_vector_map-0.2.1" }
    assert_equal("756ae7daba100d194aa0260131937b7d96672549", sorted.fetch("source_commit"))
    assert_equal(%w[rust-shed-sorted-vector-map-mit rust-shed-sorted-vector-map-apache], sorted.fetch("install_source_ids"))
    assert_empty(receipt.fetch("policy_holds"))
    assert_equal(CodexSupplementalLicenses::FEDORA_NOTIFY_PRECEDENT, receipt.fetch("fedora_precedents").fetch(0))
    bech32 = receipt.fetch("mappings").find { |mapping| mapping.fetch("directory") == "bech32-0.9.1" }
    assert_equal("later-upstream-release", bech32.fetch("provenance_mode"))
    assert_equal("d965446196e3b7decd44aa7ee49e31d630118f90ef12f97900f262eb915c951d", bech32.dig("later_upstream_release", "archive_sha256"))
    bech32_source = receipt.fetch("sources").find { |source| source.fetch("id") == "bech32-0.11.0-mit" }
    assert_equal("d965446196e3b7decd44aa7ee49e31d630118f90ef12f97900f262eb915c951d", bech32_source.fetch("expected_transport_sha256"))
    canonical = {
      "debugserver-types-0.5.0" => ["https://github.com/Marwes/debugserver-types/issues/5", %w[spdx-mit]],
      "eventsource-stream-0.2.3" => ["https://github.com/jpopesculian/eventsource-stream/issues/14", %w[spdx-mit spdx-apache]],
      "io_tee-0.1.1" => ["https://github.com/TheOnlyMrCat/io_tee/issues/1", %w[spdx-mit spdx-apache]],
      "linux-keyutils-0.2.4" => ["https://github.com/landhb/linux-keyutils/issues/21", %w[spdx-apache spdx-mit]],
      "sse-stream-0.2.1" => ["https://github.com/4t145/sse-stream/issues/14", %w[spdx-mit spdx-apache]]
    }
    canonical.each do |directory, (issue, source_ids)|
      mapping = receipt.fetch("mappings").find { |item| item.fetch("directory") == directory }
      assert_equal("canonical-standard", mapping.fetch("provenance_mode"))
      assert_equal(issue, mapping.dig("upstream_request", "url"))
      assert_equal(source_ids, mapping.fetch("source_ids"))
      assert_equal("/srv/wikis/agentlab/policies.md:55", mapping.fetch("policy_basis"))
    end
  end

  def test_supplemental_temporary_root_honors_buildroot_tmpdir
    Dir.mktmpdir do |directory|
      previous = ENV["TMPDIR"]
      ENV["TMPDIR"] = directory
      assert_equal(directory, CodexSupplementalLicenses.temporary_root)
    ensure
      ENV["TMPDIR"] = previous
    end
  end

  def test_supplemental_evidence_population_skips_later_release_archives
    receipt = {
      "sources" => [{ "id" => "later-license", "immutable_url" => "https://static.crates.io/crates/example/example-1.0.0.crate" }],
      "mappings" => [{ "provenance_mode" => "later-upstream-release", "source_ids" => ["later-license"] }]
    }

    CodexSupplementalLicenses.populate_mapping_evidence!(receipt)

    refute(receipt.fetch("mappings").first.key?("license_evidence"))
  end

  def test_supplemental_contract_rejects_stale_transport_and_bad_spec_order
    receipt = JSON.parse(File.read(File.join(PACKAGE, "codex-cli-0.144.5-cargo-supplemental-license-sources.json")))
    icu = receipt.fetch("sources").find { |source| source.fetch("id") == "icu-data-payload" }
    assert_nil(icu.fetch("expected_transport_sha256"))
    assert_empty(receipt.fetch("unresolved"))
    assert_empty(receipt.fetch("policy_holds"))
    assert_equal("rust-notify-8.2.0-2.fc44", receipt.dig("fedora_precedents", 0, "source_nvr"))
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
    assert_nil(CodexSupplementalLicenses.validate_unresolved!([], inventory, audit))
    unresolved = [{ "directory" => "missing-1", "crate_checksum" => "good", "declared_expression" => "MIT" }]
    assert_raises(CodexCargoVendor::Error) { CodexSupplementalLicenses.validate_unresolved!(unresolved, inventory, audit) }
    precedent = Marshal.load(Marshal.dump(CodexSupplementalLicenses::FEDORA_NOTIFY_PRECEDENT))
    assert_raises(CodexCargoVendor::Error) { CodexSupplementalLicenses.validate_notify_precedent!(precedent, inventory, audit) }
    Dir.mktmpdir do |dir|
      path = File.join(dir, "transport")
      File.binwrite(path, "not-the-expected-transport")
      assert_raises(CodexCargoVendor::Error) { CodexSupplementalLicenses.verify_transport!(path, { "id" => "icu", "expected_transport_sha256" => "0" * 64 }) }
    end
  end

  def test_v4_provenance_rejection_helpers
    assert_raises(CodexCargoVendor::Error) { CodexSupplementalLicenses.validate_mapping_mode!("made-up") }
    relation = {
      "kind" => "exact-byte-equality",
      "upstream_sha256" => Digest::SHA256.hexdigest("upstream"), "upstream_size_bytes" => 8,
      "vendor_sha256" => Digest::SHA256.hexdigest("vendor"), "vendor_size_bytes" => 6
    }
    assert_raises(CodexCargoVendor::Error) { CodexSupplementalLicenses.validate_release_manifest_relation!(relation, "wrong", "vendor") }
    assert_raises(CodexCargoVendor::Error) { CodexSupplementalLicenses.validate_release_manifest_relation!(relation, "upstream", "different") }
    canonical = {
      "directory" => "fxhash-0.2.1", "crate_checksum" => "crate", "declared_expression" => "Apache-2.0 OR MIT",
      "source_repository" => "https://github.com/cbreeden/fxhash", "provenance_mode" => "canonical-standard",
      "source_ids" => ["mit", "apache"], "install_source_ids" => ["mit", "apache"],
      "upstream_request" => { "url" => "https://github.com/other/fxhash/issues/9", "status" => "open", "scope" => "Ship the declared texts." },
      "policy_basis" => "/srv/wikis/agentlab/policies.md:55",
      "canonical_authority" => { "repository" => "https://github.com/spdx/license-list-data", "tag" => "v3.28.0", "commit" => "c4a7237ec8f4654e867546f9f409749300f1bf4c" }
    }
    sources = {
      "mit" => { "immutable_url" => "https://raw.githubusercontent.com/spdx/license-list-data/c4a7237ec8f4654e867546f9f409749300f1bf4c/text/MIT.txt", "spdx_ids" => ["MIT"], "install" => true, "expected_extracted_sha256" => "m", "expected_extracted_size_bytes" => 1 },
      "apache" => { "immutable_url" => "https://raw.githubusercontent.com/spdx/license-list-data/c4a7237ec8f4654e867546f9f409749300f1bf4c/text/Apache-2.0.txt", "spdx_ids" => ["Apache-2.0"], "install" => true, "expected_extracted_sha256" => "a", "expected_extracted_size_bytes" => 1 }
    }
    assert_raises(CodexCargoVendor::Error) { CodexSupplementalLicenses.validate_mapping_structure!(canonical, sources) }
    canonical["upstream_request"]["url"] = "https://github.com/cbreeden/fxhash/issues/9"
    canonical["upstream_request"]["status"] = "closed"
    assert_raises(CodexCargoVendor::Error) { CodexSupplementalLicenses.validate_mapping_structure!(canonical, sources) }
    canonical["upstream_request"]["status"] = "open"
    canonical["canonical_authority"]["tag"] = "v0"
    assert_raises(CodexCargoVendor::Error) { CodexSupplementalLicenses.validate_mapping_structure!(canonical, sources) }
    canonical["canonical_authority"]["tag"] = "v3.28.0"
    canonical["policy_basis"] = "wrong"
    assert_raises(CodexCargoVendor::Error) { CodexSupplementalLicenses.validate_mapping_structure!(canonical, sources) }
    canonical["policy_basis"] = "/srv/wikis/agentlab/policies.md:55"
    canonical["source_commit"] = "0" * 40
    assert_raises(CodexCargoVendor::Error) { CodexSupplementalLicenses.validate_mapping_structure!(canonical, sources) }
    canonical.delete("source_commit")
    sources["apache-evidence"] = sources.fetch("apache").merge("install" => false, "expected_extracted_sha256" => "different")
    canonical["source_ids"] = ["mit", "apache-evidence"]
    assert_raises(CodexCargoVendor::Error) { CodexSupplementalLicenses.validate_mapping_structure!(canonical, sources) }
  end
end
