# frozen_string_literal: true

require_relative "suppression"

module Leakproof
  module Filter
    # One question each. A suppressor returns a Suppression when it has a reason
    # to doubt the finding, and nil when it has nothing to say.
    class Suppressor
      def suppression_for(_candidate)
        nil
      end

      def rule
        self.class.name.split("::").last.gsub(/(.)([A-Z])/, '\1-\2').downcase
      end

      protected

      def suppression(reason, penalty)
        Suppression.new(rule: rule, reason: reason, penalty: penalty)
      end
    end
  end
end
