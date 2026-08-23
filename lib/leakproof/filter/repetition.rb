# frozen_string_literal: true

require_relative "suppressor"

module Leakproof
  module Filter
    # A credential lives in one place. A value repeated across many files is a
    # fixture, a checked-in sample, or a constant.
    class Repetition < Suppressor
      DEFAULT_THRESHOLD = 3
      PENALTY = 25

      def initialize(threshold: DEFAULT_THRESHOLD)
        super()
        @threshold = threshold
      end

      def noise_proxy?
        true
      end

      def suppression_for(candidate)
        count = candidate.distinct_paths
        return nil if count < @threshold

        suppression("value appears in #{count} distinct paths", PENALTY)
      end
    end
  end
end
