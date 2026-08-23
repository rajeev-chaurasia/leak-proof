# frozen_string_literal: true

require_relative "../registry"
require_relative "../../validity/jwt"

Leakproof::Detectors::Registry.register(
  Leakproof::Detectors::Detector.new(
    id: "json-web-token",
    name: "JSON web token",
    pattern: /\b(eyJ[A-Za-z0-9_-]{6,}\.eyJ[A-Za-z0-9_-]{6,}\.[A-Za-z0-9_-]{6,})(?![A-Za-z0-9_-])/,
    capture: 1,
    charset: :base64url,
    validity: Leakproof::Validity::Jwt.new,
    specificity: :high,
    sample: ->(s) { s.jwt },
    notes: "Header and payload decode offline, so expiry is settled without asking anyone.",
    examples: { positive: [], negative: ["eyJshort.eyJshort.sig"] }
  )
)
