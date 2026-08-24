# frozen_string_literal: true

require "zlib"
require_relative "../detectors/entropy/charsets"
require_relative "base62"
require_relative "strategy"

module Leakproof
  module Validity
    # The strongest offline check available anywhere in this project. GitHub and
    # npm publish a CRC32 of the entropy in the final six characters, so a token
    # can be proven well-formed, or proven fake, without asking anyone.
    class Crc32Base62 < Strategy
      CHECKSUM_LENGTH = 6

      def initialize(entropy_length:)
        super()
        @entropy_length = entropy_length
        freeze
      end

      def describes
        "CRC32 checksum"
      end

      def check(value)
        prefix, remainder = split_prefix(value)
        return Result.new(:malformed, reason: "no prefix separator") unless remainder
        return Result.new(:malformed, reason: "wrong length") unless expected_length?(remainder)

        entropy = remainder[0...-CHECKSUM_LENGTH]
        actual = remainder[-CHECKSUM_LENGTH..]
        return Result.new(:malformed, reason: "non-base62 body") unless
          Detectors::Entropy::Charsets.matches?(:base62, remainder)

        compare(prefix, entropy, actual)
      end

      private

      def compare(prefix, entropy, actual)
        expected = Base62.encode(Zlib.crc32(entropy), width: CHECKSUM_LENGTH)
        if expected == actual
          Result.new(:verified, prefix: prefix, checksum: actual)
        else
          Result.new(:rejected, reason: "checksum mismatch", expected: expected, found: actual)
        end
      end

      def split_prefix(value)
        index = value.index("_")
        return [nil, nil] unless index

        [value[0..index], value[(index + 1)..]]
      end

      def expected_length?(remainder)
        remainder.length == @entropy_length + CHECKSUM_LENGTH
      end
    end
  end
end
