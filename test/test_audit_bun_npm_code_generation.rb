#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "tmpdir"
load File.expand_path("../scripts/audit-bun-npm-code-generation", __dir__)

class BunNpmCodeGenerationAuditTest < Minitest::Test
  def test_supplemental_text_must_share_the_checked_source_directory
    Dir.mktmpdir("agentlab-bun-codegen-test-", "/srv/tmp") do |root|
      checked = File.join(root, "checked")
      outside = File.join(root, "outside")
      FileUtils.mkdir_p([checked, outside])
      license = File.join(outside, "bun-1.3.14-peechy-0.4.34-LICENSE.md")
      FileUtils.cp(File.expand_path("../packages/bun/bun-1.3.14-peechy-0.4.34-LICENSE.md", __dir__), license)

      error = assert_raises(BunNpmCodeGenerationAudit::Error) do
        BunNpmCodeGenerationAudit.supplemental_license_text(
          "peechy",
          "0.4.34",
          "MIT",
          license,
          expected_directory: checked
        )
      end
      assert_match(/outside the checked source directory/, error.message)
    end
  end
end
