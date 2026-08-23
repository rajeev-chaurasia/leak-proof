# frozen_string_literal: true

# The Liskov check made empirical: two independent enumerations of the same
# repository must agree exactly, or one of them is lying.
RSpec.describe Leakproof::Git::Backend do
  let(:secret) { "AKIA6RVFFB77RE7OLMKI" }

  before { skip("rugged is not installed") unless Leakproof::Git::RuggedBackend.available? }

  after { repo.destroy }

  shared_examples "identical enumeration" do |mode|
    it "agrees in #{mode} mode" do
      plumbing = Leakproof::Git::PlumbingBackend.new(repo.path).each_blob(mode: mode).map(&:identity)
      rugged = Leakproof::Git::RuggedBackend.new(repo.path).each_blob(mode: mode).map(&:identity)

      expect(rugged.sort).to eq(plumbing.sort)
      expect(plumbing).not_to be_empty
    end
  end

  context "with a linear history including a deletion" do
    let(:repo) do
      RepoBuilder.build do |r|
        r.commit("Add the credentials file", "config/creds.yml" => "aws_key: #{secret}\n")
        r.commit("Add a readme", "README.md" => "hello\n")
        r.delete("config/creds.yml")
        r.commit("Remove the credentials file")
      end
    end

    it_behaves_like "identical enumeration", :reachable
    it_behaves_like "identical enumeration", :all_objects
  end

  context "with binary content, nested paths and a branch" do
    let(:repo) do
      RepoBuilder.build do |r|
        r.commit("Add assets", "a/b/c/logo.png" => "\x89PNG\r\n\x00#{secret}".b)
        r.git("checkout", "--quiet", "-b", "sidebranch")
        r.commit("Add a config on the branch", "deep/nested/dir/config.env" => "TOKEN=#{secret}\n")
        r.git("checkout", "--quiet", "main")
        r.commit("Move on with main", "main.txt" => "main\n")
      end
    end

    it_behaves_like "identical enumeration", :reachable
    it_behaves_like "identical enumeration", :all_objects
  end
end
