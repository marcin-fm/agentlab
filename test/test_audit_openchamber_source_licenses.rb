# frozen_string_literal: true

require "digest"
require "json"
require "minitest/autorun"
require "rubygems/package"
require "tmpdir"
require "zlib"
require_relative "../scripts/lib/agentlab"
require_relative "../scripts/lib/openchamber_licenses"

class AuditOpenChamberSourceLicensesTest < Minitest::Test
  def test_records_raw_license_and_package_local_text_hashes_deterministically
    Dir.mktmpdir("agentlab-openchamber-licenses-", "/srv/tmp") do |temporary|
      cache = File.join(temporary, "archives")
      Dir.mkdir(cache)
      declared_license = [{ "type" => "Apache 2.0" }]
      package_json = JSON.generate("name" => "fixture", "version" => "1.0.0", "licenses" => declared_license)
      license = "fixture license\n"
      archive = write_archive(cache, package_json, license)
      source = {
        "archive" => File.basename(archive),
        "sha256" => Digest::SHA256.file(archive).hexdigest,
        "size" => File.size(archive),
        "npm_name" => "fixture",
        "version" => "1.0.0",
        "package_paths" => ["fixture"],
        "roles" => ["runtime"],
        "package_json" => "package/package.json",
        "declared_license" => declared_license,
        "license_files" => [{ "path" => "package/LICENSE", "sha256" => Digest::SHA256.hexdigest(license), "size" => license.bytesize }]
      }
      selected = { "schema" => "openchamber-selected-lock-audit/v2", "selection" => { "selected_packages" => 1 } }
      selected_path = File.join(temporary, "selected.json")
      File.write(selected_path, JSON.pretty_generate(selected) + "\n")
      source_audit = {
        "schema" => "openchamber-source-acquisition/v1",
        "package" => "openchamber",
        "release" => "1.16.3",
        "selected_lock_receipt_sha256" => Digest::SHA256.file(selected_path).hexdigest,
        "summary" => { "unique_sources" => 1 },
        "sources" => [source]
      }
      source_audit_path = File.join(temporary, "source-audit.json")
      File.write(source_audit_path, JSON.pretty_generate(source_audit) + "\n")
      receipt_path = File.join(temporary, "licenses.json")
      options = {
        selected_lock_path: selected_path,
        expected_selected_lock_sha256: Digest::SHA256.file(selected_path).hexdigest,
        source_audit_path: source_audit_path,
        expected_source_audit_sha256: Digest::SHA256.file(source_audit_path).hexdigest,
        cache_dir: cache,
        receipt_path: receipt_path,
        workdir: File.join(temporary, "work")
      }

      receipt = Agentlab::OpenChamberLicenses.audit!(**options)

      assert_equal(declared_license, receipt.dig("archives", 0, "declared_license"))
      assert_equal(Digest::SHA256.hexdigest(license), receipt.dig("archives", 0, "license_files", 0, "sha256"))
      assert_equal(1, receipt.dig("summary", "ambiguous_declared_license_sources"))
      assert_equal(receipt, Agentlab::OpenChamberLicenses.audit!(**options.merge(check: true)))
    end
  end

  private

  def write_archive(cache, package_json, license)
    temporary = File.join(cache, "fixture.tgz")
    Zlib::GzipWriter.open(temporary) do |gzip|
      Gem::Package::TarWriter.new(gzip) do |tar|
        tar.add_file_simple("package/package.json", 0o644, package_json.bytesize) { |file| file.write(package_json) }
        tar.add_file_simple("package/LICENSE", 0o644, license.bytesize) { |file| file.write(license) }
      end
    end
    path = File.join(cache, "sha512-#{Digest::SHA512.file(temporary).hexdigest}.tgz")
    File.rename(temporary, path)
    path
  end
end
