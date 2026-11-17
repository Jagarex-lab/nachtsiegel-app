extends "res://tests/production_simulations.gd"
## Paired reference-DECK experiment, using the unchanged production model/policy.
## No subclassed combat, observer policy, stat/resource patch or forced winner.
const RESULT="res://work/premium-balance/results.json"
const PLAN="res://work/premium-balance/plan.json"
const PROPOSAL="res://tools/premium/block_deck_proposal.json"
const BASELINE="res://tools/premium/block_reference_baseline.json"
var refs: Dictionary={}
var proposal: Dictionary={}
var repeats: Array=[]
var journal: FileAccess

func variant_decks(opponent: String, side: String, changed: bool) -> Array:
	var tested: Dictionary=refs["prod-block"].duplicate(true)
	tested.id="prod-block-candidate" if changed else "prod-block-baseline"
	if changed:tested.cards=proposal.candidate_cards.duplicate()
	return [tested,refs[opponent]] if side=="hero" else [refs[opponent],tested]

func planned_seed(opponent: String, side: String, first: String, start: int) -> int:
	var baseline=variant_decks(opponent,side,false)
	var candidate=variant_decks(opponent,side,true)
	for offset in 500:
		var seed_value=start+offset
		var old=make_game(baseline[0],baseline[1],seed_value,2)
		var changed=make_game(candidate[0],candidate[1],seed_value,2)
		if old!=null and changed!=null and old.state.coin==first and changed.state.coin==first:return seed_value
	check(false,"opening-only seed search exhausted "+opponent+"/"+side+"/"+first)
	return -1

func run_actual(c: Dictionary, changed: bool, fresh: bool=false) -> Dictionary:
	var pair=variant_decks(c.opponent,c.tested_side,changed)
	var model=make_game(pair[0],pair[1],int(c.seed),2,fresh)
	if model==null:return {}
	check(model.state.coin==c.first,"same predeclared first side "+str(c.index))
	var calls=finish(model)
	var result=record(model,pair[0],pair[1],int(c.seed),calls)
	result["case_index"]=c.index
	result["variant"]="candidate" if changed else "baseline"
	result["opponent"]=c.opponent
	result["tested_side"]=c.tested_side
	result["seed_block"]=c.seed_block
	result["rng_state"]=model.rng.state
	result["rng_calls"]=model.rng.calls
	result["pilot"]=c.pilot
	check(result.error.is_empty(),"no engine error "+str(c.index)+"/"+result.variant+" "+result.error)
	check(not result.censored,"completed actual match "+str(c.index)+"/"+result.variant)
	check(result.action_limit_reached==0,"AI action bound not reached "+str(c.index)+"/"+result.variant)
	return result

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://work/premium-balance"))
	proposal=JSON.parse_string(FileAccess.get_file_as_string(PROPOSAL))
	var paths=["tests/premium_block_balance.gd","tests/production_simulations.gd","tools/premium/block_deck_proposal.json","tools/premium/block_reference_baseline.json","tools/production/build_test_decks.py","data/production/cards.json","data/production/test_decks.json","data/production/starters.json","scripts/production/catalog.gd","scripts/alpha/catalog.gd","scripts/production/ai_policy.gd","scripts/card_system/production_model.gd","scripts/card_system/production_effects.gd","scripts/card_system/trigger_model.gd","scripts/card_system/runtime.gd","scripts/card_system/registry.gd","data/card_system/registry.json","data/card_system/alpha_species.json","data/alpha/cards.json","scripts/alpha/model.gd","scripts/legacy/battle_engine.gd","scripts/legacy/rng.gd"]
	for path in paths:source_hashes[path]=FileAccess.get_sha256("res://"+path)
	check(FileAccess.get_sha256(BASELINE)==proposal.baseline_test_decks_sha256,"frozen original reference lists from public10782185")
	model_script=load("res://scripts/card_system/production_model.gd")
	configuration_template=model_script.new()
	var catalog=configuration_template.catalog
	# The control opponents remain byte-for-byte the original lists even after
	# the one tested Block composition is adopted in the active reference pool.
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(BASELINE))
	for deck in source.decks:refs[deck.id]=deck
	var active_source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/production/test_decks.json"))
	var active_refs: Dictionary={}
	for deck in active_source.decks:active_refs[deck.id]=deck
	check(active_refs.size()==14,"active reference pool still contains fourteen lists")
	for id in refs:
		if id=="prod-block":check(active_refs.has(id) and active_refs[id].cards in [proposal.before_cards,proposal.candidate_cards],"active Block is exactly the original or tested candidate")
		else:check(active_refs.has(id) and active_refs[id]==refs[id],"other reference deck unchanged "+id)
	check(refs.size()==14,"all fourteen actual opponents")
	check(refs["prod-block"].cards==proposal.before_cards,"exact original Block list and order")
	check(catalog.validate(proposal.candidate_cards).ok,"candidate legal under unchanged 30-card rules")
	check(catalog.all_cards().size()==550,"actual complete production catalog")
	var seen_seeds: Dictionary={}
	var cases: Array=[]
	for opponent_index in source.decks.size():
		var opponent: String=source.decks[opponent_index].id
		for side_index in 2:
			var side="hero" if side_index==0 else "enemy"
			for block in 2:
				for coin_index in 2:
					var first="hero" if coin_index==0 else "enemy"
					var start=int(proposal.plan.seed_start)+opponent_index*100000+side_index*10000+block*1000+coin_index*500
					var seed_value=planned_seed(opponent,side,first,start)
					check(seed_value>=start and seed_value<start+500,"seed remains in its predeclared disjoint range")
					check(not seen_seeds.has(seed_value),"independent seed ranges do not reuse a case seed")
					seen_seeds[seed_value]=true
					cases.append({"index":cases.size(),"opponent":opponent,"tested_side":side,"first":first,"seed_block":block,"seed":seed_value,"seed_search_start":start,"pilot":opponent in ["prod-relic","prod-time","prod-control"] and block==0})
	check(cases.size()==112,"all112 prespecified A/B cases")
	var repeat_cases=[0,28,56,84]
	var plan={"format":"ORAFOLD-BLOCK-DECK-PLAN","version":1,"cases":cases,"source_hashes":source_hashes,"promotion_criteria":proposal.promotion_criteria,"repeat_cases_both_variants":repeat_cases,"expected_matrix_games":224,"expected_fresh_repeat_games":8,"notes":"All cases selected using only opening coin before the first completed game. The pilot is a fixed12-pair subset; no candidate modification is allowed after it."}
	var plan_file=FileAccess.open(PLAN,FileAccess.WRITE);plan_file.store_string(JSON.stringify(plan,"  ",true));plan_file.flush();plan_file.close()
	if failures>0:finish_report(plan);return
	journal=FileAccess.open("res://work/premium-balance/journal.jsonl",FileAccess.WRITE)
	var order: Array=[]
	for c in cases:
		if c.pilot:order.append(c.index)
	for c in cases:
		if not c.pilot:order.append(c.index)
	for case_index in order:
		var c: Dictionary=cases[case_index]
		for changed in [false,true]:
			var result=run_actual(c,changed)
			if result.is_empty():continue
			records.append(result);journal.store_line(JSON.stringify(result));journal.flush()
			if case_index in repeat_cases:
				var repeated=run_actual(c,changed,true)
				for key in ["event_sha256","final_state_sha256","rng_state","rng_calls"]:check(repeated.get(key)==result.get(key),"fresh complete deterministic repeat "+str(case_index)+"/"+result.variant+"/"+key)
				repeats.append(repeated)
			print("BLOCK A/B ",records.size(),"/224 case",case_index," ",result.variant,"/",c.opponent," side",c.tested_side," first",c.first," seed",c.seed," winner",result.winner," round",result.round)
	journal.close()
	check(records.size()==224,"every planned actual game recorded")
	check(repeats.size()==8,"all eight full-state/event/RNG repeats completed")
	for path in source_hashes:check(FileAccess.get_sha256("res://"+path)==source_hashes[path],"source unchanged during complete experiment "+path)
	finish_report(plan)

func finish_report(plan: Dictionary) -> void:
	var report={"format":"ORAFOLD-BLOCK-DECK-RESULTS","version":1,"godot":Engine.get_version_info().string,"assertions":assertions,"failures":failures,"source_hashes":source_hashes,"plan_sha256":FileAccess.get_sha256(PLAN),"plan":plan,"proposal":proposal,"games":records,"verification_games":repeats,"total_actual_games":records.size()+repeats.size(),"limits":["One predeclared reference-deck candidate, no change to cards/resources/rules/AI/starters.","Both variants use the exact same seed and first side per pair; fixed public-information production policy at difficulty2.","Hero origin is centrally fixed while the original enemy opening heuristic remains autonomous; first-player causality is not isolated.","The tiny historical0/12→4/12 pilot motivates this candidate only; its games are not included in this new result.","No claim of human balance, physical-device performance or complete550-card balance."]}
	var output=FileAccess.open(RESULT,FileAccess.WRITE);output.store_string(JSON.stringify(report,"  ",true));output.close()
	print("PREMIUM BLOCK BALANCE: ",assertions," assertions, ",failures," failures; ",records.size()," actual matrix games + ",repeats.size()," fresh verification games")
	var audio=get_root().get_node_or_null("GameAudio")
	if audio!=null:audio.request_quit(1 if failures else 0)
	else:quit(1 if failures else 0)
