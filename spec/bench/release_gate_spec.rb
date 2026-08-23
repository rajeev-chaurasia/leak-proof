# frozen_string_literal: true

require "tmpdir"

# The release gate. One number must be perfect and the rest are reported
# honestly: precision at the confirmed tier admits no false positive, ever.
# Recall is allowed to be below one, and every miss is named in the summary.
RSpec.describe "the release gate" do
  result = nil

  before(:all) do
    Dir.mktmpdir("leakproof-bench") do |root|
      result = Leakproof::Bench::Runner.new.call(File.join(root, "recall"))
    end
  end

  let(:filtered) { result[:filtered] }
  let(:unfiltered) { result[:unfiltered] }

  it "plants a credential for every registered rule that declares a shape" do
    expect(result[:planted]).to be >= 20
  end

  it "reports no false positive at any tier" do
    expect(filtered[:false_positives]).to eq(0), -> { filtered[:spurious].inspect }
  end

  it "reaches perfect precision" do
    expect(filtered[:precision]).to eq(1.0)
  end

  it "finds every credential planted in source or deleted from it" do
    expect(filtered[:false_negatives]).to eq(0), -> { filtered[:missed].inspect }
  end

  it "confirms only what a checksum or a key parse can prove" do
    expect(filtered[:confirmed]).to be_positive
    expect(filtered[:confirmed]).to be < filtered[:true_positives]
  end

  it "never confirms a credential sitting under a fixture or documentation path" do
    demoted, total = filtered[:demoted].split("/")

    expect(demoted).to eq(total)
  end

  it "never reports a credential type that is public by design" do
    ignored, total = filtered[:public_types_ignored].split("/")

    expect(ignored).to eq(total)
  end

  # The differentiator, measured on the same corpus rather than asserted.
  it "removes every false positive the filter exists to remove" do
    expect(unfiltered[:false_positives]).to be_positive
    expect(filtered[:false_positives]).to eq(0)
  end

  it "finds a secret that was committed and later deleted" do
    deleted = filtered[:by_rule].values.sum { |stats| stats[:found] }

    expect(deleted).to eq(filtered[:true_positives])
  end
end
