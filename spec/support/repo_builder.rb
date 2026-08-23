# frozen_string_literal: true

require "English"

require "fileutils"
require "tmpdir"

# Builds throwaway git repositories so history-shape behaviour can be asserted
# rather than assumed.
class RepoBuilder
  attr_reader :path

  ENVIRONMENT = {
    "GIT_AUTHOR_NAME" => "Test", "GIT_AUTHOR_EMAIL" => "test@example.com",
    "GIT_COMMITTER_NAME" => "Test", "GIT_COMMITTER_EMAIL" => "test@example.com",
    "GIT_CONFIG_GLOBAL" => "/dev/null", "GIT_CONFIG_SYSTEM" => "/dev/null"
  }.freeze

  def self.build(&block)
    dir = Dir.mktmpdir("leakproof-repo")
    builder = new(dir)
    builder.init
    block&.call(builder)
    builder
  end

  def initialize(path)
    @path = path
  end

  def init
    git("init", "--quiet", "--initial-branch=main")
  end

  def write(relative, content)
    absolute = File.join(path, relative)
    FileUtils.mkdir_p(File.dirname(absolute))
    File.binwrite(absolute, content)
    self
  end

  def commit(message, files = {})
    files.each { |relative, content| write(relative, content) }
    git("add", "--all")
    git("commit", "--quiet", "--allow-empty", "-m", message)
    self
  end

  def amend(message, files = {})
    files.each { |relative, content| write(relative, content) }
    git("add", "--all")
    git("commit", "--quiet", "--amend", "-m", message)
    self
  end

  def delete(relative)
    git("rm", "--quiet", relative)
    self
  end

  def head
    git("rev-parse", "HEAD").strip
  end

  def destroy
    FileUtils.remove_entry(path) if File.directory?(path)
  end

  def git(*args)
    output = IO.popen(ENVIRONMENT, ["git", "-C", path, *args], "rb", &:read)
    raise "git #{args.join(" ")} failed" unless $CHILD_STATUS.success?

    output
  end
end
