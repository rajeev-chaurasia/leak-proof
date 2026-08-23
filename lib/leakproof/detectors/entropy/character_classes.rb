# frozen_string_literal: true

module Leakproof
  module Detectors
    module Entropy
      # The signal normalized entropy could not provide.
      #
      # Measured on a 1,902-commit repository: every entropy false positive
      # (file paths, environment variable names, mime types, English phrases)
      # drew on a single character class, while 99% of random 24-character
      # tokens and 100% of longer ones draw on all three. Entropy scores the two
      # groups within 0.02 of each other, so this is what separates them.
      module CharacterClasses
        CLASSES = { lower: /[a-z]/, upper: /[A-Z]/, digit: /[0-9]/ }.freeze
        REQUIRED = 3

        module_function

        def count(value)
          CLASSES.count { |_name, pattern| pattern.match?(value.to_s) }
        end

        def diverse?(value, required: REQUIRED)
          count(value) >= required
        end
      end
    end
  end
end
