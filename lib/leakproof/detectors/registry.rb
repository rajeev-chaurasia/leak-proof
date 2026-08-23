# frozen_string_literal: true

require_relative "detector"

module Leakproof
  module Detectors
    # Providers self-register at load time, so adding a detector means adding one
    # file and touching nothing else. The open/closed spec asserts exactly that.
    class Registry
      include Enumerable

      PROVIDER_GLOB = File.join(__dir__, "providers", "*.rb")

      class << self
        def register(detector)
          registered[detector.id] = detector
        end

        def registered
          @registered ||= {}
        end

        def default
          load_providers
          new(registered.values)
        end

        def load_providers
          Dir[PROVIDER_GLOB].each { |file| require file }
        end
      end

      def initialize(detectors)
        @detectors = detectors.freeze
      end

      def each(&) = @detectors.each(&)

      def [](id) = @detectors.find { |d| d.id == id }

      def ids = @detectors.map(&:id)

      def size = @detectors.size
    end
  end
end
