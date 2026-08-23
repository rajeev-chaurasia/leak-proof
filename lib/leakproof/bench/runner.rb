# frozen_string_literal: true

require_relative "../filter/chain"
require_relative "../scanner"
require_relative "../sources"
require_relative "generator"

module Leakproof
  module Bench
    # Scans the generated corpus and grades the result against what was planted.
    #
    # Grading is binary on the underlying question: does a location hold a real
    # credential? Whether a finding reached the right tier is reported
    # separately, because grading the scoring table against itself would measure
    # nothing.
    class Runner
      REPORTABLE = %i[confirmed probable].freeze
      MUST_FIND = %i[source deleted].freeze

      def initialize(registry: nil, seed: 20_260_823)
        @registry = registry || Detectors::Registry.default
        @seed = seed
      end

      def call(root)
        generator = Generator.new(registry: @registry, seed: @seed)
        generator.build(root)
        sources = Sources.from_repository(root, mode: :all_objects)
        {
          seed: @seed,
          planted: generator.plants.length,
          decoys: generator.decoys.length,
          filtered: grade(scan(sources, filtered: true), generator),
          unfiltered: grade(scan(sources, filtered: false), generator)
        }
      end

      private

      def scan(sources, filtered:)
        filter = filtered ? Filter::Chain.default : Filter::Chain.new([])
        Scanner.new(registry: @registry, filter: filter).scan(sources)
      end

      # Three populations, graded separately, because collapsing them would let
      # correct behaviour look like failure.
      #
      #   must find    a real credential in source, or removed from it later
      #   must demote  the same credential under a fixture or documentation path.
      #                Reporting it is right; blocking a commit over it is not,
      #                so the test is that it does not reach the confirmed tier.
      #   must ignore  a type that is public by design, such as a Stripe pk_ key
      # rubocop:disable Metrics/AbcSize -- flat result assembly, no branching
      def grade(findings, generator)
        reported = findings.select { |f| REPORTABLE.include?(f.tier) }
        groups = partition(generator.plants)
        outcome = outcomes(reported, groups, generator.plants)

        counts(outcome, groups).merge(
          confirmed: reported.count { |f| f.tier == :confirmed },
          reported: reported.length,
          demoted: fraction(groups[:demote].length - outcome[:leaked].length, groups[:demote].length),
          public_types_ignored: fraction(groups[:ignore].length - outcome[:surfaced].length,
                                         groups[:ignore].length),
          missed: (groups[:find] - outcome[:found]).map(&:to_h),
          spurious: outcome[:spurious].map { |f| finding_summary(f) },
          by_rule: by_rule(groups[:find], reported)
        )
      end

      def outcome_sets(reported)
        [key_set(reported), key_set(reported.select { |f| f.tier == :confirmed })]
      end

      # Membership sets rather than nested scans: the same answers, linear
      # instead of quadratic, and legible.
      def outcomes(reported, groups, all_plants)
        any, confirmed = outcome_sets(reported)
        planted = all_plants.to_set { |plant| [plant.rule, plant.path] }
        {
          found: groups[:find].select { |plant| any.include?([plant.rule, plant.path]) },
          leaked: groups[:demote].select { |plant| confirmed.include?([plant.rule, plant.path]) },
          surfaced: groups[:ignore].select { |plant| any.include?([plant.rule, plant.path]) },
          spurious: reported.reject { |f| planted.include?([f.detector_id, f.path]) }
        }
      end

      # rubocop:enable Metrics/AbcSize

      def key_set(findings)
        findings.to_set { |f| [f.detector_id, f.path] }
      end

      def counts(outcome, groups)
        true_positives = outcome[:found].length
        false_positives = outcome[:spurious].length + outcome[:surfaced].length
        {
          must_find: groups[:find].length,
          true_positives: true_positives,
          false_negatives: groups[:find].length - true_positives,
          false_positives: false_positives,
          precision: ratio(true_positives, true_positives + false_positives),
          recall: ratio(true_positives, groups[:find].length)
        }
      end

      def finding_summary(finding)
        { rule: finding.detector_id, path: finding.path, line: finding.line, tier: finding.tier }
      end

      def fraction(part, whole) = "#{part}/#{whole}"

      def partition(plants)
        secret, public_by_design = plants.partition { |plant| secret?(plant) }
        must_find, must_demote = secret.partition { |plant| MUST_FIND.include?(plant.placement) }
        { find: must_find, demote: must_demote, ignore: public_by_design }
      end

      def secret?(plant)
        detector = @registry.find { |d| d.id == plant.rule }
        detector.nil? || detector.secret?
      end

      # A plant and a finding correspond when the rule and the file agree. Line
      # numbers are deliberately not compared: a scanner that reports the right
      # credential in the right file has found it.
      def by_rule(planted, reported)
        any = key_set(reported)
        planted.group_by(&:rule).transform_values do |plants|
          found = plants.count { |plant| any.include?([plant.rule, plant.path]) }
          { planted: plants.length, found: found, recall: ratio(found, plants.length) }
        end
      end

      def ratio(numerator, denominator)
        return nil if denominator.zero?

        (numerator.to_f / denominator).round(4)
      end
    end
  end
end
