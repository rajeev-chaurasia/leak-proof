# frozen_string_literal: true

require_relative "../registry"
require_relative "../../validity/contract"

Leakproof::Detectors::Registry.register(
  Leakproof::Detectors::Detector.new(
    id: "google-api-key",
    name: "Google API key",
    pattern: /\b(AIza[0-9A-Za-z_-]{35})(?![A-Za-z0-9_-])/,
    capture: 1,
    charset: :base64url,
    validity: Leakproof::Validity::Contract.new(prefix: "AIza", length: 39),
    specificity: :high,
    sample: ->(s) { "AIza#{s.base64url(35)}" },
    notes: "Prefix and length only.",
    examples: {
      positive: [],
      negative: %w[AIzaShort BIzaSyD-ExampleKeyMaterial_1234567890abc]
    }
  )
)
