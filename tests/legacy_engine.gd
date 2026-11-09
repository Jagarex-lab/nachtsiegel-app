extends SceneTree
const EngineModel = preload("res://scripts/legacy/battle_engine.gd")
const Random = preload("res://scripts/legacy/rng.gd")
const Compare = preload("res://tests/legacy_fixture_compare.gd")
var assertions := 0
var failures := 0
var differential_cases := 0
var supported_legacy_cases := 0
var unsupported: Array = []
func check(value: bool, label: String) -> void:
	assertions+=1
	if not value:failures+=1;printerr("FAIL: ",label)
func same(expected: Variant, actual: Variant, label: String) -> void:
	var delta: Dictionary=Compare.difference(expected,actual)
	check(delta.is_empty(),label+" "+JSON.stringify(delta))
func read(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))
func runtime(snapshot: Dictionary) -> Dictionary:
	var copy=snapshot.duplicate(true)
	for side: String in ["hero","enemy"]:
		copy[side].erase("deckCount");copy[side].erase("handCount")
		for unit: Variant in copy[side].lanes:
			if unit!=null:unit.erase("baseHp");unit.erase("baseAtk")
	return copy
func phase_events(model) -> Array:
	var result: Array=[]
	for event: Dictionary in model.events:
		if event.kind in ["phase_attack","phase_end","begin","draw_finished"]:result.append({"kind":event.kind,"state":event.state})
	return result
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var fixture=read("res://tests/fixtures/legacy/engine_p01_p04.json")
	for item: Dictionary in fixture.randoms:
		var random=Random.new(int(item.seed))
		if item.has("values"):
			for i in item.values.size():
				same(float(item.states[i])/4294967296.0,random.next_float(),item.id+" exact binary value "+str(i))
				same(item.states[i],random.state,item.id+" state "+str(i))
			check(random.calls==20,item.id+" exact RNG calls")
		else:
			var input: Array=item.input.duplicate()
			same(item.shuffled,random.shuffle(input),item.id)
			same(item.input,input,item.id+" input immutable")
			check(random.calls==input.size()-1,item.id+" shuffle call count")
		differential_cases+=1
	var consumption=read("res://tests/fixtures/legacy/rng_consumption_v1.json").cases
	for item: Dictionary in fixture.openings:
		var model=EngineModel.new()
		check(model.start(item.deck,int(item.seed),int(item.level)),item.id+" start")
		same(item.initial,model.snapshot(),item.id+" original initial snapshot")
		check(model.begin_turn(model.state.coin),item.id+" first begin")
		same(item.after_begin,model.snapshot(),item.id+" original pre-AI boundary")
		same(item.phases,phase_events(model),item.id+" first phases")
		var observed: Dictionary={}
		for sample: Dictionary in consumption:
			if sample.id==item.id:observed=sample;break
		same(observed.calls,model.rng.calls,item.id+" actual original RNG call count")
		same(observed.state,model.rng.state,item.id+" actual original RNG final state")
		same(float(observed.next_state)/4294967296.0,model.rng.next_float(),item.id+" next original RNG sample")

		differential_cases+=1
	for item: Dictionary in fixture.begins:
		var model=EngineModel.new();model.state=runtime(item.before)
		check(model.begin_turn(item.side),item.id)
		same(item.after,model.snapshot(),item.id+" resources/flags/hand/deck")
		same(item.phases,phase_events(model),item.id+" phase states")
		differential_cases+=1
	for item: Dictionary in fixture.advances:
		var model=EngineModel.new();model.state=runtime(item.before)
		check(model.advance_turn(item.side)==item.accepted,item.id+" accepted")
		same(item.after,model.snapshot(),item.id+" boundary")
		same(item.phases,phase_events(model),item.id+" phase progression")
		differential_cases+=1
	for item: Dictionary in fixture.damage:
		var player: Dictionary=item.before.duplicate(true)
		same(item.lost,EngineModel.damage(player,float(item.amount),item.pierce),item.id+" actual HP loss")
		same(item.after,player,item.id+" protection consumption")
		differential_cases+=1
	var legacy=read("res://tests/fixtures/legacy/transitions.json")
	for scenario: Dictionary in legacy.cases:
		var model=EngineModel.new();model.state=runtime(scenario.steps[0].before)
		var complete := true
		for step: Dictionary in scenario.steps:
			same(step.before,model.snapshot(),scenario.id+" exact before")
			var outcome=execute(model,step)
			if not outcome.supported:
				unsupported.append({"id":scenario.id,"command":step.command,"reason":outcome.reason});complete=false;break
			same(step.result.value if step.result.has("value") else null,outcome.value,scenario.id+" result")
			same(step.after,model.snapshot(),scenario.id+" after")
			# Death queue snapshots, including pre/post harvest, are checked against
			# actual JS death log records, not merely final HP.
			var expected_deaths: Array=[];var actual_deaths: Array=[]
			for event: Dictionary in step.events:
				if event.get("pendingDeath")!=null and str(event.message).ends_with(" fällt."):
					expected_deaths.append({"pendingDeath":event.pendingDeath,"state":event.state})
			for event: Dictionary in model.events:
				if event.kind=="death":actual_deaths.append({"pendingDeath":event.pendingDeath,"state":event.state})
			same(expected_deaths,actual_deaths,scenario.id+" death processing order/states")
			model.events.clear()
		if complete:supported_legacy_cases+=1;differential_cases+=1
	var combat=read("res://tests/fixtures/legacy/combat_p04_v1.json")
	for item: Dictionary in combat.combats:
		var model=EngineModel.new();model.state=runtime(item.before)
		check(model.attack_phase(item.side),item.id+" accepted")
		same(item.after,model.snapshot(),item.id+" full mixed combat state")
		same(item.deaths,death_events(model),item.id+" death snapshots FIFO")
		differential_cases+=1
	for item: Dictionary in combat.queues:
		var model=EngineModel.new();model.state=runtime(item.before)
		var ok := true
		if item.deferred_prefix:
			model._resolving=true
			ok=model.enqueue_many(item.batch.slice(0,item.batch.size()-1))
			check(model.events.is_empty(),item.id+" no recursive drain")
			model._resolving=false
			ok=model.enqueue(item.batch[-1])
		else:ok=model.enqueue_many(item.batch)
		check(ok!=bool(item.limited),item.id+" original limit outcome")
		same(item.after,model.snapshot(),item.id+" complete queue result")
		same(item.deaths,death_events(model),item.id+" exact FIFO states/harvest")
		same(item.remaining_queue,model._queue.size(),item.id+" queue cleared")
		same(item.resolving,model._resolving,item.id+" resolving cleared")
		same(item.pending_death,model.pending_death,item.id+" pending death cleared")
		differential_cases+=1
	var turns=read("res://tests/fixtures/legacy/turns_p03_v1.json")
	for item: Dictionary in turns.cases:
		var model=EngineModel.new();model.state=runtime(item.steps[0].before)
		for step: Dictionary in item.steps:
			same(step.before,model.snapshot(),item.id+" continuous before")
			model.events.clear()
			var ok := false
			match str(step.command):
				"play":ok=model.play(step.args[0],step.args[1],step.args[2])
				"finishDraw":ok=model.finish_draw(step.args[0])
				"endTurn":ok=model.advance_turn(step.args[0])
			check(ok==bool(step.accepted),item.id+" "+step.command)
			same(step.after,model.snapshot(),item.id+" continuous after")
			same(step.phases,phase_events(model),item.id+" continuous phases")
		differential_cases+=1
	for item: Dictionary in read("res://tests/fixtures/legacy/queue_winner_p04_v1.json").cases:
		var model=EngineModel.new();model.state=runtime(item.before)
		check(model.enqueue_many(item.batch),item.id+" queue accepted")
		same(item.after,model.snapshot(),item.id+" result before remaining death")
		check(model.state.hero.discard.is_empty() and model.state.enemy.discard.is_empty(),item.id+" no post-result death")
		same(item.remaining_queue,model._queue.size(),item.id+" queue cleared")
		differential_cases+=1
	adversarial_checks(fixture,legacy)
	queue_checks(legacy)
	var result={"assertions":assertions,"failures":failures,"differential_cases":differential_cases,"supported_existing_scenarios":supported_legacy_cases,"unsupported_existing_scenarios":unsupported}
	var file=FileAccess.open("res://work/legacy/engine-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  ")+"\n");file.close()
	print("LEGACY ENGINE: %d assertions, %d failures; %d differential cases; %d existing scenarios supported, %d explicitly unsupported" % [assertions,failures,differential_cases,supported_legacy_cases,unsupported.size()])
	root.get_node("GameAudio").request_quit(1 if failures else 0)
func execute(model, step: Dictionary) -> Dictionary:
	var args: Array=step.args
	var before: Dictionary=model.snapshot()
	var reason := ""
	var value: Variant=null
	match str(step.command):
		"attackPhase":value=model.attack_phase(args[0]);value=null if value else false
		"begin":
			reason=model.begin_support(args[0])
			if model.state.active!=args[0]:reason="guarded_begin_wrong_side"
			if reason.is_empty():model.begin_turn(args[0])
		"draw":value=model.draw_cards(args[0],int(args[1]))
		"finishDraw":
			var p: Dictionary=model.state[args[0]]
			if model.state.winner==null and model.state.active==args[0] and p.phase=="draw":reason=model._draw_requirements(p,int(p.pendingDraw))
			if reason.is_empty():value=model.finish_draw(args[0])
		"play":
			reason=model.play_support(args[0],args[1],args[2])
			if not reason.begins_with("P0"):reason="";value=model.play(args[0],args[1],args[2])
		"endTurn":
			var probe=EngineModel.new();probe.state=model.state.duplicate(true)
			var p: Dictionary=probe.state[args[0]]
			if step.accepted and args[0]=="hero":
				probe.attack_phase(args[0])
				if probe.state.winner==null:reason="P10:automatic_enemy_turn"
			if reason.is_empty():value=model.advance_turn(args[0])
		_:
			reason="later_package:"+str(step.command)
	if not reason.is_empty():
		if step.command=="play":check(not model.play(args[0],args[1],args[2]),"unsupported summon truly rejected")
		elif step.command=="begin":check(not model.begin_turn(args[0]),"unsupported begin truly rejected")
		elif step.command=="finishDraw":check(not model.finish_draw(args[0]),"unsupported draw truly rejected")
		elif step.command!="endTurn":check(not model.execute(step.command,args).ok,"later command truly rejected")
		same(before,model.snapshot(),"unsupported operation immutable: "+step.command)
		return {"supported":false,"reason":reason}
	return {"supported":true,"value":value}
func adversarial_checks(fixture: Dictionary, legacy: Dictionary) -> void:
	var model=EngineModel.new();var opening: Dictionary=fixture.openings[0]
	model.start(opening.deck,int(opening.seed),int(opening.level))
	var changed=opening.initial.duplicate(true);changed.hero.deck.reverse()
	check(not Compare.difference(changed,model.snapshot()).is_empty(),"tampered deck order fails differential")
	changed=opening.initial.duplicate(true);changed.enemy.ward=999
	check(not Compare.difference(changed,model.snapshot()).is_empty(),"tampered shield fails differential")
	changed=opening.initial.duplicate(true);changed.erase("coin")
	check(not Compare.difference(changed,model.snapshot()).is_empty(),"missing startplayer fails differential")
	var random=Random.new(1);random.next_float()
	check(random.next_float()!=fixture.randoms[6].values[0],"extra RNG consumption cannot equal first golden draw")
	model.state=runtime(legacy.cases[0].steps[0].before)
	var passive := ""
	for card in model.catalog.all_cards():
		if card.effect=="haste":passive=card.id;break
	model.state.hero.hand=[passive,passive,passive];model.state.hero.energy=10
	for bad: Variant in [-1,5,1.5,"0",true]:
		var before=model.snapshot();check(not model.play("hero",0,bad),"invalid lane "+str(bad));same(before,model.snapshot(),"invalid lane immutable")
	check(model.play("hero",0,0),"first supported summon")
	check(model.play("hero",0,1),"second supported summon")
	var before=model.snapshot();check(not model.play("hero",0,2),"third summon rejected");same(before,model.snapshot(),"third summon immutable")
	check(not model.play("unknown",0,2),"invalid side rejected")
	model=EngineModel.new();model.state=runtime(legacy.cases[0].steps[0].before)
	before=model.snapshot();check(not model.play("hero",0,0),"unsupported active summon rejected");same(before,model.snapshot(),"unsupported summon does not become vanilla")
	model.state.enemy.deck=[];model.state.enemy.discard=["ash-1"]
	before=model.snapshot();check(not model.advance_turn("hero"),"unsupported next begin preflight rejected");same(before,model.snapshot(),"rejected turn cannot partially attack")
	check(model.events.is_empty(),"rejected preflight does not emit events")
	for command: String in ["endTurn","burn","recover","burst","tacticalMove","fortify","chooseStrikeTarget","moveCreature","skipShift","inventedTimeRewind"]:
		before=model.snapshot();var count: int=model.events.size()
		var reply: Dictionary=model.execute(command,["hero"])
		check(not reply.ok and str(reply.reason).begins_with("unsupported_command:"),"closed API rejects "+command)
		same(before,model.snapshot(),"unsupported command snapshot immutable")
		check(model.events.size()==count,"unsupported command trace immutable")
	for args: Array in [[],["hero"],[12,0,0],["hero",null,0],["hero",0,0,0]]:
		before=model.snapshot();check(not model.execute("play",args).ok,"malformed command rejected");same(before,model.snapshot(),"malformed args immutable")

	model.state.winner="enemy";before=model.snapshot();check(not model.advance_turn("hero"),"finished turn rejected");same(before,model.snapshot(),"finished immutable")
	var p={"hp":35,"ward":4,"block":3};var copy=p.duplicate(true)
	check(EngineModel.damage(p,INF)==-1,"nonfinite damage rejected");same(copy,p,"bad damage immutable")
func queue_checks(legacy: Dictionary) -> void:
	var fresh=EngineModel.new()
	check(not fresh.enqueue_many([]),"uninitialized queue rejected")
	var model=EngineModel.new();model.state=runtime(legacy.cases[0].steps[0].before)
	var before_batch=model.snapshot()
	var valid={"type":"death","side":"hero","unit":{"id":"ash-1","hp":0},"lane":0}
	var invalid=valid.duplicate(true);invalid.lane=5
	check(not model.enqueue_many([valid,invalid]),"whole malformed batch rejected")
	same(before_batch,model.snapshot(),"malformed batch cannot partially discard")
	check(model.events.is_empty() and model._queue.is_empty(),"malformed batch leaves queue and trace unchanged")
	var dead={"id":"ash-1","hp":-1,"atk":1,"summoned":false,"stun":0}
	var event={"type":"death","side":"hero","unit":dead,"lane":0}
	check(model.enqueue(event),"first death accepted");check(model.enqueue(event),"duplicate delivery harmless")
	check(model.state.hero.discard==["ash-1"],"same instance discarded once")
	check(model.enqueue({"type":"death","side":"hero","unit":dead.duplicate(),"lane":1}),"distinct equal-valued copy accepted")
	check(model.state.hero.discard.size()==2,"equal dictionaries do not conflate physical instances")
	model=EngineModel.new();model.state=runtime(legacy.cases[0].steps[0].before)
	var batch: Array=[]
	for i in 101:batch.append({"type":"death","side":"hero","unit":{"id":"ash-1","hp":-1,"atk":1,"summoned":false,"stun":0},"lane":i%5})
	check(not model.enqueue_many(batch),"101-event batch trips limit")
	check(model.queue_error=="event_limit" and model.state.hero.discard.size()==100,"exactly100 events processed before abort")
	check(model._queue.is_empty() and not model._resolving and model.pending_death==null,"queue cleanup after limit")
	var before=model.snapshot();check(not model.enqueue({"type":"unknown","side":"hero"}),"unknown event rejected");same(before,model.snapshot(),"unknown event immutable")
	model.state.winner="hero";before=model.snapshot();check(not model.enqueue(event),"queue stopped on winner");same(before,model.snapshot(),"post-result death cannot mutate")

func death_events(model) -> Array:
	var result: Array=[]
	for event: Dictionary in model.events:
		if event.kind=="death":result.append({"pendingDeath":event.pendingDeath,"state":event.state})
	return result
