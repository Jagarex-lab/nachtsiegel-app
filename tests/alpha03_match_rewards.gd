extends SceneTree
## Application integration: four real starter duels through the command journal.
## Hero choices use the existing AI; every hero action crosses Session.command.
const Session = preload("res://scripts/alpha/session.gd")
const Store = preload("res://scripts/production/profile_store.gd")
const Services = preload("res://scripts/alpha/integrated_services.gd")
const Catalog = preload("res://scripts/production/catalog.gd")
const ECONOMY_PATH := "user://alpha03_match_rewards_economy.json"
const POWERS := ["houses", "stillwatch", "morph", "ninth"]
var assertions := 0
var failures := 0

class JournalPolicy extends "res://scripts/production/ai_policy.gd":
	var session: RefCounted
	func _act(model: RefCounted, side: String, method: String, args: Array) -> bool:
		# Enemy replies happen inside the player's normal endTurn command.
		if side != "hero": return super._act(model, side, method, args)
		var names := {"finish_draw":"finishDraw", "choose_strike_target":"chooseStrikeTarget", "skip_shift":"skipShift", "move_creature":"moveCreature", "activate_relic":"activateRelic", "tactical_move":"tacticalMove", "declare_convergence":"converge", "end_turn":"endTurn"}
		return bool(session.command(names.get(method, method), args).ok)

func check(value: bool, label: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		printerr("FAIL: " + label)

func clean(path: String) -> void:
	for suffix in ["", ".bak", ".tmp", ".corrupt"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	if DirAccess.dir_exists_absolute(path + ".lock"): DirAccess.remove_absolute(path + ".lock")

func make_session(id: String) -> RefCounted:
	var session := Session.new()
	var path := "user://alpha03_match_profile_" + id + ".json"
	clean(path)
	session.store = Store.new(path)
	session.profile = session.store.load_profile().profile
	session._saved_profile = session.profile.duplicate(true)
	return session

func service_for(session: RefCounted, path := ECONOMY_PATH) -> RefCounted:
	var service := Services.new()
	service.configure(session, path)
	return service

func run_opening(session: RefCounted) -> void:
	var exchange: Array = []
	for index in session.model.state.hero.hand.size():
		if int(session.card(session.model.state.hero.hand[index]).cost) > 3: exchange.append(index)
	check(session.command("mulligan", [exchange]).ok, "real mulligan journaled")
	check(session.command("origin", [2]).ok, "real origin journaled")
	if session.model.state.stage == "second":
		var highest := -1
		for index in session.model.state.hero.hand.size():
			if int(session.card(session.model.state.hero.hand[index]).cost) > 3: highest = index
		if highest >= 0: check(session.command("secondCard", [highest]).ok, "real second-player exchange")
		check(session.command("secondOrigin", [(int(session.model.state.origins.hero) + 1) % 5]).ok, "real second origin")
		check(session.command("openingDone", []).ok, "real opening completes")

func _initialize() -> void: call_deferred("run")
func run() -> void:
	clean(ECONOMY_PATH)
	var catalog := Catalog.new()
	var session := make_session("duels")
	var service := service_for(session)
	check(not service.reward_completed_duel().ok, "no model is ineligible without calling begin_duel")
	var stale := service_for(session)
	stale.local_economy() # Capture an earlier durable state before real payouts.
	var baseline: Dictionary = stale.economy.manager.state.duplicate(true)
	for index in POWERS.size():
		var power: String = POWERS[index]
		check(session.start_match("alpha", catalog.deck(power), 8802030 + index, 2, catalog.deck(POWERS[(index + 1) % 4])), "real production starter starts: " + power)
		check(not service.reward_completed_duel().ok, "new/replaced model cannot borrow old duel eligibility")
		service.begin_duel()
		check(not service.reward_completed_duel().ok, "unfinished eligible duel rejected")
		run_opening(session)
		var policy := JournalPolicy.new()
		policy.session = session
		session.model.ai_policy = policy
		var calls := 0
		while session.model.state.winner == null and session.model.state.error.is_empty() and calls < 500:
			policy.take_turn(session.model, "hero")
			calls += 1
		check(session.model.state.error.is_empty(), "real kernel completed without error: " + power)
		check(session.model.state.winner in ["hero", "enemy", "draw"], "actual completed battle: " + power)
		if session.model.state.winner == null:
			quit(1)
			return
		var audit: Dictionary = session.audit()
		var verification: Dictionary = Session.replay(audit)
		check(verification.ok and Session.digest(verification.state) == audit.final, "actual command replay reproduces final state: " + power)
		var played := 0
		for command in session.commands:
			if command.name == "play" and command.result_ok and command.args[0] == "hero": played += 1
		check(played > 0, "actual successful player commands counted: " + power)
		var prior_matches: int = service.local_economy().manager.state.activity.matches
		var granted: Dictionary = service.reward_completed_duel()
		check(granted.ok, "application completed result commits: " + power)
		check(service.economy.manager.state.activity.matches == prior_matches + 1, "exactly one completed-match activity: " + power)
		var source := "match:" + (Session.digest(session.setup) + ":" + Session.digest(session.model.state)).sha256_text()
		var receipt: Dictionary = service.economy.manager.state.activity_sources[source]
		check(receipt.event.cards_played == played, "reward counts command plays rather than summon events: " + power)
		var committed: Dictionary = service.economy.manager.state.duplicate(true)
		check(service.reward_completed_duel().get("replayed", false), "same result dialog repeats saved receipt: " + power)
		check(service.economy.manager.state == committed, "result dialog cannot mint again: " + power)
		var reloaded := service_for(session)
		reloaded.begin_duel()
		check(reloaded.reward_completed_duel().get("replayed", false), "service reload recovers receipt: " + power)
		check(reloaded.economy.manager.state == committed, "reload preserves complete economy state: " + power)
		stale.begin_duel()
		check(stale.reward_completed_duel().get("replayed", false), "earlier facade reloads receipt before payout: " + power)
		check(stale.economy.manager.state == committed, "stale service cannot duplicate completed match: " + power)
		var unbound := service_for(session)
		check(not unbound.reward_completed_duel().ok and unbound.economy == null, "campaign/replay shared session completion has no duel entitlement")
		check(Session.replay_prefix(audit, 0).ok, "replay viewer reconstruction is read-only")
		check(not unbound.reward_completed_duel().ok, "viewing complete replay creates no entitlement")
		# Even if the application erroneously reuses the old model reference,
		# setup changes cannot create an eligible production-duel receipt.
		var saved_setup: Dictionary = session.setup.duplicate(true)
		session.setup["rules_profile"] = Session.ARCHIVE_PROFILE
		check(not service.reward_completed_duel().ok, "unsupported replay/profile cannot receive payout")
		session.setup = saved_setup
		check(service.economy.manager.state == committed, "unsupported context leaves balances untouched")
		print("ALPHA03 MATCH CASE ",power," commands=",session.commands.size()," plays=",played," rounds=",session.model.state.round," winner=",session.model.state.winner)
		# Break the test policy's intentional reference cycle before the next game.
		policy.session = null
	check(service.economy.manager.state.activity.matches == baseline.activity.matches + 4, "four actual battles produce exactly four rewards")
	# The campaign's own configured chapter grant stays separate and deduplicated.
	var prior_matches: int = service.economy.manager.state.activity.matches
	check(service.reward_campaign("campaign-real-outbox", {"reward_id":"campaign_chapter","chapter":1}).ok, "campaign receives configured chapter reward")
	var campaign_committed: Dictionary = service.economy.manager.state.duplicate(true)
	check(service.reward_campaign("campaign-retry", {"reward_id":"campaign_chapter","chapter":1}).get("replayed", false), "same chapter different outbox request does not grant twice")
	check(service.economy.manager.state == campaign_committed and service.economy.manager.state.activity.matches == prior_matches, "campaign reward never counts as an additional duel")
	# Real profile-store foreign-version state propagates to economy initialization.
	var blocked := make_session("blocked")
	var writer := FileAccess.open(blocked.store.path, FileAccess.WRITE)
	writer.store_string('{"version":999,"decks":{}}')
	writer.close()
	blocked.profile = blocked.store.load_profile().profile
	check(blocked.store.write_blocked, "profile store identifies future version")
	var blocked_path := "user://alpha03_match_blocked_economy.json"
	clean(blocked_path)
	var blocked_service := service_for(blocked, blocked_path)
	check(not blocked_service.local_economy().ready and not FileAccess.file_exists(blocked_path), "source write_blocked prevents initialization without a false success")
	check(FileAccess.get_file_as_string(blocked.store.path) == '{"version":999,"decks":{}}', "future source profile bytes remain intact")
	clean(blocked.store.path)
	clean(blocked_path)
	clean(session.store.path)
	clean(ECONOMY_PATH)
	print("ALPHA03 MATCH REWARDS: %d assertions, %d failures; four real starter duels and replay verification" % [assertions, failures])
	quit(1 if failures else 0)
