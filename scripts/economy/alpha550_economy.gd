extends RefCounted
## Alpha03's local test facade over PR16. Never an authoritative account balance.
const Economy = preload("res://scripts/economy/economy_manager.gd")
const ProductionCatalog = preload("res://scripts/production/catalog.gd")
const SAVE_PATH := "user://orafold_alpha03_economy_v2.json"
var manager: RefCounted
var catalog: Dictionary = {}
var ready := false
var last_error := ""
var migration_blocked := false
var _production: RefCounted
var _legacy_protected_copies := 0

func _init(save_path: String = SAVE_PATH, protected_decks: Dictionary = {}) -> void:
	manager = Economy.new(save_path, "production550")
	catalog = manager.catalog
	_production = ProductionCatalog.new()
	last_error = manager.last_error
	if not protected_decks.is_empty(): configure_profile({"decks":protected_decks})

func configure_profile(profile: Dictionary, migration_allowed := true) -> Dictionary:
	ready = false
	migration_blocked = not migration_allowed
	if migration_blocked:
		last_error = "Alpha-Profil ist gesperrt; vorhandene Daten bleiben unverändert."
		return {"ok":false,"code":"source_profile_blocked","message":last_error}
	if not manager.load_state(): return _finish({"ok":false,"code":"economy_not_ready","message":manager.last_error})
	if not profile.get("decks", {}) is Dictionary: return _finish({"ok":false,"code":"invalid_source_profile"})
	if not manager.state.starters_granted:
		var starters: Dictionary = manager.grant_starters("alpha03:four-free-starters:v1")
		if not starters.ok: return _finish(starters)
	if "alpha03_profile_migrated" not in manager.state.claimed_rewards:
		var copies: Dictionary = {}
		for value in profile.get("decks", {}).values():
			# Archived/invalid decks remain in the source profile's quarantine;
			# only legal production decks create playable local entitlements.
			if not value is Dictionary or value.get("mode") != "alpha": continue
			var ids: Variant = value.get("cards")
			if not _production.validate(ids).ok: continue
			var counts: Dictionary = {}
			for id in ids: counts[id] = int(counts.get(id, 0)) + 1
			for id in counts: copies[id] = maxi(int(copies.get(id, 0)), int(counts[id]))
		var protected: Dictionary = manager.protect_existing_decks("alpha03:profile-migration:v1", copies)
		if not protected.ok: return _finish(protected)
	if manager.state.transactions.has("alpha03:profile-migration:v1"):
		_legacy_protected_copies = int(manager.state.transactions["alpha03:profile-migration:v1"].result.get("protected_copies", 0))
	if manager.config.progression.onboarding_reward not in manager.state.claimed_rewards:
		var welcome: Dictionary = manager.claim_reward("alpha03:onboarding:v1", manager.config.progression.onboarding_reward)
		if not welcome.ok: return _finish(welcome)
	ready = true
	last_error = manager.last_error
	return {"ok":true,"protected_copies":_legacy_protected_copies}

func _finish(result: Dictionary) -> Dictionary:
	if not result.get("ok", false): last_error = str(result.get("message", result.get("code", "economy_error")))
	else: last_error = ""
	return result

func _command_id(kind: String) -> String:
	return "alpha03:%s:%d:%d:%d" % [kind, OS.get_process_id(), Time.get_ticks_usec(), randi()]

func _available() -> bool:
	if not ready or migration_blocked: return false
	if not manager.load_state():
		ready = false
		last_error = manager.last_error
		return false
	return true

func snapshot() -> Dictionary:
	if not _available(): return {"ready":false,"error":last_error,"test_mode":true,"catalog_size":catalog.size()}
	var state: Dictionary = manager.state
	var day := int(Time.get_unix_time_from_system() / 86400.0)
	var tasks: Array = []
	for id in manager.config.quests.definitions:
		var definition: Dictionary = manager.config.quests.definitions[id]
		var period := str(day if definition.period == "daily" else int(day / 7))
		var entry: Dictionary = state.quests.get(id + ":" + period, {"count":0,"claimed":false})
		tasks.append({"id":id,"name":{"daily_play":"Eine Partie abschließen","daily_variety":"10 Karten ausspielen","weekly_play":"10 Partien in dieser Woche"}.get(id,id), "count":entry.count,"target":definition.target,"claimed":entry.claimed,"optional":definition.get("optional", false)})
	var last_open: Array = []
	for index in range(state.journal.size() - 1, -1, -1):
		var transaction: Dictionary = state.transactions[state.journal[index].id]
		if transaction.request.get("type") == "open_booster":
			last_open = transaction.result.cards.duplicate(true)
			break
	return {"ready":true,"error":last_error,"test_mode":true,"trust":state.trust,"model_id":manager.config.model_id,
		"wallet":state.wallet.duplicate(true),"progression":state.progression.duplicate(true),"collection":manager.collection.summary(state),
		"boosters":state.boosters.duplicate(true),"pity":state.pity.duplicate(true),"quests":tasks,
		"protected_path":{"matches":state.activity.matches,"checkpoints":manager.config.target_protection.checkpoints.duplicate(),"essence_per_checkpoint":manager.config.target_protection.essence_per_checkpoint},
		"crafting_costs":manager.config.crafting.costs.duplicate(true),"booster_price_gold":manager.config.booster_pools.pools.standard.price_gold,
		"booster_rules":manager.config.booster_rules.duplicate(true),"legacy_protected_copies":_legacy_protected_copies,
		"cosmetics":state.cosmetics.duplicate(),"last_open_result":last_open,"recovered_backup":manager.recovered_backup}

func owned_count(id: String) -> int:
	if not ready or not manager.ready: return 0
	return int(manager.state.collection.get(id, {}).get("count", 0))

func validate_owned_deck(ids: Array) -> Dictionary:
	var legality: Dictionary = _production.validate(ids)
	if not legality.ok: return legality
	if not _available(): return {"ok":false,"code":"economy_not_ready","message":last_error}
	var counts: Dictionary = {}
	for id in ids: counts[id] = int(counts.get(id, 0)) + 1
	var missing: Dictionary = {}
	for id in counts:
		if owned_count(id) < counts[id]: missing[id] = counts[id] - owned_count(id)
	return {"ok":missing.is_empty(),"missing":missing,"message":"" if missing.is_empty() else "Für dieses Deck fehlen lokale Kartenkopien. Booster oder Essenz schalten sie frei."}

func craft(id: String) -> Dictionary:
	if not _available(): return {"ok":false,"code":"economy_not_ready","message":last_error}
	return _finish(manager.craft(_command_id("craft"), id))

func buy_pack(pool := "standard") -> Dictionary:
	if not _available(): return {"ok":false,"code":"economy_not_ready","message":last_error}
	return _finish(manager.buy_booster(_command_id("buy"), pool))

func open_pack(pool := "standard", receipt_id := "") -> Dictionary:
	if not _available(): return {"ok":false,"code":"economy_not_ready","message":last_error}
	var transaction := _command_id("open") if receipt_id.is_empty() else "alpha03:open:" + receipt_id.sha256_text()
	return _finish(manager.open_booster(transaction, pool))

func reward_match(receipt_id: String, result: Dictionary) -> Dictionary:
	if not _available(): return {"ok":false,"code":"economy_not_ready","message":last_error}
	if receipt_id.is_empty() or receipt_id.length() > 160: return {"ok":false,"code":"invalid_receipt"}
	var cards: Variant = result.get("cards_played", 0)
	if not manager._integer(cards, 1000): return {"ok":false,"code":"invalid_cards_played"}
	var source := "match:" + receipt_id.sha256_text()
	var previous: Dictionary = manager.state.activity_sources.get(source, {}).get("event", {})
	var day: Variant = result.get("day", previous.get("day", int(Time.get_unix_time_from_system() / 86400.0)))
	if not manager._integer(day, 1000000): return {"ok":false,"code":"invalid_day"}
	var identity := result.duplicate(true)
	identity.erase("day")
	var event := {"source_id":source,"day":int(day),"cards_played":int(cards),"result_hash":manager._canonical(identity).sha256_text()}
	return _finish(manager.record_match_receipt("alpha03:" + source, event))

func reward_campaign(receipt_id: String, payload: Dictionary) -> Dictionary:
	if not _available(): return {"ok":false,"code":"economy_not_ready","message":last_error}
	if receipt_id.is_empty() or receipt_id.length() > 160: return {"ok":false,"code":"invalid_receipt"}
	var chapter: Variant = payload.get("chapter")
	if payload.size() != 2 or payload.get("reward_id") != "campaign_chapter" or not manager._integer(chapter, 5) or chapter < 1: return {"ok":false,"code":"invalid_campaign_reward"}
	var response: Dictionary = manager.claim_reward("alpha03:campaign:" + receipt_id.sha256_text(), "campaign_chapter", str(int(chapter)))
	if response.get("code") == "reward_already_claimed": return {"ok":true,"replayed":true,"chapter":int(chapter)}
	return _finish(response)
