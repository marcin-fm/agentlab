#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "open3"
require "rbconfig"

class PrepareBunSrpmSourcesTest < Minitest::Test
  def test_rejects_union_output_outside_srv_tmp_before_source_acquisition
    script = File.expand_path("../scripts/prepare-bun-srpm-sources", __dir__)
    _stdout, stderr, status = Open3.capture3(RbConfig.ruby, script, "--spec", "missing.spec", "--union-output", "/var/tmp/bun-union.tar.gz")

    refute(status.success?)
    assert_includes(stderr, "union output must be below /srv/tmp")
  end
end
