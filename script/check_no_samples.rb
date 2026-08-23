#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "leakproof"
require "leakproof/sources"

# leakproof run against its own tracked tree, through the whole pipeline rather
# than raw pattern matching, so a value the filter correctly dismisses is not
# reported here either.
#
# Two things have to hold. The tree must carry no credential the tool would
# report, and detectors must declare a shape rather than a sample: a valid
# sample committed here is a secret committed here.
SKIP = %r{\A(coverage/|tmp/|Gemfile\.lock)}

files = `git ls-files`.each_line(chomp: true).grep_v(SKIP)
findings = Leakproof::Scanner.new.scan(Leakproof::Sources.from_paths(files))
reportable = findings.reject { |f| f.tier == :ignore }

if reportable.empty?
  puts "self scan clean (#{files.length} files, #{findings.length} candidates, all dismissed)"
  exit 0
end

reportable.each do |finding|
  warn "#{finding.path}:#{finding.line}: #{finding.tier} #{finding.detector_id} #{finding.redacted}"
end
warn "\nDeclare a sample: shape on the detector instead of writing one down."
exit 1
