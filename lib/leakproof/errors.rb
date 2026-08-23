# frozen_string_literal: true

module Leakproof
  class Error < StandardError
  end

  class ConfigError < Error
  end

  class RepositoryError < Error
  end
end
