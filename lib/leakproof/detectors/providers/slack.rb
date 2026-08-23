# frozen_string_literal: true

require_relative "../registry"
require_relative "../../validity/contract"

Leakproof::Detectors::Registry.register(
  Leakproof::Detectors::Detector.new(
    id: "slack-token",
    name: "Slack token",
    pattern: /\b(xox[baprs]-[A-Za-z0-9-]{10,72})(?![A-Za-z0-9_-])/,
    capture: 1,
    validity: Leakproof::Validity::Contract.new(length: 15..90),
    specificity: :high,
    sample: ->(s) { "xoxb-#{s.digits(12)}-#{s.digits(13)}-#{s.base62(24)}" },
    notes: "Prefix and length only.",
    examples: { positive: [], negative: ["xoxb-short"] }
  )
)

Leakproof::Detectors::Registry.register(
  Leakproof::Detectors::Detector.new(
    id: "slack-webhook-url",
    name: "Slack incoming webhook URL",
    pattern: %r{(https://hooks\.slack\.com/services/T[A-Za-z0-9_]+/B[A-Za-z0-9_]+/[A-Za-z0-9_]{16,})},
    capture: 1,
    validity: Leakproof::Validity::Contract.new(prefix: "https://hooks.slack.com/"),
    specificity: :high,
    sample: lambda { |s|
      "https://hooks.slack.com/services/T#{s.base62(8)}/B#{s.base62(8)}/#{s.base62(24)}"
    },
    notes: "Structural URL shape only.",
    examples: { positive: [], negative: ["https://hooks.slack.com/services/short"] }
  )
)
