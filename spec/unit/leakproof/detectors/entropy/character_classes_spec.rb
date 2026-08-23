# frozen_string_literal: true

RSpec.describe Leakproof::Detectors::Entropy::CharacterClasses do
  # Every one of these was an entropy false positive on a real repository, and
  # every one scores within 0.02 of a drawn token on normalized entropy.
  ["/packages/client-python/", "MINIO_ROOT_ADMIN", "RR_TEST_POSTGRESQL",
   "the_quick_brown_fox_jumps", "application/json;charset"].each do |value|
    it "rejects #{value.inspect} as drawing on too few classes" do
      expect(described_class.diverse?(value)).to be(false)
    end
  end

  it "accepts effectively every drawn token" do
    accepted = (1..200).count do |seed|
      described_class.diverse?(Leakproof::Bench::Synthesizer.new(seed: seed).base62(32))
    end

    expect(accepted).to eq(200)
  end

  it "counts the classes present" do
    expect(described_class.count("abc")).to eq(1)
    expect(described_class.count("abcABC")).to eq(2)
    expect(described_class.count("abcABC123")).to eq(3)
  end
end
