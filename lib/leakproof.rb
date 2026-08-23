# frozen_string_literal: true

require_relative "leakproof/version"
require_relative "leakproof/errors"
require_relative "leakproof/git/backend"
require_relative "leakproof/git/blob"
require_relative "leakproof/git/plumbing_backend"
require_relative "leakproof/git/rugged_backend"
require_relative "leakproof/validity/result"
require_relative "leakproof/validity/strategy"
require_relative "leakproof/validity/base62"
require_relative "leakproof/validity/crc32_base62"
require_relative "leakproof/validity/pem"
require_relative "leakproof/validity/base64url"
require_relative "leakproof/validity/jwt"
require_relative "leakproof/validity/aws_account"
require_relative "leakproof/validity/contract"
require_relative "leakproof/detectors/entropy/charsets"
require_relative "leakproof/detectors/entropy/shannon"
require_relative "leakproof/detectors/entropy/candidate_extractor"
require_relative "leakproof/detectors/entropy/entropy_detector"
require_relative "leakproof/detectors/registry"
require_relative "leakproof/filter/known_dummies"
require_relative "leakproof/bench/synthesizer"

module Leakproof
end
