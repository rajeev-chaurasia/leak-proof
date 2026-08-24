# Security

## What counts as a security issue here

This is a scanner, so the interesting failures are its own.

**A missed credential** is the most valuable report this project can receive.
Open an issue with the [missed-secret template](.github/ISSUE_TEMPLATE/missed-secret.md).
A confirmed miss blocks the build until it is fixed, and the fix lands
with the reproduction committed as a test. Please do not paste a real
credential: describe the shape, or generate a structurally valid one with
`Leakproof::Bench::Synthesizer`.

**A false positive at the confirmed tier** is equally serious. That tier is
supposed to be reachable only through a checksum or a key parse, and it is what
the pre-commit hook blocks on. If something reaches it without a proof, the
scoring table is wrong.

**Anything that makes leakproof send data anywhere.** The tool performs no
network requests at all. A code path that does is a bug regardless of what it
would be used for. Report it privately.

## Trust boundaries

leakproof reads repositories that may be hostile. It treats every blob as
untrusted bytes: it never executes, deserializes, or interprets repository
content, and it does not follow anything a repository points at, including
submodules.

It makes no network requests. That is the premise of the project rather than a
configuration option, so there is no flag that turns it on.

Findings are redacted in every report format. The middle of a value is masked,
so a report can be pasted into an issue without re-leaking the credential.

The one thing to be careful with: a SARIF file contains paths, line numbers and
rule names for every finding. That is a map of where your credentials were.
Treat the artifact as sensitive.

## Reporting privately

Use GitHub's private vulnerability reporting on this repository.
