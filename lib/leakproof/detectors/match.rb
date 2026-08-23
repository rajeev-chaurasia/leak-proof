# frozen_string_literal: true

module Leakproof
  module Detectors
    class Match
      attr_reader :detector, :value, :line, :column, :line_text

      def initialize(detector:, value:, line:, column:, line_text: nil)
        @detector = detector
        @value = value
        @line = line
        @column = column
        @line_text = line_text
        freeze
      end

      def detector_id
        detector.id
      end

      def redacted
        return "*" * value.length if value.length <= 8

        "#{value[0, 4]}#{"*" * (value.length - 8)}#{value[-4..]}"
      end
    end
  end
end
