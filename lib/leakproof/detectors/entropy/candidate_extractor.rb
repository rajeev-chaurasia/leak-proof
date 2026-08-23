# frozen_string_literal: true

module Leakproof
  module Detectors
    module Entropy
      # Scoring a whole line dilutes a thirty-character secret inside two hundred
      # characters of surrounding code, so the line is split into tokens first.
      #
      # Quoted-string extraction has to be filtered back through the token
      # charset. Without that it captures interpolations and code fragments,
      # which are punctuation-rich and therefore score high on entropy while
      # containing nothing.
      module CandidateExtractor
        TOKEN = %r{[A-Za-z0-9+/=_-]{16,}}
        QUOTED = /["'`]([^"'`\n]{16,})["'`]/
        WHOLE_TOKEN = %r{\A[A-Za-z0-9+/=_-]+\z}

        # In base64 an equals sign is trailing padding. Anywhere else it is an
        # assignment, and the "token" is really KEY=VALUE from an environment
        # dump rather than an encoded secret.
        PADDING_ONLY = %r{\A[A-Za-z0-9+/_-]+={0,2}\z}

        module_function

        def call(line, minimum: 20)
          candidates = line.scan(TOKEN).flat_map { |token| split_assignment(token) }
          candidates.concat(line.scan(QUOTED).flatten.grep(WHOLE_TOKEN))
          candidates.uniq.select { |c| c.length >= minimum && PADDING_ONLY.match?(c) }
        end

        # KEY=VALUE lexes as a single token, because base64 padding is also an
        # equals sign. Take the right-hand side so an unquoted .env line is
        # visible, and only for a genuine name on the left: splitting on every
        # equals sign multiplied candidates across a whole repository.
        ASSIGNMENT = /\A[A-Za-z_][A-Za-z0-9_.-]*=[^=]/

        def split_assignment(token)
          return [token] unless ASSIGNMENT.match?(token)

          [token.split("=", 2).last]
        end
      end
    end
  end
end
