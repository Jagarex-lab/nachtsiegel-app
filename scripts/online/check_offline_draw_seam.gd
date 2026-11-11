extends SceneTree
## Compile the byte-for-byte pre-hook Alpha source supplied by git, then run
## the same accepted offline commands through both kernels and compare every
## snapshot, event stream and RNG checkpoint. No source baseline is loosened.
const Current = preload("res://scripts/alpha/model.gd")
const Session = preload("res://scripts/alpha/session.gd")
func _initialize() -> void:
	var args=OS.get_cmdline_user_args()
	if args.size()!=1:push_error("Pass original Alpha source path");quit(1);return
	var script=GDScript.new();script.source_code=FileAccess.get_file_as_string(args[0])
	if script.reload()!=OK:quit(1);return
	var checked=0
	for seed_value in [1,2,3,7,42,550,999,2147483647]:
		var old=script.new();var current=Current.new()
		var decks=[current.catalog.deck("houses"),current.catalog.deck("stillwatch")]
		assert(old.start_alpha(decks[0],decks[1],seed_value,2));assert(current.start_alpha(decks[0],decks[1],seed_value,2))
		for opening in [{"name":"mulligan","args":[[]]},{"name":"origin","args":[2]}]:
			assert(old.execute(opening.name,opening.args)==current.execute(opening.name,opening.args));_same(old,current);checked+=1
		if current.state.stage=="second":
			assert(old.execute("openingDone",[])==current.execute("openingDone",[]));_same(old,current);checked+=1
		for turn in 12:
			if current.state.winner!=null:break
			assert(current.state.active=="hero")
			while current.state.hero.phase=="draw" and current.state.winner==null:
				var name="burn" if current.state.hero.hand.size()+mini(current.state.hero.pendingDraw,current.state.hero.deck.size())>6 else "finishDraw"
				var command_args=["hero",0] if name=="burn" else ["hero"]
				assert(old.execute(name,command_args)==current.execute(name,command_args));_same(old,current);checked+=1
			if current.state.winner!=null:break
			assert(old.execute("endTurn",["hero"])==current.execute("endTurn",["hero"]));_same(old,current);checked+=1
	print("OFFLINE_DRAW_SEAM_PASS "+str(checked)+" identical accepted boundaries across 8 seeds")
	quit()

func _same(old, current) -> void:
	assert(Session.digest(old.snapshot())==Session.digest(current.snapshot()))
	assert(Session.event_digest(old.events)==Session.event_digest(current.events))
	assert(old.rng.state==current.rng.state and old.rng.calls==current.rng.calls)
