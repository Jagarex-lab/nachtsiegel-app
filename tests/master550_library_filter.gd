extends SceneTree
## Pure data-query tests; no claims of UI integration, device QA or new card execution.
const Filter = preload("res://scripts/card_system/library_filter.gd")
const Shell = preload("res://scripts/alpha/shell.gd")
var assertions := 0
var failures := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok: failures += 1; printerr("FAIL: ", label)
func ids(cards: Array) -> Array:
	var result: Array = []
	for card in cards: result.append(card.id)
	return result
func settle() -> void:
	for frame in 5: await process_frame
func tile_ids(app) -> Array:
	var result: Array = []
	for key: String in app.actions:
		if key.begins_with("card_"): result.append(key.trim_prefix("card_"))
	return result
func builder_checks() -> void:
	root.size = Vector2i(390, 844)
	var app = Shell.new(); root.add_child(app); await settle()
	app.mode = "alpha"; app.faction = "houses"; app.open_cards(true); await settle()
	check(app.library_cards().size() == 55 and tile_ids(app).size() == 55, "actual collection renders all 55 cards through filter module")
	app.show_filters(); await settle()
	for id in ["filter_type", "filter_cost", "filter_rarity", "filter_power", "filter_species", "filter_sort", "reset_filters"]:
		check(app.actions.has(id), "existing filter actions retained and new filter action exists: " + id)
	var available_species: Array = Filter.choice_options(app.library_cards()).species
	if available_species.is_empty():
		check(app.actions.filter_species.disabled and app.actions.filter_species.text.contains("noch keine"), "species filter is honestly unavailable when source has no assignments")
	else:
		check(not app.actions.filter_species.disabled, "actual overlay assignments enable species filtering")
		app.actions.filter_species.pressed.emit(); await settle()
		for species_id in available_species: check(app.actions.has("option_filter_species_" + str(species_id)), "only actual known species choices are available")
		app.actions["option_filter_species_" + str(available_species[0])].pressed.emit(); await settle()
		for card in app.library_query().cards: check(Filter.normalized(card).species.has(available_species[0]), "real selected species applies to actual UI")
		app.filter_species = "all"; app.show_filters(); await settle()
	check(app.actions.filter_sort.custom_minimum_size.y >= 44, "sort uses normal accessible button minimum")
	app.actions.filter_sort.pressed.emit(); await settle()
	for sort_id in Filter.SORTS: check(app.actions.has("option_filter_sort_" + sort_id), "all offered sort options are implemented")
	app.actions.option_filter_sort_cost_desc.pressed.emit(); await settle()
	check(app.filter_sort == "cost_desc", "real sort button updates library state")
	check(tile_ids(app) == ids(app.library_query().cards), "actual rendered tile order follows selected energy sort")
	app.show_filters(); await settle(); app.actions.filter_cost.pressed.emit(); await settle()
	var costs: Array = Filter.choice_options(app.library_cards()).cost
	for cost in range(1, 11): check(app.actions.has("option_filter_cost_" + str(cost)) == costs.has(cost), "cost choice is dynamic, not an empty future filter: " + str(cost))
	app.actions.option_filter_cost_2.pressed.emit(); await settle()
	check(app.filter_cost == "2", "existing cost-selection action works")
	for card in app.library_query().cards: check(int(card.cost) == 2, "actual collection cost filter applies")
	app.show_filters(); await settle(); app.actions.filter_type.pressed.emit(); await settle()
	check(app.actions.option_filter_type_creature.text.contains("Wesen") and app.actions.option_filter_type_event.text.contains("Impuls"), "filter shows required three-type terminology")
	app.actions.option_filter_type_event.pressed.emit(); await settle()
	for card in app.library_query().cards: check(card.kind == "event" and int(card.cost) == 2, "two actual UI filters compose")
	app.show_filters(); await settle(); app.actions.reset_filters.pressed.emit(); await settle()
	check(app.filter_cost == "all" and app.filter_type == "all" and app.filter_species == "all" and app.filter_sort == "cost_asc", "reset clears new and existing filter state")
	check(tile_ids(app).size() == 55, "reset restores real full collection")
	app.open_cards(false); await settle()
	check(app.library_cards().size() == 25, "builder keeps selected power plus neutral restriction")
	for card in app.library_cards(): check(card.faction in ["houses", "neutral"], "filter integration preserves deck power rules")
	app.close_modal(); app.queue_free(); await settle()
func run() -> void:
	var alpha: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/alpha/cards.json")).cards
	var pilot: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/card_system/pilot.json")).cards
	var original := JSON.stringify(alpha)
	check(alpha.size() == 55 and pilot.size() == 8, "real source counts, no fake added cards")
	for cards: Array in [alpha, pilot]:
		var selected := Filter.select(cards)
		check(selected.ok and selected.cards.size() == cards.size(), "all existing cards can be queried")
		check(Filter.choice_options(cards).kind == ["creature", "event", "relic"], "only three actual main kinds offered")
		for card in cards:
			var meta := Filter.normalized(card)
			check(meta.power == card.get("faction", card.get("power")), "v1 numeric effect strength never becomes power: " + card.id)
			var found := Filter.select(cards, {"query": card.name})
			check(found.ok and ids(found.cards).has(card.id), "actual full card name searchable: " + card.id)
		for power_id in ["houses", "stillwatch", "morph", "ninth", "neutral"]:
			var found := Filter.select(cards, {"power": power_id})
			check(found.ok, "power filter valid: " + power_id)
			for card in found.cards: check(Filter.normalized(card).power == power_id, "power filter excludes other powers")
		for kind in Filter.KINDS:
			var found := Filter.select(cards, {"kind": kind})
			check(found.ok, "kind filter valid: " + kind)
			for card in found.cards: check(card.kind == kind, "kind matches actual data")
		for rarity in Filter.RARITIES:
			var found := Filter.select(cards, {"rarity": rarity})
			check(found.ok, "rarity filter valid including absent rarity")
			for card in found.cards: check(card.rarity == rarity, "rarity matches actual data")
		for sort_id in ["cost_asc", "cost_desc"]:
			var found := Filter.select(cards, {"sort": sort_id})
			for index in range(1, found.cards.size()):
				var previous := Filter.normalized(found.cards[index - 1]); var current := Filter.normalized(found.cards[index])
				check(previous.cost <= current.cost if sort_id == "cost_asc" else previous.cost >= current.cost, "actual energy sort: " + sort_id)
	check(Filter.choice_options(alpha).species.is_empty(), "no species invented for 55 v1 cards")
	check(Filter.select(alpha, {"species": "human"}).cards.is_empty(), "species filter does not infer humans from a v1 name")
	check(Filter.select(alpha, {"query": "Pflanzen"}).cards.is_empty(), "species search does not invent missing v1 plant tags")
	for card in alpha: check(Filter.normalized(card).species.is_empty(), "every v1 card remains without invented species")
	var choices := Filter.choice_options(pilot)
	check(choices.species == ["human", "construct", "plant", "amalgam", "elemental"], "only real pilot species offered, no empty fake choices")
	check(not Filter.choice_options(alpha).rarity.has("epic"), "absent epic rarity is not offered as populated choice")
	check(Filter.select(pilot, {"species": "human"}).cards.size() == 3, "all actual human pilot memberships")
	check(ids(Filter.select(pilot, {"species": "construct"}).cards) == ["oa-neutral-c03"], "second species is equal membership")
	check(ids(Filter.select(pilot, {"species": "plant"}).cards) == ["oa-morph-c04"], "first species membership")
	check(ids(Filter.select(pilot, {"species": "amalgam"}).cards) == ["oa-morph-c04"], "second species has same query weight")
	check(ids(Filter.select(pilot, {"query": "Konstrukte Schild"}).cards) == ["oa-neutral-c03"], "German species plus ability words search uses AND")
	check(ids(Filter.select(pilot, {"power": "morph", "kind": "creature", "rarity": "common", "species": "plant", "cost": "2", "query": "Resonanz"}).cards) == ["oa-morph-c04"], "all filters compose on real data")
	check(Filter.select(pilot, {"power": "houses", "species": "plant"}).cards.is_empty(), "impossible combination truthfully empty")
	check(Filter.select(alpha, {"kind": "event", "query": "IMPULS"}).cards.size() == 12, "display type name is searchable")
	check(Filter.select(alpha, {"query": "cascade"}).cards.size() == 1, "actual ability ID is searchable")
	check(Filter.select(pilot, {"query": "Beim Beschwören"}).cards.size() == 4, "structured trigger labels searchable")
	check(Filter.select(pilot, {"query": "   "}).cards.size() == pilot.size(), "whitespace query matches all")
	var ties := [{"id": "test-z", "name": "Wache", "kind": "creature", "faction": "neutral", "cost": 2}, {"id": "test-b", "name": "Bote", "kind": "creature", "faction": "neutral", "cost": 2}, {"id": "test-a", "name": "Wache", "kind": "creature", "faction": "neutral", "cost": 2}]
	check(ids(Filter.select(ties).cards) == ["test-b", "test-a", "test-z"], "same cost sorts by name then stable ID")
	check(ids(Filter.select(ties, {"sort": "cost_desc"}).cards) == ["test-b", "test-a", "test-z"], "descending cost retains ascending name/ID tiebreaks")
	var duplicates := [ties[0].duplicate(true), ties[0].duplicate(true)]; duplicates[0].marker = "first"; duplicates[1].marker = "second"
	var stable: Array = Filter.select(duplicates).cards
	check(stable[0].marker == "first" and stable[1].marker == "second", "identical identity views remain stable")
	var copy: Array = Filter.select(alpha).cards; copy[0].name = "Changed only in returned copy"
	check(JSON.stringify(alpha) == original, "queries and returned deep copies do not mutate actual card data")
	for invalid: Dictionary in [{"unknown": true}, {"kind": "anomaly"}, {"species": "dragon"}, {"power": "imaginary"}, {"rarity": "mythic"}, {"cost": "free"}, {"cost": 11}, {"cost": 1.5}, {"query": 9}, {"sort": "random"}]:
		var rejected := Filter.select(alpha, invalid)
		check(not rejected.ok and not rejected.error.is_empty() and rejected.cards.is_empty(), "invalid filter reports explicit error: " + str(invalid))
	check(not Filter.select([{"kind": "anomaly", "id": "unknown-kind"}]).ok, "fourth main type is rejected")
	check(not Filter.select([null]).ok, "malformed source card is rejected without partial output")
	var legacy: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/legacy/cards.json")).cards
	var ash := Filter.select(legacy, {"power": "ash"})
	check(ash.ok and ash.cards.size() == 25, "read-only legacy order fallback does not mistake numeric power")
	check(Filter.choice_options(legacy).species.is_empty(), "legacy compatibility also invents no species")
	await builder_checks()
	print("MASTER550 LIBRARY: %d assertions, %d failures; all 55 active cards + 8 isolated pilots, stable ordering, equal species, exact filters and actual builder integration" % [assertions, failures])
	root.get_node("GameAudio").request_quit(0 if failures == 0 else 1)
