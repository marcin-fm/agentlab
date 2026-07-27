# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "tmpdir"
load File.expand_path("../scripts/prepare-opencode-photon-sources", __dir__)

class PrepareOpenCodePhotonSourcesTest < Minitest::Test
  def test_generates_sorted_manifest_with_cargo_build_metadata
    Dir.mktmpdir do |directory|
      write_crate(directory, "wasi-0.11.0+wasi-snapshot-preview1", "wasi", "0.11.0+wasi-snapshot-preview1")
      write_crate(directory, "anyhow-1.0.98", "anyhow", "1.0.98")

      assert_equal(
        "anyhow v1.0.98\nwasi v0.11.0+wasi-snapshot-preview1\n",
        Agentlab::OpenCodePhotonSources.manifest_bytes(directory)
      )
    end
  end

  def test_rejects_incomplete_package_identity
    Dir.mktmpdir do |directory|
      crate = File.join(directory, "broken-1.0.0")
      FileUtils.mkdir_p(crate)
      File.write(File.join(crate, "Cargo.toml"), "[package]\nname = \"broken\"\n")

      error = assert_raises(Agentlab::Error) do
        Agentlab::OpenCodePhotonSources.manifest_bytes(directory)
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

      [[bench]]
      name = "ignored"
      harness = false
    TOML
  end
end
