# frozen_string_literal: true

RSpec.describe Leakproof::Detectors::Detector do
  let(:registry) { Leakproof::Detectors::Registry.default }

  it "reports the line a match was found on" do
    text = "harmless\nharmless\naws_key = #{PublishedVectors.aws_key}\n"
    match = registry["aws-access-key-id"].scan(text).first

    expect(match.line).to eq(3)
  end

  # A PEM block spans lines, so its start has to be translated back to one.
  it "reports the starting line of a multi-line match" do
    text = "first\nsecond\n#{SampleSecrets.private_key}"
    match = registry["private-key"].scan(text).first

    expect(match.line).to eq(3)
  end

  it "redacts the middle of a value for reporting" do
    match = registry["aws-access-key-id"].scan(PublishedVectors.aws_key).first

    expect(match.redacted).to eq("#{PublishedVectors::AWS_PREFIX}#{"*" * 12}#{PublishedVectors::AWS_BODY[-4..]}")
  end

  it "marks a Stripe publishable key as not a secret" do
    expect(registry["stripe-publishable-key"].secret?).to be(false)
    expect(registry["stripe-secret-key"].secret?).to be(true)
  end

  it "finds every occurrence on a line" do
    text = "a=#{SampleSecrets.aws_key} b=#{PublishedVectors.aws_key}"

    expect(registry["aws-access-key-id"].scan(text).count).to eq(2)
  end
end
