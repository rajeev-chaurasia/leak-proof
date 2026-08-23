# frozen_string_literal: true

RSpec.describe Leakproof::Detectors::Registry do
  around do |example|
    saved = described_class.registered.dup
    example.run
    described_class.instance_variable_set(:@registered, saved)
  end

  it "loads every provider file without being told their names" do
    expect(described_class.default.size).to be >= 19
  end

  it "looks a detector up by id" do
    expect(described_class.default["aws-access-key-id"].name).to eq("AWS access key ID")
  end

  # The open/closed claim, enforced rather than asserted in prose: a detector
  # registered from outside reaches scanning, validation and the generated table
  # without a single edit to the core.
  describe "adding a detector" do
    let(:added) do
      Leakproof::Detectors::Detector.new(
        id: "acme-deploy-key",
        name: "Acme deploy key",
        pattern: /\b(acme_[a-f0-9]{16})\b/,
        capture: 1,
        validity: Leakproof::Validity::Contract.new(prefix: "acme_", length: 21, charset: :hex),
        examples: { positive: ["acme_0123456789abcdef"], negative: ["acme_short"] }
      )
    end

    before { described_class.register(added) }

    it "appears in the registry" do
      expect(described_class.default.ids).to include("acme-deploy-key")
    end

    it "scans without any core change" do
      match = described_class.default["acme-deploy-key"].scan("key = acme_0123456789abcdef").first

      expect(match.value).to eq("acme_0123456789abcdef")
      expect(match.line).to eq(1)
    end

    it "validates through its declared strategy" do
      expect(added.check("acme_0123456789abcdef")).to be_well_formed
    end

    it "renders into the generated documentation table" do
      expect(added.to_h).to include(id: "acme-deploy-key", offline_check: "prefix and length only")
    end
  end

  it "refuses an unknown specificity at construction time" do
    expect do
      Leakproof::Detectors::Detector.new(id: "x", name: "x", pattern: /x/, specificity: :enormous)
    end.to raise_error(ArgumentError, /specificity/)
  end
end
