extends SceneTree
const Adapter = preload("res://scripts/campaign_orafold/battle_adapter.gd")
const BattleView = preload("res://scripts/campaign_orafold/battle_view.gd")
const Manager = preload("res://scripts/campaign_orafold/campaign_manager.gd")
const Overview = preload("res://scenes/campaign_orafold/campaign_overview.tscn")
const Session = preload("res://scripts/alpha/session.gd")
var assertions := 0
var failures := 0
var callbacks: Array = []
var integration_ui
var receiver_fails := true
var acknowledgement_fails := false
var receipt_path := "user://campaign_integration_receipts.json"
var receipts: Dictionary = {}
func check(ok: bool, name: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", name)
func _initialize() -> void: call_deferred("run")
func settle() -> void:
	for frame in 3: await process_frame
func fresh(seed_value: int = 42):
	var a = Adapter.new()
	check(a.begin({"deck_profile":"houses","enemy_profile":"stillwatch","ai_profile":"practice","seed":seed_value,"rules_profile":"production-550-v1"}, "run-"+str(seed_value)), "configured production encounter starts")
	check(a.model.catalog.all_cards().size() == 550 and a.snapshot().production.profile == "production-550-v1", "actual 550-card production kernel selected")
	check(a.session.setup.deck.size() == 30 and a.session.setup.enemy_deck.size() == 30 and a.snapshot().hero.hp == 30 and a.snapshot().enemy.hp == 30 and a.snapshot().hero.lanes.size() == 5, "30-card decks, 30 HP and five paths")
	a.completed.connect(func(token,outcome):callbacks.append([token,outcome]))
	return a
func run() -> void:
	var a = fresh()
	var before: Dictionary = a.snapshot()
	check(not a.command("endTurn",["enemy"]).ok, "opponent commands blocked")
	check(not a.command("advanceTurnBoundary",["hero"]).ok, "internal boundary blocked")
	check(before == a.snapshot(), "adapter rejects without mutating engine")
	check(not a.begin({"deck_profile":"unconfirmed","enemy_profile":"stillwatch","ai_profile":"practice"},"x"), "unconfigured decks rejected")
	check(before == a.snapshot(), "invalid begin preserves active battle")
	check(not a.begin({"deck_profile":"houses","enemy_profile":"stillwatch","ai_profile":"practice","rules_profile":"alpha-55-v1"},"x"), "explicit archived rules rejected")
	a.set_paused(true)
	check(not a.command("mulligan",[[]]).ok and not a.surrender() and a.snapshot()==before, "pause blocks all battle actions without mutation")
	a.set_paused(false)
	check(a.surrender(), "explicit concession")
	check(a.outcome == "defeat" and callbacks.size()==1, "concession callback exactly once")
	check(not a.surrender() and not a.command("mulligan",[[]]).ok, "completed adapter refuses commands")
	check(a.snapshot()==before, "concession never forges engine winner")
	callbacks.clear()
	var winners: Array = []
	for seed_value in [42, 20261110, 12345]:
		a = fresh(seed_value)
		play(a, true)
		winners.append(a.outcome)
		check(not a.outcome.is_empty(), "actual match reaches terminal outcome "+str(seed_value))
		check(a.model.state.error.is_empty(), "engine remains valid "+str(seed_value))
		if not a.outcome.is_empty():
			check(a.outcome == ("victory" if a.model.state.winner=="hero" else "defeat"), "engine result drives route "+str(seed_value))
	check(winners.has("victory"), "legal-command strategy wins an actual match")
	a = fresh(42)
	play(a, false)
	check(a.outcome=="defeat" and a.model.state.winner=="enemy", "passive strategy loses actual match")
	check(callbacks.size()==4, "one callback for each actual match")
	var final_snapshot: Dictionary = a.snapshot()
	check(not a.command("endTurn",["hero"]).ok and final_snapshot==a.snapshot(), "finished match immutable")
	# UI executes existing controls. No test-only result shortcuts.
	a = fresh(42)
	var view = BattleView.new()
	root.add_child(view)
	view.setup(a, null)
	await settle()
	check(view.actions.has("keep") and view.actions.has("card_0"), "battle view exposes opening hand")
	view.actions.keep.pressed.emit()
	await settle()
	check(a.snapshot().stage=="origins" and view.actions.has("origin_2"), "opening UI dispatches model command")
	view.actions.origin_2.pressed.emit()
	await settle()
	if a.snapshot().stage=="second":
		view.actions.begin.pressed.emit()
		await settle()
	check(a.snapshot().stage=="battle", "battle UI completes opening")
	view.actions.surrender.pressed.emit()
	await settle()
	check(a.outcome.is_empty() and view.actions.has("confirm"), "concede requires deliberate confirmation")
	view.actions.confirm.pressed.emit()
	await settle()
	check(a.outcome=="defeat" and view.actions.has("return"), "concede yields return action")
	var returned: Array = []
	view.returned.connect(func(token,outcome):returned.append([token,outcome]))
	view.actions["return"].pressed.emit()
	await settle()
	view._return_to_story()
	check(returned==[[a.token,"defeat"]], "UI returns exact token once")
	view.queue_free()
	await process_frame
	await _campaign_integration()
	print("CAMPAIGN BATTLE: %d assertions, %d failures; actual outcomes %s" % [assertions,failures,str(winners)])
	quit(0 if failures==0 else 1)

func _receive_reward(key: String, payload: Dictionary) -> Dictionary:
	if receiver_fails: return {"ok":false,"code":"simulated_unavailable"}
	if not receipts.has(key):
		receipts[key] = payload.duplicate(true)
		var file = FileAccess.open(receipt_path, FileAccess.WRITE)
		file.store_string(JSON.stringify(receipts)); file.close()
	if acknowledgement_fails: integration_ui.manager.state.path = "user://missing-campaign-integration-directory/progress.json"
	return {"ok":true}

func _campaign_integration() -> void:
	var path := "user://campaign_production_integration.json"
	for base in [path,receipt_path]:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(base+suffix): DirAccess.remove_absolute(base+suffix)
	var m = Manager.new("res://data/campaign_orafold/prototype.json", path)
	check(m.load_campaign() and m.start_chapter("cp01") and m.advance() and m.choose("preserve") and m.advance(), "integrated narrative reaches production encounter")
	var request: Dictionary = m.request_battle()
	m = Manager.new("res://data/campaign_orafold/prototype.json", path)
	check(m.load_campaign() and m.request_battle().token == request.token, "reopening before combat preserves durable token and decisions")
	integration_ui = Overview.instantiate()
	var shared_session = Session.new()
	integration_ui.configure_host(shared_session, _receive_reward)
	root.add_child(integration_ui)
	await settle()
	integration_ui.manager = m
	m.changed.connect(integration_ui._manager_changed)
	m.rewards.grant_requested.connect(integration_ui._reward_requested)
	integration_ui._start_battle()
	await settle()
	var a = integration_ui.battle_adapter
	check(a.session == shared_session and a.model == shared_session.model, "embedded campaign uses host production Session")
	var paused_snapshot: Dictionary = a.snapshot()
	integration_ui.open_overview()
	check(a.paused and not a.command("mulligan",[[]]).ok and a.snapshot() == paused_snapshot, "campaign overview pauses battle without state corruption")
	integration_ui._resume()
	check(integration_ui.battle_adapter == a and not a.paused, "resume retains current battle instance")
	# Audio has one owner. Its mute/suspension result never controls progression.
	var audio = root.get_node_or_null("GameAudio")
	if audio != null:
		audio.set_muted(true, false); audio.set_suspended(true)
	play(a,true)
	if audio != null:
		audio.set_suspended(false); audio.set_muted(false, false)
	check(a.outcome == "victory" and a.model.state.winner == "hero", "actual configured production battle wins while audio muted/suspended")
	check(Session.replay(a.audit()).ok, "campaign commands reproduce full production match and event digest")
	integration_ui._render()
	await settle()
	var before: Dictionary = m.state.data.duplicate(true)
	integration_ui._battle_returned("stale-token","victory")
	check(m.state.data == before, "stale terminal return cannot change campaign")
	m.state.path = "user://missing-campaign-integration-directory/progress.json"
	integration_ui.battle_view.actions["return"].pressed.emit()
	check(m.state.data == before and integration_ui.battle_adapter == a, "failed result save preserves pending battle and terminal adapter")
	await settle()
	check(not integration_ui.battle_view.return_sent and integration_ui.battle_view.actions.has("return"), "save failure leaves an actionable result return button")
	m.state.path = path
	integration_ui.battle_view.actions["return"].pressed.emit()
	check(m.current_scene().id == "victory" and integration_ui.battle_adapter == null, "same terminal result retries and commits exactly once")
	check(m.advance(), "chapter completion stages production reward after real victory")
	integration_ui._deliver_rewards()
	check(m.state.data.reward_ledger.production_chapter_1.state == "pending" and receipts.is_empty(), "failed receiver retains durable reward outbox")
	receiver_fails = false
	acknowledgement_fails = true
	integration_ui._deliver_rewards()
	check(receipts.size() == 1 and m.state.data.reward_ledger.production_chapter_1.state == "pending", "receipt survives failed campaign acknowledgement")
	acknowledgement_fails = false
	m = Manager.new("res://data/campaign_orafold/prototype.json",path)
	check(m.load_campaign(), "campaign reloads after receipt acknowledgement failure")
	integration_ui.manager = m
	integration_ui._deliver_rewards()
	check(receipts.size() == 1 and m.state.data.reward_ledger.production_chapter_1.state == "delivered", "redelivery reuses receipt and acknowledges without duplicate reward")
	check(m.start_chapter("cp02"), "actual battle unlocks chapter two")
	check(m.dialogue.lines(m.current_scene(),m.state.data)[0].text_id == "dialogue.return.01", "saved decision selects chapter-two conditional dialogue")
	check(m.advance() and m.advance() and m.advance() and m.choose("open") and m.advance(), "second decision and alternative ending finish normally")
	integration_ui._deliver_rewards()
	check(receipts.size() == 2, "each completed chapter receives one configured receipt")
	var ledger: Dictionary = m.state.data.reward_ledger.duplicate(true)
	check(m.replay_chapter("cp01") and m.advance() and m.choose("compare") and m.advance(), "replay explores alternate choice without resetting first completion")
	request = m.request_battle()
	a = Adapter.new(shared_session)
	check(a.begin(request,request.token) and a.surrender() and m.resolve_battle(a.token,a.outcome), "replay confirmed concession follows defeat route")
	check(m.advance() and m.request_battle().token != request.token, "repeat encounter gets a fresh saved token")
	check(m.state.data.reward_ledger == ledger and receipts.size() == 2, "replay and repeat never duplicate chapter rewards")
	var exits: Array = []
	integration_ui.exit_requested.connect(func():exits.append(true))
	integration_ui.request_exit()
	check(exits.size() == 1, "embedded campaign supplies host back signal")
	integration_ui.queue_free()
	await settle()
	for base in [path,receipt_path]:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(base+suffix): DirAccess.remove_absolute(base+suffix)
func play(a, active_strategy: bool) -> void:
	check(a.command("mulligan",[[]]).ok,"opening mulligan")
	check(a.command("origin",[2]).ok,"opening origin")
	if a.snapshot().stage=="second": check(a.command("openingDone",[]).ok,"opening second chance")
	for turn in 100:
		if not a.outcome.is_empty(): return
		var p: Dictionary = a.snapshot().hero
		if p.phase=="draw":
			while p.hand.size()+mini(int(p.pendingDraw),p.deck.size())>6:
				check(a.command("burn",["hero",0]).ok,"legal overflow burn")
				p=a.snapshot().hero
			check(a.command("finishDraw",["hero"]).ok,"legal draw")
		for step in 20:
			if not a.outcome.is_empty(): return
			p=a.snapshot().hero
			if p.pendingTarget!=null:
				for lane in 5:
					if a.snapshot().enemy.lanes[lane]!=null:
						check(a.command("chooseStrikeTarget",["hero",lane]).ok,"legal arrival target")
						break
				continue
			if p.pendingShift!=null:
				check(a.command("skipShift",["hero"]).ok,"legal optional shift skip")
				continue
			if not active_strategy:break
			var best: Dictionary = {}
			for index in p.hand.size():
				var c: Dictionary = a.card(p.hand[index])
				for lane in a.model.legal_targets("hero",index):
					var score = float(c.get("atk",0)) + float(c.get("hp",0))*0.45 - float(c.cost)*0.2
					if c.kind=="creature" and a.snapshot().enemy.lanes[lane]==null:score+=float(c.atk)*0.5
					if c.kind=="event":score=2
					if c.effect=="heal":score=5 if p.hp<20 else -1
					if c.effect=="recall":score=6
					if c.effect in ["stasis","bolt","displace"]:score=4
					if c.kind=="relic":score=3 if p.relic==null else -1
					if best.is_empty() or score>best.score:best={"index":index,"lane":lane,"score":score}
			if best.is_empty() or best.score<0:break
			check(a.command("play",["hero",best.index,best.lane]).ok,"legal strategy play")
		if not a.outcome.is_empty():return
		if active_strategy:
			p=a.snapshot().hero
			if p.relic!=null and p.energy>0:
				a.command("activateRelic",["hero"])
			if p.resonance>=15:
				for faction in a.model.catalog.deck_ids():
					if a.command("burst",["hero",faction]).ok:break
			var controlled: Array=[]
			for lane in 5:
				if a.model.controlled("hero",lane):controlled.append(lane)
			if controlled.size()>=3 and a.snapshot().round>=11:
				if a.command("converge",["hero",controlled.slice(0,3)]).ok:continue
		check(a.command("endTurn",["hero"]).ok,"legal turn plus existing AI reply")
