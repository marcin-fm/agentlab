# frozen_string_literal: true

require "digest"
require "json"
require "minitest/autorun"
require "rubygems/package"
require "tmpdir"
require "zlib"
load File.expand_path("../packages/bun/bun-stage-release-local-sources", __dir__)

class BunReleaseLocalStagingTest < Minitest::Test
  def test_bun_semver_hashes_match_the_checked_cache_identities
    expected = {
      "0" => "b8f8325b21a8a1e5",
      "cjs.1" => "ec7b5e1ef906f68d",
      "cjs.2" => "0e40aeb971250b85",
      "patch.1" => "505c8ed44add284c"
    }

    assert_equal(expected, expected.to_h { |value, hash| [value, format("%016x", BunReleaseLocalStaging.wyhash11(value))] })
  end

  def test_derives_registry_and_github_cache_names
    roots = {
      "." => {
        "sources" => [
          {
            "package_path" => "bun-tracestrings",
            "origin" => "github",
            "resolution" => "github:oven-sh/bun.report#912ca63e26c51429d3e6799aa2a6ab079b188fd8"
          }
        ]
      }
    }
    registry = {
      "origin" => "registry",
      "source_name" => "fixture",
      "source_version" => "1.2.3-cjs.1"
    }
    github = {
      "origin" => "github",
      "references" => [{ "install_root" => ".", "package_path" => "bun-tracestrings" }]
    }

    assert_equal(
      "fixture@1.2.3-ec7b5e1ef906f68d@@@1",
      BunReleaseLocalStaging.source_cache_name(registry, roots, "cjs.1" => "ec7b5e1ef906f68d")
    )
    assert_equal(
      "@GH@oven-sh-bun.report-912ca63e26c51429d3e6799aa2a6ab079b188fd8@@@1",
      BunReleaseLocalStaging.source_cache_name(github, roots, {})
    )
  end

  def test_extracts_a_safe_npm_archive_and_records_a_stable_tree
    Dir.mktmpdir("agentlab-bun-stage-test-", "/srv/tmp") do |temporary|
      archive = File.join(temporary, "fixture.tgz")
      package_json = JSON.generate("name" => "fixture", "version" => "1.0.0", "bin" => "bin/tool") + "\n"
      script = "#!/bin/sh\n"
      Zlib::GzipWriter.open(archive) do |gzip|
        gzip.mtime = 0
        Gem::Package::TarWriter.new(gzip) do |tar|
          tar.mkdir("package", 0o755)
          tar.mkdir("package/bin", 0o755)
          tar.add_file_simple("package/package.json", 0o644, package_json.bytesize) { |file| file.write(package_json) }
          tar.add_file_simple("package/bin/tool", 0o644, script.bytesize) { |file| file.write(script) }
        end
      end

      destination = File.join(temporary, "cache", "fixture@1.0.0@@@1")
      BunReleaseLocalStaging.extract_npm_archive!(archive, destination, "package")
      manifest = JSON.parse(File.read(File.join(destination, "package.json")))
      BunReleaseLocalStaging.normalize_package_bins!(destination, manifest)
      receipt = BunReleaseLocalStaging.tree_receipt(destination)

      assert_equal(2, receipt.fetch("files"))
      assert_equal(1, receipt.fetch("directories"))
      assert_equal(0o777, File.stat(File.join(destination, "bin", "tool")).mode & 0o777)
      assert_match(/\A[0-9a-f]{64}\z/, receipt.fetch("sha256"))
    end
  end

  def test_rejects_unsafe_relative_paths
    assert_nil(BunReleaseLocalStaging.safe_relative_path("../escape"))
    assert_nil(BunReleaseLocalStaging.safe_relative_path("/absolute"))
    assert_equal("safe/path", BunReleaseLocalStaging.safe_relative_path("safe/path"))
  end
end
