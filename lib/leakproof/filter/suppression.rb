# frozen_string_literal: true

module Leakproof
  module Filter
    class Suppression
      attr_reader :rule, :reason, :penalty

      def initialize(rule:, reason:, penalty:)
        @rule = rule
        @reason = reason
        @penalty = penalty
        freeze
      end

      def to_h = { rule: rule, reason: reason, penalty: penalty }
    end
  end
end
