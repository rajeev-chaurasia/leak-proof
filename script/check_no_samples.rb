#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "leakproof"

# leakproof scanning itself, before the scanner is finished. A detector must
# never carry a literal sample: a valid sample committed here is a secret
# committed here, and GitHub's push protection is right to refuse it.
SKIP = %r{\A(coverage/|tmp/|Gemfile\.lock|script/check_no_samples\.rb)}

registry = Leakproof::Detectors::Registry.default
provider_rules = registry.reject { |d| %w[high-entropy-string generic-assignment].include?(d.id) }
failures = []

`git ls-files`.each_line(chomp: true).each do |file|
  next if file.match?(SKIP)
  next unless File.file?(file)

  content = File.read(file, encoding: "UTF-8", invalid: :replace, undef: :replace)
  provider_rules.each do |detector|
    detector.scan(content) do |match|
      next if %i[rejected malformed].include?(detector.check(match.value).status)

      failures << "#{file}:#{match.line}: #{detector.id} would flag a committed literal"
    end
  end
end

if failures.empty?
  puts "no committed samples"
  exit 0
end

warn failures.join("\n")
warn "\nDeclare a sample: shape on the detector instead of writing one down."
exit 1
