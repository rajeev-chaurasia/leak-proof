# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "rake", "~> 13.2"

group :development, :test do
  gem "rspec", "~> 3.13"
  gem "rubocop", "~> 1.66"
  gem "rubocop-rspec", "~> 3.1"
  gem "simplecov", "~> 0.22"
end

# Optional accelerated git backend. Absent by default so the pre-commit hook
# and the Action never require a native build.
group :rugged do
  gem "rugged", "~> 1.7", require: false
end
