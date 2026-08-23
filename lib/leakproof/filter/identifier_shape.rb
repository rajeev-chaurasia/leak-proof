# frozen_string_literal: true

require_relative "suppressor"

module Leakproof
  module Filter
    # A value that reads as a name is a name.
    #
    # Every false positive in the first real-repository run was of this kind: a
    # header name assigned to a variable called api_key, a schema field called
    # chat_token, a UI string in a locale file. Length normalization makes short
    # identifiers score high on entropy, so entropy alone cannot exclude them.
    class IdentifierShape < Suppressor
      SNAKE_OR_KEBAB = /\A[a-z][a-z0-9]*([_.-][a-z0-9]+)+\z/i
      DOTTED_PATH = %r{\A[a-z0-9]+([./][a-z0-9_-]+)+\z}i
      WORDS = /\A[A-Za-z]+( [A-Za-z]+)+\z/

      # Nine of the fifteen surviving findings on a 1,902-commit repository were
      # one Python class name: Mask2FormerInstanceLoader. It carries all three
      # character classes and scores as high on entropy as a drawn token.
      # Measured cost against drawn tokens: 0.7% at 24 characters, 0.15% at 32,
      # none at 40.
      CAMEL_CASE = /\A([A-Z][a-z0-9]+){2,}\z/

      PENALTY = 100

      # Only for rules with no structural claim of their own. A provider rule
      # that matched its own pattern has already established shape, and several
      # real formats are dot-separated or hyphenated.
      def suppression_for(candidate)
        return nil unless candidate.detector.specificity == :low

        value = candidate.value.to_s
        if SNAKE_OR_KEBAB.match?(value)
          return suppression("value is an identifier, not a credential",
                             PENALTY)
        end
        return suppression("value is a path or dotted name", PENALTY) if DOTTED_PATH.match?(value)
        return suppression("value is a phrase of words", PENALTY) if WORDS.match?(value)
        return suppression("value is a camel-case identifier", PENALTY) if CAMEL_CASE.match?(value)

        nil
      end
    end
  end
end
