# frozen_string_literal: true

require "openssl"
require "json"
require "zlib"
require_relative "../detectors/entropy/charsets"
require_relative "../validity/base62"
require_relative "../validity/base64url"

module Leakproof
  module Bench
    # Builds structurally valid credentials from a shape, deterministically from
    # a seed. Nothing it produces was ever issued by a provider.
    #
    # It exists because detectors must not carry literal samples: a valid sample
    # committed to this repository is a secret committed to this repository, and
    # GitHub's own push protection will refuse it. Detectors declare the shape,
    # this builds the material, and the material never touches disk.
    class Synthesizer
      BASE62 = Detectors::Entropy::Charsets::BASE62
      BASE32 = Detectors::Entropy::Charsets::BASE32
      BASE64URL = Detectors::Entropy::Charsets::BASE64URL

      # Deliberately not Charsets::HEX. That one is a membership set and carries
      # both cases, so drawing from it would make a-f twice as likely as 0-9.
      HEX = "0123456789abcdef"
      DIGITS = "0123456789"

      def initialize(seed: 20_260_823)
        @random = Random.new(seed)
      end

      def base62(length) = pick(BASE62, length)
      def base32(length) = pick(BASE32, length)
      def hex(length) = pick(HEX, length)
      def digits(length) = pick(DIGITS, length)
      def base64url(length) = pick(BASE64URL, length)

      # The scheme GitHub and npm share: base62 entropy, then a base62 CRC32 of it.
      def crc32_token(prefix, entropy_length: 30)
        entropy = base62(entropy_length)
        "#{prefix}#{entropy}#{Validity::Base62.encode(Zlib.crc32(entropy))}"
      end

      def aws_key(prefix: "AKIA")
        "#{prefix}#{base32(16)}"
      end

      def rsa_key(bits: 1024)
        OpenSSL::PKey::RSA.new(bits).to_pem
      end

      def jwt(expires_at: 1_000_000_000, subject: "service-account")
        header = segment({ alg: "HS256", typ: "JWT" })
        payload = segment({ sub: subject, exp: expires_at })
        "#{header}.#{payload}.#{base64url(43)}"
      end

      private

      def segment(hash)
        Validity::Base64url.encode(JSON.generate(hash))
      end

      def pick(alphabet, length)
        Array.new(length) { alphabet[@random.rand(alphabet.length)] }.join
      end
    end
  end
end
