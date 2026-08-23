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

      # Some suppressors carry evidence about intent: a key under a fixture path
      # really may be a test key. Others are only proxies for machine-generated
      # noise, and a long line is not an argument against a key that parses.
      def noise_proxy?
        false
      end

      protected

      def suppression(reason, penalty)
        Suppression.new(rule: rule, reason: reason, penalty: penalty)
      end
    end
  end
end
