# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "open3"
require "rbconfig"
require "tempfile"
require "tmpdir"

load File.expand_path("../scripts/audit-xberg-model-source", __dir__)

class TestAuditXbergModelSource < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  PACKAGE_DIR = File.join(ROOT, "packages/xberg")
  WITNESS_DIR = PACKAGE_DIR
  INPUTS = {
    released_witness: File.join(WITNESS_DIR, "xberg-1.0.3-lightweight-released-source.json"),
    mirror_tree: File.join(WITNESS_DIR, "xberg-embedding-models-4b127809-potion-tree.json"),
    upstream_tree: File.join(WITNESS_DIR, "minishlab-potion-base-8M-bf8b0566-tree.json"),
    upstream_readme: File.join(WITNESS_DIR, "minishlab-potion-base-8M-bf8b0566-README.md")
  }.freeze

  def test_regenerates_checked_receipt_from_tracked_witnesses
    Tempfile.create(["xberg-model-source", ".json"]) do |output|
      command = [
        RbConfig.ruby,
        File.join(ROOT, "scripts/audit-xberg-model-source"),
        "--released-witness", INPUTS.fetch(:released_witness),
        "--mirror-tree", INPUTS.fetch(:mirror_tree),
        "--upstream-tree", INPUTS.fetch(:upstream_tree),
        "--upstream-readme", INPUTS.fetch(:upstream_readme),
        "--output", output.path
      ]
      _stdout, stderr, status = Open3.capture3(*command)

      assert(status.success?, stderr)
      assert_equal(File.binread(File.join(PACKAGE_DIR, "xberg-1.0.3-lightweight-model-source.json")), File.binread(output.path))
    end
  end

  def test_rejects_tampered_tree_response
    Dir.mktmpdir("xberg-model-source") do |directory|
      tampered = File.join(directory, "mirror-tree.json")
      rows = JSON.parse(File.binread(INPUTS.fetch(:mirror_tree)))
      rows.first["oid"] = "0" * 40
      File.write(tampered, JSON.generate(rows) + "\n")

      error = assert_raises(ArgumentError) do
        XbergModelSource.build(**INPUTS.merge(mirror_tree: tampered))
      end
      assert_match(/mirror object id differs/, error.message)
    end
  end

  def test_rejects_absent_upstream_only_file
    Dir.mktmpdir("xberg-model-source") do |directory|
      incomplete = File.join(directory, "upstream-tree.json")
      rows = JSON.parse(File.binread(INPUTS.fetch(:upstream_tree)))
      rows.reject! { |row| row["path"] == "tokenizer.json" }
      File.write(incomplete, JSON.generate(rows) + "\n")

      error = assert_raises(ArgumentError) do
        XbergModelSource.build(**INPUTS.merge(upstream_tree: incomplete))
      end
      assert_match(/upstream tree file set differs/, error.message)
    end
  end

  def test_rejects_reencoded_tree_response
    Dir.mktmpdir("xberg-model-source") do |directory|
      reencoded = File.join(directory, "mirror-tree.json")
      rows = JSON.parse(File.binread(INPUTS.fetch(:mirror_tree)))
      File.write(reencoded, JSON.pretty_generate(rows) + "\n")

      error = assert_raises(ArgumentError) do
        XbergModelSource.build(**INPUTS.merge(mirror_tree: reencoded))
      end
      assert_match(/mirror tree response checksum differs/, error.message)
    end
  end

  def test_rejects_missing_tree_response
    error = assert_raises(ArgumentError) do
      XbergModelSource.build(**INPUTS.merge(mirror_tree: File.join(WITNESS_DIR, "missing.json")))
    end
    assert_match(/missing mirror tree response/, error.message)
  end
end
