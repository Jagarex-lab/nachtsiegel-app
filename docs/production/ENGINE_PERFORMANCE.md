# Long-match engine performance

Measured on the shared Linux test executor on 2026-11-10, Godot 4.6.3, two-CPU
container quota. These are native headless measurements, not iPhone measurements.
Host scheduling varies; wall time is not a fixed performance guarantee.

The reproducible case is the actual `prod-control` deck against itself, seed 0,
AI level 2. Exchange initial cards costing more than 3, choose origin 2, apply the
existing second-player exchange/path option, then call the real hero AI until a
winner. It finishes normally with enemy victory at global round 118, 58 combined
hero/enemy calls and 3,738 retained ordered events. No winner, turn cap, damage,
resource, card, deck or AI rule was changed for this optimization.

| Measurement | Original history | Final optimized profile |
|---|---:|---:|
| Sum of combined-turn command wall times | 44.866 s | 11.009 s |
| Median of final ten combined-turn calls | 1,215.628 ms | 178.393 ms |
| End-of-match obsolete/current usage keys | 678 | 10 |
| Maximum resident memory | about 374 MiB in the shallow-history baseline | 127.965 MiB |
| Whole optimized child wall time | — | 14.201 s |
| Optimized child user + system CPU | — | 12.074 s |

A separate compact-bookkeeping run took 7.688 command seconds, showing the wall
measurements' sensitivity to shared-host load. The final result does **not** claim
that all combined-turn calls finish within 100 ms. One call includes both players'
full AI turns and effects. The original full 848-case attempt stopped after 120
completed cases while a long control mirror grew above 2 GiB; that interrupted
attempt is not a passing simulation report.

Changes remove repeated work and storage:

1. Reuse immutable validated card configuration across constructors and probes.
2. Copy only mutable battle state; shallow-copy closed history containers, with
   a deep fallback if a queue is resolving.
3. Remove only past-round cooldown keys and departed-source condition latches.
4. Production-only constant-work ordered publication digest, explicitly versioned;
   archived bridge/Legacy hash behavior remains unchanged.
5. Snapshot base stats read immutable production data rather than deep-copying
   entire art/ability definitions for every unit on every event.
6. Share unchanged immutable historical snapshot branches while keeping every
   complete event record and its order available.

The final state and last 30 full event records match the original control proof
once **only** expired cooldown/latch bookkeeping and the explicitly versioned
history digest fields are normalized. All combat fields, source/target identities,
counters, event order and event details compare equal. This limited comparison is
not a claim that a complete old/new 3,738-event trace was compared: the original
retained proof contained its final state and last 30 events.

The complete engine regression after the optimization passed 4,335 assertions,
including all 550 cards played for both sides, all sixteen automatic trigger
families for both sides and 940 actual generic ability fixtures. A further focused
bookkeeping run passed 14 assertions: accepted/illegal/duplicate hash behavior,
probe digest/state identity and original-history isolation, pruning scope and
immutable event-branch sharing. Both groups run together in the normal engine test.

`engine-performance-evidence.json` records the final measured process result.
Run the normal full tests before merging; these measurements do not replace
session replay tests, the 848-case full simulation gate or browser/device QA.
