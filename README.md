# leakproof

Finds credentials in full git history, then decides which findings are real without
calling a single provider.

> **Status: in progress.** The scanner is being built in phases and the measured
> numbers below do not exist yet. Nothing here should be trusted until this notice
> is replaced by a published confusion matrix.

## Why another secret scanner

| Tool | Approach | Cost |
|---|---|---|
| gitleaks | regex plus entropy | noisy, needs a hand-maintained ignore file |
| TruffleHog | regex, then a live API call to the provider | requires network egress to the provider |
| GitHub push protection | provider-partnered patterns | server-side only |

Nobody occupies *verified without network egress*. That is the gap leakproof fills:
everything a live verifier does with an HTTP call, done offline wherever the format's
own mathematics allow it.

That matters when CI has no egress, when sending a candidate credential to a
third-party endpoint is itself the risk, and when a pre-commit hook has a latency
budget measured in milliseconds.

## License

Apache-2.0. See [LICENSE](LICENSE).
