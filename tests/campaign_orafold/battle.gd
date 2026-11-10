extends SceneTree
const Adapter = preload("res://scripts/campaign_orafold/battle_adapter.gd")
const BattleView = preload("res://scripts/campaign_orafold/battle_view.gd")
var assertions := 0
var failures := 0
var callbacks: Array = []
func check(ok: bool, name: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", name)
func _initialize() -> void: call_deferred("run")
func fresh(seed_value: int = 42):
	var a = Adapter.new()
	check(a.begin({"deck_profile":"houses","enemy_profile":"stillwatch","ai_profile":"practice","seed":seed_value}, "run-"+str(seed_value)), "configured Alpha encounter starts")
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
	await process_frame
	check(view.actions.has("keep") and view.actions.has("card_0"), "battle view exposes opening hand")
	view.actions.keep.pressed.emit()
	check(a.snapshot().stage=="origins" and view.actions.has("origin_2"), "opening UI dispatches model command")
	view.actions.origin_2.pressed.emit()
	if a.snapshot().stage=="second": view.actions.begin.pressed.emit()
	check(a.snapshot().stage=="battle", "battle UI completes opening")
	view.actions.surrender.pressed.emit()
	check(a.outcome.is_empty() and view.actions.has("confirm"), "concede requires deliberate confirmation")
	view.actions.confirm.pressed.emit()
	check(a.outcome=="defeat" and view.actions.has("return"), "concede yields return action")
	var returned: Array = []
	view.returned.connect(func(token,outcome):returned.append([token,outcome]))
	view.actions["return"].pressed.emit()
	view._return_to_story()
	check(returned==[[a.token,"defeat"]], "UI returns exact token once")
	view.queue_free()
	await process_frame
	print("CAMPAIGN BATTLE: %d assertions, %d failures; actual outcomes %s" % [assertions,failures,str(winners)])
	quit(0 if failures==0 else 1)
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
					var score = float(c.atk) + float(c.hp)*0.45 - float(c.cost)*0.2
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
