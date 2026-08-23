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

    it "uses the length ceiling when it binds before the alphabet ceiling" do
      short = "abcdefgh"

      expect(described_class.ceiling(short, charset: :base64)).to eq(Math.log2(8))
    end

    it "scores a repeated character at zero" do
      expect(described_class.normalized("a" * 30)).to eq(0.0)
    end

    it "returns zero for values too short to carry information" do
      expect(described_class.normalized("a")).to eq(0.0)
    end
  end
end
