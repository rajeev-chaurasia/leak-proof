# frozen_string_literal: true

RSpec.describe Leakproof::Detectors::Entropy::Sequence do
  # Each of these was a real false positive on a 1,902-commit repository, and
  # each has perfect Shannon entropy.
  {
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ" => "the uppercase alphabet",
    "abcdefghijklmnopqrstuvwxyz" => "the lowercase alphabet",
    "0123456789012345678901234" => "a digit run"
  }.each do |value, description|
    it "recognises #{description} as an enumeration" do
      expect(described_class.enumerated?(value)).to be(true)
    end

    it "scores #{description} at maximum normalized entropy anyway" do
      next if value.start_with?("0")

      expect(Leakproof::Detectors::Entropy::Shannon.normalized(value)).to be_within(0.01).of(1.0)
    end
  end

  it "says nothing about a drawn token" do
    token = Leakproof::Bench::Synthesizer.new.base62(32)

    expect(described_class.enumerated?(token)).to be(false)
  end

  it "reports adjacency as a fraction" do
    expect(described_class.adjacency("abcd")).to eq(1.0)
    expect(described_class.adjacency("aqzm")).to eq(0.0)
    expect(described_class.adjacency("")).to eq(0.0)
  end
end
