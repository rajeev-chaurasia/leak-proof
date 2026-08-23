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
    end
  end
end
