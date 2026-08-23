# frozen_string_literal: true

require "json"
require_relative "base64url"
require_relative "strategy"

module Leakproof
  module Validity
    # A JWT carries its own metadata in clear text, so expiry can be settled
    # offline. An expired token is still a leak worth reporting, just not an
    # emergency, and saying which is the entire job of the triage tier.
    class Jwt < Strategy
      def describes
        "decodes, expiry readable"
      end

      def check(value)
        parts = value.split(".")
        return Result.new(:malformed, reason: "expected three segments") unless parts.length == 3

        header = decode_segment(parts[0])
        payload = decode_segment(parts[1])
        return Result.new(:malformed, reason: "segments are not base64url JSON") unless header && payload
        return Result.new(:malformed, reason: "no alg in header") unless header["alg"]

        Result.new(:well_formed, **claims(header, payload))
      end

      private

      def claims(header, payload)
        expiry = payload["exp"]
        {
          algorithm: header["alg"],
          subject: payload["sub"],
          expires_at: expiry,
          expired: expiry.is_a?(Numeric) ? Time.now.to_i > expiry : nil
        }.compact
      end

      def decode_segment(segment)
        parsed = JSON.parse(Base64url.decode(segment))
        parsed.is_a?(Hash) ? parsed : nil
      rescue ArgumentError, JSON::ParserError
        nil
      end
    end
  end
end
