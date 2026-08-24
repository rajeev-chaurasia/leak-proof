# frozen_string_literal: true

# The Liskov check made empirical: two independent enumerations of the same
# repository must agree exactly, or one of them is lying.
RSpec.describe Leakproof::Git::Backend do
  let(:secret) { SampleSecrets.aws_key }

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

  # Without an unreachable object the two modes enumerate the same set, so the
  # all_objects half of this spec proved nothing: rugged could ignore the mode
  # argument entirely and still pass.
  context "with objects no ref can reach" do
    let(:repo) do
      RepoBuilder.build do |r|
        r.commit("Add a readme", "README.md" => "hello\n")
        r.commit("Add the credentials file", "config/creds.yml" => "aws_key: #{secret}\n")
        r.amend("Add the credentials file", "config/creds.yml" => "aws_key: REDACTED\n")
      end
    end

    it "sees strictly more in all_objects mode than in reachable mode" do
      reachable = Leakproof::Git::PlumbingBackend.new(repo.path).each_blob(mode: :reachable).map(&:oid)
      everything = Leakproof::Git::PlumbingBackend.new(repo.path).each_blob(mode: :all_objects).map(&:oid)

      expect(everything.size).to be > reachable.size
      expect(everything).to include(*reachable)
    end

    it "agrees with rugged about which objects are unreachable" do
      plumbing = Leakproof::Git::PlumbingBackend.new(repo.path)
      rugged = Leakproof::Git::RuggedBackend.new(repo.path)
      orphans = lambda do |backend|
        backend.each_blob(mode: :all_objects).map(&:oid) - backend.each_blob(mode: :reachable).map(&:oid)
      end

      expect(orphans.call(rugged).sort).to eq(orphans.call(plumbing).sort)
      expect(orphans.call(plumbing)).not_to be_empty
    end

    it_behaves_like "identical enumeration", :reachable
    it_behaves_like "identical enumeration", :all_objects
  end

  # The oracle is only worth having if it can fail. Identity carries content, so
  # a backend that returned the right oids with the wrong bytes must be caught.
  context "when one backend is deliberately wrong" do
    let(:repo) do
      RepoBuilder.build { |r| r.commit("Add config", "config.yml" => "aws_key: #{secret}\n") }
    end

    it "fails when a backend truncates content" do
      truthful = Leakproof::Git::PlumbingBackend.new(repo.path).each_blob(mode: :reachable).map(&:identity)
      liar = Leakproof::Git::RuggedBackend.new(repo.path).each_blob(mode: :reachable).map do |blob|
        Leakproof::Git::Blob.new(oid: blob.oid, size: blob.size, path: blob.path,
                                 content: blob.content.to_s[0, 4]).identity
      end

      expect(liar.sort).not_to eq(truthful.sort)
    end
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
