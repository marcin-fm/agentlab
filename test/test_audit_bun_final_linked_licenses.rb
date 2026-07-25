# frozen_string_literal: true

require "json"
require "minitest/autorun"
load File.expand_path("../scripts/audit-bun-final-linked-licenses", __dir__)

class BunFinalLinkedLicenseAuditTest < Minitest::Test
  def test_parses_and_classifies_the_final_link
    ninja = <<~NINJA
      build bun-profile: link obj/vendor/foo/a.o obj/src/main.o $ 
          bun-zig.0.o deps/WebKit/lib/libWTF.a | source/src/symbols.dyn
        ldflags = -lc -llolhtml
    NINJA

    parsed = BunFinalLinkedLicenseAudit.parse_final_link(ninja)
    assert_equal(%w[obj/vendor/foo/a.o obj/src/main.o bun-zig.0.o], parsed.fetch("objects"))
    assert_equal(["deps/WebKit/lib/libWTF.a"], parsed.fetch("archives"))
    assert_equal({ "bun" => %w[bun-zig.0.o obj/src/main.o], "foo" => ["obj/vendor/foo/a.o"] }, BunFinalLinkedLicenseAudit.classify_objects(parsed.fetch("objects"), ["foo"]))
  end

  def test_rejects_unknown_and_missing_native_components
    assert_raises(BunFinalLinkedLicenseAudit::Error) do
      BunFinalLinkedLicenseAudit.classify_objects(["obj/vendor/unknown/a.o"], ["foo"])
    end
    assert_raises(BunFinalLinkedLicenseAudit::Error) do
      BunFinalLinkedLicenseAudit.classify_objects(["obj/src/main.o"], ["foo"])
    end
  end

  def test_checked_receipt_maps_every_input_without_legal_overclaim
    receipt = JSON.parse(File.read(File.expand_path("../packages/bun/bun-1.3.14-final-linked-license-closure.json", __dir__)))

    assert_equal(1165, receipt.dig("final_link", "linked_input_count"))
    assert_equal(19, receipt.fetch("components").length)
    assert_equal(18, receipt.fetch("components").count { |component| component.fetch("kind") == "bundled_native_source" })
    assert_equal(true, receipt.dig("validation", "final_link_inputs_mapped"))
    assert_equal(true, receipt.dig("validation", "partial_native_license_selection_verified"))
    assert_equal(15, receipt.fetch("components").count { |component| component.fetch("kind") == "bundled_native_source" && component.fetch("license_selection_verified") })
    assert_equal(%w[libarchive libjpeg-turbo libwebp], receipt.dig("unresolved", "native_license_selections"))
    assert_equal(%w[libarchive libjpeg-turbo libwebp], receipt.dig("unresolved", "native_license_details").map { |record| record.fetch("name") })
    %w[
      native_license_selections_verified webkit_linked_file_semantic_review_verified
      final_npm_codegen_closure_verified fedora_allowed_spdx_verified required_license_texts_verified
      final_license_expression_verified rpm_payload_license_verified
    ].each do |key|
      assert_equal(false, receipt.dig("validation", key), key)
    end
  end
end
