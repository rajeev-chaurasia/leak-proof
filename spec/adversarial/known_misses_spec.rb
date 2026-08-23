# frozen_string_literal: true

require "tmpdir"

# docs/known-misses.md, executed.
#
# A published list of gaps is worth nothing if it drifts. Every claim on that
# page is asserted here, so closing a gap fails this suite and forces the page
# to be rewritten alongside the fix.
RSpec.describe "documented gaps" do
  let(:scanner) { Leakproof::Scanner.new }
  let(:synth) { Leakproof::Bench::Synthesizer.new }
  let(:token) { synth.crc32_token("ghp_") }

  def tiers(content, path: "app/config.rb")
    scanner.scan_text(content, path: path).map(&:tier).reject { |tier| tier == :ignore }
  end

  describe "by design" do
    it "never confirms an AWS access key, because the format carries no checksum" do
      expect(tiers(%(key = "#{synth.aws_key}"))).to eq([:probable])
    end

    it "never confirms a Stripe secret key" do
      expect(tiers(%(key = "sk_live_#{synth.base62(24)}"))).to eq([:probable])
    end
  end

  describe "the entropy rule's bounds" do
    it "misses a credential shorter than twenty-four characters" do
      expect(tiers(%(value = "#{synth.base62(18)}"))).to be_empty
    end

    it "misses a credential longer than one hundred and twenty characters" do
      expect(tiers(%(value = "#{synth.base62(200)}"))).to be_empty
    end

    it "misses a hex-encoded secret with no provider prefix" do
      expect(tiers(%(value = "#{synth.hex(40)}"))).to be_empty
    end

    it "misses a secret drawn from a single character class" do
      expect(tiers(%(value = "#{synth.base32(32)}"))).to be_empty
    end
  end

  describe "structural" do
    it "misses a credential split across source lines" do
      split = %(T = "#{token[0, 20]}" \\\n  "#{token[20..]}")

      expect(tiers(split)).to be_empty
    end

    it "skips a binary blob" do
      source = Leakproof::Scanner::Source.new(path: "a.png", content: "\x00#{token}", oid: nil)

      expect(scanner.scan([source])).to be_empty
    end
  end

  describe "verified as not missed" do
    def repo_tiers(mode, &)
      Dir.mktmpdir("leakproof-gap") do |dir|
        repo = RepoBuilder.new(dir)
        repo.init
        yield repo
        findings = scanner.scan(Leakproof::Sources.from_repository(dir, mode: mode))
        findings.select(&:confirmed?).map(&:tier)
      end
    end

    it "finds a secret committed and later deleted" do
      result = repo_tiers(:reachable) do |repo|
        repo.commit("Add config", "config/app.rb" => %(T = "#{token}"\n))
        repo.delete("config/app.rb")
        repo.commit("Remove config")
      end

      expect(result).to eq([:confirmed])
    end

    it "finds a secret in a stash, which refs/stash keeps reachable" do
      result = repo_tiers(:reachable) do |repo|
        repo.commit("Initial", "README.md" => "hello\n")
        repo.write("config/app.rb", %(T = "#{token}"\n))
        repo.git("add", "--all")
        repo.git("stash", "--quiet")
      end

      expect(result).to eq([:confirmed])
    end

    it "surfaces a base64-wrapped credential only when a name corroborates it" do
      wrapped = [token].pack("m0")

      expect(tiers(%(x = "#{wrapped}"))).to be_empty
      expect(tiers(%(api_key = "#{wrapped}"))).to eq([:probable])
    end
  end
end
