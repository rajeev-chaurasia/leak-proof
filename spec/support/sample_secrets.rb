# frozen_string_literal: true

require "openssl"
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

  # Both encrypted forms: PKCS#8 keeps a DER structure under the encryption,
  # while a traditional PEM body is raw ciphertext with two extra headers.
  def encrypted_private_key
    @encrypted_private_key ||=
      OpenSSL::PKey::RSA.new(private_key).private_to_pem(cipher, "passphrase")
  end

  def traditional_encrypted_private_key
    @traditional_encrypted_private_key ||=
      OpenSSL::PKey::RSA.new(private_key).to_pem(cipher, "passphrase")
  end

  def cipher
    OpenSSL::Cipher.new("aes-256-cbc")
  end
end
