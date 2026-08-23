# frozen_string_literal: true

require_relative "../registry"
require_relative "../entropy/entropy_detector"
require_relative "../../validity/contract"

Leakproof::Detectors::Registry.register(
  Leakproof::Detectors::Detector.new(
    id: "generic-assignment",
    name: "Credential-shaped assignment",
    pattern: /(?i:password|passwd|secret|token|api[_-]?key|auth[_-]?token)\s*[:=]\s*
              ["'`]([^"'`\s]{8,120})["'`]/x,
    capture: 1,
    specificity: :low,
    notes: "Named by its variable rather than its shape. Noisy by construction.",
    examples: {
      positive: ['password = "hunter2correcthorse"'],
      negative: ['password = "short"', 'unrelated = "hunter2correcthorse"'],
      suppressed: ['password = "${DB_PASSWORD}"', 'password = "changeme"', 'password = "YOUR_API_KEY"']
    }
  )
)

Leakproof::Detectors::Registry.register(Leakproof::Detectors::Entropy::EntropyDetector.new)
