extends RefCounted
## Isolated, local UNTRUSTED economy sandbox. No commerce or combat dependencies.
const Config = preload("res://scripts/economy/config.gd")
const Catalog = preload("res://scripts/economy/catalog_adapter.gd")
const Store = preload("res://scripts/economy/save_adapter.gd")
const Collection = preload("res://scripts/economy/collection_manager.gd")
const Booster = preload("res://scripts/economy/booster_manager.gd")
const Crafting = preload("res://scripts/economy/crafting_manager.gd")
const Progression = preload("res://scripts/economy/progression_manager.gd")
const Rewards = preload("res://scripts/economy/reward_manager.gd")
const Quests = preload("res://scripts/economy/quest_manager.gd")
const SCHEMA_VERSION := 2
var state: Dictionary = {}
var config: Dictionary = {}
var catalog: Dictionary = {}
var catalog_adapter: RefCounted
var store: RefCounted
var collection: RefCounted
var booster: RefCounted
var crafting: RefCounted
var progression: RefCounted
var rewards: RefCounted
var quests: RefCounted
var last_error := ""
var ready := false
var recovered_backup := false
var refresh_before_transaction := false
func _init(save_path := "user://orafold_economy_sandbox_v2.json", catalog_mode := "fixture") -> void:
	var settings := Config.new()
	config = settings.data
	if not settings.errors.is_empty():
		last_error = "Invalid economy configuration: " + str(settings.errors)
		return
	catalog_adapter = Catalog.new(catalog_mode)
	refresh_before_transaction = catalog_mode == "production550"
	if refresh_before_transaction:
		# The user-authorized Alpha03 test uses the existing cosmetics_first model.
		# Keep the original sandbox model and its reports reproducible.
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string("res://data/economy/analysis/monetization.json")) != OK or not parser.data is Dictionary:
			last_error = "Alpha03 economy model missing or invalid; no balances initialized"
			return
		var model: Variant = parser.data.get("models", {}).get("cosmetics_first")
		if not model is Dictionary or not model.get("target_protection") is Dictionary or model.get("recurring_gold_multiplier") != 1.0 or model.get("booster_price_gold") != config.booster_pools.pools.standard.price_gold:
			last_error = "Alpha03 economy model is incompatible with the existing reward configuration"
			return
		config["target_protection"] = model.target_protection.duplicate(true)
		config["model_id"] = "cosmetics_first"
	catalog = catalog_adapter.cards
	var catalog_errors: Array = [] if not settings.errors.is_empty() else settings.validate_catalog(catalog_adapter)
	if not settings.errors.is_empty() or not catalog_errors.is_empty():
		last_error = "Invalid economy configuration/catalog: " + str(settings.errors) + str(catalog_errors)
		return
	collection = Collection.new(config, catalog)
	booster = Booster.new(config, catalog)
	crafting = Crafting.new(config, catalog)
	progression = Progression.new(config)
	rewards = Rewards.new(config, collection, progression)
	quests = Quests.new(config, rewards)
	store = Store.new(save_path)
	load_state()
func defaults() -> Dictionary:
	var tokens: Dictionary = {}
	var pity: Dictionary = {}
	var wallet: Dictionary = {}
	for currency in config.currencies.currencies:
		var definition: Dictionary = config.currencies.currencies[currency]
		wallet[currency] = int(definition.initial_balance) if definition.enabled else 0
	for pool in config.booster_pools.pools:
		tokens[pool] = 0
		pity[pool] = {"epic": 0, "legendary": 0}
	return {"schema_version": SCHEMA_VERSION, "trust": "local_untrusted_test_data", "catalog_id": catalog_adapter.catalog_id,
		"wallet": wallet, "collection": {}, "boosters": tokens, "pity": pity,
		"progression": {"xp": 0, "level": 1}, "rng": 123456789, "claimed_rewards": [], "milestones": [],
		"cosmetics": [], "unlocks": [], "starters_granted": false,
		"activity": {"day": 0, "daily_gold": 0, "daily_matches": 0, "matches": 0}, "activity_sources": {}, "reserved_copies": {}, "quests": {}, "transactions": {}, "journal": [], "sequence": 0}
func load_state() -> bool:
	ready = false
	if store == null: return false
	if not store.exists() and not store.exists(true):
		state = defaults()
		ready = true
		return true
	var slots := [_normalize(store.read_slot(false)), _normalize(store.read_slot(true))]
	# A foreign backup must not be overwritten by rotating an older primary.
	for value in slots:
		if value is Dictionary and ((value.has("schema_version") and value.schema_version not in [1, SCHEMA_VERSION]) or (value.has("catalog_id") and value.catalog_id != catalog_adapter.catalog_id)):
			last_error = "Newer or foreign economy profile preserved; writes blocked"
			state = {}
			return false
	for backup in [false, true]:
		var value: Variant = slots[1 if backup else 0]
		var candidate := migrate(value)
		if not candidate.is_empty() and validate_state(candidate):
			state = candidate
			ready = true
			recovered_backup = backup
			store.last_good_data = candidate.duplicate(true)
			last_error = "Recovered last-good backup; latest operation may require retry" if backup else ""
			return true
	last_error = "Invalid economy save and backup; slot blocked without resetting balances"
	state = {}
	return false
func migrate(value: Variant) -> Dictionary:
	if not value is Dictionary: return {}
	var migrated: Dictionary = _normalize(value)
	if migrated.get("schema_version") == 1:
		# The only supported historical sandbox version has identical inventory fields.
		# Gameplay ProgressStore v1 has no wallet/catalog; it must never be imported.
		if not migrated.has("wallet") or not migrated.has("catalog_id"): return {}
		migrated.schema_version = SCHEMA_VERSION
		migrated["milestones"] = migrated.get("milestones", [])
		migrated["activity_sources"] = migrated.get("activity_sources", {})
		migrated["reserved_copies"] = migrated.get("reserved_copies", {})
		migrated["trust"] = "local_untrusted_test_data"
	if migrated.get("schema_version") != SCHEMA_VERSION: return {}
	return migrated
func _normalize(value: Variant) -> Variant:
	if value is float and is_finite(value) and value == floor(value) and absf(value) < 9007199254740992.0: return int(value)
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value: result[key] = _normalize(value[key])
		return result
	if value is Array:
		var result: Array = []
		for entry in value: result.append(_normalize(entry))
		return result
	return value
func _integer(value: Variant, maximum := 1000000000) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= 0 and value <= maximum
func validate_state(value: Dictionary) -> bool:
	var required := defaults()
	for key in required:
		if not value.has(key): return false
		if typeof(value[key]) != typeof(required[key]) and not (_integer(value[key]) and _integer(required[key])): return false
	if value.schema_version != SCHEMA_VERSION or value.trust != "local_untrusted_test_data" or value.catalog_id != catalog_adapter.catalog_id: return false
	if value.wallet.keys().size() != 3: return false
	for key in ["gold", "crafting", "premium"]:
		if not _integer(value.wallet.get(key), int(config.currencies.currencies[key].maximum_balance)): return false
		if not config.currencies.currencies[key].enabled and value.wallet[key] != 0: return false
	if not _integer(value.progression.get("xp")) or value.progression.get("level") != progression.level_for(int(value.progression.xp)): return false
	if not _integer(value.rng, 4294967295) or not _integer(value.sequence): return false
	for id in value.collection:
		if not catalog.has(id) or not value.collection[id] is Dictionary: return false
		var owned: Dictionary = value.collection[id]
		if not _integer(owned.get("count"), collection.cap(id)) or not _integer(owned.get("bound"), int(owned.count)) or not owned.get("locked") is bool: return false
	for id in value.reserved_copies:
		if not catalog.has(id) or not _integer(value.reserved_copies[id], int(value.collection.get(id, {}).get("count", 0))): return false
	for pool in value.boosters:
		if not config.booster_pools.pools.has(pool) or not _integer(value.boosters[pool]): return false
	for pool in value.pity:
		if not config.booster_pools.pools.has(pool) or not value.pity[pool] is Dictionary: return false
		for rarity in ["epic", "legendary"]:
			if not _integer(value.pity[pool].get(rarity), int(config.booster_rules.pity[rarity]) - 1): return false
	for pool in config.booster_pools.pools:
		if not value.boosters.has(pool) or not value.pity.has(pool): return false
	for key in required.activity:
		if not _integer(value.activity.get(key)): return false
	for source in value.activity_sources:
		var receipt: Variant = value.activity_sources[source]
		if not source is String or source.is_empty() or not receipt is Dictionary or not receipt.get("event") is Dictionary or not receipt.get("result") is Dictionary or receipt.result.get("ok") != true: return false
	if int(value.activity.daily_gold) > int(config.progression.match.daily_gold_cap): return false
	for key in value.quests:
		if not key is String or not value.quests[key] is Dictionary or not _integer(value.quests[key].get("count")) or not value.quests[key].get("claimed") is bool: return false
	for key in ["claimed_rewards", "milestones", "cosmetics", "unlocks"]:
		var seen: Dictionary = {}
		for id in value[key]:
			if not id is String or seen.has(id): return false
			seen[id] = true
	if value.transactions.size() != int(value.sequence) or value.journal.size() != int(value.sequence): return false
	var previous := ""
	for index in range(value.journal.size()):
		var entry: Variant = value.journal[index]
		if not entry is Dictionary or entry.get("sequence") != index + 1 or entry.get("previous") != previous: return false
		if not entry.get("id") is String or entry.id.is_empty() or entry.id.length() > 160 or not entry.get("hash") is String: return false
		var tx: Variant = value.transactions.get(entry.get("id", ""))
		if not tx is Dictionary or not tx.get("request") is Dictionary or not tx.get("result") is Dictionary or tx.result.get("ok") != true or tx.get("sequence") != index + 1: return false
		var payload := _canonical({"id": entry.id, "sequence": index + 1, "previous": previous, "request": tx.request, "result": tx.result})
		if entry.get("hash") != payload.sha256_text(): return false
		previous = entry.hash
	return true
func _transact(id: String, request: Dictionary, operation: Callable) -> Dictionary:
	if refresh_before_transaction and not load_state(): return {"ok": false, "code": "economy_not_ready", "message": last_error}
	if not ready: return {"ok": false, "code": "economy_not_ready", "message": last_error}
	if id.is_empty() or id.length() > 160: return {"ok": false, "code": "invalid_transaction_id"}
	if state.transactions.has(id):
		var old: Dictionary = state.transactions[id]
		if old.request != request: return {"ok": false, "code": "transaction_conflict"}
		var replay: Dictionary = old.result.duplicate(true)
		replay["replayed"] = true
		return replay
	var candidate := state.duplicate(true)
	var result: Dictionary = operation.call(candidate)
	if not result.get("ok", false): return result
	_apply_milestones(candidate)
	candidate.sequence += 1
	var previous: String = "" if candidate.journal.is_empty() else candidate.journal[-1].hash
	var payload := _canonical({"id": id, "sequence": candidate.sequence, "previous": previous, "request": request, "result": result})
	candidate.transactions[id] = {"request": request.duplicate(true), "result": result.duplicate(true), "sequence": candidate.sequence}
	candidate.journal.append({"id": id, "sequence": candidate.sequence, "previous": previous, "hash": payload.sha256_text()})
	if not validate_state(candidate): return {"ok": false, "code": "invalid_transaction_state"}
	store.data = candidate
	if not store.save():
		last_error = store.last_error
		store.data = state
		return {"ok": false, "code": "save_failed", "message": last_error}
	state = candidate
	last_error = ""
	return result
func _canonical(value: Dictionary) -> String:
	# JSON loads numbers as float. Normalize once before hashing so disk round trips
	# do not change journal checksums; this is corruption detection, not authentication.
	return JSON.stringify(JSON.parse_string(JSON.stringify(value, "", true)), "", true)
func _apply_milestones(candidate: Dictionary) -> void:
	for milestone in config.progression.get("milestones", []):
		var key := str(milestone.level)
		if candidate.progression.level >= int(milestone.level) and key not in candidate.milestones:
			candidate.milestones.append(key)
			rewards.apply(candidate, config.rewards.definitions[milestone.reward])
func grant_starters(tx_id := "starter:v1") -> Dictionary:
	return _transact(tx_id, {"type": "starters"}, func(candidate: Dictionary) -> Dictionary:
		if candidate.starters_granted: return {"ok": false, "code": "starters_already_granted"}
		var entitlement: Dictionary = {}
		for deck in catalog_adapter.starters.values():
			var counts: Dictionary = {}
			for id in deck: counts[id] = int(counts.get(id, 0)) + 1
			for id in counts: entitlement[id] = maxi(int(entitlement.get(id, 0)), int(counts[id]))
		var cards: Array = []
		for id in entitlement:
			var existing: int = candidate.collection.get(id, {}).get("count", 0)
			cards.append_array(collection.add(candidate, id, maxi(0, int(entitlement[id]) - existing), true))
			candidate.collection[id].bound = maxi(int(candidate.collection[id].bound), int(entitlement[id]))
		candidate.starters_granted = true
		return {"ok": true, "cards": cards})
func claim_reward(tx_id: String, reward_id: String, source_id := "") -> Dictionary:
	return _transact(tx_id, {"type": "reward", "reward": reward_id, "source": source_id}, func(candidate: Dictionary) -> Dictionary:
		if reward_id == "campaign_chapter":
			if not source_id.is_valid_int(): return {"ok": false, "code": "invalid_campaign_source"}
			var chapter := int(source_id)
			if chapter < 1 or chapter > int(config.rewards.campaign_chapter_limit) or str(chapter) != source_id: return {"ok": false, "code": "invalid_campaign_source"}
			var source := "campaign_chapter:" + source_id
			if source in candidate.claimed_rewards: return {"ok": false, "code": "reward_already_claimed"}
			candidate.claimed_rewards.append(source)
			return rewards.apply(candidate, config.rewards.definitions[reward_id])
		if reward_id != config.progression.onboarding_reward: return {"ok": false, "code": "reward_requires_entitlement"}
		return rewards.claim(candidate, reward_id))
func buy_booster(tx_id: String, pool := "standard") -> Dictionary:
	return _transact(tx_id, {"type": "buy_booster", "pool": pool}, func(candidate: Dictionary) -> Dictionary: return booster.buy(candidate, pool))
func open_booster(tx_id: String, pool := "standard") -> Dictionary:
	return _transact(tx_id, {"type": "open_booster", "pool": pool}, func(candidate: Dictionary) -> Dictionary: return booster.open(candidate, pool))
func craft(tx_id: String, id: String) -> Dictionary:
	return _transact(tx_id, {"type": "craft", "card": id}, func(candidate: Dictionary) -> Dictionary: return crafting.craft(candidate, id))
func salvage(tx_id: String, id: String, confirm := false) -> Dictionary:
	return _transact(tx_id, {"type": "salvage", "card": id, "confirmed": confirm}, func(candidate: Dictionary) -> Dictionary: return crafting.salvage(candidate, id, confirm))
func set_deck_reservations(tx_id: String, copies: Dictionary) -> Dictionary:
	return _transact(tx_id, {"type": "deck_reservations", "copies": copies.duplicate(true)}, func(candidate: Dictionary) -> Dictionary:
		for id in copies:
			if not catalog.has(id) or not _integer(copies[id], int(candidate.collection.get(id, {}).get("count", 0))): return {"ok": false, "code": "invalid_deck_reservation"}
		candidate.reserved_copies = copies.duplicate(true)
		return {"ok": true})
func lock_card(tx_id: String, id: String, locked: bool) -> Dictionary:
	return _transact(tx_id, {"type": "lock", "card": id, "locked": locked}, func(candidate: Dictionary) -> Dictionary:
		if not candidate.collection.has(id): return {"ok": false, "code": "card_not_owned"}
		candidate.collection[id].locked = locked
		return {"ok": true})
func record_activity(tx_id: String, event: Dictionary) -> Dictionary:
	return _transact(tx_id, {"type": "activity", "event": event.duplicate(true)}, func(candidate: Dictionary) -> Dictionary:
		var source: Variant = event.get("source_id")
		if not source is String or source.is_empty() or source.length() > 160: return {"ok": false, "code": "invalid_activity_source"}
		if candidate.activity_sources.has(source):
			var receipt: Dictionary = candidate.activity_sources[source]
			if receipt.event != event: return {"ok": false, "code": "activity_source_conflict"}
			var replay: Dictionary = receipt.result.duplicate(true)
			replay["replayed_source"] = true
			return replay
		var result: Dictionary = quests.record(candidate, event)
		if result.get("ok", false): candidate.activity_sources[source] = {"event": event.duplicate(true), "result": result.duplicate(true)}
		return result)

func protect_existing_decks(tx_id: String, copies: Dictionary) -> Dictionary:
	return _transact(tx_id, {"type":"protect_alpha_decks", "copies":copies.duplicate(true)}, func(candidate: Dictionary) -> Dictionary:
		for id in copies:
			if not catalog.has(id) or not _integer(copies[id], collection.cap(id)): return {"ok":false,"code":"invalid_protected_copy"}
		var granted := 0
		for id in copies:
			var missing := maxi(0, int(copies[id]) - int(candidate.collection.get(id, {}).get("count", 0)))
			collection.add(candidate, id, missing, true)
			candidate.collection[id].bound = maxi(int(candidate.collection[id].bound), int(copies[id]))
			candidate.reserved_copies[id] = maxi(int(candidate.reserved_copies.get(id, 0)), int(copies[id]))
			granted += missing
		candidate.claimed_rewards.append("alpha03_profile_migrated")
		return {"ok":true,"protected_copies":granted})

func record_match_receipt(tx_id: String, event: Dictionary) -> Dictionary:
	return _transact(tx_id, {"type":"match_receipt", "event":event.duplicate(true)}, func(candidate: Dictionary) -> Dictionary:
		var source: Variant = event.get("source_id")
		if not source is String or source.is_empty() or source.length() > 160: return {"ok":false,"code":"invalid_activity_source"}
		if candidate.activity_sources.has(source):
			var old: Dictionary = candidate.activity_sources[source]
			if old.event != event: return {"ok":false,"code":"activity_source_conflict"}
			var replay: Dictionary = old.result.duplicate(true)
			replay["replayed_source"] = true
			return replay
		var result: Dictionary = quests.record(candidate, {"type":"match_completed", "day":event.get("day", -1), "amount":1})
		if not result.get("ok", false): return result
		if event.get("cards_played", 0) > 0:
			var variety: Dictionary = quests.record(candidate, {"type":"cards_played", "day":event.day, "amount":event.cards_played})
			if not variety.get("ok", false): return variety
			result.quests.append_array(variety.quests)
		candidate.activity_sources[source] = {"event":event.duplicate(true), "result":result.duplicate(true)}
		return result)
func save() -> bool:
	if not ready or not validate_state(state): return false
	store.data = state
	return store.save()
