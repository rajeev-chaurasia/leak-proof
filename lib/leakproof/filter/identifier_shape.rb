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
      # Case-sensitive on purpose. Read with /i, <prefix><separator><drawn body>
      # reads as snake_case, which is the shape most modern providers ship and
      # silently closed off most of the space the entropy rule exists to cover.
      SNAKE_OR_KEBAB = /\A[a-z][a-z0-9]*([_.-][a-z0-9]+)+\z/
      DOTTED_PATH = %r{\A[a-z0-9]+([./][a-z0-9_-]+)+\z}
      WORDS = /\A[A-Za-z]+( [A-Za-z]+)+\z/

      # Nine of the fifteen surviving findings on a 1,902-commit repository were
      # one Python class name: Mask2FormerInstanceLoader. It carries all three
      # character classes and scores as high on entropy as a drawn token.
      # Measured cost against drawn tokens: 0.7% at 24 characters, 0.15% at 32,
      # none at 40.
      CAMEL_CASE = /\A([A-Z][a-z0-9]+){2,}\z/

      # lowerCamelCase is the JavaScript norm and CAMEL_CASE cannot see it,
      # because that pattern needs a capital first letter. Consecutive capitals
      # (decodeURIComponentSafe) defeat a pattern-based fix entirely.
      #
      # What separates them is how often the character class changes. An
      # identifier flips once per word; a drawn token flips every other
      # character. Measured over 3,000 draws: identifiers observed between 0.19
      # and 0.357, tokens lose 1.0% at 24 characters, 0.4% at 32, 0.1% at 40 and
      # none at 64.
      CASE_TRANSITION_FLOOR = 0.36
      MINIMUM_FOR_TRANSITIONS = 12

      PENALTY = 100

      # Not for high-specificity rules: several real formats are dot-separated or
      # hyphenated, and a rule that matched a distinctive prefix and a checksum
      # has already established shape. Everything weaker has to earn it.
      APPLIES_TO = %i[low medium].freeze

      def suppression_for(candidate)
        return nil unless APPLIES_TO.include?(candidate.detector.specificity)

        value = candidate.value.to_s
        if SNAKE_OR_KEBAB.match?(value)
          return suppression("value is an identifier, not a credential",
                             PENALTY)
        end
        return suppression("value is a path or dotted name", PENALTY) if DOTTED_PATH.match?(value)
        return suppression("value is a phrase of words", PENALTY) if WORDS.match?(value)
        return suppression("value is a camel-case identifier", PENALTY) if CAMEL_CASE.match?(value)
        return suppression("value reads as an identifier, not a draw", PENALTY) if identifier_cadence?(value)

        nil
      end

      private

      def identifier_cadence?(value)
        return false if value.length < MINIMUM_FOR_TRANSITIONS

        case_transition_rate(value) < CASE_TRANSITION_FLOOR
      end

      def case_transition_rate(value)
        classes = value.each_char.map do |c|
          if c.match?(/[a-z]/)
            :lower
          else
            (c.match?(/[A-Z]/) ? :upper : :other)
          end
        end
        classes.each_cons(2).count { |a, b| a != b }.to_f / (value.length - 1)
      end
    end
  end
end
