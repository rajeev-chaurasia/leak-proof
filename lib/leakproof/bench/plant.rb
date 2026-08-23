# frozen_string_literal: true

module Leakproof
  module Bench
    # Ground truth for one planted credential. Deliberately binary: a location
    # either holds a real credential or it does not. Expected tiers are not
    # recorded, because grading the scoring table against the scoring table
    # would measure nothing.
    Plant = Struct.new(:rule, :path, :value, :line, :placement, keyword_init: true) do
      def key = [path, value]

      def to_h = { rule: rule, path: path, line: line, placement: placement }
    end

    # A value that must not be reported. Every kind here was an observed false
    # positive on a real repository.
    Decoy = Struct.new(:kind, :path, :content, keyword_init: true) do
      def to_h = { kind: kind, path: path }
    end
  end
end
