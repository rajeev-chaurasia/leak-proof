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
  it "treats an encrypted PKCS#8 key as a real key" do
    result = strategy.check(SampleSecrets.encrypted_private_key)

    expect(result).to be_verified
    expect(result.detail[:encrypted]).to eq(:pkcs8)
  end

  it "treats a traditional encrypted key as a real key" do
    result = strategy.check(SampleSecrets.traditional_encrypted_private_key)

    expect(result).to be_verified
    expect(result.detail[:encrypted]).to eq(:traditional)
  end

  # The header alone used to be enough, so a four-character stub in a spec file
  # reached the confirmed tier. leakproof found this one in its own history.
  it "refuses an encrypted envelope with nothing inside it" do
    marker = "ENCRYPTED PRIVATE KEY"
    stub = "-----BEGIN #{marker}-----\nMIIB\n-----END #{marker}-----\n"

    expect(strategy.check(stub)).to be_malformed
  end
end
