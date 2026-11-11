# Exact draw-controller compatibility in source guards

The approved online seam is the two-line default hook plus one branch call in
`scripts/alpha/model.gd`, introduced by `1151530`. It leaves the default predicate
`side=="enemy"`; the online subclass can opt out of automatic enemy draw handling.

The original model anchor remains:

`fd1c2937f74bf587a4bcdf7a82e0da5990ad8dfadb7bf812b4ad0728b9fa6bd2`

The sole accepted changed model is:

`9e41cab7589c3a05ab1ede8375075018672142c9afdd90873a72efaaf0c5d089`

`tools/production/source_compatibility.py` requires that exact changed hash,
removes the exact comment/hook, reverses the exact branch and verifies both the
original hash and byte-for-byte forward reconstruction. This is an explicit
compatibility exception for this source path and this delta only. Other model,
rule, resource, card, AI, harness or data changes are rejected.

Full-pool coverage retains its original D3 core commit and `core_source_sha256`.
The actual source hashes stay in `source_sha256`; the report separately records
anchor, actual and normalized model hashes plus the compatibility guard hash.
The existing frozen Godot harnesses and baseline fixtures remain unchanged.

Resource reports still require every default case to reproduce the original
winner, round, convergence, complete event digest and complete state digest.
The original baseline commit/source hashes are still verified. Balance aggregate
and report generators bind the actual current model hash; this compatibility
proof cannot relabel an old run as a new run. Fresh matrices must be run against
the integrated sources, with their actual source hashes recorded.

`python3 tests/production_source_compatibility_test.py -v` passes seven tests,
including rejection of changed hook defaults, wrong branch/side, duplicate hooks,
unrelated resource edits, whitespace changes, a changed anchor, changes to other
paths, old evidence against the new source, and altered resource default state or
event digests. The full-pool context test checks that the original core and actual
executed hashes remain distinct and that an AI change is still rejected. These
tests generate no match results or replacement evidence.

The online worker separately verified 148 identical accepted command boundaries
over eight seeds against the pre-seam source, comparing complete state/event
digests and RNG state/call count. That focused runtime proof supplements the
source proof; it is not a substitute for the fresh production matrices.
