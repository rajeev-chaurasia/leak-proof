# frozen_string_literal: true

RSpec.describe Leakproof::Detectors::Entropy::EntropyDetector do
  subject(:detector) { described_class.new }

  let(:synth) { Leakproof::Bench::Synthesizer.new }

  it "reports a drawn token" do
    expect(detector.scan(%(k = "#{synth.base62(32)}")).count).to eq(1)
  end

  it "ignores a hex digest, because at this length hex is a checksum" do
    expect(detector.scan(%(sha = "3d59a50f177d77ce013625030ba8dba906f75696")).count).to eq(0)
  end

  it "ignores an alphabet constant" do
    expect(detector.scan(%(ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")).count).to eq(0)
  end

  it "ignores a blob too long to be a credential" do
    expect(detector.scan(%(dump = "#{synth.base62(400)}")).count).to eq(0)
  end

  it "ignores a value too short to carry a credential" do
    expect(detector.scan(%(k = "#{synth.base62(12)}")).count).to eq(0)
  end

  # Quoted-string extraction used to capture interpolations and code fragments,
  # which are punctuation-rich and so score high while containing nothing.
  it "ignores a code fragment that merely sits inside quotes" do
    expect(detector.scan(%(msg = "${VERSION}-build (2, x)")).count).to eq(0)
  end
end
