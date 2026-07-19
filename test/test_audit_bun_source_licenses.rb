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
    assert_equal(19, BunSourceLicenseAudit::NATIVE_LICENSE_PATHS.length)
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

  def test_checked_inventory_keeps_final_license_claims_false
    receipt = JSON.parse(File.read(File.expand_path("../packages/bun/bun-1.3.14-source-license-inventory.json", __dir__)))

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
  end
end
