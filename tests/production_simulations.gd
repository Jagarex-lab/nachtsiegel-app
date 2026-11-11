extends SceneTree
## Full real-kernel AI matches. No damage shortcut, fake winner or alternate rules.
const Policy = preload("res://scripts/production/ai_policy.gd")
const OUTPUT := "res://work/production/simulations.json"
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
func summarize() -> Dictionary:
	var summary := {"games":records.size(),"completed":0,"censored":0,"errors":0,"draws":0,"first_wins":0,"convergence_wins":0,"hero_damage_wins":0,"round_sum":0,"rounds":[],"deck_results":{},"power_results":{},"matchups":{},"card_uses":{},"unknown_card_ids":[],"event_counts":{},"total_energy_at_action_phase":0,"known_card_energy_paid":0,"unspent_energy_at_end":0,"action_net_resonance_gained":0,"action_net_resonance_spent":0,"failed_action_attempts":0,"longest_native_chain":0,"longest_generic_chain":0,"games_with_generic_chain_at_least10":0,"generic_effect_statuses":{},"played_card_game_results":{}}
	for r in records:
		if r.censored:summary.censored+=1
		else:summary.completed+=1
		if not r.error.is_empty():summary.errors+=1
		if r.winner=="draw":summary.draws+=1
		if r.winner==r.first:summary.first_wins+=1
		if r.convergence:summary.convergence_wins+=1
		elif r.winner in ["hero","enemy"]:summary.hero_damage_wins+=1
		summary.round_sum+=r.round;summary.rounds.append(r.round)
		summary.longest_native_chain=maxi(summary.longest_native_chain,int(r.longest_native_chain))
		summary.longest_generic_chain=maxi(summary.longest_generic_chain,int(r.longest_generic_chain))
		if int(r.longest_generic_chain)>=10:summary.games_with_generic_chain_at_least10+=1
		for status in r.generic_effect_statuses:summary.generic_effect_statuses[status]=int(summary.generic_effect_statuses.get(status,0))+int(r.generic_effect_statuses[status])
		for side in ["hero","enemy"]:
			var id: String=r[side]
			var power: String=r[side+"_power"]
			for group in ["deck_results","power_results"]:
				var key: String=id if group=="deck_results" else power
				if not summary[group].has(key):summary[group][key]={"games":0,"wins":0,"first_games":0,"first_wins":0,"convergence_wins":0,"nonmirror_games":0,"nonmirror_wins":0}
				var value: Dictionary=summary[group][key]
				value.games+=1
				if side==r.first:value.first_games+=1
				if side==r.winner:
					value.wins+=1
					if r.convergence:value.convergence_wins+=1
					if side==r.first:value.first_wins+=1
				if r.hero_power!=r.enemy_power:
					value.nonmirror_games+=1
					if side==r.winner:value.nonmirror_wins+=1
			var m: Dictionary=r.metrics[side]
			for key in ["known_card_energy_paid","unspent_energy_at_end","action_net_resonance_gained","action_net_resonance_spent","failed_action_attempts"]:summary[key]+=int(m[key])
			summary.total_energy_at_action_phase+=int(m.energy_at_action_phase)
			for id_value in m.cards_played:
				summary.card_uses[id_value]=int(summary.card_uses.get(id_value,0))+int(m.cards_played[id_value])
				if not summary.played_card_game_results.has(id_value):summary.played_card_game_results[id_value]={"side_games_played":0,"side_games_won":0}
				summary.played_card_game_results[id_value].side_games_played+=1
				if r.winner==side:summary.played_card_game_results[id_value].side_games_won+=1
		var pair: String=r.hero+"/"+r.enemy
		if not summary.matchups.has(pair):summary.matchups[pair]={"games":0,"hero_wins":0,"enemy_wins":0,"draws":0,"censored":0}
		summary.matchups[pair].games+=1
		if r.winner=="hero":summary.matchups[pair].hero_wins+=1
		elif r.winner=="enemy":summary.matchups[pair].enemy_wins+=1
		elif r.winner=="draw":summary.matchups[pair].draws+=1
		else:summary.matchups[pair].censored+=1
		for kind in r.event_counts:summary.event_counts[kind]=int(summary.event_counts.get(kind,0))+int(r.event_counts[kind])
	summary.rounds.sort()
	if not summary.rounds.is_empty():
		summary["mean_round"]=float(summary.round_sum)/float(records.size())
		summary["median_round"]=summary.rounds[summary.rounds.size()/2]
	summary.erase("rounds")
	summary["distinct_cards_used"]=summary.card_uses.size()
	summary["first_win_rate"]=float(summary.first_wins)/float(maxi(1,int(summary.completed)-int(summary.draws)))
	return summary
func run_pair(a: Dictionary,b: Dictionary,group: String,verify: bool) -> void:
	if verify:expected_verification_games+=1
	var paired_seeds := seeds_for(a,b)
	for seed_value in paired_seeds:
		var model=make_game(a,b,seed_value)
		if model==null:continue
		planned_cases.append({"group":group,"hero":a.id,"enemy":b.id,"seed":seed_value,"first":model.state.coin})
		var calls:=finish(model)
		var result:=record(model,a,b,seed_value,calls)
		result["group"]=group
		records.append(result)
		check(result.error.is_empty(),"no engine error "+a.id+"/"+b.id+" seed"+str(seed_value)+" "+result.error)
		check(not result.censored,"complete result "+a.id+"/"+b.id+" seed"+str(seed_value))
		check(result.action_limit_reached==0,"bounded AI actions "+a.id+"/"+b.id+str(seed_value))
		if verify and seed_value==paired_seeds[0]:
			var fresh := fresh_constructor_verification_games<2
			var replay=make_game(a,b,seed_value,2,fresh)
			finish(replay);verification_games+=1
			if fresh:fresh_constructor_verification_games+=1
			check(result.event_sha256==event_digest(replay),"exact full deterministic event replay "+a.id)
			check(result.final_state_sha256==JSON.stringify(replay.snapshot(),"",true).sha256_text(),"exact full deterministic state replay "+a.id)
	print("PRODUCTION SIMULATION: completed ",group," ",a.id,"/",b.id,"; ",records.size()," matrix games")

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument=="--quick":quick=true;per_first=1
		elif argument.begins_with("--per-first="):
			var value:=argument.trim_prefix("--per-first=")
			if not value.is_valid_int() or int(value)<1 or int(value)>32:check(false,"per-first must be an integer1..32; no silent sampling reduction");quit(1);return
			per_first=int(value)
		elif argument.begins_with("--shard="):
			var spec:=argument.trim_prefix("--shard=").split("/")
			if spec.size()!=2 or not spec[0].is_valid_int() or not spec[1].is_valid_int():check(false,"invalid shard syntax, expected zero-based I/N");quit(1);return
			shard_index=int(spec[0]);shard_count=int(spec[1])
	if shard_count<1 or shard_count>32 or shard_index<0 or shard_index>=shard_count:check(false,"shard index in0..N-1 and N1..32");quit(1);return
	if quick and shard_count!=1:check(false,"quick and sharding cannot be combined");quit(1);return
	var bound_paths := ["tests/production_simulations.gd","data/production/cards.json","data/production/test_decks.json","data/production/starters.json","scripts/production/catalog.gd","scripts/alpha/catalog.gd","scripts/production/ai_policy.gd","scripts/card_system/production_model.gd","scripts/card_system/production_effects.gd","scripts/card_system/trigger_model.gd","scripts/card_system/runtime.gd","scripts/card_system/registry.gd","data/card_system/registry.json","data/card_system/alpha_species.json","data/alpha/cards.json","scripts/alpha/model.gd","scripts/legacy/battle_engine.gd","scripts/legacy/rng.gd"]
	for path in bound_paths:
		if FileAccess.file_exists("res://"+path):source_hashes[path]=FileAccess.get_sha256("res://"+path)
	model_script=load("res://scripts/card_system/production_model.gd")
	check(model_script!=null and model_script.can_instantiate(),"production model exists and compiles; unsupported is not a passed simulation")
	if model_script==null or not model_script.can_instantiate():quit(1);return
	if not FileAccess.file_exists("res://data/production/test_decks.json"):check(false,"real reference decks exist");quit(1);return
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/production/test_decks.json"))
	decks=source.get("decks",[])
	check(decks.size()==14,"all fourteen strategy reference decks")
	configuration_template=model_script.new()
	var catalog=configuration_template.catalog
	check(catalog.all_cards().size()==550,"exact550 active data, not test stubs")
	for deck in decks:check(catalog.validate(deck.cards).ok,"reference deck legal "+deck.id)
	var selected_strategy_pairs:=0
	for a_index in decks.size():
		for b_index in decks.size():
			if quick and b_index!=(a_index+1)%decks.size():continue
			if (a_index*decks.size()+b_index)%shard_count!=shard_index:continue
			selected_strategy_pairs+=1
			var a: Dictionary=decks[a_index];var b: Dictionary=decks[b_index]
			run_pair(a,b,"strategy",b_index==(a_index+1)%decks.size())
	var strategy_count:=records.size()
	var starters: Array=[]
	for power in catalog.deck_ids():
		var deck: Dictionary={"id":"starter-"+power,"power":power,"cards":catalog.deck(power)}
		check(catalog.validate(deck.cards).ok,"visible starter legal "+power)
		starters.append(deck)
	check(starters.size()==4,"four visible production starters")
	var selected_starter_pairs:=0
	for a_index in starters.size():
		for b_index in starters.size():
			if (decks.size()*decks.size()+a_index*starters.size()+b_index)%shard_count!=shard_index:continue
			selected_starter_pairs+=1
			run_pair(starters[a_index],starters[b_index],"starter",b_index==(a_index+1)%starters.size())
	var starter_count:=records.size()-strategy_count
	var theoretical_strategy:=selected_strategy_pairs*per_first*2
	var theoretical_starter:=selected_starter_pairs*per_first*2
	var theoretical:=theoretical_strategy+theoretical_starter
	check(strategy_count==theoretical_strategy,"complete planned strategy matrix, no dropped unsupported cases")
	check(starter_count==theoretical_starter,"complete selected starter matrix, no dropped unsupported cases")
	check(verification_games==expected_verification_games,"all selected full-state/event replay controls completed")
	var source_changes: Array=[]
	for path in source_hashes:
		if source_hashes[path]!=FileAccess.get_sha256("res://"+path):source_changes.append(path)
	check(source_changes.is_empty(),"executed sources remained frozen throughout simulation "+str(source_changes))
	var report: Dictionary={"schema_version":1,"profile":"production-550-v1","godot":Engine.get_version_info().string,"quick":quick,"shard_index":shard_index,"shard_count":shard_count,"planned_cases":planned_cases,"expected_global_matrix_games":(decks.size()*(1 if quick else decks.size())+starters.size()*starters.size())*per_first*2,"expected_verification_games":expected_verification_games,"seeds_per_first_side":per_first,"expected_matrix_games":theoretical,"strategy_matrix_games":strategy_count,"starter_matrix_games":starter_count,"matrix_games":records.size(),"additional_verification_games":verification_games,"fresh_constructor_verification_games":fresh_constructor_verification_games,"assertions":assertions,"failures":failures,"measurement_notes":["Full real model matches, standard30-card/30HP rules; no altered resource rules.","Each ordered pair has equal counts for hero/enemy first, seeds selected deterministically.","AI reads only public opponent board/hero values and its own cards; no bonus resources.","Immutable validated configuration is shared between fresh match instances; first two deterministic repeats use wholly fresh constructors and compare complete final state/event order.","action_net_resonance totals are measured net changes per AI action; automatic effects between actions and cancelling simultaneous gains/spends are not a gross resource-flow accounting.","known_card_energy_paid counts printed successfully played card costs; it excludes relic/tactic costs and automatic gains.","These heuristic AI games do not prove human metagame balance or exhaustive550-card interactions.","Quick strategy mode covers only a ring of fourteen strategy pairs; full mode covers196 ordered strategy pairs. Both include16 ordered starter pairs."],"summary":summarize(),"games":records,"source_sha256":source_hashes,"source_changes_during_run":source_changes}
	DirAccess.make_dir_recursive_absolute("res://work/production")
	var output_path:=OUTPUT if shard_count==1 else "res://work/production/simulations-shard-%d-of-%d.json"%[shard_index,shard_count]
	var output=FileAccess.open(output_path,FileAccess.WRITE)
	check(output!=null,"write simulation evidence")
	report.assertions=assertions;report.failures=failures
	if output!=null:output.store_string(JSON.stringify(report,"\t",true));output.close()
	print("PRODUCTION SIMULATIONS: ",assertions," assertions; ",failures," failures; ",records.size()," matrix games + ",verification_games," verification games")
	print(JSON.stringify(report.summary,"",true))
	quit(0 if failures==0 else 1)
