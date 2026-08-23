# frozen_string_literal: true

require "set"
require_relative "backend"
require_relative "blob"

module Leakproof
  module Git
    # A second, independent implementation over libgit2. It exists to be the oracle
    # in the differential spec, not as a user-facing option.
    class RuggedBackend < Backend
      def self.available?
        return @available if defined?(@available)

        @available = begin
          require "rugged"
          true
        rescue LoadError
          false
        end
      end

      def available?
        self.class.available?
      end

      def each_blob(mode: :reachable)
        return enum_for(:each_blob, mode: mode) unless block_given?
        raise ArgumentError, "unknown mode: #{mode}" unless MODES.include?(mode)
        raise LoadError, "rugged is not installed" unless available?

        entries = mode == :all_objects ? all_object_entries : reachable_entries
        entries.each do |oid, blob_path|
          object = repo.lookup(oid)
          next unless object.type == :blob
          next unless include_blob?(object.size)

          yield Blob.new(oid: oid, size: object.size, path: blob_path, content: object.content)
        end
      end

      private

      def repo
        @repo ||= Rugged::Repository.new(path)
      end

      def reachable_entries
        entries = {}
        seen_trees = Set.new
        each_commit do |commit|
          tree = commit.tree
          next unless seen_trees.add?(tree.oid)

          tree.walk_blobs(:preorder) do |root, entry|
            entries[entry[:oid]] ||= "#{root}#{entry[:name]}"
          end
        end
        entries
      end

      def all_object_entries
        entries = {}
        repo.each_id { |oid| entries[oid] = nil }
        entries
      end

      def each_commit
        walker = Rugged::Walker.new(repo)
        pushed = false
        repo.refs.each do |ref|
          oid = commit_oid(ref)
          next unless oid

          walker.push(oid)
          pushed = true
        end
        return unless pushed

        walker.each { |commit| yield commit }
      end

      def commit_oid(ref)
        object = repo.lookup(ref.target_id)
        object = repo.lookup(object.target_id) while object.type == :tag
        object.type == :commit ? object.oid : nil
      rescue Rugged::Error, Rugged::OdbError, Rugged::InvalidError
        nil
      end
    end
  end
end
