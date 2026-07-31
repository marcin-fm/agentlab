# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "yaml"
load File.expand_path("../scripts/audit-opencode-final-licenses", __dir__) unless defined?(OpenCodeFinalLicenseAudit)

class OpenCodeFinalLicenseAuditTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  OPENCODE = File.join(ROOT, "packages", "opencode")
  BUN = File.join(ROOT, "packages", "bun")

  def paths
    {
      binary_embedding_path: File.join(OPENCODE, "opencode-1.18.8-binary-embedding.json"),
      source_license_set_path: File.join(OPENCODE, "source-license-set-proof.json"),
      license_review_path: File.join(OPENCODE, "license-review.yml"),
      native_review_path: File.join(OPENCODE, "native-review.yml"),
      bun_final_license_path: File.join(BUN, "bun-1.3.14-final-linked-license-closure.json")
    }
  end

  def parsed_inputs
    {
      binary_embedding: JSON.parse(File.read(paths.fetch(:binary_embedding_path))),
      source_license_set: JSON.parse(File.read(paths.fetch(:source_license_set_path))),
      license_review: YAML.safe_load(File.read(paths.fetch(:license_review_path)), aliases: false),
      native_review: YAML.safe_load(File.read(paths.fetch(:native_review_path)), aliases: false),
      bun_final_license: JSON.parse(File.read(paths.fetch(:bun_final_license_path)))
    }
  end

  def records
    {
      "binary_embedding" => OpenCodeFinalLicenseAudit.repo_record(paths.fetch(:binary_embedding_path)),
      "source_license_set" => OpenCodeFinalLicenseAudit.repo_record(paths.fetch(:source_license_set_path)),
      "license_review" => OpenCodeFinalLicenseAudit.repo_record(paths.fetch(:license_review_path)),
      "native_review" => OpenCodeFinalLicenseAudit.repo_record(paths.fetch(:native_review_path)),
      "bun_final_linked_license_closure" => OpenCodeFinalLicenseAudit.repo_record(paths.fetch(:bun_final_license_path))
    }
  end

  def build(inputs)
    OpenCodeFinalLicenseAudit.build(
      **inputs,
      input_records: records,
      auditor_record: OpenCodeFinalLicenseAudit.repo_record(File.join(ROOT, "scripts", "audit-opencode-final-licenses")),
      audit_date: "2026-07-31"
    )
  end

  def test_checked_receipt_matches_live_inputs_without_legal_overclaim
    actual = OpenCodeFinalLicenseAudit.generate(**paths, audit_date: "2026-07-31")
    checked = JSON.parse(File.read(File.join(OPENCODE, "opencode-1.18.8-final-license-closure.json")))

    assert_equal(checked, actual)
    assert_equal(3, actual.dig("unresolved", "opencode_notice_holds").length)
    assert_equal(6, actual.dig("unresolved", "bun_webkit_headerless_files").length)
    assert_equal(true, actual.dig("validation", "native_wasm_source_mapping_verified"))
    assert_equal(true, actual.dig("validation", "bun_final_link_mapping_verified"))
    %w[
      all_required_license_texts_verified final_aggregate_license_expression_verified
      rpm_license_payload_complete clean_fedora_build_matrix_verified copr_submission_verified
    ].each do |flag|
      assert_equal(false, actual.dig("validation", flag), flag)
    end
  end

  def test_rejects_removed_opencode_notice_hold
    inputs = parsed_inputs
    inputs.dig(:license_review, "embedded_package_local_text_holds", "packages").pop

    assert_raises(OpenCodeFinalLicenseAudit::Error) { build(inputs) }
  end

  def test_rejects_bun_final_license_overclaim
    inputs = parsed_inputs
    inputs.dig(:bun_final_license, "validation")["final_license_expression_verified"] = true

    assert_raises(OpenCodeFinalLicenseAudit::Error) { build(inputs) }
  end
end
