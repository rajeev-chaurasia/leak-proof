# frozen_string_literal: true

require "rspec/core/rake_task"
require "rubocop/rake_task"

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new(:rubocop)

desc "Check prose for em-dashes and tool attribution"
task :prose do
  ruby "script/check_prose.rb"
end

desc "Check that every repo-relative markdown link resolves"
task :links do
  ruby "script/check_links.rb"
end

desc "Scan the tracked tree with the project's own detectors"
task :selfscan do
  ruby "script/check_no_samples.rb"
end

desc "Verify the generated detector table matches the registry"
task :docs do
  ruby "script/generate_docs.rb --check"
end

desc "Verify the layering rule: detection must not reach into git"
task :layering do
  ruby "script/check_layering.rb"
end

task default: %i[rubocop prose links layering docs selfscan spec]
