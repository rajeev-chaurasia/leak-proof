# frozen_string_literal: true

module CorpusSamples
  REGISTRY = Leakproof::Detectors::Registry.default
  SYNTHESIZER = Leakproof::Bench::Synthesizer.new
  SEEDS = (1..40).to_a.freeze
end
