# frozen_string_literal: true

# Generated samples across many seeds, because a single hand-picked sample hides
# charset edge cases. The trailing word boundary on the base64url rules survived
# review and one fixed sample, and was only caught when a generated token
# happened to end in a hyphen.
RSpec.describe "detector round trip" do
  registry = Leakproof::Detectors::Registry.default

  registry.each do |detector|
    next unless detector.synthesize(Leakproof::Bench::Synthesizer.new)

    describe detector.id do
      it "detects and accepts its own generated sample for every seed" do
        failures = CorpusSamples::SEEDS.filter_map do |seed|
          sample = detector.synthesize(Leakproof::Bench::Synthesizer.new(seed: seed))
          match = detector.scan(sample).first
          next "seed #{seed}: no match for #{sample[0, 32]}" unless match

          status = detector.check(match.value).status
          "seed #{seed}: #{status} for #{sample[0, 32]}" if %i[rejected malformed].include?(status)
        end

        expect(failures).to be_empty
      end

      # Name-anchored rules embed their sample in an assignment, so only the
      # bare-token rules can be compared for equality.
      it "recovers the whole token, not a prefix of it" do
        sample = detector.synthesize(Leakproof::Bench::Synthesizer.new(seed: 7))
        next if detector.multiline? || sample.match?(/\s/)

        match = detector.scan("value = #{sample}").first

        expect(match.value).to eq(sample)
      end
    end
  end
end
