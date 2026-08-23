# frozen_string_literal: true

module Leakproof
  module Git
    # Both backends satisfy this contract. The differential spec asserts they are
    # substitutable by comparing Blob#identity sets, which is Liskov made empirical.
    class Backend
      MODES = %i[reachable all_objects].freeze

      DEFAULT_MAX_BLOB_BYTES = 1_000_000

      attr_reader :path, :max_blob_bytes

      def initialize(path, max_blob_bytes: DEFAULT_MAX_BLOB_BYTES)
        @path = File.expand_path(path)
        @max_blob_bytes = max_blob_bytes
      end

      def each_blob(mode: :reachable)
        raise NotImplementedError, "#{self.class} must implement #each_blob"
      end

      def available?
        true
      end

      def name
        self.class.name.split("::").last
      end

      private

      # Shared policy rather than shared logic, so the differential spec still
      # compares two independent enumerations.
      def include_blob?(size)
        size.positive? && size <= max_blob_bytes
      end
    end
  end
end
