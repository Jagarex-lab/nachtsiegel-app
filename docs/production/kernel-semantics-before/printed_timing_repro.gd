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
  for id in ["of-houses-077","of-ninth-078","of-morph-089"]:
   var power: String=id.split("-")[1]
   battle(side,power)
   model.state[side].hand=[id,"oa-neutral-c02"] if id=="of-morph-089" else [id]
   if id=="of-ninth-078":model.state[side].energy=5
   var before: Dictionary=model.snapshot()
   var reply: Dictionary=model.execute("play",[side,0,2])
   var p: Dictionary=model.state[side]
   var expected: bool=reply.ok and p.energy==(4 if id=="of-ninth-078" else 6) and p.resonance==(13 if id=="of-houses-077" else 11 if id=="of-morph-089" else 10)
   if id=="of-morph-089":expected=expected and p.hand==["oa-neutral-c02"] and p.discard==[id]
   record("optional_or_ordered_play:"+id,side,expected,{"reply":reply,"hand":p.hand.duplicate(),"discard":p.discard.duplicate(),"energy":p.energy,"resonance":p.resonance,"rejection_atomic":before==model.snapshot(),"printed_text":model.catalog.card(id).description})
   # Positive control gives each current preflight a target before play.
   battle(side,power);model.state[side].hand=[id,"oa-neutral-c02"]
   if id=="of-morph-089":model.state[side].discard=["oa-neutral-c01"]
   reply=model.execute("play",[side,0,2])
   record("same_card_with_preexisting_targets:"+id,side,reply.ok and model.state.error.is_empty(),{"reply":reply,"hand":model.state[side].hand.duplicate(),"resonance":model.state[side].resonance},true)
  for id in ["of-houses-075","of-neutral-076"]:
   for defended in [false,true]:
    battle(side,"houses")
    model.state[side].hand=[id]
    var reply: Dictionary=model.execute("play",[side,0,2]);assert(reply.ok)
    if defended:put(side,2)
    put(other(side),2)
    assert(model.attack_phase(other(side)))
    var p: Dictionary=model.state[side]
    var expected: bool=p.hp==8 and p.resonance==10 and model.armed_impulses(side).size()==1
    if defended:expected=p.hp==(13 if id=="of-houses-075" else 10) and p.resonance==9 and model.armed_impulses(side).is_empty() and (id!="of-neutral-076" or p.block==2)
    record(("actual_creature_damage:" if defended else "hero_only_damage:")+id,side,expected,{"hp":p.hp,"block":p.block,"resonance":p.resonance,"armed":model.armed_impulses(side),"own_creature_present":defended,"printed_text":model.catalog.card(id).description},defended)
  for id in ["of-stillwatch-070","of-stillwatch-093"]:
   for defended in [false,true]:
    battle(side,"stillwatch");model.state[side].hand=[id]
    var reply: Dictionary=model.execute("play",[side,0,2]);assert(reply.ok)
    if defended:put(side,2)
    put(other(side),2)
    assert(model.attack_phase(other(side)))
    var p: Dictionary=model.state[side]
    var expected: bool=p.hp==8 and p.ward==0 and p.block==0 and p.resonance==10 and (id!="of-stillwatch-070" or model.armed_impulses(side).size()==1)
    if defended:expected=p.hp==10 and (p.ward==3 and p.resonance==9 and model.armed_impulses(side).is_empty() if id=="of-stillwatch-070" else p.block==2 and p.resonance==10)
    record(("actual_creature_defense:" if defended else "empty_lane_defense:")+id,side,expected,{"hp":p.hp,"ward":p.ward,"block":p.block,"resonance":p.resonance,"armed":model.armed_impulses(side),"own_creature_present":defended,"printed_text":model.catalog.card(id).description},defended)
 var report: Dictionary={"suite":"isolated_actual_printed_timing_review","model_sha256":FileAccess.get_sha256("res://scripts/card_system/production_model.gd"),"cases":results.size(),"printed_semantics_failures":failures,"positive_control_failures":controls_failed,"results":results,"fixture_limits":"Exact catalog definitions, public play execution and native combat; direct reachable battle arrangement mirrors existing tests. No definition/stat changes, no full match claim."}
 var file:=FileAccess.open("/workspace/tmp/kernel-review/printed_timing_results.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"  ",true));file.close()
 print(JSON.stringify(report))
 quit(1 if failures or controls_failed else 0)
