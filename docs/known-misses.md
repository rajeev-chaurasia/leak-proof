# What leakproof misses

Every entry here was verified by running the scanner, and every one is asserted
in `spec/adversarial/known_misses_spec.rb`. If a miss is fixed, that spec fails
and this page has to change with it. If a new one is found, it belongs here
before the change that closes it lands.

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
there is no rule for. It is the weakest rule here and it is bounded on six
sides. Each bound was chosen against a measurement, and each costs recall.

It is also **advisory**: it carries no entropy bonus, so on its own evidence it
scores below the probable tier and is only visible with `--show ignore`. It
surfaces as a finding when something else corroborates it, in practice a
credential-shaped variable name. This is deliberate. The low base score and the
entropy bonus previously summed to exactly the probable threshold, which meant
every base64 blob in a repository, every embedded font, every subresource
integrity hash and every certificate body arrived as a finding with nothing
supporting it. That single coincidence accounted for the large majority of the
false positives measured in the ten-repository sweep.

| bound | value | why | what it misses |
|---|---|---|---|
| minimum length | 24 | below this, entropy cannot separate a token from an identifier at any threshold | shorter credentials |
| maximum length | 120 | above this, high entropy means encoded data: a dump, a certificate, an image | very long credentials |
| hex excluded | any length | at 24 characters and up, hex is overwhelmingly digests, object IDs and checksums | hex-encoded secrets with no provider prefix |
| three character classes required | lower, upper and digit | every entropy false positive found on a real repository drew on one class | base32 secrets, and about 1% of drawn 24-character tokens |
| identifier cadence | case changes at least every third character | `decodeURIComponentSafe` scores as high as a drawn token on entropy; identifiers flip character class once per word, draws flip every other character | 1.0% of drawn tokens at 24 characters, 0.4% at 32, 0.1% at 40, none at 64 |
| adjacency below 0.5 | | `ABCDEFGHIJKLMNOPQRSTUVWXYZ` has perfect Shannon entropy and is not a secret | credentials that happen to run sequentially |

The camel-case suppressor costs a further 0.7% of drawn tokens at 24
characters, 0.15% at 32, and none at 40. It exists because nine of fifteen
surviving findings on a 1,902-commit repository were one Python class name.

## Not reported, on purpose

**A JSON web token never reaches the confirmed tier.** Decoding a JWT proves it
is a JWT. It does not prove the token is live, and nothing here checks the
signature, which would need the key. A JWT in source reaches `probable`; a JWT
in a README reaches `ignore`.

**Commit messages, tag messages and `.git/config` are not scanned.** Only blob
contents are read, in either mode. A credential pasted into a commit message is
invisible to this tool.

**A Twilio API key SID is any 34-character hex string starting `SK`.** That
collides with hex digests, and the rule is `medium` specificity for exactly that
reason. Expect it on a repository that names a constant `SK...`.

## Structural

**A credential split across source lines is missed.** String concatenation
across a line break defeats every rule here, because scanning is per line.

**Binary blobs are skipped**, and so is any blob over 1 MB.

**Objects git has already collected are gone.** `--all-objects` reads what is
still in the object database. After `git gc --prune`, an amended-away commit is
not there to find.

**Submodule contents are not scanned.** Only the pointer is in the tree.

**Rule coverage is narrow.** TruffleHog has several hundred detectors; the
current count here is the row count of [detectors.md](detectors.md), which is
generated. A provider without a rule falls through to the entropy rule, and that
rule is advisory: it never reports on its own evidence, only when a
credential-shaped variable name corroborates it.

## Verified as not missed

Recorded because they are the cases people ask about:

- a secret committed and later deleted, at any depth of history
- a secret removed by `git commit --amend`, using `--all-objects`
- a secret in a stash, which `refs/stash` keeps reachable
- a base64-wrapped credential, once a credential-shaped name corroborates it
- a credential in an unquoted `KEY=VALUE` line, which is what a `.env` file is
- a private key escaped into JSON, which is the shape of every GCP
  service-account key file
