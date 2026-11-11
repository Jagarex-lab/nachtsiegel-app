# Alpha03 local economy integration

This integrates the staged PR16 managers with `production-550-v1`; it does not introduce a second economy design or change combat rules. All balances are local, untrusted test data. There are no purchases, premium currency, payments, trading, accounts, or server-confirmed ownership.

The user-authorized test selects `cosmetics_first` from `data/economy/analysis/monetization.json`: the existing recurring reward amounts, standard booster price100 gold, and permanent300-essence checkpoints at10/20/30/40 completed matches. Existing onboarding gives300 gold,100 XP,5 boosters and1200 essence; level rewards apply normally. The four existing legal30-card production starters are free, bound entitlements. Onboarding plus target checkpoints provides2400 essence before other milestone rewards, enough for the existing1200-cost legendary plus two400-cost epics. This is an access budget, not evidence of competitive matchup parity. Cosmetic purchase concepts remain unimplemented.

The Alpha test laboratory retains access to all550 cards. `owned_count()` and `validate_owned_deck()` provide advisory collection information; neither the battle kernel nor card rules enforce ownership.

## Host API

```gdscript
const Economy = preload("res://scripts/economy/alpha550_economy.gd")
var economy = Economy.new() # independent user://orafold_alpha03_economy_v2.json
var initialized = economy.configure_profile(session.profile, not session.store.write_blocked)
var panel = preload("res://scenes/economy/alpha550_panel.tscn").instantiate()
panel.configure(economy)
panel.back_requested.connect(show_menu)
```

`configure_profile(profile, migration_allowed=true)` accepts the production profile's `{decks:{slot:{mode,cards,catalog_profile}}}`. It never writes to that profile. On the first economy migration only, legal saved Alpha decks receive any necessary bound copies using the maximum per-card requirement across decks. Existing decks and quarantined recovery data remain intact in their original profile. A blocked source profile prevents initialization. Save failures return`ok:false`; no success screen should be shown.

| Facade method | Contract |
| --- | --- |
| `snapshot()` | Ready/error, local wallet, XP/level, collection summary, boosters, pity, quests, crafting costs, permanent path progress, preserved copies and last saved pack reveal |
| `owned_count(card_id)` | Local playable copies; advisory only |
| `validate_owned_deck(ids)` | Production legality plus missing local copies; host decides whether advisory applies |
| `craft(card_id)` | Existing rarity cost and copy limit, saved before success |
| `buy_pack(pool="standard")` | Gold only; debits and stores unopened pack |
| `open_pack(pool="standard", receipt_id="")` | Consumes stored pack, persists five real cards/RNG/pity/duplicate essence before reveal; optional stable receipt replays exact cards |
| `reward_match(receipt_id, result)` | Stable match ID; dictionary may include `cards_played`0..1000 and UTC integer`day`; commits match/quests/free path together. Remaining fields are hashed for conflict detection. Omitted day is retained on retry. No win claim is server verified. |
| `reward_campaign(receipt_id, payload)` | Only`{reward_id:"campaign_chapter",chapter:1..5}`; existing150 gold/100 XP/one standard pack. Chapter deduplicates independently of request ID. Campaign acknowledges its outbox only after`ok:true`. |

Match IDs must identify one actual completed local battle, including mode/catalog/seed/final digest as supplied by the host. Reopening result UI must reuse the ID. Quest timing uses untrusted local UTC; the permanent free path does not expire or require a login streak.

## Persistence and limits

PR16 schema v2 remains in an independent namespace. Receipts, source IDs, balances, packs, RNG, pity, and collection commit together. Native saves verify temporary bytes, preserve last-good backups, quarantine damaged primary bytes, compare the loaded slot before writing, and serialize writers with an atomic local directory lock. A process interrupted while holding the lock leaves writes blocked for recovery. Newer or foreign profile versions block fallback and preserve their bytes. Failed writes keep the previous in-memory state and cannot report success.

Web saves use one synchronous localStorage envelope, a last-good backup, damaged-primary quarantine, and a stale-envelope comparison before replacement. The exact expressions are tested in Chromium across reload and a second tab. This is local conflict detection, not a distributed transaction or multi-device ownership guarantee. Native crash-lock recovery and truly simultaneous browser-tab writes need further platform testing. Receipt history is retained without pruning and can grow over long test accounts. Mobile device pause/resume and physical Safari storage behavior require separate platform QA.

## Validation

Use Godot4.6.3, `LP_NUM_THREADS=1`, headless CPU, and isolated XDG directories. No full editor import is needed when the repository's immutable import cache is already prepared.

```sh
godot --headless --path . --script tests/economy_alpha550.gd
godot --headless --path . --script tests/economy_config.gd
godot --headless --path . --script tests/economy_core.gd
godot --headless --path . --script tests/economy_ui.gd
python3 -m unittest discover -s tests -p 'economy*_test.py' -v
node --test tests/economy_web_storage.test.cjs
```

Focused real550 integration:660 assertions passed, including all real IDs, four free starters, protected custom migration, two local facade writers/stale-save rejection, native writer contention/retry, exact costs, duplicate essence, pity, reward receipts/reload, saved reveal, failed saves, corruption/backup/quarantine, future primary/backup versions and responsive390×844/1440×900 controls. Configuration:66 assertions passed. Existing Godot core:469 assertions passed. Existing Godot UI:101 assertions passed, including mobile layouts and real touch input. Existing Python suite:40 tests passed, including existing free-path simulations. Actual Chromium storage:1 integration test passed, covering reload, stale second tab, quota and denied storage. Full heavy5000×730-day simulations were not repeated. Panel rendering was checked headlessly; root integration owns visual and Safari QA.

### Full Session completion and application receipts

`godot --headless --path . --script tests/alpha03_match_rewards.gd` passed102 assertions with the root-owned `scripts/alpha/integrated_services.gd`. The test uses the existing production AI policy for hero choices, routes every hero action through the real `Session.command()` journal, and leaves automatic enemy replies on the normal policy. Four fresh production starter matches use seeds8802030..8802033 and difficulty2, followed by deterministic replay verification. No winner, HP, resources, or battle state is arranged.

| Starter | Journal commands | Successful hero play commands | Final round | Actual winner |
| --- | ---: | ---: | ---: | --- |
| houses | 52 | 15 | 25 | hero |
| stillwatch | 40 | 14 | 21 | hero |
| morph | 33 | 12 | 16 | hero |
| ninth | 107 | 39 | 47 | hero |

Checks cover unfinished battles, missing or replaced application-duel eligibility, replay/unsupported contexts, exact command-based play counts, one reward per actual completion, repeated result views, reloaded and stale services, a separate deduplicated campaign chapter reward, and a real future-version ProfileStore propagating `write_blocked` without initializing economy balances or modifying source bytes. The application service must bind a duel with `begin_duel()` immediately after a successful host duel start. Campaign adapters create a different model and never acquire that binding. The copied root service used for this domain-worktree run is deliberately excluded from the economy test commit; integration owns that service.
