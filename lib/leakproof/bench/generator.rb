# frozen_string_literal: true

require "fileutils"
require_relative "plant"
require_relative "synthesizer"

module Leakproof
  module Bench
    # Builds the recall corpus at run time from the detector registry, so a new
    # provider earns corpus coverage the moment it is registered.
    #
    # Nothing it writes is committed. A structurally valid token in a public
    # repository is a secret in a public repository, and GitHub's push
    # protection refuses it, correctly. The repository carries the recipe.
    class Generator
      PLACEMENTS = {
        "src/config/settings.rb" => :source,
        "app/services/client.rb" => :source,
        "spec/fixtures/credentials.rb" => :fixture,
        "docs/setup.md" => :documentation
      }.freeze

      DECOYS = {
        git_sha: "REVISION = \"%<hex40>s\"",
        uuid: "REQUEST_ID = \"%<uuid>s\"",
        camel_case: "loader = Mask2FormerInstanceLoader.new",
        env_name: "MINIO_ROOT_ADMIN=1",
        alphabet: "BASE64_ALPHABET = \"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/\"",
        placeholder: "api_key = \"YOUR_API_KEY_HERE\"",
        interpolation: "password = \"${DB_PASSWORD}\"",
        prose: "message = \"the quick brown fox jumps over the lazy dog\"",
        mime: "content_type = \"application/json;charset=utf-8\"",
        path: "MODULE_PATH = \"/packages/client-python/src\"",
        documentation_key: "aws_key = \"%<aws_doc>s\""
      }.freeze

      attr_reader :plants, :decoys

      def initialize(registry:, seed: 20_260_823)
        @registry = registry
        @seed = seed
        @synthesizer = Synthesizer.new(seed: seed)
        @plants = []
        @decoys = []
      end

      def build(root)
        FileUtils.rm_rf(root)
        FileUtils.mkdir_p(root)
        run(root, "init", "--quiet", "--initial-branch=main")
        write_decoys(root)
        commit(root, "Add ordinary application code")
        write_plants(root)
        commit(root, "Add configuration")
        plant_deleted_secret(root)
        root
      end

      private

      # The case a working-tree scanner cannot see: committed, then removed.
      def plant_deleted_secret(root)
        detector = @registry.find { |d| d.id == "github-pat" }
        value = detector.synthesize(@synthesizer)
        path = "config/deploy.rb"
        write(root, path, %(DEPLOY_TOKEN = "#{value}"\n))
        commit(root, "Add the deploy token")
        run(root, "rm", "--quiet", path)
        commit(root, "Remove the deploy token")
        @plants << Plant.new(rule: detector.id, path: path, value: value, line: 1, placement: :deleted)
      end

      def write_plants(root)
        placements = PLACEMENTS.to_a
        @registry.each_with_index do |detector, index|
          value = detector.synthesize(@synthesizer)
          next unless value

          path, placement = placements[index % placements.length]
          @plants << Plant.new(rule: detector.id, path: path, value: value,
                               line: nil, placement: placement)
        end
        PLACEMENTS.each_key { |path| write(root, path, content_for(path)) }
      end

      def content_for(path)
        lines = @plants.select { |plant| plant.path == path }.each_with_index.map do |plant, index|
          plant.line = index + 1
          literal = plant.value.include?("\n") ? "<<~KEY\n#{plant.value}KEY" : %("#{plant.value}")
          "SECRET_#{index} = #{literal}\n"
        end
        lines.join
      end

      def write_decoys(root)
        content = DECOYS.map do |kind, template|
          line = format(template, hex40: @synthesizer.hex(40), uuid: uuid,
                                  aws_doc: "AKIAIOSFODNN7EXAMPLE")
          @decoys << Decoy.new(kind: kind, path: "app/models/user.rb", content: line)
          line
        end.join("\n")
        write(root, "app/models/user.rb", "#{content}\n")
      end

      def uuid
        hex = @synthesizer.hex(32)
        [hex[0, 8], hex[8, 4], hex[12, 4], hex[16, 4], hex[20, 12]].join("-")
      end

      def write(root, relative, content)
        absolute = File.join(root, relative)
        FileUtils.mkdir_p(File.dirname(absolute))
        File.binwrite(absolute, content)
      end

      def commit(root, message)
        run(root, "add", "--all")
        run(root, "commit", "--quiet", "--allow-empty", "-m", message)
      end

      def run(root, *args)
        environment = {
          "GIT_AUTHOR_NAME" => "bench", "GIT_AUTHOR_EMAIL" => "bench@example.com",
          "GIT_COMMITTER_NAME" => "bench", "GIT_COMMITTER_EMAIL" => "bench@example.com",
          "GIT_CONFIG_GLOBAL" => "/dev/null", "GIT_CONFIG_SYSTEM" => "/dev/null"
        }
        output = IO.popen(environment, ["git", "-C", root, *args], "rb", &:read)
        raise Error, "git #{args.join(" ")} failed" unless $CHILD_STATUS.success?

        output
      end
    end
  end
end
