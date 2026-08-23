# frozen_string_literal: true

require_relative "charsets"

module Leakproof
  module Detectors
    module Entropy
      # Raw Shannon entropy is not comparable across alphabets or lengths, which is
      # why threshold-on-raw-bits makes entropy detection useless in practice.
      module Shannon
        module_function

        def bits(value)
          return 0.0 if value.nil? || value.empty?

          length = value.length.to_f
          value.each_char.tally.values.sum do |count|
            probability = count / length
            -probability * Math.log2(probability)
          end
        end

        # A 20-character string cannot exceed log2(20) bits however large its
        # alphabet, so the ceiling is whichever limit binds first.
        def ceiling(value, charset: nil)
          return 0.0 if value.nil? || value.length < 2

          charset ||= Charsets.classify(value)
          [Math.log2(Charsets.size(charset)), Math.log2(value.length)].min
        end

        def normalized(value, charset: nil)
          limit = ceiling(value, charset: charset)
          return 0.0 if limit <= 0

          (bits(value) / limit).clamp(0.0, 1.0)
        end
      end
    end
  end
end
