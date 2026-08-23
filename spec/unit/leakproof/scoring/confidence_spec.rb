# frozen_string_literal: true

RSpec.describe Leakproof::Scoring::Confidence do
  let(:scanner) { Leakproof::Scanner.new }
  let(:synth) { Leakproof::Bench::Synthesizer.new }

  # A candidate whose value is deliberately drawn, so the entropy bonus applies
  # wherever a rule is eligible for it.
  def candidate_for(detector, status)
    value = synth.base62(40)
    match = Leakproof::Detectors::Match.new(
      detector: detector, value: value, line: 1, column: 1, line_text: value
    )
    Leakproof::Scoring::Candidate.new(
      match: match, validity: Leakproof::Validity::Result.new(status), path: "src/config.rb"
    )
  end

  def verdict(content, path:)
    scanner.scan_text(content, path: path).first
  end

  # The project's one hard invariant, expressed as a test rather than a promise.
  describe "the confirmed tier" do
    it "admits a finding whose format carries a checksum" do
      finding = verdict(%(TOKEN = "#{synth.crc32_token("ghp_")}"), path: "src/config.rb")

      expect(finding.tier).to eq(:confirmed)
      expect(finding.validity).to be_verified
    end

    it "refuses a format with no proof, however suggestive the context" do
      finding = verdict(%(aws_key = "#{synth.aws_key}"), path: "src/config.rb")

      expect(finding.tier).to eq(:probable)
      expect(finding.validity).to be_well_formed
    end

    it "produces nothing at all for a bare hex digest" do
      findings = scanner.scan_text(%(sha = "3d59a50f177d77ce013625030ba8dba906f75696"), path: "src/config.rb")

      expect(findings).to be_empty
    end

    # Randomness on its own is not evidence of a credential. The base score for
    # a low-specificity rule plus the entropy bonus used to land exactly on
    # PROBABLE_AT, which surfaced every base64 blob in a repository.
    it "leaves an uncorroborated random token below the probable tier" do
      advisory = Leakproof::Scanner.new(include_advisory: true)
      finding = advisory.scan_text(%(value = "#{synth.base62(32)}"), path: "src/config.rb").first

      expect(finding.tier).to eq(:ignore)
      expect(finding.detector_id).to eq("high-entropy-string")
    end

    # And it is not even computed unless something asks to see the ignore tier.
    it "does not run an advisory rule by default" do
      expect(scanner.scan_text(%(value = "#{synth.base62(32)}"), path: "src/config.rb")).to be_empty
    end

    it "reports the same token once a credential-shaped name corroborates it" do
      expect(verdict(%(api_key = "#{synth.base62(32)}"), path: "src/config.rb").tier).to eq(:probable)
    end

    # A JWT decodes; that proves it is a JWT, not that it is live or secret.
    it "never confirms a JSON web token" do
      expect(verdict(%(t = "#{synth.jwt}"), path: "src/config.rb").tier).to eq(:probable)
    end

    # Driven through the real scorer, for every registered rule, at every
    # non-verified validity status. The previous version recomputed the constants
    # and never called Confidence.call, so doubling the entropy bonus passed.
    it "cannot be reached by any rule without a proof, at any validity short of verified" do
      reached = Leakproof::Detectors::Registry.default.flat_map do |detector|
        %i[unknown well_formed malformed].map do |status|
          verdict = described_class.call(candidate_for(detector, status), [])
          "#{detector.id}/#{status}" if verdict.tier == :confirmed
        end
      end.compact

      expect(reached).to be_empty
    end

    it "does reach the confirmed tier once a proof is present" do
      detector = Leakproof::Detectors::Registry.default["github-pat"]

      expect(described_class.call(candidate_for(detector, :verified), []).tier).to eq(:confirmed)
    end
  end

  describe "demotion" do
    it "drops a verified token to probable when it sits in a fixture tree" do
      finding = verdict(%(TOKEN = "#{synth.crc32_token("ghp_")}"), path: "spec/fixtures/creds.rb")

      expect(finding.tier).to eq(:probable)
      expect(finding.verdict.suppressions.map(&:rule)).to include("path-rules")
    end

    it "ignores a credential type that is public by design" do
      finding = verdict(%(pk = "pk_test_#{synth.base62(24)}"), path: "src/pay.rb")

      expect(finding.tier).to eq(:ignore)
      expect(finding.verdict.reason).to include("public by design")
    end

    it "ignores a value the format itself rejects" do
      finding = verdict(%(TOKEN = "ghp_#{"0" * 36}"), path: "src/config.rb")

      expect(finding.tier).to eq(:ignore)
      expect(finding.verdict.reason).to include("not a credential")
    end
  end

  describe "the entropy bonus" do
    it "promotes a random value assigned to a credential-shaped name" do
      expect(verdict(%(PASSWORD = "#{synth.base62(28)}"), path: "src/a.rb").tier).to eq(:probable)
    end

    it "leaves a word-shaped value alone" do
      expect(verdict(%(password = "correcthorsebattery"), path: "src/a.rb").tier).to eq(:ignore)
    end
  end
end
