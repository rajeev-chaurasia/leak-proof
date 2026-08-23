# frozen_string_literal: true

require_relative "../registry"
require_relative "../../validity/contract"

Leakproof::Detectors::Registry.register(
  Leakproof::Detectors::Detector.new(
    id: "mailgun-api-key",
    keywords: %w[key-],
    name: "Mailgun API key",
    pattern: /\b(key-[0-9a-f]{32})\b/,
    capture: 1,
    charset: :hex,
    validity: Leakproof::Validity::Contract.new(prefix: "key-", length: 36, charset: :hex),
    specificity: :high,
    sample: ->(s) { "key-#{s.hex(32)}" },
    notes: "Prefix and hex length only.",
    examples: {
      positive: [],
      negative: %w[key-short]
    }
  )
)
