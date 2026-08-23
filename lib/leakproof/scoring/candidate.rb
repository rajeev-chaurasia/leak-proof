# frozen_string_literal: true

module Leakproof
  module Scoring
    # Everything the filter and the score need, gathered once. Mutable in exactly
    # one respect: distinct_paths is only knowable after the whole walk.
    class Candidate
      attr_reader :match, :path, :oid, :validity
      attr_accessor :distinct_paths

      def initialize(match:, validity:, path: nil, oid: nil)
        @match = match
        @path = path
        @oid = oid
        @validity = validity
        @distinct_paths = 1
      end

      def detector = match.detector
      def detector_id = match.detector_id
      def value = match.value
      def line = match.line
      def column = match.column
      def line_text = match.line_text
      def redacted = match.redacted

      # A PEM block occupies every line of its body, not only the line it starts
      # on. Without the span, the entropy rule reports each base64 line of a key
      # the private-key rule has already claimed.
      def line_span
        line..(line + value.to_s.count("\n"))
      end
    end
  end
end
