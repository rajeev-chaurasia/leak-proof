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

        return encrypted_result(value) if encrypted?(value)

        parse(value)
      end

      private

      # An encrypted key is still a real key, but the header alone proves nothing:
      # this returned :verified for any string carrying the marker, so a
      # four-character stub in a test file reached the confirmed tier. The
      # passphrase is unknowable here, the DER structure underneath is not.
      def encrypted_result(value)
        return Result.new(:verified, encrypted: :pkcs8) if der_structure?(value)
        return Result.new(:verified, encrypted: :traditional) if traditional_headers?(value)

        Result.new(:malformed, reason: "encrypted PEM envelope with no parsable structure")
      end

      # A traditional encrypted PEM body is raw ciphertext rather than DER, so
      # there is nothing to parse. Its two headers plus a body of real size are
      # what distinguishes it from a stub.
      def traditional_headers?(value)
        return false unless value.include?("Proc-Type: 4,ENCRYPTED") && value.include?("DEK-Info:")

        body_bytes(value).to_s.bytesize >= 48
      end

      def der_structure?(value)
        decoded = body_bytes(value)
        return false if decoded.nil? || decoded.bytesize < 48

        OpenSSL::ASN1.decode(decoded).is_a?(OpenSSL::ASN1::Sequence)
      rescue ArgumentError, OpenSSL::ASN1::ASN1Error
        false
      end

      def body_bytes(value)
        body = value.lines.reject { |line| line.start_with?("-----", "Proc-Type", "DEK-Info") }.join
        body.unpack1("m")
      rescue ArgumentError
        nil
      end

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
