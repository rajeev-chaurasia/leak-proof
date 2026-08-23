# frozen_string_literal: true

RSpec.describe Leakproof::Validity::Contract do
  it "never returns a verified status, because it has no proof to offer" do
    strategy = described_class.new(prefix: "sk_live_", length: 32)

    expect(strategy.check("sk_live_#{"a" * 24}")).to be_well_formed
    expect(strategy.check("sk_live_#{"a" * 24}")).not_to be_proven
  end

  it "checks a prefix" do
    expect(described_class.new(prefix: "sk_").check("pk_abc")).to be_malformed
  end

  it "accepts a length range" do
    strategy = described_class.new(length: 10..20)

    expect(strategy.check("a" * 15)).to be_well_formed
    expect(strategy.check("a" * 25)).to be_malformed
  end

  it "checks the body against the declared charset" do
    strategy = described_class.new(prefix: "SK", charset: :hex)

    expect(strategy.check("SKdeadbeef")).to be_well_formed
    expect(strategy.check("SKzzzzzzzz")).to be_malformed
  end

  it "describes itself honestly in the generated table" do
    expect(described_class.new.describes).to eq("prefix and length only")
  end
end
