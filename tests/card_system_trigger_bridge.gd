extends SceneTree
## Real headless model/command tests; direct state arrangements are named fixtures.
const Alpha = preload("res://scripts/alpha/model.gd")
const Bridge = preload("res://scripts/card_system/trigger_model.gd")
var assertions := 0
var failures := 0
var pilot: Array = []

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)
func semantic(model) -> Dictionary:
	var result: Dictionary = model.snapshot()
	result.erase("v2_bridge")
	return result
func stamp(model) -> String:
	var extra: Variant = model.trigger_journal if model is Bridge else null
	return JSON.stringify([model.snapshot(), model.events, extra, model.rng.state, model.rng.calls, model._queue], "", true)
func battle(use_bridge := true, bind_cards := true):
	var model = Bridge.new() if use_bridge else Alpha.new()
	if use_bridge and bind_cards: check(model.configure_v2(pilot).ok, "source pilot configuration")
	check(model.start_alpha(model.catalog.deck("houses"), model.catalog.deck("stillwatch"), 12345), "start real Alpha setup")
	# Explicit battle-boundary fixture, not a claimed UI setup or full legal replay.
	model.state.stage = "battle";model.state.coin = "hero";model.state.active = "hero";model.state.round = 11
	model.state.origins = {"hero": 2, "enemy": 2}
	for side in ["hero", "enemy"]:
		var p: Dictionary = model.state[side]
		p.phase = "main";p.pendingDraw = 0;p.drawDone = true;p.energy = 8;p.hp = 20;p.ward = 0;p.block = 0;p.resonance = 0
		p.hand = [];p.discard = [];p.deck = ["oa-neutral-c01", "oa-neutral-c02"]
		p.lanes = [null, null, null, null, null]
	model.events.clear()
	return model
func unit(model, side: String, lane: int, id := "oa-neutral-c02") -> Dictionary:
	var result: Dictionary = model.make_unit(side, model.catalog.card(id), lane)
	result.summoned = false;model.state[side].lanes[lane] = result
	return result
func journal(model, trigger: String, card_id := "") -> Array:
	return model.trigger_journal.filter(func(row): return row.trigger == trigger and (card_id.is_empty() or row.card_id == card_id))
func command(model, name: String, args: Array, label: String) -> void:
	var result: Dictionary = model.execute(name, args)
	check(result.ok and model.state.error.is_empty(), label + ": original command accepted without bridge error")
func run() -> void:
	pilot = JSON.parse_string(FileAccess.get_file_as_string("res://data/card_system/pilot.json")).cards
	configuration_checks()
	pilot_command_checks()
	repeated_impulse_checks()
	queue_identity_checks()
	nested_queue_checks()
	probe_checks()
	resource_and_ownership_checks()
	full_game_checks()
	print("V2 TRIGGER BRIDGE: %d assertions, %d failures; source-bound opt-in, three automatic trigger families, native activation observation, no production Session integration" % [assertions, failures])
	quit(1 if failures else 0)

func configuration_checks() -> void:
	var model = Bridge.new()
	check(model.configure_v2(pilot).ok, "eight real source-bound pilots configure")
	var caps: Dictionary = model.capabilities()
	check(caps.trigger_matrix.size() == 16 and caps.automatic_ability_triggers.size() == 3, "three executable trigger families, sixteen explicit statuses")
	check(caps.trigger_matrix.on_relic_activate == "observation_only" and not caps.production_session_uses_profile, "activation observation is not generalized ability support or production integration")
	for key in caps.trigger_matrix:
		if not key in ["on_play", "on_summon", "on_death", "on_relic_activate"]: check(caps.trigger_matrix[key] == "unsupported", "explicit remaining gap " + key)
	var original_ids: Array = caps.configured_cards.duplicate()
	for case in ["wrong_cost", "wrong_stats", "wrong_original_power", "unsupported_trigger", "resonance_cost", "unknown_card", "duplicate", "wrong_parameters"]:
		var definitions: Array = pilot.duplicate(true)
		match case:
			"wrong_cost": definitions[0].energy_cost += 1
			"wrong_stats": definitions[0].health += 1
			"wrong_original_power": definitions[0].source_binding.power += 1
			"unsupported_trigger": definitions[0].abilities[0].trigger = "on_attack"
			"resonance_cost": definitions[5].resonance_cost = "free"
			"unknown_card": definitions[0].id = "unknown-card"
			"duplicate": definitions.append(definitions[0].duplicate(true))
			"wrong_parameters": definitions[0].abilities[0].params.amount += 1
		check(not model.configure_v2(definitions).ok, "invalid whole configuration rejected " + case)
		check(model.state.is_empty() and model.capabilities().configured_cards == original_ids, "configuration rejection is atomic " + case)
	var unsupported: Dictionary = pilot[0].duplicate(true)
	var source: Dictionary = model.catalog.card("oa-neutral-c01")
	unsupported.id = source.id;unsupported.attack = source.atk;unsupported.health = source.hp;unsupported.energy_cost = source.cost
	unsupported.source_binding.card_id = source.id;unsupported.source_binding.effect = "strike";unsupported.source_binding.power = source.power
	unsupported.abilities = [{"mode": "triggered", "trigger": "on_summon", "effect": "strike", "target": "enemy_unit_or_hero_if_no_units", "params": {"amount": 2}, "limit": "once_per_summon"}]
	check(model.configure_v2([unsupported]).get("reason") == "automatic_target_window_unsupported", "unimplemented chosen-target window rejected before binding")
	model = battle()
	var before := stamp(model)
	check(not model.configure_v2(pilot).ok and stamp(model) == before, "cannot replace bindings during a running game")

func pilot_command_checks() -> void:
	for side in ["hero", "enemy"]:
		for card in pilot:
			var bridge = battle()
			var reference = battle(false)
			for model in [bridge, reference]:
				model.state.active = side;model.state[side].hand = [card.id]
				if card.abilities[0].effect == "recall": model.state[side].discard = ["oa-neutral-c02"]
			command(reference, "play", [side, 0, 2], "reference source play " + side + card.id)
			command(bridge, "play", [side, 0, 2], "opt-in source play " + side + card.id)
			check(semantic(reference) == semantic(bridge), "complete gameplay state equals source " + side + card.id)
			check(journal(bridge, "on_play", card.id).size() == 1, "one actual play event " + side + card.id)
			if card.kind == "creature":
				check(journal(bridge, "on_summon", card.id).size() == 1, "one actual summon event " + side + card.id)
				check(journal(bridge, "on_play", card.id)[0].serial < journal(bridge, "on_summon", card.id)[0].serial, "play before summon " + side + card.id)
				check(bridge.state[side].lanes[2].ward == 1, "native origin shield preserved " + side + card.id)
			if card.kind == "relic":
				command(reference, "activateRelic", [side], "reference activation")
				command(bridge, "activateRelic", [side], "one native opt-in activation")
				check(semantic(reference) == semantic(bridge) and bridge.state[side].resonance == 1, "relic gain and costs not doubled " + side)
				check(journal(bridge, "on_relic_activate").size() == 1 and journal(bridge, "on_relic_activate")[0].status == "observed_native_effect", "activation is observed exactly once " + side)
				var before := stamp(bridge)
				check(not bridge.execute("activateRelic", [side]).ok and stamp(bridge) == before, "second activation rejects without bridge mutation " + side)
			var before := stamp(bridge)
			check(not bridge.execute("play", [side, 99, 2]).ok and stamp(bridge) == before, "illegal play cannot reserve an event or mutate history " + side + card.id)

func repeated_impulse_checks() -> void:
	for side in ["hero", "enemy"]:
		var model = battle()
		model.state.active = side;model.state[side].hp = 10;model.state[side].hand = ["oa-neutral-e02", "oa-neutral-e02"]
		command(model, "play", [side, 0, 0], "first heal copy")
		command(model, "play", [side, 0, 0], "second heal copy at same hand index")
		var entries: Array = journal(model, "on_play")
		check(entries.size() == 2 and entries[0].event_id != entries[1].event_id, "same ID/round/index receives distinct occurrence IDs " + side)
		check(model.state[side].hp == 20 and model.state[side].energy == 4 and model.state[side].discard == ["oa-neutral-e02", "oa-neutral-e02"], "both heal copies really execute and pay once " + side)
		check(entries.all(func(row): return row.status == "applied"), "both distinct effects proved applied " + side)

func queue_identity_checks() -> void:
	var model = battle()
	var old := unit(model, "hero", 0)
	model._resolving = true
	check(model.enqueue({"type": "summon", "side": "hero", "lane": 0, "card_id": old.id}), "native queue accepts and captures current UID")
	var replacement := unit(model, "hero", 0)
	model._resolving = false
	check(model.enqueue_many([]), "drain genuine native queue boundary")
	check(model.state.hero.block == 0 and model.state.hero.lanes[0].uid == replacement.uid, "same-card replacement does not inherit old arrival")
	check(journal(model, "on_summon")[0].status == "fizzled" and journal(model, "on_summon")[0].context.source_uid == old.uid, "stale source is specifically logged by old UID")
	model = battle()
	var source := unit(model, "hero", 0)
	var event := {"type": "summon", "side": "hero", "lane": 0, "card_id": source.id}
	check(model.enqueue_many([event, event]), "duplicate native occurrence handled deterministically")
	check(model.state.hero.block == 3 and journal(model, "on_summon")[1].detail.reason == "duplicate_summon_instance", "same instance summons once, no repeated resource generation")
	model = battle()
	var events: Array = []
	for side in ["hero", "enemy"]:
		for lane in 5:
			var value := unit(model, side, lane)
			events.append({"type": "summon", "side": side, "lane": lane, "card_id": value.id})
	check(model.enqueue_many(events), "ten distinct automatic source arrivals in native FIFO")
	check(model.state.hero.block == 15 and model.state.enemy.block == 15, "all ten automatic effects really apply")
	var entries: Array = journal(model, "on_summon")
	check(entries.size() == 10 and entries.all(func(row): return row.status == "applied"), "ten-plus chain journal has no unsupported/no-op pass")
	for index in 10: check(entries[index].side == ("hero" if index < 5 else "enemy") and entries[index].context.source_lane == index % 5, "deterministic source order " + str(index))
	var before := stamp(model)
	check(not model.enqueue({"type": "death", "side": "hero", "lane": 0, "unit": {"id": "oa-morph-c04", "hp": -1}}), "bound death without actual instance identity rejected")
	check(stamp(model) == before, "malformed death cannot mutate queues/discard/trigger history")

func nested_queue_checks() -> void:
	for side in ["hero", "enemy"]:
		var model = battle()
		model.state.active = side;model.state[side].hand = ["oa-houses-e01"];model.state[side].discard = ["oa-neutral-c02"]
		command(model, "play", [side, 0, 2], "runtime recall enters native summon which republishes runtime arrival")
		check(model.state[side].block == 3 and model.state[side].lanes[2].ward == 1, "nested arrival applies once with original origin shield " + side)
		check(model.state[side].discard == ["oa-houses-e01"] and model.state[side].summons == 0 and model.state[side].attune == null, "effect summon is not counted/attuned/paid as play " + side)
		check(journal(model, "on_play", "oa-neutral-c02").is_empty() and journal(model, "on_summon", "oa-neutral-c02").size() == 1, "effect summon never emits a creature play event " + side)
		var ordered: Array = model.effect_runtime.log.map(func(row): return row.effect)
		check(ordered == ["recall", "guard"], "crossing native/runtime FIFO keeps parent before child " + side)
		model = battle()
		var defending: String = model._other(side)
		model.state.active = side;model.state[side].hand = ["oa-neutral-c01"]
		var target := unit(model, defending, 2, "oa-morph-c04")
		target.hp = 1;target.ward = 0
		command(model, "play", [side, 0, 0], "unbound native strike queues opted-in death")
		if model.state[side].pendingTarget != null: command(model, "chooseStrikeTarget", [side, 2], "native pending target command")
		check(model.state[defending].resonance == 2 and model.state[defending].discard == [target.id], "V2 harvest replaces original harvest without losing death bookkeeping " + side)
		var deaths: Array = journal(model, "on_death")
		check(deaths.size() == 1 and deaths[0].detail.pending_death.card == target.id and deaths[0].detail.pending_death.overkill == 1, "pending-death context copied at the actual queue boundary " + side)
		check(model.pending_death == null, "native pending death is cleared after V2 effect " + side)
		var before := stamp(model)
		check(model.enqueue({"type": "death", "side": defending, "lane": 2, "unit": target}), "already-resolved native death can be safely ignored")
		check(stamp(model) == before, "duplicate death neither discards nor harvests twice " + side)
		model = battle()
		model.state.active = side
		var attacker := unit(model, side, 2)
		attacker.atk = 10
		target = unit(model, defending, 2, "oa-morph-c04");target.hp = 2;target.ward = 0
		command(model, "advanceTurnBoundary", [side], "ordinary original attack resolves opted-in death after isolated preflight")
		check(model.state[defending].resonance == 2 and model.state[defending].discard == [target.id], "ordinary attack death harvests/discards exactly once " + side)
		check(journal(model, "on_death").size() == 1, "probe does not duplicate the actual attack/death hook " + side)
		model = battle()
		var hand: Array = model.state[side].hand.duplicate()
		var energy: int = model.state[side].energy
		check(model.effect_runtime.summon(side, "oa-neutral-c02", 2, "external-effect-summon").ok, "existing explicit summon primitive reaches automatic V2 arrival " + side)
		check(model.state[side].hand == hand and model.state[side].energy == energy and model.state[side].attune == null and model.state[side].summons == 0, "primitive summon has no play side effects " + side)
		check(journal(model, "on_play").is_empty() and journal(model, "on_summon")[0].status == "applied" and model.state[side].block == 3, "external-runtime nested journal reflects final applied result " + side)

func probe_checks() -> void:
	var model = battle()
	model.state.hero.hand = ["oa-neutral-c02"]
	command(model, "play", ["hero", 0, 2], "create preexisting runtime history")
	var before := stamp(model)
	var probe = model._validation_probe()
	check(probe._bindings == model._bindings and not is_same(probe._bindings, model._bindings), "probe owns a separate equivalent binding registry")
	check(probe.effect_runtime._seen == model.effect_runtime._seen and not is_same(probe.effect_runtime._seen, model.effect_runtime._seen), "probe clones rather than shares dedup history")
	check(probe.snapshot() == model.snapshot(), "probe starts with equivalent functional state and counters")
	probe.state.hero.hand = ["oa-neutral-e02"];probe.state.hero.energy = 8
	command(probe, "play", ["hero", 0, 0], "probe dispatches actual configured V2 effect")
	check(stamp(model) == before, "probe events/counters/RNG/effects never escape to live model")
	model.state.hero.phase = "draw";model.state.hero.pendingDraw = 1;model.state.hero.hand = []
	command(model, "finishDraw", ["hero"], "original disposable draw preflight works with bound profile")
	var serial: int = model._trigger_serial
	model.state.enemy.hand = [];model.state.enemy.deck = []
	command(model, "advanceTurnBoundary", ["hero"], "original disposable turn preflight works with bound profile")
	check(model._trigger_serial == serial, "draw/turn boundaries are not falsely claimed as executable trigger hooks")

func resource_and_ownership_checks() -> void:
	var model = battle()
	var runtime: RefCounted = model.effect_runtime
	var lifetime: WeakRef = weakref(model)
	model = null
	check(lifetime.get_ref() == null and runtime.model == null, "model-owned adapter uses weak back-reference without RefCounted cycle")
	check(not runtime.publish("on_summon", "hero", [], {"event_id": "after-owner-free"}).ok, "retained adapter safely rejects after its owner is freed")
	var holder: Array = [battle()]
	runtime = holder[0].effect_runtime
	lifetime = weakref(holder[0])
	runtime.effect_processed.connect(func(_entry: Dictionary): holder[0] = null)
	check(runtime.summon("hero", "oa-neutral-c02", 0, "release-owner-in-callback").ok, "drain retains weak model until synchronous resolution completes")
	check(lifetime.get_ref() == null and runtime.model == null, "temporary resolution ownership is released after returning")
	model = battle()
	runtime = model.effect_runtime
	var once := [false]
	var injected_failure: Callable = func(_entry: Dictionary):
		if not once[0]:
			once[0] = true
			# Explicit fault-injection fixture, not a new gameplay ability.
			model.state.error = "Injected technical failure during effect callback"
	runtime.effect_processed.connect(injected_failure)
	var callback_reply: Dictionary = runtime.summon("hero", "oa-neutral-c02", 0, "callback-error")
	check(not callback_reply.ok and callback_reply.reason == "native_effect_failed", "post-callback technical failure cannot be reported as success")
	check(model.state.hero.block == 0 and journal(model, "on_summon")[0].status == "cancelled", "remaining queued arrival is cancelled after callback failure")
	# This deliberately stateful observer captured its model. Release that test
	# callback explicitly rather than manufacturing a model->signal->model cycle.
	runtime.effect_processed.disconnect(injected_failure)
	injected_failure = Callable()
	model = battle()
	model.state.hero.resonance = 14;model.state.hero.ward = 24
	model.state.hero.hand = ["oa-neutral-c09", "oa-neutral-c03"]
	command(model, "play", ["hero", 0, 0], "automatic weave source")
	command(model, "play", ["hero", 0, 1], "automatic ward source")
	check(model.state.hero.resonance == 15 and model.state.hero.ward == 25, "automatic source effects preserve resonance/shield caps")
	model = battle()
	model.state.hero.hand = ["oa-neutral-r01"]
	command(model, "play", ["hero", 0, 0], "install native relic before explicit Runtime activation")
	var observation_id: String = journal(model, "on_play")[0].event_id
	var activation: Dictionary = pilot[7].abilities[0]
	check(model.effect_runtime.activate("hero", activation, {"event_id": observation_id}).ok, "explicit activation can use an otherwise independent trigger ID namespace")
	check(journal(model, "on_play")[0].status == "no_matching_ability" and journal(model, "on_relic_activate")[0].status == "observed_native_effect", "external Runtime IDs cannot rewrite source play/observation outcomes")
	model = battle()
	for index in 10000: model.effect_runtime._seen["safety-fixture:" + str(index)] = true
	model.state.hero.hand = ["oa-neutral-c02"]
	var reply: Dictionary = model.execute("play", ["hero", 0, 0])
	check(not reply.ok and reply.get("accepted", false) and reply.reason == "effect_resolution_error", "committed command technical failure is not falsely reported as atomic illegal action")
	check(not model.state.error.is_empty() and model.state.hero.energy == 6 and model.state.hero.block == 0, "technical history guard halts explicitly without falling back to original guard")
	var before := stamp(model)
	check(not model.execute("play", ["hero", 0, 1]).ok and stamp(model) == before, "guard failure locks further commands without mutation")
	model = battle()
	for index in 10000: model.effect_runtime._seen["safety-fixture:" + str(index)] = true
	var source := unit(model, "hero", 0)
	var batch := [{"type": "summon", "side": "hero", "lane": 0, "card_id": source.id},
		{"type": "echo", "side": "hero", "remaining": 1},
		{"type": "summon", "side": "hero", "lane": 1, "card_id": "oa-neutral-c01"}]
	check(not model.enqueue_many(batch), "bridge failure returns native queue failure for the whole active drain")
	check(not model.state.error.is_empty() and model._queue.is_empty() and model.state.enemy.hp == 20 and model.state.hero.pendingTarget == null, "native trailing echo/unbound arrival never execute after bridge halt")
	check(model.events.filter(func(row): return row.kind in ["echo", "strike_hero", "strike_pending"]).is_empty(), "no hidden post-error effect in full native protocol")

func open_game(model, seed_value: int, bind := false) -> void:
	if bind: check(model.configure_v2(pilot).ok, "configure source-bound full-game profile")
	check(model.start_alpha(model.catalog.deck("houses"), model.catalog.deck("stillwatch"), seed_value, 2), "start actual full game")
	check(model.mulligan([]) and model.choose_origin(2), "actual opening commands")
	if model.state.stage == "second": check(model.finish_opening(), "actual second-player opening completion")
func full_game_checks() -> void:
	for seed_value in [1, 2]:
		var original = Alpha.new();var opt_out = Bridge.new();var opt_in = Bridge.new();var repeated = Bridge.new()
		open_game(original, seed_value);open_game(opt_out, seed_value);open_game(opt_in, seed_value, true);open_game(repeated, seed_value, true)
		var rounds := 0
		while original.state.winner == null and original.state.error.is_empty() and rounds < 200:
			for model in [original, opt_out, opt_in, repeated]: model.ai_turn("hero")
			rounds += 1
			check(original.snapshot() == opt_out.snapshot() and original.events == opt_out.events, "opt-out complete state and event parity seed %d step %d" % [seed_value, rounds])
			check(semantic(original) == semantic(opt_in), "bound original effects preserve complete gameplay state seed %d step %d" % [seed_value, rounds])
			check(opt_in.snapshot() == repeated.snapshot() and opt_in.events == repeated.events and opt_in.trigger_journal == repeated.trigger_journal, "bound events/state/journal repeat exactly in independent model seed %d step %d" % [seed_value, rounds])
			check(opt_in.state.error.is_empty() and opt_out.state.error.is_empty(), "no optional bridge runtime error")
		check(original.state.winner != null and opt_in.state.winner == original.state.winner, "complete actual AI games conclude identically seed " + str(seed_value))
		check(not opt_in.trigger_journal.is_empty(), "full game really used automatic source hooks")
