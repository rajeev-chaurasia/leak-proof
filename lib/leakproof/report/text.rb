# frozen_string_literal: true

module Leakproof
  module Report
    class Text
      TIER_LABEL = { confirmed: "CONFIRMED", probable: "PROBABLE ", ignore: "ignored  " }.freeze

      def initialize(findings, io: $stdout)
        @findings = findings
        @io = io
      end

      def render
        if @findings.empty?
          @io.puts "No findings."
          return
        end

        @findings.each { |finding| @io.puts(*lines_for(finding)) }
        @io.puts summary
      end

      private

      def lines_for(finding)
        [
          "#{TIER_LABEL.fetch(finding.tier)}  #{finding.detector_name}",
          "  #{finding.path}:#{finding.line}  #{finding.redacted}",
          "  #{detail(finding)}",
          ""
        ]
      end

      def detail(finding)
        (["offline check: #{finding.validity.status}"] + evidence(finding) + dismissal(finding)).join("  |  ")
      end

      def evidence(finding)
        detail = finding.validity.detail
        parts = []
        parts << "aws account #{detail[:account_id]}" if detail[:account_id]
        parts << "expired" if detail[:expired]
        parts
      end

      def dismissal(finding)
        reasons = finding.verdict.suppressions.map(&:reason)
        parts = reasons.empty? ? [] : ["suppressed by #{reasons.join(", ")}"]
        parts << finding.verdict.reason if finding.verdict.reason
        parts
      end

      def summary
        counts = @findings.group_by(&:tier).transform_values(&:size)
        "#{counts.fetch(:confirmed, 0)} confirmed, #{counts.fetch(:probable, 0)} probable, " \
          "#{counts.fetch(:ignore, 0)} ignored"
      end
    end
  end
end
