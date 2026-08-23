# frozen_string_literal: true

require "json"

module Leakproof
  module Report
    # SARIF so findings land in GitHub's Security tab rather than only in a log.
    class Sarif
      SCHEMA = "https://json.schemastore.org/sarif-2.1.0.json"
      LEVEL = { confirmed: "error", probable: "warning", ignore: "note" }.freeze

      def initialize(findings, io: $stdout, registry: nil)
        @findings = findings
        @io = io
        @registry = registry || Detectors::Registry.default
      end

      def render
        @io.puts JSON.pretty_generate(
          "$schema" => SCHEMA, "version" => "2.1.0", "runs" => [run]
        )
      end

      private

      def run
        { "tool" => { "driver" => driver }, "results" => @findings.map { |f| result(f) } }
      end

      def driver
        {
          "name" => "leakproof",
          "version" => Leakproof::VERSION,
          "informationUri" => "https://github.com/rajeev-chaurasia/leak-proof",
          "rules" => @registry.map { |detector| rule(detector) }
        }
      end

      def rule(detector)
        {
          "id" => detector.id,
          "name" => detector.name,
          "shortDescription" => { "text" => detector.name },
          "fullDescription" => { "text" => detector.notes.to_s },
          "properties" => { "offlineCheck" => detector.validity.describes,
                            "specificity" => detector.specificity.to_s }
        }
      end

      def result(finding)
        {
          "ruleId" => finding.detector_id,
          "level" => LEVEL.fetch(finding.tier),
          "message" => { "text" => message(finding) },
          "partialFingerprints" => { "leakproofFingerprint/v1" => finding.fingerprint },
          "locations" => [location(finding)]
        }
      end

      def message(finding)
        "#{finding.detector_name} (#{finding.tier}, offline check: #{finding.validity.status})"
      end

      def location(finding)
        {
          "physicalLocation" => {
            "artifactLocation" => { "uri" => finding.path.to_s },
            "region" => { "startLine" => finding.line, "startColumn" => finding.column }
          }
        }
      end
    end
  end
end
