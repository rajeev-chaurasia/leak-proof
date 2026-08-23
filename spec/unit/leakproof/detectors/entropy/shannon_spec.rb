# frozen_string_literal: true

RSpec.describe Leakproof::Detectors::Entropy::Shannon do
  describe ".normalized" do
    let(:git_sha) { "3d59a50f177d77ce013625030ba8dba906f75696" }
    let(:words) { "thequickbrownfoxjumpsoverthelaz" }

    it "scores a full alphabet at its own ceiling rather than a shared one" do
      expect(described_class.normalized("kD9xQ2mVbN7pLzR4tYeW1sA6gH3jU8")).to be_within(0.01).of(1.0)
    end

    it "gives a hex digest a lower raw entropy than English letters" do
      expect(described_class.bits(git_sha)).to be < described_class.bits(words)
    end

    # Thresholding raw bits would rank the English string above the digest, which
    # is backwards. Normalizing against each alphabet's ceiling reverses it.
    it "ranks the hex digest above the English string once normalized" do
      expect(described_class.normalized(git_sha)).to be > described_class.normalized(words)
    end

    # A short draw cannot reach the alphabet's entropy, so the ceiling collapses
    # towards the floor and short values stop scoring as maximally random.
    it "collapses the ceiling for a value too short to sample its alphabet" do
      expect(described_class.ceiling("abcdefgh", charset: :base64)).to eq(described_class::MINIMUM_CEILING)
    end

    it "keeps random tokens above the detection threshold at every length" do
      scores = [24, 32, 64, 100].flat_map do |length|
        (1..50).map { |seed| described_class.normalized(Leakproof::Bench::Synthesizer.new(seed: seed).base62(length)) }
      end

      expect(scores.min).to be > 0.90
    end

    it "scores a repeated character at zero" do
      expect(described_class.normalized("a" * 30)).to eq(0.0)
    end

    it "returns zero for values too short to carry information" do
      expect(described_class.normalized("a")).to eq(0.0)
    end
  end
end
