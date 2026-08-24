#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "leakproof"
require "leakproof/sources"

# leakproof run against its own repository, through the whole pipeline rather
# than raw pattern matching, so a value the filter correctly dismisses is not
# reported here either.
#
# Two things have to hold. The repository must carry no credential the tool
# would report, and detectors must declare a shape rather than a sample: a valid
# sample committed here is a secret committed here.
#
# It reads the whole object store, not the working tree. Checking only the tree
# would leave the gate blind to history, which is the one thing this tool exists
# to read, and a sample deleted in a later commit is still committed.
#
# The entries below are values this repository really does carry in old blobs,
# from before the shape-not-sample rule existed. None was ever issued by a
# provider: they are synthetic drafts and third-party published vectors. They
# are keyed by content fingerprint rather than commit, so they stay suppressed
# across a rebase and cannot be widened to cover anything new.
KNOWN = {
  "048eea0d26d1f302e6c72590ef2df519" => "synthetic AWS key ID from an early git-backend spec",
  "a12cf3c90235528053456f4c881a5a25" => "the psanford AWS account-ID vector, published and non-live",
  "548c74cf04aff452ab357da024fa3a6a" => "synthetic AWS secret from a superseded detector fixture",
  "5c354bccadea224801f736e1afff7736" => "synthetic Slack token from a superseded detector fixture",
  "12b2d391d3f39c4487cffc0c8364301c" => "synthetic Slack webhook from a superseded detector fixture",
  "51a65bc0d19beb86487fc7d6bc3c4854" => "synthetic Google API key from a superseded detector fixture",
  "314736051dd325c1340fa64b10279be6" => "generated RSA key from a superseded validity fixture"
}.freeze

HISTORY = "(history)"

SKIP = %r{\A(coverage/|tmp/|Gemfile\.lock)}

scanner = Leakproof::Scanner.new
findings = []

# The working tree first, so a sample is caught before it is ever committed.
# History alone would only ever report it after the fact.
`git ls-files`.each_line(chomp: true).grep_v(SKIP).each do |file|
  next unless File.file?(file)

  text = File.binread(file)
  next if text.include?("\x00")

  findings.concat(
    scanner.scan_text(text.force_encoding(Encoding::UTF_8).scrub(""), path: HISTORY)
           .map { |f| [f, file] }
  )
end

# Then the object store, because a sample deleted in a later commit is still
# committed, and history is the one thing this tool exists to read.
Leakproof::Git::PlumbingBackend.new(Dir.pwd).each_blob(mode: :all_objects) do |blob|
  next if blob.binary?

  # One constant path for every source, so a fingerprint here depends only on
  # the rule and the bytes. An unreachable object has no path to key on anyway.
  findings.concat(scanner.scan_text(blob.text, path: HISTORY).map { |f| [f, blob.path] })
end

reportable = findings.reject { |(f, _)| f.tier == :ignore || KNOWN.key?(f.fingerprint) }

if reportable.empty?
  puts "self scan clean (#{findings.length} candidates, #{KNOWN.size} known historical samples)"
  exit 0
end

reportable.each do |finding, origin|
  where = origin || "unreachable object"
  warn "#{where}:#{finding.line}: #{finding.tier} #{finding.detector_id} #{finding.redacted}"
  warn "  fingerprint #{finding.fingerprint}"
end
warn "\nDeclare a sample: shape on the detector instead of writing one down."
exit 1
