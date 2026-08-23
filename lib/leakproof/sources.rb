# frozen_string_literal: true

require_relative "git/plumbing_backend"
require_relative "git/rugged_backend"
require_relative "scanner"

module Leakproof
  # Adapts the git layer into the plain (path, content) pairs the scanner wants.
  # This is the only place the two halves of the project meet.
  module Sources
    BACKENDS = { plumbing: Git::PlumbingBackend, rugged: Git::RuggedBackend }.freeze

    module_function

    def from_repository(path, mode: :reachable, backend: :plumbing, max_blob_bytes: nil)
      klass = BACKENDS.fetch(backend) { raise ConfigError, "unknown backend: #{backend}" }
      options = max_blob_bytes ? { max_blob_bytes: max_blob_bytes } : {}
      reader = klass.new(path, **options)
      raise ConfigError, "the #{backend} backend is unavailable" unless reader.available?

      reader.each_blob(mode: mode).map do |blob|
        Scanner::Source.new(path: blob.path, content: blob.content, oid: blob.oid)
      end
    end

    # What the pre-commit hook sees: staged content only, never the working tree,
    # because the working tree is not what is about to be committed.
    def from_staged(path = ".")
      names = git(path, "diff", "--cached", "--name-only", "--diff-filter=ACMR").split("\n")
      names.filter_map do |name|
        content = git(path, "show", ":#{name}")
        Scanner::Source.new(path: name, content: content, oid: nil)
      rescue RepositoryError
        nil
      end
    end

    def from_paths(paths)
      paths.filter_map do |file|
        next unless File.file?(file)

        Scanner::Source.new(path: file, content: File.binread(file), oid: nil)
      end
    end

    def git(path, *args)
      output = IO.popen(["git", "-C", path, *args], "rb", &:read)
      raise RepositoryError, "git #{args.join(" ")} failed" unless $CHILD_STATUS.success?

      output
    end
  end
end
