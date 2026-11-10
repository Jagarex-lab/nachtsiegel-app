extends RefCounted
## Read-only integration with the existing Alpha rules. No Session/profile writes.
signal completed(token: String, outcome: String)
const Model = preload("res://scripts/alpha/model.gd")
const AI_PROFILES = {"practice":1, "standard":2, "expert":5}
var model
var token := ""
var outcome := ""
var last_error := ""
var commands: Array = []

func begin(request: Dictionary, request_token: String) -> bool:
	var encounter: Dictionary = request.get("encounter", request)
	var candidate = Model.new()
	var player_profile = encounter.get("deck_profile", "")
	var enemy_profile = encounter.get("enemy_profile", "")
	var ai = encounter.get("ai_profile", "")
	if request_token.is_empty() or not candidate.catalog.deck_ids().has(player_profile) or not candidate.catalog.deck_ids().has(enemy_profile) or not AI_PROFILES.has(ai):
		last_error = "invalid_encounter_profile"
		return false
	var seed_value = encounter.get("seed", 1)
	if not (seed_value is int or seed_value is float) or float(seed_value) != floor(float(seed_value)):
		last_error = "invalid_encounter_seed"
		return false
	if not candidate.start_alpha(candidate.catalog.deck(player_profile), candidate.catalog.deck(enemy_profile), int(seed_value), AI_PROFILES[ai]):
		last_error = "battle_start_failed"
		return false
	model = candidate
	token = request_token
	outcome = ""
	commands.clear()
	last_error = ""
	return true

func command(name: String, args: Array) -> Dictionary:
	if model == null or not outcome.is_empty(): return {"ok":false,"reason":"no_active_battle"}
	# Only expose hero commands. AI replies are owned by the existing model.
	if name not in ["mulligan","origin","secondOrigin","secondCard","openingDone"] and (args.is_empty() or args[0] != "hero"):
		return {"ok":false,"reason":"hero_commands_only"}
	if name == "advanceTurnBoundary": return {"ok":false,"reason":"internal_command"}
	var result: Dictionary = model.execute(name, args)
	if result.ok:
		commands.append({"name":name,"args":args.duplicate(true)})
		if model.state.winner != null:
			outcome = "victory" if model.state.winner == "hero" else "defeat"
			completed.emit(token, outcome)
	return result

func surrender() -> bool:
	if model == null or not outcome.is_empty(): return false
	outcome = "defeat"
	completed.emit(token, outcome)
	return true

func snapshot() -> Dictionary:
	return {} if model == null else model.snapshot()

func card(id: String) -> Dictionary:
	return {} if model == null else model.catalog.card(id)
