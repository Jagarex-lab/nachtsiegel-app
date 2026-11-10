extends SceneTree
## Curated real-card templates: data contracts, full games, and actual shell.
const Catalog = preload("res://scripts/alpha/catalog.gd")
const Model = preload("res://scripts/alpha/model.gd")
const Shell = preload("res://scripts/alpha/shell.gd")
const Session = preload("res://scripts/alpha/session.gd")
const SOURCE := "res://data/card_system/test_decks.json"
const STRATEGIES := ["aggro", "control", "resonance", "shield", "recurrence", "movement", "impulse_combo", "relic", "convergence", "species"]
var assertions := 0
var failures := 0
var games: Array = []

func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)
func counts(ids: Array) -> Dictionary:
	var result: Dictionary = {}
	for id in ids:result[id] = int(result.get(id, 0)) + 1
	return result
func replacement_distance(a: Array, b: Array) -> int:
	var ac := counts(a)
	var bc := counts(b)
	var changed := 0
	for id in ac:changed += maxi(0, int(ac[id]) - int(bc.get(id, 0)))
	return changed
func data_checks(data: Dictionary) -> bool:
	var before := failures
	var catalog = Catalog.new()
	check(data.get("format") == "ORAFOLD-TEST-DECKS" and data.get("schema_version") == 1, "versioned real-card deck format")
	check(data.get("ruleset_id") == Catalog.RULESET_ID, "templates use production Alpha ruleset")
	check(data.get("source_catalog") == "data/alpha/cards.json", "single existing card catalog")
	check(data.get("decks") is Array and data.decks.size() == 10, "exactly ten test decks")
	if not data.get("decks") is Array:return false
	var seen_ids: Dictionary = {}
	var seen_names: Dictionary = {}
	var strategies: Array = []
	for entry in data.decks:
		check(entry is Dictionary, "deck record is structured")
		if not entry is Dictionary:continue
		for field in ["id", "name_de", "strategy", "power", "description_de", "limitations_de"]:
			check(entry.get(field) is String and not str(entry.get(field, "")).is_empty(), "nonempty deck field " + field + " " + str(entry.get("id")))
		check(not seen_ids.has(entry.id), "unique deck ID " + entry.id)
		check(not seen_names.has(entry.name_de), "unique deck name " + entry.name_de)
		seen_ids[entry.id] = true;seen_names[entry.name_de] = true
		check(entry.strategy in STRATEGIES, "known test strategy " + entry.id)
		strategies.append(entry.strategy)
		check(entry.power in catalog.deck_ids(), "one actual nonneutral power " + entry.id)
		check(entry.get("cards") is Array and entry.cards.size() == 30, "exact30 template " + entry.id)
		if not entry.get("cards") is Array:continue
		var validation: Dictionary = catalog.validate(entry.cards)
		check(validation.ok and validation.get("faction") == entry.power, "production catalog accepts deck and declared power " + entry.id)
		var effects: Array = []
		var powers: Dictionary = {}
		var creature_count := 0
		var focused_creatures := 0
		for id in entry.cards:
			var card: Dictionary = catalog.card(str(id))
			check(not card.is_empty(), "existing card only " + str(id))
			if card.is_empty():continue
			check(card.faction in [entry.power, "neutral"], "correct affiliation " + entry.id + str(id))
			if card.faction != "neutral":powers[card.faction] = true
			effects.append(card.effect)
			if card.kind == "creature":
				creature_count += 1
				for type in entry.species_focus:
					if card.species.has(type):focused_creatures += 1;break
		check(powers.size() == 1, "exactly one power plus optional neutrals " + entry.id)
		check(creature_count >= 15, "at least half actual creatures " + entry.id)
		for id in counts(entry.cards):
			var limit := 1 if catalog.card(str(id)).rarity == "legendary" else 3
			check(int(counts(entry.cards)[id]) <= limit, "original copy limit " + entry.id + str(id))
		for id in entry.key_card_ids:check(entry.cards.has(id), "advertised key card present " + entry.id + str(id))
		for effect in entry.focus_effects:check(effects.has(effect), "advertised effect really present " + entry.id + str(effect))
		check(not effects.has("redirect") or effects.has("delay"), "no redirect without an own delay source " + entry.id)
		check(not entry.cards.has("oa-ninth-e01"), "known unsupported-in-legal-deck redirect excluded " + entry.id)
		if entry.strategy == "species":
			check(entry.species_focus == ["human"] and focused_creatures == 28, "28 actual equal-rank Human creatures")
			check(entry.limitations_de.contains("keine implementierten automatischen Artenboni"), "species composition does not advertise nonexistent bonuses")
		else:check(entry.species_focus.is_empty(), "species focus is explicit only where intended " + entry.id)
	var expected := STRATEGIES.duplicate();expected.sort();strategies.sort()
	check(strategies == expected, "all ten required strategies once")
	for i in data.decks.size():
		for j in range(i + 1, data.decks.size()):
			check(replacement_distance(data.decks[i].cards, data.decks[j].cards) >= 9, "templates differ by at least9 copy replacements " + data.decks[i].id + data.decks[j].id)
		for starter in catalog.deck_ids():check(replacement_distance(data.decks[i].cards, catalog.deck(starter)) > 0, "existing starter not duplicated " + data.decks[i].id + starter)
	return failures == before
func make_game(deck: Array, enemy: Array, seed_value: int):
	var m = Model.new()
	if not m.start_alpha(deck, enemy, seed_value, 2):return null
	var exchange: Array = []
	for index in m.state.hero.hand.size():
		if m.catalog.card(m.state.hero.hand[index]).cost > 3:exchange.append(index)
	if not m.mulligan(exchange):return null
	return m
func seeds_for(deck: Array, enemy: Array) -> Array:
	var selected: Array = []
	var seen: Dictionary = {}
	for seed_value in 2048:
		var m = make_game(deck, enemy, seed_value)
		if m == null:check(false, "legal template game can start");return []
		if not seen.has(m.state.coin):
			seen[m.state.coin] = true
			selected.append(seed_value)
		if seen.size() == 2:return selected
	check(false, "deterministic seeds cover both actual first players")
	return []
func card_total(m, side: String) -> int:
	var p: Dictionary = m.state[side]
	var total: int = p.hand.size() + p.deck.size() + p.discard.size() + (1 if p.relic != null else 0)
	for unit in p.lanes:
		if unit != null:total += 1
	return total
func full_games(entries: Array) -> void:
	var catalog = Catalog.new()
	for index in entries.size():
		var entry: Dictionary = entries[index]
		var enemy_power: String = catalog.deck_ids()[index % 4]
		var enemy: Array = catalog.deck(enemy_power)
		var seen_first: Dictionary = {}
		for seed_value in seeds_for(entry.cards, enemy):
			var m = make_game(entry.cards, enemy, seed_value)
			seen_first[m.state.coin] = true
			check(m.choose_origin(2), "origin uses real opening " + entry.id)
			if m.state.stage == "second":
				var last_expensive := -1
				for hand_index in m.state.hero.hand.size():
					if m.catalog.card(m.state.hero.hand[hand_index]).cost > 3:last_expensive = hand_index
				if last_expensive >= 0:check(m.second_exchange(last_expensive), "second player exchange " + entry.id)
				check(m.second_change((int(m.state.origins.hero) + 1) % 5), "second origin choice " + entry.id)
				check(m.finish_opening(), "complete real opening " + entry.id)
			var calls := 0
			while m.state.winner == null and m.state.error.is_empty() and calls < 400:
				m.ai_turn("hero")
				calls += 1
				for side in ["hero", "enemy"]:check(card_total(m, side) == 30, "30-card conservation " + entry.id + side + str(seed_value))
			check(m.state.error.is_empty(), "no engine error " + entry.id + str(seed_value))
			check(m.state.winner in ["hero", "enemy", "draw"], "complete duel; unsupported/censored never counts " + entry.id + str(seed_value))
			games.append({"deck":entry.id, "enemy_power":enemy_power, "seed":seed_value, "first":m.state.coin, "winner":m.state.winner, "round":m.state.round, "calls":calls, "longest_chain":m.longest_chain, "error":m.state.error, "convergence":not m.events.is_empty() and m.events[-1].kind == "convergence_win", "event_sha256":JSON.stringify(m.events, "", true).sha256_text(), "final_state_sha256":JSON.stringify(m.snapshot(), "", true).sha256_text()})
		check(seen_first.size() == 2, "both first positions played " + entry.id)
		print("TEST DECK complete ", entry.id, ": ", seen_first.size(), " first positions")
func settle() -> void:
	for frame in 6:await process_frame
func bounded(control: Control) -> bool:
	return control.is_visible_in_tree() and control.size.x >= 44 and control.size.y >= 44 and Rect2(Vector2.ZERO, Vector2(root.size)).encloses(control.get_global_rect())
func nearest_scroll(node: Node) -> ScrollContainer:
	var current := node.get_parent()
	while current != null:
		if current is ScrollContainer:return current
		current = current.get_parent()
	return null
func shell_checks(entries: Array) -> void:
	# Preserve any earlier test profile. Only work/XDG state is touched by the
	# shell's deliberate preference save; saved deck fixtures must stay intact.
	var profile_existed := FileAccess.file_exists(Session.PROFILE)
	var original_profile := FileAccess.get_file_as_string(Session.PROFILE) if profile_existed else ""
	var app = Shell.new()
	root.add_child(app);await settle()
	var fixture_saved: Dictionary = {}
	for power in Catalog.new().deck_ids():fixture_saved["alpha:" + power] = {"mode":"alpha", "cards":Catalog.new().deck(power), "catalog_profile":Session.PRODUCTION_PROFILE}
	app.session.profile.decks = fixture_saved.duplicate(true)
	app.session.profile.reduced_motion = true
	check(app.session.save_profile(), "valid version2 saved-deck fixture is accepted before loading templates")
	app.mode = "alpha";app.faction = "houses"
	for dimensions in [Vector2i(390, 844), Vector2i(844, 390), Vector2i(320, 568), Vector2i(756, 320)]:
		root.size = dimensions
		app.close_modal();app.open_cards(false);await settle()
		check(app.actions.has("strategy_templates") and bounded(app.actions.strategy_templates), "visible44px template button " + str(dimensions))
		app.actions.strategy_templates.pressed.emit();await settle()
		check(is_instance_valid(app.modal) and bounded(app.actions.modal_close), "template modal has a visible dismissal " + str(dimensions))
		for entry in entries:
			var action := "template_" + str(entry.id)
			check(app.actions.has(action) and is_instance_valid(app.actions[action]) and not app.actions[action].disabled, "all14 realvalid productiontemplate actions " + action + str(dimensions))
		app.close_modal();await settle()
		for entry in entries:
			app.show_test_decks();await settle()
			var action := "template_" + str(entry.id)
			var target: Button = app.actions[action]
			var sc := nearest_scroll(target)
			check(sc != null, "template list scrolls " + action)
			if sc != null:sc.ensure_control_visible(target)
			await settle()
			check(bounded(target), "scrolled template action is visible44px " + action + str(dimensions))
			target.pressed.emit();await settle()
			check(app.deck == entry.cards and app.faction == entry.power and app.deck_tab == "deck", "template loads exact original IDs and selected power " + action + str(dimensions))
			check(app.deck_check().ok and not app.actions.save_deck.disabled, "loaded template passes actual deckbuilder validation " + action)
			check(app.session.profile.decks == fixture_saved, "loading template leaves all previously saved decks unchanged " + action)
			check(not is_instance_valid(app.modal), "loaded template returns to editable decklist " + action)
	app.queue_free();await settle()
	if profile_existed:
		var file := FileAccess.open(Session.PROFILE, FileAccess.WRITE)
		check(file != null, "restore previous test profile")
		if file != null:file.store_string(original_profile);file.close()
	else:check(DirAccess.remove_absolute(ProjectSettings.globalize_path(Session.PROFILE)) == OK, "remove profile created by shell fixture")
func run() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	check(data is Dictionary, "test deck source is valid JSON")
	if not data is Dictionary or not data_checks(data):
		printerr("MASTER550 TEST DECKS: malformed data, no games counted")
		root.get_node("GameAudio").request_quit(1);return
	var mechanical_data_before := FileAccess.get_sha256("res://data/alpha/cards.json")
	full_games(data.decks)
	var active_templates: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/production/test_decks.json"))
	check(active_templates.decks.size()==14,"actualproductiontemplates cover14strategies")
	await shell_checks(active_templates.decks)
	check(games.size() == 20, "twenty full deterministic games")
	check(FileAccess.get_sha256("res://data/alpha/cards.json") == mechanical_data_before, "production cards and starters unchanged")
	DirAccess.make_dir_recursive_absolute("res://work/master550")
	var file := FileAccess.open("res://work/master550/test_decks.json", FileAccess.WRITE)
	check(file != null, "write reproducible test deck artifact")
	if file != null:
		file.store_string(JSON.stringify({"godot_version":Engine.get_version_info().string, "source_sha256":FileAccess.get_sha256(SOURCE), "assertions":assertions, "failures":failures, "games":games}, "\t", true));file.close()
	print("MASTER550 TEST DECKS: %d assertions, %d failures; %d complete games; 10archivedstrategies/20games,2firstpositions,14productiontemplateactions/4actualshellsizes" % [assertions, failures, games.size()])
	root.get_node("GameAudio").request_quit(0 if failures == 0 else 1)
