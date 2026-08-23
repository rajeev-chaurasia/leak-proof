# frozen_string_literal: true

require_relative "../detector"
require_relative "candidate_extractor"
require_relative "charsets"
require_relative "shannon"

module Leakproof
  module Detectors
    module Entropy
      # The weakest rule in the project, and labelled as such. A 40-character git
      # SHA scores as high here as a real credential does, which is precisely why
      # entropy alone can never promote a finding to the confirmed tier.
      class EntropyDetector < Detector
        DEFAULT_THRESHOLD = 0.86
        DEFAULT_MINIMUM_LENGTH = 20

        def initialize(threshold: DEFAULT_THRESHOLD, minimum_length: DEFAULT_MINIMUM_LENGTH)
          @threshold = threshold
          @minimum_length = minimum_length
          super(
            id: "high-entropy-string",
            name: "Unclassified high-entropy string",
            pattern: CandidateExtractor::TOKEN,
            specificity: :low,
            notes: "No provider, no checksum, no contract. Reaches the probable tier at best.",
            examples: {
              positive: ["api = 'kD9xQ2mVbN7pLzR4tYeW1sA6gH3jU8cF'"],
              negative: ["const message = 'hello world this is plain'", "id = '#{"a" * 32}'"],
              suppressed: ["sha = '3d59a50f177d77ce013625030ba8dba906f75696'"]
            }
          )
        end

        def scan(text)
          return enum_for(:scan, text) unless block_given?

          text.to_s.each_line.with_index(1) do |line, number|
            CandidateExtractor.call(line, minimum: @minimum_length).each do |candidate|
              next unless interesting?(candidate)

              yield Match.new(detector: self, value: candidate, line: number,
                              column: (line.index(candidate) || 0) + 1, line_text: line.chomp)
            end
          end
        end

        def score(value)
          Shannon.normalized(value)
        end

        private

        def interesting?(candidate)
          score(candidate) >= @threshold
        end
      end
    end
  end
end
