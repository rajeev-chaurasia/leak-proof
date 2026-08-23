# frozen_string_literal: true

require_relative "../registry"
require_relative "../../validity/contract"

Leakproof::Detectors::Registry.register(
  Leakproof::Detectors::Detector.new(
    id: "stripe-secret-key",
    name: "Stripe secret key",
    pattern: /\b((?:sk|rk)_(?:live|test)_[A-Za-z0-9]{24,99})\b/,
    capture: 1,
    charset: :base62,
    validity: Leakproof::Validity::Contract.new(length: 32..110),
    specificity: :high,
    sample: ->(s) { "sk_live_#{s.base62(24)}" },
    notes: "Prefix and length only. Stripe publishes no offline checksum.",
    examples: {
      positive: [],
      negative: %w[sk_live_short]
    }
  )
)

# Publishable keys ship in client-side bundles by design. Reporting one as a leak
# is what forces a project to start keeping an ignore file.
Leakproof::Detectors::Registry.register(
  Leakproof::Detectors::Detector.new(
    id: "stripe-publishable-key",
    name: "Stripe publishable key",
    pattern: /\b(pk_(?:live|test)_[A-Za-z0-9]{24,99})\b/,
    capture: 1,
    charset: :base62,
    validity: Leakproof::Validity::Contract.new(length: 32..110),
    specificity: :high,
    secret: false,
    sample: ->(s) { "pk_test_#{s.base62(24)}" },
    notes: "Public by design. Detected so it can be dismissed explicitly rather than " \
           "matched by a generic rule.",
    examples: {
      positive: [],
      negative: ["pk_live_short"]
    }
  )
)
