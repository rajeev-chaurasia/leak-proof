# Confidence

Three tiers, from one arithmetic table. Every number below is in
`lib/leakproof/scoring/confidence.rb`, because a confidence score nobody can
recompute is a vibe.

## The table

Start from the rule's specificity:

| specificity | points | meaning |
|---|---|---|
| high | 60 | a provider format with a distinctive prefix and shape |
| medium | 45 | a format that needs its surrounding context to be recognised |
| low | 30 | no format at all, only entropy or a variable name |

Add what the offline check established:

| validity | points |
|---|---|
| verified, by checksum or key parse | +40 |
| well formed, contract satisfied, nothing proven | +10 |
| unknown, no check applicable | 0 |
| rejected or malformed | disqualified outright |

Add 15 when a name-anchored rule matched a value of at least 20 characters
whose normalized entropy is 0.92 or above. Not for the bare entropy rule:
applying it there would promote every git object ID in the repository.

Subtract what the filter found:

| suppressor | penalty |
|---|---|
| placeholder shape | 100 |
| identifier shape, for low-specificity rules only | 100 |
| value published in vendor documentation | 100 |
| path is a test tree, fixture, example, vendored dependency or lock file | 35 |
| minified asset or a line long enough to be a bundle | 30 |
| value appears in three or more distinct paths | 25 |

Then:

| score | tier |
|---|---|
| 90 or above | confirmed |
| 45 to 89 | probable |
| below 45 | ignore |

## What the shape of the table guarantees

The highest score reachable without a proof is 60 + 10 + 15 = 85, and the
confirmed tier begins at 90. So:

> **A finding can only be confirmed if its format carries a checksum or parses
> as a key.** No amount of suggestive context can substitute.

That is the project's one hard invariant, and it is enforced by a test rather
than by care: see `spec/unit/leakproof/scoring/confidence_spec.rb`, which
recomputes the maximum reachable unverified score from the table itself.

It has a cost, stated plainly: an AWS access key can never be confirmed,
because AWS publishes no checksum for that format. A real AWS key in source
reaches `probable` and no higher. That is the honest answer, and it is why
`--fail-on probable` exists.

## Fingerprints

A finding is identified by `sha256(rule + normalized path + value)`, with no
commit in it. Fingerprinting by commit means a rebase, a squash or a force-push
orphans every triaged suppression and the same finding returns as new. That is
not hypothetical: it is the third entry in the `.gitleaksignore` this project
was built from.
