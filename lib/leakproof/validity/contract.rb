# frozen_string_literal: true

require_relative "../detectors/entropy/charsets"
require_relative "strategy"

module Leakproof
  module Validity
    # The weak row in the published table. A prefix and a length prove almost
    # nothing, and the report says so rather than dressing it up.
    class Contract < Strategy
      def initialize(prefix: nil, length: nil, charset: nil)
        super()
        @prefix = prefix
        @length = length
        @charset = charset
        freeze
      end

      def describes
        "prefix and length only"
      end

      def check(value)
        return Result.new(:malformed, reason: "prefix mismatch") if @prefix && !value.start_with?(@prefix)
        return Result.new(:malformed, reason: "length mismatch") unless length_ok?(value)
        return Result.new(:malformed, reason: "charset mismatch") unless charset_ok?(value)

        Result.new(:well_formed, prefix: @prefix)
      end

      private

      def length_ok?(value)
        return true unless @length

        @length.is_a?(Range) ? @length.cover?(value.length) : value.length == @length
      end

      def charset_ok?(value)
        return true unless @charset

        body = @prefix ? value.delete_prefix(@prefix) : value
        Detectors::Entropy::Charsets.matches?(@charset, body)
      end
    end
  end
end
