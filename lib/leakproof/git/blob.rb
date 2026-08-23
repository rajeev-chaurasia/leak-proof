# frozen_string_literal: true

require "digest"

module Leakproof
  module Git
    # A blob as the scanner sees it: bytes, plus enough provenance to report on.
    class Blob
      attr_reader :oid, :size, :path, :content

      def initialize(oid:, size:, content:, path: nil)
        @oid = oid
        @size = size
        @path = path
        @content = content
        freeze
      end

      # Not memoized, because the object is frozen and this is off the hot path:
      # only #identity asks for it, which the differential spec compares.
      def content_sha
        Digest::SHA256.hexdigest(content.to_s)
      end

      def binary?
        content.to_s.byteslice(0, 8000).to_s.include?("\x00")
      end

      def text
        content.to_s.dup.force_encoding(Encoding::UTF_8).scrub("")
      end

      # What the differential spec compares. Deliberately excludes path, since
      # a blob reachable at two paths is still the same bytes.
      def identity
        [oid, size, content_sha]
      end

      def ==(other)
        other.is_a?(Blob) && identity == other.identity
      end
      alias eql? ==

      def hash
        identity.hash
      end
    end
  end
end
