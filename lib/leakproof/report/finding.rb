# frozen_string_literal: true

require_relative "../scoring/fingerprint"

module Leakproof
  module Report
    class Finding
      attr_reader :detector_id, :detector_name, :path, :line, :column, :oid,
                  :redacted, :validity, :verdict, :fingerprint

      def initialize(candidate:, verdict:)
        @detector_id = candidate.detector_id
        @detector_name = candidate.detector.name
        @path = candidate.path
        @line = candidate.line
        @column = candidate.column
        @oid = candidate.oid
        @redacted = candidate.redacted
        @validity = candidate.validity
        @verdict = verdict
        @fingerprint = Scoring::Fingerprint.call(
          detector_id: candidate.detector_id, path: candidate.path, value: candidate.value
        )
        freeze
      end

      def tier = verdict.tier
      def confirmed? = verdict.confirmed?

      def to_h
        {
          fingerprint: fingerprint,
          rule: detector_id,
          name: detector_name,
          path: path,
          line: line,
          column: column,
          blob: oid,
          secret: redacted,
          validity: validity.to_h,
          verdict: verdict.to_h
        }
      end
    end
  end
end
