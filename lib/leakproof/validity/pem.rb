# frozen_string_literal: true

require "openssl"
require_relative "strategy"

module Leakproof
  module Validity
    # A private key is the one credential type that can be checked completely
    # offline: either the DER underneath parses as a key, or it does not.
    class Pem < Strategy
      ENCRYPTED_MARKERS = ["Proc-Type: 4,ENCRYPTED", "BEGIN ENCRYPTED PRIVATE KEY"].freeze

      def describes
        "ASN.1 key parse"
      end

      def check(value)
        return Result.new(:malformed, reason: "no PEM envelope") unless value.include?("-----BEGIN")

        # An encrypted key is still a real key. Refusing to guess the passphrase
        # is not the same as failing to recognise one.
        return Result.new(:verified, encrypted: true) if encrypted?(value)

        parse(value)
      end

      private

      def encrypted?(value)
        ENCRYPTED_MARKERS.any? { |marker| value.include?(marker) }
      end

      def parse(value)
        key = read_key(value)
        return Result.new(:verified, algorithm: key.oid, bits: bit_length(key)) if key

        Result.new(:rejected, reason: "PEM envelope does not contain a parsable key")
      end

      # A key arrives escaped when it is embedded in JSON or a .env line, and
      # indented when it sits in a YAML literal block. OpenSSL accepts neither.
      def read_key(value)
        unescaped = value.gsub("\\n", "\n").gsub("\\r", "\r")
        candidates = [value, unescaped].flat_map { |form| [form, dedent(form)] }.uniq
        candidates.each do |candidate|
          return OpenSSL::PKey.read(candidate)
        rescue OpenSSL::PKey::PKeyError, ArgumentError
          next
        end
        nil
      end

      def dedent(form)
        form.lines.map(&:lstrip).join
      end

      def bit_length(key)
        key.respond_to?(:n) && key.n ? key.n.num_bits : nil
      rescue StandardError
        nil
      end
    end
  end
end
