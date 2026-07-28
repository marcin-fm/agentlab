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

  def test_accepts_x64_selection_from_a_union_bundle
    assert_union_selection(
      ["common.tgz", "x64.tgz"],
      ["common.tgz", "x64.tgz", "arm64.tgz"]
    )
  end

  def test_accepts_arm64_selection_from_a_union_bundle
    assert_union_selection(
      ["common.tgz", "arm64.tgz"],
      ["common.tgz", "x64.tgz", "arm64.tgz"]
    )
  end

  def test_main_accepts_arm64_selection_from_a_union_bundle
    assert_main_target("arm64")
  end

  def test_main_rejects_unsupported_target
    error = assert_raises(BunReleaseLocalStaging::Error) { assert_main_target("riscv64") }
    assert_includes(error.message, "target mismatch")
  end

  private

  def assert_union_selection(selected, union)
    Dir.mktmpdir("agentlab-bun-union-test-", "/srv/tmp") do |temporary|
      bundle = File.join(temporary, "bun-1.3.14-npm-sources.tar.gz")
      Zlib::GzipWriter.open(bundle) do |gzip|
        gzip.mtime = 0
        Gem::Package::TarWriter.new(gzip) do |tar|
          root = "bun-1.3.14-npm-sources"
          tar.mkdir(root, 0o755)
          tar.mkdir("#{root}/npm", 0o755)
          union.each { |archive| tar.add_file_simple("#{root}/npm/#{archive}", 0o644, 1) { |file| file.write("x") } }
        end
      end
      closure = {
        "release" => "1.3.14",
        "npm" => { "source_archives" => selected.map { |archive| { "archive" => archive } }
      }
      }

      BunReleaseLocalStaging.verify_npm_bundle_superset!(bundle, closure, chdir: temporary)
    end
  end

  def assert_main_target(cpu)
    Dir.mktmpdir("agentlab-bun-stage-main-test-", "/srv/tmp") do |temporary|
      source_root = File.join(temporary, "source")
      FileUtils.mkdir_p(source_root)
      closure = {
        "schema" => "bun-release-local-source-closure/v3",
        "package" => "bun",
        "release" => "1.3.14",
        "target" => { "os" => "linux", "cpu" => cpu, "libc" => "glibc" },
        "native_github_sources" => Array.new(18) { |index| { "name" => "native#{index}" } },
        "node_headers" => { "name" => "nodejs" },
        "npm" => { "summary" => { "unique_sources" => 1 }, "source_archives" => [{ "archive" => "#{cpu}.tgz" }] }
      }
      closure_path = File.join(temporary, "closure.json")
      bundle = File.join(temporary, "bundle.tar.gz")
      File.write(closure_path, JSON.generate(closure))
      File.binwrite(bundle, "bundle")
      selected_targets = []
      originals = %i[stage_native! stage_node_headers! stage_npm!].to_h { |name| [name, BunReleaseLocalStaging.method(name)] }
      BunReleaseLocalStaging.define_singleton_method(:stage_native!) { |*_arguments| { "name" => "native" } }
      BunReleaseLocalStaging.define_singleton_method(:stage_node_headers!) { |*_arguments| { "version" => "24.3.0", "abi" => "137", "identity" => "24.3.0" } }
      BunReleaseLocalStaging.define_singleton_method(:stage_npm!) do |selected_closure, *_arguments|
        selected_targets << selected_closure.fetch("target")
        { "cache_entries" => 1 }
      end
      BunReleaseLocalStaging.main([
        "--source-root", source_root,
        "--closure", closure_path,
        "--npm-bundle", bundle,
        "--npm-cache", File.join(temporary, "cache"),
        "--prefetch-dir", File.join(temporary, "prefetch"),
        "--receipt", File.join(temporary, "receipt.json"),
        "--npm-manifest", File.join(temporary, "manifest.jsonl"),
        "--expected-npm-tree-sha256", "0" * 64,
        "--expected-npm-entries", "1",
        "--expected-npm-files", "1",
        "--expected-npm-directories", "0",
        "--expected-npm-file-bytes", "1"
      ])
      assert_equal([closure.fetch("target")], selected_targets)
    ensure
      originals.each { |name, method| BunReleaseLocalStaging.define_singleton_method(name, method) } if originals
    end
  end
end
