# frozen_string_literal: true

require "minitest/autorun"
require_relative "../scripts/lib/package_release"

class PackageReleaseTest < Minitest::Test
  def test_accepts_normal_agentlab_release
    assert(Agentlab::PackageRelease.valid?("0.4%{?dist}"))
    refute(Agentlab::PackageRelease.valid?("4.1%{?dist}"))
  end

  def test_accepts_fedora_adaptation_dot_release
    assert(Agentlab::PackageRelease.valid?("5.1%{?dist}", policy: "fedora_adaptation"))
    refute(Agentlab::PackageRelease.valid?("5%{?dist}", policy: "fedora_adaptation"))
    refute(Agentlab::PackageRelease.valid?("0.1%{?dist}", policy: "fedora_adaptation"))
  end
end
