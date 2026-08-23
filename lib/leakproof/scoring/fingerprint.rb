# frozen_string_literal: true

require "digest"

module Leakproof
  module Scoring
    # Deliberately not derived from a commit SHA.
    #
    # Fingerprinting by commit means a rebase, a squash or a force-push orphans
    # every triaged suppression and the same finding is reported again as new.
    # Content and path survive history rewrites, so a dismissal stays dismissed.
    module Fingerprint
      module_function

      def call(detector_id:, path:, value:)
        Digest::SHA256.hexdigest([detector_id, normalize(path), value].join("\n"))[0, 32]
      end

      def normalize(path)
        path.to_s.sub(%r{\A\./}, "").downcase
      end
    end
  end
end
