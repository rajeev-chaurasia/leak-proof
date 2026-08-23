# frozen_string_literal: true

# Three findings a real project had to write into a .gitleaksignore by hand.
#
# Each entry in that file is a false positive someone triaged, explained in a
# comment, and suppressed permanently. They are reproduced here because a
# scanner that still reports them has not improved on the tool that produced
# the ignore file.
RSpec.describe "findings that earned a .gitleaksignore entry" do
  let(:scanner) { Leakproof::Scanner.new }
  let(:synth) { Leakproof::Bench::Synthesizer.new }

  def tiers(content, path:)
    scanner.scan_text(content, path: path).to_h { |f| [f.detector_id, f.tier] }
  end

  # "Stripe publishable key (pk_test_*) is a public client-side key, not a secret."
  # gitleaks matched it with its generic-api-key rule.
  describe "a Stripe publishable key" do
    let(:content) { %(STRIPE_PUBLISHABLE_KEY=pk_test_#{synth.base62(24)}\n) }

    it "is recognised as the publishable form rather than a generic key" do
      expect(tiers(content, path: ".config")).to include("stripe-publishable-key" => :ignore)
    end

    it "produces no finding above the ignore tier" do
      findings = scanner.scan_text(content, path: ".config").reject { |f| f.tier == :ignore }

      expect(findings).to be_empty
    end

    it "still reports the secret form from the same vendor" do
      secret = %(STRIPE_SECRET_KEY=sk_live_#{synth.base62(24)}\n)

      expect(tiers(secret, path: ".config")["stripe-secret-key"]).to eq(:probable)
    end
  end

  # "False positive: placeholder API key in node test config template."
  describe "a placeholder in a node service config" do
    let(:path) { "nodes/src/nodes/tool_exa_search/services.json" }

    it "ignores an interpolated reference" do
      content = %({"apikey": "${EXA_API_KEY}"}\n)

      expect(scanner.scan_text(content, path: path).reject { |f| f.tier == :ignore }).to be_empty
    end

    it "ignores an instructional placeholder" do
      content = %({"apikey": "YOUR_API_KEY_HERE"}\n)

      expect(scanner.scan_text(content, path: path).reject { |f| f.tier == :ignore }).to be_empty
    end

    it "ignores a self-labelled example" do
      content = %({"apikey": "sk-EXAMPLE-KEY-DO-NOT-USE-1234567890"}\n)

      expect(scanner.scan_text(content, path: path).reject { |f| f.tier == :ignore }).to be_empty
    end

    it "still reports a real credential in the same file" do
      content = %({"apikey": "#{synth.crc32_token("ghp_")}"}\n)

      expect(scanner.scan_text(content, path: path).map(&:tier)).to include(:confirmed)
    end
  end

  # "Orphaned SHA after develop force-push resurfaced the finding on this dot
  # release PR." Covered end to end in the fingerprint spec; asserted here as
  # the property that makes the suppression durable.
  it "identifies a finding by content rather than by the commit that carried it" do
    value = synth.crc32_token("ghp_")
    first = Leakproof::Scoring::Fingerprint.call(detector_id: "github-pat", path: "a.rb", value: value)
    second = Leakproof::Scoring::Fingerprint.call(detector_id: "github-pat", path: "a.rb", value: value)

    expect(first).to eq(second)
  end
end
