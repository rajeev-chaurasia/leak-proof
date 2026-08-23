# frozen_string_literal: true

require_relative "../registry"
require_relative "../../validity/pem"

Leakproof::Detectors::Registry.register(
  Leakproof::Detectors::Detector.new(
    id: "private-key",
    name: "Private key",
    pattern: /(-----BEGIN (?:[A-Z0-9 ]+ )?PRIVATE KEY-----.*?-----END (?:[A-Z0-9 ]+ )?PRIVATE KEY-----)/m,
    capture: 1,
    multiline: true,
    validity: Leakproof::Validity::Pem.new,
    specificity: :high,
    sample: ->(s) { s.rsa_key },
    notes: "The strongest check here. The DER underneath either parses as a key or it does not.",
    examples: { positive: [],
                negative: ["-----BEGIN RSA PRIVATE KEY-----\nnope\n-----END RSA PRIVATE KEY-----"] }
  )
)
