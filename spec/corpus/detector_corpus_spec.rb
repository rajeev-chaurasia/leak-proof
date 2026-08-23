# frozen_string_literal: true

# The executable specification of the detector engine. Every registered detector
# must declare examples, and every example must behave as declared. A new
# provider file cannot be merged without earning its row here.
RSpec.describe "detector corpus" do
  registry = CorpusSamples::REGISTRY

  def survives?(detector, sample)
    match = detector.scan(sample).first
    return false unless match

    !detector.check(match.value).status.then { |s| %i[rejected malformed].include?(s) }
  end

  it "registers every provider file exactly once" do
    expect(registry.ids.uniq.length).to eq(registry.size)
  end

  registry.each do |detector|
    describe detector.id do
      let(:positives) { detector.examples[:positive] + Array(detector.synthesize(CorpusSamples::SYNTHESIZER)) }

      it "declares at least one positive example" do
        expect(positives).not_to be_empty
      end

      it "declares at least one negative example" do
        expect(detector.examples[:negative]).not_to be_empty
      end

      it "matches every positive example and lets it survive validation" do
        positives.each do |sample|
          expect(survives?(detector, sample)).to be(true),
                                                 "expected #{detector.id} to accept #{sample[0, 24]}"
        end
      end

      it "rejects every negative example, by pattern or by validation" do
        detector.examples[:negative].each do |sample|
          expect(survives?(detector, sample)).to be(false),
                                                 "expected #{detector.id} to reject #{sample[0, 24]}"
        end
      end

      it "reports an offline check in the generated table" do
        expect(detector.to_h[:offline_check]).to be_a(String)
      end
    end
  end
end
