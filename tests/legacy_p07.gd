extends "res://tests/legacy_p05_p06.gd"
func run() -> void:
	var fixture=read("res://tests/fixtures/legacy/p07_v1.json")
	fixture.cases.append_array(read("res://tests/fixtures/legacy/p07_edges_v1.json").cases)
	var chains: Dictionary={}
	for scenario: Dictionary in fixture.cases:
		var model=EngineModel.new();model.state=runtime(scenario.steps[0].before)
		model.rng=Random.new(123456)
		for step: Dictionary in scenario.steps:
			model.events.clear()
			same(step.before,model.snapshot(),scenario.id+" before")
			var value: Variant=invoke(model,step.command,step.args)
			same(step.result.get("value"),value,scenario.id+" result "+step.command)
			same(step.after,model.snapshot(),scenario.id+" full state "+step.command)
			var points: Array=[{"state":step.before,"pendingDeath":null}]
			for event: Dictionary in model.events:points.append({"state":event.state,"pendingDeath":event.get("pendingDeath")})
			points.append({"state":model.snapshot(),"pendingDeath":model.pending_death})
			same(step.state_sequence,compress(points),scenario.id+" ordered event states "+step.command)
			check(model.rng.calls==0 and model.rng.state==123456,scenario.id+" no added match RNG consumption")
			if step.result.get("value")==false:
				check(not step.reference_mutates_on_reject,scenario.id+" original rejection immutable")
				var public=EngineModel.new();public.state=runtime(step.before)
				var reply: Dictionary=public.execute(step.command,step.args)
				check(not reply.ok,scenario.id+" public rejected")
				same(step.before,public.snapshot(),scenario.id+" public rejection immutable")
				check(public.events.is_empty(),scenario.id+" rejected events empty")
			elif step.result.type=="boolean":
				var public=EngineModel.new();public.state=runtime(step.before)
				check(public.execute(step.command,step.args).ok,scenario.id+" accepted via public facade")
				same(step.after,public.snapshot(),scenario.id+" public accepted full state")
			transition_count+=1
		if scenario.id.begins_with("card_chain."):chains[scenario.id]=true
		differential_cases+=1
	check(chains.size()==200,"all100 cards on both sides after actual mixed-order summons")
	var baseline=read("res://docs/migration/p05-p06-evidence/core-results.json")
	check(baseline.unsupported_existing_scenarios.size()==27,"P05/P06 unsupported baseline retained")
	var output={"assertions":assertions,"failures":failures,"differential_cases":differential_cases,"transitions":transition_count,"mixed_card_side_pairs":chains.size(),"unsupported":[],"match_rng_calls":0}
	var file=FileAccess.open("res://work/legacy/p07-results.json",FileAccess.WRITE);file.store_string(JSON.stringify(output,"  ")+"\n");file.close()
	print("LEGACY P07: %d assertions, %d failures; %d differential cases, %d transitions, 200 mixed card-side chains" % [assertions,failures,differential_cases,transition_count])
	root.get_node("GameAudio").request_quit(1 if failures else 0)
func invoke(model, command: String, args: Array) -> Variant:
	match command:
		"burst":return model.burst(args[0],args[1])
		"tacticalMove":return model.tactical_move(args[0],args[1],args[2])
		"fortify":return model.fortify(args[0],args[1])
	return super.invoke(model,command,args)
