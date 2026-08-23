# frozen_string_literal: true

RSpec.describe Leakproof::Validity::Crc32Base62 do
  subject(:strategy) { described_class.new(entropy_length: 30) }

  describe "against tokens GitHub actually issued" do
    PublishedVectors::GITHUB.each_with_index do |(entropy, checksum), index|
      it "verifies published vector #{index + 1}" do
        result = strategy.check("ghp_#{entropy}#{checksum}")

        expect(result).to be_verified
        expect(result.detail[:prefix]).to eq("ghp_")
      end

      it "rejects vector #{index + 1} when a single checksum character is altered" do
        tampered = checksum.dup
        tampered[-1] = tampered[-1] == "7" ? "8" : "7"

        expect(strategy.check("ghp_#{entropy}#{tampered}")).to be_rejected
      end

      it "rejects vector #{index + 1} when a single entropy character is altered" do
        tampered = entropy.dup
        tampered[0] = tampered[0] == "z" ? "y" : "z"

        expect(strategy.check("ghp_#{tampered}#{checksum}")).to be_rejected
      end
    end
  end

  describe "malformed input" do
    it "reports a missing separator" do
      expect(strategy.check("ghpNoSeparatorHere")).to be_malformed
    end

    it "reports the wrong length" do
      expect(strategy.check("ghp_tooshort")).to be_malformed
    end

    it "reports a non-base62 body" do
      expect(strategy.check("ghp_#{"!" * 36}")).to be_malformed
    end
  end

  it "distinguishes proven answers from unproven ones" do
    vector = PublishedVectors::GITHUB[0]
    expect(strategy.check("ghp_#{vector[0]}#{vector[1]}")).to be_proven
    expect(strategy.check("ghp_tooshort")).not_to be_proven
  end
end
