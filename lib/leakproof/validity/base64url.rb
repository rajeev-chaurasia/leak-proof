# frozen_string_literal: true

module Leakproof
  module Validity
    # Core pack/unpack rather than the base64 gem, which left the default gems in
    # Ruby 3.4. A scanner with no runtime dependencies has no supply chain.
    module Base64url
      module_function

      def decode(segment)
        normalized = segment.tr("-_", "+/")
        normalized += "=" * ((4 - (normalized.length % 4)) % 4)
        normalized.unpack1("m")
      end

      def encode(data)
        [data].pack("m0").tr("+/", "-_").delete("=")
      end
    end
  end
end
