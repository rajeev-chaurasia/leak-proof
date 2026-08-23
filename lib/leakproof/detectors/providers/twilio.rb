# frozen_string_literal: true

require_relative "../registry"
require_relative "../../validity/contract"

Leakproof::Detectors::Registry.register(
  Leakproof::Detectors::Detector.new(
    id: "twilio-api-key",
    name: "Twilio API key SID",
    pattern: /\b(SK[0-9a-fA-F]{32})\b/,
    capture: 1,
    charset: :hex,
    validity: Leakproof::Validity::Contract.new(prefix: "SK", length: 34, charset: :hex),
    specificity: :medium,
    sample: ->(s) { "SK#{s.hex(32)}" },
    notes: "Prefix and hex length only. Collides readily with hex digests, so context does the work.",
    examples: {
      positive: [],
      negative: %w[SK0123]
    }
  )
)

# An account SID is an identifier, not a credential: it appears in Twilio's own
# console and in request URLs, and cannot authenticate without the paired auth
# token. Detected so it can be dismissed deliberately rather than by a generic
# hex rule. GitHub's own push protection flags these, which is how this gap was
# found.
Leakproof::Detectors::Registry.register(
  Leakproof::Detectors::Detector.new(
    id: "twilio-account-sid",
    name: "Twilio account SID",
    pattern: /\b(AC[0-9a-fA-F]{32})\b/,
    capture: 1,
    charset: :hex,
    validity: Leakproof::Validity::Contract.new(prefix: "AC", length: 34, charset: :hex),
    specificity: :medium,
    secret: false,
    sample: ->(s) { "AC#{s.hex(32)}" },
    notes: "Identifier rather than credential. Useless without the paired auth token.",
    examples: {
      positive: [],
      negative: %w[AC0123]
    }
  )
)
