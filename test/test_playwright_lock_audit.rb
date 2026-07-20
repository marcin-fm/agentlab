#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require_relative "../scripts/lib/agentlab"
load File.expand_path("../scripts/audit-playwright-lock-closure", __dir__)

class PlaywrightLockAuditTest < Minitest::Test
  def test_filters_musl_and_wrong_cpu_records
    target = { "os" => "linux", "cpu" => "x64", "libc" => "glibc" }
    gnu = {
      "resolved" => "https://registry.npmjs.org/example-linux-x64-gnu/-/example-linux-x64-gnu-1.0.0.tgz",
      "os" => ["linux"],
      "cpu" => ["x64"]
    }
    musl = gnu.merge("resolved" => "https://registry.npmjs.org/example-linux-x64-musl/-/example-linux-x64-musl-1.0.0.tgz")
    arm64 = gnu.merge("cpu" => ["arm64"])

    assert_equal([true, nil], PlaywrightLockAudit.platform_allowed?("node_modules/example-linux-x64-gnu", gnu, target))
    assert_equal([false, "libc"], PlaywrightLockAudit.platform_allowed?("node_modules/example-linux-x64-musl", musl, target))
    assert_equal([false, "cpu"], PlaywrightLockAudit.platform_allowed?("node_modules/example-linux-arm64-gnu", arm64, target))
  end

  def test_classifies_registry_workspaces_and_links
    lock = {
      "packages" => {
        "" => { "name" => "root" },
        "packages/module" => { "name" => "module", "version" => "1.0.0" },
        "node_modules/module" => { "resolved" => "packages/module", "link" => true },
        "node_modules/dependency" => {
          "version" => "2.0.0",
          "resolved" => "https://registry.npmjs.org/dependency/-/dependency-2.0.0.tgz",
          "integrity" => "sha512-fixture"
        }
      }
    }

    registry, workspaces, links = PlaywrightLockAudit.classify_packages(lock)

    assert_equal(["node_modules/dependency"], registry.map(&:first))
    assert_equal(["packages/module"], workspaces.map(&:first))
    assert_equal(["node_modules/module"], links.map(&:first))
  end

  def test_selected_summary_distinguishes_names_from_versions
    records = [
      { "npm_name" => "example", "version" => "1.0.0", "declared_license" => "MIT", "selected_targets" => ["target"] },
      { "npm_name" => "example", "version" => "2.0.0", "declared_license" => "MIT", "selected_targets" => ["target"] },
      { "npm_name" => "other", "version" => "1.0.0", "declared_license" => "ISC", "selected_targets" => [] }
    ]

    summary = PlaywrightLockAudit.selected_summary(records, "target")

    assert_equal(2, summary.fetch("registry_records"))
    assert_equal(1, summary.fetch("unique_npm_names"))
    assert_equal(2, summary.fetch("unique_name_version_identities"))
    assert_equal(1, summary.fetch("platform_excluded_records"))
  end
end
