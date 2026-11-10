extends RefCounted
## Presentation adapter: accepts already resolved semantic events, never commands.
## Hosts call this after successful resolution; no rules or numeric thresholds live here.
const FACTIONS := {"houses": "zwoelf_haeuser", "stillwatch": "stillwacht", "morph": "vielgestalt", "ninth": "neunte_stunde", "neutral": "neutral"}
const LEGACY_CUES := {"ui": "ui.confirm", "draw": "card.draw", "attack": "creature.attack", "hit": "creature.hit", "turn": "ui.confirm", "win": "battle.victory", "lose": "battle.defeat"}
var _manager: WeakRef

func _init(manager: Node = null) -> void:
	bind_manager(manager)

func bind_manager(manager: Node) -> void:
	_manager = weakref(manager) if is_instance_valid(manager) else null

func route(event_name: String, context: Dictionary = {}) -> bool:
	var manager := _manager.get_ref() as Node if _manager != null else null
	if not is_instance_valid(manager) or not manager.has_method("play_event"):
		return false
	var payload := context.duplicate(true)
	if payload.has("faction"):
		payload.faction = FACTIONS.get(str(payload.faction), str(payload.faction))
	return bool(manager.play_event(event_name, payload))

func legacy_cue(cue_name: String, context: Dictionary = {}) -> bool:
	if not LEGACY_CUES.has(cue_name):
		return false
	return route(LEGACY_CUES[cue_name], context)

func resonance(stage: String, context: Dictionary = {}) -> bool:
	if stage not in ["low", "medium", "high", "gain", "spend", "unleash"]:
		return false
	return route("resonance." + stage, context)

func music(context: String, fade_seconds: float = 1.5) -> bool:
	var manager := _manager.get_ref() as Node if _manager != null else null
	return is_instance_valid(manager) and manager.has_method("set_music") and bool(manager.set_music(context, fade_seconds))
