# frozen_string_literal: true

require_relative "../registry"
require_relative "../../validity/contract"

Leakproof::Detectors::Registry.register(
  Leakproof::Detectors::Detector.new(
    id: "sendgrid-api-key",
    name: "SendGrid API key",
    pattern: /\b(SG\.[A-Za-z0-9_-]{22}\.[A-Za-z0-9_-]{43})\b/,
    capture: 1,
    validity: Leakproof::Validity::Contract.new(prefix: "SG.", length: 69),
    specificity: :high,
    sample: ->(s) { "SG.#{s.base64url(22)}.#{s.base64url(43)}" },
    notes: "Three-segment structure and length only.",
    examples: {
      positive: [],
      negative: ["SG.short.short"]
    }
  )
)
