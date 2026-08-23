# Non-goals

Written down on day one so that scope creep has to argue with something.

**No live credential verification.** Never an HTTP request to a provider to ask
whether a key works. That is TruffleHog's approach and it is a good one, but it
is the opposite of this project's premise. Offline verification is the whole
point: it works with no egress, it cannot be used to exfiltrate a candidate
credential to an endpoint an attacker chose, and it has no rate limit.

**No web UI, no server mode, no daemon, no database.** A scanner is a program
that reads a repository and writes a report.

**No plugin system and no configuration language.** A flat YAML file at most.
Adding a detector means adding one file to `lib/leakproof/detectors/providers/`,
which is already the extension mechanism.

**No language-aware parsing.** Byte-level scanning only. An AST would improve
context detection and would mean carrying a parser per language.

**No remediation.** No key rotation, no history rewriting, no automatic
revocation. Detection and reporting stop at the report. Rewriting someone's git
history is not something a scanner should do.

**Two git backends, which is not an exception to this.** `rugged` is not here in
case someone wants it. It is here because a second independent implementation is
the oracle that proves the first one correct, in
`spec/unit/leakproof/git/backend_differential_spec.rb`. If that test were
removed, the backend should be deleted the same day.
