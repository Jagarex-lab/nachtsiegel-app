extends SceneTree
## Read-only M3 experiment: the production model is inherited, never copied.
const Model = preload("res://scripts/alpha/model.gd")
const Catalog = preload("res://scripts/alpha/catalog.gd")
const CONDITIONS := [
	{"id":"energy8_res15", "energy_cap":8, "resonance_cap":15},
	{"id":"energy10_res15", "energy_cap":10, "resonance_cap":15},
	{"id":"energy10_res20", "energy_cap":10, "resonance_cap":20},
]
const SEEDS_PER_FIRST_SIDE := 2
const OUTPUT := "res://work/master550/resource_experiments.json"
var assertions := 0
var failures := 0
var records: Array = []
var verification_games := 0

class ResourceModel extends Model:
	var energy_cap := 8
	var resonance_cap := 15
	var metrics: Dictionary = {}
	var _harvest_before := -1
	var _harvest_side := ""
	func _init() -> void:
		super._init()
		for side in ["hero", "enemy"]:
			metrics[side] = {"turns":0, "energy_available":0, "energy_spent":0, "energy_unspent":0, "energy_from_reactions":0, "resonance_gained":0, "resonance_spent":0, "resonance_clipped":0, "resonance_peak":0, "resonance_at_begin_total":0, "bursts":0, "relic_activations":0, "cards_played":{}, "turn_open":false, "turn_recorded":false}
	func _record_resonance(side: String, before: int, requested: int) -> void:
		if side.is_empty():return
		var gained := int(state[side].resonance) - before
		metrics[side].resonance_gained += gained
		metrics[side].resonance_clipped += maxi(0, requested - gained)
		metrics[side].resonance_peak = maxi(int(metrics[side].resonance_peak), int(state[side].resonance))
	func add_res(player: Dictionary, amount: int) -> void:
		var before := int(player.resonance)
		player.resonance = mini(resonance_cap, before + amount)
		var side := ""
		for candidate in ["hero", "enemy"]:
			if state.has(candidate) and is_same(player, state[candidate]):side = candidate
		_record_resonance(side, before, amount)
	func _resolve_death(event: Dictionary) -> void:
		# Harvest is the one gain path that writes min(15, ...) directly in
		# the inherited kernel. Adapt its cap at its existing trace boundary.
		var previous_before := _harvest_before
		var previous_side := _harvest_side
		_harvest_before = int(state[event.side].resonance)
		_harvest_side = str(event.side)
		super._resolve_death(event)
		_harvest_before = previous_before
		_harvest_side = previous_side
	func _record_unspent(side: String) -> void:
		if metrics[side].turn_open and not metrics[side].turn_recorded:
			metrics[side].energy_unspent += int(state[side].energy)
			metrics[side].turn_recorded = true
	func _trace(kind: String, side: String, detail: Dictionary = {}) -> void:
		if kind == "begin":
			# The ordinary own-turn refresh is the only changed energy rule.
			# Apply it before the inherited trace / enemy draw helper runs.
			state[side].energy = mini(energy_cap, int(state[side].turns))
			metrics[side].turns += 1
			metrics[side].energy_available += int(state[side].energy)
			metrics[side].resonance_at_begin_total += int(state[side].resonance)
			metrics[side].turn_open = true
			metrics[side].turn_recorded = false
		elif kind == "harvest" and side == _harvest_side and _harvest_before >= 0:
			var requested := int(catalog.card(str(detail.card_id)).power) + 1
			state[side].resonance = mini(resonance_cap, _harvest_before + requested)
			_record_resonance(side, _harvest_before, requested)
		elif kind == "reaction" and str(detail.get("pair", "")) == "tide>veil":
			metrics[side].energy_available += 1
			metrics[side].energy_from_reactions += 1
		elif kind == "phase_attack":_record_unspent(side)
		elif kind == "burst":
			metrics[side].bursts += 1
			metrics[side].resonance_spent += 8
		elif kind == "recover":metrics[side].resonance_spent += 5
		elif kind == "tactical_move":metrics[side].resonance_spent += 3
		elif kind == "fortify":metrics[side].resonance_spent += 2
		super._trace(kind, side, detail)
	func play(side: String, index: Variant, lane: Variant) -> bool:
		var card: Dictionary = {}
		if state.has(side) and _integer(index) and index >= 0 and index < state[side].hand.size():
			card = catalog.card(state[side].hand[index])
		var ok := super.play(side, index, lane)
		if ok:
			metrics[side].energy_spent += int(card.cost)
			metrics[side].cards_played[card.id] = int(metrics[side].cards_played.get(card.id, 0)) + 1
		return ok
	func activate_relic(side: String) -> bool:
		var ok := super.activate_relic(side)
		if ok:
			metrics[side].energy_spent += 1
			metrics[side].relic_activations += 1
		return ok
	func finish_metrics() -> Dictionary:
		for side in ["hero", "enemy"]:_record_unspent(side)
		return metrics.duplicate(true)

func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)
func make_game(a: String, b: String, seed_value: int, condition: Dictionary, production := false):
	var m = Model.new() if production else ResourceModel.new()
	if not production:
		m.energy_cap = condition.energy_cap
		m.resonance_cap = condition.resonance_cap
	m.start_alpha(m.catalog.deck(a), m.catalog.deck(b), seed_value, 2)
	var exchange: Array = []
	for i in m.state.hero.hand.size():
		if m.catalog.card(m.state.hero.hand[i]).cost > 3:exchange.append(i)
	m.mulligan(exchange)
	return m
func seeds_for(a: String, b: String) -> Array:
	var selected: Array = []
	var counts := {"hero":0, "enemy":0}
	for seed_value in 2048:
		var m = make_game(a, b, seed_value, CONDITIONS[0])
		if counts[m.state.coin] < SEEDS_PER_FIRST_SIDE:
			selected.append(seed_value)
			counts[m.state.coin] += 1
		if counts.hero == SEEDS_PER_FIRST_SIDE and counts.enemy == SEEDS_PER_FIRST_SIDE:return selected
	check(false, "counterbalanced seeds found " + a + "/" + b)
	return []
func complete_game(m) -> void:
	# Same policy as alpha02_balance.gd and the existing production opponent.
	m.choose_origin(2)
	if m.state.stage == "second":
		var highest := -1
		for i in m.state.hero.hand.size():
			if m.catalog.card(m.state.hero.hand[i]).cost > 3:highest = i
		if highest >= 0:m.second_exchange(highest)
		m.second_change((int(m.state.origins.hero) + 1) % 5)
		m.finish_opening()
	var calls := 0
	while m.state.winner == null and m.state.error.is_empty() and calls < 400:
		m.ai_turn("hero")
		calls += 1
func event_hash(m) -> String:
	return JSON.stringify(m.events, "", true).sha256_text()
func record_game(m, a: String, b: String, seed_value: int, condition: Dictionary) -> Dictionary:
	var declarations := 0
	var broken := 0
	for event in m.events:
		if event.kind == "convergence_declared":declarations += 1
		if event.kind == "convergence_failed":broken += 1
	var metrics: Dictionary = m.finish_metrics()
	for side in ["hero", "enemy"]:
		var s: Dictionary = metrics[side]
		check(s.energy_available == s.energy_spent + s.energy_unspent, "energy accounting " + condition.id + "/" + side)
		check(s.resonance_gained - s.resonance_spent == int(m.state[side].resonance), "resonance accounting " + condition.id + "/" + side)
	return {"condition":condition.id, "hero":a, "enemy":b, "seed":seed_value, "first":m.state.coin, "winner":m.state.winner, "round":m.state.round, "declarations":declarations, "broken":broken, "convergence":not m.events.is_empty() and m.events[-1].kind == "convergence_win", "longest_chain":m.longest_chain, "error":m.state.error, "censored":m.state.winner == null, "event_sha256":event_hash(m), "final_state_sha256":JSON.stringify(m.snapshot(), "", true).sha256_text(), "metrics":metrics}
func fixture(condition: Dictionary, side := "hero"):
	var m = make_game("houses", "stillwatch", 42, condition)
	m.state.stage = "battle"
	m.state.coin = side
	m.state.active = side
	m.state.round = 1
	m.state.origins = {"hero":2, "enemy":2}
	for player in ["hero", "enemy"]:
		m.state[player].phase = "main"
		m.state[player].lanes = [null, null, null, null, null]
	return m
func test_boundaries() -> void:
	for condition in CONDITIONS:
		for side in ["hero", "enemy"]:
			var m = fixture(condition, side)
			m.state[side].resonance = 14
			m.add_res(m.state[side], 4)
			check(m.state[side].resonance == mini(condition.resonance_cap, 18), "ordinary resonance cap " + condition.id + side)
			var carried: int = m.state[side].resonance
			m.begin_turn(side)
			check(m.state[side].resonance == carried, "resonance stored across begin " + condition.id + side)
			m = fixture(condition, side)
			var harvest: Dictionary = {}
			for card in m.catalog.all_cards():
				if card.kind == "creature" and card.effect == "harvest":harvest = card;break
			check(not harvest.is_empty(), "real harvest fixture exists")
			m.state[side].resonance = 14
			var dead: Dictionary = m.make_unit(side, harvest, 0)
			dead.hp = 0
			m._resolve_death({"type":"death", "side":side, "lane":0, "unit":dead})
			check(m.state[side].resonance == mini(condition.resonance_cap, 14 + int(harvest.power) + 1), "harvest cap " + condition.id + side)
			m = fixture(condition, side)
			var u: Dictionary = m.make_unit(side, m.catalog.card("oa-houses-c01"), 0)
			m.state[side].lanes[0] = u
			m.state[side].resonance = 14
			var before: Dictionary = m.snapshot()
			check(not m.burst(side, "houses"), "burst still needs15 " + condition.id + side)
			check(before == m.snapshot(), "rejected burst immutable " + condition.id + side)
			m.state[side].resonance = 15
			check(m.burst(side, "houses") and m.state[side].resonance == 7, "burst still costs8 " + condition.id + side)
			for cost in [9, 10]:
				m = fixture(condition, side)
				# In-memory synthetic test record, never saved / included in 55.
				var card: Dictionary = m.catalog.card("oa-neutral-c01")
				card.id = "fixture-energy-" + str(cost)
				card.name = "Synthetischer Kosten-" + str(cost) + "-Test"
				card.cost = cost;card.effect = "haste";card.atk = 1;card.hp = 1
				m.catalog.cards[card.id] = card
				m.state[side].hand = [card.id]
				m.state[side].turns = cost - 1
				check(m.begin_turn(side), "synthetic cost refresh " + condition.id + side + str(cost))
				if m.state[side].phase == "draw":m.finish_draw(side)
				check(m.state[side].energy == mini(cost, int(condition.energy_cap)), "synthetic refreshed energy " + condition.id + side + str(cost))
				before = m.snapshot()
				var playable: bool = int(condition.energy_cap) >= cost
				check(m.play(side, 0, 2) == playable, "synthetic cost reachability " + condition.id + side + str(cost))
				if not playable:check(before == m.snapshot(), "rejected synthetic cost immutable " + condition.id + side + str(cost))
				check(m.catalog.all_cards().size() == 55, "synthetic fixture excluded from actual card pool")
func mechanical_pool() -> Array:
	var pool: Array = []
	for card in Catalog.new().all_cards():
		var definition: Dictionary = {}
		for key in ["id", "faction", "order", "kind", "rarity", "cost", "atk", "hp", "effect", "power"]:definition[key] = card[key]
		pool.append(definition)
	return pool
func summarize() -> Dictionary:
	var result: Dictionary = {}
	for condition in CONDITIONS:
		var s := {"games":0, "hero_wins":0, "enemy_wins":0, "first_wins":0, "draws":0, "convergence_wins":0, "declarations":0, "broken":0, "round_sum":0, "rounds":[], "energy_available":0, "energy_spent":0, "energy_unspent":0, "energy_from_reactions":0, "resonance_gained":0, "resonance_spent":0, "resonance_clipped":0, "resonance_peak":0, "resonance_at_begin_total":0, "own_turns":0, "bursts":0, "relic_activations":0, "card_uses":{}, "longest_chain":0, "engine_errors":0, "censored":0, "nonmirror_power_wins":{}, "nonmirror_power_games":{}}
		for record in records:
			if record.condition != condition.id:continue
			s.games += 1;s.round_sum += int(record.round);s.rounds.append(record.round)
			if record.winner == "hero":s.hero_wins += 1
			elif record.winner == "enemy":s.enemy_wins += 1
			elif record.winner == "draw":s.draws += 1
			if record.winner == record.first:s.first_wins += 1
			if record.convergence:s.convergence_wins += 1
			s.declarations += int(record.declarations);s.broken += int(record.broken)
			s.longest_chain = maxi(s.longest_chain, int(record.longest_chain))
			if not record.error.is_empty():s.engine_errors += 1
			if record.censored:s.censored += 1
			if record.hero != record.enemy:
				for power in [record.hero, record.enemy]:s.nonmirror_power_games[power] = int(s.nonmirror_power_games.get(power, 0)) + 1
				if record.winner in ["hero", "enemy"]:
					var power: String = record[record.winner]
					s.nonmirror_power_wins[power] = int(s.nonmirror_power_wins.get(power, 0)) + 1
			for side in ["hero", "enemy"]:
				var m: Dictionary = record.metrics[side]
				for key in ["energy_available", "energy_spent", "energy_unspent", "energy_from_reactions", "resonance_gained", "resonance_spent", "resonance_clipped", "resonance_at_begin_total", "bursts", "relic_activations"]:s[key] += int(m[key])
				s.own_turns += int(m.turns)
				s.resonance_peak = maxi(s.resonance_peak, int(m.resonance_peak))
				for id in m.cards_played:s.card_uses[id] = int(s.card_uses.get(id, 0)) + int(m.cards_played[id])
		s.rounds.sort()
		s["round_median"] = (float(s.rounds[s.rounds.size()/2-1]) + float(s.rounds[s.rounds.size()/2])) / 2.0
		s["round_mean"] = float(s.round_sum) / float(s.games)
		s["energy_utilization"] = float(s.energy_spent) / float(s.energy_available)
		s["mean_resonance_at_own_begin"] = float(s.resonance_at_begin_total) / float(s.own_turns)
		s["card_ids_played"] = s.card_uses.size()
		s.erase("rounds")
		result[condition.id] = s
	var pairs: Dictionary = {}
	for condition in CONDITIONS.slice(1):
		var changed := {"winner_changes":0, "round_changes":0, "pairs":0}
		for baseline in records:
			if baseline.condition != CONDITIONS[0].id:continue
			for candidate in records:
				if candidate.condition == condition.id and candidate.hero == baseline.hero and candidate.enemy == baseline.enemy and candidate.seed == baseline.seed:
					changed.pairs += 1
					if candidate.winner != baseline.winner:changed.winner_changes += 1
					if candidate.round != baseline.round:changed.round_changes += 1
		pairs[condition.id] = changed
	result["paired_against_baseline"] = pairs
	return result
func run() -> void:
	var initial_pool := mechanical_pool()
	var initial_starters: Dictionary = Catalog.new().source.starters.duplicate(true)
	check(initial_pool.size() == 55, "experiment uses actual55 Alpha cards")
	for card in initial_pool:check(int(card.cost) <= 6, "current card cost at most6 " + str(card.id))
	for deck in Catalog.new().deck_ids():check(Catalog.new().validate(Catalog.new().deck(deck)).ok, "actual30-card starter " + deck)
	test_boundaries()
	# Prove instrumentation does not alter the existing baseline event order
	# or final state, against the real production model on both first sides.
	var baseline_seeds := seeds_for("houses", "ninth")
	var verified_first: Dictionary = {}
	for seed_value in baseline_seeds:
		var probe = make_game("houses", "ninth", seed_value, CONDITIONS[0])
		if verified_first.has(probe.state.coin):continue
		verified_first[probe.state.coin] = true
		var production = make_game("houses", "ninth", seed_value, CONDITIONS[0], true)
		complete_game(probe);complete_game(production);verification_games += 2
		check(probe.snapshot() == production.snapshot(), "baseline exact production final state " + str(seed_value))
		check(event_hash(probe) == event_hash(production), "baseline exact production events " + str(seed_value))
	for a in Catalog.new().deck_ids():
		for b in Catalog.new().deck_ids():
			var seeds := seeds_for(a, b)
			for condition in CONDITIONS:
				for seed_value in seeds:
					var m = make_game(a, b, seed_value, condition)
					complete_game(m)
					var record := record_game(m, a, b, seed_value, condition)
					records.append(record)
					check(record.error.is_empty() and not record.censored, "complete game " + condition.id + a + b + str(seed_value))
			print("RESOURCE matrix completed ", a, "/", b, ": ", records.size(), " games")
	# One independent exact replay per condition (not added to the matrix).
	for condition in CONDITIONS:
		var expected: Dictionary = {}
		for record in records:
			if record.condition == condition.id and record.hero == "houses" and record.enemy == "ninth":expected = record;break
		var m = make_game(expected.hero, expected.enemy, expected.seed, condition)
		complete_game(m);verification_games += 1
		check(expected.event_sha256 == event_hash(m), "deterministic exact event replay " + condition.id)
	check(initial_pool == mechanical_pool(), "production mechanical card definitions unchanged")
	check(initial_starters == Catalog.new().source.starters, "production starter definitions unchanged")
	check(records.size() == 192, "192 paired matrix games")
	var summary := summarize()
	DirAccess.make_dir_recursive_absolute("res://work/master550")
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	check(file != null, "write reproducible resource experiment artifact")
	var source_hashes: Dictionary = {}
	for path in ["scripts/alpha/model.gd", "scripts/alpha/catalog.gd", "scripts/legacy/battle_engine.gd", "scripts/legacy/rng.gd"]:source_hashes[path] = FileAccess.get_sha256("res://" + path)
	var output := {"schema_version":1, "scope":"Actual55-card Alpha pool only; synthetic9/10-cost fixtures are not collection content", "godot_version":Engine.get_version_info().string, "conditions":CONDITIONS, "seeds_per_first_side":SEEDS_PER_FIRST_SIDE, "matrix_games":records.size(), "additional_verification_games":verification_games, "assertions":assertions, "failures":failures, "mechanical_pool_sha256":JSON.stringify(initial_pool, "", true).sha256_text(), "starter_decks_sha256":JSON.stringify(initial_starters, "", true).sha256_text(), "production_source_sha256":source_hashes, "summary":summary, "games":records}
	if file != null:file.store_string(JSON.stringify(output, "\t", true));file.close()
	print("MASTER550 RESOURCES: ", assertions, " assertions; ", failures, " failures; ", records.size(), " matrix games + ", verification_games, " verification games; output ", OUTPUT)
	print(JSON.stringify(summary, "", true))
	quit(0 if failures == 0 else 1)
