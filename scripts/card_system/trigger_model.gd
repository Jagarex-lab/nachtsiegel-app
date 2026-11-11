extends "res://scripts/alpha/model.gd"
## Experimental, explicitly instantiated profile. The production Session does not use it.
## Replaces effects only for validated source-bound cards; never falls back after V2 ownership.
const EffectRuntime = preload("res://scripts/card_system/runtime.gd")
const EffectRegistry = preload("res://scripts/card_system/registry.gd")
const AUTOMATIC := ["on_play", "on_summon", "on_death"]
const OBSERVED_ONLY := ["on_relic_activate"]
const SAFE_SUMMON := ["guard", "ward", "mend", "weave", "drain", "rally", "silence", "draw", "weaken", "pulse"]
var effect_runtime: RefCounted
var trigger_journal: Array = []
var _bindings: Dictionary = {}
var _binding_hash := ""
var _trigger_serial := 0
var _runtime_log_cursor := 0
var _journal_ids: Dictionary = {}
var _probe_instance := false
var _summoned_uids: Dictionary = {}
var _dead_uids: Dictionary = {}

class ObservedRuntime extends EffectRuntime:
	var _owner: WeakRef
	func _init(owner: RefCounted) -> void:
		super._init(owner, true)
		_owner = weakref(owner)
	func _record(item: Dictionary, status: String, actual: Dictionary) -> void:
		super._record(item, status, actual)
		var owner: RefCounted = _owner.get_ref()
		if owner != null: owner._sync_runtime_log()

func _init() -> void:
	super._init()
	effect_runtime = ObservedRuntime.new(self)

func configure_v2(cards: Array) -> Dictionary:
	if not state.is_empty(): return {"ok": false, "reason": "configure_before_match"}
	var candidate: Dictionary = {}
	for definition: Variant in cards:
		var reason := _validate_binding(definition)
		if not reason.is_empty(): return {"ok": false, "reason": reason}
		if candidate.has(definition.id): return {"ok": false, "reason": "duplicate_binding"}
		candidate[definition.id] = definition.duplicate(true)
	var runtime = ObservedRuntime.new(self)
	if not runtime.bind_species(cards): return {"ok": false, "reason": "invalid_species"}
	_bindings = candidate
	_binding_hash = JSON.stringify(candidate, "", true).sha256_text()
	effect_runtime = runtime
	return {"ok": true, "reason": "", "bound_cards": candidate.size()}

func _validate_binding(definition: Variant) -> String:
	if not definition is Dictionary or definition.get("schema_version") != 2: return "invalid_definition"
	var id := str(definition.get("id", ""))
	var original: Dictionary = catalog.card(id)
	if original.is_empty(): return "unknown_original_card"
	var binding: Variant = definition.get("source_binding")
	if not binding is Dictionary or binding.size() != 4: return "source_binding_required"
	if binding.get("catalog") != "orafold-alpha-0.1" or binding.get("card_id") != id or binding.get("effect") != original.effect or binding.get("power") != original.power: return "source_binding_mismatch"
	for pair in [["kind", "kind"], ["power", "faction"], ["rarity", "rarity"], ["energy_cost", "cost"]]:
		if definition.get(pair[0]) != original[pair[1]]: return "original_value_mismatch:" + pair[0]
	if definition.has("resonance_cost") and not EffectRegistry.integer(definition.resonance_cost, 0, 0): return "printed_resonance_cost_unsupported"
	if original.kind == "creature":
		if definition.get("attack") != original.atk or definition.get("health") != original.hp: return "original_stats_mismatch"
		if definition.has("resonance_cost"): return "creature_resonance_cost_forbidden"
	else:
		for key in ["attack", "health", "species"]:
			if definition.has(key): return "noncreature_stats_forbidden"
	var abilities: Variant = definition.get("abilities")
	if not abilities is Array or abilities.size() != 1 or not abilities[0] is Dictionary: return "single_source_ability_required"
	var ability: Dictionary = abilities[0]
	if ability.get("effect") != original.effect: return "source_effect_mismatch"
	var reason: String = effect_runtime.registry.validate_ability(ability, ability.get("mode") == "activated")
	if not reason.is_empty(): return reason
	var rule: Dictionary = effect_runtime.registry.contract.effects[original.effect]
	if not original.kind in rule.kinds: return "effect_kind_mismatch"
	for parameter in rule.source_binding.parameter_semantics:
		var expression: String = rule.source_binding.parameter_semantics[parameter]
		var expected: int = int(original.power)
		if expression.begins_with("constant "): expected = int(expression.trim_prefix("constant "))
		elif expression.begins_with("power + "): expected += int(expression.trim_prefix("power + "))
		elif expression != "power": return "unknown_source_parameter_expression"
		if ability.params.get(parameter) != expected: return "source_parameter_mismatch:" + str(parameter)
	if original.kind == "creature" and ability.get("trigger") == "on_summon" and not original.effect in SAFE_SUMMON: return "automatic_target_window_unsupported"
	return ""

func start_alpha(deck: Array, opponent_deck: Array, seed_value: int, difficulty: int = 2) -> bool:
	if not catalog.validate(deck).ok or not catalog.validate(opponent_deck).ok: return false
	effect_runtime = ObservedRuntime.new(self)
	effect_runtime.bind_species(_bindings.values())
	trigger_journal = []
	_journal_ids = {}
	_runtime_log_cursor = 0
	_trigger_serial = 0
	_summoned_uids = {}
	_dead_uids = {}
	return super.start_alpha(deck, opponent_deck, seed_value, difficulty)

func snapshot() -> Dictionary:
	var result:=super.snapshot()
	if not _bindings.is_empty() and not result.is_empty():result["v2_bridge"]=_bridge_snapshot_metadata()
	return result

func _bridge_snapshot_metadata() -> Dictionary:
	var summoned: Array=_summoned_uids.keys();summoned.sort()
	var dead: Array=_dead_uids.keys();dead.sort()
	return {"version":1,"binding_sha256":_binding_hash,"trigger_serial":_trigger_serial,
		"summoned_uids":summoned,"dead_uids":dead,"runtime_event_count":effect_runtime._seen.size(),
		"runtime_history_sha256":JSON.stringify(effect_runtime._seen,"",true).sha256_text(),"runtime_chain":effect_runtime._chain}

func capabilities() -> Dictionary:
	var matrix: Dictionary = {}
	for trigger in effect_runtime.registry.contract.triggers:
		matrix[trigger] = "automatic_source_bound" if trigger in AUTOMATIC else "observation_only" if trigger in OBSERVED_ONLY else "unsupported"
	return {"profile": "orafold-v2-trigger-lab", "production_session_uses_profile": false,
		"source_bound_only": true, "configured_cards": _bindings.keys(), "trigger_matrix": matrix,
		"automatic_ability_triggers": AUTOMATIC.duplicate(), "reaction_windows": "not_generalized",
		"unsupported": ["new card identities", "new printed resonance costs", "source-less target selection", "generalized reactive/passive abilities", "additional thirteen executable trigger families", "rule commands issued reentrantly by external effect observers"]}

func execute(command: String, args: Array) -> Dictionary:
	var reply: Dictionary = super.execute(command, args)
	if reply.ok and not state.get("error", "").is_empty():
		# The original command was committed before a technical resolution failure.
		# This is distinct from an illegal, atomically rejected player command.
		return {"ok": false, "accepted": true, "reason": "effect_resolution_error", "detail": state.error}
	return reply

func _validation_probe():
	var probe = get_script().new()
	var result: Dictionary = probe.configure_v2(_bindings.values())
	assert(result.ok)
	probe.state = state.duplicate(true)
	probe._probe_instance = true
	probe._trigger_serial = _trigger_serial
	probe.trigger_journal = trigger_journal.duplicate(true)
	probe._journal_ids = _journal_ids.duplicate(true)
	probe._runtime_log_cursor = _runtime_log_cursor
	probe._summoned_uids = _summoned_uids.duplicate(true)
	probe._dead_uids = _dead_uids.duplicate(true)
	probe.effect_runtime.log = effect_runtime.log.duplicate(true)
	probe.effect_runtime._seen = effect_runtime._seen.duplicate(true)
	probe.effect_runtime._chain = effect_runtime._chain
	return probe

func _after_card_played(side: String, card: Dictionary, lane: int) -> void:
	if not _bindings.has(card.id): return
	var context: Dictionary = {}
	if card.kind == "creature":
		var unit: Variant = state[side].lanes[lane]
		if unit == null or unit.id != card.id: return
		context = {"source_lane": lane, "source_uid": unit.uid}
	_emit_trigger("on_play", side, card.id, context, {"cause": "card_play", "lane": lane})

func _resolve_event_effect(side: String, card: Dictionary, lane: int) -> void:
	if not _bindings.has(card.id):
		super._resolve_event_effect(side, card, lane)
		return
	var context := {"target_lane": lane}
	var target_side: String = side if card.effect == "surge" else _other(side)
	if card.effect in ["stasis", "surge", "displace"] and state[target_side].lanes[lane] != null: context.target_uid = state[target_side].lanes[lane].uid
	_emit_trigger("on_play", side, card.id, context, {"cause": "card_play", "lane": lane})

func enqueue_many(batch: Array) -> bool:
	# Native payloads do not normally carry UIDs. Bind opted-in arrivals before
	# another queued effect can replace that same card identity on the same lane.
	var captured: Array = []
	for item: Variant in batch:
		if not item is Dictionary: return false
		var event: Dictionary = item.duplicate(false)
		if event.get("type") == "death" and event.get("unit") is Dictionary and _bindings.has(str(event.unit.get("id", ""))):
			if not EffectRegistry.integer(event.unit.get("uid"), 1, 9007199254740991): return false
		if event.get("type") == "summon" and _bindings.has(str(event.get("card_id", ""))):
			var side := str(event.get("side", ""))
			var lane: Variant = event.get("lane")
			if not _valid_side(side) or not _integer(lane) or lane < 0 or lane > 4: return false
			if event.has("v2_source_uid"):
				if not EffectRegistry.integer(event.v2_source_uid, 1, 9007199254740991): return false
			else:
				var unit: Variant = state[side].lanes[int(lane)]
				if unit == null or unit.id != event.card_id: return false
				event.v2_source_uid = unit.uid
		captured.append(event)
	return super.enqueue_many(captured)

func _resolve_summon(event: Dictionary) -> void:
	var id := str(event.card_id)
	if not _bindings.has(id):
		super._resolve_summon(event)
		return
	var side: String = event.side
	var lane := int(event.lane)
	var uid := int(event.get("v2_source_uid", -1))
	var unit: Variant = state[side].lanes[lane]
	if unit == null or unit.id != id or int(unit.uid) != uid:
		_note_trigger("on_summon", side, id, {"source_lane": lane, "source_uid": uid}, {"cause": "native_summon_queue", "reason": "stale_source"}, "fizzled")
		return
	if _summoned_uids.has(uid):
		_note_trigger("on_summon", side, id, {"source_lane": lane, "source_uid": uid}, {"cause": "native_summon_queue", "reason": "duplicate_summon_instance"}, "fizzled")
		return
	_summoned_uids[uid] = true
	_emit_trigger("on_summon", side, id, {"source_lane": lane, "source_uid": uid}, {"cause": "native_summon_queue"})

func _dispatch_effect(event: Dictionary) -> void:
	# Alpha's original native drain stops on a winner. This optional profile can
	# additionally raise a bridge error inside that drain; no later V1/echo event
	# is allowed to mutate the halted game after that technical failure.
	if not state.error.is_empty():
		_queue.clear()
		return
	super._dispatch_effect(event)
	if not state.error.is_empty(): _queue.clear()

func _resolve_death(event: Dictionary) -> void:
	var unit: Dictionary = event.unit
	if _bindings.has(str(unit.id)):
		var uid := int(unit.get("uid", -1))
		if _dead_uids.has(uid): return
		_dead_uids[uid] = true
	super._resolve_death(event)

func _apply_death_effect(event: Dictionary, card: Dictionary) -> void:
	if not _bindings.has(card.id):
		super._apply_death_effect(event, card)
		return
	var context := {"source_lane": int(event.lane), "source_uid": int(event.unit.uid)}
	_emit_trigger("on_death", str(event.side), card.id, context, {"cause": "native_death_queue", "pending_death": pending_death.duplicate(true)})

func activate_relic(side: String) -> bool:
	var id := ""
	if _valid_side(side) and state[side].get("relic") != null: id = state[side].relic.id
	var ok := super.activate_relic(side)
	if ok and _bindings.has(id):
		_note_trigger("on_relic_activate", side, id, {}, {"cause": "native_relic_activation", "energy_paid": 1, "resonance_paid": 0}, "observed_native_effect")
	return ok

func _note_trigger(trigger: String, side: String, card_id: String, context: Dictionary, detail: Dictionary, status: String) -> Dictionary:
	_trigger_serial += 1
	var record := {"serial": _trigger_serial, "event_id": "v2:" + str(_trigger_serial), "trigger": trigger,
		"side": side, "card_id": card_id, "context": context.duplicate(true), "detail": detail.duplicate(true), "status": status}
	trigger_journal.append(record)
	_trace("v2_trigger", side, record)
	return record

func _emit_trigger(trigger: String, side: String, card_id: String, context: Dictionary, detail: Dictionary) -> void:
	var record := _note_trigger(trigger, side, card_id, context, detail, "published")
	var selected: Array = []
	for ability in _bindings[card_id].abilities:
		if ability.get("mode") == "triggered" and ability.get("trigger") == trigger: selected.append(ability)
	if selected.is_empty():
		record.status = "no_matching_ability"
		return
	# Only publications actually owned by the bridge may update this journal.
	# External Runtime activation/primitive IDs must not rewrite observation-only
	# or no-matching records even when a caller chooses the same ID string.
	_journal_ids[record.event_id] = trigger_journal.size() - 1
	var runtime_context := context.duplicate(true)
	runtime_context.event_id = record.event_id
	var result: Dictionary = effect_runtime.publish(trigger, side, selected, runtime_context)
	_sync_runtime_log()
	if not result.ok:
		record.status = "error"
		record["reason"] = result.reason
		state.error = "V2 trigger bridge halted: " + str(result.reason)
		_trace("v2_error", "system", {"reason": result.reason, "event_id": record.event_id})
	elif record.status == "published": record.status = "queued"

func _sync_runtime_log() -> void:
	while _runtime_log_cursor < effect_runtime.log.size():
		var entry: Dictionary = effect_runtime.log[_runtime_log_cursor]
		_runtime_log_cursor += 1
		if not _journal_ids.has(entry.event_id): continue
		var record: Dictionary = trigger_journal[int(_journal_ids[entry.event_id])]
		record.status = entry.status
		record["outcome"] = entry.actual.duplicate(true)
		if entry.status == "error": state.error = "V2 trigger bridge halted: native effect failed"
		_trace("v2_effect_outcome", entry.side, {"event_id": entry.event_id, "status": entry.status, "effect": entry.effect, "actual": entry.actual})
