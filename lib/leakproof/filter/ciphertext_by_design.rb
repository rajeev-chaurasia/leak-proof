# frozen_string_literal: true

require_relative "suppressor"

module Leakproof
  module Filter
    # Some formats exist to put ciphertext in a public file. A Travis `secure:`
    # blob is RSA ciphertext only Travis can decrypt, and publishing it is the
    # entire design. Reporting it is reporting the intended state of the file.
    class CiphertextByDesign < Suppressor
      LINE_PATTERNS = [
        [/^\s*-?\s*secure:\s/, "encrypted CI value"],
        [/\bsops\b|\benc\.[a-z]+\b/, "sops-encrypted value"],
        [/^\s*-?\s*(ENC\[|vault:)/, "sealed value"]
      ].freeze

      PENALTY = 100

      def suppression_for(candidate)
        line = candidate.line_text.to_s
        _pattern, label = LINE_PATTERNS.find { |pattern, _| line.match?(pattern) }
        return nil unless label

        suppression(label, PENALTY)
      end
    end
  end
end
