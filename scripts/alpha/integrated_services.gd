extends RefCounted
## Presentation/application services. Neither ownership nor wallets enter combat.
var session: RefCounted
var economy: RefCounted
var last_reward: Dictionary = {}
var eligible_duel: WeakRef
var eligible_setup := ""
const DEFAULT_ECONOMY_PATH := "user://orafold_alpha03_economy_v2.json"
var economy_path := DEFAULT_ECONOMY_PATH

func configure(shared_session: RefCounted, save_path: String = DEFAULT_ECONOMY_PATH) -> void:
	session = shared_session
	economy_path = save_path

func local_economy() -> RefCounted:
	if economy == null:
		economy = load("res://scripts/economy/alpha550_economy.gd").new(economy_path)
		economy.configure_profile(session.profile, not session.store.write_blocked)
	return economy

func reward_campaign(receipt_id: String, payload: Dictionary) -> Dictionary:
	return local_economy().reward_campaign(receipt_id, payload)

func begin_duel() -> void:
	eligible_duel = weakref(session.model)
	eligible_setup = session.digest(session.setup)
	last_reward = {}

func reward_completed_duel() -> Dictionary:
	if eligible_duel == null or eligible_duel.get_ref() != session.model or eligible_setup != session.digest(session.setup):
		return {"ok":false,"code":"not_application_duel"}
	if session.model == null or session.mode != "alpha" or session.setup.get("rules_profile") != session.PRODUCTION_PROFILE:
		return {"ok":false,"code":"not_production_duel"}
	var state: Dictionary = session.model.state
	if state.winner == null or not state.get("error", "").is_empty():
		return {"ok":false,"code":"not_completed"}
	var played := 0
	for command in session.commands:
		if command.get("name") == "play" and command.get("result_ok",false) and not command.get("args",[]).is_empty() and command.args[0] == "hero": played += 1
	var receipt: String = session.digest(session.setup) + ":" + session.digest(state)
	last_reward = local_economy().reward_match(receipt, {"winner":state.winner,"human_side":"hero","kind":"duel","cards_played":mini(1000,played),"turns":int(state.get("round",0))})
	return last_reward
