# Contributing

## Adding a detector

One file in `lib/leakproof/detectors/providers/`. Nothing else should need to
change, and there is a test that enforces that.

```ruby
Leakproof::Detectors::Registry.register(
  Leakproof::Detectors::Detector.new(
    id: "acme-deploy-key",
    name: "Acme deploy key",
    pattern: /\b(acme_[a-f0-9]{32})\b/,
    capture: 1,
    keywords: %w[acme_],
    validity: Leakproof::Validity::Contract.new(prefix: "acme_", length: 37, charset: :hex),
    sample: ->(s) { "acme_#{s.hex(32)}" },
    notes: "Prefix and length only.",
    examples: { positive: [], negative: %w[acme_short] }
  )
)
```

Three rules, all enforced by the suite:

**Declare a shape, never a sample.** `sample:` builds a valid credential at run
time. Writing one into the file means committing a credential to this
repository, and `script/check_no_samples.rb` will fail before GitHub's push
protection does.

**Claim only the check you actually have.** `Validity::Contract` means a prefix
and a length, and the generated table will say so. Reach for
`Validity::Crc32Base62` or `Validity::Pem` only when the format genuinely
publishes something checkable. A rule that overstates its evidence can put a
guess in the confirmed tier, which is the one thing this project must not do.

**Earn a corpus row.** Every rule needs at least one negative example. The
`suppressed:` bucket is for values the rule matches on purpose but the filter
must dismiss.

## The bar for scoring changes

`lib/leakproof/scoring/confidence.rb` is load-bearing. The shape of the table
guarantees that a finding cannot be confirmed without a checksum or a key parse,
and a test recomputes that from the table itself. A change that raises any
unverified path above 89 will fail it, and should.

If you change any threshold, re-run `./exe/leakproof-bench` and commit the
regenerated `bench/results/`. The published numbers come from that file.

## Calibration

Thresholds in this project are measured, not chosen. The entropy model was
rewritten because a measurement showed a 64-character random token scoring
below the 10-character string `chat_token`. If you propose a threshold, include
the distribution it came from.

## Before opening a pull request

```bash
bundle exec rake
```

That runs rubocop, the prose and link and layering checks, the self-scan, and
the full suite including the benchmark gate.

## House style

No em-dashes, and no tool attribution anywhere in the tree, enforced by
`script/check_prose.rb`. Comments are sparse and explain why rather than what.
Commit subjects are one line of plain prose.
