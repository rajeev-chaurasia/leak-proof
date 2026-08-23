# The benchmark

```bash
./exe/leakproof-bench
```

Writes `bench/results/recall.json` and `bench/results/summary.md`, and exits
non-zero if any false positive survives the filter.

## What it builds

A git repository under `tmp/corpus/`, generated from the detector registry and a
committed seed. Every rule that declares a `sample:` shape gets a credential
planted, so a new provider earns corpus coverage the moment it is registered.

Plants are placed in four locations, and the placement decides what correct
behaviour is:

| placement | expectation |
|---|---|
| `src/config/settings.rb`, `app/services/client.rb` | must be reported |
| a file committed and then deleted | must be reported |
| `spec/fixtures/credentials.rb` | reported, but must not reach the confirmed tier |
| `docs/setup.md` | reported, but must not reach the confirmed tier |

Alongside them sit eleven decoys, each one a false positive actually observed on
a real repository: a git object ID, a UUID, a camel-case class name, an
environment variable name, a base64 alphabet constant, a placeholder, a shell
interpolation, an English phrase, a mime type, a module path, and a vendor
documentation key.

## Why nothing is committed

A structurally valid `ghp_` token with a correct CRC32 committed to a public
repository is a secret committed to a public repository, and GitHub's push
protection refuses the push. It did refuse this one, twice, during development.

So the repository carries the generator and the seed rather than the corpus.
The corpus is reproducible by anyone from those two things, which is more than
can be said for a benchmark whose author cannot share it.

## How grading works

Binary on the underlying question: does a location hold a real credential?
Expected tiers are not part of ground truth, because grading the scoring table
against the scoring table would measure nothing.

Three populations are graded apart, because collapsing them makes correct
behaviour look like failure:

- credentials in source, or deleted from it, which must be reported
- the same credentials under fixture and documentation paths, which must be
  reported but must not be confirmed
- types that are public by design, such as a Stripe `pk_` key, which must not
  be reported at all

The same corpus is scanned twice, once with the context filter and once
without, which is where the false-positive reduction table comes from.

## The release gate

`spec/bench/release_gate_spec.rb` runs the whole thing in the test suite.
Precision must be exactly 1.0 and no false positive may survive the filter.
Recall is allowed to be below 1.0, and anything missed is named in the summary
and in [known-misses.md](known-misses.md).
