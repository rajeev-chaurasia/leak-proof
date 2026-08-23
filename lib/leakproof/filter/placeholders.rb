# frozen_string_literal: true

require_relative "suppressor"

module Leakproof
  module Filter
    # A value that names itself as a placeholder is not a credential. This is the
    # cheapest large win against false positives.
    class Placeholders < Suppressor
      PATTERNS = [
        [/\A\$[A-Za-z_][A-Za-z0-9_]*\z/, "shell variable reference"],
        [/\A\$\{[^}]+\}\z/, "interpolation"],
        [/\A#\{[^}]+\}\z/, "interpolation"],
        [/\A<[^>]+>\z/, "angle-bracket placeholder"],
        [/\A%\{[^}]+\}\z/, "format placeholder"],
        [/\A\{\{[^}]+\}\}\z/, "template placeholder"],
        # Anchored at both ends. Without a closing anchor this matched any value
        # merely starting with "my" or "your", which includes real passwords.
        [/\A(your|my|our|some|insert|replace|put|the)([_ -]?[a-z]+){0,4}\z/i, "instructional placeholder"],
        [/\A(changeme|change_me|placeholder|redacted|removed|dummy|fake|test|example)\z/i,
         "literal placeholder"],
        [/\A(x{4,}|X{4,}|0{4,}|1{4,}|a{4,}|A{4,}|\.{3,})\z/, "filler run"],
        # Only as a standalone run of capitals, so a drawn token containing the
        # letters by chance is not zeroed.
        [/(\A|[^A-Z])(EXAMPLE|SAMPLE|DUMMY|PLACEHOLDER|REDACTED)([^A-Z]|\z)/, "self-labelled example"],
        [/\A[<{\[].*[>}\]]\z/, "bracketed placeholder"]
      ].freeze

      PENALTY = 100

      def suppression_for(candidate)
        value = candidate.value.to_s
        _pattern, label = PATTERNS.find { |pattern, _| value.match?(pattern) }
        return nil unless label

        suppression(label, PENALTY)
      end
    end
  end
end
