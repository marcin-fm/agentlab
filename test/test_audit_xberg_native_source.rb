# frozen_string_literal: true

require "minitest/autorun"
require "rubygems/package"
require "stringio"
require "tempfile"
require "zlib"

load File.expand_path("../scripts/audit-xberg-native-source", __dir__)

class TestAuditXbergNativeSource < Minitest::Test
  def test_canonical_digest_is_order_independent
    records = [
      { "path" => "b", "bytes" => 2, "sha256" => "22" },
      { "path" => "a", "bytes" => 1, "sha256" => "11" }
    ]

    assert_equal XbergNativeSource.canonical_digest(records), XbergNativeSource.canonical_digest(records.reverse)
  end

  def test_archive_record_rejects_parent_traversal
    Tempfile.create(["native-source", ".tar.gz"]) do |file|
      tar_bytes = StringIO.new("".b)
      Gem::Package::TarWriter.new(tar_bytes) do |tar|
        tar.add_file("../escape", 0o644) { |entry| entry.write("bad") }
      end
      gzip = Zlib::GzipWriter.new(file)
      gzip.write(tar_bytes.string)
      gzip.finish
      file.flush
      contract = { sha256: Digest::SHA256.file(file.path).hexdigest, source_prefix: nil, expected_cpp: 0, license_files: [] }

      error = assert_raises(ArgumentError) { XbergNativeSource.archive_record(file.path, contract) }
      assert_match(/unsafe archive path/, error.message)
    end
  end

  def test_boost_license_record_rejects_noncanonical_text
    Tempfile.create("boost-license") do |file|
      file.write("not the Boost license\n")
      file.flush

      error = assert_raises(ArgumentError) { XbergNativeSource.boost_license_record(file.path) }
      assert_match(/checksum mismatch/, error.message)
    end
  end
end
