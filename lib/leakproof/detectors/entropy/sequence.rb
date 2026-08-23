# frozen_string_literal: true

module Leakproof
  module Detectors
    module Entropy
      # The pathological case for entropy scoring.
      #
      # "ABCDEFGHIJKLMNOPQRSTUVWXYZ" has perfect Shannon entropy: every character
      # appears exactly once. It is also not random in any useful sense, and a
      # base64 alphabet constant appears in more codebases than any credential.
      # Adjacency is what separates an enumeration from a draw.
      module Sequence
        module_function

        def adjacency(value)
          return 0.0 if value.nil? || value.length < 2

          steps = value.each_char.each_cons(2).count { |a, b| (b.ord - a.ord).abs == 1 }
          steps.to_f / (value.length - 1)
        end

        def enumerated?(value, threshold: 0.5)
          adjacency(value) >= threshold
        end
      end
    end
  end
end
