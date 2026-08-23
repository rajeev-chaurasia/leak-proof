# frozen_string_literal: true

module Leakproof
  module Detectors
    module Entropy
      # Scoring a whole line dilutes a 30-character secret inside 200 characters
      # of surrounding code, so the line is split into plausible tokens first.
      module CandidateExtractor
        TOKEN = %r{[A-Za-z0-9+/=_-]{16,}}
        QUOTED = /["'`]([^"'`\n]{16,})["'`]/

        module_function

        def call(line, minimum: 20)
          candidates = line.scan(TOKEN)
          candidates.concat(line.scan(QUOTED).flatten)
          candidates.uniq.select { |c| c.length >= minimum }
        end
      end
    end
  end
end
