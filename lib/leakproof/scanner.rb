# frozen_string_literal: true

require_relative "detectors/registry"
require_relative "filter/chain"
require_relative "report/finding"
require_relative "scoring/candidate"
require_relative "scoring/confidence"

module Leakproof
  # Composition only. It owns no detection logic, no validity rule and no
  # suppression rule, which is why the whole engine below it can be tested
  # without a repository on disk.
  class Scanner
    # A provider rule and the entropy rule both fire on the same token. The
    # specific one wins, otherwise every real finding arrives three times.
    RANK = { high: 0, medium: 1, low: 2 }.freeze

    Source = Struct.new(:path, :content, :oid, keyword_init: true) do
      def text = content.to_s
      def binary? = content.to_s.byteslice(0, 8000).to_s.include?("\x00")
    end

    def initialize(registry: nil, filter: nil)
      @registry = registry || Detectors::Registry.default
      @filter = filter || Filter::Chain.default
    end

    # Two passes on purpose. Whether a value is repeated across the tree is only
    # knowable once the whole tree has been read, and it changes the verdict.
    def scan(sources)
      candidates = resolve_overlaps(collect(sources))
      annotate_repetition(candidates)
      candidates.map { |candidate| Report::Finding.new(candidate: candidate, verdict: verdict_for(candidate)) }
    end

    def scan_text(text, path: nil)
      scan([Source.new(path: path, content: text, oid: nil)])
    end

    private

    def collect(sources)
      candidates = []
      sources.each do |source|
        next if source.binary?

        text = source.text
        @registry.each do |detector|
          detector.scan(text) do |match|
            candidates << build_candidate(match, detector, source)
          end
        end
      end
      candidates
    end

    def build_candidate(match, detector, source)
      Scoring::Candidate.new(
        match: match, validity: detector.check(match.value),
        path: source.path, oid: source.oid
      )
    end

    # Grouping by identical value is not enough: the entropy rule matches the
    # random tail of a prefixed token, which is a different string at a different
    # column. Overlapping spans on one line are one finding.
    def resolve_overlaps(candidates)
      candidates.group_by(&:path).values.flat_map { |group| keep_widest(group) }
    end

    def keep_widest(group)
      kept = []
      group.sort_by { |c| [RANK.fetch(c.detector.specificity), -c.value.length] }.each do |candidate|
        next if kept.any? { |other| overlaps?(candidate, other) }

        kept << candidate
      end
      kept
    end

    def overlaps?(one, other)
      return false unless spans_overlap?(one.line_span, other.line_span)
      return true if one.line_span.size > 1 || other.line_span.size > 1

      one.column < other.column + other.value.length && other.column < one.column + one.value.length
    end

    def spans_overlap?(one, other)
      one.first <= other.last && other.first <= one.last
    end

    def annotate_repetition(candidates)
      paths_by_value = Hash.new { |hash, key| hash[key] = Set.new }
      candidates.each { |c| paths_by_value[c.value] << c.path }
      # rubocop:disable Style/CombinableLoops -- the second pass reads the first pass's result
      candidates.each { |c| c.distinct_paths = paths_by_value[c.value].size }
      # rubocop:enable Style/CombinableLoops
    end

    def verdict_for(candidate)
      Scoring::Confidence.call(candidate, @filter.call(candidate))
    end
  end
end
