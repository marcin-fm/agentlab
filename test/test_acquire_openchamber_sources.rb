# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "open3"

class AcquireOpenChamberSourcesTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  SCRIPT = File.join(ROOT, "scripts", "acquire-openchamber-sources")

  def test_plan_deduplicates_the_selected_registry_sources
    stdout, stderr, status = Open3.capture3("ruby", SCRIPT, "--plan", chdir: ROOT)

    assert(status.success?, stderr)
    plan = JSON.parse(stdout)
    assert_equal(832, plan.fetch("selected_package_records"))
    assert_equal(818, plan.fetch("unique_sources"))
    assert_equal({ "github" => 0, "registry" => 818 }, plan.fetch("origins"))
  end
end
