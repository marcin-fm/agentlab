# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "open3"

class AcquireOpenChamberSourcesTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  SCRIPT = File.join(ROOT, "scripts", "acquire-openchamber-sources")
  BASE_SCRIPT = File.join(ROOT, "scripts", "acquire-opencode-sources")
  NODE_SOURCE_ENV_KEYS = %w[
    AGENTLAB_NODE_SOURCE_PACKAGE AGENTLAB_NODE_SELECTED_SCHEMA AGENTLAB_NODE_SOURCE_SCHEMA
    AGENTLAB_NODE_SOURCE_WORKDIR AGENTLAB_NODE_SOURCE_OUTPUT AGENTLAB_NODE_SOURCE_MARKER
    AGENTLAB_NODE_SOURCE_LABEL AGENTLAB_NODE_SELECTED_LOCK_FILE_KEY
  ].freeze

  def clean_source_env(overrides = {})
    NODE_SOURCE_ENV_KEYS.to_h { |key| [key, nil] }.merge(overrides)
  end

  def test_plan_deduplicates_the_selected_registry_sources
    stdout, stderr, status = Open3.capture3("ruby", SCRIPT, "--plan", chdir: ROOT)

    assert(status.success?, stderr)
    plan = JSON.parse(stdout)
    assert_equal(832, plan.fetch("selected_package_records"))
    assert_equal(818, plan.fetch("unique_sources"))
    assert_equal({ "github" => 0, "registry" => 818 }, plan.fetch("origins"))
  end

  def test_opencode_retains_the_default_selected_lock_key
    stdout, stderr, status = Open3.capture3(clean_source_env, "ruby", BASE_SCRIPT, "--plan", chdir: ROOT)

    assert(status.success?, stderr)
    assert_operator(JSON.parse(stdout).fetch("selected_package_records"), :>, 0)
  end

  def test_missing_selected_lock_key_fails_closed
    env = clean_source_env(
      "AGENTLAB_NODE_SOURCE_PACKAGE" => "openchamber",
      "AGENTLAB_NODE_SELECTED_LOCK_FILE_KEY" => "missing_selected_lock"
    )
    _stdout, stderr, status = Open3.capture3(env, "ruby", BASE_SCRIPT, "--plan", chdir: ROOT)

    refute(status.success?)
    assert_match(/source closure file key is missing: missing_selected_lock/, stderr)
  end
end
