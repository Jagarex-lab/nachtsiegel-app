extends SceneTree
## Regression for the actual500-call shield/control seed2 failure.
const Model=preload("res://scripts/card_system/production_model.gd")
var assertions:=0
var failures:=0
var games:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 assertions+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func definitions() -> Dictionary:
 var result: Dictionary={}
 var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/production/test_decks.json"))
 for deck in source.decks:result[deck.id]=deck
 return result
func fixture(side: String):
 var m=Model.new()
 m.start_alpha(m.catalog.deck("stillwatch"),m.catalog.deck("stillwatch"),12,2)
 m.state.stage="battle";m.state.active=side;m.state.coin=side;m.state.round=13;m.state.origins={"hero":4,"enemy":4}
 for candidate in ["hero","enemy"]:
  m.state[candidate].phase="main";m.state[candidate].lanes=[null,null,null,null,null]
 for lane in 5:
  for candidate in ["hero","enemy"]:
   var u: Dictionary=m.make_unit(candidate,m.catalog.card("oa-neutral-c02"),lane)
   u.summoned=false;u.atk=0 if candidate==side else 2;u.ward=10
   m.state[candidate].lanes[lane]=u
 m.state[side].energy=8;m.state[side].resonance=0
 return m
func test_decisions() -> void:
 for side in ["hero","enemy"]:
  var m=fixture(side)
  m.state[side].relic={"id":"of-stillwatch-089","uid":1};m._relic_serial=1
  m.state[side].hand=["of-stillwatch-097","of-stillwatch-089"]
  var before: Dictionary=m.snapshot()
  var best: Dictionary=m.ai_policy.choose_play(m,side)
  check(not best.is_empty() and best.card_id=="of-stillwatch-097","blocked full board chooses actual attack-growth finisher "+side)
  check(before==m.snapshot(),"finisher evaluation does not change model "+side)
  check(m.play(side,best.index,best.lane),"chosen finisher is genuinely playable "+side)
  check(m.state[side].relic.id=="of-stillwatch-097","growth relic installed through real model "+side)
  m.state[side].energy=8;m.state[side].hand=["of-stillwatch-089"]
  best=m.ai_policy.choose_play(m,side)
  check(best.is_empty() or best.score<0,"does not replace active finisher with another protection-only relic "+side)
  m=fixture(side)
  m.state[side].hand=["of-stillwatch-097","of-stillwatch-097","oa-neutral-c02"]
  check(m.ai_policy._burn_index(m,side)!=0,"preserves best growth copy during required burn "+side)
func complete(a: Dictionary,b: Dictionary,seed_value: int):
 var m=Model.new()
 check(m.start_alpha(a.cards,b.cards,seed_value,2),"actual legal finisher decks "+a.id+b.id)
 var exchange: Array=[]
 for i in m.state.hero.hand.size():
  if m.catalog.card(m.state.hero.hand[i]).cost>3:exchange.append(i)
 check(m.mulligan(exchange),"mulligan")
 check(m.choose_origin(2),"origin")
 if m.state.stage=="second":
  var highest: int=-1
  for i in m.state.hero.hand.size():
   if m.catalog.card(m.state.hero.hand[i]).cost>3:highest=i
  if highest>=0:m.second_exchange(highest)
  m.second_change((int(m.state.origins.hero)+1)%5)
  check(m.finish_opening(),"second-player opening")
 var calls:=0
 while m.state.winner==null and m.state.error.is_empty() and calls<200:
  m.ai_turn("hero");calls+=1
 games+=1
 check(m.state.error.is_empty(),"no engine error "+a.id+b.id+str(seed_value))
 check(m.state.winner!=null,"real result within200calls; no forced winner "+a.id+b.id+str(seed_value))
 check(m.ai_policy.action_limit_reached==0,"no AI passage limit "+a.id+b.id+str(seed_value))
 print("FINISHER MATCH ",a.id,"/",b.id," seed=",seed_value," round=",m.state.round," winner=",m.state.winner," calls=",calls)
 return m
func run() -> void:
 var refs:=definitions()
 var catalog=Model.new().catalog
 for id in ["prod-shield","prod-control","prod-block","prod-convergence"]:
  var copies:=0
  check(catalog.validate(refs[id].cards).ok,"legal defensive reference "+id)
  for card_id in refs[id].cards:
   if catalog.card(card_id).kind=="relic":
    check(catalog.card(card_id).abilities.any(func(a):return a.get("effect")=="modify_attack" and a.get("trigger")=="on_turn_start"),"defensive relic slot supplies actual persistent win plan "+id)
    copies+=1
  check(copies>=2,"redundant finisher availability without over-copy "+id)
 test_decisions()
 var expected={}
 for seed_value in [0,1,2,4]:
  var m=complete(refs["prod-shield"],refs["prod-control"],seed_value)
  if seed_value==2:expected={"state":m.snapshot(),"events":m.events.duplicate(true)}
  complete(refs["prod-control"],refs["prod-shield"],seed_value)
 var replay=complete(refs["prod-shield"],refs["prod-control"],2)
 check(expected.state==replay.snapshot(),"formerly censored case exact final state repeat")
 check(expected.events==replay.events,"formerly censored case exact full event repeat")
 print("PRODUCTION FINISHERS: ",assertions," assertions; ",failures," failures; ",games," actual production matches")
 quit(0 if failures==0 else 1)
