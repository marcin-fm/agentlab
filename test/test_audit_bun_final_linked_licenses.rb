# frozen_string_literal: true

require "json"
require "minitest/autorun"
load File.expand_path("../scripts/audit-bun-final-linked-licenses", __dir__)

class BunFinalLinkedLicenseAuditTest < Minitest::Test
  def test_parses_and_classifies_the_final_link
    ninja = <<~NINJA
      build bun-profile: link obj/vendor/foo/a.o obj/vendor/libjpeg-turbo/jcapimin.c.o obj/vendor/libjpeg-turbo/jbun_stubs.c.o obj/src/main.o $ 
          bun-zig.0.o deps/WebKit/lib/libWTF.a | source/src/symbols.dyn
        ldflags = -lc -llolhtml
    NINJA

    parsed = BunFinalLinkedLicenseAudit.parse_final_link(ninja)
    assert_equal(%w[obj/vendor/foo/a.o obj/vendor/libjpeg-turbo/jcapimin.c.o obj/vendor/libjpeg-turbo/jbun_stubs.c.o obj/src/main.o bun-zig.0.o], parsed.fetch("objects"))
    assert_equal(["deps/WebKit/lib/libWTF.a"], parsed.fetch("archives"))
    assert_equal({ "bun" => %w[bun-zig.0.o obj/src/main.o obj/vendor/libjpeg-turbo/jbun_stubs.c.o], "foo" => ["obj/vendor/foo/a.o"], "libjpeg-turbo" => ["obj/vendor/libjpeg-turbo/jcapimin.c.o"] }, BunFinalLinkedLicenseAudit.classify_objects(parsed.fetch("objects"), ["foo", "libjpeg-turbo"]))
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

    assert_equal("bun-final-linked-license-closure/v3", receipt.fetch("schema"))
    assert_equal(1165, receipt.dig("final_link", "linked_input_count"))
    assert_equal(19, receipt.fetch("components").length)
    assert_equal(18, receipt.fetch("components").count { |component| component.fetch("kind") == "bundled_native_source" })
    assert_equal(true, receipt.dig("validation", "final_link_inputs_mapped"))
    assert_equal(true, receipt.dig("validation", "native_license_selection_review_verified"))
    assert_equal(true, receipt.dig("validation", "native_license_selections_verified"))
    assert_equal(true, receipt.dig("validation", "bundled_native_selected_spdx_verified"))
    assert_equal(true, receipt.dig("validation", "bundled_native_selected_license_texts_verified"))
    assert_equal(true, receipt.dig("validation", "npm_codegen_selected_spdx_verified"))
    assert_equal(true, receipt.dig("validation", "npm_codegen_selected_license_texts_verified"))
    assert_equal(18, receipt.dig("selected_license_evidence", "bundled_native", "component_count"))
    assert_equal(23, receipt.dig("selected_license_evidence", "bundled_native", "selected_license_file_count"))
    assert_equal(38, receipt.dig("selected_license_evidence", "npm_codegen_inputs", "package_count"))
    assert_equal(38, receipt.dig("selected_license_evidence", "npm_codegen_inputs", "packages_with_required_text"))
    assert_equal([], receipt.dig("selected_license_evidence", "npm_codegen_inputs", "packages_missing_required_text"))
    assert_equal(true, receipt.dig("selected_license_evidence", "npm_codegen_inputs", "generator_execution_reproduced"))
    assert_equal(true, receipt.dig("selected_license_evidence", "npm_codegen_inputs", "final_codegen_provenance_verified"))
    assert_equal(BunFinalLinkedLicenseAudit::SCOPE, receipt.fetch("scope"))
    assert_equal(true, receipt.dig("unresolved", "npm_and_codegen_final_payload_provenance"))
    assert_equal(true, receipt.dig("validation", "generator_execution_reproduced"))
    assert_equal(true, receipt.dig("validation", "webkit_member_source_mapping_verified"))
    assert_equal(true, receipt.dig("validation", "webkit_license_marker_inventory_verified"))
    assert_equal(531, receipt.dig("webkit", "archive_member_count"))
    assert_equal(1601, receipt.dig("webkit", "resolved_source_count"))
    assert_equal(5098, receipt.dig("webkit", "transitive_dependencies", "unique_dependency_count"))
    assert_equal(4196, receipt.dig("webkit", "transitive_dependencies", "source_dependency_count"))
    assert_equal(902, receipt.dig("webkit", "transitive_dependencies", "generated_dependency_count"))
    assert_equal(3, receipt.dig("webkit", "transitive_dependencies", "resolved_headerless_source_code_count"))
    assert_equal(6, receipt.dig("webkit", "transitive_dependencies", "unresolved_headerless_source_code_count"))
    assert_equal(true, receipt.dig("validation", "webkit_transitive_dependency_mapping_verified"))
    assert_equal(true, receipt.dig("validation", "webkit_headerless_dependency_review_verified"))
    assert_equal({ "JavaScriptCore" => 191, "WTF" => 173, "bmalloc" => 167 }, receipt.dig("webkit", "archives").to_h { |archive| [archive.fetch("name"), archive.fetch("member_count")] })
    assert_equal({ "JavaScriptCore" => 1261, "WTF" => 173, "bmalloc" => 167 }, receipt.dig("webkit", "archives").to_h { |archive| [archive.fetch("name"), archive.fetch("source_count")] })
    assert_equal(18, receipt.fetch("components").count { |component| component.fetch("kind") == "bundled_native_source" && component.fetch("license_selection_verified") })
    assert_equal([], receipt.dig("unresolved", "native_license_selections"))
    assert_equal([], receipt.dig("unresolved", "native_license_details"))
    %w[
      webkit_linked_file_semantic_review_verified final_npm_codegen_closure_verified
      fedora_allowed_spdx_verified required_license_texts_verified
      final_license_expression_verified rpm_payload_license_verified
    ].each do |key|
      assert_equal(false, receipt.dig("validation", key), key)
    end
  end

  def test_rebind_validates_the_checked_source_inventory
    root = File.expand_path("..", __dir__)
    receipt = File.join(root, "packages", "bun", "bun-1.3.14-final-linked-license-closure.json")
    inventory = File.join(root, "packages", "bun", "bun-1.3.14-source-license-inventory.json")
    npm_codegen = File.join(root, "packages", "bun", "bun-1.3.14-npm-code-generation-closure.json")

    rebound = BunFinalLinkedLicenseAudit.rebind_receipt(
      receipt_path: receipt,
      source_inventory_path: inventory,
      npm_codegen_path: npm_codegen,
      audit_date: "2026-08-01"
    )
    assert_equal("packages/bun/bun-1.3.14-source-license-inventory.json", rebound.dig("inputs", "source_license_inventory", "path"))

    previous = JSON.parse(File.read(receipt))
    previous.fetch("inputs")["source_license_inventory"] = BunFinalLinkedLicenseAudit::PREVIOUS_SOURCE_INVENTORY_RECORD
    Tempfile.create(["bun-final-license-previous-", ".json"]) do |file|
      file.write(JSON.generate(previous))
      file.flush
      transitioned = BunFinalLinkedLicenseAudit.rebind_receipt(
        receipt_path: file.path,
        source_inventory_path: inventory,
        npm_codegen_path: npm_codegen,
        audit_date: "2026-08-01"
      )
      assert_equal(BunFinalLinkedLicenseAudit::CURRENT_SOURCE_INVENTORY_RECORD, transitioned.dig("inputs", "source_license_inventory"))
      assert_equal(true, transitioned.dig("selected_license_evidence", "npm_codegen_inputs", "final_codegen_provenance_verified"))
      assert_equal(BunFinalLinkedLicenseAudit::SCOPE, transitioned.fetch("scope"))
    end

    drifted = JSON.parse(JSON.generate(BunFinalLinkedLicenseAudit::CURRENT_SOURCE_INVENTORY_RECORD))
    drifted["sha256"] = "0" * 64
    refute_includes(
      [BunFinalLinkedLicenseAudit::PREVIOUS_SOURCE_INVENTORY_RECORD, BunFinalLinkedLicenseAudit::CURRENT_SOURCE_INVENTORY_RECORD],
      drifted
    )

    unrelated = File.join(root, "packages", "bun", "bun-1.3.14-npm-code-generation-closure.json")
    assert_raises(BunFinalLinkedLicenseAudit::Error) do
      BunFinalLinkedLicenseAudit.rebind_receipt(
        receipt_path: receipt,
        source_inventory_path: unrelated,
        npm_codegen_path: npm_codegen,
        audit_date: "2026-08-01"
      )
    end

    npm = JSON.parse(File.read(npm_codegen))
    npm["rpm_release"] = "0.0.40"
    Tempfile.create(["bun-npm-codegen-stale-", ".json"]) do |file|
      file.write(JSON.generate(npm))
      file.flush
      assert_raises(BunFinalLinkedLicenseAudit::Error) do
        BunFinalLinkedLicenseAudit.rebind_receipt(
          receipt_path: receipt,
          source_inventory_path: inventory,
          npm_codegen_path: file.path,
          audit_date: "2026-08-01"
        )
      end
    end

    npm["rpm_release"] = "0.0.41"
    npm.fetch("validation")["all_selected_package_license_texts_verified"] = false
    Tempfile.create(["bun-npm-codegen-incomplete-", ".json"]) do |file|
      file.write(JSON.generate(npm))
      file.flush
      assert_raises(BunFinalLinkedLicenseAudit::Error) do
        BunFinalLinkedLicenseAudit.rebind_receipt(
          receipt_path: receipt,
          source_inventory_path: inventory,
          npm_codegen_path: file.path,
          audit_date: "2026-08-01"
        )
      end
    end

    npm.fetch("validation")["all_selected_package_license_texts_verified"] = true
    npm.fetch("validation")["selected_package_license_expressions_verified"] = false
    Tempfile.create(["bun-npm-codegen-disallowed-", ".json"]) do |file|
      file.write(JSON.generate(npm))
      file.flush
      assert_raises(BunFinalLinkedLicenseAudit::Error) do
        BunFinalLinkedLicenseAudit.rebind_receipt(
          receipt_path: receipt,
          source_inventory_path: inventory,
          npm_codegen_path: file.path,
          audit_date: "2026-08-01"
        )
      end
    end

    npm.fetch("validation")["selected_package_license_expressions_verified"] = true
    npm.fetch("validation")["generator_execution_reproduced"] = false
    Tempfile.create(["bun-npm-codegen-unreproduced-", ".json"]) do |file|
      file.write(JSON.generate(npm))
      file.flush
      assert_raises(BunFinalLinkedLicenseAudit::Error) do
        BunFinalLinkedLicenseAudit.rebind_receipt(
          receipt_path: receipt,
          source_inventory_path: inventory,
          npm_codegen_path: file.path,
          audit_date: "2026-08-01"
        )
      end
    end

    npm.fetch("validation")["generator_execution_reproduced"] = true
    codegen_path = File.join(root, "packages", "bun", "bun-1.3.14-codegen-reexecution-proof.json")
    codegen = JSON.parse(File.read(codegen_path))
    codegen.fetch("validation")["independent_runs_byte_identical"] = false
    Tempfile.create(["bun-codegen-reexecution-drifted-", ".json"]) do |file|
      file.write(JSON.pretty_generate(codegen) + "\n")
      file.flush
      npm.fetch("inputs")["codegen_reexecution_proof"] = {
        "path" => BunFinalLinkedLicenseAudit::CODEGEN_REEXECUTION_PATH,
        "size_bytes" => File.size(file.path),
        "sha256" => Digest::SHA256.file(file.path).hexdigest
      }
      assert_raises(BunFinalLinkedLicenseAudit::Error) do
        BunFinalLinkedLicenseAudit.validate_codegen_reexecution!(npm, codegen_reexecution_path: file.path)
      end
    end

    codegen = JSON.parse(File.read(codegen_path))
    codegen.fetch("runs").first.fetch("commands").first.fetch("argv")[0] = "/forged/unshare"
    Tempfile.create(["bun-codegen-reexecution-command-drifted-", ".json"]) do |file|
      file.write(JSON.pretty_generate(codegen) + "\n")
      file.flush
      npm.fetch("inputs")["codegen_reexecution_proof"] = {
        "path" => BunFinalLinkedLicenseAudit::CODEGEN_REEXECUTION_PATH,
        "size_bytes" => File.size(file.path),
        "sha256" => Digest::SHA256.file(file.path).hexdigest
      }
      assert_raises(BunFinalLinkedLicenseAudit::Error) do
        BunFinalLinkedLicenseAudit.validate_codegen_reexecution!(npm, codegen_reexecution_path: file.path)
      end
    end

    npm = JSON.parse(File.read(npm_codegen))
    header = npm.fetch("final_link").fetch("generated_outputs").find do |record|
      record["path"] == "codegen/GeneratedBunObject.h"
    end
    header["sha256"] = "0" * 64
    assert_raises(BunFinalLinkedLicenseAudit::Error) do
      BunFinalLinkedLicenseAudit.validate_codegen_reexecution!(npm)
    end

    contradictory = JSON.parse(File.read(receipt))
    contradictory.fetch("validation")["final_npm_codegen_closure_verified"] = true
    Tempfile.create(["bun-final-license-contradictory-", ".json"]) do |file|
      file.write(JSON.pretty_generate(contradictory) + "\n")
      file.flush
      assert_raises(BunFinalLinkedLicenseAudit::Error) do
        BunFinalLinkedLicenseAudit.rebind_receipt(
          receipt_path: file.path,
          source_inventory_path: inventory,
          npm_codegen_path: npm_codegen,
          audit_date: "2026-08-01"
        )
      end
    end
  end
end
