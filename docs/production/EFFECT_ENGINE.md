# ORAFOLD production effect engine

Status: implemented profile `production-550-v1`. This extends the PR #11 bridge,
which extends AlphaModel and the shared Legacy kernel. It does not introduce an
independent combat simulation. `scripts/card_system/runtime.gd` remains the single
generic FIFO and delegates to existing damage, draw, summon, death and zone helpers.
The archived Alpha/Legacy constructors keep their original pools and behavior.

## Executable contract

Definitions use `abilities` with `mode`, `effect`, `target`, `params`, `limit`, and
`trigger` for triggered/reactive abilities. Activated/reactive abilities also print
`activation: {energy, resonance}`. `on_condition` requires a bounded
`condition: {resource, at_least}`. Unknown effects, fields, targets, parameters,
conditions and modes fail validation; incorrect JSON numeric enum types are
normalized only after integral/range validation. Card identity and mechanical
fingerprints exclude illustration, name and description updates.

| Category | Implemented generic operations |
|---|---|
| Schaden | `deal_damage` |
| Schutz | `grant_shield`, `grant_block` |
| Heilung | `heal_target` |
| Verstärkung | `modify_attack` |
| Schwächung | `weaken_unit` |
| Bewegung | `move_unit` |
| Beschwörung | `summon_card` of an explicit real creature ID |
| Wiederkehr | `return_card`: newest discarded creature to hand if space exists |
| Ressourcen | `gain_resonance`, `gain_energy` |
| Kartenmanipulation | `draw_cards`, `discard_card` |
| Zeitmanipulation | `delay_damage`, passive `haste` |
| Kontrolle | `stun_unit` |

Side-wide operations require `target: self`; they cannot misleadingly name an
enemy target while changing the owner. Stat-changing unit operations cannot use
hero targets. Delayed damage names a lane explicitly. Equal-rank species matching
checks both creature species. Each matching unit is affected once. Energy remains
capped at 8, resonance at 15, shield/block at 25 and generic attack buffs at 40.
These are technical/rule bounds, not evidence of complete card balance.

**Supported passive is haste, not an arbitrary aura language. Activated abilities
are currently relic abilities, not general clickable creature skills.** The active
catalog uses this implemented subset; unsupported promises must not be authored.

## Automatic triggers and timing

| Trigger | Actual hook |
|---|---|
| `on_play` | After payment/removal and creature/relic placement; before arrival effect |
| `on_summon` | Actual native summon FIFO event, including effect summons; never an extra `on_play` |
| `on_attack` | Before an attack, followed by attacker UID/liveness validation |
| `on_defend` | Before incoming unit/hero damage; attacker is revalidated afterward |
| `on_deal_damage` | Actual positive HP damage caused by the source creature/effect |
| `on_take_damage` | Actual positive HP loss; absorbed shield/block alone does not count |
| `on_kill` | After the defeated unit is removed and its native death queue runs |
| `on_death` | Native death queue, after the card enters discard; each UID once |
| `on_turn_start` | After reset/refill and delayed/convergence boundary, before normal draw |
| `on_turn_end` | After attack phase, before energy clears and control passes |
| `on_lane_change` | Actual shift/tactical/generic movement to a different lane |
| `on_draw` | Each actual card added by draw; capped/empty draws publish nothing |
| `on_discard` | Mandatory burn or explicit discard effect; ordinary playing is not discarding |
| `on_spend_resonance` | Actual printed ability/card cost, recovery, burst, movement or fortification |
| `on_relic_activate` | Accepted actual relic activation |
| `on_condition` | First true check, then false-to-true crossings; once-per-turn limit remains |

A creature's attack/defense/damage/kill/movement triggers refer to that creature.
Its draw/discard/resource/turn/relic watchers observe its own side. A relic observes
its own side's corresponding actions while it remains installed. Arrival follows the same played instance if an `on_play` ability moves it; an
instance removed before arrival receives no surviving arrival trigger. New source
instances receive new UIDs; replacement copies cannot inherit queued abilities.
Haste is consulted by actual attack readiness and convergence control.

Simultaneous watchers publish left-to-right, then the relic, then armed impulses.
Abilities on a card publish in definition order. Native death/summon events keep
native FIFO order. Generic effects publish nested effects into the same FIFO;
reentrant publication does not recursively execute a second queue. A reaction
which defeats or moves an attacker cancels its pending hit. Stasis applied before
a hit consumes that skipped attack once, not a second extra turn.

## Reactions and relics

Reactive impulses pay their printed card cost when armed and the printed ability
cost when triggered. Each player may arm up to three; a triggered card enters
discard once and an untriggered card expires at the next own turn. This is an
**automatic, declared trigger window**, not an interactive hidden interrupt or an
unimplemented priority/pass UI. Creature/relic reactive abilities use the same
printed costs and event ordering.

Only one relic slot exists per side. Installing another relic moves the previous
card to discard. Replacement does not refresh a spent once-per-turn activation.
Passive/triggered effects stop when their source leaves. Activation preflight
checks phase, unresolved selections, energy, resonance, target availability and
slot usage. Slot/source identity is included in deterministic state.

## Targets and safety

Chosen enemy lanes and opposite units bind their UID (or the fact that the lane
was empty and targeted the hero) when published. A replaced, moved, defeated or
newly appeared unit does not inherit the queued effect. Invalidated targets fizzle
without paying an activation cost. Minimum-health selectors choose at resolution,
with leftmost tie breaking; this is distinct from a chosen creature target.

Illegal player commands leave full state, events and RNG unchanged. Costs reserve
only after valid preflight. Sources, targets and costs are checked again before
applying queued effects. Once-per-turn usage is instance-bound. Limits include
1,000 generic effects per chain, 10,000 remembered publications, bounded nested
trigger depth and the native queue's cycle guard. A technical limit stops the
match with a logged error; it is not counted as a successful game or a balance win.

The mandatory attack rule is preserved: an empty directly opposite lane sends the
attack to the opposing hero. Hero block absorbs first, then shield, then HP. New
unit block and shield have distinct displayed/state values and the same absorption
order; temporary unit block expires at the next own turn.

## Verification and scope

`tests/production_engine.gd` uses actual catalog identities and real handlers:

- Every declared generic ability has an explicitly arranged legal boundary fixture.
- Every one of the 550 actual cards is played through `execute("play", ...)` for
  both sides: 1,100 accepted commands with prerequisites, not 1,100 complete games.
- All 16 automatic trigger families execute from real actions for both sides.
- Twelve categories, haste, ten FIFO effects, target/source replacement, direct
  hero attacks, block/shield, costs, reactive expiry, relic replacement and illegal
  command immutability have specific assertions.

Reproduce with the normal repository XDG environment and:

```sh
godot --headless --path . --script tests/production_engine.gd
bash tools/test_trigger_bridge.sh
```

Ability boundary fixtures are not substitutes for full-game simulations, real
mobile-device tests, sufficient balancing data or individual illustration QA.
The source-bound PR #11 lab retains its own tests/status; the production profile
supersedes its three-trigger limitation only when explicitly instantiated.

## Long-match bookkeeping and replay ABI

Production bridge snapshots use version 2 with
`history_algorithm: sha256-event-chain-v1`: start with SHA-256 of the empty string;
for each accepted publication, hash the previous hexadecimal digest, `:`, the UTF-8
byte length of the deduplication key, `:`, and that key. Illegal, duplicate and
preflight-rejected submissions never advance it. The complete deduplication map
still enforces the 10,000-publication limit. Probe copies preserve the digest.
The archived source-bound bridge retains its exact version-1 canonical-map hash.

Only unreachable past-round ability-use keys and departed-source condition latches
are pruned at a real turn boundary. Current-round uses and living-source condition
crossings remain intact. This removes obsolete bookkeeping from new production
snapshots; it changes no card, resource, phase or victory rule.

Published historical event snapshots are immutable. Unchanged hands, decks,
creature records and side dictionaries are shared between records. Every event
still exposes its complete normal Dictionary state and its original sequence.
Validation probes shallow-copy closed history containers while appending their
own rows; a resolving queue uses a deep-copy fallback. Consumers needing mutable
history must explicitly duplicate it. See `ENGINE_PERFORMANCE.md` for measurements.

## Native arrival choices in mixed effect chains

Production retains the native strike/optional-shift handlers and choice commands.
If an arrival already awaits a target or optional shift, later arrivals wait in
one UID-bound FIFO backlog instead of overwriting the existing selection. Choosing
a strike target, moving a creature or skipping a shift drains that backlog until
the next actual choice. The backlog and original choice-source UIDs are included
in snapshots, validation probes and new-match reset; at most 1,000 arrivals wait.

A removed source fizzles with an explicit record. A moved surviving source is
located by UID; a new copy with the same card ID never inherits the queued arrival.
If a strike window has no remaining enemy creature, it applies the existing
empty-board strike-to-hero rule automatically and continues. Each of several
strikes/optional shifts resolves or is skipped separately. Other already queued
native death/automatic effects retain their existing handlers.

Generic `summon_card` now always uses the leftmost free own lane, matching its
printed text. Own-neighbor selectors follow the source's current UID/lane when
alive, or its last lane for death triggers; defeated neighbors are not buff targets.
A later printed ability published after movement captures that current position.

## Lethal-damage priority

Hero HP reaching zero is terminal **before post-damage triggered healing or
reactions**. This applies equally to a direct native attack and a generic impulse;
the same two damage cannot save/defeat a one-HP hero differently according to the
caller. The pre-hit defense/shield window still resolves before damage and can
prevent lethal damage. Nonlethal post-damage healing continues to work.

A creature with zero HP is not a valid `self` heal/buff target. However, an actual
fatal-damage event still publishes that creature's other legitimate damage triggers
(such as giving its hero Block). A captured source capability records the real
side/card/UID while those publications are pending. Its strictly typed context
marker is accepted only against that trusted capture; an arbitrary stale UID cannot
forge it. Captures are cloned/snapshotted while needed and retired after their last
queued publication. Thus a dying creature's hero-Block trigger resolves once both
for native attacks and generic damage, without resurrecting the defeated creature.
These changes are confined to Production; archived Alpha/Legacy behavior is retained.

## Attack reduction and convergence

Reducing attack does not itself cancel an existing convergence binding. The normal
binding refresh checks the actual remaining attack against the player's weakness,
as well as source UID, stasis and summon readiness. Thus attack 4 → 3 leaves a
controlled path bound, while attack 1 → 0 breaks it. The earlier unconditional
break in `weaken_unit` was removed. Regression fixtures use the real damage-triggered
`of-stillwatch-005` for both sides and verify attack, control, binding and identity;
these arranged boundaries are not reported as complete matches.

## Relic watchers and creature-effect kills

`of-neutral-093`, `of-neutral-094` and `of-neutral-095` award resonance when an own
creature defeats a creature. A native attack already notified them; a creature's
printed generic damage incorrectly notified only the creature itself. The latter
now also publishes to the currently installed relic instance. Damage caused by
an impulse or relic does not satisfy the printed own-creature condition. No card
text, cost, resource limit or ordinary attack rule changed.

`tests/production_creature_kill_watchers.gd` compares native attacks, generic
creature damage and actual impulse commands for all three relics and both sides.
Two creature kills in one attack phase still grant only one resonance. Its 18
arranged boundaries produced 90 assertions/12 failures before the fix and 90/0
afterward. The full engine suite still passes 4,425 assertions, 940 ability
fixtures and all 1,100 card/side play commands. These fixtures are separate from
complete-match simulations, which must be rerun on the corrected source hash.
