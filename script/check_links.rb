#!/usr/bin/env ruby
# frozen_string_literal: true

# Guards against a README that promises documents which do not exist.
LINK = /\[[^\]]*\]\(([^)#][^)]*)\)/
failures = []

`git ls-files "*.md"`.each_line(chomp: true).each do |file|
  File.readlines(file).each_with_index do |line, index|
    line.scan(LINK).flatten.each do |target|
      next if target.start_with?("http://", "https://", "mailto:")

      resolved = File.expand_path(target.split("#").first.to_s, File.dirname(file))
      next if File.exist?(resolved)

      failures << "#{file}:#{index + 1}: dead link: #{target}"
    end
  end
end

if failures.empty?
  puts "links ok"
  exit 0
end

warn failures.join("\n")
exit 1
