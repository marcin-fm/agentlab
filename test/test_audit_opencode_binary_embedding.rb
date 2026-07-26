# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "tmpdir"
require "yaml"
load File.expand_path("../scripts/audit-opencode-binary-embedding", __dir__)

class AuditOpenCodeBinaryEmbeddingTest < Minitest::Test
  def test_generates_a_fail_closed_embedding_receipt
    Dir.mktmpdir do |directory|
      source_root = File.join(directory, "source")
      package_dir = File.join(source_root, "packages", "opencode")
      workspace_dir = File.join(source_root, "packages", "core")
      runtime_dir = File.join(source_root, "node_modules", "runtime-pkg")
      build_dir = File.join(source_root, "node_modules", "build-pkg")
      [package_dir, workspace_dir, runtime_dir, build_dir, File.join(source_root, ".build-tools")].each do |path|
        FileUtils.mkdir_p(path)
      end

      File.write(File.join(workspace_dir, "index.js"), "export const workspace = true\n")
      File.write(File.join(runtime_dir, "index.js"), "export const runtime = true\n")
      File.write(File.join(runtime_dir, "unused.js"), "export const unused = true\n")
      File.write(File.join(runtime_dir, "parser.worker.js"), "self.onmessage = () => {}\n")
      File.write(File.join(build_dir, "index.js"), "export const bundledBuildInput = true\n")
      write_json(File.join(runtime_dir, "package.json"), { "name" => "runtime-pkg", "version" => "1.0.0" })
      write_json(File.join(build_dir, "package.json"), { "name" => "build-pkg", "version" => "2.0.0-beta.1" })
      File.write(File.join(source_root, ".build-tools", "models.json"), "{}\n")
      binary = File.join(package_dir, "opencode")
      File.write(binary, "#!/bin/sh\nprintf '%s\\n' 1.0.0\n")
      File.chmod(0o755, binary)

      source_audit_path = File.join(directory, "source-audit.json")
      source_audit = {
        "schema" => "opencode-source-acquisition/v1",
        "package" => "opencode",
        "release" => "1.0.0",
        "sources" => [
          source_record("runtime-pkg", "1.0.0", "runtime-pkg", "a", [{ "path" => "package/LICENSE", "sha256" => "b" * 64, "size" => 10 }]),
          source_record("build-pkg", "2.0.0-beta.1", "build-pkg", "c", [])
        ]
      }
      write_json(source_audit_path, source_audit)
      source_audit_sha256 = Digest::SHA256.file(source_audit_path).hexdigest

      closure_path = File.join(directory, "closure.json")
      closure = {
        "schema" => "agentlab-opencode-source-closure/v1",
        "package" => "opencode",
        "release" => "1.0.0",
        "receipts" => { "source_audit" => { "sha256" => source_audit_sha256 } },
        "workspaces" => [{ "path" => "packages/core", "name" => "@opencode-ai/core", "version" => "1.0.0", "role" => "runtime" }],
        "packages" => [
          closure_record("runtime-pkg", "1.0.0", "runtime", true, "a"),
          closure_record("build-pkg", "2.0.0-beta.1", "build", false, "c")
        ]
      }
      write_json(closure_path, closure)
      closure_sha256 = Digest::SHA256.file(closure_path).hexdigest

      license_review_path = File.join(directory, "license-review.yml")
      license_text_dir = File.join(directory, "license-texts")
      FileUtils.mkdir_p(license_text_dir)
      license_text = "MIT fixture license\n"
      File.write(File.join(license_text_dir, "build-pkg-LICENSE"), license_text)
      File.write(license_review_path, YAML.dump(
        "schema" => "opencode-license-review/v1",
        "release" => "1.0.0",
        "declaration_resolutions" => [],
        "package_local_text_resolutions" => [
          {
            "packages" => ["build-pkg@2.0.0-beta.1"],
            "license" => "MIT",
            "disposition" => "payload_file",
            "evidence_kind" => "fixture",
            "payload_file" => "build-pkg-LICENSE",
            "license_sha256" => Digest::SHA256.hexdigest(license_text)
          }
        ]
      ))
      license_review_sha256 = Digest::SHA256.file(license_review_path).hexdigest
      source_license_set_path = File.join(directory, "source-license-set.json")
      write_json(source_license_set_path, {
        "schema" => "agentlab-opencode-source-license-set/v1",
        "package" => "opencode",
        "release" => "1.0.0",
        "receipts" => {
          "source_audit" => { "sha256" => source_audit_sha256 },
          "license_review" => { "sha256" => license_review_sha256 }
        },
        "normalizations" => [],
        "expression_counts" => { "MIT" => 2 }
      })
      materialization_path = File.join(source_root, ".build-tools", "node-modules-materialization.json")
      write_json(materialization_path, {
        "schema" => "agentlab-opencode-node-modules-materialization/v2",
        "package" => "opencode",
        "release" => "1.0.0",
        "source_audit" => { "sha256" => source_audit_sha256 },
        "source_closure" => { "sha256" => closure_sha256 },
        "scope" => { "package_paths" => 2 }
      })
      build_patch_path = File.join(directory, "build.patch")
      File.write(build_patch_path, "fixture\n")
      metafile_path = File.join(source_root, ".build-tools", "metafile.json")
      write_json(metafile_path, {
        "inputs" => {
          "../../node_modules/runtime-pkg/index.js" => { "bytes" => 28, "imports" => [], "format" => "esm" },
          "../../node_modules/runtime-pkg/unused.js" => { "bytes" => 27, "imports" => [], "format" => "esm" },
          "../../node_modules/build-pkg/index.js" => { "bytes" => 38, "imports" => [], "format" => "esm" },
          "../core/index.js" => { "bytes" => 30, "imports" => [], "format" => "esm" }
        },
        "outputs" => {
          "./src/index.js" => {
            "bytes" => 100,
            "inputs" => {
              "../../node_modules/runtime-pkg/index.js" => { "bytesInOutput" => 20 },
              "../../node_modules/runtime-pkg/unused.js" => { "bytesInOutput" => 0 },
              "../../node_modules/build-pkg/index.js" => { "bytesInOutput" => 30 },
              "../core/index.js" => { "bytesInOutput" => 25 }
            },
            "imports" => [],
            "exports" => [],
            "entryPoint" => "src/index.ts"
          }
        }
      })
      output_path = File.join(directory, "embedding.json")

      result = Agentlab::OpenCodeBinaryEmbedding.generate!(
        source_root: source_root,
        metafile_path: metafile_path,
        closure_path: closure_path,
        source_audit_path: source_audit_path,
        source_license_set_path: source_license_set_path,
        license_review_path: license_review_path,
        license_text_dir: license_text_dir,
        materialization_path: materialization_path,
        build_patch_path: build_patch_path,
        models_snapshot_path: File.join(source_root, ".build-tools", "models.json"),
        parser_worker_path: File.join(runtime_dir, "parser.worker.js"),
        binary_path: binary,
        expected_version: "1.0.0",
        output_path: output_path
      )
      receipt = result.fetch("receipt")

      assert_equal(2, receipt.dig("scope", "embedded_package_paths"))
      assert_equal(2, receipt.dig("scope", "embedded_public_name_versions"))
      assert_equal(1, receipt.dig("scope", "embedded_workspace_paths"))
      assert_equal(1, receipt.dig("scope", "resolved_license_text_gaps"))
      assert_equal(0, receipt.dig("scope", "included_license_text_gaps"))
      assert_empty(receipt.fetch("included_license_text_gaps"))
      assert_equal([
        {
          "filename" => "build-pkg-LICENSE",
          "sha256" => Digest::SHA256.hexdigest(license_text),
          "packages" => ["build-pkg@2.0.0-beta.1"]
        }
      ], receipt.fetch("license_text_payloads"))
      build_record = receipt.fetch("packages").find { |record| record.fetch("npm_name") == "build-pkg" }
      assert_equal("build", build_record.fetch("selected_role"))
      assert_equal("runtime", build_record.fetch("role"))
      assert_equal("2.0.0~beta.1", build_record.fetch("rpm_version"))
      refute(build_record.fetch("license_text_gap"))
      assert_equal("build-pkg-LICENSE", build_record.dig("license_text_resolution", "payload_file"))
      assert(receipt.dig("validation", "final_npm_binary_inclusion_verified"))
      assert_equal(result.fetch("sha256"), Digest::SHA256.file(output_path).hexdigest)
    end
  end

  private

  def write_json(path, value)
    File.write(path, JSON.pretty_generate(value) + "\n")
  end

  def source_record(name, version, package_path, hash_prefix, license_files)
    {
      "npm_name" => name,
      "version" => version,
      "origin" => "registry",
      "source_url" => "https://registry.npmjs.org/#{name}/-/#{name}-#{version}.tgz",
      "integrity" => "sha512-fixture-#{name}",
      "sha256" => hash_prefix * 64,
      "archive" => "#{name}.tgz",
      "package_paths" => [package_path],
      "declared_license" => "MIT",
      "license_files" => license_files
    }
  end

  def closure_record(name, version, role, candidate, hash_prefix)
    {
      "package_path" => name,
      "npm_name" => name,
      "version" => version,
      "origin" => "registry",
      "role" => role,
      "candidate_for_binary" => candidate,
      "integrity" => "sha512-fixture-#{name}",
      "source_url" => "https://registry.npmjs.org/#{name}/-/#{name}-#{version}.tgz",
      "included_in_binary" => false,
      "sha256" => hash_prefix * 64
    }
  end
end
