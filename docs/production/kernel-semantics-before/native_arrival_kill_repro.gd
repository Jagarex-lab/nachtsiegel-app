extends SceneTree
const Model=preload("res://scripts/card_system/production_model.gd")
var model
var results: Array=[]
var failures:=0
func _initialize() -> void:call_deferred("run")
func battle(side: String) -> void:
 model=Model.new();assert(model.start_alpha(model.catalog.deck("ninth"),model.catalog.deck("ninth"),59108))
 model.ai_policy=null;model.state.stage="battle";model.state.coin=side;model.state.active=side;model.state.round=11
 model.state.origins={"hero":4,"enemy":4};model.state.origin_used={"hero":true,"enemy":true}
 for s in ["hero","enemy"]:
  var p: Dictionary=model.state[s]
  p.phase="main";p.pendingDraw=0;p.drawDone=true;p.energy=8;p.resonance=2;p.hp=30;p.ward=0;p.block=0
  p.hand=[];p.discard=[];p.deck=["oa-neutral-c01","oa-neutral-c02","oa-neutral-c03"]
  p.lanes=[null,null,null,null,null];p.relic=null;p.relic_used=false
 model.events.clear()
func put(side: String,lane: int,id: String) -> Dictionary:
 var u: Dictionary=model.make_unit(side,model.catalog.card(id),lane)
 u.summoned=false;model.state[side].lanes[lane]=u;return u
func run() -> void:
 for side in ["hero","enemy"]:
  var other: String="enemy" if side=="hero" else "hero"
  for relic in ["of-neutral-093","of-neutral-094","of-neutral-095"]:
   for source in ["oa-neutral-c01","oa-ninth-c01"]:
    for cause in ["native_arrival_strike","native_attack_control"]:
     battle(side);model.state[side].hand=[relic,source]
     assert(model.execute("play",[side,0,2]).ok)
     var victim:=put(other,2,"oa-ninth-c01") # Actual printed HP2, no stat modification.
     var reply: Dictionary
     if cause=="native_arrival_strike":
      reply=model.execute("play",[side,0,2]);assert(reply.ok)
      if side=="hero":reply=model.execute("chooseStrikeTarget",[side,2]);assert(reply.ok)
     else:
      put(side,2,"oa-neutral-c02") # Actual printed attack2.
      reply={"ok":model.attack_phase(side)};assert(reply.ok)
     var applied:=0
     for event in model.effect_runtime.log:
      if event.status=="applied" and event.trigger=="on_kill" and event.context.get("source_card_id")==relic:applied+=1
     var passed: bool=model.state[other].lanes[2]==null and applied==1 and model.state[side].resonance==3 and model.state.error.is_empty()
     if not passed:failures+=1
     results.append({"side":side,"relic":relic,"source":source,"cause":cause,"pass":passed,"kill_watcher_applied":applied,"resonance":model.state[side].resonance,"victim_dead":model.state[other].lanes[2]==null,"victim_uid":victim.uid,"error":model.state.error,"printed_text":model.catalog.card(relic).description})
 var report: Dictionary={"suite":"native_arrival_creature_kill_review","model_sha256":FileAccess.get_sha256("res://scripts/card_system/production_model.gd"),"cases":results.size(),"failures":failures,"results":results,"fixture_limits":"Actual legal Ninth+Neutral identities, public relic/card play and chosen native arrival targets; native attack positive controls. Direct reachable battle setup, no card/stat changes, not full matches."}
 var f:=FileAccess.open("/workspace/tmp/kernel-review/native_arrival_kill_results.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  ",true));f.close()
 print(JSON.stringify({"suite":report.suite,"cases":results.size(),"failures":failures,"model_sha256":report.model_sha256}));quit(1 if failures else 0)
