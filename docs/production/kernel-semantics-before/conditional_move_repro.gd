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
  for id in ["of-ninth-072","of-neutral-069"]:
   for blocked in [true,false]:
    battle(side,"ninth");model.state[side].hand=[id]
    var unit:=put(side,0)
    if blocked:put(side,1)
    var reply: Dictionary=model.execute("play",[side,0,2])
    var passed: bool=reply.ok and (model.state[side].resonance==11 if id=="of-ninth-072" else model.state[side].block==1)
    if not blocked:passed=passed and model.state[side].lanes[1]!=null and model.state[side].lanes[1].uid==unit.uid
    record("conditional_move:"+id+":"+str(blocked),side,passed,{"reply":reply,"resonance":model.state[side].resonance,"block":model.state[side].block,"blocked":blocked,"printed_text":model.catalog.card(id).description},not blocked)
 var report: Dictionary={"suite":"optional_movement_review","model_sha256":FileAccess.get_sha256("res://scripts/card_system/production_model.gd"),"cases":results.size(),"printed_semantics_failures":failures,"positive_control_failures":controls_failed,"results":results}
 var f:=FileAccess.open("/workspace/tmp/kernel-review/conditional_move_results.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  ",true));f.close()
 print(JSON.stringify(report));quit(1 if failures or controls_failed else 0)
