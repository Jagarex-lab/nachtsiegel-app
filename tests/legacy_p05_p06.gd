extends "res://tests/legacy_engine.gd"
var transition_count := 0
var raw_rejection_mutations := 0
func run() -> void:
	var fixture=read("res://tests/fixtures/legacy/p05_p06_v1.json")
	fixture.cases.append_array(read("res://tests/fixtures/legacy/p05_p06_edges_v1.json").cases)
	fixture.cases.append_array(read("res://tests/fixtures/legacy/p05_p06_lifecycle_v1.json").cases)
	var cards: Dictionary={}
	var effects: Dictionary={}
	for scenario: Dictionary in fixture.cases:
		var model=EngineModel.new();model.state=runtime(scenario.steps[0].before)
		for step: Dictionary in scenario.steps:
			model.events.clear()
			same(step.before,model.snapshot(),scenario.id+" before")
			var value: Variant=invoke(model,step.command,step.args)
			same(step.result.get("value"),value,scenario.id+" "+step.command+" result")
			same(step.after,model.snapshot(),scenario.id+" "+step.command+" full state")
			var points: Array=[{"state":step.before,"pendingDeath":null}]
			for event: Dictionary in model.events:points.append({"state":event.state,"pendingDeath":event.get("pendingDeath")})
			points.append({"state":model.snapshot(),"pendingDeath":model.pending_death})
			same(step.state_sequence,compress(points),scenario.id+" "+step.command+" ordered full event states")
			if step.result.get("value")==false:
				var public=EngineModel.new();public.state=runtime(step.before)
				var reply: Dictionary=public.execute(step.command,step.args)
				check(not reply.ok,scenario.id+" public rejection")
				same(step.before,public.snapshot(),scenario.id+" public rejection immutable")
				check(public.events.is_empty(),scenario.id+" no public rejected events")
			if step.reference_mutates_on_reject:raw_rejection_mutations+=1
			transition_count+=1
		if scenario.card_id!=null:
			cards[scenario.side+":"+str(scenario.card_id)]=true
			effects[model.catalog.card(scenario.card_id).effect]=true
		differential_cases+=1
	check(cards.size()==200,"all100 cards on both sides, with exact original effects")
	check(effects.size()==16,"all16 abilities covered")
	check(raw_rejection_mutations==2,"known recycle-before-reject raw cases tracked")
	guard_checks(fixture)
	var result={"assertions":assertions,"failures":failures,"differential_cases":differential_cases,"transitions":transition_count,"card_side_pairs":cards.size(),"effects":effects.keys(),"raw_rejection_mutation_cases":raw_rejection_mutations,"unsupported":[]}
	var file=FileAccess.open("res://work/legacy/p05-p06-results.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"  ")+"\n");file.close()
	print("LEGACY P05/P06: %d assertions, %d failures; %d differential cases, %d transitions, 200 card-side pairs,16 effects" % [assertions,failures,differential_cases,transition_count])
	root.get_node("GameAudio").request_quit(1 if failures else 0)
func invoke(model, command: String, args: Array) -> Variant:
	match command:
		"play":return model.play(args[0],args[1],args[2])
		"finishDraw":return model._finish_draw_reference(args[0])
		"burn":return model._burn_reference(args[0],args[1])
		"recover":return model.recover(args[0])
		"chooseStrikeTarget":return model.choose_strike_target(args[0],args[1])
		"moveCreature":return model.move_creature(args[0],args[1],args[2])
		"skipShift":return model._skip_shift_reference(args[0])
		"begin":model.begin_turn(args[0]);return null
		"attackPhase":model.attack_phase(args[0]);return null
	check(false,"unknown fixture command "+command)
	return null
func compress(points: Array) -> Array:
	var result: Array=[]
	for point in points:
		if result.is_empty() or not Compare.difference(result[-1],point).is_empty():result.append(point)
	return result
func guard_checks(fixture: Dictionary) -> void:
	var model=EngineModel.new();model.state=runtime(fixture.cases[0].steps[0].before)
	model.state.hero.pendingTarget={"power":2,"sourceLane":0}
	var before=model.snapshot();var result: Dictionary=model.execute("play",["hero",0,2])
	check(not result.ok,"pending target remains a play gate")
	same(before,model.snapshot(),"pending play rejected before resources/card/field mutation")
	for command: String in ["inventedTimeRewind"]:
		before=model.snapshot();check(not model.execute(command,["hero"]).ok,"unsupported "+command);same(before,model.snapshot(),"unsupported immutable")
	model.state.winner="enemy";model.state.hero.phase="draw";model.state.hero.pendingDraw=1;model.state.hero.hand=model.catalog.deck("start").slice(0,6)
	before=model.snapshot();check(not model.execute("burn",["hero",0]).ok,"public end guard for legacy raw burn")
	same(before,model.snapshot(),"public ended game immutable")
	var wrong=fixture.cases[0].steps[0].state_sequence.duplicate(true)
	if wrong.size()>1:
		var temp=wrong[0];wrong[0]=wrong[-1];wrong[-1]=temp
		check(not Compare.difference(wrong,fixture.cases[0].steps[0].state_sequence).is_empty(),"event reordering detected")
