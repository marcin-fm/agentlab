# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "minitest/autorun"
require "open3"
require "tmpdir"
require_relative "../scripts/lib/opencode_sources"

class MaterializeOpenCodeSourcesTest < Minitest::Test
  def test_materializes_deterministic_bundles_and_rejects_corruption
    Dir.mktmpdir("agentlab-opencode-sources-", "/srv/tmp") do |temporary|
      cache = File.join(temporary, "cache")
      FileUtils.mkdir_p(cache)
      records = %w[first second].map { |name| source_record(cache, name) }
      audit = File.join(temporary, "source-audit.json")
      File.write(audit, JSON.pretty_generate({
        "schema" => "opencode-source-acquisition/v1",
        "package" => "opencode",
        "release" => "1.18.5",
        "selected_lock_receipt_sha256" => "a" * 64,
        "sources" => records,
        "validation" => {
          "registry_integrity_verified" => true,
          "archive_paths_verified" => true,
          "source_sha256_recorded" => true,
          "lifecycle_scripts_executed" => false,
          "dependency_resolution_performed" => false
        }
      }) + "\n")
      options = {
        source_audit_path: audit,
        expected_source_audit_sha256: Digest::SHA256.file(audit).hexdigest,
        cache_dir: cache,
        output_dir: File.join(temporary, "output"),
        receipt_path: File.join(temporary, "receipt.json"),
        workdir: File.join(temporary, "work"),
        expected_filenames: {
          "production_build" => "opencode-1.18.5-nm-prod-build.tar.zst",
          "test" => "opencode-1.18.5-nm-dev-test.tar.zst"
        },
        check: false
      }
      receipt = Agentlab::OpenCodeSources.materialize!(**options)
      assert_equal(2, receipt.dig("archives", "production_build", "member_count"))
      assert_equal(2, receipt.dig("archives", "test", "member_count"))
      assert_equal(receipt, Agentlab::OpenCodeSources.materialize!(**options.merge(check: true, workdir: File.join(temporary, "check"))))

      source = Dir.glob(File.join(cache, "*.tgz")).first
      File.binwrite(source, "corrupt\n")
      error = assert_raises(Agentlab::Error) { Agentlab::OpenCodeSources.materialize!(**options.merge(workdir: File.join(temporary, "corrupt"))) }
      assert_match(/size mismatch|SHA-256 mismatch/, error.message)
    end
  end

  private

  def source_record(cache, name)
    bytes = "#{name} source\n"
    sha512 = Digest::SHA512.hexdigest(bytes)
    archive = "sha512-#{sha512}.tgz"
    File.binwrite(File.join(cache, archive), bytes)
    {
      "archive" => archive,
      "sha256" => Digest::SHA256.hexdigest(bytes),
      "size" => bytes.bytesize,
      "npm_name" => "fixture-#{name}",
      "version" => "1.0.0",
      "roles" => ["runtime"],
      "package_paths" => ["fixture-#{name}"]
    }
  end
end
