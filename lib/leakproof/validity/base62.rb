# frozen_string_literal: true

module Leakproof
  module Validity
    # GitHub and npm both encode a CRC32 with this alphabet, in this order.
    # Verified against published expired tokens in the crc32_base62 spec.
    module Base62
      ALPHABET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"

      module_function

      def encode(number, width: 6)
        return ALPHABET[0] * width if number.zero?

        digits = +""
        remaining = number
        while remaining.positive?
          digits.prepend(ALPHABET[remaining % 62])
          remaining /= 62
        end
        digits.rjust(width, ALPHABET[0])
      end

      def valid?(value)
        !value.empty? && value.each_char.all? { |c| ALPHABET.include?(c) }
      end
    end
  end
end
