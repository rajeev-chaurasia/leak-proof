# frozen_string_literal: true

RSpec.describe Leakproof::Git::PlumbingBackend do
  subject(:backend) { described_class.new(repo.path) }

  let(:secret) { "AKIA6RVFFB77RE7OLMKI" }

  after { repo.destroy }

  describe "history that no longer shows the secret at HEAD" do
    let(:repo) do
      RepoBuilder.build do |r|
        r.commit("Add the credentials file", "config/creds.yml" => "aws_key: #{secret}\n")
        r.delete("config/creds.yml")
        r.commit("Remove the credentials file")
      end
    end

    it "finds a secret that was committed and later deleted" do
      contents = backend.each_blob(mode: :reachable).map(&:text)

      expect(contents).to include(a_string_including(secret))
    end

    it "does not find it in the working tree" do
      expect(File).not_to exist(File.join(repo.path, "config/creds.yml"))
    end
  end

  describe "history that was amended away" do
    let(:repo) do
      RepoBuilder.build do |r|
        r.commit("Add a readme", "README.md" => "hello\n")
        r.commit("Add the credentials file", "config/creds.yml" => "aws_key: #{secret}\n")
        r.amend("Add the credentials file", "config/creds.yml" => "aws_key: REDACTED\n")
      end
    end

    it "misses the amended-away secret in reachable mode" do
      contents = backend.each_blob(mode: :reachable).map(&:text)

      expect(contents).not_to include(a_string_including(secret))
    end

    it "finds the amended-away secret in all-objects mode" do
      contents = backend.each_blob(mode: :all_objects).map(&:text)

      expect(contents).to include(a_string_including(secret))
    end
  end

  describe "framing" do
    let(:binary) { "\x89PNG\r\n\x1a\n#{secret}\n\x00\x01\x02trailing".b }
    let(:repo) do
      RepoBuilder.build do |r|
        r.commit("Add a file with newlines and a null byte", "assets/logo.png" => binary)
      end
    end

    it "reads blob bodies by byte count rather than to a newline" do
      blob = backend.each_blob(mode: :reachable).find { |b| b.path == "assets/logo.png" }

      expect(blob.content.b).to eq(binary)
      expect(blob.size).to eq(binary.bytesize)
    end
  end

  describe "size policy" do
    let(:repo) do
      RepoBuilder.build do |r|
        r.commit("Add a large vendored bundle", "vendor/big.js" => "x" * 5_000)
      end
    end

    it "skips blobs above the configured ceiling but keeps the stream in sync" do
      small = described_class.new(repo.path, max_blob_bytes: 1_000)

      expect(small.each_blob(mode: :reachable).map(&:path)).not_to include("vendor/big.js")
    end
  end
end
