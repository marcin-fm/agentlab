# frozen_string_literal: true

require "minitest/autorun"
require "stringio"
require "tmpdir"
require "zlib"

load File.expand_path("../scripts/audit-xberg-cargo-closure", __dir__)

class XbergCargoClosureTest < Minitest::Test
  def filter(path, target, reason: "absolute-target", type: "symlink", mode: "120000", safe_links: 0)
    symlinks = safe_links + (type == "symlink" ? 1 : 0)
    hardlinks = type == "hardlink" ? 1 : 0
    { "schema" => "agentlab-xberg-source-filter/v1", "release" => { "name" => "xberg", "version" => XbergCargoClosure::VERSION }, "source" => { "tag" => "v#{XbergCargoClosure::VERSION}", "commit" => "commit", "tree" => "tree", "archive_sha256" => "sha256" }, "archive_link_inventory" => { "symlinks" => symlinks, "hardlinks" => hardlinks, "safe_in_root_links" => safe_links, "unsafe_links" => 1 }, "unsafe_links" => [{ "path" => path, "mode" => mode, "type" => type, "target" => target, "reason" => reason }] }
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

  def tar_header(name, typeflag:, size: 0, linkname: "")
    Gem::Package::TarHeader.new(name: name, mode: 0o644, size: size, mtime: 0, checksum: "", typeflag: typeflag, linkname: linkname, magic: "ustar", version: "00", uname: "", gname: "", devmajor: 0, devminor: 0, prefix: "").to_s
  end

  def with_raw_archive(records)
    Dir.mktmpdir do |directory|
      archive = File.join(directory, "source.tar.gz")
      Zlib::GzipWriter.open(archive) do |gzip|
        records.each do |record|
          gzip.write(tar_header(record.fetch(:name), typeflag: record.fetch(:type), size: record.fetch(:data, "").bytesize, linkname: record.fetch(:linkname, "")))
          data = record.fetch(:data, "")
          gzip.write(data)
          gzip.write("\0" * ((512 - data.bytesize % 512) % 512))
        end
        gzip.write("\0" * 1024)
      end
      yield archive, directory
    end
  end

  def pax_record(key, value)
    record = "#{key}=#{value}\n"
    length = record.bytesize + 3
    loop do
      candidate = "#{length} #{record}"
      return candidate if candidate.bytesize == length

      length = candidate.bytesize
    end
  end

  def test_exact_reviewed_absolute_symlink_is_omitted_and_safe_link_is_retained
    target = "/reviewed/developer/fixture"
    with_archive([
      { type: :file, path: "xberg-1.0.1/test_documents/fixture", content: "fixture" },
      { type: :symlink, path: "xberg-1.0.1/e2e/safe", target: "../test_documents/fixture" },
      { type: :symlink, path: "xberg-1.0.1/e2e/unavailable", target: target }
    ], filter("xberg-1.0.1/e2e/unavailable", target, safe_links: 1)) do |archive, receipt, directory|
      root = XbergCargoClosure.extract_gzip!(archive, File.join(directory, "out"), filter: receipt)
      assert_equal("../test_documents/fixture", File.readlink(File.join(root, "e2e/safe")))
      refute_path_exists(File.join(root, "e2e/unavailable"))
    end
  end

  def test_archive_link_inventory_must_match_the_checked_filter
    target = "/reviewed/developer/fixture"
    with_archive([
      { type: :file, path: "xberg-1.0.1/test_documents/fixture", content: "fixture" },
      { type: :symlink, path: "xberg-1.0.1/e2e/safe", target: "../test_documents/fixture" },
      { type: :symlink, path: "xberg-1.0.1/e2e/unavailable", target: target }
    ], filter("xberg-1.0.1/e2e/unavailable", target)) do |archive, receipt, directory|
      error = assert_raises(XbergCargoClosure::Error) { XbergCargoClosure.extract_gzip!(archive, File.join(directory, "out"), filter: receipt) }
      assert_includes(error.message, "archive link inventory differs")
    end
  end

  def test_unknown_absolute_symlink_is_rejected
    with_archive([{ type: :symlink, path: "xberg-1.0.1/e2e/unknown", target: "/unknown" }], filter("xberg-1.0.1/e2e/reviewed", "/reviewed")) do |archive, receipt, directory|
      assert_raises(XbergCargoClosure::Error) { XbergCargoClosure.extract_gzip!(archive, File.join(directory, "out"), filter: receipt) }
    end
  end

  def test_safe_archive_does_not_require_a_filter
    with_archive([{ type: :file, path: "xberg-1.0.1/README", content: "ok" }], filter("xberg-1.0.1/e2e/reviewed", "/reviewed")) do |archive, _receipt, directory|
      root = XbergCargoClosure.extract_gzip!(archive, File.join(directory, "out"))
      assert_equal("ok", File.read(File.join(root, "README")))
    end
  end

  def test_unsafe_archive_without_a_filter_is_rejected
    with_archive([{ type: :symlink, path: "xberg-1.0.1/e2e/unknown", target: "/unknown" }], filter("xberg-1.0.1/e2e/reviewed", "/reviewed")) do |archive, _receipt, directory|
      error = assert_raises(XbergCargoClosure::Error) { XbergCargoClosure.extract_gzip!(archive, File.join(directory, "out")) }
      assert_includes(error.message, "require a checked source filter")
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

  def test_gnu_long_path_is_used_for_duplicate_detection_and_extraction
    path = "xberg-1.0.1/" + ("a" * 120)
    with_raw_archive([
      { name: "././@LongLink", type: "L", data: "#{path}\0" },
      { name: path[0, 100], type: "0", data: "one" }
    ]) do |archive, directory|
      root = XbergCargoClosure.extract_gzip!(archive, File.join(directory, "out"))
      assert_equal("one", File.read(File.join(root, "a" * 120)))
    end
  end

  def test_gnu_long_link_target_is_used
    target = "../" + ("b" * 130)
    with_raw_archive([
      { name: "xberg-1.0.1/" + ("b" * 130), type: "0", data: "target" },
      { name: "././@LongLink", type: "K", data: "#{target}\0" },
      { name: "xberg-1.0.1/links/link", type: "2", linkname: target[0, 100] }
    ]) do |archive, directory|
      root = XbergCargoClosure.extract_gzip!(archive, File.join(directory, "out"))
      assert_equal(target, File.readlink(File.join(root, "links/link")))
    end
  end

  def test_pax_path_and_linkpath_override_headers
    path = "xberg-1.0.1/" + ("p" * 120)
    target = "../" + ("q" * 130)
    with_raw_archive([
      { name: "xberg-1.0.1/" + ("q" * 130), type: "0", data: "target" },
      { name: "PaxHeader", type: "x", data: pax_record("path", path) },
      { name: "ignored", type: "0", data: "file" },
      { name: "PaxHeader", type: "x", data: pax_record("linkpath", target) },
      { name: "xberg-1.0.1/links/link", type: "2", linkname: "ignored" }
    ]) do |archive, directory|
      root = XbergCargoClosure.extract_gzip!(archive, File.join(directory, "out"))
      assert_equal("file", File.read(File.join(root, "p" * 120)))
      assert_equal(target, File.readlink(File.join(root, "links/link")))
    end
  end

  def test_global_pax_path_is_preserved_for_following_entries
    path = "xberg-1.0.1/global"
    with_raw_archive([
      { name: "PaxHeader", type: "g", data: pax_record("path", path) },
      { name: "ignored", type: "0", data: "global" }
    ]) do |archive, directory|
      root = XbergCargoClosure.extract_gzip!(archive, File.join(directory, "out"))
      assert_equal("global", File.read(File.join(root, "global")))
    end
  end

  def test_malformed_dangling_and_conflicting_extension_records_are_rejected
    malformed = [{ name: "PaxHeader", type: "x", data: "12 path=bad\n" }]
    dangling = [{ name: "././@LongLink", type: "L", data: "xberg-1.0.1/long\0" }]
    conflicting = [
      { name: "././@LongLink", type: "L", data: "xberg-1.0.1/one\0" },
      { name: "PaxHeader", type: "x", data: pax_record("path", "xberg-1.0.1/two") },
      { name: "ignored", type: "0", data: "file" }
    ]
    [malformed, dangling, conflicting].each do |records|
      with_raw_archive(records) do |archive, directory|
        assert_raises(XbergCargoClosure::Error) { XbergCargoClosure.extract_gzip!(archive, File.join(directory, "out")) }
      end
    end
  end

  def test_duplicate_effective_pax_paths_are_rejected
    path = "xberg-1.0.1/effective"
    with_raw_archive([
      { name: "PaxHeader", type: "x", data: pax_record("path", path) },
      { name: "first", type: "0", data: "one" },
      { name: "PaxHeader", type: "x", data: pax_record("path", path) },
      { name: "second", type: "0", data: "two" }
    ]) do |archive, directory|
      error = assert_raises(XbergCargoClosure::Error) { XbergCargoClosure.extract_gzip!(archive, File.join(directory, "out")) }
      assert_includes(error.message, "duplicate archive entry #{path}")
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

  def test_identity_digest_uses_sorted_unique_tab_delimited_lines
    canonical = "alpha\t1.0.0\nbeta\t2.0.0\n"
    assert_equal(Digest::SHA256.hexdigest(canonical), XbergCargoClosure.identity_digest([["alpha", "1.0.0"], ["beta", "2.0.0"]]))
    assert_raises(XbergCargoClosure::Error) { XbergCargoClosure.identity_digest([["beta", "2.0.0"], ["alpha", "1.0.0"]]) }
  end
end
