# Printed timing and source ownership review

The production review found real discrepancies between existing card text and
engine behavior. No card definitions, statistics, decks, resource caps or AI
policy changed. The executable fixes use the existing model and FIFO.

The byte-preserved [before evidence](kernel-semantics-before/manifest.json) binds
96 isolated actual-card cases to model SHA
`4d1ed5652514cbc3e13a69cfea3784b1f42cb6a309ce15206966237ab8de9b27`:
48 expected-semantics failures and 48 successful controls. These are reachable
battle fixtures, including public card commands/combat and actual turn
transitions; they are not 96 complete matches. Historical failures remain
failures and are not included in later successful match totals.

| Confirmed behavior before repair | Corrected behavior |
|---|---|
| Optional discard/return/draw availability rejected an entire impulse before earlier printed steps could provide its later hand prerequisites. | The command still validates resources, phase, lanes and required unit targets; each hand/deck step checks availability when the existing FIFO reaches it. An unavailable step fizzles without suppressing later steps. |
| A blocked conditional movement destination suppressed unconditional later benefits. | A live required unit remains mandatory. “Falls dort Platz ist” is checked when the movement resolves; later printed benefits still resolve. |
| Hero-only damage consumed reactions whose text requires damage to an own creature. | Hero damage retains terminal winner checks and does not publish creature damage notifications. |
| An empty defending lane triggered “own creature defends” reactions and relic abilities. | Creature combat notifications require an actual creature instance. Existing contradictory test expectations were corrected and positive creature-defense controls retained. |
| Native arrival strikes and native retaliation defeated creatures without notifying the own-creature kill relics. | Actual casualty removal precedes the corresponding captured-source kill notification. Both native strikes and both native retaliators have repeated-kill/once-per-turn controls. |
| Creature summon/death delays defaulted to path 0 and discarded source identity. | The printed source path is scheduled. Original owner/card/UID provenance accompanies creature delays; due damage retains its path targeting and reports its actual source. |

Delayed damage continues after its creator leaves play. Personal creature
abilities require the living original UID; a returned or replacement copy does
not inherit them. Relic kill watchers use the creature ownership captured when
the damage was scheduled, including when that original creature has since
left play. Impulse delays carry no invented creature provenance. The scheduled
path is evaluated at the due boundary: a replacement occupant can be hit and
an empty path hits the hero; no old target UID freezes that future target.
Fully absorbed damage produces no damage/kill rewards. Death queues and source
capabilities must retire exactly once.

The Alpha extension point preserves the original default damage call followed
by the original delayed trace and winner check. Native retaliation adds only
existing no-op combat hooks for archived Alpha; existing Alpha/Legacy golden
fixtures and replay digests are unchanged.

[ON_PLAY_PROGRAM_REVIEW.json](ON_PLAY_PROGRAM_REVIEW.json) records all 82 actual
multipart on-play programs (79 impulses, 3 creatures). No summon-then-unit-buff
program exists in this catalog. The two summon-then-summon programs resolve
sequentially; if the first fills the last free path, the second step fizzles.
A missing required unit target or no free summon path still rejects the
command atomically. This uses no second simulation engine or per-choice probe.

The targeted regressions execute all 19 actual delayed creature identities on
all five paths for both sides, plus moved/removed/replaced sources, replacement
and moved targets, protection, personal rewards, relic ownership and native /
generic impulse negatives. There is no printed relic delay ability in the
550-card data. Its negative case is explicitly an ABI provenance fixture using
an existing operation and a real relic context, not a claimed legal card play.

[Validation evidence](KERNEL_SEMANTICS_VALIDATION.json) records the actual gate
logs and source hashes. The existing 4,425 engine assertions still include all
940 generic ability fixtures, all 16 automatic trigger families for both sides,
and 1,100 arranged public card plays. Additional suites cover 44 printed cases,
60 kill-watcher boundaries and 226 delayed-source boundaries.

The earlier [848-match report](PRE_SEMANTICS_SIMULATION_RESULTS.json) remains
historical evidence for its own executed source. The corrected source passed a fresh complete 848-match matrix plus 18 replay
controls and 10 negative evidence guards, with zero failures/errors/censors.
[KERNEL_SEMANTICS_SIMULATION_PROVENANCE.json](KERNEL_SEMANTICS_SIMULATION_PROVENANCE.json)
records the official CI artifact and all 18 verified executed source hashes.
[KERNEL_SEMANTICS_BEFORE_AFTER.json](KERNEL_SEMANTICS_BEFORE_AFTER.json) compares the
actual identical 848-case plans: 84 winners and 42/64 starter event digests
change, so the old resource-comparison baseline must be rebound before use.
The pre-getter starter export comes from these 64 actual new starter records.

Review limits: these targeted fixtures and heuristic AI matches do not prove
all reachable 550-card interactions or human metagame balance. The actual
catalog has no printed nonzero card resonance cost, no conditional relic and
no delayed relic ability; their absent combinations are not claimed as tested
legal card programs.
