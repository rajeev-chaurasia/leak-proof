# frozen_string_literal: true

require_relative "../detectors/entropy/shannon"

module Leakproof
  module Scoring
    # The published scoring table. Every number here is in docs/confidence.md and
    # in the README, because a confidence score nobody can recompute is a vibe.
    #
    # The shape of the table enforces the project's one hard invariant: only a
    # finding whose format carries a mathematical proof can reach `confirmed`.
    # A prefix and a length are never enough, however suggestive the context.
    module Confidence
      BASE = { high: 60, medium: 45, low: 30 }.freeze

      VALIDITY = { verified: 40, well_formed: 10, unknown: 0 }.freeze

      # Only for name-anchored rules. Applying it to the bare entropy rule would
      # promote every git SHA in the repository to a finding.
      ENTROPY_BONUS = 15
      ENTROPY_BONUS_AT = 0.92
      ENTROPY_BONUS_MIN_LENGTH = 20

      CONFIRMED_AT = 90
      PROBABLE_AT = 45

      Verdict = Struct.new(:tier, :score, :suppressions, :reason, keyword_init: true) do
        def confirmed? = tier == :confirmed
        def probable? = tier == :probable
        def ignored? = tier == :ignore
        def to_h = { tier: tier, score: score, reason: reason, suppressions: suppressions.map(&:to_h) }
      end

      module_function

      def call(candidate, suppressions)
        disqualifier = disqualify(candidate)
        if disqualifier
          return Verdict.new(tier: :ignore, score: 0, suppressions: suppressions,
                             reason: disqualifier)
        end

        score = BASE.fetch(candidate.detector.specificity) + VALIDITY.fetch(candidate.validity.status, 0)
        score += entropy_bonus(candidate)
        score -= suppressions.sum(&:penalty)
        Verdict.new(tier: tier_for(score), score: score, suppressions: suppressions, reason: nil)
      end

      def entropy_bonus(candidate)
        return 0 unless candidate.detector.entropy_bonus?
        return 0 if candidate.value.length < ENTROPY_BONUS_MIN_LENGTH
        return 0 if Detectors::Entropy::Shannon.normalized(candidate.value) < ENTROPY_BONUS_AT

        ENTROPY_BONUS
      end

      def tier_for(score)
        return :confirmed if score >= CONFIRMED_AT
        return :probable if score >= PROBABLE_AT

        :ignore
      end

      # Three ways a candidate stops being a finding regardless of anything else.
      def disqualify(candidate)
        return "the format's own structure says this is not a credential" if unproven?(candidate)
        return "this credential type is public by design" unless candidate.detector.secret?

        nil
      end

      def unproven?(candidate)
        %i[rejected malformed].include?(candidate.validity.status)
      end
    end
  end
end
