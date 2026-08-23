# frozen_string_literal: true

RSpec.describe Leakproof::Filter::IdentifierShape do
  subject(:suppressor) { described_class.new }

  let(:registry) { Leakproof::Detectors::Registry.default }

  def candidate_for(value, detector_id)
    detector = registry[detector_id]
    match = Leakproof::Detectors::Match.new(
      detector: detector, value: value, line: 1, column: 1, line_text: value
    )
    Leakproof::Scoring::Candidate.new(match: match, validity: detector.check(value), path: "src/a.rb")
  end

  # Every false positive from the first real-repository run.
  ["x-api-key", "chat_token", "api.key.header", "content-type", "Bearer token here",
   "Mask2FormerInstanceLoader", "GetModelServerAddress"].each do |value|
    it "dismisses #{value.inspect} from a generic rule" do
      expect(suppressor.suppression_for(candidate_for(value, "generic-assignment"))).not_to be_nil
    end
  end

  it "says nothing about a random value" do
    expect(suppressor.suppression_for(candidate_for("kD9xQ2mVbN7pLzR4tYeW", "generic-assignment"))).to be_nil
  end

  # The camel-case rule costs recall. The cost is measured rather than assumed.
  it "dismisses under one percent of drawn tokens at forty characters" do
    dismissed = (1..500).count do |seed|
      token = Leakproof::Bench::Synthesizer.new(seed: seed).base62(40)
      !suppressor.suppression_for(candidate_for(token, "high-entropy-string")).nil?
    end

    expect(dismissed).to be < 5
  end

  # Several real formats are dot-separated or hyphenated, so this heuristic must
  # never reach a rule that already matched a provider's own structure.
  it "never touches a provider rule" do
    jwt = SampleSecrets.jwt

    expect(suppressor.suppression_for(candidate_for(jwt, "json-web-token"))).to be_nil
  end

  it "leaves a Slack token alone despite its hyphens" do
    token = Leakproof::Bench::Synthesizer.new.then { |s| "xoxb-#{s.digits(12)}-#{s.digits(13)}-#{s.base62(24)}" }

    expect(suppressor.suppression_for(candidate_for(token, "slack-token"))).to be_nil
  end
end
