# frozen_string_literal: true

require "minitest/autorun"
require "stringio"
require "tmpdir"
require "zlib"

load File.expand_path("../scripts/audit-xberg-cargo-closure", __dir__)

class XbergCargoClosureTest < Minitest::Test
  def filter(path, target, reason: "absolute-target", type: "symlink", mode: "120000")
    { "schema" => "agentlab-xberg-source-filter/v1", "release" => { "name" => "xberg", "version" => "1.0.1" }, "source" => { "tag" => "v1.0.1", "commit" => "commit", "tree" => "tree", "archive_sha256" => "sha256" }, "unsafe_links" => [{ "path" => path, "mode" => mode, "type" => type, "target" => target, "reason" => reason }] }
  end

  def with_archive(entries, receipt)
    Dir.mktmpdir do |directory|
      archive = File.join(directory, "source.tar.gz")
      filter_path = File.join(directory, "filter.json")
      Zlib::GzipWriter.open(archive) do |gzip|
        Gem::Package::TarWriter.new(gzip) do |tar|
          tar.mkdir("xberg-1.0.1", 0o755)
          entries.each do |entry|
            case entry.fetch(:type)
            when :file
              tar.add_file_simple(entry.fetch(:path), 0o644, entry.fetch(:content).bytesize) { |io| io.write(entry.fetch(:content)) }
            when :symlink
              tar.add_symlink(entry.fetch(:path), entry.fetch(:target), 0o777)
            end
          end
        end
      end
      File.write(filter_path, JSON.generate(receipt))
      yield archive, filter_path, directory
    end
  end

  def test_exact_reviewed_absolute_symlink_is_omitted_and_safe_link_is_retained
    target = "/reviewed/developer/fixture"
    with_archive([
      { type: :file, path: "xberg-1.0.1/test_documents/fixture", content: "fixture" },
      { type: :symlink, path: "xberg-1.0.1/e2e/safe", target: "../test_documents/fixture" },
      { type: :symlink, path: "xberg-1.0.1/e2e/unavailable", target: target }
    ], filter("xberg-1.0.1/e2e/unavailable", target)) do |archive, receipt, directory|
      root = XbergCargoClosure.extract_gzip!(archive, File.join(directory, "out"), filter: receipt)
      assert_equal("../test_documents/fixture", File.readlink(File.join(root, "e2e/safe")))
      refute_path_exists(File.join(root, "e2e/unavailable"))
    end
  end

  def test_unknown_absolute_symlink_is_rejected
    with_archive([{ type: :symlink, path: "xberg-1.0.1/e2e/unknown", target: "/unknown" }], filter("xberg-1.0.1/e2e/reviewed", "/reviewed")) do |archive, receipt, directory|
      assert_raises(XbergCargoClosure::Error) { XbergCargoClosure.extract_gzip!(archive, File.join(directory, "out"), filter: receipt) }
    end
  end

  def test_missing_expected_unsafe_link_is_rejected
    with_archive([{ type: :file, path: "xberg-1.0.1/README", content: "ok" }], filter("xberg-1.0.1/e2e/reviewed", "/reviewed")) do |archive, receipt, directory|
      assert_raises(XbergCargoClosure::Error) { XbergCargoClosure.extract_gzip!(archive, File.join(directory, "out"), filter: receipt) }
    end
  end

  def test_root_escaping_relative_symlink_is_filtered_only_when_receipted
    with_archive([{ type: :symlink, path: "xberg-1.0.1/e2e/escape", target: "../../../outside" }], filter("xberg-1.0.1/e2e/escape", "../../../outside", reason: "root-escaping-target")) do |archive, receipt, directory|
      root = XbergCargoClosure.extract_gzip!(archive, File.join(directory, "out"), filter: receipt)
      refute_path_exists(File.join(root, "e2e/escape"))
    end
  end

  def test_hardlink_targets_must_stay_in_the_archive_root
    assert_equal("xberg-1.0.1/file", XbergCargoClosure.safe_hardlink_target("xberg-1.0.1/link", "xberg-1.0.1/file"))
    assert_raises(XbergCargoClosure::Error) { XbergCargoClosure.safe_hardlink_target("xberg-1.0.1/link", "../outside") }
    assert_raises(XbergCargoClosure::Error) { XbergCargoClosure.safe_hardlink_target("xberg-1.0.1/link", "/outside") }
  end

  def test_duplicate_archive_entries_are_rejected
    with_archive([
      { type: :file, path: "xberg-1.0.1/duplicate", content: "first" },
      { type: :file, path: "xberg-1.0.1/duplicate", content: "second" }
    ], filter("xberg-1.0.1/e2e/reviewed", "/reviewed")) do |archive, receipt, directory|
      assert_raises(XbergCargoClosure::Error) { XbergCargoClosure.extract_gzip!(archive, File.join(directory, "out"), filter: receipt) }
    end
  end

  def test_sanitize_only_scans_without_following_and_removes_only_receipted_link
    Dir.mktmpdir do |directory|
      root = File.join(directory, "xberg-1.0.1")
      FileUtils.mkdir_p(File.join(root, "e2e"))
      File.symlink("/reviewed", File.join(root, "e2e/reviewed"))
      File.symlink("inside", File.join(root, "e2e/safe"))
      receipt = File.join(directory, "filter.json")
      File.write(receipt, JSON.generate(filter("xberg-1.0.1/e2e/reviewed", "/reviewed")))
      XbergCargoClosure.sanitize_tree!(root, filter: receipt)
      refute_path_exists(File.join(root, "e2e/reviewed"))
      assert_equal("inside", File.readlink(File.join(root, "e2e/safe")))
    end
  end
end
