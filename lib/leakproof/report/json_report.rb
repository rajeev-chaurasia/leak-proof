# frozen_string_literal: true

require "json"

module Leakproof
  module Report
    class JsonReport
      SCHEMA = "leakproof/findings-v1"

      def initialize(findings, io: $stdout)
        @findings = findings
        @io = io
      end

      def render
        @io.puts JSON.pretty_generate(
          schema: SCHEMA,
          version: Leakproof::VERSION,
          summary: summary,
          findings: @findings.map(&:to_h)
        )
      end

      private

      def summary
        counts = @findings.group_by(&:tier).transform_values(&:size)
        { confirmed: counts.fetch(:confirmed, 0), probable: counts.fetch(:probable, 0),
          ignored: counts.fetch(:ignore, 0) }
      end
    end
  end
end
