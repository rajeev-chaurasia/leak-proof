# frozen_string_literal: true

RSpec.describe Leakproof::Validity::AwsAccount do
  subject(:strategy) { described_class.new }

  # Published test vector from psanford/aws-account-id-from-key. AWS keys carry
  # no checksum, so this is the strongest offline statement the format allows.
  it "derives the owning account ID without contacting AWS" do
    result = strategy.check(PublishedVectors.aws_key)

    expect(result).to be_well_formed
    expect(result.detail[:account_id]).to eq(PublishedVectors::AWS_ACCOUNT_ID)
  end

  it "reports the key type prefix" do
    expect(strategy.check(PublishedVectors.aws_key).detail[:prefix]).to eq(PublishedVectors::AWS_PREFIX)
  end

  # Whether a well-formed key is a documented dummy is the filter's question.
  # This layer only answers whether the format holds.
  it "still reports a documentation key as well formed, leaving dismissal to the filter" do
    expect(strategy.check(PublishedVectors.aws_documentation_key)).to be_well_formed
  end

  it "refuses a body containing characters outside the base32 alphabet" do
    expect(strategy.check("AKIA0189#{"O" * 12}")).to be_malformed
  end

  it "refuses an unknown prefix" do
    expect(strategy.check("XXXX#{PublishedVectors::AWS_BODY}")).to be_malformed
  end

  it "refuses the wrong length" do
    expect(strategy.check("AKIASHORT")).to be_malformed
  end

  it "never claims a proof it does not have" do
    expect(strategy.check(PublishedVectors.aws_key)).not_to be_verified
  end
end
