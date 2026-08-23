# frozen_string_literal: true

require_relative "lib/leakproof/version"

Gem::Specification.new do |spec|
  spec.name = "leakproof"
  spec.version = Leakproof::VERSION
  spec.authors = ["Rajeev Chaurasia"]
  spec.email = ["rajeevchaurasia.dev@gmail.com"]

  spec.summary = "Credential scanner that verifies findings offline, with a published confusion matrix."
  spec.description = <<~TEXT
    Walks full git history across all refs, detects credentials with provider patterns
    and charset-normalized entropy, then decides which findings are real using offline
    structural validation. No network egress to any provider, ever.
  TEXT
  spec.homepage = "https://github.com/rajeev-chaurasia/leak-proof"
  spec.license = "Apache-2.0"
  spec.required_ruby_version = ">= 3.3"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir[
    "lib/**/*.rb",
    "exe/*",
    "docs/**/*.md",
    "README.md",
    "LICENSE"
  ]
  spec.bindir = "exe"
  spec.executables = %w[leakproof leakproof-bench]
  spec.require_paths = ["lib"]
end
