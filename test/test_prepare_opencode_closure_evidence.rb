# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "tmpdir"
load File.expand_path("../scripts/prepare-opencode-closure-evidence", __dir__)

class PrepareOpenCodeClosureEvidenceTest < Minitest::Test
  def test_generates_fail_closed_current_evidence
    package_dir = File.expand_path("../packages/opencode", __dir__)
    Dir.mktmpdir do |output_dir|
      receipts = Agentlab::OpenCodeClosureEvidence.prepare!(package_dir: package_dir, output_dir: output_dir)
      closure = JSON.parse(File.read(File.join(output_dir, "opencode-1.18.5-closure.json")))

      assert_equal(1_019, closure.fetch("packages").length)
      assert(closure.fetch("packages").none? { |record| record.fetch("included_in_binary") })
      refute(closure.dig("validation", "bundled_provides_verified"))
      refute(closure.dig("validation", "offline_build_verified"))
      assert_equal(3, receipts.length)
    end
  end
end
