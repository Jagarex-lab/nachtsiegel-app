extends RefCounted
## Pure library queries. No inferred species, ownership rules, UI or combat mutation.
const CONTRACT_PATH := "res://data/card_system/registry.json"
const KINDS := ["creature", "event", "relic"]
const RARITIES := ["common", "rare", "epic", "legendary"]
const POWERS := ["houses", "stillwatch", "morph", "ninth", "neutral", "ash", "tide", "thorn", "veil"]
const SORTS := ["cost_asc", "cost_desc", "name_asc"]
const FILTER_KEYS := ["power", "kind", "rarity", "species", "cost", "query", "sort"]
static var _contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT_PATH))

static func species_labels() -> Dictionary:
	var result: Dictionary = {}
	for species_id in _contract.species: result[species_id] = str(_contract.species[species_id].de)
	return result

static func normalized(card: Dictionary) -> Dictionary:
	var power_id := str(card.get("faction", card.get("order", "neutral")))
	# V1 power is numeric effect strength; it must never become faction identity.
	if card.get("power") is String and card.power in POWERS: power_id = card.power
	var species: Array = []
	if card.get("kind") == "creature" and card.get("species") is Array:
		for species_id: Variant in card.species:
			if _contract.species.has(species_id) and not species.has(species_id): species.append(species_id)
	var kind := str(card.get("kind", ""))
	var searchable := [str(card.get("name", "")), str(card.get("description", "")), str(card.get("text_de", "")), str(card.get("effect", "")), kind, str(_contract.kinds.get(kind, ""))]
	for species_id in species:
		searchable.append(str(species_id)); searchable.append(str(_contract.species[species_id].de))
	if card.get("abilities") is Array:
		for ability: Variant in card.abilities:
			if not ability is Dictionary: continue
			searchable.append(str(ability.get("effect", "")))
			var trigger: String = str(ability.get("trigger", ""))
			if _contract.triggers.has(trigger): searchable.append(str(_contract.triggers[trigger].de))
	return {"id": str(card.get("id", "")), "name": str(card.get("name", "")), "power": power_id, "kind": kind,
		"rarity": str(card.get("rarity", "common")), "cost": int(card.get("energy_cost", card.get("cost", 0))),
		"species": species, "search": " ".join(searchable).to_lower()}

static func select(cards: Array, filters: Dictionary = {}) -> Dictionary:
	var reason := validate_filters(filters)
	if not reason.is_empty(): return {"ok": false, "cards": [], "error": reason}
	var selected: Array = []
	var query: String = str(filters.get("query", "")).strip_edges().to_lower()
	var words := query.split(" ", false)
	for index in cards.size():
		if not cards[index] is Dictionary: return {"ok": false, "cards": [], "error": "invalid_card_at:" + str(index)}
		var meta := normalized(cards[index])
		if not meta.kind in KINDS: return {"ok": false, "cards": [], "error": "unknown_card_kind:" + meta.id}
		var matches := true
		for key in ["power", "kind", "rarity"]:
			if filters.get(key, "all") != "all" and meta[key] != filters[key]: matches = false
		if filters.get("species", "all") != "all" and not meta.species.has(filters.species): matches = false
		var cost_filter: Variant = filters.get("cost", "all")
		if not (cost_filter is String and cost_filter == "all") and meta.cost != int(cost_filter): matches = false
		for word in words:
			if not meta.search.contains(word): matches = false; break
		if matches: selected.append({"card": cards[index], "meta": meta, "index": index})
	var sort_id := str(filters.get("sort", "cost_asc"))
	selected.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _before(a, b, sort_id))
	var result: Array = []
	for entry in selected: result.append(entry.card.duplicate(true))
	return {"ok": true, "cards": result, "error": ""}

static func validate_filters(filters: Dictionary) -> String:
	for key in filters:
		if not key in FILTER_KEYS: return "unknown_filter:" + str(key)
	for key in ["power", "kind", "rarity", "species"]:
		var value: Variant = filters.get(key, "all")
		if not value is String: return "invalid_filter:" + key
		var allowed: Array = POWERS if key == "power" else KINDS if key == "kind" else RARITIES if key == "rarity" else _contract.species.keys()
		if value != "all" and not value in allowed: return "invalid_filter:" + key
	var cost: Variant = filters.get("cost", "all")
	if not (cost is String and cost == "all"):
		if not cost is int and not (cost is String and cost.is_valid_int()): return "invalid_filter:cost"
		if int(cost) < 0 or int(cost) > 10: return "invalid_filter:cost"
	if not filters.get("query", "") is String: return "invalid_filter:query"
	if not filters.get("sort", "cost_asc") in SORTS: return "invalid_filter:sort"
	return ""

static func _before(a: Dictionary, b: Dictionary, sort_id: String) -> bool:
	if sort_id != "name_asc" and a.meta.cost != b.meta.cost:
		return a.meta.cost > b.meta.cost if sort_id == "cost_desc" else a.meta.cost < b.meta.cost
	var names := str(a.meta.name).naturalnocasecmp_to(str(b.meta.name))
	if names != 0: return names < 0
	if a.meta.id != b.meta.id: return a.meta.id < b.meta.id
	# Exact same identity views retain their input order as the final stable tie.
	return a.index < b.index

static func choice_options(cards: Array) -> Dictionary:
	var present := {"power": [], "kind": [], "rarity": [], "species": [], "cost": []}
	for card: Variant in cards:
		if not card is Dictionary: continue
		var meta := normalized(card)
		if not meta.kind in KINDS: continue
		for key in ["power", "kind", "rarity", "cost"]:
			if not present[key].has(meta[key]): present[key].append(meta[key])
		for species_id in meta.species:
			if not present.species.has(species_id): present.species.append(species_id)
	var result := {"power": [], "kind": [], "rarity": [], "species": [], "cost": [], "sort": SORTS.duplicate()}
	for key in ["power", "kind", "rarity", "species"]:
		var canonical: Array = POWERS if key == "power" else KINDS if key == "kind" else RARITIES if key == "rarity" else _contract.species.keys()
		for value in canonical:
			if present[key].has(value): result[key].append(value)
	present.cost.sort(); result.cost = present.cost
	return result
