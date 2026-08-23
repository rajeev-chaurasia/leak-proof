# frozen_string_literal: true

require_relative "suppressor"

module Leakproof
  module Filter
    # Where a value lives is evidence about what it is. A credential under a
    # fixtures directory is usually a fixture.
    class PathRules < Suppressor
      PATTERNS = {
        %r{(\A|/)(spec|test|tests|__tests__)/} => "test tree",
        %r{(\A|/)fixtures?/} => "fixture directory",
        %r{(\A|/)(examples?|samples?|demos?)/} => "example directory",
        %r{(\A|/)(docs?|documentation)/} => "documentation",
        %r{(\A|/)(vendor|node_modules|third_party|\.bundle)/} => "vendored dependency",
        /\.(example|sample|template|dist)(\.[a-z]+)?\z/ => "template file",
        /\.(lock|sum)\z/ => "lock file",
        %r{(\A|/)(package-lock\.json|yarn\.lock|pnpm-lock\.yaml|Gemfile\.lock)\z} => "lock file"
      }.freeze

      PENALTY = 35

      def suppression_for(candidate)
        path = candidate.path.to_s
        return nil if path.empty?

        _pattern, label = PATTERNS.find { |pattern, _| path.match?(pattern) }
        return nil unless label

        suppression("path is a #{label}", PENALTY)
      end
    end
  end
end
