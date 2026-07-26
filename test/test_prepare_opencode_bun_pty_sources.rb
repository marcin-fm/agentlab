# frozen_string_literal: true

require "fileutils"
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
