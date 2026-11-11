extends SceneTree
const Model=preload("res://scripts/card_system/production_model.gd")
var results: Array=[]
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var failures:=0
 for side in ["hero","enemy"]:
  var other: String="enemy" if side=="hero" else "hero"
  for relic in ["of-neutral-093","of-neutral-094","of-neutral-095"]:
   for cause in ["native_retaliation","native_attack_control"]:
    var model=Model.new()
    assert(model.start_alpha(model.catalog.deck("morph" if side=="hero" else "ninth"),model.catalog.deck("morph" if side=="enemy" else "ninth"),59109))
    model.ai_policy=null;model.state.stage="battle";model.state.active=side;model.state.round=11
    model.state.origins={"hero":4,"enemy":4};model.state.origin_used={"hero":true,"enemy":true}
    for s in ["hero","enemy"]:
     var p: Dictionary=model.state[s]
     p.phase="main";p.pendingDraw=0;p.drawDone=true;p.energy=8;p.resonance=2;p.hp=30;p.ward=0;p.block=0
     p.hand=[];p.discard=[];p.lanes=[null,null,null,null,null];p.relic=null;p.relic_used=false
    model.events.clear();model.state[side].hand=[relic,"oa-morph-c06"]
    assert(model.execute("play",[side,0,2]).ok)
    if cause=="native_retaliation":assert(model.execute("play",[side,0,2]).ok)
    else:
     var source: Dictionary=model.make_unit(side,model.catalog.card("oa-neutral-c02"),2);source.summoned=false;model.state[side].lanes[2]=source
    var victim: Dictionary=model.make_unit(other,model.catalog.card("oa-ninth-c01"),2);victim.summoned=false;model.state[other].lanes[2]=victim
    assert(model.attack_phase(other if cause=="native_retaliation" else side))
    var applied:=0
    for event in model.effect_runtime.log:
     if event.status=="applied" and event.trigger=="on_kill" and event.context.get("source_card_id")==relic:applied+=1
    var passed: bool=model.state[other].lanes[2]==null and applied==1 and model.state[side].resonance==3 and model.state.error.is_empty()
    if not passed:failures+=1
    results.append({"side":side,"relic":relic,"cause":cause,"pass":passed,"kill_watcher_applied":applied,"resonance":model.state[side].resonance,"victim_dead":model.state[other].lanes[2]==null,"source_hp":model.state[side].lanes[2].hp,"error":model.state.error})
 var report: Dictionary={"suite":"native_retaliation_creature_kill_review","model_sha256":FileAccess.get_sha256("res://scripts/card_system/production_model.gd"),"cases":results.size(),"failures":failures,"results":results,"fixture_limits":"Actual Morph+Neutral versus Ninth, actual public relic/retaliator play. Unmodified printed HP/attack/power. Native attack controls. Reachable battle fixture, not full matches."}
 var f:=FileAccess.open("/workspace/tmp/kernel-review/native_retaliation_kill_results.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  ",true));f.close()
 print(JSON.stringify({"suite":report.suite,"cases":results.size(),"failures":failures,"model_sha256":report.model_sha256}));quit(1 if failures else 0)
