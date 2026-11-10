extends RefCounted
## Executable subset of the isolated V2 contract. Registration is not production wiring.
const CONTRACT_PATH := "res://data/card_system/registry.json"
const MAX_CHAIN := 1000
const MAX_EVENT_HISTORY := 10000
const SUPPORTED := ["strike", "guard", "ward", "mend", "weave", "drain", "rally", "silence", "harvest", "draw", "weaken", "pulse", "bolt", "heal", "stasis", "surge", "recall", "delay", "redirect", "displace", "cascade", "relic_res", "relic_ward", "relic_heal", "relic_draw"]
var contract: Dictionary = {}

func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT_PATH))
	if parsed is Dictionary: contract = parsed

func capabilities() -> Dictionary:
	var planned: Array = []
	for id in contract.get("effects", {}):
		if not id in SUPPORTED: planned.append(id)
	return {"schema_version": 2, "scope": "explicit_dispatch_adapter_only", "production_wired": false,
		"automatic_hooks": [], "recognized_triggers": contract.get("triggers", {}).keys(),
		"categories": contract.get("categories", {}).keys(), "supported_effects": SUPPORTED.duplicate(),
		"explicit_primitives": ["summon_known_catalog_creature"],
		"unsupported_effects": planned, "max_chain": MAX_CHAIN,
		"reaction_windows": "existing AlphaModel only; no new reactive timing is implemented"}

func validate_ability(ability: Variant, activated: bool = false) -> String:
	if not ability is Dictionary: return "invalid_ability"
	var required := ["mode", "effect", "target", "params", "limit"]
	var allowed := required + ["trigger", "activation"]
	for key in ability:
		if not key in allowed: return "unknown_ability_field:" + str(key)
	for key in required:
		if not ability.has(key): return "missing_ability_field:" + key
	var effect: String = str(ability.effect)
	if not contract.get("effects", {}).has(effect): return "unknown_effect:" + effect
	if not effect in SUPPORTED: return "unsupported_effect:" + effect
	var rule: Dictionary = contract.effects[effect]
	if not ability.mode in rule.modes: return "invalid_mode"
	if not ability.target in rule.targets: return "invalid_target_rule"
	if not ability.limit in rule.limits: return "invalid_limit"
	if activated:
		if ability.mode != "activated" or ability.has("trigger"): return "not_activated"
		if not ability.get("activation") is Dictionary: return "invalid_activation"
		if ability.activation.size() != 2: return "invalid_activation"
		for key in ["energy", "resonance"]:
			if not integer(ability.activation.get(key), 0, 15): return "invalid_cost"
		# Existing relic costs are preserved. A future cost model needs separate approval/tests.
		if ability.activation != rule.get("activation", {}): return "unsupported_activation_cost"
	else:
		if ability.mode != "triggered" or ability.has("activation"): return "unsupported_mode"
		if not ability.get("trigger") in rule.triggers: return "invalid_trigger_for_effect"
	if not ability.params is Dictionary or ability.params.size() != rule.params.size(): return "invalid_params"
	for key in rule.params:
		var range_rule: Dictionary = rule.params[key]
		if not integer(ability.params.get(key), int(range_rule.min), int(range_rule.max)): return "invalid_param:" + key
	return ""

static func integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= minimum and value <= maximum
