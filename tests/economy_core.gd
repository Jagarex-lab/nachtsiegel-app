extends SceneTree
const Economy = preload("res://scripts/economy/economy_manager.gd")
const Store = preload("res://scripts/economy/save_adapter.gd")
var assertions := 0
var failures := 0
var base := "user://economy_core_test.json"
func check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)
func clean(path: String) -> void:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	check(Store.decode_web_read('{"status":"missing"}').is_empty(), "only absent web key creates fresh slot")
	for raw in ["", "null", "[]", "{}", "malformed", '{"primary":null}']:
		var decoded: Dictionary = Store.decode_web_read(JSON.stringify({"status": "present", "raw": raw}))
		check(decoded.has("primary") and decoded.primary == null, "invalid present web envelope fails closed")
	check(Store.decode_web_read('{"status":"error"}').get("storage_error", false), "web read denial fails closed")
	check(Store.decode_web_read(null).get("storage_error", false), "bridge read failure fails closed")
	var web_recovery: Dictionary = Store.decode_web_read(JSON.stringify({"status": "present", "raw": JSON.stringify({"primary": null, "backup": {"valid": true}})}))
	check(web_recovery.backup.valid and web_recovery.primary == null, "malformed web primary retains backup candidate")
	clean(base)
	var economy := Economy.new(base)
	check(economy.ready, "default fixture ready")
	if not economy.ready:
		print(economy.last_error)
		quit(1)
		return
	check(economy.catalog.size() == 550, "fixture contains 550 cards")
	var binding_path := base + ".binding"
	clean(binding_path)
	var binding_economy := Economy.new(binding_path)
	var starter_counts: Dictionary = {}
	for deck in binding_economy.catalog_adapter.starters.values():
		var deck_counts: Dictionary = {}
		for id in deck: deck_counts[id] = int(deck_counts.get(id, 0)) + 1
		for id in deck_counts: starter_counts[id] = maxi(int(starter_counts.get(id, 0)), int(deck_counts[id]))
	for id in starter_counts:
		if starter_counts[id] == 2:
			binding_economy.collection.add(binding_economy.state, id, 3, true)
			check(binding_economy.grant_starters().ok, "starter grant after previously crafted bound copies")
			check(binding_economy.state.collection[id].bound == 3, "starter grant never unbinds crafted copies")
			break
	clean(binding_path)
	check(economy.state.wallet.gold == 0 and economy.state.wallet.premium == 0, "initial currency balances")
	economy.config.currencies.currencies.gold.initial_balance = 9
	check(economy.defaults().wallet.gold == 9, "initial balance derives from central config")
	economy.config.currencies.currencies.gold.initial_balance = 0
	check(not economy.buy_booster("poor").ok, "insufficient gold rejected")
	check(not economy.claim_reward("", "onboarding").ok, "blank transaction rejected")
	check(economy.grant_starters().ok, "four starters granted")
	var after_starters: Dictionary = economy.state.duplicate(true)
	check(economy.grant_starters().get("replayed", false), "starter transaction replay")
	check(economy.state == after_starters, "starter replay no mutation")
	check(not economy.grant_starters("starter-different").ok, "starter source cannot repeat")
	var starter_ids: Array = economy.state.collection.keys()
	check(not starter_ids.is_empty(), "starter cards owned")
	check(not economy.salvage("starter-salvage", starter_ids[0], true).ok, "starter bound cards protected")
	for deck in economy.catalog_adapter.starters.values():
		check(deck.size() == 30, "starter30")
		var needed: Dictionary = {}
		for id in deck: needed[id] = int(needed.get(id, 0)) + 1
		for id in needed: check(economy.state.collection[id].count >= needed[id], "starter playable owned count")
	var reward: Dictionary = economy.claim_reward("welcome", "onboarding")
	check(reward.ok, "onboarding reward")
	check(economy.state.wallet.gold == 350, "reward plus level-up gold")
	var reward_state: Dictionary = economy.state.duplicate(true)
	check(economy.claim_reward("welcome", "onboarding").get("replayed", false), "reward retry replay")
	check(economy.state == reward_state, "reward retry exact state")
	check(not economy.claim_reward("different-welcome", "onboarding").ok, "reward source dedup independent tx")
	check(not economy.buy_booster("welcome").ok, "same tx different payload conflict")
	check(not economy.claim_reward("bypass-daily", "daily_play").ok, "daily rewards require activity")
	check(not economy.claim_reward("bypass-milestone", "deck_upgrade_milestone").ok, "milestone rewards require earned level")
	check(not economy.claim_reward("bypass-challenge", "challenge").ok, "achievement rewards require future entitlement adapter")
	check(not economy.claim_reward("campaign-bad", "campaign_chapter", "999").ok, "campaign bounded source")
	check(economy.claim_reward("campaign-one", "campaign_chapter", "1").ok, "campaign source1")
	check(not economy.claim_reward("campaign-one-again", "campaign_chapter", "1").ok, "campaign source dedup")
	var before_failure: Dictionary = economy.state.duplicate(true)
	economy.store.fail_writes = true
	check(not economy.open_booster("failed-open").ok, "failed save rejects booster reveal")
	check(economy.state == before_failure, "save failure rolls back all state incl RNG/pity")
	economy.store.fail_writes = false
	var opened: Dictionary = economy.open_booster("failed-open")
	check(opened.ok and opened.cards.size() == 5, "retry failure opens five cards")
	var open_state: Dictionary = economy.state.duplicate(true)
	check(economy.open_booster("failed-open").cards == opened.cards, "animation retry same cards")
	check(economy.state == open_state, "aborted animation cannot duplicate ownership")
	var reloaded := Economy.new(base)
	if not reloaded.ready: print("RELOAD ERROR: ", reloaded.last_error)
	if reloaded.ready and reloaded.state != economy.state: print("RELOAD RECOVERED BACKUP: ", reloaded.recovered_backup)
	check(reloaded.ready and reloaded.state == economy.state, "save reload roundtrip journal RNG")
	check(reloaded.open_booster("failed-open").cards == opened.cards, "persisted transaction replay")
	for day in range(10):
		for match_index in range(12):
			check(economy.record_activity("match-%d-%d" % [day, match_index], {"type": "match_completed", "day": day, "source_id": "match-source-%d-%d" % [day, match_index]}).ok, "normalized match event")
		check(economy.state.activity.daily_gold == 100, "daily gold cap")
		check(economy.record_activity("variety-%d" % day, {"type": "cards_played", "day": day, "amount": 10, "source_id": "variety-source-%d" % day}).ok, "optional variety activity")
	var activity_before: int = economy.state.wallet.gold
	check(economy.record_activity("alternate-tx", {"type": "match_completed", "day": 0, "source_id": "match-source-0-0"}).get("replayed_source", false), "same logical match different transaction dedup")
	check(economy.state.wallet.gold == activity_before, "source dedup no gold mint")
	check(not economy.record_activity("alternate-conflict", {"type": "match_completed", "day": 1, "source_id": "match-source-0-0"}).ok, "source conflict rejected")
	check(not economy.record_activity("rewind", {"type": "match_completed", "day": 0, "source_id": "rewind"}).ok, "clock rewind rejected")
	check(not economy.record_activity("invalid-activity", {"type": "battle_engine_pointer", "day": 10, "source_id": "bad-event"}).ok, "unknown event rejected")
	check(not economy.record_activity("negative-event", {"type": "cards_played", "day": 10, "amount": -10, "source_id": "negative-event"}).ok, "negative event rejected")
	check(economy.state.progression.level > 1, "levels advanced")
	check(economy.state.quests["weekly_play:0"].claimed, "weekly quest complete")
	check(economy.state.quests["daily_play:0"].claimed, "daily quest complete")
	# Force threshold states in the explicitly untrusted test fixture, then transact.
	economy.state.pity.standard.legendary = 19
	economy.state.pity.standard.epic = 4
	economy.state.boosters.standard += 1
	var forced: Dictionary = economy.open_booster("pity-test")
	check(forced.ok, "threshold open")
	var got_legendary := false
	for card in forced.cards:
		if card.rarity == "legendary": got_legendary = true
	check(got_legendary, "legendary guaranteed by twentieth pack")
	check(economy.state.pity.standard.epic == 0 and economy.state.pity.standard.legendary == 0, "legendary resets both counters")
	economy.state.boosters.standard += 100
	for index in range(100):
		var output: Dictionary = economy.open_booster("monte-packs-%d" % index)
		check(output.ok and output.cards.size() == 5, "five-card booster")
		check(economy.state.pity.standard.legendary < 20 and economy.state.pity.standard.epic < 5, "pity dry-pack bounds")
	var common := ""
	for id in economy.catalog:
		if economy.catalog[id].rarity == "common" and not economy.state.collection.get(id, {}).get("bound", 0):
			common = id
			break
	economy.state.wallet.crafting += 1000
	economy.state.collection[common] = {"count": 0, "bound": 0, "locked": false}
	var before_craft: int = economy.state.wallet.crafting
	check(economy.craft("craft-common", common).ok, "craft card")
	check(economy.state.wallet.crafting == before_craft - int(economy.config.crafting.costs.common), "craft debits full cost")
	check(not economy.salvage("unconfirmed", common).ok, "manual salvage needs confirmation")
	check(not economy.salvage("crafted-bound", common, true).ok, "crafted cards bound")
	# Add an unbound earned copy to exercise protected manual salvage separately.
	economy.collection.add(economy.state, common)
	check(economy.set_deck_reservations("reserve", {common: 2}).ok, "deck reservations adapter")
	check(not economy.salvage("reserved-salvage", common, true).ok, "saved deck copies preserved")
	check(economy.set_deck_reservations("unreserve", {}).ok, "deck reservations cleared")
	economy.state.collection[common].locked = true
	check(not economy.salvage("locked", common, true).ok, "locked card protected")
	economy.state.collection[common].locked = false
	check(economy.salvage("salvage-common", common, true).ok, "manual salvage confirmed")
	check(economy.state.wallet.crafting < before_craft, "craft salvage cycle loses resource")
	economy.state.collection[common].count = 3
	check(not economy.craft("overcap", common).ok, "craft copy cap")
	var before_dup: int = economy.state.wallet.crafting
	economy.collection.add(economy.state, common)
	check(economy.state.collection[common].count == 3, "duplicate capped")
	check(economy.state.wallet.crafting == before_dup + int(economy.config.crafting.salvage.common), "duplicate converts")
	var invalid: Dictionary = economy.state.duplicate(true)
	invalid.wallet.gold = -1
	check(not economy.validate_state(invalid), "negative balance invalid")
	invalid.wallet.gold = 1.5
	check(not economy.validate_state(invalid), "fractional balance invalid")
	invalid = economy.state.duplicate(true)
	invalid.collection["missing-card"] = {"count": 1, "bound": 0, "locked": false}
	check(not economy.validate_state(invalid), "missing catalog ID invalid")
	invalid = economy.state.duplicate(true)
	invalid.wallet.premium = 1
	check(not economy.validate_state(invalid), "disabled premium remains zero")
	invalid = economy.state.duplicate(true)
	invalid.transactions.welcome.result.ok = false
	check(not economy.validate_state(invalid), "journal altered receipt rejected")
	invalid = economy.defaults()
	invalid.sequence = 1
	invalid.transactions = {"": {"request": {}, "result": {"ok": true}, "sequence": 1}}
	invalid.journal = [{"sequence": 1, "previous": "", "hash": ""}]
	check(not economy.validate_state(invalid), "malformed journal missing transaction id rejected safely")
	var migrated: Dictionary = economy.state.duplicate(true)
	migrated.schema_version = 1
	migrated.erase("milestones")
	check(economy.validate_state(economy.migrate(migrated)), "explicit sandbox v1 migration")
	check(economy.migrate({"schema_version": 1, "wins": 999}).is_empty(), "gameplay v1 never imported")
	check(economy.migrate({"schema_version": 999}).is_empty(), "unknown future version rejected")
	check(economy.save(), "save after sandbox test state modifications")
	var writer := FileAccess.open(base, FileAccess.WRITE)
	writer.store_string("malformed")
	writer.close()
	var recovered := Economy.new(base)
	check(recovered.ready and recovered.recovered_backup, "corrupt primary recovers backup")
	writer = FileAccess.open(base + ".bak", FileAccess.WRITE)
	writer.store_string("malformed")
	writer.close()
	var blocked := Economy.new(base)
	check(not blocked.ready, "corrupt both slots fail closed")
	check(not blocked.claim_reward("blocked", "onboarding").ok, "invalid storage prevents grants")
	clean(base)
	print("ECONOMY CORE: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures else 0)
