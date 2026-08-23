# What leakproof misses

Every entry here was verified by running the scanner, and every one is asserted
in `spec/adversarial/known_misses_spec.rb`. If a miss is fixed, that spec fails
and this page has to change with it. If a new one is found, it belongs here
before the release that contains it.

## By design

**An AWS access key can never be confirmed.** AWS publishes no checksum for the
format, so the strongest honest statement is that the key is well formed and
belongs to account N. It reaches `probable` and stops there. Use
`--fail-on probable` if you want AWS keys to block a build.

The same holds for every rule in the `weak` column of
[detectors.md](detectors.md): Stripe, Slack, SendGrid, Google, OpenAI, Twilio,
and GitHub's fine-grained tokens. None of those formats publishes anything that
can be checked without asking the provider.

## Limits of the entropy rule

The unclassified-high-entropy rule exists to catch credentials from providers
there is no rule for. It is the weakest rule here and it is bounded on five
sides. Each bound was chosen against a measurement, and each costs recall.

| bound | value | why | what it misses |
|---|---|---|---|
| minimum length | 24 | below this, entropy cannot separate a token from an identifier at any threshold | shorter credentials |
| maximum length | 120 | above this, high entropy means encoded data: a dump, a certificate, an image | very long credentials |
| hex excluded | any length | at 24 characters and up, hex is overwhelmingly digests, object IDs and checksums | hex-encoded secrets with no provider prefix |
| three character classes required | lower, upper and digit | every entropy false positive found on a real repository drew on one class | base32 secrets, and about 1% of drawn 24-character tokens |
| adjacency below 0.5 | | `ABCDEFGHIJKLMNOPQRSTUVWXYZ` has perfect Shannon entropy and is not a secret | credentials that happen to run sequentially |

The camel-case suppressor costs a further 0.7% of drawn tokens at 24
characters, 0.15% at 32, and none at 40. It exists because nine of fifteen
surviving findings on a 1,902-commit repository were one Python class name.

## Structural

**A credential split across source lines is missed.** String concatenation
across a line break defeats every rule here, because scanning is per line.

**Binary blobs are skipped**, and so is any blob over 1 MB.

**Objects git has already collected are gone.** `--all-objects` reads what is
still in the object database. After `git gc --prune`, an amended-away commit is
not there to find.

**Submodule contents are not scanned.** Only the pointer is in the tree.

**There are 22 rules.** TruffleHog has several hundred detectors. Any provider
without a rule here falls through to the entropy rule and its five bounds.

## Verified as not missed

Recorded because they are the cases people ask about:

- a secret committed and later deleted, at any depth of history
- a secret removed by `git commit --amend`, using `--all-objects`
- a secret in a stash, which `refs/stash` keeps reachable
- a base64-wrapped credential, caught by the entropy rule at `probable`
