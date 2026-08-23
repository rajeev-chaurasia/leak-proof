# frozen_string_literal: true

require_relative "../registry"
require_relative "../../validity/contract"

Leakproof::Detectors::Registry.register(
  Leakproof::Detectors::Detector.new(
    id: "openai-api-key",
    keywords: %w[sk-],
    name: "OpenAI API key",
    pattern: /\b(sk-(?:proj-)?[A-Za-z0-9_-]{20,})\b/,
    capture: 1,
    validity: Leakproof::Validity::Contract.new(prefix: "sk-", length: 23..200),
    specificity: :medium,
    sample: ->(s) { "sk-#{s.base62(32)}" },
    notes: "Prefix and length only. The hyphen separates this from Stripe's sk_ underscore form.",
    examples: {
      positive: [],
      negative: %w[sk-short]
    }
  )
)
