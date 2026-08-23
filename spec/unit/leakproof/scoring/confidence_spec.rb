# frozen_string_literal: true

RSpec.describe Leakproof::Scoring::Confidence do
  let(:scanner) { Leakproof::Scanner.new }
  let(:synth) { Leakproof::Bench::Synthesizer.new }

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

    it "keeps an unclassified random token below the confirmed tier" do
      finding = verdict(%(value = "#{synth.base62(32)}"), path: "src/config.rb")

      expect(finding.tier).to eq(:probable)
      expect(finding.detector_id).to eq("high-entropy-string")
    end

    it "cannot be reached by any unverified detector at any specificity" do
      unverifiable = Leakproof::Detectors::Registry.default.reject do |d|
        %w[verified].include?(d.validity.check("").status.to_s)
      end
      best = unverifiable.map { |d| described_class::BASE.fetch(d.specificity) }.max

      expect(best + described_class::VALIDITY[:well_formed] + described_class::ENTROPY_BONUS)
        .to be < described_class::CONFIRMED_AT
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
