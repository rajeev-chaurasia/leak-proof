# frozen_string_literal: true

# Every number this project publishes, asserted at the value where it changes
# behaviour rather than somewhere comfortably past it.
#
# A mutation audit found that DEFAULT_THRESHOLD could be halved, the length
# bounds moved by one, and the PAT length anchor widened from 36 to a range,
# with the suite staying green throughout. Samples far from a boundary do not
# pin the boundary.
RSpec.describe Leakproof::Scoring::Confidence do # rubocop:disable RSpec/SpecFilePathFormat
  let(:synth) { Leakproof::Bench::Synthesizer.new(seed: 41) }
  let(:scanner) { Leakproof::Scanner.new }

  def detector(id)
    Leakproof::Detectors::Registry.default.find { |d| d.id == id }
  end

  describe "the entropy rule's length bounds" do
    subject(:rule) { detector("high-entropy-string") }

    it "ignores a value one character below the minimum of 24" do
      expect(rule.scan(%(x = "#{synth.base62(23)}")).to_a).to be_empty
    end

    it "matches a value at exactly the minimum of 24" do
      expect(rule.scan(%(x = "#{synth.base62(24)}")).to_a).not_to be_empty
    end

    it "matches a value at exactly the maximum of 120" do
      expect(rule.scan(%(x = "#{synth.base62(120)}")).to_a).not_to be_empty
    end

    it "ignores a value one character above the maximum of 120" do
      expect(rule.scan(%(x = "#{synth.base62(121)}")).to_a).to be_empty
    end
  end

  describe "the entropy threshold of 0.92" do
    subject(:rule) { detector("high-entropy-string") }

    let(:dull_value) { "qbuu7bzkXn1LrtAhyaZRGGWGoIqqqqqq" }

    # Deliberately just under the threshold, and carrying three character
    # classes so every other bound is satisfied and the threshold is the only
    # thing rejecting it. A duller value would be turned away on charset instead
    # and would pin nothing.

    it "ignores a value whose normalized entropy sits just below the threshold" do
      score = Leakproof::Detectors::Entropy::Shannon.normalized(dull_value)

      expect(score).to be_between(0.50, 0.92)
      expect(rule.scan(%(x = "#{dull_value}")).to_a).to be_empty
    end

    it "reports that same value once the threshold is relaxed" do
      relaxed = Leakproof::Detectors::Entropy::EntropyDetector.new(threshold: 0.50)

      expect(relaxed.scan(%(x = "#{dull_value}")).to_a).not_to be_empty
    end

    it "matches a drawn value, which sits above the threshold" do
      drawn = synth.base62(32)

      expect(Leakproof::Detectors::Entropy::Shannon.normalized(drawn)).to be >= 0.92
      expect(rule.scan(%(x = "#{drawn}")).to_a).not_to be_empty
    end
  end

  describe "the GitHub token length anchor of 36" do
    subject(:rule) { detector("github-pat") }

    it "matches at exactly 36 body characters" do
      expect(rule.scan(%(t = "ghp_#{synth.base62(36)}")).to_a).not_to be_empty
    end

    it "ignores 35 and 37 body characters" do
      expect(rule.scan(%(t = "ghp_#{synth.base62(35)}")).to_a).to be_empty
      expect(rule.scan(%(t = "ghp_#{synth.base62(37)}")).to_a).to be_empty
    end
  end

  describe "the default blob ceiling of 1 MB" do
    it "is exactly one million bytes" do
      expect(Leakproof::Git::Backend::DEFAULT_MAX_BLOB_BYTES).to eq(1_000_000)
    end

    it "reads a blob at the ceiling and skips one above it" do
      repo = RepoBuilder.build do |r|
        r.commit("Add two blobs", "at.txt" => "a" * 1_000_000, "over.txt" => "b" * 1_000_001)
      end
      paths = Leakproof::Git::PlumbingBackend.new(repo.path).each_blob(mode: :reachable).map(&:path)

      expect(paths).to include("at.txt")
      expect(paths).not_to include("over.txt")
    ensure
      repo&.destroy
    end
  end

  describe "the registry" do
    it "holds exactly the rules the documentation counts" do
      expect(Leakproof::Detectors::Registry.default.size).to eq(22)
    end

    # The generated page is the only place a rule count is written down, and it
    # is regenerated rather than typed. This asserts it has not drifted.
    it "has one row in the generated table for every registered rule" do
      rows = File.readlines("docs/detectors.md").count { |line| line.start_with?("| `") }

      expect(rows).to eq(Leakproof::Detectors::Registry.default.size)
    end
  end

  # The alphabet a rule declares was read by nothing for most of this project's
  # life, so it could be wrong on ten providers without anything noticing.
  describe "a rule's declared charset" do
    let(:hex_only) { "abcdef0123456789abcdef0123456789" }

    it "changes the entropy ceiling, so it cannot be decorative" do
      inferred = Leakproof::Detectors::Entropy::Shannon.normalized(hex_only)
      declared = Leakproof::Detectors::Entropy::Shannon.normalized(hex_only, charset: :base64)

      expect(inferred).to be > declared
    end

    it "is what the scorer uses, rather than re-inferring one from the sample" do
      rule = detector("aws-secret-access-key")
      candidate = candidate_for(rule, :well_formed, hex_only)

      expect(rule.charset).to eq(:base64)
      expect(described_class.call(candidate, []).score).to eq(
        Leakproof::Scoring::Confidence::BASE[rule.specificity] +
        Leakproof::Scoring::Confidence::VALIDITY[:well_formed]
      )
    end
  end

  # Tier assertions alone cannot see a changed weight, because a score can move
  # a long way inside one tier. These pin the arithmetic itself.
  describe "the scoring weights" do
    it "gives a corroborated random value exactly the low base plus the entropy bonus" do
      verdict = scanner.scan_text(%(api_key = "#{synth.base62(32)}"), path: "src/app.rb").first.verdict

      expect(verdict.score).to eq(
        Leakproof::Scoring::Confidence::BASE[:low] + Leakproof::Scoring::Confidence::ENTROPY_BONUS
      )
      expect(verdict.score).to eq(45)
    end

    it "gives a checksum-verified token the high base plus the verified weight" do
      verdict = scanner.scan_text(%(t = "#{synth.crc32_token("ghp_")}"), path: "src/app.rb").first.verdict

      expect(verdict.score).to eq(100)
    end
  end

  # The invariant the whole confidence tier rests on, driven through the real
  # scorer rather than recomputed from the same constants it is meant to guard.
  describe "the confirmed tier" do
    it "is unreachable for any rule without a proof, across the whole registry" do
      Leakproof::Detectors::Registry.default.each do |rule|
        %i[unknown well_formed malformed].each do |status|
          verdict = described_class.call(
            candidate_for(rule, status, synth.base62(40)), []
          )

          expect(verdict.tier).not_to eq(:confirmed),
                                      "#{rule.id} reached confirmed with validity #{status}"
        end
      end
    end
  end

  def candidate_for(rule, status, value)
    match = Leakproof::Detectors::Match.new(detector: rule, value: value, line: 1,
                                            column: 1, line_text: value)
    Leakproof::Scoring::Candidate.new(
      match: match, path: "src/app.rb",
      validity: Leakproof::Validity::Result.new(status)
    )
  end
end
