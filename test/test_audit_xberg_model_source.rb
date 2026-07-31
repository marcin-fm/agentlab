# frozen_string_literal: true

require "minitest/autorun"
require "open3"
require "rbconfig"
require "tempfile"

load File.expand_path("../scripts/audit-xberg-model-source", __dir__)

class TestAuditXbergModelSource < Minitest::Test
  def test_file_record_binds_content
    Tempfile.create("xberg-model") do |file|
      file.write("model bytes")
      file.flush

      assert_equal(
        { "path" => File.basename(file.path), "bytes" => 11, "sha256" => "9cb7487000bc86ac36ce83c4acfabe8878552be99572a6770f65ab1d048a5c48" },
        XbergModelSource.file_record(file.path)
      )
    end
  end

  def test_upstream_tree_rejects_license_text_claim
    Tempfile.create(["potion-tree", ".json"]) do |file|
      rows = XbergModelSource::FILES.keys.map { |path| { "type" => "file", "path" => path } }
      rows << { "type" => "file", "path" => "LICENSE" }
      file.write(JSON.generate(rows))
      file.flush

      error = assert_raises(ArgumentError) { XbergModelSource.upstream_tree_record(file.path) }
      assert_match(/unexpectedly contains license text/, error.message)
    end
  end

  def test_regenerates_checked_receipt_from_exact_sources
    source = ENV["AGENTLAB_XBERG_RELEASED_SOURCE"]
    upstream = ENV["AGENTLAB_XBERG_POTION_SOURCE"]
    tree = ENV["AGENTLAB_XBERG_POTION_TREE"]
    assert(source && upstream && tree, "set all Xberg model-source fixture variables") if source || upstream || tree
    skip("exact Xberg and Potion sources are not available") unless source && upstream && tree

    package_dir = File.expand_path("../packages/xberg", __dir__)
    expected = File.join(package_dir, "xberg-1.0.3-lightweight-model-source.json")
    Tempfile.create(["xberg-model-source", ".json"]) do |output|
      command = [
        RbConfig.ruby,
        File.expand_path("../scripts/audit-xberg-model-source", __dir__),
        "--released-source", source,
        "--upstream-dir", upstream,
        "--upstream-tree", tree,
        "--output", output.path
      ]
      _stdout, stderr, status = Open3.capture3(*command)

      assert(status.success?, stderr)
      assert_equal(File.binread(expected), File.binread(output.path))
    end
  end
end
