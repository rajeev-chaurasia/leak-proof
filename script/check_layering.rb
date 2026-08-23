#!/usr/bin/env ruby
# frozen_string_literal: true

# The detection engine must stay testable with no repository on disk, so it may
# not reach the git layer by any spelling.
#
# An earlier version grepped for "Leakproof::Git" only. That missed a bare
# `Git::Blob` resolved lexically inside `module Leakproof`, a `require_relative
# "../git/..."`, a `const_get(:Git)`, and shelling out to git directly.
FORBIDDEN_LAYERS = %w[detectors validity filter scoring report].freeze

PATTERNS = {
  /\bLeakproof::Git\b/ => "names the git layer",
  /\bGit::[A-Z]/ => "resolves a git constant lexically",
  %r{require(_relative)?\s+["'][^"']*\bgit/} => "requires from the git layer",
  /const_get\(\s*:Git\b/ => "reaches the git layer reflectively",
  /(IO\.popen|Open3|%x\(|`)\s*\(?\s*\[?\s*["']?git\b/ => "shells out to git"
}.freeze

failures = []

FORBIDDEN_LAYERS.each do |layer|
  Dir.glob("lib/leakproof/#{layer}/**/*.rb").each do |file|
    File.readlines(file).each_with_index do |line, index|
      next if line.lstrip.start_with?("#")

      PATTERNS.each do |pattern, reason|
        failures << "#{file}:#{index + 1}: #{layer}/ #{reason}" if line.match?(pattern)
      end
    end
  end
end

if failures.empty?
  puts "layering ok (#{FORBIDDEN_LAYERS.length} layers, #{PATTERNS.length} patterns)"
  exit 0
end

warn failures.join("\n")
exit 1
