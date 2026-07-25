# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "minitest/autorun"
require "open3"
require "tmpdir"
require_relative "../scripts/lib/openchamber_sources"

class MaterializeOpenChamberSourcesTest < Minitest::Test
  def with_fixture
    Dir.mktmpdir("agentlab-openchamber-sources-", "/srv/tmp") do |temporary|
      cache = File.join(temporary, "cache")
      FileUtils.mkdir_p(cache)
      records = [
        source_record(cache, "runtime", %w[runtime]),
        source_record(cache, "build", %w[build]),
        source_record(cache, "test", %w[test])
      ]
      receipt = {
        "schema" => "openchamber-source-acquisition/v1",
        "package" => "openchamber",
        "release" => "1.16.3",
        "selected_lock_receipt_sha256" => "a" * 64,
        "sources" => records,
        "validation" => {
          "registry_integrity_verified" => true,
          "archive_paths_verified" => true,
          "source_sha256_recorded" => true,
          "lifecycle_scripts_executed" => false,
          "dependency_resolution_performed" => false
        }
      }
      audit = File.join(temporary, "source-audit.json")
      File.write(audit, JSON.pretty_generate(receipt) + "\n")
      options = {
        source_audit_path: audit,
        expected_source_audit_sha256: Digest::SHA256.file(audit).hexdigest,
        cache_dir: cache,
        output_dir: File.join(temporary, "output"),
        receipt_path: File.join(temporary, "closure.json"),
        workdir: File.join(temporary, "work"),
        expected_filenames: {
          "production_build" => "openchamber-1.16.3-nm-prod-build.tar.zst",
          "test" => "openchamber-1.16.3-nm-dev-test.tar.zst"
        },
        check: false
      }
      yield temporary, options
    end
  end

  def test_materializes_deterministic_role_bundles
    with_fixture do |_temporary, options|
      receipt = Agentlab::OpenChamberSources.materialize!(**options)
      assert_equal(2, receipt.dig("archives", "production_build", "member_count"))
      assert_equal(3, receipt.dig("archives", "test", "member_count"))
      assert(receipt.dig("validation", "test_superset_verified"))

      production = File.join(options.fetch(:output_dir), receipt.dig("archives", "production_build", "filename"))
      test_bundle = File.join(options.fetch(:output_dir), receipt.dig("archives", "test", "filename"))
      assert_equal(2, archive_members(production).count { |path| path.end_with?(".tgz") })
      assert_equal(3, archive_members(test_bundle).count { |path| path.end_with?(".tgz") })

      checked = Agentlab::OpenChamberSources.materialize!(**options.merge(check: true, workdir: File.join(File.dirname(options.fetch(:workdir)), "check")))
      assert_equal(receipt, checked)
    end
  end

  def test_rejects_corrupt_cached_source
    with_fixture do |_temporary, options|
      source = Dir.glob(File.join(options.fetch(:cache_dir), "*.tgz")).first
      File.binwrite(source, "corrupt\n")
      error = assert_raises(Agentlab::Error) { Agentlab::OpenChamberSources.materialize!(**options) }
      assert_match(/size mismatch|SHA-256 mismatch/, error.message)
    end
  end

  private

  def source_record(cache, name, roles)
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
      "roles" => roles,
      "package_paths" => ["fixture-#{name}"]
    }
  end

  def archive_members(path)
    output, error, status = Open3.capture3("tar", "-tf", path)
    assert(status.success?, error)
    output.lines.map(&:chomp)
  end
end
