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
| malformed, contract not satisfied | 0 |
| rejected, the format's own checksum says no | disqualified outright |

Only a failed proof disqualifies. A value that does not fit a length contract is
one this layer cannot speak to, which is not the same as one it can clear.
Treating the two alike had a perverse effect: recognising a provider prefix made
the scanner *less* likely to report the secret than not recognising it at all,
because an over-long `sk-` value was dismissed while the same bytes with no
prefix reached the probable tier.

Add 15 when a name-anchored rule matched a value of at least 20 characters
whose normalized entropy is 0.92 or above. Not for the bare entropy rule:
applying it there would promote every git object ID in the repository.

Subtract what the filter found:

| suppressor | penalty |
|---|---|
| placeholder shape | 100 |
| identifier shape, for low and medium specificity rules | 100 |
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

Two rules sit on top of the arithmetic, both because a proof should outrank a
heuristic:

**A verified finding never falls out of the report.** Suppressors may take it out
of the confirmed tier, since a key under a fixture path really may be a test key,
but they cannot stack it into silence. Without this floor a checksum-verified
token in `docs/` on a long line scored 35 and vanished, which made the whole
confirmed tier a matter of luck about how many heuristics happened to fire.

**Suppressors that are only proxies for machine-generated noise do not apply to a
verified finding at all.** A long line is not an argument against a key that
parses. `minified` and `repetition` are proxies of that kind; the rest carry
real evidence about intent and still apply. This is why a Google service-account
JSON, which is one very long line, is confirmed rather than demoted.

## What the shape of the table guarantees

The highest score reachable without a proof is 60 + 10 + 15 = 85, and the
confirmed tier begins at 90. So:

> **A finding can only be confirmed if its format carries a checksum or parses
> as a key.** No amount of suggestive context can substitute.

That is the project's one hard invariant, and it is enforced by a test rather
than by care. `spec/unit/leakproof/boundaries_spec.rb` drives every registered
rule through the real scorer at each unproven validity status and asserts none
of them reaches the confirmed tier. Recomputing the ceiling from the constants
would only restate the table; running the registry through the function is what
catches a rule that overstates its evidence.

It has a cost, stated plainly: an AWS access key can never be confirmed,
because AWS publishes no checksum for that format. A real AWS key in source
reaches `probable` and no higher. That is the honest answer, and it is why
`--fail-on probable` exists.

## Fingerprints

A finding is identified by the first 128 bits of
`sha256(rule + normalized path + value)`, with no commit in it. Fingerprinting by commit means a rebase, a squash or a force-push
orphans every triaged suppression and the same finding returns as new. That is
not hypothetical: it is the third entry in the `.gitleaksignore` this project
was built from.
