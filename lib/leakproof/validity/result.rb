# frozen_string_literal: true

module Leakproof
  module Validity
    # The honest four-way answer. "well_formed" is not "verified", and the
    # difference is the whole point of the project.
    class Result
      STATUSES = %i[verified rejected well_formed malformed unknown].freeze

      attr_reader :status, :detail

      def initialize(status, detail = {})
        raise ArgumentError, "unknown status: #{status}" unless STATUSES.include?(status)

        @status = status
        @detail = detail.freeze
        freeze
      end

      STATUSES.each do |name|
        define_method(:"#{name}?") { status == name }
      end

      def proven?
        verified? || rejected?
      end

      def to_h
        { status: status, detail: detail }
      end
    end
  end
end
