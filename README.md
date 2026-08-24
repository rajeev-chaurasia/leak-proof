# leakproof

Finds credentials across full git history, then decides which findings are real
without calling a single provider.

[![CI](https://github.com/rajeev-chaurasia/leak-proof/actions/workflows/ci.yml/badge.svg)](https://github.com/rajeev-chaurasia/leak-proof/actions/workflows/ci.yml)
[![Self-scan](https://github.com/rajeev-chaurasia/leak-proof/actions/workflows/selfhost.yml/badge.svg)](https://github.com/rajeev-chaurasia/leak-proof/actions/workflows/selfhost.yml)

> **Status: alpha, and personal.** Nothing here is published; build it from a
> checkout. `leakproof-bench` regenerates the synthetic numbers and CI gates on
> them. The real-repository figures were measured by hand on pinned commits and
> are dated. The gaps are in [docs/known-misses.md](docs/known-misses.md), and
> most are asserted as tests, so closing one breaks the build until the page is
> rewritten.

## Why another secret scanner

| Tool | Approach | Cost |
|---|---|---|
| gitleaks | regex plus entropy | noisy; you end up maintaining an ignore file |
| TruffleHog | regex, then a live API call to the provider | needs egress to the provider |
| GitHub push protection | provider-partnered patterns | server-side only |

Nobody occupies **verified without network egress**. That is the gap this fills:
everything a live verifier does with an HTTP call, done offline wherever the
format's own mathematics allow it.

It matters when CI has no egress, when sending a candidate credential to a
third-party endpoint is itself the risk you are managing, and when a pre-commit
hook has a latency budget measured in milliseconds.

Where egress is fine and you want the widest possible coverage, use TruffleHog.
It verifies against several hundred providers. Three formats here carry a real
offline proof: GitHub's token family and npm's, which publish a CRC32, and
private keys, which either parse as a key or do not. Everything else is a
prefix and a length, and the table below says so.

## What "verified offline" actually means

| Format | Offline check | Strength |
|---|---|---|
| GitHub `ghp_ gho_ ghu_ ghs_ ghr_`, npm `npm_` | CRC32 of the body, base62-encoded, last six characters | proof |
| Private keys | the DER underneath parses as a key, or it does not | proof |
| JSON web tokens | header and payload decode; `exp` settles expiry | structure |
| AWS `AKIA ASIA AIDA AROA` | base32-decodes to the owning 12-digit account ID | structure |
| Stripe, Slack, SendGrid, Google, OpenAI, Twilio | prefix, length and charset only | weak |

The weak rows are published on purpose. A rule that can only compare a prefix
and a length says so, rather than borrowing credibility from the rules that
carry a proof. The full table is generated from the rule registry into
[docs/detectors.md](docs/detectors.md), so it cannot drift from the code.

**One thing the tool will not do is confirm a finding it cannot prove.** The
scoring table tops out at 85 without a checksum or a key parse, and the
confirmed tier begins at 90. A real AWS key in source reaches `probable` and
stops, because AWS publishes no checksum. That is the honest answer rather than
the reassuring one. See [docs/confidence.md](docs/confidence.md).

## Measured

### On real repositories

Ten open-source repositories, full history, scanned at pinned commits on
2026-08-23. This is the number that matters: a synthetic corpus grades a scanner
against its own author's imagination, and a real repository does not.

| repository | commit | confirmed | probable |
|---|---|---|---|
| `axios` | `84a9f3b9` | 0 | 1 |
| `devise` | `372b295f` | 0 | 0 |
| `express` | `023767fe` | 0 | 0 |
| `faraday` | `b25b1b2` | 0 | 4 |
| `faraday-net_http` | `7c9fefe` | 0 | 0 |
| `octokit.rb` | `6d02a4b5` | 1 | 14 |
| `puma` | `b8341dc9` | 0 | 17 |
| `rack` | `8bf4eb07` | 0 | 0 |
| `ruby-jwt` | `a2cb272` | 0 | 19 |
| `sinatra` | `cb22afd7` | 0 | 0 |
| **total** | | **1** | **55** |

Every one of those 56 findings is real credential material. I triaged them by
hand:

| what | count | verdict |
|---|---|---|
| private keys | 36 | real keys: octokit's integration key, puma's example TLS keys, ruby-jwt's spec fixture keys, axios's test key |
| plaintext tokens in CI config | 16 | octokit's legacy 40-character GitHub token and ruby-jwt's Coveralls `repo_token`, both committed unencrypted |
| AWS access key IDs | 4 | faraday published one in `.travis.yml`, paired secret encrypted |

**No finding was a random string, an identifier, a hash, or a base64 blob.** The
single confirmed finding is octokit's `integration.private-key.pem`, which is a
real RSA key committed to a public repository.

An earlier build of this scanner reported **522 findings across the same
repositories, 492 of them noise, and 32 of 33 confirmed findings were wrong**,
every one a JSON web token in a README. The cause was this project committing
the error it exists to prevent: `Validity::Jwt` returned `verified` for any token
that merely decoded, and decoding proves a string is a JWT, not that it is live.
That history is in the commit log rather than tidied away, because a scanner
that claims a proof it does not have is the failure mode worth showing.

### On a corpus built from the rule registry

Regenerated by `leakproof-bench`; see [bench/results/summary.md](bench/results/summary.md).

Every rule is planted in every one of fourteen renderings: quoted and unquoted,
Ruby, JavaScript, Python, Go, `.env`, Dockerfile, YAML literal blocks, JSON with
escaped newlines, and Markdown, across source, fixture, documentation, vendored
and build paths. The cross product is the point. A rule that only works inside
double quotes is a rule with a hole in it, and widening the corpus this way
immediately found one: a private key in a YAML literal block was invisible,
because OpenSSL will not parse an indented PEM.

The corpus is built at run time from a committed seed and never checked in. A
structurally valid token in a public repository is a secret in a public
repository, and GitHub's push protection blocks it, correctly. So the repository
carries the recipe rather than the material, which also means anyone can
reproduce the corpus exactly.

| | reported | not reported |
|---|---|---|
| credential present in source | 145 | 0 |
| no credential present | 0 | n/a |

Precision 100%, recall 100% over 145 credentials planted in source or deleted
from it, out of 295 plants and 30 decoys. 57 reached the confirmed tier. Graded
separately, because reporting them would be the error: 108 of 108 credentials
under fixture, documentation, vendored and build paths were kept out of the
confirmed tier, and 42 of 42 public-by-design or advisory rules were ignored
entirely.


## Try it

Ruby 3.3 or newer, and git. CI runs the suite on 3.3 and 3.4, on Linux and
macOS. There is nothing to install: the scanner uses only the standard library,
so a clone runs as it is.

```bash
git clone https://github.com/rajeev-chaurasia/leak-proof
cd leak-proof
./exe/leakproof scan /path/to/repo
```

`bundle install` is only needed to run the test suite.

Include objects no ref points at, which is where an amended-away commit hides:

```bash
./exe/leakproof scan /path/to/repo --all-objects
```

As a pre-commit hook, scanning staged content only and blocking on the
confirmed tier alone:

```bash
ln -s ../../hooks/pre-commit .git/hooks/pre-commit
```

In GitHub Actions, with findings in the Security tab:

```yaml
- uses: rajeev-chaurasia/leak-proof@main
  with:
    mode: all-objects
    fail-on: confirmed
```

## Design

Detection knows nothing about git, and git knows nothing about detection. That
is a lint rule rather than a convention, checked by `script/check_layering.rb`,
and the payoff is that the whole engine is testable with no repository on disk.

Adding a provider means adding one file to
`lib/leakproof/detectors/providers/`. The registry finds it, and a test asserts
that by registering a rule at run time and checking it reaches scanning and
validation with no edit to the core. One tracked file does change:
`docs/detectors.md` is generated from the registry, and CI fails if it has not
been regenerated.

Blobs are enumerated twice, by git plumbing and by libgit2, and a differential
test asserts the two independent readings agree byte for byte. That is the
Liskov substitution principle made empirical instead of aspirational.

No detector contains a credential. Each declares a *shape*, and samples are
built at run time, which is why this repository can be pushed to GitHub at all.
`script/check_no_samples.rb` keeps it that way by running leakproof over the
working tree and the whole object store, so a sample is caught before it is
committed and cannot hide in a blob that a later commit deleted. Seven values
from before that rule existed are listed there by content fingerprint, with what
each one is.

Runtime dependencies: none. `rugged` is optional and only the differential test
uses it.

## Documentation

- [docs/detectors.md](docs/detectors.md), generated from the registry
- [docs/confidence.md](docs/confidence.md), the scoring table and what it guarantees
- [docs/known-misses.md](docs/known-misses.md), what it does not catch
- [docs/non-goals.md](docs/non-goals.md), what it will not become
- [bench/results/summary.md](bench/results/summary.md), the current measurement

## License

Apache-2.0. See [LICENSE](LICENSE).
