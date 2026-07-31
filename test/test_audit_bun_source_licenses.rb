# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "tmpdir"
load File.expand_path("../scripts/audit-bun-source-licenses", __dir__)

class BunSourceLicenseAuditTest < Minitest::Test
  def test_source_cache_names_cover_registry_and_github_sources
    closure = {
      "npm" => {
        "source_archives" => [
          {
            "archive" => "fixture.tgz",
            "origin" => "registry",
            "source_name" => "fixture",
            "source_version" => "1.2.3-cjs.1"
          },
          {
            "archive" => "github.tar.gz",
            "origin" => "github",
            "references" => [{ "install_root" => ".", "package_path" => "bun-tracestrings" }]
          }
        ],
        "install_roots" => [
          {
            "path" => ".",
            "sources" => [
              {
                "package_path" => "bun-tracestrings",
                "origin" => "github",
                "resolution" => "github:oven-sh/bun.report#912ca63e26c51429d3e6799aa2a6ab079b188fd8"
              }
            ]
          }
        ]
      }
    }

    assert_equal(
      {
        "fixture.tgz" => "fixture@1.2.3-ec7b5e1ef906f68d@@@1",
        "github.tar.gz" => "@GH@oven-sh-bun.report-912ca63e26c51429d3e6799aa2a6ab079b188fd8@@@1"
      },
      BunSourceLicenseAudit.source_cache_names(closure)
    )
  end

  def test_file_record_rejects_paths_outside_root
    Dir.mktmpdir("agentlab-bun-license-test-", "/srv/tmp") do |root|
      inside = File.join(root, "LICENSE")
      File.write(inside, "MIT\n")
      assert_equal("LICENSE", BunSourceLicenseAudit.file_record(inside, root).fetch("path"))
      assert_raises(BunSourceLicenseAudit::Error) do
        BunSourceLicenseAudit.file_record("/etc/hosts", root)
      end
    end
  end

  def test_native_license_map_matches_the_checked_component_set
    assert_equal(18, BunSourceLicenseAudit::NATIVE_LICENSE_PATHS.length)
    refute(BunSourceLicenseAudit::NATIVE_LICENSE_PATHS.key?("lolhtml"))
    assert_equal(%w[LICENSE LICENSE.chrome], BunSourceLicenseAudit::NATIVE_LICENSE_PATHS.fetch("lsquic"))
    assert_equal(["picohttpparser.c"], BunSourceLicenseAudit::NATIVE_LICENSE_PATHS.fetch("picohttpparser"))
  end

  def test_recursively_inventories_supplied_license_texts
    Dir.mktmpdir("agentlab-bun-license-test-", "/srv/tmp") do |root|
      package_root = File.join(root, "package")
      nested = File.join(package_root, "docs")
      FileUtils.mkdir_p(nested)
      File.write(File.join(nested, "LICENSE.txt"), "MIT\n")

      records = BunSourceLicenseAudit.license_file_records(package_root, root)

      assert_equal(["package/docs/LICENSE.txt"], records.map { |record| record.fetch("path") })
    end
  end

  def test_expected_npm_declarations_cover_all_checked_sources
    assert_equal(236, BunSourceLicenseAudit::EXPECTED_NPM_DECLARATIONS.values.sum)
    assert_equal(2, BunSourceLicenseAudit::EXPECTED_NPM_DECLARATIONS.fetch("<missing>"))
  end

  def test_supplemental_text_must_share_the_checked_source_directory
    Dir.mktmpdir("agentlab-bun-license-test-", "/srv/tmp") do |root|
      checked = File.join(root, "checked")
      outside = File.join(root, "outside")
      FileUtils.mkdir_p([checked, outside])
      license = File.join(outside, "bun-1.3.14-peechy-0.4.34-LICENSE.md")
      FileUtils.cp(File.expand_path("../packages/bun/bun-1.3.14-peechy-0.4.34-LICENSE.md", __dir__), license)
      source = { "sha256" => "135dcdcd42984756d18a31aedcb9a1b670261522542c6dc7c3fca6e1aa42534d" }
      manifest = { "name" => "peechy", "version" => "0.4.34", "license" => "MIT" }

      error = assert_raises(BunSourceLicenseAudit::Error) do
        BunSourceLicenseAudit.npm_supplemental_license_text(source, manifest, license, expected_directory: checked)
      end
      assert_match(/outside the checked source directory/, error.message)
    end
  end

  def test_checked_inventory_keeps_final_license_claims_false
    receipt = JSON.parse(File.read(File.expand_path("../packages/bun/bun-1.3.14-source-license-inventory.json", __dir__)))
    peechy = receipt.fetch("npm").fetch("records").find { |record| record["name"] == "peechy" && record["version"] == "0.4.34" }

    assert_equal([], peechy.fetch("license_files"))
    assert_equal(
      "a6f766e4ab93cbd6dbc17e58a3d33b09d09be18d2f67f3133005b038dbc5915e",
      peechy.dig("supplemental_license_text", "text", "sha256")
    )
    assert_equal(false, peechy.dig("supplemental_license_text", "exact_release_source_correspondence_verified"))

    %w[
      final_npm_installed_closure_verified
      final_linked_native_components_verified
      webkit_linked_file_semantic_review_verified
      fedora_allowed_spdx_verified
      required_license_texts_verified
      final_license_expression_verified
      rpm_payload_license_verified
    ].each do |key|
      assert_equal(false, receipt.dig("validation", key), key)
    end
    refute(receipt.key?("cargo"))
    assert_equal(18, receipt.fetch("native").length)
    assert_equal(true, receipt.dig("validation", "system_lolhtml_provider_external_to_bun_inventory"))
    assert_equal(
      "ed1cc04702f7b609a8a735edf0a1cc7c33ec22c5",
      receipt.dig("historical_evidence", "private_lolhtml_cargo_graph", "source_commit")
    )
  end
end
