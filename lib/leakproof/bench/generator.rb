# frozen_string_literal: true

require "digest"
require "fileutils"
require_relative "plant"
require_relative "renderings"
require_relative "synthesizer"

module Leakproof
  module Bench
    # Builds the recall corpus at run time from the detector registry, so a new
    # provider earns corpus coverage the moment it is registered.
    #
    # Every rule is planted in every rendering below, because the syntax around
    # a secret decides whether it is visible: an unquoted .env line and a key
    # escaped into JSON were both missed until a red-team pass found them.
    #
    # Nothing it writes is committed. A structurally valid token in a public
    # repository is a secret in a public repository, and GitHub's push
    # protection refuses it, correctly. The repository carries the recipe.
    class Generator # rubocop:disable Metrics/ClassLength
      PLACEMENTS = [
        { path: "src/config/settings.rb", placement: :source, render: :ruby },
        { path: "web/src/api-client.js", placement: :source, render: :javascript },
        { path: "scripts/deploy.py", placement: :source, render: :python },
        { path: "cmd/server/main.go", placement: :source, render: :go },
        { path: ".env", placement: :source, render: :env },
        { path: "Dockerfile", placement: :source, render: :dockerfile },
        { path: "config/credentials.yml", placement: :source, render: :yaml },
        { path: "config/service-account.json", placement: :source, render: :json },
        { path: "spec/fixtures/credentials.rb", placement: :fixture, render: :ruby },
        { path: "test/support/tokens.js", placement: :fixture, render: :javascript },
        { path: "docs/setup.md", placement: :documentation, render: :markdown },
        { path: "README.md", placement: :documentation, render: :markdown },
        { path: "vendor/sdk/client.rb", placement: :vendored, render: :ruby },
        { path: "dist/bundle.js", placement: :build, render: :javascript }
      ].freeze

      # Every entry below was an observed false positive on a real repository during
      # the blue-team sweep, or a published value that must never be reported.
      DECOYS = {
        git_sha: { path: "app/models/user.rb", line: 'REVISION = "%<hex40>s"' },
        uuid: { path: "app/models/user.rb", line: 'REQUEST_ID = "%<uuid>s"' },
        camel_case: { path: "app/models/user.rb", line: "loader = Mask2FormerInstanceLoader.new" },
        lower_camel_case: { path: "web/src/util.js", line: "const fn = utilsHasOwnProperty;" },
        consecutive_caps: { path: "web/src/util.js", line: "const g = decodeURIComponentSafe;" },
        method_call: { path: "app/models/user.rb", line: "secret = SecureRandom.random_bytes(32)" },
        # rubocop:disable Lint/InterpolationCheck
        ruby_interpolation: { path: "app/models/user.rb", line: 'token = "#{session.id}"' },
        # rubocop:enable Lint/InterpolationCheck
        env_name: { path: "app/models/user.rb", line: "MINIO_ROOT_ADMIN=1" },
        alphabet: {
          path: "app/models/user.rb",
          line: 'ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"'
        },
        placeholder: { path: "app/models/user.rb", line: 'api_key = "YOUR_API_KEY_HERE"' },
        interpolation: { path: "app/models/user.rb", line: 'password = "${DB_PASSWORD}"' },
        prose: { path: "app/models/user.rb",
                 line: 'message = "the quick brown fox jumps over the lazy dog"' },
        mime: { path: "app/models/user.rb", line: 'content_type = "application/json;charset=utf-8"' },
        path_segment: { path: "app/models/user.rb", line: 'MODULE_PATH = "/packages/client-python/src"' },
        documentation_key: { path: "app/models/user.rb", line: 'aws_key = "AKIAIOSFODNN7EXAMPLE"' },
        spinkit_class: { path: "web/src/spinner.scss", line: ".sk-fading-circle-container-large { top: 0 }" },
        sklearn_artifact: { path: "ml/train.py",
                            line: 'ARTIFACT = "sk-learn-gradient-boosting-classifier-v2"' },
        bitcoin_address: { path: "app/models/user.rb",
                           line: 'TREASURY = "1BvBMSEYstWetqTFn5Au4m4GFg7xJaNVN2"' },
        ssh_public_key: { path: "config/authorized_keys",
                          line: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI%<base64url_long>s deploy@host" },
        sri_hash: { path: "web/index.html",
                    line: '<script integrity="sha384-%<base64_long>s"></script>' },
        data_uri: { path: "web/index.html",
                    line: '<img src="data:image/png;base64,%<base64_long>s">' },
        mangled_symbol: { path: "build/app.symbols",
                          line: "0000000100003a10 T __ZN7leveldb6DBImpl11CompactonV2E" },
        emscripten_export: { path: "web/src/pdfium.js", line: 'Module["_FPDFText_LoadCidType2Font"] = 1;' },
        content_hash: { path: "web/index.html",
                        line: '<script src="/assets/app-%<base62_mid>s.js"></script>' },
        azurite_key: {
          path: ".github/workflows/build.yml",
          line: "  AZURITE_KEY: Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/" \
                "K1SZFPTOtr/KBHBeksoGMGw=="
        },
        travis_secure: { path: ".travis.yml", line: "  secure: \"%<base64_long>s\"" },
        bcrypt_digest: { path: "db/seeds.rb", line: 'PASSWORD_DIGEST = "$2a$12$%<base62_mid>s"' },
        jwk_coordinate: { path: "config/jwks.json", line: '{"kty":"EC","x":"%<base64url_long>s"}' },
        webkit_boundary: { path: "spec/support/multipart.rb",
                           line: 'BOUNDARY = "----WebKitFormBoundary%<base62_mid>s"' },
        lockfile_integrity: { path: "web/package-lock.json", line: '"integrity": "sha512-%<base64_long>s"' }
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

      # Every rule in every rendering. The cross product is the point: a rule
      # that only works inside double quotes is a rule with a hole in it.
      def write_plants(root)
        PLACEMENTS.each do |slot|
          lines = @registry.filter_map { |detector| plant_line(detector, slot) }
          write(root, slot[:path], lines.join)
        end
      end

      def plant_line(detector, slot)
        value = detector.synthesize(@synthesizer)
        return nil unless value

        name = "SECRET_#{detector.id.upcase.gsub(/[^A-Z0-9]/, "_")}"
        rendered = Renderings.public_send(slot[:render], name, value)
        @plants << Plant.new(rule: detector.id, path: slot[:path], value: value,
                             line: nil, placement: slot[:placement])
        rendered
      end

      def write_decoys(root)
        DECOYS.each do |kind, spec|
          line = format(spec[:line], decoy_values)
          @decoys << Decoy.new(kind: kind, path: spec[:path], content: line)
        end
        @decoys.group_by(&:path).each do |path, group|
          write(root, path, "#{group.map(&:content).join("\n")}\n")
        end
      end

      def decoy_values
        {
          hex40: @synthesizer.hex(40), uuid: uuid,
          base64url_long: @synthesizer.base64url(43),
          base64_long: @synthesizer.base62(64),
          base62_mid: @synthesizer.base62(32)
        }
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
