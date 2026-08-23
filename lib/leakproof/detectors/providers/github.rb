# frozen_string_literal: true

require_relative "../registry"
require_relative "../../validity/crc32_base62"

module Leakproof
  module Detectors
    module Providers
      module Github
        CLASSIC = {
          "github-pat" => ["ghp_", "personal access token"],
          "github-oauth-token" => ["gho_", "OAuth access token"],
          "github-user-to-server" => ["ghu_", "user-to-server token"],
          "github-server-to-server" => ["ghs_", "server-to-server token"],
          "github-refresh-token" => ["ghr_", "refresh token"]
        }.freeze
      end
    end
  end
end

Leakproof::Detectors::Providers::Github::CLASSIC.each do |id, (prefix, description)|
  Leakproof::Detectors::Registry.register(
    Leakproof::Detectors::Detector.new(
      id: id,
      name: "GitHub #{description}",
      pattern: /\b(#{prefix}[A-Za-z0-9]{36})\b/,
      capture: 1,
      charset: :base62,
      validity: Leakproof::Validity::Crc32Base62.new(entropy_length: 30),
      specificity: :high,
      sample: ->(s) { s.crc32_token(prefix) },
      notes: "Last six characters are a base62 CRC32 of the preceding thirty.",
      examples: { positive: [], negative: ["#{prefix}#{"0" * 36}"] }
    )
  )
end

Leakproof::Detectors::Registry.register(
  Leakproof::Detectors::Detector.new(
    id: "github-fine-grained-pat",
    name: "GitHub fine-grained personal access token",
    pattern: /\b(github_pat_[A-Za-z0-9_]{82})\b/,
    capture: 1,
    validity: Leakproof::Validity::Contract.new(prefix: "github_pat_", length: 93),
    specificity: :high,
    sample: ->(s) { "github_pat_#{s.base62(82)}" },
    notes: "Length contract only. The fine-grained format publishes no checksum.",
    examples: { positive: [], negative: ["github_pat_short"] }
  )
)
