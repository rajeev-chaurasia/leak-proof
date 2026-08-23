# frozen_string_literal: true

require_relative "match"
require_relative "../validity/strategy"

module Leakproof
  module Detectors
    # A frozen declaration. The registry reads it, the specs read it, and the
    # docs/detectors.md is generated from it, so behaviour and documentation
    # cannot drift apart.
    class Detector
      SPECIFICITIES = %i[high medium low].freeze

      attr_reader :id, :name, :pattern, :charset, :validity, :specificity, :examples, :notes

      # rubocop:disable Metrics/ParameterLists -- the declaration is the interface
      # rubocop:disable Metrics/MethodLength -- the declaration is the interface
      def initialize(id:, name:, pattern:, validity: nil, charset: nil, specificity: :high,
                     secret: true, capture: 0, multiline: false, sample: nil,
                     entropy_bonus: false, advisory: false, keywords: [], keywords_ignore_case: false,
                     examples: {}, notes: nil)
        raise ArgumentError, "unknown specificity: #{specificity}" unless SPECIFICITIES.include?(specificity)

        @id = id
        @name = name
        @pattern = pattern
        @charset = charset
        @validity = validity || Validity::Strategy.new
        @specificity = specificity
        @secret = secret
        @multiline = multiline
        @sample = sample
        @entropy_bonus = entropy_bonus
        @advisory = advisory
        @keywords = keywords.freeze
        @keyword_matcher = build_keyword_matcher(keywords, keywords_ignore_case)
        @capture = capture
        @examples = { positive: [], negative: [], suppressed: [] }.merge(examples).freeze
        @notes = notes
        freeze
      end
      # rubocop:enable Metrics/ParameterLists
      # rubocop:enable Metrics/MethodLength

      # A Stripe publishable key is published on purpose. Detecting it and then
      # calling it a leak is how a scanner earns an ignore file.
      def secret?
        @secret
      end

      # An advisory rule cannot reach a reportable tier on its own evidence. It
      # exists to be visible with --show ignore during a manual audit.
      def advisory?
        @advisory
      end

      # True for rules anchored on a variable name rather than a value shape.
      # A random-looking value assigned to something called "password" is
      # evidence; the same value alone on a line is not.
      def entropy_bonus?
        @entropy_bonus
      end

      # A union of literals is far cheaper than the full rule, and on a real
      # repository almost every blob fails it.
      def applicable?(text)
        return true unless @keyword_matcher

        @keyword_matcher.match?(text)
      end

      def scan(text, &)
        return enum_for(:scan, text) unless block_given?
        return unless applicable?(text)

        if @multiline
          scan_whole(text.to_s, &)
        else
          text.to_s.each_line.with_index(1) do |line, number|
            scan_line(line, number, &)
          end
        end
      end

      def multiline?
        @multiline
      end

      def check(value)
        validity.check(value)
      end

      # A detector declares the shape of a valid credential, never one itself.
      # Committing a literal sample would mean committing a secret.
      def synthesize(synthesizer)
        @sample&.call(synthesizer)
      end

      def to_h
        {
          id: id, name: name, specificity: specificity, secret: secret?,
          offline_check: validity.describes, notes: notes
        }
      end

      private

      def build_keyword_matcher(keywords, ignore_case)
        return nil if keywords.empty?

        Regexp.union(keywords).then { |u| ignore_case ? Regexp.new(u.source, Regexp::IGNORECASE) : u }
      end

      def scan_line(line, number)
        line.scan(pattern) { yield build_match(line, number, Regexp.last_match) }
      end

      # A PEM block spans lines, so its offset has to be translated back into one.
      def scan_whole(text)
        text.scan(pattern) do
          data = Regexp.last_match
          number = text[0...data.begin(0)].count("\n") + 1
          value = @capture.zero? ? data[0] : data[@capture]
          yield Match.new(detector: self, value: value, line: number, column: 1,
                          line_text: value.lines.first.to_s.chomp)
        end
      end

      def build_match(line, number, data)
        index = capture_index(data)
        Match.new(detector: self, value: data[index], line: number,
                  column: data.begin(index) + 1, line_text: line.chomp)
      end

      # A rule with alternate branches captures into whichever group matched.
      def capture_index(data)
        return @capture unless @capture == :value

        (1...data.size).find { |i| data[i] } || 0
      end
    end
  end
end
