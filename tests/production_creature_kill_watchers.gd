extends SceneTree
## Real catalog effects at explicit reachable battle boundaries, not full games.
## Two deaths per case verify the relic's once-per-turn limit and native death FIFO.
const Model=preload("res://scripts/card_system/production_model.gd")
var model
var assertions:=0
var failures:=0
var boundaries:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 assertions+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func battle(side: String,power: String,relic_id: String) -> void:
 model=Model.new()
 check(model.start_alpha(model.catalog.deck(power if side=="hero" else "ninth"),model.catalog.deck(power if side=="enemy" else "ninth"),12345),"real legal decks initialize")
 model.ai_policy=null;model.state.stage="battle";model.state.active=side;model.state.round=11
 model.state.origins={"hero":4,"enemy":4};model.state.origin_used={"hero":true,"enemy":true}
 for owner in ["hero","enemy"]:
  var player: Dictionary=model.state[owner]
  player.phase="main";player.pendingDraw=0;player.drawDone=true;player.energy=8;player.resonance=2
  player.pendingTarget=null;player.pendingShift=null;player.lanes=[null,null,null,null,null]
  player.relic=null;player.hp=30;player.ward=0;player.block=0;player.hand=[];player.discard=[]
 model._relic_serial+=1;model.state[side].relic={"id":relic_id,"uid":model._relic_serial}
func put(side: String,lane: int,id: String) -> Dictionary:
 var unit: Dictionary=model.make_unit(side,model.catalog.card(id),lane);unit.summoned=false
 model.state[side].lanes[lane]=unit;return unit
func run() -> void:
 var causes: Array=["native_attack","generic_creature","impulse","native_strike_neutral","native_strike_ninth","native_retaliate_morph","native_retaliate_still","native_pierce_arrival","native_pierce_overflow","opposing_relic_damage"]
 for side in ["hero","enemy"]:
  for relic_id in ["of-neutral-093","of-neutral-094","of-neutral-095"]:
   for cause in causes:
    var power: String="morph" if cause=="native_retaliate_morph" else "stillwatch" if cause in ["impulse","native_retaliate_still"] else "ninth" if cause in ["native_strike_ninth","native_pierce_arrival","native_pierce_overflow","opposing_relic_damage"] else "houses"
    battle(side,power,relic_id);boundaries+=1
    var other: String=model._other(side)
    for lane in [1,3]:
     var victim:=put(other,lane,"oa-ninth-c01") # Actual printed HP2.
     if cause in ["native_retaliate_still","native_pierce_overflow"]:model.hit_unit(victim,1) # Reachable wounded state, unmodified base stats.
     if cause in ["native_attack","generic_creature","native_retaliate_morph","native_retaliate_still","native_pierce_overflow"]:
      var source: String="of-houses-009" if cause=="generic_creature" else "oa-morph-c06" if cause=="native_retaliate_morph" else "oa-stillwatch-c04" if cause=="native_retaliate_still" else "oa-ninth-c02" if cause=="native_pierce_overflow" else "oa-neutral-c02"
      put(side,lane,source)
    if cause in ["native_strike_neutral","native_strike_ninth","native_pierce_arrival","impulse"]:
     var source: String="oa-neutral-c01" if cause=="native_strike_neutral" else "oa-ninth-c01" if cause=="native_strike_ninth" else "oa-ninth-c02" if cause=="native_pierce_arrival" else "of-stillwatch-072"
     for lane in [1,3]:
      model.state[side].hand=[source]
      check(model.execute("play",[side,0,lane]).ok,"real public play for "+cause)
      if cause.begins_with("native_strike") and side=="hero":check(model.execute("chooseStrikeTarget",[side,lane]).ok,"actual native strike target")
    elif cause=="opposing_relic_damage":
     # An opposing relic killing our creature must not notify our kill watcher.
     model._relic_serial+=1;model.state[other].relic={"id":"of-ninth-093","uid":model._relic_serial}
     put(side,2,"oa-ninth-c01");model.state.active=other
     check(model.execute("activateRelic",[other]).ok,"real damaging relic activation")
    else:check(model.attack_phase(other if cause.begins_with("native_retaliate") else side),"actual native combat for "+cause)
    var applied:=0
    for event in model.effect_runtime.log:
     if event.status=="applied" and event.trigger=="on_kill" and event.context.get("source_card_id")==relic_id:applied+=1
    var expected:=0 if cause in ["impulse","native_pierce_arrival","opposing_relic_damage"] else 1
    check(applied==expected,"printed own-creature watcher once: "+side+" "+relic_id+" "+cause)
    check(model.state[side].resonance==2+expected,"resonance exact for "+cause)
    var deaths: int=model.state[other].discard.count("oa-ninth-c01")
    check(deaths==(0 if cause in ["native_pierce_arrival","opposing_relic_damage"] else 2),"native death queue discards each defeated UID once: "+cause)
    check(model._queue.is_empty() and model.effect_runtime._queue.is_empty() and model._pending_arrivals.is_empty() and model._fatal_damage_sources.is_empty(),"all native/generic source queues retire: "+cause)
    check(model.state.error.is_empty(),"kill cause produces no engine error")
 print("PRODUCTION KILL WATCHERS: %d assertions, %d failures; %d explicitly arranged source/side/relic boundaries" % [assertions,failures,boundaries])
 quit(1 if failures else 0)
