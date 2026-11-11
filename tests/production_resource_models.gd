extends SceneTree
## A test-only subclass changes two caps. No experimental profile is exposed by Session/UI.
const Model=preload("res://scripts/card_system/production_model.gd")
const Policy=preload("res://scripts/production/ai_policy.gd")
const BASELINE="res://tests/fixtures/production/resource_baseline.json"
const OUTPUT="res://work/production/resource-models.json"
const CONDITIONS=[
 {"id":"energy8_res15","energy":8,"resonance":15},
 {"id":"energy10_res15","energy":10,"resonance":15},
 {"id":"energy10_res20","energy":10,"resonance":20},
]
class ResourceModel extends Model:
 var test_energy_cap:=8
 var test_resonance_cap:=15
 func energy_limit() -> int:return test_energy_cap
 func resonance_limit() -> int:return test_resonance_cap

var assertions:=0
var failures:=0
var records: Array=[]
var hashes: Dictionary={}
var template: RefCounted
var verification_games:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 assertions+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func digest(value: Variant) -> String:return JSON.stringify(value,"",true).sha256_text()
func read_json(path: String) -> Dictionary:return JSON.parse_string(FileAccess.get_file_as_string(path))
func source_hashes() -> Dictionary:
 var result: Dictionary={}
 for p in ["scripts/legacy/battle_engine.gd","scripts/alpha/model.gd","scripts/card_system/trigger_model.gd","scripts/card_system/production_model.gd","scripts/card_system/production_effects.gd","scripts/card_system/runtime.gd","scripts/production/ai_policy.gd","scripts/production/catalog.gd","data/production/cards.json","data/production/starters.json","tests/production_resource_models.gd",BASELINE.trim_prefix("res://")]:result[p]=FileAccess.get_sha256("res://"+p)
 return result
func make_game(g: Dictionary,condition: Dictionary,plain:=false):
 var m=Model.new(template) if plain else ResourceModel.new(template)
 if not plain:m.test_energy_cap=condition.energy;m.test_resonance_cap=condition.resonance
 m.ai_policy=Policy.new();m.ai_policy.record_decisions=true
 var a: Array=m.catalog.deck(str(g.hero).trim_prefix("starter-"))
 var b: Array=m.catalog.deck(str(g.enemy).trim_prefix("starter-"))
 if not m.start_alpha(a,b,int(g.seed),2):check(false,"actual starter decks accepted");return null
 var exchange: Array=[]
 for i in m.state.hero.hand.size():
  if int(m.catalog.card(m.state.hero.hand[i]).cost)>3:exchange.append(i)
 if not m.mulligan(exchange):check(false,"actual mulligan");return null
 return m
func finish(m) -> void:
 check(m.choose_origin(2),"origin accepted")
 if m.state.stage=="second":
  var highest:=-1
  for i in m.state.hero.hand.size():
   if int(m.catalog.card(m.state.hero.hand[i]).cost)>3:highest=i
  if highest>=0:check(m.second_exchange(highest),"second exchange")
  check(m.second_change((int(m.state.origins.hero)+1)%5),"second origin")
  check(m.finish_opening(),"second opening complete")
 var calls:=0
 while m.state.winner==null and m.state.error.is_empty() and calls<500:
  m.ai_turn("hero");calls+=1
 check(m.state.winner!=null and m.state.error.is_empty(),"full real duel; no forced result")
 check(m.ai_policy.action_limit_reached==0,"no policy action limit")
func record(m,g: Dictionary,c: Dictionary) -> Dictionary:
 var result: Dictionary={"condition":c.id,"hero":g.hero,"enemy":g.enemy,"seed":g.seed,"first":m.state.coin,"winner":m.state.winner,"round":m.state.round,"convergence":not m.events.is_empty() and m.events[-1].kind=="convergence_win","event_sha256":digest(m.events),"final_state_sha256":digest(m.snapshot()),"error":m.state.error,"censored":m.state.winner==null,"energy_at_actions":0,"known_card_energy_paid":0,"unspent_energy":0,"net_resonance_gain":0,"net_resonance_spent":0,"resonance_peak":0,"cards_played":{}}
 for t in m.ai_policy.turn_observations:
  result.energy_at_actions+=int(t.energy);result.resonance_peak=maxi(result.resonance_peak,int(t.resonance))
 for a in m.ai_policy.decisions:
  if not a.ok:check(false,"no illegal policy command in experiment");continue
  var delta:=int(a.after.resonance)-int(a.before.resonance)
  result.net_resonance_gain+=maxi(0,delta);result.net_resonance_spent+=maxi(0,-delta)
  result.resonance_peak=maxi(result.resonance_peak,int(a.after.resonance))
  if a.method=="play":
   result.known_card_energy_paid+=int(m.catalog.card(a.card_id).cost)
   result.cards_played[a.card_id]=int(result.cards_played.get(a.card_id,0))+1
  if a.method in ["end_turn","declare_convergence"]:result.unspent_energy+=int(a.before.energy)
 return result
func boundaries() -> void:
 for c in CONDITIONS:
  for side in ["hero","enemy"]:
   var g={"hero":"starter-houses","enemy":"starter-stillwatch","seed":42}
   var m=make_game(g,c)
   m.state.stage="battle";m.state.active=side;m.state.round=17;m.state.origins={"hero":2,"enemy":2}
   for name in ["hero","enemy"]:
    m.state[name].lanes=[null,null,null,null,null];m.state[name].relic=null;m.state[name].resonance=0
   m.state[side].turns=9
   check(m.begin_turn(side) and int(m.state[side].energy)==int(c.energy),"own refresh uses cap before turn triggers "+c.id+side)
   m.state[side].phase="main";m.state[side].energy=int(c.energy)-1
   var ability={"mode":"triggered","trigger":"on_play","effect":"gain_energy","target":"self","params":{"amount":3},"limit":"once_per_turn"}
   m.production_apply(side,ability,{"source_instance":"resource-boundary"})
   check(int(m.state[side].energy)==int(c.energy),"generic energy gain shares refresh cap "+c.id+side)
   m.state[side].resonance=int(c.resonance)-1;m.add_res(m.state[side],9)
   check(int(m.state[side].resonance)==int(c.resonance),"ordinary resonance cap "+c.id+side)
   # Native harvest must share exactly the same cap, not a second fixed15 path.
   var harvest: Dictionary={}
   for card in m.catalog.all_cards():
    if card.kind=="creature" and card.effect=="harvest":harvest=card;break
   check(not harvest.is_empty(),"actual native harvest record exists")
   if not harvest.is_empty():
    m.state[side].resonance=int(c.resonance)-1
    var u: Dictionary=m.make_unit(side,harvest,0);u.hp=0
    m._resolve_death({"type":"death","side":side,"lane":0,"unit":u})
    check(int(m.state[side].resonance)==int(c.resonance),"native harvest cap "+c.id+side)
   # A real matching unit isolates the threshold from the separate formation rule.
   m.state[side].lanes[0]=m.make_unit(side,m.catalog.card("oa-houses-c01"),0)
   m.state[side].resonance=14
   var before: Dictionary=m.snapshot()
   check(not m.burst(side,"houses") and m.snapshot()==before,"burst threshold stays15, illegal action immutable "+c.id+side)
   m.state[side].resonance=15
   check(m.burst(side,"houses") and int(m.state[side].resonance)==7,"burst threshold15 and cost8 unchanged "+c.id+side)
func run() -> void:
 hashes=source_hashes();template=Model.new()
 var baseline:=read_json(BASELINE)
 check(baseline.format=="ORAFOLD-PRE-SEAM-STARTER-EVIDENCE" and baseline.games.size()==64,"all64 real pre-seam starter digests")
 check(template.energy_limit()==8 and template.resonance_limit()==15,"production defaults stay8/15")
 boundaries()
 for c in CONDITIONS:
  var pair_counts: Dictionary={}
  for g in baseline.games:
   var key: String=g.hero+"/"+g.enemy
   if not pair_counts.has(key):pair_counts[key]={"hero":0,"enemy":0}
   pair_counts[key][g.first]+=1
   var m=make_game(g,c)
   if m==null:continue
   check(m.state.coin==g.first,"same seed/start side "+c.id+key)
   finish(m)
   var row:=record(m,g,c);records.append(row)
   if c.id==CONDITIONS[0].id:
    for field in ["winner","round","convergence","event_sha256","final_state_sha256"]:check(row[field]==g[field],"default equals actual pre-seam full evidence "+key+"/"+str(g.seed)+"/"+field)
  check(pair_counts.size()==16,"all16 ordered starter matchups "+c.id)
  for key in pair_counts:check(pair_counts[key]=={"hero":2,"enemy":2},"balanced first positions "+c.id+key)
  for index in [0,21]:
   var g: Dictionary=baseline.games[index];var m=make_game(g,c);finish(m);verification_games+=1
   var repeated:=record(m,g,c)
   check(repeated==records[(int(CONDITIONS.find(c))*64)+index],"full repeat state/event/metrics deterministic "+c.id)
 # Ordinary default factory versus experimental subclass at default caps.
 for index in [0,16,32,48]:
  var g: Dictionary=baseline.games[index];var m=make_game(g,CONDITIONS[0],true);finish(m);verification_games+=1
  check(record(m,g,CONDITIONS[0])==records[index],"plain constructor equals default subclass including complete event/state digests")
 check(records.size()==192 and verification_games==10,"exact192matrix plus10additional actual duels")
 check(source_hashes()==hashes,"source files unchanged during whole experiment")
 var report={"schema_version":1,"suite":"production_resource_models","profile":"test-only cap comparison; ordinary production unchanged8/15","conditions":CONDITIONS,"matrix_games":records.size(),"additional_verification_games":verification_games,"pre_seam_default_comparisons":64,"source_sha256":hashes,"baseline_report_sha256":baseline.source_report_sha256,"assertions":assertions,"failures":failures,"games":records,"measurement_notes":["Actual550-card catalog and four actual30-card starter decks; no synthetic playable cards or shortcut engine.","Same retained policy and exact predeclared seeds/start sides in each condition; experimental caps are never exposed through Session or UI.","Energy metrics are observed action-boundary values/known printed card payments, not complete gross accounting. Resonance changes are net per AI action, not hidden simultaneous gross flow.","A small paired self-play sample does not establish human balance or full550-card metagame coverage."]}
 var out=FileAccess.open(OUTPUT,FileAccess.WRITE);out.store_string(JSON.stringify(report,"  ",true)+"\n");out.close()
 print("PRODUCTION RESOURCE MODELS: ",assertions," assertions; ",failures," failures; ",records.size()," actual matrix games + ",verification_games," verification games")
 quit(1 if failures else 0)
