extends SceneTree
const Model=preload("res://scripts/card_system/production_model.gd")
var model
var results: Array=[]
var failures:=0
var controls_failed:=0
func _initialize() -> void:call_deferred("run")
func battle(side: String,power: String) -> void:
 model=Model.new()
 assert(model.start_alpha(model.catalog.deck(power),model.catalog.deck(power),59107))
 model.ai_policy=null
 model.state.stage="battle";model.state.coin=side;model.state.active=side;model.state.round=11
 model.state.origins={"hero":4,"enemy":4};model.state.origin_used={"hero":true,"enemy":true}
 for s in ["hero","enemy"]:
  var p: Dictionary=model.state[s]
  p.phase="main";p.pendingDraw=0;p.drawDone=true;p.energy=8;p.hp=10;p.ward=0;p.block=0;p.resonance=10;p.turns=6
  p.hand=[];p.discard=[];p.deck=["oa-neutral-c01","oa-neutral-c02","oa-neutral-c03"]
  p.lanes=[null,null,null,null,null];p.relic=null;p.relic_used=false
 model.events.clear()
func put(side: String,lane: int,id: String="oa-neutral-c02") -> Dictionary:
 var u: Dictionary=model.make_unit(side,model.catalog.card(id),lane)
 u.summoned=false;model.state[side].lanes[lane]=u
 return u
func record(label: String,side: String,passed: bool,observed: Dictionary,control: bool=false) -> void:
 results.append({"case":label,"side":side,"expected_printed_semantics_pass":passed,"positive_control":control,"observed":observed})
 if not passed:
  if control:controls_failed+=1
  else:failures+=1
func other(side: String) -> String:return "enemy" if side=="hero" else "hero"
func run() -> void:
 for side in ["hero","enemy"]:
  for lane in [0,2]:
   for relic in ["of-neutral-093","of-neutral-094","of-neutral-095"]:
    for delayed in [true,false]:
     battle(side,"ninth");model.state[side].resonance=2
     model._relic_serial+=1;model.state[side].relic={"id":relic,"uid":model._relic_serial}
     var victim:=put(other(side),lane,"oa-ninth-c01");victim.summoned=true
     var scheduled: Array=[]
     var source: Dictionary
     if delayed:
      model.state[side].hand=["of-ninth-015"]
      assert(model.execute("play",[side,0,lane]).ok);source=model.state[side].lanes[lane];scheduled=model.state.delayed.duplicate(true)
      assert(model.execute("advanceTurnBoundary",[side]).ok)
      if model.state[other(side)].phase=="draw":assert(model.execute("finishDraw",[other(side)]).ok)
      assert(model.execute("advanceTurnBoundary",[other(side)]).ok)
     else:
      source=put(side,lane,"of-ninth-015");assert(model.attack_phase(side))
     var applied_kill:=0;var applied_damage:=0
     for event in model.effect_runtime.log:
      if event.status=="applied" and event.context.get("source_card_id")==relic and event.trigger=="on_kill":applied_kill+=1
      if event.status=="applied" and event.context.get("source_card_id")=="of-ninth-015" and event.trigger=="on_deal_damage":applied_damage+=1
     var passed: bool=model.state[other(side)].lanes[lane]==null and model.state[side].resonance==4 and applied_kill==1 and applied_damage==1
     record("delayed_creature_damage:"+relic+":"+str(delayed),side,passed,{"resonance":model.state[side].resonance,"kill_applied":applied_kill,"source_damage_applied":applied_damage,"victim_dead":model.state[other(side)].lanes[lane]==null,"source_alive":model.state[side].lanes[lane]!=null and model.state[side].lanes[lane].uid==source.uid,"round":model.state.round,"source_lane":lane,"scheduled":scheduled,"victim_hp":victim.hp,"opponent_hp":model.state[other(side)].hp},not delayed)
 var report: Dictionary={"suite":"delayed_creature_attribution_review","model_sha256":FileAccess.get_sha256("res://scripts/card_system/production_model.gd"),"cases":results.size(),"printed_semantics_failures":failures,"positive_control_failures":controls_failed,"results":results,"fixture_limits":"Real play of actual creature015, then two public advanceTurnBoundary commands (finishDraw when required); actual summoned waiting, actual native HP2 victim. Source persists alive. No card/stat modifications."}
 var f:=FileAccess.open("/workspace/tmp/kernel-review/delayed_creature_results.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  ",true));f.close()
 print(JSON.stringify(report));quit(1 if failures or controls_failed else 0)
