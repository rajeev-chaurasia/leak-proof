# frozen_string_literal: true

RSpec.describe Leakproof::Scoring::Fingerprint do
  it "does not depend on a commit" do
    a = described_class.call(detector_id: "github-pat", path: "src/a.rb", value: "x")
    b = described_class.call(detector_id: "github-pat", path: "src/a.rb", value: "x")

    expect(a).to eq(b)
  end

  it "changes when the rule, the path or the value changes" do
    base = described_class.call(detector_id: "github-pat", path: "src/a.rb", value: "x")

    expect(described_class.call(detector_id: "npm-access-token", path: "src/a.rb",
                                value: "x")).not_to eq(base)
    expect(described_class.call(detector_id: "github-pat", path: "src/b.rb", value: "x")).not_to eq(base)
    expect(described_class.call(detector_id: "github-pat", path: "src/a.rb", value: "y")).not_to eq(base)
  end

  it "ignores a leading current-directory prefix" do
    expect(described_class.call(detector_id: "r", path: "./src/a.rb", value: "x"))
      .to eq(described_class.call(detector_id: "r", path: "src/a.rb", value: "x"))
  end

  # The concrete bug this design exists to fix: a force-push orphans the commit a
  # gitleaks fingerprint is built from, and an already-triaged finding returns as
  # new. Content and path survive the rewrite.
  describe "across a history rewrite" do
    let(:secret) { SampleSecrets.github }
    let(:scanner) { Leakproof::Scanner.new }

    def fingerprints(repo)
      backend = Leakproof::Git::PlumbingBackend.new(repo.path)
      sources = backend.each_blob(mode: :reachable).map do |blob|
        Leakproof::Scanner::Source.new(path: blob.path, content: blob.content, oid: blob.oid)
      end
      scanner.scan(sources).select(&:confirmed?).map(&:fingerprint)
    end

    it "reports the same fingerprint before and after an amend" do
      repo = RepoBuilder.build { |r| r.commit("Add config", "src/config.rb" => %(TOKEN = "#{secret}"\n)) }
      before = fingerprints(repo)

      repo.amend("Add config with a better message", "src/other.rb" => "unrelated\n")
      after = fingerprints(repo)

      expect(before).not_to be_empty
      expect(after).to eq(before)
      repo.destroy
    end
  end
end
