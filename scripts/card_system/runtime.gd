extends RefCounted
## Explicit V2 effect adapter to AlphaModel. No scene, second combat engine or automatic hooks.
## The caller owns trigger detection and stable event IDs. Do not attach alongside existing effects.
signal effect_processed(entry: Dictionary)
const Registry = preload("res://scripts/card_system/registry.gd")
var registry = Registry.new()
var _strong_model: RefCounted
var _weak_model: WeakRef
var model: RefCounted:
	get: return _weak_model.get_ref() if _weak_model != null else _strong_model
	set(value):
		_strong_model = value
		_weak_model = null
var log: Array = []
var last_error := ""
var _queue: Array = []
var _resolving := false
var _processed := 0
var _chain := 0
var _seen: Dictionary = {}
var _species: Dictionary = {}

func _init(battle_model: RefCounted = null, weak_model := false) -> void:
	# Explicit adapters own their model by default, as before. A model-owned
	# opt-in adapter must use a weak back-reference to avoid a RefCounted cycle.
	if weak_model and battle_model != null: _weak_model = weakref(battle_model)
	else: model = battle_model

func capabilities() -> Dictionary:
	return registry.capabilities()

func bind_species(cards: Array) -> bool:
	# Editorial V2 metadata stays separate from the active catalogue and mutable unit state.
	var replacement: Dictionary = {}
	for card: Variant in cards:
		if not card is Dictionary or not card.get("kind") in ["creature", "event", "relic"]: return false
		if card.kind != "creature": continue
		if not card.get("id") is String or not card.get("species") is Array or card.species.size() < 1 or card.species.size() > 2: return false
		var seen: Dictionary = {}
		for id: Variant in card.species:
			if not registry.contract.species.has(id) or seen.has(id): return false
			seen[id] = true
		if replacement.has(card.id): return false
		replacement[card.id] = card.species.duplicate()
	_species = replacement
	return true

func matches_species(unit: Dictionary, species: String) -> bool:
	return registry.contract.species.has(species) and _species.get(str(unit.get("id", "")), []).has(species)

func validate_costs(side: String, costs: Dictionary) -> String:
	if not _ready(side): return "not_battle"
	if costs.size() != 2: return "invalid_cost"
	for key in ["energy", "resonance"]:
		if not Registry.integer(costs.get(key), 0, 15): return "invalid_cost"
	if int(model.state[side].energy) < int(costs.energy): return "insufficient_energy"
	if int(model.state[side].resonance) < int(costs.resonance): return "insufficient_resonance"
	return ""

func publish(trigger: String, side: String, abilities: Array, context: Dictionary) -> Dictionary:
	if not registry.contract.get("triggers", {}).has(trigger): return _rejected("unknown_trigger")
	return _submit(trigger, side, abilities, context, false)

func activate(side: String, ability: Dictionary, context: Dictionary) -> Dictionary:
	return _submit("activated", side, [ability], context, true)

func summon(side: String, card_id: String, lane: int, event_id: String) -> Dictionary:
	# A source-explicit engine primitive, not support for the still-ambiguous declarative
	# summon(count) contract. No hand removal, play cost, attunement or on_play publication.
	if not _ready(side): return _rejected("not_battle")
	var context := {"event_id": event_id, "target_lane": lane}
	var reason := _validate_context(context)
	if not reason.is_empty(): return _rejected(reason)
	var ability := {"mode": "primitive", "effect": "summon", "target": "own_free_lane", "params": {"card_id": card_id}}
	reason = _preflight(side, ability, context, false)
	if not reason.is_empty(): return _rejected(reason)
	return _queue_batch("effect_summon", side, [{"trigger": "effect_summon", "side": side,
		"ability": ability, "context": context, "index": 0, "activated": false}], context)

func _submit(trigger: String, side: String, abilities: Array, context: Dictionary, activated: bool) -> Dictionary:
	if not _ready(side): return _rejected("not_battle")
	var reason := _validate_context(context)
	if not reason.is_empty(): return _rejected(reason)
	var batch: Array = []
	for index in abilities.size():
		var ability: Variant = abilities[index]
		reason = registry.validate_ability(ability, activated)
		if not reason.is_empty(): return _rejected(reason)
		if activated and ability.mode!="activated":return _rejected("not_activated")
		if not activated and not ability.mode in ["triggered","reactive"]:return _rejected("unsupported_mode")
		if not activated and ability.trigger != trigger: continue
		reason = _preflight(side, ability, context, activated)
		if not reason.is_empty(): return _rejected(reason)
		batch.append({"trigger": trigger, "side": side, "ability": ability.duplicate(true), "context": context.duplicate(true), "index": index, "activated": activated})
	if batch.is_empty(): return {"ok": true, "queued": 0, "processed": 0, "reason": "no_matching_abilities"}
	return _queue_batch(trigger, side, batch, context)

func _queue_batch(trigger: String, side: String, batch: Array, context: Dictionary) -> Dictionary:
	# Weak ownership prevents a model/adapter cycle; this local reference keeps
	# a synchronous drain safe if an observer releases its last external owner.
	var active_model: RefCounted = model
	if active_model == null: return _rejected("not_battle")
	var key := side + ":" + trigger + ":" + str(context.event_id)
	if _seen.has(key): return _rejected("duplicate_event")
	if _seen.size() >= Registry.MAX_EVENT_HISTORY: return _rejected("event_history_limit")
	var chain_used := _processed if _resolving else 0
	if chain_used + _queue.size() + batch.size() > Registry.MAX_CHAIN: return _rejected("chain_limit")
	# Reserve only after the whole batch validates: an invalid action does not mutate the battle.
	_seen[key] = true
	_queue.append_array(batch)
	if _resolving: return {"ok": true, "queued": batch.size(), "processed": 0, "reason": ""}
	_chain += 1
	_processed = 0
	_resolving = true
	last_error = ""
	while not _queue.is_empty():
		if active_model.state.winner != null:
			_cancel_remaining("battle_finished")
			break
		var item: Dictionary = _queue.pop_front()
		_processed += 1
		# Queued targets are revalidated by UID. Their replacements never inherit selected effects.
		var late_reason := _preflight(item.side, item.ability, item.context, item.activated)
		if not late_reason.is_empty():
			_record(item, "fizzled", {"reason": late_reason})
			continue
		var actual := _apply(item)
		var failed_native := false
		for native_key in ["activated", "summon_resolved", "chain_resolved"]:
			if actual.has(native_key) and not actual[native_key]: failed_native = true
		if failed_native or not active_model.state.get("error", "").is_empty():
			last_error = "native_effect_failed"
			_record(item, "error", actual)
			_cancel_remaining(last_error)
			break
		_record(item, "applied", actual)
		# effect_processed is synchronous. An observer can cause a native failure
		# after _apply succeeded; do not report the enclosing chain as successful.
		if not active_model.state.get("error", "").is_empty():
			last_error = "native_effect_failed"
			_cancel_remaining(last_error)
			break
		active_model.check_winner()
	_resolving = false
	return {"ok": last_error.is_empty(), "queued": batch.size(), "processed": _processed, "reason": last_error}

func _ready(side: String) -> bool:
	return model != null and model.state.get("stage") == "battle" and model._valid_side(side) and model.state.get("winner") == null and model.state.get("error", "").is_empty()

func _validate_context(context: Dictionary) -> String:
	var allowed := ["event_id", "source_lane", "source_uid", "target_lane", "target_uid", "target_species"]
	if model != null and model.has_method("production_preflight"): allowed.append_array(["source_card_id", "ability_index", "source_relic", "event_lane", "event_side", "event_uid", "source_armed", "source_relic_uid", "source_instance"])
	for key in context:
		if not key in allowed: return "unknown_context_field:" + str(key)
	if not context.get("event_id") is String or context.event_id.is_empty() or context.event_id.length() > 100: return "invalid_event_id"
	for key in ["source_lane", "target_lane"]:
		if context.has(key) and not Registry.integer(context[key], 0, 4): return "invalid_lane"
	for key in ["source_uid", "target_uid"]:
		if context.has(key) and not Registry.integer(context[key], 1, 9007199254740991): return "invalid_uid"
	if context.has("target_species") and not registry.contract.species.has(context.target_species): return "unknown_species"
	return ""

func _target(side: String, context: Dictionary) -> String:
	if not context.has("target_lane") or not context.has("target_uid"): return "missing_target_identity"
	var unit: Variant = model.state[side].lanes[int(context.target_lane)]
	if unit == null or int(unit.uid) != int(context.target_uid) or int(unit.hp) <= 0: return "stale_target"
	if context.has("target_species") and not matches_species(unit, str(context.target_species)): return "species_mismatch"
	return ""

func _source(side: String, context: Dictionary) -> String:
	if not context.has("source_lane") or not context.has("source_uid"): return "missing_source_identity"
	var unit: Variant = model.state[side].lanes[int(context.source_lane)]
	return "" if unit != null and int(unit.uid) == int(context.source_uid) and int(unit.hp) > 0 else "stale_source"

func _preflight(side: String, ability: Dictionary, context: Dictionary, activated: bool) -> String:
	if not _ready(side): return "not_battle"
	if Registry.ProductionEffects.OPS.has(ability.get("effect")):
		return model.production_preflight(side, ability, context) if model.has_method("production_preflight") else "production_profile_required"
	var p: Dictionary = model.state[side]
	var other: String = model._other(side)
	var op: Dictionary = model.state[other]
	if activated:
		if model.state.active != side or p.phase != "main" or p.pendingTarget != null or p.pendingShift != null: return "invalid_activation_phase"
		if p.relic == null or p.relic_used: return "relic_unavailable"
		if model.catalog.card(p.relic.id).effect != ability.effect: return "wrong_relic"
		var cost_reason := validate_costs(side, ability.activation)
		if not cost_reason.is_empty(): return cost_reason
		if ability.effect == "relic_draw" and (p.hand.size() >= 6 or p.deck.is_empty()): return "cannot_draw"
	# A UID supplied for the source is a binding, including for effects aimed at heroes.
	if context.has("source_uid") and str(ability.get("trigger", "")) != "on_death":
		var source_reason := _source(side, context)
		if not source_reason.is_empty(): return source_reason
	var effect: String = ability.effect
	if effect in ["rally", "silence", "pulse"]:
		var source_reason := _source(side, context)
		if not source_reason.is_empty(): return source_reason
	if effect == "strike":
		var has_units := false
		for unit in op.lanes:
			if unit != null: has_units = true
		if has_units or context.has("target_uid"): return _target(other, context)
	elif effect in ["stasis", "displace"]:
		var reason := _target(other, context)
		if not reason.is_empty(): return reason
		if effect == "displace":
			var free := false
			for lane in [int(context.target_lane) - 1, int(context.target_lane) + 1]:
				if lane >= 0 and lane < 5 and op.lanes[lane] == null: free = true
			if not free: return "no_free_neighbor"
	elif effect == "surge":
		var reason := _target(side, context)
		if not reason.is_empty(): return reason
		if not model.can_fight(side, int(context.target_lane)): return "not_ready"
	elif effect in ["bolt", "delay", "redirect", "recall", "summon"]:
		if not context.has("target_lane"): return "missing_target_lane"
		if effect == "bolt" and context.has("target_uid"):
			var reason := _target(other, context)
			if not reason.is_empty(): return reason
		if effect == "recall" and (p.lanes[int(context.target_lane)] != null or model._discard_unit(side) < 0): return "no_recall_target"
		if effect == "summon":
			var card: Dictionary = model.catalog.card(str(ability.params.get("card_id", "")))
			if card.is_empty() or card.get("kind") != "creature" or not card.get("effect") in model.EFFECTS: return "unsupported_summon_card"
			if p.lanes[int(context.target_lane)] != null: return "occupied_summon_lane"
		if effect == "redirect":
			var found := false
			for delayed in model.state.delayed:
				if delayed.side == side: found = true
			if not found: return "no_delayed_event"
	if context.has("target_species") and not effect in ["strike", "stasis", "displace", "surge", "bolt"]: return "species_target_not_supported"
	if context.has("target_species") and effect == "bolt" and not context.has("target_uid"): return "missing_target_identity"
	if context.has("target_species") and effect == "strike" and not context.has("target_uid"): return "missing_target_identity"
	return ""

func _apply(item: Dictionary) -> Dictionary:
	if Registry.ProductionEffects.OPS.has(item.ability.get("effect")):
		return model.production_apply(item.side, item.ability, item.context)
	var side: String = item.side
	var p: Dictionary = model.state[side]
	var other: String = model._other(side)
	var op: Dictionary = model.state[other]
	var ability: Dictionary = item.ability
	var context: Dictionary = item.context
	var amount := int(ability.params.get("amount", 0))
	var result: Dictionary = {}
	if item.activated:
		# Delegates costs, once-per-turn flag and the original four effects to the existing model.
		result["activated"] = model.activate_relic(side)
		return result
	match str(ability.effect):
		"guard": p.block = int(p.block) + amount
		"ward": p.ward = mini(25, int(p.ward) + amount)
		"mend", "heal": p.hp = mini(int(p.maxHp), int(p.hp) + amount)
		"weave", "harvest": model.add_res(p, amount)
		"draw": result["drawn"] = model.draw_cards(side, int(ability.params.count))
		"drain":
			var lost: int = model.damage(op, amount)
			p.hp = mini(int(p.maxHp), int(p.hp) + lost)
			result["hp_lost"] = lost
		"strike":
			if context.has("target_uid"): model._strike_target(side, int(context.target_lane), amount, int(context.get("source_lane", 0)))
			else: result["hp_lost"] = model.damage(op, amount)
		"bolt": model._lane_damage(other, int(context.target_lane), amount)
		"rally":
			var lane := int(context.source_lane)
			var neighbor: Variant = p.lanes[lane - 1] if lane > 0 else null
			if neighbor == null and lane < 4: neighbor = p.lanes[lane + 1]
			if neighbor != null: neighbor.atk = int(neighbor.atk) + amount
		"silence":
			var unit: Variant = op.lanes[int(context.source_lane)]
			if unit != null: unit.stun = maxi(int(unit.stun), 1)
		"weaken": op.weak = maxi(int(op.weak), amount)
		"pulse":
			model.add_res(p, amount)
			p.ward = mini(25, int(p.ward) + amount)
			for lane in [int(context.source_lane) - 1, int(context.source_lane) + 1]:
				if lane >= 0 and lane < 5 and p.lanes[lane] != null: p.lanes[lane].atk = int(p.lanes[lane].atk) + 1
		"stasis":
			var unit: Dictionary = op.lanes[int(context.target_lane)]
			unit.stun = maxi(int(unit.stun), int(ability.params.count))
			model._break_uid(int(unit.uid))
		"surge":
			var unit: Dictionary = p.lanes[int(context.target_lane)]
			unit.extra_attacks = int(unit.extra_attacks) + 1
		"recall":
			var index: int = model._discard_unit(side)
			var id: String = p.discard[index]
			p.discard.remove_at(index)
			var lane := int(context.target_lane)
			p.lanes[lane] = model.make_unit(side, model.catalog.card(id), lane)
			model._trace("recall", side, {"lane": lane, "card_id": id})
			result["summon_resolved"] = model.enqueue({"type": "summon", "side": side, "lane": lane, "card_id": id})
		"summon":
			var id: String = ability.params.card_id
			var lane := int(context.target_lane)
			p.lanes[lane] = model.make_unit(side, model.catalog.card(id), lane)
			model._trace("effect_summon", side, {"lane": lane, "card_id": id})
			result["summon_resolved"] = model.enqueue({"type": "summon", "side": side, "lane": lane, "card_id": id})
		"delay": model.state.delayed.append({"side": side, "lane": int(context.target_lane), "due": int(model.state.round) + int(ability.params.turn_changes), "power": amount})
		"redirect":
			for delayed in model.state.delayed:
				if delayed.side == side:
					delayed.lane = int(context.target_lane)
					break
		"displace":
			var lane := int(context.target_lane)
			for destination in [lane - 1, lane + 1]:
				if destination >= 0 and destination < 5 and op.lanes[destination] == null:
					var unit: Dictionary = op.lanes[lane]
					model._break_uid(int(unit.uid))
					op.lanes[destination] = unit
					op.lanes[lane] = null
					result["destination"] = destination
					break
		"cascade": result["chain_resolved"] = model.enqueue({"type": "echo", "side": side, "remaining": int(ability.params.count)})
	model._refresh_bindings()
	return result

func _record(item: Dictionary, status: String, actual: Dictionary) -> void:
	var entry := {"seq": log.size(), "chain": _chain, "event_id": item.context.event_id,
		"trigger": item.trigger, "side": item.side, "ability_index": item.index,
		"effect": item.ability.effect, "ability": item.ability.duplicate(true),
		"context": item.context.duplicate(true), "status": status, "actual": actual.duplicate(true)}
	log.append(entry)
	if status == "applied": model._trace("card_system_effect", item.side, entry)
	effect_processed.emit(entry.duplicate(true))

func _cancel_remaining(reason: String) -> void:
	while not _queue.is_empty(): _record(_queue.pop_front(), "cancelled", {"reason": reason})

func _rejected(reason: String) -> Dictionary:
	if _resolving and reason in ["chain_limit", "event_history_limit"]: last_error = reason
	return {"ok": false, "queued": 0, "processed": 0, "reason": reason}
