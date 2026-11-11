extends RefCounted
## Campaign handoff into the same production Session/kernel as the Alpha arena.
signal completed(token: String, outcome: String)
signal sound_requested(event_name: String, context: Dictionary)
const Session = preload("res://scripts/alpha/session.gd")
const Catalog = preload("res://scripts/production/catalog.gd")
const AudioEvents = preload("res://scripts/audio/presentation_audio.gd")
const AI_PROFILES = {"practice":1, "standard":2, "expert":5}
const OPENING = ["mulligan","origin","secondOrigin","secondCard","openingDone"]
const HERO_COMMANDS = ["play","burn","finishDraw","endTurn","activateRelic","converge","burst","recover","tacticalMove","fortify","moveCreature","skipShift","chooseStrikeTarget"]
var session
var model
var token := ""
var outcome := ""
var last_error := ""
var commands: Array = []
var paused := false
var conceded := false
var audio_events = AudioEvents.new()

func _init(existing_session = null) -> void:
	session = existing_session

func begin(request: Dictionary, request_token: String) -> bool:
	var encounter: Dictionary = request.get("encounter", request)
	var catalog = Catalog.new()
	var player_profile = encounter.get("deck_profile", "")
	var enemy_profile = encounter.get("enemy_profile", "")
	var ai = encounter.get("ai_profile", "")
	if request_token.is_empty() or not catalog.deck_ids().has(player_profile) or not catalog.deck_ids().has(enemy_profile) or not AI_PROFILES.has(ai):
		last_error = "invalid_encounter_profile"
		return false
	# Older callers can omit these fields; explicit archived/custom rule requests
	# never silently run as production.
	if encounter.get("rules_profile", Session.PRODUCTION_PROFILE) != Session.PRODUCTION_PROFILE or encounter.get("starting_situation", "engine_default") != "engine_default":
		last_error = "unsupported_encounter_rules"
		return false
	var seed_value = encounter.get("seed", 1)
	if not (seed_value is int or seed_value is float) or not is_finite(float(seed_value)) or float(seed_value) != floor(float(seed_value)) or float(seed_value) < 0:
		last_error = "invalid_encounter_seed"
		return false
	if session == null: session = Session.new()
	if not session.start_match("alpha", catalog.deck(player_profile), int(seed_value), AI_PROFILES[ai], catalog.deck(enemy_profile), true, Session.PRODUCTION_PROFILE):
		last_error = "battle_start_failed"
		return false
	model = session.model
	token = request_token
	outcome = ""
	commands.clear()
	paused = false
	conceded = false
	audio_events.reset()
	last_error = ""
	return true

func command(name: String, args: Array) -> Dictionary:
	if model == null or not outcome.is_empty(): return {"ok":false,"reason":"no_active_battle"}
	if session.model != model: return {"ok":false,"reason":"battle_session_replaced"}
	if paused: return {"ok":false,"reason":"battle_paused"}
	if not name in OPENING and (not name in HERO_COMMANDS or args.is_empty() or args[0] != "hero"):
		return {"ok":false,"reason":"hero_commands_only"}
	var before: Dictionary = model.snapshot()
	var offset: int = model.events.size()
	var result: Dictionary = session.command(name, args)
	if result.ok or result.get("accepted", false):
		commands.append({"name":name,"args":args.duplicate(true)})
		for sound in audio_events.collect(model.events.slice(offset), before, model.catalog):
			sound_requested.emit(sound.event, sound.context)
		if model.state.winner != null:
			outcome = "victory" if model.state.winner == "hero" else "defeat"
			completed.emit(token, outcome)
	return result

func set_paused(value: bool) -> void:
	paused = value

func surrender() -> bool:
	if model == null or not outcome.is_empty() or paused: return false
	conceded = true
	outcome = "defeat"
	completed.emit(token, outcome)
	return true

func confirmed_result(request_token: String, result: String) -> bool:
	return model != null and token == request_token and not outcome.is_empty() and result == outcome and (conceded and result == "defeat" or model.state.winner != null and result == ("victory" if model.state.winner == "hero" else "defeat"))

func snapshot() -> Dictionary:
	return {} if model == null else model.snapshot()

func card(id: String) -> Dictionary:
	return {} if model == null else model.catalog.card(id)

func audit() -> Dictionary:
	return {} if model == null else session.audit()
