extends SceneTree
## Full real-kernel AI matches. No damage shortcut, fake winner or alternate rules.
const Policy = preload("res://scripts/production/ai_policy.gd")
const OUTPUT := "res://work/alpha03/balance-fresh.json"
var assertions := 0
var failures := 0
var records: Array = []
var max_calls := 500
var per_first := 2
var quick := false
var shard_index := 0
var shard_count := 1
var planned_cases: Array=[]
var expected_verification_games := 0
var model_script: Script
var decks: Array = []
var source_hashes: Dictionary = {}
var verification_games := 0
var fresh_constructor_verification_games := 0
var configuration_template: RefCounted

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func make_game(a: Dictionary, b: Dictionary, seed_value: int, difficulty := 2, fresh := false):
	# Share only immutable validated catalog/configuration. Every match still gets
	# fresh mutable state, FIFO, RNG, source identities, ability uses and policy.
	var model = model_script.new() if fresh else model_script.new(configuration_template)
	var policy = Policy.new()
	policy.record_decisions = true
	model.ai_policy = policy
	if not model.start_alpha(a.cards,b.cards,seed_value,difficulty):
		check(false,"real model accepts reference decks "+a.id+"/"+b.id)
		return null
	var exchange: Array = []
	for index in model.state.hero.hand.size():
		if int(model.catalog.card(model.state.hero.hand[index]).cost)>3:exchange.append(index)
	if not model.mulligan(exchange):
		check(false,"mulligan accepted")
		return null
	return model
func seeds_for(a: Dictionary, b: Dictionary) -> Array:
	var selected: Array = []
	var counts := {"hero":0,"enemy":0}
	for seed_value in 4096:
		var model = make_game(a,b,seed_value)
		if model == null: return []
		if counts[model.state.coin]<per_first:
			counts[model.state.coin]+=1
			selected.append(seed_value)
		if counts.hero==per_first and counts.enemy==per_first:return selected
	check(false,"counterbalanced starting positions found "+a.id+"/"+b.id)
	return []
func finish(model) -> int:
	if not model.choose_origin(2):check(false,"choose origin before duel");return 0
	if model.state.stage=="second":
		var highest := -1
		for i in model.state.hero.hand.size():
			if int(model.catalog.card(model.state.hero.hand[i]).cost)>3:highest=i
		if highest>=0:model.second_exchange(highest)
		model.second_change((int(model.state.origins.hero)+1)%5)
		if not model.finish_opening():check(false,"second player completed opening")
	var calls := 0
	while model.state.winner==null and model.state.error.is_empty() and calls<max_calls:
		model.ai_turn("hero")
		calls+=1
	return calls
func event_digest(model) -> String: return JSON.stringify(model.events,"",true).sha256_text()
func metrics(model) -> Dictionary:
	var result: Dictionary = {}
	for side in ["hero","enemy"]:
		var report := {"turns_observed":0,"energy_at_action_phase":0,"known_card_energy_paid":0,"known_card_resonance_paid":0,"unspent_energy_at_end":0,"resonance_at_turn_begin":[],"resonance_peak_observed":0,"action_net_resonance_gained":0,"action_net_resonance_spent":0,"cards_played":{},"actions":{},"failed_action_attempts":0}
		for turn in model.ai_policy.turn_observations:
			if turn.side!=side:continue
			report.turns_observed+=1
			report.energy_at_action_phase+=int(turn.energy)
			report.resonance_at_turn_begin.append(turn.resonance)
			report.resonance_peak_observed=maxi(int(report.resonance_peak_observed),int(turn.resonance))
		for action in model.ai_policy.decisions:
			if action.side!=side:continue
			if not action.ok:
				report.failed_action_attempts+=1
				continue
			report.actions[action.method]=int(report.actions.get(action.method,0))+1
			var delta := int(action.after.resonance)-int(action.before.resonance)
			report.action_net_resonance_gained+=maxi(0,delta)
			report.action_net_resonance_spent+=maxi(0,-delta)
			report.resonance_peak_observed=maxi(int(report.resonance_peak_observed),int(action.after.resonance))
			if action.method in ["end_turn","declare_convergence"]:report.unspent_energy_at_end+=int(action.before.energy)
			if action.method=="play":
				var c: Dictionary=model.catalog.card(action.card_id)
				report.known_card_energy_paid+=int(c.cost)
				report.known_card_resonance_paid+=int(c.get("resonance_cost",0))
				report.cards_played[action.card_id]=int(report.cards_played.get(action.card_id,0))+1
		result[side]=report
	return result
func record(model,a: Dictionary,b: Dictionary,seed_value: int,calls: int) -> Dictionary:
	var event_counts: Dictionary = {}
	for event in model.events:event_counts[event.kind]=int(event_counts.get(event.kind,0))+1
	var convergence := false
	for event in model.events:
		if event.kind=="convergence_win":convergence=true
	var generic_statuses: Dictionary={}
	var generic_chains: Dictionary={}
	for entry in model.effect_runtime.log:
		generic_statuses[entry.status]=int(generic_statuses.get(entry.status,0))+1
		generic_chains[entry.chain]=int(generic_chains.get(entry.chain,0))+1
	var longest_generic:=0
	for count in generic_chains.values():longest_generic=maxi(longest_generic,int(count))
	return {"hero":a.id,"enemy":b.id,"hero_power":a.power,"enemy_power":b.power,"seed":seed_value,"difficulty":int(model.state.level),"first":model.state.coin,"winner":model.state.winner,"round":int(model.state.round),"hero_calls":calls,"convergence":convergence,"error":str(model.state.error),"censored":model.state.winner==null,"longest_native_chain":int(model.longest_chain),"longest_generic_chain":longest_generic,"generic_effect_statuses":generic_statuses,"event_counts":event_counts,"event_count":model.events.size(),"event_sha256":event_digest(model),"final_state_sha256":JSON.stringify(model.snapshot(),"",true).sha256_text(),"action_limit_reached":int(model.ai_policy.action_limit_reached),"metrics":metrics(model)}

func run() -> void:
	var bound_paths := ["tests/alpha03_balance.gd","data/production/cards.json","data/production/test_decks.json","data/production/starters.json","scripts/production/catalog.gd","scripts/alpha/catalog.gd","scripts/production/ai_policy.gd","scripts/card_system/production_model.gd","scripts/card_system/production_effects.gd","scripts/card_system/trigger_model.gd","scripts/card_system/runtime.gd","scripts/card_system/registry.gd","data/card_system/registry.json","data/card_system/alpha_species.json","data/alpha/cards.json","scripts/alpha/model.gd","scripts/legacy/battle_engine.gd","scripts/legacy/rng.gd"]
	for path in bound_paths:
		check(FileAccess.file_exists("res://"+path),"required bound source "+path)
		if FileAccess.file_exists("res://"+path):source_hashes[path]=FileAccess.get_sha256("res://"+path)
	model_script=load("res://scripts/card_system/production_model.gd")
	check(model_script!=null and model_script.can_instantiate(),"actual production kernel compiles")
	if model_script==null or not model_script.can_instantiate():quit(1);return
	configuration_template=model_script.new()
	var catalog=configuration_template.catalog
	check(catalog.all_cards().size()==550,"exact550 active catalog")
	var refs: Dictionary={}
	for entry in JSON.parse_string(FileAccess.get_file_as_string("res://data/production/test_decks.json")).decks:refs[entry.id]=entry
	for power in catalog.deck_ids():refs["starter-"+power]={"id":"starter-"+power,"power":power,"cards":catalog.deck(power)}
	var pairings: Array=[]
	for candidate in ["starter-ninth","prod-time"]:
		for opponent in ["starter-houses","starter-stillwatch","starter-morph"]:pairings.append([candidate,opponent])
	pairings.append(["prod-time","prod-relic"])
	# Plan every seed before playing; select only the opening coin, never winners.
	var plan: Array=[]
	for pair in pairings:
		for reverse in [false,true]:
			var a: Dictionary=refs[pair[1] if reverse else pair[0]]
			var b: Dictionary=refs[pair[0] if reverse else pair[1]]
			check(catalog.validate(a.cards).ok and catalog.validate(b.cards).ok,"both real decks legal")
			for level in [1,5]:
				var coins: Dictionary={}
				for seed_value in range(930017,934113):
					var probe=make_game(a,b,seed_value,level)
					if probe==null:continue
					var coin: String=probe.state.coin
					if not coins.has(coin):
						coins[coin]=true
						plan.append({"hero":a.id,"enemy":b.id,"difficulty":level,"seed":seed_value,"first":coin})
					if coins.size()==2:break
				check(coins.size()==2,"both starting coins planned")
	check(plan.size()==56,"complete56-game prespecified paired matrix")
	var plan_file=FileAccess.open("res://work/alpha03/balance-plan.json",FileAccess.WRITE)
	plan_file.store_string(JSON.stringify({"cases":plan,"source_hashes":source_hashes},"  ",true));plan_file.close()
	var replay_indices: Array=[0,7,32,55]
	var replay_results: Array=[]
	for index in plan.size():
		var c: Dictionary=plan[index]
		var model=make_game(refs[c.hero],refs[c.enemy],c.seed,c.difficulty)
		if model==null:continue
		check(model.state.coin==c.first,"planned coin preserved")
		var calls:=finish(model)
		var result:=record(model,refs[c.hero],refs[c.enemy],c.seed,calls)
		result["index"]=index;records.append(result)
		check(result.error.is_empty(),"engine error absent "+str(index))
		check(not result.censored,"complete uncensored match "+str(index))
		check(result.action_limit_reached==0,"AI action limit not reached "+str(index))
		if index in replay_indices:
			var replay=make_game(refs[c.hero],refs[c.enemy],c.seed,c.difficulty,true)
			finish(replay)
			var replay_event: String=event_digest(replay)
			var replay_state: String=JSON.stringify(replay.snapshot(),"",true).sha256_text()
			check(result.event_sha256==replay_event,"exact ordered events repeat "+str(index))
			check(result.final_state_sha256==replay_state,"exact full state repeat "+str(index))
			replay_results.append({"index":index,"event_sha256":replay_event,"final_state_sha256":replay_state})
		print("ALPHA03 BALANCE ",index+1,"/56 ",c.hero,"/",c.enemy," AI",c.difficulty," seed",c.seed," first",c.first," winner",result.winner," round",result.round)
	check(records.size()==56,"all planned outcomes retained")
	for path in source_hashes:check(FileAccess.get_sha256("res://"+path)==source_hashes[path],"source unchanged during run "+path)
	var report: Dictionary={"format":"ORAFOLD-ALPHA03-FRESH-BALANCE","version":1,"godot":Engine.get_version_info().string,"assertions":assertions,"failures":failures,"source_hashes":source_hashes,"plan_sha256":FileAccess.get_sha256("res://work/alpha03/balance-plan.json"),"games":records,"matrix_games":records.size(),"verification_games":replay_results,"total_actual_games":records.size()+replay_results.size(),"notes":["Fresh deterministic seeds selected before play using opening coin only.","Same unmodified production policy and difficulty apply to both sides; both board roles and opening coins counterbalanced.","Hero origin is fixed central while original enemy opening choices remain autonomous; this does not isolate the causal effect of initiative.","AIlevels1and5 are production policy variants, not independent optimal human play. No card, deck, resource or policy changed."]}
	var output=FileAccess.open(OUTPUT,FileAccess.WRITE);output.store_string(JSON.stringify(report,"  ",true));output.close()
	print("ALPHA03 BALANCE: ",assertions," assertions, ",failures," failures; ",records.size()," fresh matrix + ",replay_results.size()," replay games")
	quit(1 if failures else 0)
