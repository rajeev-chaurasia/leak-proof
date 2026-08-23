# frozen_string_literal: true

# The other half of the corpus contract. A detector may declare values it
# deliberately matches but the filter must dismiss, and each one is asserted.
RSpec.describe "suppression corpus" do
  scanner = Leakproof::Scanner.new

  CorpusSamples::REGISTRY.each do |detector|
    next if detector.examples[:suppressed].empty?

    describe detector.id do
      detector.examples[:suppressed].each do |sample|
        it "dismisses #{sample[0, 40]}" do
          findings = scanner.scan_text(sample, path: "src/app.rb")
          surviving = findings.reject { |f| f.tier == :ignore }

          expect(surviving).to be_empty
        end
      end
    end
  end
end
