extends "res://tests/production_simulations.gd"
## Test orchestration only: inherit the existing real-model setup, policy, turns
## and observations. Never copy a combat engine or change a card/rule/AI method.
const DECK_FIXTURE="res://tests/fixtures/production/full_pool_decks.json"
const CORE_COMMIT="d3c7c7bf1e2d714aef896d39538bfd343d2365c2"
const POWERS=["houses","stillwatch","morph","ninth"]
const REPEAT_CASES=[0,57,64,121,128,185,192,249]
const FRESH_CASES=[2,67,130,195]
const BOUND_PATHS=["tests/production_full_pool_coverage.gd","tests/production_simulations.gd","tests/fixtures/production/full_pool_decks.json","tools/production/build_full_pool_decks.py","data/production/cards.json","data/production/starters.json","scripts/production/catalog.gd","scripts/alpha/catalog.gd","scripts/production/ai_policy.gd","scripts/card_system/production_model.gd","scripts/card_system/production_effects.gd","scripts/card_system/trigger_model.gd","scripts/card_system/runtime.gd","scripts/card_system/registry.gd","data/card_system/registry.json","data/card_system/alpha_species.json","data/alpha/cards.json","scripts/alpha/model.gd","scripts/legacy/battle_engine.gd","scripts/legacy/rng.gd"]
var deck_by_id: Dictionary={}
var controls: Array=[]
var planning_openings:=0
var output_prefix="res://work/production/full-pool-coverage"
var plan_hash=""
var plan_only:=false
var selected_case:=-1
var journal: FileAccess
var run_start_usec:=0
var executed_commit=""

func plan_seeds(a: Dictionary,b: Dictionary) -> Array:
 var selected: Array=[]
 var counts={"hero":0,"enemy":0}
 for seed_value in 4096:
  var model=make_game(a,b,seed_value)
  planning_openings+=1
  if model==null:continue
  var first: String=model.state.coin
  if counts[first]<2:
   selected.append({"seed":seed_value,"first":first});counts[first]+=1
  if counts.hero==2 and counts.enemy==2:return selected
 check(false,"could not predeclare balanced real opening seeds "+a.id+"/"+b.id)
 return selected

func build_plan() -> Dictionary:
 var groups: Dictionary={}
 for power in POWERS:groups[power]=[]
 for deck in decks:
  deck_by_id[deck.id]=deck;groups[deck.power].append(deck)
 for power in POWERS:
  groups[power].sort_custom(func(a: Dictionary,b: Dictionary):return a.id<b.id)
  check(groups[power].size()==8,"eight exposure decks for "+power)
 var cases: Array=[]
 for power_index in 4:
  for local_index in 8:
   var a: Dictionary=groups[POWERS[power_index]][local_index]
   var opponents=[groups[POWERS[(power_index+1)%4]][local_index],groups[POWERS[(power_index+2)%4]][(local_index+3)%8]]
   for b in opponents:
    var pair_index: int=cases.size()/4
    for opening in plan_seeds(a,b):
     cases.append({"case_index":cases.size(),"case_id":"coverage-%03d"%cases.size(),"pair_index":pair_index,"hero":a.id,"enemy":b.id,"hero_power":a.power,"enemy_power":b.power,"seed":int(opening.seed),"first":opening.first})
 check(cases.size()==256,"all256 predeclared cases before playing any full match")
 var control_plan: Array=[]
 for index in REPEAT_CASES:control_plan.append({"kind":"repeat","matrix_case_index":index})
 for index in FRESH_CASES:control_plan.append({"kind":"fresh_constructor","matrix_case_index":index})
 return {"schema_version":1,"suite":"production_full_pool_coverage","base_core_commit":CORE_COMMIT,"executed_commit":executed_commit,"deck_fixture_sha256":FileAccess.get_sha256(DECK_FIXTURE),"expected_matrix_games":256,"expected_repeats":8,"expected_fresh_constructor_games":4,"opening_probes_not_full_games":planning_openings,"cases":cases,"controls":control_plan}

func stable_result(row: Dictionary) -> String:
 var stable:=row.duplicate(true)
 stable.erase("wall_usec")
 return JSON.stringify(stable,"",true).sha256_text()

func play_case(c: Dictionary,fresh:=false) -> Dictionary:
 var a: Dictionary=deck_by_id[c.hero]
 var b: Dictionary=deck_by_id[c.enemy]
 var start_usec:=Time.get_ticks_usec()
 var model=make_game(a,b,int(c.seed),2,fresh)
 if model==null:
  return {"case_index":c.case_index,"case_id":c.case_id,"hero":c.hero,"enemy":c.enemy,"seed":c.seed,"first":c.first,"winner":null,"error":"model_initialization_failed","censored":true,"initialization_failed":true,"wall_usec":Time.get_ticks_usec()-start_usec}
 check(model.state.coin==c.first,"actual first side equals frozen plan "+c.case_id)
 var calls:=finish(model)
 var elapsed:=Time.get_ticks_usec()-start_usec
 var result:=record(model,a,b,int(c.seed),calls)
 result["case_index"]=c.case_index;result["case_id"]=c.case_id
 result["group"]="full_pool_coverage"
 result["wall_usec"]=elapsed
 result["initialization_failed"]=false
 result["policy_decisions"]=model.ai_policy.decisions.size()
 result["generic_effect_operations"]={}
 result["generic_applied_by_card"]={}
 for entry in model.effect_runtime.log:
  var operation: String=str(entry.effect)+"/"+str(entry.status)
  result.generic_effect_operations[operation]=int(result.generic_effect_operations.get(operation,0))+1
  if entry.status=="applied":
   var source: String=entry.context.get("source_card_id","")
   if not source.is_empty():
    if not result.generic_applied_by_card.has(source):result.generic_applied_by_card[source]={}
    var effects: Dictionary=result.generic_applied_by_card[source]
    effects[entry.effect]=int(effects.get(entry.effect,0))+1
 result["illegal_card_play_attempts"]=0
 for action in model.ai_policy.decisions:
  if action.method=="play" and not action.ok:result.illegal_card_play_attempts+=1
 return result

func validate_game(row: Dictionary,label: String) -> void:
 check(row.error.is_empty(),"no engine error "+label+" "+str(row.error))
 check(not row.censored,"actual completed game "+label)
 if row.get("initialization_failed",true):return
 check(row.winner in ["hero","enemy","draw"],"actual winner "+label)
 check(int(row.action_limit_reached)==0,"no policy action ceiling "+label)
 check(int(row.illegal_card_play_attempts)==0,"no illegal advertised card play "+label)

func append_journal(kind: String,index: int,row: Dictionary,control_kind: String="") -> void:
 journal.store_line(JSON.stringify({"record_type":kind,"case_index":index,"control_kind":control_kind,"game":row},"",true))
 journal.flush()

func save_report(plan: Dictionary,run_state: String,source_changes: Array) -> void:
 var report={"schema_version":1,"suite":"production_full_pool_coverage","profile":"production-550-v1","base_core_commit":CORE_COMMIT,"executed_commit":executed_commit,"godot":Engine.get_version_info().string,"run_state":run_state,"diagnostic_case_index":selected_case,"expected_matrix_games":256,"matrix_games":records.size(),"expected_repeat_games":8,"expected_fresh_constructor_games":4,"additional_verification_games":controls.size(),"max_hero_calls_per_game":max_calls,"planning_openings_not_full_games":planning_openings,"planned_cases":plan.cases,"control_plan":plan.controls,"plan_sha256":plan_hash,"decks":decks,"assertions":assertions,"failures":failures,"source_sha256":source_hashes,"source_changes_during_run":source_changes,"source_guard_completed":run_state=="completed","games":records,"controls":controls,"total_elapsed_usec":Time.get_ticks_usec()-run_start_usec,"measurement_notes":["Only existing ProductionModel and AI; orchestration inherits production_simulations.gd setup, full turns and actual observations. No engine/card/rule/policy edits.","32 legal30-card decks collectively include550 IDs; membership never means actual play. Successful play counts come only from observed policy commands.","All64 directed pairs and256 seeds/first sides are written to a separate frozen plan before the first complete duel. Opening-only seed probes are excluded from played-game totals.","Every planned game is retained, including errors/censors; no chosen replacement winner and no silent case removal. Max500 hero policy calls is a technical stop, not a draw rule.","Eight repeats and four fresh constructors are separate controls, never added to matrix coverage or headline256 games. Determinism excludes only measured wall time.","Generic effect counts come from actual runtime effect/status entries, not printed abilities. Native event-kind counts are observed traces, not exhaustive per-handler coverage.","Energy is observed action-phase availability/printed successful play costs/end residue; resonance is net per action, not complete gross accounting. Peaks are observed boundaries.","Wall time measures setup/opening/real match until finish returns, before report aggregation; shared hardware/load makes this a sample, not a benchmark guarantee.","Journal flushes each completed attempt. An externally interrupted run retains its frozen plan and actual finished attempts; unrun cases must remain explicitly unrun.","Heuristic self-play samples interactions/performance; neither550 played identities nor all interactions/human balance are guaranteed."]}
 var target=FileAccess.open(output_prefix+".json",FileAccess.WRITE)
 check(target!=null,"write raw sampler report")
 if target!=null:
  report.assertions=assertions;report.failures=failures
  target.store_string(JSON.stringify(report,"\t",true)+"\n");target.close()

func run() -> void:
 run_start_usec=Time.get_ticks_usec()
 executed_commit=OS.get_environment("ORAFOLD_COVERAGE_SOURCE_COMMIT")
 for argument in OS.get_cmdline_user_args():
  if argument=="--plan-only":plan_only=true
  elif argument.begins_with("--case-index="):
   var value:=argument.trim_prefix("--case-index=")
   if not value.is_valid_int() or int(value)<0 or int(value)>=256:check(false,"case index0..255");quit(1);return
   selected_case=int(value)
 if plan_only:output_prefix+="-planning"
 elif selected_case>=0:output_prefix+="-case-%03d"%selected_case
 DirAccess.make_dir_recursive_absolute("res://work/production")
 for path in BOUND_PATHS:source_hashes[path]=FileAccess.get_sha256("res://"+path)
 model_script=load("res://scripts/card_system/production_model.gd")
 configuration_template=model_script.new()
 check(configuration_template.catalog.all_cards().size()==550,"actual550 pool")
 check(configuration_template.energy_limit()==8 and configuration_template.resonance_limit()==15,"unchanged default8/15")
 var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DECK_FIXTURE))
 decks=fixture.get("decks",[])
 check(decks.size()==32,"all32 declared decks")
 var membership: Dictionary={}
 for deck in decks:
  check(configuration_template.catalog.validate(deck.cards).ok,"actual engine accepts legal30-card deck "+deck.id)
  for id in deck.cards:membership[id]=true
 check(membership.size()==550,"all550 identities appear in deck lists")
 var plan:=build_plan()
 planned_cases=plan.cases
 var plan_file=FileAccess.open(output_prefix+"-plan.json",FileAccess.WRITE)
 plan_file.store_string(JSON.stringify(plan,"\t",true)+"\n");plan_file.close()
 plan_hash=FileAccess.get_sha256(output_prefix+"-plan.json")
 save_report(plan,"planning_only" if plan_only else "running",[])
 if plan_only:
  print("FULL POOL PLANNING: ",assertions," assertions; ",failures," failures; no full games")
  quit(1 if failures else 0);return
 journal=FileAccess.open(output_prefix+"-journal.jsonl",FileAccess.WRITE)
 for c in planned_cases:
  if selected_case>=0 and c.case_index!=selected_case:continue
  print("FULL POOL CASE START: ",c.case_id," ",c.hero,"/",c.enemy," seed=",c.seed," first=",c.first)
  var row:=play_case(c)
  records.append(row);append_journal("matrix",int(c.case_index),row)
  validate_game(row,c.case_id)
  if records.size()%4==0:print("FULL POOL: ",records.size()," actual matrix attempts; ",failures," failed checks")
 if selected_case<0:
  for control in plan.controls:
   var index: int=control.matrix_case_index
   print("FULL POOL CONTROL START: ",control.kind," ",planned_cases[index].case_id)
   var replay:=play_case(planned_cases[index],control.kind=="fresh_constructor")
   append_journal("control",index,replay,control.kind)
   validate_game(replay,"control "+str(index))
   var identical:=stable_result(replay)==stable_result(records[index])
   check(identical,"full state/event/metrics deterministic "+control.kind+str(index))
   controls.append({"kind":control.kind,"matrix_case_index":index,"identical_excluding_wall_time":identical,"game":replay})
  check(records.size()==256 and controls.size()==12,"exact256 attempts plus8repeat/4fresh controls")
 journal.close()
 var changes: Array=[]
 for path in source_hashes:
  if source_hashes[path]!=FileAccess.get_sha256("res://"+path):changes.append(path)
 check(changes.is_empty(),"all executed sources frozen")
 check(FileAccess.get_sha256(output_prefix+"-plan.json")==plan_hash,"pre-match plan remained frozen")
 save_report(plan,"completed",changes)
 print("FULL POOL COVERAGE: ",assertions," assertions; ",failures," failures; ",records.size()," actual matrix games + ",controls.size()," controls")
 quit(1 if failures else 0)
