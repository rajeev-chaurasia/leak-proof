# frozen_string_literal: true

require_relative "documented_dummy"
require_relative "minified"
require_relative "path_rules"
require_relative "placeholders"
require_relative "repetition"

module Leakproof
  module Filter
    class Chain
      DEFAULT = [Placeholders, DocumentedDummy, PathRules, Minified, Repetition].freeze

      def self.default
        new(DEFAULT.map(&:new))
      end

      def initialize(suppressors)
        @suppressors = suppressors.freeze
      end

      def call(candidate)
        @suppressors.filter_map { |s| s.suppression_for(candidate) }
      end

      def rules = @suppressors.map(&:rule)
    end
  end
end
