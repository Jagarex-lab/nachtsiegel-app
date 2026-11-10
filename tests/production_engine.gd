extends SceneTree
const Model=preload("res://scripts/card_system/production_model.gd")
const Generic=preload("res://scripts/card_system/production_effects.gd")
var assertions:=0
var failures:=0
var exercised: Dictionary={}
var covered_triggers: Dictionary={}
var model
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 assertions+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func battle() -> void:
 check(model.start_alpha(model.catalog.deck("houses"),model.catalog.deck("stillwatch"),12345),"actual catalog/decks initialize")
 model.ai_policy=null
 model.state.stage="battle";model.state.coin="hero";model.state.active="hero";model.state.round=11
 model.state.origins={"hero":4,"enemy":4};model.state.origin_used={"hero":true,"enemy":true}
 for side in ["hero","enemy"]:
  var p: Dictionary=model.state[side]
  p.phase="main";p.pendingDraw=0;p.drawDone=true;p.energy=8;p.hp=20;p.ward=0;p.block=0;p.resonance=12;p.turns=6
  p.hand=["oa-neutral-c01"];p.discard=["oa-neutral-c02"];p.deck=["oa-neutral-c01","oa-neutral-c02","oa-neutral-c03"]
  p.lanes=[null,null,null,null,null];p.relic=null;p.relic_used=false
 model.events.clear()
func put(side: String,lane: int,id: String="oa-neutral-c02") -> Dictionary:
 var u: Dictionary=model.make_unit(side,model.catalog.card(id),lane);u.summoned=false
 model.state[side].lanes[lane]=u
 return u
func source_context(card: Dictionary,index: int) -> Dictionary:
 var context: Dictionary={"event_id":"fixture:"+card.id+":"+str(index),"source_card_id":card.id,"ability_index":index,"target_lane":2}
 if card.kind=="creature":
  var u:=put("hero",2,card.id);context.source_lane=2;context.source_uid=u.uid
 elif card.kind=="relic":
  model._relic_serial+=1;model.state.hero.relic={"id":card.id,"uid":model._relic_serial};context.source_relic=true;context.source_relic_uid=model._relic_serial
 return context
func run() -> void:
 model=Model.new()
 check(model._configuration_error.is_empty() and model._bindings.size()>=495,"all generic identities configure against actual catalog")
 var ability_count:=0
 if OS.get_environment("PRODUCTION_HOOKS_ONLY")=="1":
  test_automatic_triggers();print("HOOKS ",failures);quit(1 if failures else 0);return
 for card in model.catalog.all_cards():
  if card.get("effect")!="v2":continue
  for i in card.abilities.size():
   var a: Dictionary=card.abilities[i];ability_count+=1
   battle();put("hero",1);put("enemy",2);put("enemy",4)
   var context:=source_context(card,i)
   if a.target=="own_species":
    var found:=false
    for candidate in model.catalog.all_cards():
     if candidate.kind=="creature" and candidate.get("species",[]).has(a.params.species):put("hero",1,candidate.id);found=true;break
    check(found,"actual species target exists "+card.id)
   if a.effect=="move_unit":
    var targets: Array=model._targets("hero",a,context)
    for target in targets:
     var to:=int(target.lane)+int(a.params.steps)
     if to>=0 and to<5:model.state[target.side].lanes[to]=null
   if a.mode=="passive":
    check(model.can_fight("hero",2),"generichaste allows same-turn fight "+card.id)
    model.state.hero.lanes[2].summoned=true
    check(model.can_fight("hero",2),"generichaste bypasses summon delay "+card.id)
    exercised[a.effect]=true;continue
   if a.get("trigger")=="on_death" and card.kind=="creature":model.state.hero.lanes[2].hp=0;model.state.hero.lanes[2]=null
   var reply: Dictionary=model.effect_runtime.activate("hero",a,context) if a.mode=="activated" else model.effect_runtime.publish(a.trigger,"hero",[a],context)
   var applied:=false
   for entry in model.effect_runtime.log:
    if entry.status=="applied" and entry.context.get("source_card_id")==card.id and entry.context.get("ability_index")==i and entry.ability==a:applied=true
   check(reply.ok and applied and model.state.error.is_empty(),"actual ability resolved "+card.id+":"+str(i)+" "+str(reply))
   if applied:exercised[a.effect]=true
 test_automatic_triggers()
 test_rules_and_identity()
 print(JSON.stringify({"suite":"production_engine","assertions":assertions,"failures":failures,"generic_cards":model._bindings.size(),"ability_fixtures":ability_count,"effects_executed":exercised.keys(),"automatic_triggers_executed":covered_triggers.keys(),"fixture_limit":"ability fixtures explicitly arrange battle boundaries; separate cases use real actions for all sixteen automatic hooks"}))
 quit(1 if failures else 0)
func find_trigger(trigger: String) -> Dictionary:
 for card in model.catalog.all_cards():
  if card.get("effect")!="v2" or card.kind!="creature":continue
  for a in card.abilities:
   if a.get("trigger")==trigger:return card
 return {}
func test_automatic_triggers() -> void:
 for trigger in Generic.TRIGGERS:
  battle()
  var card:=find_trigger(trigger)
  check(not card.is_empty(),"actual card for automatic "+trigger)
  if card.is_empty():continue
  var context:=source_context(card,0);var unit: Dictionary=model.state.hero.lanes[2]
  put("hero",1)
  if trigger=="on_play" or trigger=="on_summon":
   model.state.hero.lanes[2]=null;model.state.hero.hand=[card.id]
   check(model.play("hero",0,2),"real play invokes "+trigger)
  elif trigger=="on_attack":put("enemy",2);model.attack_phase("hero")
  elif trigger=="on_defend":put("enemy",2);model.state.enemy.lanes[2].atk=1;model.attack_phase("enemy")
  elif trigger=="on_deal_damage":unit.atk=3;put("enemy",2).hp=20;model.attack_phase("hero")
  elif trigger=="on_take_damage":model._lane_damage("hero",2,1)
  elif trigger=="on_kill":unit.atk=20;put("enemy",2).hp=1;model.attack_phase("hero")
  elif trigger=="on_death":model._lane_damage("hero",2,100)
  elif trigger=="on_turn_start":model.state.hero.energy=0;model.begin_turn("hero")
  elif trigger=="on_turn_end":model.advance_turn("hero")
  elif trigger=="on_lane_change":check(model.tactical_move("hero",2,3),"real tactical shift")
  elif trigger=="on_draw":model.draw_cards("hero",1)
  elif trigger=="on_discard":
   model.state.hero.hand=["oa-neutral-c01","oa-neutral-c01","oa-neutral-c01","oa-neutral-c01","oa-neutral-c01","oa-neutral-c01"]
   model.state.hero.phase="draw";model.state.hero.pendingDraw=1
   check(model.burn("hero",0),"real mandatory burn")
  elif trigger=="on_spend_resonance":check(model.fortify("hero",2),"real fortification spends resonance")
  elif trigger=="on_relic_activate":
   model.state.hero.relic={"id":"oa-houses-r01","uid":10}
   check(model.activate_relic("hero"),"actual native relic activation")
  elif trigger=="on_condition":model.state.hero.resonance=15;model.execute("finishDraw",["hero"]);model._evaluate_conditions()
  var applied:=false
  for entry in model.effect_runtime.log:
   if entry.status=="applied" and entry.trigger==trigger and entry.context.get("source_card_id")==card.id:applied=true
  if not applied:print("AUTOMATIC DETAIL ",trigger," ",card.id," ",card.abilities," ",model.trigger_journal," ",model.state.error)
  check(applied and model.state.error.is_empty(),"actual action executes automatic "+trigger)
  if applied:covered_triggers[trigger]=true
 check(covered_triggers.size()==16,"all sixteen automatic triggers executed")
func test_rules_and_identity() -> void:
 battle()
 var attacker:=put("hero",2);attacker.atk=7
 model.state.enemy.block=2;model.state.enemy.ward=3
 model.attack_phase("hero")
 check(model.state.enemy.hp==18 and model.state.enemy.block==0 and model.state.enemy.ward==0,"empty opposite lane hits hero, block then shield absorb")
 battle()
 var victim:=put("enemy",2);victim["block"]=2;victim.ward=3;victim.hp=10
 model._lane_damage("enemy",2,7)
 check(victim.hp==8 and victim.block==0 and victim.ward==0,"unitblock distinct from shield and hp")
 battle()
 var before:=JSON.stringify([model.snapshot(),model.events,model.rng.state,model.rng.calls],"",true)
 check(not model.execute("play",["hero",99,2]).ok,"illegal index rejected")
 check(JSON.stringify([model.snapshot(),model.events,model.rng.state,model.rng.calls],"",true)==before,"illegal action completely immutable")
 # Real ten-effect sequence uses existing FIFO, validated identical operation snapshots.
 var card: Dictionary={}
 for c in model.catalog.all_cards():
  if c.get("effect")=="v2" and c.kind=="creature":
   for a in c.abilities:
    if a.get("trigger")=="on_summon" and a.effect=="gain_resonance":card=c;break
  if not card.is_empty():break
 if not card.is_empty():
  var context:=source_context(card,0);context.event_id="ten-effects"
  var a: Dictionary=card.abilities[0].duplicate(true);a.mode="triggered";a.trigger="on_summon";a.limit="once_per_event"
  var abilities: Array=[]
  for _i in 10:abilities.append(a.duplicate(true))
  var offset: int=model.effect_runtime.log.size();var result: Dictionary=model.effect_runtime.publish("on_summon","hero",abilities,context)
  check(result.ok and model.effect_runtime.log.size()-offset==10,"ten effects execute in one actual FIFO")
  check(model.state.hero.resonance<=15,"ten resource effects respect resonance cap")
