# frozen_string_literal: true

require "fileutils"
require "json"
require "minitest/autorun"
require "tmpdir"
load File.expand_path("../scripts/prepare-opencode-bun-pty-sources", __dir__)

class PrepareOpenCodeBunPtySourcesTest < Minitest::Test
  def test_generates_sorted_checked_manifest_from_versioned_directories
    Dir.mktmpdir do |directory|
      write_crate(directory, "serde-1.0.219", "serde", "1.0.219")
      write_crate(directory, "anyhow-1.0.98", "anyhow", "1.0.98")

      assert_equal(
        "anyhow v1.0.98\nserde v1.0.219\n",
        Agentlab::OpenCodeBunPtySources.manifest_bytes(directory)
      )
    end
  end

  def test_rejects_incomplete_package_identity
    Dir.mktmpdir do |directory|
      crate = File.join(directory, "broken-1.0.0")
      FileUtils.mkdir_p(crate)
      File.write(File.join(crate, "Cargo.toml"), "[package]\nname = \"broken\"\n")

      error = assert_raises(Agentlab::Error) do
        Agentlab::OpenCodeBunPtySources.manifest_bytes(directory)
      end
      assert_match(/identity is incomplete/, error.message)
    end
  end

  def test_normalizes_cargo_checksum_comments
    Dir.mktmpdir do |directory|
      crate = File.join(directory, "anyhow-1.0.98")
      FileUtils.mkdir_p(crate)
      checksum_path = File.join(crate, ".cargo-checksum.json")
      File.binwrite(checksum_path, JSON.generate({ "$comment" => "Cargo metadata", "files" => { "src/lib.rs" => "a" * 64 }, "package" => "b" * 64 }))

      assert_equal(1, Agentlab::OpenCodeBunPtySources.normalize_vendor_checksums!(directory))
      assert_equal(
        { "files" => { "src/lib.rs" => "a" * 64 }, "package" => "b" * 64 },
        JSON.parse(File.binread(checksum_path))
      )
      refute_includes(File.binread(checksum_path), "$comment")
      refute(File.binread(checksum_path).end_with?("\n"))
    end
  end

  private

  def write_crate(directory, dirname, name, version)
    crate = File.join(directory, dirname)
    FileUtils.mkdir_p(crate)
    File.write(File.join(crate, "Cargo.toml"), <<~TOML)
      [package]
      name = "#{name}"
      version = "#{version}"
    TOML
  end
end
