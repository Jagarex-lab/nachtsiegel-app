# Alpha 0.3 campaign integration

The existing PR18 provisional campaign is embedded in the production Alpha shell.
Its two chapters, thirteen scenes, two decisions, conditional dialogue, character
knowledge, history and replay remain labelled PROTOTYPE / VORSCHLAG. Integration
does not approve new lore, Eira details, world secrets or the placeholder imagery.
This document supersedes the archived Alpha55 adapter guidance in
`docs/campaign_orafold/INTEGRATION.md` for the Alpha 0.3 entry.

## Host contract

Instantiate `res://scenes/campaign_orafold/campaign_overview.tscn`, call
`configure_host(shared_session, economy.reward_campaign)` before adding it to the
tree, and connect `exit_requested` to the host's main menu. The embedded view
does not change the host's browser canvas scale or document title. It fills its
parent Control. Main menu and Escape from overview emit the exit signal; Escape
from a campaign page opens overview. The host controls placement inside its safe
area and must include `data/campaign_orafold/` and `assets/campaign_orafold/` in its
export.

The battle adapter calls the existing `scripts/alpha/session.gd` with explicit
`production-550-v1`, production starter decks, supported AI and encounter seed.
Session selects the existing production kernel, with 550 cards, thirty-card
decks, thirty HP and five paths. No alternate rules engine or archived55 model
is instantiated. Unknown profiles, custom starting positions and archived rule
requests are rejected. Hero commands use Session's audit/replay and normal
profile behavior. The host should keep this shared Session exclusive while the
campaign is mounted. Replacing its model blocks stale adapter commands; Resume
then restarts the same saved request safely.

## Checkpoints, returns and reward delivery

Campaign state remains in `user://orafold_campaign_v2.json` and the existing web
mirror `orafold.campaign.v2`; schema version remains2, content version is2.
Each completed narrative action saves before moving on. Overview pauses the
active adapter without changing its model. Resume inside the same mounted view
continues that instance. Closing/reopening or reloading starts the persisted
encounter token with the same seed at its prebattle checkpoint. Midbattle state
is not persisted; the battle note explicitly explains this behavior.

Only a current adapter's actual terminal result, or deliberate confirmed
concession, can return through the UI. The manager checks its persisted token.
An unwritable result save preserves the checkpoint and terminal adapter and
leaves Return actionable for retry. Defeat returns to the repeatable encounter;
a new attempt has a new token. Completed chapter replay restores the original
decisions, relationships and knowledge and grants no additional rewards.

Each first completion stages one external outbox entry with payload
`{reward_id:"campaign_chapter",chapter:1}` or chapter2. Both chapter2 endings
share the same reward ID. The receiver is the economy facade's
`reward_campaign(receipt_id,payload) -> Dictionary`; only `{ok:true}` after a
durable receipt authorizes `acknowledge_reward`. These are the existing free
configured chapter rewards, with no paid feature. Failure leaves a visible
pending notice and Retry action. If economy commits but campaign acknowledgement
fails, reopening resends the same key; economy's chapter/receipt deduplication
prevents a second grant. Lore knowledge rewards remain local.

Opening the campaign preserves corrupt primary evidence and displays the load
notice. Backup recovery stays visible after subsequent saves. Future schema or
content versions in either primary or backup are protected from rotation or
downgrade. Existing production and archived save namespaces are not migrated.

## Audio and verification

The view routes narrative and ordered combat presentation events into the
existing `/root/GameAudio`. It creates no players, mixers or audio settings
writer. Campaign/battle music and UI/result cues are optional; muted, suspended
or unavailable audio cannot reject a gameplay action.

`CAMPAIGN_SKIP_IMPORT=1 tools/test_campaign_orafold.sh` runs against a warmed
import cache; the default first imports project assets. The GDScript suites
cover structural/editorial validation, all narrative decision combinations,
save/migration/backup failures, responsive layouts, menu/battle navigation,
confirmed concession and stale return rejection. Actual production battles
exercise legal-command victories and defeat. The integrated flow reloads the
pending token, wins the configured encounter, verifies Session replay, retries a
failed result save through the UI, simulates reward receiver and acknowledgement
failure, reloads/redelivers the receipt, finishes chapter2 and checks replay and
repeat reward isolation. The failure receiver uses persisted test receipts;
economy's own suite verifies its actual facade and store.

The Node check validates the existing browser QA runner's syntax; it is not a
browser execution claim. The Python check verifies packaged story/profile/reward
data. Headless geometry covers360×800,390×844,844×390 and1280×720 in German and
English at100% and130% story text. Production card names/rules text currently
remain German even when story UI is English. No physical iOS/Android acceptance,
new screenshot sign-off or production publication is claimed here.
