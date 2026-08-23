# frozen_string_literal: true

require "English"
require_relative "backend"
require_relative "blob"

module Leakproof
  module Git
    # Enumerates blobs by driving git's own plumbing. No native extension, so the
    # pre-commit hook and the Action run anywhere git already exists.
    class PlumbingBackend < Backend
      BATCH_CHECK_FORMAT = "%(objectname) %(objecttype) %(objectsize)"

      def each_blob(mode: :reachable)
        return enum_for(:each_blob, mode: mode) unless block_given?
        raise ArgumentError, "unknown mode: #{mode}" unless MODES.include?(mode)

        paths = mode == :reachable ? reachable_paths : {}
        stream(catalog(mode)) do |oid, size, content|
          yield Blob.new(oid: oid, size: size, path: paths[oid], content: content)
        end
      end

      def repository?
        run("rev-parse", "--git-dir")
        true
      rescue CommandError
        false
      end

      private

      def catalog(mode)
        rows = mode == :all_objects ? all_object_rows : reachable_rows
        rows.filter_map do |line|
          oid, type, size = line.split
          next unless type == "blob"

          size = size.to_i
          [oid, size] if include_blob?(size)
        end
      end

      def all_object_rows
        run("cat-file", "--batch-all-objects", "--batch-check=#{BATCH_CHECK_FORMAT}").lines
      end

      def reachable_rows
        oids = reachable_paths.keys
        return [] if oids.empty?

        batch_check(oids)
      end

      def reachable_paths
        @reachable_paths ||= begin
          paths = {}
          run("rev-list", "--all", "--objects").each_line do |line|
            oid, path = line.chomp.split(" ", 2)
            next if oid.nil? || oid.empty?

            paths[oid] ||= path
          end
          paths
        end
      end

      def batch_check(oids)
        rows = []
        IO.popen(argv("cat-file", "--batch-check=#{BATCH_CHECK_FORMAT}"), "r+") do |io|
          oids.each do |oid|
            io.write("#{oid}\n")
            io.flush
            line = io.gets
            rows << line if line
          end
          io.close_write
        end
        rows
      end

      def stream(entries)
        return if entries.empty?

        IO.popen(argv("cat-file", "--batch"), "rb+") do |io|
          io.binmode
          entries.each do |entry|
            oid = entry.first
            io.write("#{oid}\n")
            io.flush
            read_framed(io) { |type, size, body| yield oid, size, body if type == "blob" }
          end
          io.close_write
        end
      end

      # The batch protocol frames each body by byte count. Reading to a newline would
      # truncate every blob that contains one, which is nearly all of them.
      def read_framed(io)
        header = io.gets
        return if header.nil?

        _oid, type, declared = header.split
        return if type.nil? || type == "missing"

        size = declared.to_i
        body = io.read(size).to_s
        io.read(1)
        yield type, size, body
      end

      def run(*args)
        output = IO.popen(argv(*args), "rb", &:read)
        raise CommandError, "git #{args.join(" ")} failed" unless $CHILD_STATUS.nil? || $CHILD_STATUS.success?

        output
      end

      def argv(*args)
        ["git", "-C", path, *args]
      end

      class CommandError < StandardError; end
    end
  end
end
