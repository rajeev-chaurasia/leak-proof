---
name: A credential leakproof missed
about: The most valuable report this project can receive
labels: missed-secret
---

A confirmed miss blocks the build until it is fixed, and the fix lands
with the reproduction committed as a test.

**Do not paste a real credential.** Describe its shape, or generate a
structurally valid one with `Leakproof::Bench::Synthesizer`.

## The credential

- Provider and format:
- Where it sat (path, and whether it was still at HEAD):
- Was it reachable from a ref, or only from an amended or orphaned commit?

## What leakproof did

- Reported nothing at all / reported below the tier you expected:
- Command you ran:
- Version (`leakproof --version`):

## Why it should have been caught

Anything about the format that allows an offline check would help most: a
checksum, a length contract, a parseable structure.
