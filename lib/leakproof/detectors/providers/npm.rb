# frozen_string_literal: true

require_relative "../registry"
require_relative "../../validity/crc32_base62"

Leakproof::Detectors::Registry.register(
  Leakproof::Detectors::Detector.new(
    id: "npm-access-token",
    keywords: %w[npm_],
    name: "npm access token",
    pattern: /\b(npm_[A-Za-z0-9]{36})\b/,
    capture: 1,
    charset: :base62,
    validity: Leakproof::Validity::Crc32Base62.new(entropy_length: 30),
    specificity: :high,
    sample: ->(s) { s.crc32_token("npm_") },
    notes: "Same base62 CRC32 scheme GitHub uses.",
    examples: { positive: [], negative: ["npm_#{"0" * 36}"] }
  )
)
