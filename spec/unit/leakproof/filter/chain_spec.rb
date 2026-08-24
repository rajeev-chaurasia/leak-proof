# frozen_string_literal: true

RSpec.describe Leakproof::Filter::Chain do
  subject(:chain) { described_class.default }

  def candidate(value:, path: "src/app.rb", distinct_paths: 1, line_text: nil)
    detector = Leakproof::Detectors::Registry.default["aws-access-key-id"]
    match = Leakproof::Detectors::Match.new(
      detector: detector, value: value, line: 1, column: 1, line_text: line_text || value
    )
    Leakproof::Scoring::Candidate.new(match: match, validity: detector.check(value), path: path).tap do |c|
      c.distinct_paths = distinct_paths
    end
  end

  def rules_for(value:, path: "src/app.rb", distinct_paths: 1, line_text: nil)
    chain.call(
      candidate(value: value, path: path, distinct_paths: distinct_paths, line_text: line_text)
    ).map(&:rule)
  end

  it "runs every suppressor it was given" do
    expect(chain.rules).to contain_exactly(
      "placeholders", "identifier-shape", "documented-dummy",
      "path-rules", "minified", "repetition"
    )
  end

  it "says nothing about an ordinary value in an ordinary path" do
    expect(rules_for(value: SampleSecrets.aws_key)).to be_empty
  end

  describe "path rules" do
    {
      "spec/fixtures/keys.rb" => "fixture directory",
      "test/support/a.rb" => "test tree",
      "vendor/gem/a.rb" => "vendored dependency",
      "docs/setup.md" => "documentation",
      "config/database.yml.example" => "template file",
      "Gemfile.lock" => "lock file"
    }.each do |path, label|
      it "flags #{label} for #{path}" do
        expect(rules_for(value: SampleSecrets.aws_key, path: path)).to include("path-rules")
      end
    end
  end

  describe "placeholders" do
    ["${AWS_KEY}", "$AWS_KEY", "<your-key-here>", "YOUR_API_KEY", "changeme", "xxxxxxxx",
     "AKIAIOSFODNN7EXAMPLE"].each do |value|
      it "flags #{value}" do
        expect(rules_for(value: value)).to include("placeholders")
      end
    end
  end

  it "flags a value published in vendor documentation" do
    expect(rules_for(value: PublishedVectors.aws_documentation_key)).to include("documented-dummy")
  end

  describe "minified content" do
    it "flags a minified asset path" do
      expect(rules_for(value: SampleSecrets.aws_key, path: "public/app.min.js")).to include("minified")
    end

    it "flags a line long enough to be a bundle" do
      long = "a" * 600

      expect(rules_for(value: SampleSecrets.aws_key, line_text: long)).to include("minified")
    end
  end

  describe "repetition" do
    it "says nothing below the threshold" do
      expect(rules_for(value: SampleSecrets.aws_key, distinct_paths: 2)).not_to include("repetition")
    end

    it "flags a value that appears across several files" do
      expect(rules_for(value: SampleSecrets.aws_key, distinct_paths: 5)).to include("repetition")
    end
  end
end
