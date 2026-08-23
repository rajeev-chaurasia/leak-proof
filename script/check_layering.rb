#!/usr/bin/env ruby
# frozen_string_literal: true

# ADR 0001. The detection engine must stay testable with no repository on disk,
# so it may not name the git layer at all.
FORBIDDEN = %w[detectors validity filter scoring].freeze
failures = []

FORBIDDEN.each do |layer|
  Dir.glob("lib/leakproof/#{layer}/**/*.rb").each do |file|
    File.readlines(file).each_with_index do |line, index|
      next unless line.match?(%r{Leakproof::Git|require.*leakproof/git})

      failures << "#{file}:#{index + 1}: #{layer}/ must not reach into the git layer"
    end
  end
end

if failures.empty?
  puts "layering ok"
  exit 0
end

warn failures.join("\n")
exit 1
