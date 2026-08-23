# frozen_string_literal: true

require "optparse"
require_relative "../leakproof"
require_relative "report/json_report"
require_relative "report/sarif"
require_relative "report/text"
require_relative "sources"

module Leakproof
  class CLI
    FORMATS = { "text" => Report::Text, "json" => Report::JsonReport, "sarif" => Report::Sarif }.freeze
    TIERS = %w[confirmed probable ignore].freeze

    EXIT_OK = 0
    EXIT_FINDINGS = 1
    EXIT_USAGE = 2

    def self.run(argv, io: $stdout, err: $stderr)
      new(io: io, err: err).run(argv)
    end

    def initialize(io: $stdout, err: $stderr)
      @io = io
      @err = err
      @options = { mode: :reachable, backend: :plumbing, format: "text",
                   show: "probable", fail_on: "confirmed", staged: false }
    end

    class Done < StandardError
    end

    def run(argv)
      paths = parser.parse(argv.dup)
      findings = scan(paths.first || ".")
      render(visible(findings))
      exit_code(findings)
    rescue Done => e
      @io.puts e.message
      EXIT_OK
    rescue OptionParser::ParseError, ConfigError, RepositoryError, Git::PlumbingBackend::CommandError => e
      @err.puts "leakproof: #{e.message}"
      EXIT_USAGE
    end

    private

    def scan(path)
      ensure_repository(path)
      sources = if @options[:staged]
                  Sources.from_staged(path)
                else
                  Sources.from_repository(path, mode: @options[:mode], backend: @options[:backend])
                end
      Scanner.new.scan(sources)
    end

    def ensure_repository(path)
      return if @options[:staged]
      return if Git::PlumbingBackend.new(path).repository?

      raise RepositoryError, "#{path} is not a git repository"
    end

    def visible(findings)
      threshold = TIERS.index(@options[:show])
      findings.select { |f| TIERS.index(f.tier.to_s) <= threshold }
              .sort_by { |f| [TIERS.index(f.tier.to_s), f.path.to_s, f.line] }
    end

    def render(findings)
      FORMATS.fetch(@options[:format]).new(findings, io: @io).render
    end

    def exit_code(findings)
      return EXIT_OK if @options[:fail_on] == "never"

      threshold = TIERS.index(@options[:fail_on])
      findings.any? { |f| TIERS.index(f.tier.to_s) <= threshold } ? EXIT_FINDINGS : EXIT_OK
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength -- a flat option table
    def parser
      OptionParser.new do |o|
        o.banner = "Usage: leakproof scan [PATH] [options]"
        o.on("--all-objects", "Include objects no ref points at, such as amended-away commits") do
          @options[:mode] = :all_objects
        end
        o.on("--staged", "Scan staged content only, for use in a pre-commit hook") do
          @options[:staged] = true
        end
        o.on("--backend BACKEND", %w[plumbing rugged], "Git backend (plumbing, rugged)") do |v|
          @options[:backend] = v.to_sym
        end
        o.on("--format FORMAT", FORMATS.keys, "Output format (#{FORMATS.keys.join(", ")})") do |v|
          @options[:format] = v
        end
        o.on("--show TIER", TIERS, "Lowest tier to report (#{TIERS.join(", ")})") { |v| @options[:show] = v }
        o.on("--fail-on TIER", TIERS + ["never"], "Tier that fails the run") { |v| @options[:fail_on] = v }
        o.on("--version") { raise Done, Leakproof::VERSION }
        o.on("-h", "--help") { raise Done, o.to_s }
      end
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
  end
end
