# frozen_string_literal: true

require "json"

module Leakproof
  module Bench
    # How a credential is written down. The syntax around a secret decides
    # whether a scanner sees it at all: an unquoted .env line and a key escaped
    # into JSON were both invisible until a red-team pass found them, so the
    # corpus plants every rule in every one of these forms.
    module Renderings
      module_function

      def ruby(name, value)
        value.include?("\n") ? "#{name} = <<~KEY\n#{value}KEY\n" : %(#{name} = "#{value}"\n)
      end

      def javascript(name, value)
        %(const #{name.downcase} = #{JSON.generate(value)};\n)
      end

      def python(name, value)
        %(#{name} = #{JSON.generate(value)}\n)
      end

      def go(name, value)
        %(const #{name} = #{JSON.generate(value)}\n)
      end

      # Unquoted, which is what .env, shell exports and .properties all look like.
      def env(name, value)
        "#{name}=#{value.gsub("\n", '\n')}\n"
      end

      def dockerfile(name, value)
        "ENV #{name}=#{value.gsub("\n", '\n')}\n"
      end

      def yaml(name, value)
        return "#{name.downcase}: |\n#{value.lines.map { |l| "  #{l}" }.join}" if value.include?("\n")

        %(#{name.downcase}: "#{value}"\n)
      end

      # The GCP service-account shape: a PEM with its newlines escaped.
      def json(name, value)
        "#{JSON.generate(name.downcase => value)}\n"
      end

      def markdown(name, value)
        "```\n#{name} = \"#{value.gsub("\n", '\n')}\"\n```\n\n"
      end

      def extension(kind)
        { ruby: "rb", javascript: "js", python: "py", go: "go", env: "env",
          dockerfile: "Dockerfile", yaml: "yml", json: "json", markdown: "md" }.fetch(kind)
      end
    end
  end
end
