# frozen_string_literal: true

require "digest"

module Leakproof
  module Git
    Blob = Struct.new(:oid, :size, :path, :content, keyword_init: true) do
      def content_sha
        Digest::SHA256.hexdigest(content.to_s)
      end

      def binary?
        content.to_s.byteslice(0, 8000).to_s.include?("\x00")
      end

      def text
        content.to_s.dup.force_encoding(Encoding::UTF_8).scrub("")
      end

      def identity
        [oid, size, content_sha]
      end
    end
  end
end
