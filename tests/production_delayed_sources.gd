extends SceneTree
## Actual catalog cards at explicit battle/due boundaries; not full matches.
const Model=preload("res://scripts/card_system/production_model.gd")
var model
var assertions:=0
var failures:=0
var boundaries:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 assertions+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func battle(side: String,relic: String="of-neutral-093",power: String="ninth") -> void:
 model=Model.new();assert(model.start_alpha(model.catalog.deck(power),model.catalog.deck(power),67201))
 model.ai_policy=null;model.state.stage="battle";model.state.active=side;model.state.round=11
 model.state.origins={"hero":4,"enemy":4};model.state.origin_used={"hero":true,"enemy":true}
 for owner in ["hero","enemy"]:
  var p: Dictionary=model.state[owner]
  p.phase="main";p.pendingDraw=0;p.drawDone=true;p.energy=8;p.resonance=2;p.hp=20;p.ward=0;p.block=0;p.turns=6
  p.hand=[];p.discard=[];p.deck=["oa-neutral-c01","oa-neutral-c02","oa-neutral-c03"]
  p.lanes=[null,null,null,null,null];p.relic=null;p.relic_used=false
 model._relic_serial+=1;model.state[side].relic={"id":relic,"uid":model._relic_serial};model.events.clear()
func other(side: String) -> String:return "enemy" if side=="hero" else "hero"
func put(side: String,lane: int,id: String) -> Dictionary:
 var u: Dictionary=model.make_unit(side,model.catalog.card(id),lane);u.summoned=false;model.state[side].lanes[lane]=u;return u
func due(side: String) -> void:
 assert(not model.state.delayed.is_empty())
 var latest: int=int(model.state.round)
 for event in model.state.delayed:latest=maxi(latest,int(event.due))
 model.state.round=latest;model.state.active=side
 check(model.begin_turn(side),"real due-boundary resolver")
func applied(id: String,trigger: String) -> int:
 var n:=0
 for row in model.effect_runtime.log:
  if row.status=="applied" and row.trigger==trigger and row.context.get("source_card_id")==id:n+=1
 return n
func run() -> void:
 model=Model.new()
 var delayed_cards: Array=[];var relic_delays:=0
 for card in model.catalog.all_cards():
  for a in card.get("abilities",[]):
   if a.effect=="delay_damage":
    if card.kind=="creature" and not delayed_cards.has(card.id):delayed_cards.append(card.id)
    elif card.kind=="relic":relic_delays+=1
 check(delayed_cards.size()==19 and relic_delays==0,"actual19 delayed creature identities; no printed relic delayed ability")
 # All actual summon/death delayed programs preserve the printed path and owner.
 for side in ["hero","enemy"]:
  for id in delayed_cards:
   for lane in 5:
    battle(side);boundaries+=1;model.state[side].hand=[id]
    check(model.execute("play",[side,0,lane]).ok,"actual delayed creature public play "+id)
    var source: Dictionary=model.state[side].lanes[lane]
    var has_death:=false;var expected:=0
    for a in model.catalog.card(id).abilities:
     if a.effect=="delay_damage" and a.get("trigger") in ["on_summon","on_death"]:
      expected+=1
      if a.trigger=="on_death":has_death=true
    if has_death:model._lane_damage(side,lane,int(source.hp))
    check(model.state.delayed.size()==expected,"all printed delayed abilities scheduled "+id)
    for event in model.state.delayed:
     check(event.lane==lane and event.side==side and event.creature_source.owner==side and event.creature_source.source_card_id==id and event.creature_source.source_uid==source.uid,"exact delayed path/owner/card/UID "+id)
 # Selected public regressions also exercise two complete turn transitions.
 for side in ["hero","enemy"]:
  for relic in ["of-neutral-093","of-neutral-094","of-neutral-095"]:
   for lane in [0,2]:
    battle(side,relic);boundaries+=1
    var victim:=put(other(side),lane,"oa-ninth-c01");victim.summoned=true
    model.state[side].hand=["of-ninth-015"]
    check(model.execute("play",[side,0,lane]).ok,"real015 schedules damage")
    check(model.execute("advanceTurnBoundary",[side]).ok,"first actual turn transition")
    if model.state[other(side)].phase=="draw":check(model.execute("finishDraw",[other(side)]).ok,"required actual draw boundary")
    check(model.execute("advanceTurnBoundary",[other(side)]).ok,"second actual turn transition")
    check(victim.hp<=0 and model.state[other(side)].lanes[lane]==null and model.state[side].resonance==4 and applied(relic,"on_kill")==1 and applied("of-ninth-015","on_deal_damage")==1,"living delayed creator receives own reward and relic receives real kill")
 # Boundary fixtures isolate source/target UID changes and protection.
 for side in ["hero","enemy"]:
  for mode in ["moved_source","removed_source","replaced_source","replaced_target","moved_target","protected","partial_protection","empty_path","death_source","generic_impulse","native_impulse","relic_provenance_guard"]:
   battle(side,"of-neutral-093","stillwatch" if mode=="native_impulse" else "ninth");boundaries+=1
   var victim:=put(other(side),2,"oa-ninth-c01")
   var source: Dictionary={};var source_id: String="of-ninth-020" if mode=="death_source" else "oa-neutral-c02" if mode=="native_impulse" else "of-ninth-015"
   if mode in ["generic_impulse","native_impulse","relic_provenance_guard"]:
    source=put(side,4,source_id)
    if mode=="relic_provenance_guard":
     # ABI provenance guard only: the actual catalog contains no relic delayed
     # program. Use an actual event operation with a real relic context, without
     # claiming it is a printed/legal relic ability or adding a card identity.
     var a: Dictionary=model.catalog.card("of-ninth-065").abilities[0]
     var c: Dictionary={"event_id":"relic-kind-guard","source_card_id":"of-neutral-093","source_relic":true,"source_relic_uid":model.state[side].relic.uid,"target_lane":2,"ability_index":0}
     check(model.effect_runtime.publish("on_play",side,[a],c).ok,"explicit relic-kind provenance primitive")
    else:
     model.state[side].hand=["of-ninth-065" if mode=="generic_impulse" else "oa-stillwatch-e01"]
     check(model.execute("play",[side,0,2]).ok,"actual delayed impulse")
    check(not model.state.delayed[0].has("creature_source"),"noncreature delay has no invented creature ownership")
   else:
    model.state[side].hand=[source_id];check(model.execute("play",[side,0,2]).ok,"actual source play for "+mode);source=model.state[side].lanes[2]
   if mode=="moved_source":
    model.state[side].resonance=6;check(model.execute("tacticalMove",[side,2,3]).ok,"public source movement preserves original UID")
   if mode in ["removed_source","replaced_source","death_source"]:
    model._lane_damage(side,2,int(source.hp))
    if mode=="replaced_source":
     var replacement:=put(side,2,source_id);check(replacement.uid!=source.uid,"replacement owns a new UID")
   if mode=="replaced_target":
    model._lane_damage(other(side),2,int(victim.hp));victim=put(other(side),2,"oa-ninth-c01")
   if mode=="moved_target":model.state[other(side)].lanes[3]=victim;model.state[other(side)].lanes[2]=null
   if mode=="protected":victim["block"]=2;victim.ward=2
   if mode=="partial_protection":victim.ward=1
   if mode=="empty_path":model.state[other(side)].lanes[2]=null
   var before:=int(model.state[side].resonance)
   due(side)
   var noncreature: bool=mode in ["generic_impulse","native_impulse","relic_provenance_guard"]
   var dead_source: bool=mode in ["removed_source","replaced_source","death_source"]
   var kill_expected:=0 if noncreature or mode in ["protected","partial_protection","empty_path","moved_target"] else 1
   var damage_expected:=0 if noncreature or dead_source or mode=="protected" else 1
   check(applied("of-neutral-093","on_kill")==kill_expected and applied(source_id,"on_deal_damage")==damage_expected,"captured ownership/live original UID exact for "+mode)
   check(model.state[side].resonance==before+kill_expected+damage_expected,"exact delayed rewards for "+mode)
   if mode=="protected":check(victim.hp==2 and victim.block==0 and victim.ward==2,"block/shield absorb without false damage/kill")
   elif mode=="partial_protection":check(victim.hp==1 and victim.ward==0,"partial protection produces damage but no defeat")
   elif mode in ["empty_path","moved_target"]:check(model.state[other(side)].hp==18 and victim.hp==2,"scheduled path hits hero and does not follow prior target UID")
   else:check(victim.hp<=0 and model.state[other(side)].lanes[2]==null,"current occupant removed at scheduled path")
   check(model._queue.is_empty() and model.effect_runtime._queue.is_empty() and model._pending_arrivals.is_empty() and model._fatal_damage_sources.is_empty() and model.state.delayed.is_empty() and model.state.error.is_empty(),"delayed/native/FIFO source capabilities retired for "+mode)
 print("PRODUCTION DELAYED SOURCES: %d assertions, %d failures; %d actual card/boundary fixtures" % [assertions,failures,boundaries])
 model=null;quit(1 if failures else 0)
