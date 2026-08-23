# frozen_string_literal: true

require_relative "../detector"
require_relative "candidate_extractor"
require_relative "character_classes"
require_relative "charsets"
require_relative "sequence"
require_relative "shannon"

module Leakproof
  module Detectors
    module Entropy
      # The weakest rule in the project, and labelled as such. A 40-character git
      # SHA scores as high here as a real credential does, which is precisely why
      # entropy alone can never promote a finding to the confirmed tier.
      class EntropyDetector < Detector
        DEFAULT_THRESHOLD = 0.92
        DEFAULT_MINIMUM_LENGTH = 24
        # Above this, high entropy means encoded data: a dump, a certificate, an
        # image. Credentials do not run this long.
        DEFAULT_MAXIMUM_LENGTH = 120

        # rubocop:disable Metrics/MethodLength -- the declaration is the interface
        def initialize(threshold: DEFAULT_THRESHOLD, minimum_length: DEFAULT_MINIMUM_LENGTH,
                       maximum_length: DEFAULT_MAXIMUM_LENGTH)
          @threshold = threshold
          @minimum_length = minimum_length
          @maximum_length = maximum_length
          super(
            id: "high-entropy-string",
            name: "Unclassified high-entropy string",
            pattern: CandidateExtractor::TOKEN,
            specificity: :low,
            advisory: true,
            notes: "No provider, no checksum, no contract. Advisory only: visible " \
                   "with --show ignore, never reportable on its own evidence.",
            sample: ->(s) { s.base62(32) },
            examples: {
              positive: [],
              negative: ["const message = 'hello world this is plain'", "id = '#{"a" * 32}'"],
              suppressed: ["sha = '3d59a50f177d77ce013625030ba8dba906f75696'"]
            }
          )
        end
        # rubocop:enable Metrics/MethodLength

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

        # Hex at this length is overwhelmingly digests, git object IDs and
        # checksums. Excluding it costs recall on hex-encoded secrets, which is
        # recorded in docs/known-misses.md rather than hidden.
        def interesting?(candidate)
          return false if candidate.length > @maximum_length
          return false if Charsets.classify(candidate) == :hex
          return false if Sequence.enumerated?(candidate)
          return false unless CharacterClasses.diverse?(candidate)

          score(candidate) >= @threshold
        end
      end
    end
  end
end
