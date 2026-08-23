# frozen_string_literal: true

require_relative "result"

module Leakproof
  module Validity
    # Narrow by design: a detector with no offline proof available is not forced
    # to pretend it has one, it just declares Contract instead.
    class Strategy
      def check(_value)
        Result.new(:unknown)
      end

      # What the generated README table prints in the "offline check" column.
      def describes
        "none"
      end

      def name
        self.class.name.split("::").last
      end
    end
  end
end
