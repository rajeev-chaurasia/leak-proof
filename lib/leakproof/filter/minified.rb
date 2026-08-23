# frozen_string_literal: true

require_relative "suppressor"

module Leakproof
  module Filter
    # Minified bundles and source maps are uniformly high-entropy, which makes
    # every entropy rule fire on them and none of it mean anything.
    class Minified < Suppressor
      PATH_PATTERNS = [/\.min\.(js|css)\z/, /\.map\z/, /\bbundle\.[a-f0-9]{8,}\./].freeze
      LONG_LINE = 500
      PENALTY = 30

      def suppression_for(candidate)
        return suppression("minified asset path", PENALTY) if minified_path?(candidate.path.to_s)
        return suppression("line longer than #{LONG_LINE} characters", PENALTY) if long_line?(candidate)

        nil
      end

      private

      def minified_path?(path)
        PATH_PATTERNS.any? { |pattern| path.match?(pattern) }
      end

      def long_line?(candidate)
        candidate.line_text.to_s.length > LONG_LINE
      end
    end
  end
end
