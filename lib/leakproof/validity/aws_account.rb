# frozen_string_literal: true

require_relative "../detectors/entropy/charsets"
require_relative "strategy"

module Leakproof
  module Validity
    # AWS publishes no checksum for access key IDs, contrary to a claim that
    # circulates widely. What the format does carry is the owning account, which
    # answers the actual triage question without ever calling AWS.
    class AwsAccount < Strategy
      ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
      PREFIXES = %w[AKIA ASIA AIDA AROA AGPA AIPA ANPA ANVA APKA].freeze
      BODY_LENGTH = 16
      ACCOUNT_MASK = 0x7fffffffff80

      def describes
        "account ID extraction"
      end

      def check(value)
        return Result.new(:malformed, reason: "wrong length") unless value.length == 4 + BODY_LENGTH

        prefix = value[0, 4]
        body = value[4..]
        return Result.new(:malformed, reason: "unknown prefix") unless PREFIXES.include?(prefix)
        return Result.new(:malformed, reason: "non-base32 body") unless
          Detectors::Entropy::Charsets.matches?(:base32, body)

        Result.new(:well_formed, prefix: prefix, account_id: account_id(body))
      end

      def account_id(body)
        bytes = decode(body)
        packed = bytes.first(6).inject(0) { |acc, byte| (acc << 8) | byte }
        format("%012d", (packed & ACCOUNT_MASK) >> 7)
      end

      private

      def decode(body)
        bits = body.each_char.map { |c| ALPHABET.index(c).to_s(2).rjust(5, "0") }.join
        bits.scan(/.{8}/).map { |byte| byte.to_i(2) }
      end
    end
  end
end
