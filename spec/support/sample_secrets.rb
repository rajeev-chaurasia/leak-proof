# frozen_string_literal: true

# Every credential the suite needs is built here at run time. Nothing that looks
# like a credential is committed, which is why this repository can be pushed to
# GitHub at all: push protection rejects a valid sample exactly as it should.
module SampleSecrets
  module_function

  def synthesizer
    @synthesizer ||= Leakproof::Bench::Synthesizer.new
  end

  def github(prefix: "ghp_") = synthesizer.crc32_token(prefix)
  def npm = synthesizer.crc32_token("npm_")
  def aws_key(prefix: "AKIA") = synthesizer.aws_key(prefix: prefix)
  def jwt(expires_at: 1_000_000_000) = synthesizer.jwt(expires_at: expires_at)

  def private_key
    @private_key ||= synthesizer.rsa_key
  end
end
