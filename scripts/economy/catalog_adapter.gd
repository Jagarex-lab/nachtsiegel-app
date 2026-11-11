extends RefCounted
## Read-only catalog boundary. Fixture metadata never enters a combat catalog.
const AlphaCatalog = preload("res://scripts/alpha/catalog.gd")
const ProductionCatalog = preload("res://scripts/production/catalog.gd")
const RARITIES := ["common", "rare", "epic", "legendary"]
const POWERS := ["houses", "stillwatch", "morph", "ninth", "neutral"]
var cards: Dictionary = {}
var starters: Dictionary = {}
var actual_starters: Dictionary = {}
var errors: Array = []
var warnings: Array = []
var catalog_id := ""
var fixture := true

func _init(mode: String = "fixture") -> void:
	if mode == "production550":
		fixture = false
		catalog_id = ProductionCatalog.PROFILE_ID
		var production = ProductionCatalog.new()
		if not production.load_error.is_empty(): errors.append(production.load_error)
		for id in production.cards:
			cards[id] = production.card(id)
			cards[id]["set"] = "core"
		for power in production.deck_ids():
			actual_starters[power] = production.deck(power)
			starters[power] = production.deck(power)
			if not production.validate(starters[power]).ok: errors.append("invalid_production_starter:" + power)
		if cards.size() != 550: errors.append("production_catalog_requires_550_cards")
		_validate()
		return
	var alpha = AlphaCatalog.new()
	for power in alpha.deck_ids():
		actual_starters[power] = alpha.deck(power)
	if mode == "alpha":
		fixture = false
		catalog_id = AlphaCatalog.RULESET_ID
		for id in alpha.cards:
			cards[id] = alpha.card(id)
			cards[id]["set"] = "core"
		starters = actual_starters.duplicate(true)
	elif mode == "fixture":
		catalog_id = "ORAFOLD-ECONOMY-FIXTURE-550-v1"
		var scenario = JSON.parse_string(FileAccess.get_file_as_string("res://data/economy/scenarios.json"))
		if not scenario is Dictionary or not scenario.get("catalog") is Dictionary:
			errors.append("fixture_scenario_missing")
			return
		for rarity in RARITIES:
			var count: int = int(scenario.catalog.rarity_counts.get(rarity, 0))
			for index in count:
				var id := "economy-fixture-%s-%03d" % [rarity, index + 1]
				cards[id] = {"id": id, "name": "Testkarte %s %03d" % [rarity, index + 1], "kind": "creature", "cost": 0, "atk": 0, "hp": 1, "faction": POWERS[index % POWERS.size()], "rarity": rarity, "set": "core", "economy_fixture": true, "description": "Wirtschafts-Testdatensatz. Keine spielbare Karte.", "art": 0}
		# Preserve real starter rarity/copy/overlap shape without pinning evolving IDs.
		var source_to_fixture: Dictionary = {}
		var available: Dictionary = {}
		for id in cards:
			var group: String = cards[id].rarity + ":" + cards[id].faction
			if not available.has(group): available[group] = []
			available[group].append(id)
		var source_ids: Array = alpha.cards.keys()
		source_ids.sort()
		for id in source_ids:
			var card: Dictionary = alpha.cards[id]
			var group: String = card.rarity + ":" + card.faction
			if available.get(group, []).is_empty():
				errors.append("fixture_starter_mapping_exhausted:" + group)
				continue
			source_to_fixture[id] = available[group].pop_front()
		for power in actual_starters:
			starters[power] = []
			for id in actual_starters[power]:
				if source_to_fixture.has(id): starters[power].append(source_to_fixture[id])
		warnings.append("synthetic_metadata_only_not_a_playable_550_card_catalog")
	else:
		errors.append("unknown_catalog_mode:" + mode)
	_validate()

func _validate() -> void:
	for rarity in RARITIES:
		var found := false
		for card in cards.values():
			if card.get("rarity") == rarity:
				found = true
				break
		if not found: errors.append("booster_pool_missing_rarity:" + rarity)
	for power in starters:
		if not starters[power] is Array or starters[power].size() != 30:
			errors.append("invalid_starter_size:" + str(power))
			continue
		var counts: Dictionary = {}
		for id in starters[power]:
			if not cards.has(id):
				errors.append("starter_card_missing:" + str(id))
				continue
			counts[id] = int(counts.get(id, 0)) + 1
			if counts[id] > (1 if cards[id].rarity == "legendary" else 3): errors.append("starter_copy_cap:" + str(id))
	if starters.size() != 4: errors.append("four_starters_required")

func card(id: String) -> Dictionary:
	return cards.get(id, {}).duplicate(true)

func pool(filter: Dictionary = {}) -> Array:
	var result: Array = []
	for id in cards:
		var card_data: Dictionary = cards[id]
		if filter.has("set") and card_data.get("set") != filter.set: continue
		if filter.has("faction") and card_data.get("faction") != filter.faction: continue
		if filter.has("ids") and id not in filter.ids: continue
		result.append(id)
	return result
