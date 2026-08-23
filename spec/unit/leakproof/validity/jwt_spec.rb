# frozen_string_literal: true

RSpec.describe Leakproof::Validity::Jwt do
  subject(:strategy) { described_class.new }

  # Decoding is not proof. Nothing here checks a signature, so the strongest
  # honest answer is that the token is well formed.
  it "decodes the header and payload offline without claiming a proof" do
    result = strategy.check(SampleSecrets.jwt)

    expect(result).to be_well_formed
    expect(result).not_to be_verified
    expect(result.detail[:algorithm]).to eq("HS256")
    expect(result.detail[:subject]).to eq("service-account")
  end

  it "settles expiry without asking the issuer" do
    expect(strategy.check(SampleSecrets.jwt(expires_at: 1_000_000_000)).detail[:expired]).to be(true)
    expect(strategy.check(SampleSecrets.jwt(expires_at: 4_000_000_000)).detail[:expired]).to be(false)
  end

  it "requires three segments" do
    expect(strategy.check("eyJhbGciOiJIUzI1NiJ9.payload")).to be_malformed
  end

  it "requires segments that decode to JSON" do
    expect(strategy.check("eyJhbGciOiJ.bm90anNvbg.sig")).to be_malformed
  end
end
