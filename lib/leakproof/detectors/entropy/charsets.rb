# frozen_string_literal: true

module Leakproof
  module Detectors
    module Entropy
      # Membership sets for entropy scoring and the validity contracts, so a
      # detector cannot accept a character its entropy model has never heard of.
      #
      # Deliberately not shared with Validity::Base62 or Validity::AwsAccount:
      # there the order of the alphabet is load-bearing (positional digit value
      # for CRC32, RFC 4648 index for base32), and here it is incidental.
      module Charsets
        HEX = "0123456789abcdefABCDEF"
        BASE32 = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
        BASE62 = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
        BASE64 = "#{BASE62}+/=".freeze
        BASE64URL = "#{BASE62}-_".freeze

        SIZES = {
          hex: 16,
          base32: 32,
          base62: 62,
          base64: 64,
          base64url: 64
        }.freeze

        MEMBERS = {
          hex: HEX,
          base32: BASE32,
          base62: BASE62,
          base64: BASE64,
          base64url: BASE64URL
        }.freeze

        module_function

        def size(name)
          SIZES.fetch(name) { raise ArgumentError, "unknown charset: #{name}" }
        end

        def matches?(name, value)
          allowed = MEMBERS.fetch(name) { raise ArgumentError, "unknown charset: #{name}" }
          !value.empty? && value.each_char.all? { |c| allowed.include?(c) }
        end

        # Narrowest alphabet the value fits inside. Order matters: hex is a subset
        # of base62, so the cheapest classification has to be tried first.
        def classify(value)
          %i[hex base32 base62 base64url base64].find { |name| matches?(name, value) } || :base64
        end
      end
    end
  end
end
