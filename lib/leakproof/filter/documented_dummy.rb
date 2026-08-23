# frozen_string_literal: true

require_relative "known_dummies"
require_relative "suppressor"

module Leakproof
  module Filter
    class DocumentedDummy < Suppressor
      PENALTY = 100

      def suppression_for(candidate)
        label = KnownDummies.match(candidate.value)
        return nil unless label

        suppression("published vendor example (#{label})", PENALTY)
      end
    end
  end
end
