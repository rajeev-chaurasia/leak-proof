# frozen_string_literal: true

# A hook slower than a moment gets uninstalled, and an uninstalled hook protects
# nothing. This is a budget rather than a benchmark: it fails the build.
RSpec.describe "pre-commit latency" do
  BUDGET_SECONDS = 0.5
  STAGED_FILES = 60

  let(:repo) do
    RepoBuilder.build do |r|
      r.commit("Initial commit", "README.md" => "hello\n")
      STAGED_FILES.times do |index|
        r.write("app/models/model_#{index}.rb", generated_source(index))
      end
      r.git("add", "--all")
    end
  end

  after { repo.destroy }

  def generated_source(index)
    lines = Array.new(40) { |line| "  CONSTANT_#{line} = \"value-#{index}-#{line}\"\n" }
    "class Model#{index}\n#{lines.join}end\n"
  end

  def elapsed
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
  end

  it "scans a realistic staged changeset within the budget" do
    sources = Leakproof::Sources.from_staged(repo.path)
    scanner = Leakproof::Scanner.new

    duration = elapsed { scanner.scan(sources) }

    expect(sources.length).to eq(STAGED_FILES)
    expect(duration).to be < BUDGET_SECONDS
  end

  it "reads staged content rather than the working tree" do
    File.write(File.join(repo.path, "app/models/model_0.rb"), %(TOKEN = "#{SampleSecrets.github}"\n))

    findings = Leakproof::Scanner.new.scan(Leakproof::Sources.from_staged(repo.path))

    expect(findings.select(&:confirmed?)).to be_empty
  end

  it "sees a credential once it is staged" do
    File.write(File.join(repo.path, "app/models/model_0.rb"), %(TOKEN = "#{SampleSecrets.github}"\n))
    repo.git("add", "--all")

    findings = Leakproof::Scanner.new.scan(Leakproof::Sources.from_staged(repo.path))

    expect(findings.select(&:confirmed?).map(&:path)).to eq(["app/models/model_0.rb"])
  end
end
