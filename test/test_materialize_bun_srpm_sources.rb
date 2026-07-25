# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "minitest/autorun"
require "open3"
require "rubygems/package"
require "tmpdir"
require "zlib"
require_relative "../scripts/lib/bun_srpm_sources"

class MaterializeBunSrpmSourcesTest < Minitest::Test
  def with_fixture
    Dir.mktmpdir("agentlab-bun-srpm-sources-", "/srv/tmp") do |temporary|
      cache = File.join(temporary, "cache")
      %w[archives npm].each { |directory| FileUtils.mkdir_p(File.join(cache, directory)) }

      native = 2.times.map do |index|
        raw_record(cache, "archives", "native-#{index}.tar.gz", "native #{index}\n").merge(
          "symbol" => "native#{index}",
          "name" => "native#{index}",
          "url" => "https://example.test/native#{index}.tar.gz"
        )
      end
      node = raw_record(cache, "archives", "node.tar.gz", "node\n").merge(
        "symbol" => "nodejsHeaders",
        "name" => "nodejs",
        "version" => "24.3.0",
        "abi" => "137",
        "url" => "https://example.test/node.tar.gz"
      )
      npm = 2.times.map do |index|
        raw_record(cache, "npm", "npm-#{index}.tgz", "npm #{index}\n").merge(
          "origin" => "registry",
          "npm_name" => "fixture-#{index}",
          "source_name" => "fixture-#{index}",
          "source_version" => "1.0.#{index}",
          "source_commit" => nil,
          "integrity" => "sha512-fixture#{index}",
          "source_url" => "https://example.test/npm-#{index}.tgz"
        )
      end
      source_sha256 = Digest::SHA256.hexdigest("bun source")
      closure = {
        "schema" => "bun-release-local-source-closure/v3",
        "package" => "bun",
        "release" => "1.3.14",
        "target" => { "os" => "linux", "cpu" => "x64", "libc" => "glibc" },
        "source_tree" => { "source_sha256" => source_sha256 },
        "native_github_sources" => native,
        "node_headers" => node,
        "npm" => { "source_archives" => npm }
      }
      closure_path = File.join(temporary, "closure.json")
      File.write(closure_path, JSON.pretty_generate(closure) + "\n")
      options = {
        closure_path: closure_path,
        expected_closure_sha256: Digest::SHA256.file(closure_path).hexdigest,
        expected_source_sha256: source_sha256,
        expected_counts: { "native" => 2, "node" => 1, "npm" => 2 },
        cache_dir: cache,
        output_dir: File.join(temporary, "output"),
        receipt_path: File.join(temporary, "output", "receipt.json"),
        workdir: File.join(temporary, "work"),
        check: false
      }
      FileUtils.mkdir_p(options.fetch(:workdir))
      yield temporary, closure, options
    end
  end

  def test_materializes_deterministic_archives_and_checks_them
    with_fixture do |temporary, _closure, options|
      receipt = Agentlab::BunSrpmSources.materialize!(**options)
      assert_equal("bun-srpm-source-bundles/v2", receipt.fetch("schema"))
      assert(receipt.dig("scope", "archive_generation_architecture_independent"))
      refute(receipt.dig("scope", "complete_multi_architecture_closure_verified"))
      assert_equal({ "os" => "linux", "cpu" => "x64", "libc" => "glibc" }, receipt.dig("scope", "closure_target"))
      assert_equal(3, receipt.dig("archives", "native_node", "member_count"))
      assert_equal(2, receipt.dig("archives", "npm", "member_count"))

      native_entries = tar_entries(File.join(options.fetch(:output_dir), receipt.dig("archives", "native_node", "filename")))
      assert_includes(native_entries, "bun-1.3.14-native-node-sources/archives/native-0.tar.gz")
      assert_includes(native_entries, "bun-1.3.14-native-node-sources/archives/node.tar.gz")
      npm_entries = tar_entries(File.join(options.fetch(:output_dir), receipt.dig("archives", "npm", "filename")))
      assert_includes(npm_entries, "bun-1.3.14-npm-sources/npm/npm-1.tgz")
      check_options = options.merge(workdir: File.join(temporary, "check-work"), check: true)
      FileUtils.mkdir_p(check_options.fetch(:workdir))
      checked = Agentlab::BunSrpmSources.materialize!(**check_options)
      assert_equal(receipt, checked)
    end
  end

  def test_rejects_a_corrupt_cached_member
    with_fixture do |_temporary, _closure, options|
      File.binwrite(File.join(options.fetch(:cache_dir), "npm", "npm-0.tgz"), "corrupt\n")
      error = assert_raises(Agentlab::Error) { Agentlab::BunSrpmSources.materialize!(**options) }
      assert_includes(error.message, "size mismatch")
    end
  end

  def test_materializes_only_the_selected_npm_archive
    with_fixture do |_temporary, _closure, options|
      receipt = Agentlab::BunSrpmSources.materialize!(**options.merge(roles: %w[npm]))

      assert_equal(%w[npm], receipt.fetch("selected_archive_roles"))
      assert_equal(%w[npm], receipt.fetch("archives").keys.sort)
      refute(File.exist?(File.join(options.fetch(:output_dir), "bun-1.3.14-native-node-sources.tar.gz")))
      assert(File.file?(File.join(options.fetch(:output_dir), "bun-1.3.14-npm-sources.tar.gz")))
    end
  end

  def test_check_mode_rejects_a_changed_archive
    with_fixture do |temporary, _closure, options|
      receipt = Agentlab::BunSrpmSources.materialize!(**options)
      npm_archive = File.join(options.fetch(:output_dir), receipt.dig("archives", "npm", "filename"))
      File.open(npm_archive, "ab") { |file| file.write("changed") }
      check_options = options.merge(workdir: File.join(temporary, "check-work"), check: true)
      FileUtils.mkdir_p(check_options.fetch(:workdir))
      error = assert_raises(Agentlab::Error) { Agentlab::BunSrpmSources.materialize!(**check_options) }
      assert_includes(error.message, "npm source archive is stale")
    end
  end

  def test_rejects_unsafe_archive_names_and_expected_npm_drift
    with_fixture do |temporary, closure, options|
      closure.fetch("npm").fetch("source_archives").first["archive"] = "../escape.tgz"
      File.write(options.fetch(:closure_path), JSON.pretty_generate(closure) + "\n")
      unsafe_options = options.merge(expected_closure_sha256: Digest::SHA256.file(options.fetch(:closure_path)).hexdigest)
      error = assert_raises(Agentlab::Error) { Agentlab::BunSrpmSources.materialize!(**unsafe_options) }
      assert_includes(error.message, "archive filename is invalid")

      FileUtils.rm_rf(options.fetch(:workdir))
      FileUtils.mkdir_p(options.fetch(:workdir))
      closure.fetch("npm").fetch("source_archives").first["archive"] = "npm-0.tgz"
      File.write(options.fetch(:closure_path), JSON.pretty_generate(closure) + "\n")
      drift_options = options.merge(
        expected_closure_sha256: Digest::SHA256.file(options.fetch(:closure_path)).hexdigest,
        expected_npm_archive: {
          "filename" => "bun-1.3.14-npm-sources.tar.gz",
          "sha256" => "0" * 64,
          "size_bytes" => 1
        }
      )
      error = assert_raises(Agentlab::Error) { Agentlab::BunSrpmSources.materialize!(**drift_options) }
      assert_includes(error.message, "does not match package metadata")
    end
  end

  private

  def raw_record(cache, subdir, archive, content)
    path = File.join(cache, subdir, archive)
    File.binwrite(path, content)
    {
      "archive" => archive,
      "sha256" => Digest::SHA256.file(path).hexdigest,
      "size_bytes" => File.size(path)
    }
  end

  def tar_entries(path)
    output, error, status = Open3.capture3("tar", "-tzf", path)
    assert(status.success?, error)
    output.lines.map { |line| line.strip.delete_suffix("/") }
  end
end
