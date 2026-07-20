# frozen_string_literal: true

module Agentlab
  module PackageRelease
    DEFAULT_PATTERN = /\A0\.(?:0\.)?[1-9][0-9]*%\{\?dist\}\z/
    FEDORA_ADAPTATION_PATTERN = /\A[1-9][0-9]*(?:\.[1-9][0-9]*)+%\{\?dist\}\z/

    module_function

    def valid?(release, policy: nil)
      pattern = policy == "fedora_adaptation" ? FEDORA_ADAPTATION_PATTERN : DEFAULT_PATTERN
      release.to_s.match?(pattern)
    end

    def description(policy: nil)
      return "a Fedora base Release with an Agentlab dot revision" if policy == "fedora_adaptation"

      "0.x%{?dist} or legacy 0.0.x%{?dist}"
    end
  end
end
