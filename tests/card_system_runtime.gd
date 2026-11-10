extends SceneTree
## Real headless tests of the isolated adapter; not proof of production trigger wiring.
const Model = preload("res://scripts/alpha/model.gd")
const Runtime = preload("res://scripts/card_system/runtime.gd")
const Registry = preload("res://scripts/card_system/registry.gd")
var assertions := 0
var failures := 0
var exercised: Dictionary = {}
var definitions: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func battle():
	var model = Model.new()
	model.start_alpha(model.catalog.deck("houses"), model.catalog.deck("stillwatch"), 12345)
	model.state.stage = "battle"
	model.state.coin = "hero"
	model.state.active = "hero"
	model.state.round = 11
	for side in ["hero", "enemy"]:
		var p: Dictionary = model.state[side]
		p.phase = "main"
		p.energy = 8
		p.resonance = 0
		p.hp = 20
		p.ward = 0
		p.block = 0
		p.lanes = [null, null, null, null, null]
		p.hand = []
		p.discard = []
		p.deck = ["oa-neutral-c01", "oa-neutral-c02"]
	model.events.clear()
	return model

func unit(model, side: String, lane: int, id: String = "oa-neutral-c02") -> Dictionary:
	var value: Dictionary = model.make_unit(side, model.catalog.card(id), lane)
	value.summoned = false
	model.state[side].lanes[lane] = value
	return value

func ability(id: String, params: Dictionary = {}) -> Dictionary:
	var rule: Dictionary = Registry.new().contract.effects[id]
	var result := {"mode": rule.modes[0], "effect": id, "target": rule.targets[0], "params": params, "limit": rule.limits[0]}
	if result.mode == "activated": result.activation = rule.activation.duplicate()
	elif result.mode != "passive": result.trigger = rule.triggers[0]
	return result

func publish(runtime, side: String, value: Dictionary, context: Dictionary = {}) -> Dictionary:
	var ctx := context.duplicate(true)
	if not ctx.has("event_id"): ctx.event_id = "test-" + str(runtime.log.size())
	var result: Dictionary = runtime.activate(side, value, ctx) if value.mode == "activated" else runtime.publish(value.trigger, side, [value], ctx)
	if result.ok and result.processed > 0: exercised[value.effect] = true
	return result

func stamp(model) -> String:
	return JSON.stringify([model.state, model.events, model._queue, model.pending_death, model.rng.state, model.rng.calls], "", true)

func rejected_unchanged(model, result: Dictionary, before: String, label: String) -> void:
	check(not result.ok, label + " rejected")
	check(stamp(model) == before, label + " leaves state/events/queue/RNG unchanged")

func run() -> void:
	definitions = JSON.parse_string(FileAccess.get_file_as_string("res://data/card_system/pilot.json")).cards
	contract_checks()
	pilot_checks()
	creature_effect_comparisons()
	event_and_relic_checks()
	summon_checks()
	selection_and_atomicity_checks()
	queue_checks()
	for id in Registry.SUPPORTED: check(exercised.has(id), "executable test covers supported effect " + id)
	print(JSON.stringify({"suite": "card_system_runtime", "assertions": assertions, "failures": failures, "exercised_effects": exercised.keys(), "production_wired": false}))
	quit(1 if failures else 0)

func pilot_checks() -> void:
	for side in ["hero", "enemy"]:
		for card in definitions:
			var model = battle()
			model.state.active = side
			var runtime = Runtime.new(model)
			var context: Dictionary = {}
			if card.kind == "creature":
				var source := unit(model, side, 2, card.id)
				context = {"source_lane": 2, "source_uid": source.uid}
				if card.abilities[0].trigger == "on_death":
					source.hp = 0
					model.state[side].lanes[2] = null
			elif card.kind == "relic": model.state[side].relic = {"id": card.id}
			else:
				if card.abilities[0].effect == "recall":
					model.state[side].discard = ["oa-neutral-c02"]
					context.target_lane = 2
			check(publish(runtime, side, card.abilities[0], context).ok, "exact authored pilot ability executes " + side + card.id)

func contract_checks() -> void:
	var runtime = Runtime.new(battle())
	var caps: Dictionary = runtime.capabilities()
	check(caps.recognized_triggers.size() == 16, "sixteen canonical trigger IDs recognized")
	check(caps.categories.size() == 12, "twelve category IDs retained")
	check(not caps.production_wired and caps.automatic_hooks.is_empty(), "automatic hook coverage is explicitly absent")
	check(runtime.bind_species(definitions), "pilot species bind separately")
	var dual := {"id": "oa-neutral-c03"}
	check(runtime.matches_species(dual, "human") and runtime.matches_species(dual, "construct"), "both dual species match equally")
	check(not runtime.matches_species(dual, "beast"), "unrelated species does not match")
	for species in runtime.registry.contract.species:
		check(runtime.bind_species([{"kind": "creature", "id": "qa-species", "species": [species]}]), "species accepted " + species)
		check(runtime.matches_species({"id": "qa-species"}, species), "species selector works " + species)
	check(not runtime.bind_species([{"kind": "creature", "id": "qa-species", "species": ["beast", "beast"]}]), "duplicate species rejected")
	check(not runtime.bind_species([{"kind": "creature", "id": "qa-species", "species": ["unknown"]}]), "unknown species rejected")
	var model = runtime.model
	var before := stamp(model)
	var guard := ability("guard", {"amount": 3})
	check(runtime.publish("on_play", "hero", [guard], {"event_id": "distinct"}).processed == 0, "play and summon are distinct")
	check(stamp(model) == before, "unmatched trigger leaves battle unchanged")
	check(runtime.validate_costs("hero", {"energy": 1, "resonance": 1}) == "insufficient_resonance", "insufficient resonance is explicit")
	model.state.hero.resonance = 3
	check(runtime.validate_costs("hero", {"energy": 1, "resonance": 3}).is_empty(), "exact resonance cost validates")
	check(runtime.validate_costs("hero", {"energy": 1, "resonance": -1}) == "invalid_cost", "negative resonance rejected")
	check(runtime.validate_costs("hero", {"energy": 1, "resonance": 1.5}) == "invalid_cost", "fractional resonance rejected")

func creature_effect_comparisons() -> void:
	# Same original primitive/state setup, comparing complete snapshots after the effect.
	# The adapter is given the final amount; original power offsets remain in source_binding.
	var offsets := {"strike": 1, "guard": 2, "ward": 1, "mend": 2, "weave": 1, "drain": 1, "rally": 0, "silence": 0, "draw": 0, "weaken": 0, "pulse": 0}
	for side in ["hero", "enemy"]:
		for effect in offsets:
			var reference = battle()
			var adapted = battle()
			var selected: Dictionary = {}
			for card in reference.catalog.all_cards():
				if card.kind == "creature" and card.effect == effect:
					selected = card
					break
			check(not selected.is_empty(), "reference card for " + effect)
			if selected.is_empty(): continue
			for model in [reference, adapted]:
				model.state.active = side
				unit(model, side, 2, selected.id)
				unit(model, side, 1)
				unit(model, side, 3)
				unit(model, model._other(side), 2).hp = 20
			var params: Dictionary = {}
			if effect == "draw": params.count = 1
			elif effect != "silence": params.amount = int(selected.power) + int(offsets[effect])
			var context := {"source_lane": 2, "source_uid": adapted.state[side].lanes[2].uid}
			if effect == "strike":
				context.target_lane = 2
				context.target_uid = adapted.state[adapted._other(side)].lanes[2].uid
			var runtime = Runtime.new(adapted)
			reference._resolve_summon({"side": side, "card_id": selected.id, "lane": 2})
			if reference.state[side].pendingTarget != null: reference.choose_strike_target(side, 2)
			check(publish(runtime, side, ability(effect, params), context).ok, "adapter effect accepted " + side + effect)
			check(reference.snapshot() == adapted.snapshot(), "complete effect snapshot matches original primitive " + side + effect)
		var model = battle()
		var runtime = Runtime.new(model)
		check(publish(runtime, side, ability("harvest", {"amount": 2}), {"source_uid": 42}).ok, "explicit death publication " + side)
		check(model.state[side].resonance == 2, "death gain exactly once " + side)
		model.state[side].resonance = 14
		publish(runtime, side, ability("weave", {"amount": 15}))
		check(model.state[side].resonance == 15, "resonance cap fifteen " + side)
		model.state[side].ward = 24
		publish(runtime, side, ability("ward", {"amount": 30}))
		check(model.state[side].ward == 25, "hero shield cap twenty-five " + side)
		model.state[side].hp = 29
		publish(runtime, side, ability("mend", {"amount": 30}))
		check(model.state[side].hp == 30, "healing capped at maximum " + side)

func event_and_relic_checks() -> void:
	for side in ["hero", "enemy"]:
		var model = battle()
		model.state.active = side
		var runtime = Runtime.new(model)
		var other: String = model._other(side)
		model.state[other].block = 2
		model.state[other].ward = 3
		check(publish(runtime, side, ability("bolt", {"amount": 7}), {"target_lane": 2}).ok, "empty lane bolt accepted " + side)
		check(model.state[other].hp == 18 and model.state[other].block == 0 and model.state[other].ward == 0, "empty opposite hero hit absorbs block then shield " + side)
		var creature := unit(model, other, 2)
		creature.ward = 2
		check(publish(runtime, side, ability("bolt", {"amount": 3}), {"target_lane": 2, "target_uid": creature.uid}).ok, "unit damage accepted " + side)
		check(creature.hp == 3 and creature.ward == 0, "unit shield is absorbed before HP " + side)
		publish(runtime, side, ability("bolt", {"amount": 30}), {"target_lane": 2, "target_uid": creature.uid})
		check(model.state[other].lanes[2] == null and model.state[other].discard == [creature.id], "original death queue removes and discards once " + side)
		model.state[side].discard = ["oa-neutral-c03", "oa-neutral-e02", "oa-neutral-c02"]
		check(publish(runtime, side, ability("recall"), {"target_lane": 4}).ok, "recall accepted " + side)
		check(model.state[side].lanes[4].id == "oa-neutral-c02" and model.state[side].lanes[4].summoned and model.state[side].block == 3, "recall latest creature and execute original summon effect " + side)
		check(model.state[side].discard == ["oa-neutral-c03", "oa-neutral-e02"], "recall preserves other discard order " + side)
		check(publish(runtime, side, ability("heal", {"amount": 5})).ok and model.state[side].hp == 25, "impulse healing " + side)
		var target := unit(model, other, 2)
		var selection := {"target_lane": 2, "target_uid": target.uid}
		check(publish(runtime, side, ability("stasis", {"count": 2}), selection).ok and target.stun == 2, "stasis " + side)
		check(publish(runtime, side, ability("displace"), selection).ok and model.state[other].lanes[1] == target and model.state[other].lanes[2] == null, "displace chooses left free neighbor " + side)
		var own := unit(model, side, 2)
		check(publish(runtime, side, ability("surge"), {"target_lane": 2, "target_uid": own.uid}).ok and own.extra_attacks == 1, "extra attack " + side)
		check(publish(runtime, side, ability("delay", {"amount": 3, "turn_changes": 2}), {"target_lane": 0}).ok, "delayed hit scheduled " + side)
		check(model.state.delayed == [{"side": side, "lane": 0, "due": 13, "power": 3}], "delay uses original round boundary " + side)
		check(publish(runtime, side, ability("redirect"), {"target_lane": 3}).ok and model.state.delayed[0].lane == 3, "oldest delay redirected " + side)
		model.state[other].block = 20
		check(publish(runtime, side, ability("cascade", {"count": 12})).ok and model.state[other].block == 8, "twelve original queued echo hits " + side)
		for effect in ["relic_res", "relic_ward", "relic_heal", "relic_draw"]:
			var id := ""
			for card in model.catalog.all_cards():
				if card.effect == effect: id = card.id; break
			model.state[side].relic = {"id": id}
			model.state[side].relic_used = false
			var before_energy: int = model.state[side].energy
			var params: Dictionary = {"count": 1} if effect == "relic_draw" else {"amount": 1 if effect == "relic_res" else 2}
			check(publish(runtime, side, ability(effect, params)).ok, "native relic activation " + side + effect)
			check(model.state[side].energy == before_energy - 1 and model.state[side].relic_used, "original relic energy and once flag " + side + effect)
			var before := stamp(model)
			rejected_unchanged(model, publish(runtime, side, ability(effect, params)), before, "repeat relic activation " + side + effect)
		# Ordinary lane attacks remain the authoritative engine rule, not an adapter reimplementation.
		model = battle()
		unit(model, side, 0).atk = 7
		model.state[other].block = 2
		model.state[other].ward = 3
		model.attack_phase(side)
		check(model.state[other].hp == 18, "existing direct hero attack retained " + side)

func selection_and_atomicity_checks() -> void:
	var model = battle()
	var runtime = Runtime.new(model)
	var guard := ability("guard", {"amount": 3})
	var before := stamp(model)
	var malformed := guard.duplicate(true)
	malformed.params.unrecognized = 4
	rejected_unchanged(model, runtime.publish("on_summon", "hero", [guard, malformed], {"event_id": "mixed"}), before, "entire mixed batch")
	malformed = guard.duplicate(true)
	malformed.params.amount = -1
	rejected_unchanged(model, publish(runtime, "hero", malformed), before, "negative parameter")
	malformed.params.amount = 1.5
	rejected_unchanged(model, publish(runtime, "hero", malformed), before, "fractional parameter")
	malformed.effect = "imaginary_effect"
	rejected_unchanged(model, publish(runtime, "hero", malformed), before, "unknown effect")
	for effect in ["shift", "pierce", "retaliate", "haste", "summon"]:
		var value := ability(effect)
		rejected_unchanged(model, runtime.publish("on_summon", "hero", [value], {"event_id": effect}), before, "unsupported is not a passed effect " + effect)
	rejected_unchanged(model, runtime.publish("not_a_trigger", "hero", [guard], {"event_id": "bad-trigger"}), before, "unknown trigger")
	rejected_unchanged(model, runtime.publish("on_summon", "nobody", [guard], {"event_id": "bad-side"}), before, "unknown side")
	rejected_unchanged(model, runtime.publish("on_summon", "hero", [guard], {"event_id": "bad-lane", "target_lane": 5}), before, "off-board context")
	var target := unit(model, "enemy", 2, "oa-neutral-c03")
	runtime.bind_species(definitions)
	for species in ["human", "construct"]:
		check(publish(runtime, "hero", ability("stasis", {"count": 1}), {"target_lane": 2, "target_uid": target.uid, "target_species": species}).ok, "target accepts dual species " + species)
	before = stamp(model)
	rejected_unchanged(model, publish(runtime, "hero", ability("stasis", {"count": 1}), {"target_lane": 2, "target_uid": target.uid, "target_species": "beast"}), before, "wrong target species")
	rejected_unchanged(model, publish(runtime, "hero", ability("stasis", {"count": 1}), {"target_lane": 2, "target_uid": target.uid + 100}), before, "stale target identity")
	rejected_unchanged(model, publish(runtime, "hero", ability("stasis", {"count": 1}), {"target_lane": 2}), before, "missing target UID")
	rejected_unchanged(model, publish(runtime, "hero", ability("recall"), {"target_lane": 0}), before, "empty recall pile")
	model.state.hero.hand = ["oa-neutral-c02", "oa-neutral-c02", "oa-neutral-c02", "oa-neutral-c02", "oa-neutral-c02", "oa-neutral-c02"]
	check(publish(runtime, "hero", ability("draw", {"count": 1})).ok and model.state.hero.hand.size() == 6, "original draw respects hand cap")
	model.state.hero.hand = []
	model.state.hero.deck = []
	model.state.hero.discard = ["oa-neutral-c02"]
	check(publish(runtime, "hero", ability("draw", {"count": 1})).ok and model.state.hero.fatigue == 0 and model.state.hero.discard.size() == 1, "effect draw does not invent fatigue/recycle")
	model.state.hero.relic = {"id": "oa-neutral-r01"}
	var costly := ability("relic_res", {"amount": 1})
	costly.activation.resonance = 1
	before = stamp(model)
	rejected_unchanged(model, publish(runtime, "hero", costly), before, "unapproved activation cost model")

func summon_checks() -> void:
	for side in ["hero", "enemy"]:
		var model = battle()
		var runtime = Runtime.new(model)
		model.state.origins[side] = 2
		model.state[side].attune = "houses"
		var original_hand: Array = model.state[side].hand.duplicate()
		var original_energy: int = model.state[side].energy
		check(runtime.summon(side, "oa-neutral-c02", 2, "summon-one").ok, "source-explicit effect summon " + side)
		check(model.state[side].lanes[2].id == "oa-neutral-c02" and model.state[side].lanes[2].summoned and model.state[side].lanes[2].ward == 1, "summon preserves origin shield and delay " + side)
		check(model.state[side].block == 3 and model.state[side].summons == 0, "arrival effect fires without counting as played card " + side)
		check(model.state[side].hand == original_hand and model.state[side].energy == original_energy and model.state[side].attune == "houses", "effect summon preserves hand, energy and attunement " + side)
		check(runtime.log[0].trigger == "effect_summon", "no synthetic play event " + side)
		var before := stamp(model)
		rejected_unchanged(model, runtime.summon(side, "oa-neutral-c02", 2, "occupied"), before, "occupied summon lane " + side)
		rejected_unchanged(model, runtime.summon(side, "unknown-card", 1, "unknown"), before, "unknown summon card " + side)
		rejected_unchanged(model, runtime.summon(side, "oa-neutral-e02", 1, "not-unit"), before, "impulse cannot be summoned " + side)
		rejected_unchanged(model, runtime.summon(side, "oa-neutral-c02", 5, "offboard"), before, "invalid summon lane " + side)
		# Compare to the same existing effect-summon primitive used by recall, excluding the
		# source selection/removal from discard, which belongs specifically to recall.
		var reference = battle()
		var adapted = battle()
		for value in [reference, adapted]: value.state.origins[side] = 2
		reference.state[side].lanes[2] = reference.make_unit(side, reference.catalog.card("oa-neutral-c02"), 2)
		reference.enqueue({"type": "summon", "side": side, "lane": 2, "card_id": "oa-neutral-c02"})
		check(Runtime.new(adapted).summon(side, "oa-neutral-c02", 2, "compare").ok, "effect summon comparison accepted " + side)
		check(reference.snapshot() == adapted.snapshot(), "complete summon state matches original primitive " + side)

func queue_checks() -> void:
	var model = battle()
	var runtime = Runtime.new(model)
	var chain: Array = []
	for value in range(1, 13): chain.append(ability("guard", {"amount": value}))
	check(runtime.publish("on_summon", "hero", chain, {"event_id": "twelve"}).ok, "twelve consecutive effects resolve")
	check(model.state.hero.block == 78 and runtime.log.size() == 12, "entire ten-plus chain applied")
	for index in 12: check(runtime.log[index].ability_index == index and runtime.log[index].seq == index, "FIFO index " + str(index))
	var replay_model = battle()
	var replay_runtime = Runtime.new(replay_model)
	replay_runtime.publish("on_summon", "hero", chain, {"event_id": "twelve"})
	check(stamp(model) == stamp(replay_model) and runtime.log == replay_runtime.log, "complete state/event ordering deterministic")
	var before := stamp(model)
	rejected_unchanged(model, runtime.publish("on_summon", "hero", chain, {"event_id": "twelve"}), before, "duplicate trigger event")
	var oversized: Array = []
	for index in 1001: oversized.append(ability("guard", {"amount": 1}))
	rejected_unchanged(model, runtime.publish("on_summon", "hero", oversized, {"event_id": "too-long"}), before, "1001 effects exceed bounded preflight")
	model = battle()
	runtime = Runtime.new(model)
	var nested := [false]
	runtime.effect_processed.connect(func(entry: Dictionary):
		if not nested[0]:
			nested[0] = true
			publish(runtime, "hero", ability("heal", {"amount": 1}), {"event_id": "nested"}))
	check(runtime.publish("on_summon", "hero", [ability("guard", {"amount": 1}), ability("ward", {"amount": 1})], {"event_id": "outer"}).ok, "reentrant publication accepted")
	check(runtime.log.map(func(entry): return entry.effect) == ["guard", "ward", "heal"], "reentrant work follows older FIFO work")
	model = battle()
	runtime = Runtime.new(model)
	var target := unit(model, "enemy", 2)
	var original_uid: int = target.uid
	var replaced := [false]
	runtime.effect_processed.connect(func(entry: Dictionary):
		if not replaced[0]:
			replaced[0] = true
			unit(model, "enemy", 2))
	var value := ability("stasis", {"count": 1})
	check(runtime.publish("on_play", "hero", [value, value], {"event_id": "stale-between", "target_lane": 2, "target_uid": original_uid}).ok, "initially valid queued effects accepted")
	check(runtime.log[1].status == "fizzled" and model.state.enemy.lanes[2].stun == 0, "late stale target fizzles without hitting replacement")
	model = battle()
	runtime = Runtime.new(model)
	var loop_index := [0]
	runtime.effect_processed.connect(func(entry: Dictionary):
		loop_index[0] += 1
		runtime.publish("on_summon", "hero", [ability("weave", {"amount": 1})], {"event_id": "loop-" + str(loop_index[0])}))
	var result: Dictionary = runtime.publish("on_summon", "hero", [ability("weave", {"amount": 1})], {"event_id": "loop-0"})
	check(not result.ok and result.reason == "chain_limit" and runtime.log.size() == 1000, "fresh-ID reentrant loop stops exactly at 1000")
	check(model.state.hero.resonance == 15 and model.state.error.is_empty(), "bounded loop cannot exceed resonance cap or silently alter battle rules")
