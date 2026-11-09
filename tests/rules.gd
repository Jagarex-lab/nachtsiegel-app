extends SceneTree
var assertions := 0
var failures := 0
var arena
func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAIL: ",message)
func _initialize() -> void:
	call_deferred("run")
func reset() -> void:
	arena.hand = [0,1,6,4,2,3]
	arena.deck = []
	arena.allies = [null,null,null,null,null]
	arena.foes = [null,null,null,null,null]
	arena.energy = 10
	arena.summons = 0
	arena.selected = -1
	arena.finished = false
	arena.busy = false
	arena.player_hp = 35
	arena.foe_hp = 35
	arena.streak = 0
	arena.round_number = 1
	arena._refresh()
func unit(index: int) -> Dictionary:
	return arena.CARD_POOL[index].duplicate(true)
func snapshot(game) -> Array:
	return [game.hand,game.deck,game.allies,game.foes,game.energy,game.summons,game.selected,game.finished,game.player_hp,game.foe_hp,game.streak,game.round_number]
func run() -> void:
	var source = load("res://scripts/arena.gd")
	if source == null or not source.can_instantiate():
		printerr("FAIL: Arena cannot instantiate")
		quit(1)
		return
	arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	reset()
	arena._choose_lane(0)
	check(arena.allies[0] == null,"No summon without selection")
	arena._select_card(0)
	arena._choose_lane(0)
	check(arena.allies[0].name == "Aschenwache" and arena.energy == 8 and arena.hand.size() == 5,"Summon spends cost and card")
	arena._select_card(0)
	arena._choose_lane(0)
	check(arena.energy == 8 and arena.hand.size() == 5,"Occupied lane rejects summon")
	arena._choose_lane(1)
	check(arena.summons == 2,"Second summon allowed")
	arena.selected = 1
	arena._choose_lane(2)
	check(arena.allies[2] == null,"Third summon rejected")
	reset()
	arena.selected = 2
	arena._choose_lane(4)
	check(arena.foe_hp == 35 and arena.energy == 10 and arena.hand.size() == 6,"Spell cannot hit empty field or hero")
	arena.foes[4] = unit(1)
	arena._choose_lane(4)
	check(arena.foes[4] == null and arena.energy == 8 and arena.hand.size() == 5,"Spell kills target and spends exactly once")
	reset()
	arena.energy = 1
	arena._select_card(0)
	arena._choose_lane(0)
	check(arena.allies[0] == null and arena.energy == 1,"Insufficient energy rejected")
	reset()
	arena.allies[0] = unit(0)
	arena.foes[0] = unit(1)
	arena._combat_phase(arena.allies,arena.foes,true)
	check(arena.foes[0] == null and arena.allies[0].hp == 4 and arena.foe_hp == 35,"Directional combat hits blocker without retaliation")
	arena._combat_phase(arena.allies,arena.foes,true)
	check(arena.foe_hp == 33,"Unblocked attack hits hero")
	reset()
	arena.foe_hp = 1
	arena.allies[0] = unit(0)
	arena._resolve_turn()
	check(arena.finished and arena.foe_hp == 0,"Hero victory clamps HP and ends duel")
	reset()
	arena.player_hp = 1
	arena.foes[0] = unit(0)
	arena._resolve_turn()
	check(arena.finished and arena.player_hp == 0,"Hero defeat ends duel")
	reset()
	arena.streak = 1
	for i in 3: arena.allies[i] = unit(0)
	arena._resolve_turn()
	check(arena.finished and arena.streak == 2,"Three free paths held twice win")
	reset()
	arena.deck = [0,1,2]
	arena._draw_card()
	check(arena.hand.size() == 6 and arena.deck.size() == 3,"Six card hand limit")
	# Differential regression against the original develop branch rules.
	var random = RandomNumberGenerator.new()
	random.seed = 11082026
	for seed_value in 30:
		reset()
		var baseline = load("res://tests/reference_rules.gd").new()
		arena.rng.seed = seed_value
		baseline.rng.seed = seed_value
		arena.deck = []
		for i in 25: arena.deck.append(random.randi_range(0,6))
		arena.hand = [0,1,2,3]
		arena.energy = 3
		baseline.deck = arena.deck.duplicate()
		baseline.hand = arena.hand.duplicate()
		for turn in 35:
			for attempt in 3:
				if arena.hand.is_empty() or arena.finished: break
				var index = random.randi_range(0,arena.hand.size()-1)
				var lane = random.randi_range(0,4)
				arena.selected = index
				baseline.selected = index
				arena._choose_lane(lane)
				baseline._choose_lane(lane)
				check(snapshot(arena) == snapshot(baseline),"Baseline action parity seed %d turn %d" % [seed_value,turn])
			arena._resolve_turn()
			baseline._end_turn()
			check(snapshot(arena) == snapshot(baseline),"Baseline combat parity seed %d turn %d" % [seed_value,turn])
			if arena.finished: break
		await process_frame
	reset()
	arena._end_turn()
	arena._end_turn()
	check(arena.busy and arena.round_number == 1,"Animation locks duplicate turn input")
	await create_timer(0.6).timeout
	check(not arena.busy and arena.round_number == 2,"Animated end turn resolves exactly once")
	print("RULES: %d assertions, %d failures; 30 baseline differential duels" % [assertions,failures])
	quit(1 if failures else 0)
