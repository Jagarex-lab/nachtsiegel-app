extends "res://tests/legacy_engine.gd"
const Session=preload("res://scripts/alpha/session.gd")
func run() -> void:
	for mode in ["legacy","alpha"]:
		for seed_value in [12345,8802026]:
			var s=Session.new();var cat=preload("res://scripts/alpha/catalog.gd").new() if mode=="alpha" else preload("res://scripts/legacy/catalog.gd").new()
			check(s.start_match(mode,cat.deck("houses" if mode=="alpha" else "start"),seed_value,5,cat.deck("morph") if mode=="alpha" else []),"native match start")
			if mode=="alpha":
				check(s.command("mulligan",[[]]).ok,"replay mulligan");check(s.command("origin",[2]).ok,"replay origin")
				if s.model.state.stage=="second":s.command("openingDone",[])
			for turn in 200:
				var m=s.model;var p: Dictionary=m.state.hero
				if m.state.winner!=null:break
				if p.phase=="draw":
					while p.hand.size()+mini(int(p.pendingDraw),p.deck.size())>6:check(s.command("burn",["hero",0]).ok,"burn command")
					check(s.command("finishDraw",["hero"]).ok,"finish draw command")
				for _action in 12:
					if m.state.winner!=null:break
					if p.pendingTarget!=null:
						for lane in 5:
							if m.state.enemy.lanes[lane]!=null:check(s.command("chooseStrikeTarget",["hero",lane]).ok,"target command");break
						continue
					if p.pendingShift!=null:check(s.command("skipShift",["hero"]).ok,"skip command");continue
					var choice: Dictionary={}
					for index in p.hand.size():
						for lane in 5:
							if m.play_support("hero",index,lane).is_empty():choice={"index":index,"lane":lane};break
						if not choice.is_empty():break
					if choice.is_empty():break
					check(s.command("play",["hero",choice.index,choice.lane]).ok,"play command")
				if m.state.winner==null:check(s.command("endTurn",["hero"]).ok,"end complete command")
			check(s.model.state.winner!=null,"native full duel terminal "+mode)
			var audit=s.audit();var replay=Session.replay(JSON.parse_string(JSON.stringify(audit)))
			check(replay.ok,"full native replay "+mode)
			same(s.model.snapshot(),replay.get("state",{}),"full replay state "+mode)
			var before=s.model.snapshot();check(not s.command("play",["hero",0,0]).ok,"ended play blocked");same(before,s.model.snapshot(),"ended command immutable")
			audit.commands[0].after="tampered";check(not Session.replay(audit).ok,"tamper rejected")
	print("ALPHA REPLAY: %d assertions, %d failures; four complete Legacy/Alpha native replays" % [assertions,failures])
	root.get_node("GameAudio").request_quit(1 if failures else 0)

func same(expected: Variant, actual: Variant, label: String) -> void:
	# Alpha has additional instance/shield fields; compare EVERY field canonically.
	check(JSON.stringify(expected,"",true)==JSON.stringify(actual,"",true),label)
