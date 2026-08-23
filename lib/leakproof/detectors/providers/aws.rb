# frozen_string_literal: true

require_relative "../registry"
require_relative "../../validity/aws_account"
require_relative "../../validity/contract"

Leakproof::Detectors::Registry.register(
  Leakproof::Detectors::Detector.new(
    id: "aws-access-key-id",
    name: "AWS access key ID",
    pattern: /\b((?:AKIA|ASIA|AIDA|AROA|AGPA|AIPA|ANPA|ANVA|APKA)[A-Z2-7]{16})\b/,
    capture: 1,
    charset: :base32,
    validity: Leakproof::Validity::AwsAccount.new,
    specificity: :high,
    sample: ->(s) { s.aws_key },
    notes: "Decodes to the owning account ID offline. No checksum exists in this format.",
    examples: {
      positive: [],
      negative: %w[AKIA1111111111111111 NOTAKEYATALLHERE0000]
    }
  )
)

Leakproof::Detectors::Registry.register(
  Leakproof::Detectors::Detector.new(
    id: "aws-secret-access-key",
    name: "AWS secret access key",
    pattern: %r{(?i:aws)?_?(?i:secret)_?(?i:access)?_?(?i:key)\s*[:=]\s*["']?([A-Za-z0-9/+=]{40})["']?},
    capture: 1,
    charset: :base64,
    validity: Leakproof::Validity::Contract.new(length: 40, charset: :base64),
    specificity: :medium,
    entropy_bonus: true,
    sample: ->(s) { "aws_secret_access_key = #{s.base62(40)}" },
    notes: "No checksum and no structure. Only the assignment context distinguishes it.",
    examples: {
      positive: [],
      negative: ["aws_secret_access_key = tooshort", "unrelated_field = kD9xQ2mVbN7pLzR4"],
      suppressed: ["aws_secret_access_key = ${AWS_SECRET}"]
    }
  )
)
