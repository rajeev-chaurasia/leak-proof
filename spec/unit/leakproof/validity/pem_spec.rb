# frozen_string_literal: true

RSpec.describe Leakproof::Validity::Pem do
  subject(:strategy) { described_class.new }

  it "verifies a key whose DER actually parses" do
    result = strategy.check(SampleSecrets.private_key)

    expect(result).to be_verified
    expect(result.detail[:bits]).to eq(1024)
  end

  it "rejects an envelope wrapped around content that is not a key" do
    marker = "RSA PRIVATE KEY"
    envelope = "-----BEGIN #{marker}-----\nbm90IGEga2V5\n-----END #{marker}-----\n"

    expect(strategy.check(envelope)).to be_rejected
  end

  it "reports a missing envelope as malformed rather than rejected" do
    expect(strategy.check("just some text")).to be_malformed
  end

  # Refusing to guess a passphrase is not the same as failing to recognise a key.
  it "treats an encrypted key as a real key" do
    marker = "ENCRYPTED PRIVATE KEY"
    encrypted = "-----BEGIN #{marker}-----\nMIIB\n-----END #{marker}-----\n"
    result = strategy.check(encrypted)

    expect(result).to be_verified
    expect(result.detail[:encrypted]).to be(true)
  end
end
