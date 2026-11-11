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
func source_context(card: Dictionary,index: int,side: String="hero") -> Dictionary:
 var context: Dictionary={"event_id":"fixture:"+card.id+":"+str(index),"source_card_id":card.id,"ability_index":index,"target_lane":2}
 if card.kind=="creature":
  var u:=put(side,2,card.id);context.source_lane=2;context.source_uid=u.uid
 elif card.kind=="relic":
  model._relic_serial+=1;model.state[side].relic={"id":card.id,"uid":model._relic_serial};context.source_relic=true;context.source_relic_uid=model._relic_serial
 return context
func run() -> void:
 model=Model.new()
 check(model._configuration_error.is_empty() and model._bindings.size()>=495,"all generic identities configure against actual catalog")
 if OS.get_environment("PRODUCTION_LETHAL_ONLY")=="1":
  test_lethal_damage_order();print("LETHAL ORDER: ",assertions," assertions, ",failures," failures");quit(1 if failures else 0);return
 if OS.get_environment("PRODUCTION_CHOICES_ONLY")=="1":
  test_pending_arrival_choices();print("PENDING ARRIVALS: ",assertions," assertions, ",failures," failures");quit(1 if failures else 0);return
 if OS.get_environment("PRODUCTION_PERF_ONLY")=="1":
  test_performance_bookkeeping();print("PERF BOOKKEEPING: ",assertions," assertions, ",failures," failures");quit(1 if failures else 0);return
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
 test_automatic_triggers("hero")
 test_automatic_triggers("enemy")
 test_rules_and_identity()
 test_reactions_and_boundaries()
 test_all_cards_play()
 test_queue_target_identity()
 test_performance_bookkeeping()
 test_pending_arrival_choices()
 test_lethal_damage_order()
 test_weaken_convergence_control()
 var categories: Dictionary={}
 for id in exercised:categories[Generic.OPS[id].category]=true
 check(categories.size()==12,"all twelve executable effect categories covered")
 print(JSON.stringify({"suite":"production_engine","assertions":assertions,"failures":failures,"generic_cards":model._bindings.size(),"ability_fixtures":ability_count,"effects_executed":exercised.keys(),"automatic_triggers_executed":covered_triggers.keys(),"fixture_limit":"ability fixtures explicitly arrange battle boundaries; separate cases use real actions for all sixteen automatic hooks"}))
 quit(1 if failures else 0)
func find_trigger(trigger: String) -> Dictionary:
 for card in model.catalog.all_cards():
  if card.get("effect")!="v2" or card.kind!="creature":continue
  for a in card.abilities:
   if a.get("trigger")==trigger:return card
 return {}
func test_automatic_triggers(side: String="hero") -> void:
 var other: String=model._other(side)
 for trigger in Generic.TRIGGERS:
  battle()
  var card:=find_trigger(trigger)
  check(not card.is_empty(),"actual card for automatic "+trigger)
  if card.is_empty():continue
  model.state.active=side
  var context:=source_context(card,0,side);var unit: Dictionary=model.state[side].lanes[2]
  put(side,1)
  for ability in card.abilities:
   if ability.target=="own_species":
    for candidate in model.catalog.all_cards():
     if candidate.kind=="creature" and candidate.get("species",[]).has(ability.params.species):put(side,4,candidate.id);break
  if trigger=="on_play" or trigger=="on_summon":
   model.state[side].lanes[2]=null;model.state[side].hand=[card.id]
   check(model.play(side,0,2),"real play invokes "+trigger)
  elif trigger=="on_attack":put(other,2);model.attack_phase(side)
  elif trigger=="on_defend":put(other,2);model.state[other].lanes[2].atk=1;model.attack_phase(other)
  elif trigger=="on_deal_damage":unit.atk=3;put(other,2).hp=20;model.attack_phase(side)
  elif trigger=="on_take_damage":model._lane_damage(side,2,1)
  elif trigger=="on_kill":unit.atk=20;put(other,2).hp=1;model.attack_phase(side)
  elif trigger=="on_death":model._lane_damage(side,2,100)
  elif trigger=="on_turn_start":model.state[side].energy=0;model.begin_turn(side)
  elif trigger=="on_turn_end":model.advance_turn(side)
  elif trigger=="on_lane_change":check(model.tactical_move(side,2,3),"real tactical shift")
  elif trigger=="on_draw":model.draw_cards(side,1)
  elif trigger=="on_discard":
   model.state[side].hand=["oa-neutral-c01","oa-neutral-c01","oa-neutral-c01","oa-neutral-c01","oa-neutral-c01","oa-neutral-c01"]
   model.state[side].phase="draw";model.state[side].pendingDraw=1
   check(model.burn(side,0),"real mandatory burn")
  elif trigger=="on_spend_resonance":check(model.fortify(side,2),"real fortification spends resonance")
  elif trigger=="on_relic_activate":
   model.state[side].relic={"id":"oa-houses-r01","uid":10}
   check(model.activate_relic(side),"actual native relic activation")
  elif trigger=="on_condition":model.state[side].resonance=15;model.execute("finishDraw",[side]);model._evaluate_conditions()
  var applied:=false
  for entry in model.effect_runtime.log:
   if entry.status=="applied" and entry.trigger==trigger and entry.context.get("source_card_id")==card.id:applied=true
  if not applied:print("AUTOMATIC DETAIL ",trigger," ",card.id," ",card.abilities," ",model.trigger_journal," ",model.state.error)
  check(applied and model.state.error.is_empty(),"actual action executes automatic "+trigger)
  if applied:covered_triggers[side+":"+trigger]=true
 check(covered_triggers.keys().filter(func(key):return str(key).begins_with(side+":")).size()==16,"all sixteen automatic triggers executed for "+side)
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

func test_reactions_and_boundaries() -> void:
 battle()
 model.state.hero.hand=["oa-morph-c07"]
 check(model.play("hero",0,2),"actual haste creature moves during its on_play")
 var arrived: Variant=model.state.hero.lanes[3]
 check(arrived!=null and arrived.id=="oa-morph-c07" and model._summoned_uids.has(int(arrived.uid)),"arrival queue follows played instance after on_play movement")
 battle()
 var attacker:=put("hero",2);attacker.hp=1;attacker.atk=9
 var defender:=put("enemy",2,"of-ninth-009");var hp_before:=int(defender.hp)
 var discard_before: int=model.state.hero.discard.size()
 model.attack_phase("hero")
 check(model.state.hero.lanes[2]==null and defender.hp==hp_before,"defender damage trigger kills attacker before any attack damage")
 check(model.state.hero.discard.size()==discard_before+1,"defeated attacking instance discarded once")
 battle()
 attacker=put("hero",2);attacker.atk=20
 defender=put("enemy",2,"oa-stillwatch-c07");hp_before=int(defender.hp)
 model.attack_phase("hero")
 check(defender.hp==hp_before and attacker.stun==0,"on_defend stasis cancels current attack and consumes one skip")
 # The second battle phase must not inherit another unintended skipped turn.
 var attacker_hp:=int(attacker.hp)
 model.state.round+=2;model.attack_phase("hero")
 check(int(attacker.hp)==attacker_hp,"same rule has no free defender counterattack")
 battle()
 var reactive: Dictionary=model.catalog.card("of-stillwatch-070")
 model.state.hero.hand=[reactive.id]
 var res_before:=int(model.state.hero.resonance)
 check(model.play("hero",0,2),"real reactive impulse play arms it")
 check(model.armed_impulses("hero").size()==1 and not model.state.hero.discard.has(reactive.id),"armed impulse is a separate pending zone")
 put("hero",2)
 var enemy_attacker:=put("enemy",2);enemy_attacker.atk=5
 model.attack_phase("enemy")
 check(model.state.hero.hp==20 and model.state.hero.ward==3 and model.state.hero.lanes[2]==null,"creature defense arms hero shield before the defender takes combat damage")
 check(model.armed_impulses("hero").is_empty() and model.state.hero.discard.has(reactive.id),"reactive impulse consumed exactly once")
 check(model.state.hero.resonance==res_before-1,"reactive printed resonance cost paid once")
 battle();model.state.hero.hand=[reactive.id];check(model.play("hero",0,2),"arm expiry case")
 model.begin_turn("hero")
 check(model.armed_impulses("hero").is_empty() and model.state.hero.discard.has(reactive.id),"untriggered impulse expires at next own turn")
 # A full hand can legally play a draw impulse because payment removes that card first.
 battle()
 var draw_impulse: Dictionary={}
 for c in model.catalog.all_cards():
  if c.get("effect")=="v2" and c.kind=="event" and c.abilities.size()==1 and c.abilities[0].effect=="draw_cards":draw_impulse=c;break
 check(not draw_impulse.is_empty(),"actual draw impulse exists")
 if not draw_impulse.is_empty():
  model.state.hero.hand=[draw_impulse.id,"oa-neutral-c01","oa-neutral-c01","oa-neutral-c01","oa-neutral-c01","oa-neutral-c01"]
  check(model.play("hero",0,0) and model.state.hero.hand.size()==6,"draw impulse playable from six-card hand")
 # Replacing an active relic does not refresh the slot's once-per-turn activation.
 battle()
 var relic: Dictionary={}
 for c in model.catalog.all_cards():
  if c.get("effect")=="v2" and c.kind=="relic":
   for a in c.abilities:
    if a.mode=="activated" and a.effect=="grant_shield":relic=c;break
  if not relic.is_empty():break
 if not relic.is_empty():
  model.state.hero.hand=[relic.id];check(model.play("hero",0,0),"install generic relic")
  check(model.can_activate_relic("hero") and model.activate_relic("hero"),"generic relic uses actual activation API")
  model.state.hero.energy=8;model.state.hero.hand=[relic.id]
  check(model.play("hero",0,0) and not model.can_activate_relic("hero"),"replacement preserves spent slot activation")
func test_all_cards_play() -> void:
 var plays:=0
 for side in ["hero","enemy"]:
  for card in model.catalog.all_cards():
   battle();model.state.active=side
   model.state[side].hand=[card.id,"oa-neutral-c01"]
   # Explicit legal-target fixtures: existing paths/hand/discard/delay prerequisites.
   put(side,1);put(model._other(side),2)
   model.state[side].lanes[1].hp=1
   var species_slot:=1
   for a in card.get("abilities",[]):
    if a.target=="own_species":
     for candidate in model.catalog.all_cards():
      if candidate.kind=="creature" and candidate.get("species",[]).has(a.params.species):
       put(side,species_slot,candidate.id);model.state[side].lanes[species_slot].hp=1;species_slot=3;break
   model.state[side].relic=null
   model.state.delayed=[{"side":side,"lane":0,"due":14,"power":2}]
   # Creature plays need an empty destination. Impulses can require a free movement neighbor.
   var targets: Array=model.legal_targets(side,0)
   var reply: Dictionary={"ok":false,"reason":"no_target"}
   if not targets.is_empty():reply=model.execute("play",[side,0,targets[0]])
   check(reply.ok and model.state.error.is_empty(),"actual card play "+side+":"+card.id+" "+str(reply))
   if reply.ok:plays+=1
   if model.state[side].pendingTarget!=null:
    var chosen: int=-1
    for lane in 5:
     if model.state[model._other(side)].lanes[lane]!=null:chosen=lane;break
    if chosen>=0:check(model.choose_strike_target(side,chosen),"resolve native chosen target "+card.id)
   if model.state[side].pendingShift!=null:check(model.skip_shift(side),"resolve optional native shift "+card.id)
 check(plays==1100,"all550actualcards legally played for both sides")
 print("PRODUCTION CARD COMMAND MATRIX: ",plays," accepted plays; explicitly arranged prerequisites, not1100completegames")

func test_queue_target_identity() -> void:
 for target_rule in ["enemy_lane","opposite_enemy_unit"]:
  for initially_empty in [false,true]:
   if initially_empty and target_rule=="opposite_enemy_unit":continue
   battle()
   var source: Dictionary={};var ability: Dictionary={}
   for card in model.catalog.all_cards():
    if card.get("effect")!="v2":continue
    for a in card.abilities:
     if a.effect=="deal_damage" and a.target==target_rule and a.mode=="triggered":source=card;ability=a;break
    if not source.is_empty():break
   check(not source.is_empty(),"real damage card for queued target binding "+target_rule)
   if source.is_empty():continue
   var context:=source_context(source,0);context.event_id="binding-test";context.target_lane=2
   if not initially_empty:put("enemy",2).hp=20
   var flag: Dictionary={"done":false,"replacement":null}
   var callback:=func(entry: Dictionary):
    if entry.event_id=="binding-test" and entry.status=="applied" and not flag.done:
     flag.done=true;flag.replacement=put("enemy",2)
   model.effect_runtime.effect_processed.connect(callback)
   var offset: int=model.effect_runtime.log.size()
   var reply: Dictionary=model.effect_runtime.publish(ability.trigger,"hero",[ability.duplicate(true),ability.duplicate(true)],context)
   model.effect_runtime.effect_processed.disconnect(callback)
   check(reply.ok and flag.done,"queued replacement fixture processed first effect")
   var rows: Array=model.effect_runtime.log.slice(offset)
   check(rows.size()==2 and rows[0].status=="applied" and rows[1].status=="fizzled" and rows[1].actual.reason=="stale_target","replacement or newly appeared defender does not inherit queued chosen target")
   check(flag.replacement.hp==model.catalog.card(flag.replacement.id).hp,"replacement takes no inherited damage")
 # A source-bound queued relic effect cannot move to a fresh copy of the same identity.
 battle()
 var relic: Dictionary={};var a: Dictionary={}
 for c in model.catalog.all_cards():
  if c.kind!="relic" or c.get("effect")!="v2":continue
  for candidate in c.abilities:
   if candidate.mode=="triggered" and candidate.effect in ["gain_resonance","gain_energy","draw_cards"]:relic=c;a=candidate;break
  if not relic.is_empty():break
 if not relic.is_empty():
  var context:=source_context(relic,0);context.event_id="relic-replacement"
  var flag: Dictionary={"done":false}
  var callback:=func(entry: Dictionary):
   if entry.event_id=="relic-replacement" and entry.status=="applied" and not flag.done:
    flag.done=true;model._relic_serial+=1;model.state.hero.relic={"id":relic.id,"uid":model._relic_serial}
  model.effect_runtime.effect_processed.connect(callback)
  var offset: int=model.effect_runtime.log.size()
  var reply: Dictionary=model.effect_runtime.publish(a.trigger,"hero",[a.duplicate(true),a.duplicate(true)],context)
  model.effect_runtime.effect_processed.disconnect(callback)
  var rows: Array=model.effect_runtime.log.slice(offset)
  check(reply.ok and rows.size()==2 and rows[0].status=="applied" and rows[1].status=="fizzled" and rows[1].actual.reason=="stale_source","same-ID relic replacement cannot inherit queued source ability")

func test_performance_bookkeeping() -> void:
 battle()
 var card: Dictionary={};var a: Dictionary={}
 for c in model.catalog.all_cards():
  if c.get("effect")!="v2" or c.kind!="creature":continue
  for candidate in c.abilities:
   if candidate.mode=="triggered" and candidate.limit=="once_per_event" and candidate.effect=="gain_resonance":card=c;a=candidate;break
  if not card.is_empty():break
 check(not card.is_empty(),"real resource card for publication hash proof")
 if card.is_empty():return
 var context:=source_context(card,0);context.event_id="perf-publication"
 var initial: String=model.snapshot().v2_bridge.runtime_history_sha256
 var rejected: Dictionary=model.effect_runtime.publish("not_a_trigger","hero",[a],context)
 check(not rejected.ok and model.snapshot().v2_bridge.runtime_history_sha256==initial,"illegal publication does not advance rolling hash")
 var reply: Dictionary=model.effect_runtime.publish(a.trigger,"hero",[a],context)
 var accepted: String=model.snapshot().v2_bridge.runtime_history_sha256
 check(reply.ok and accepted!=initial,"accepted publication advances rolling hash")
 var duplicate: Dictionary=model.effect_runtime.publish(a.trigger,"hero",[a],context)
 check(not duplicate.ok and model.snapshot().v2_bridge.runtime_history_sha256==accepted,"duplicate publication does not advance rolling hash")
 check(model.snapshot().v2_bridge.version==2 and model.snapshot().v2_bridge.history_algorithm=="sha256-event-chain-v1","production-only digest format explicitly versioned")
 var probe=model._validation_probe()
 check(probe.snapshot()==model.snapshot(),"compact validation probe begins with full identical state and digest")
 var stamp:=JSON.stringify([model.snapshot(),model.events,model.trigger_journal],"",true)
 context.event_id="probe-only-publication"
 check(probe.effect_runtime.publish(a.trigger,"hero",[a],context).ok,"probe can resolve a new actual ability")
 check(JSON.stringify([model.snapshot(),model.events,model.trigger_journal],"",true)==stamp,"shallow closed histories remain immutable while probe appends its own outcomes")
 model._ability_uses={"hero:old:0:10":true,"enemy:current:0:11":true}
 model._condition_latches={"hero:departed:0":true}
 model._prune_rule_caches()
 check(model._ability_uses=={"enemy:current:0:11":true},"only unreachable past-round cooldowns are pruned")
 check(model._condition_latches.is_empty(),"departed condition sources cannot retain latches")
 model._trace("perf_before","hero")
 var before_state: Dictionary=model.events[-1].state
 var before_json:=JSON.stringify(before_state,"",true)
 model.state.hero.energy=maxi(0,int(model.state.hero.energy)-1)
 model._trace("perf_after","hero")
 check(JSON.stringify(before_state,"",true)==before_json,"published historical snapshot is not mutated by later real state changes")
 check(is_same(before_state.enemy,model.events[-1].state.enemy),"unchanged immutable history branch is shared, not copied repeatedly")

func test_pending_arrival_choices() -> void:
 battle()
 put("hero",0,"oa-ninth-c01");put("hero",1,"oa-ninth-c01")
 var target:=put("enemy",0);target.hp=4
 check(model.enqueue_many([{"type":"summon","side":"hero","lane":0,"card_id":"oa-ninth-c01"},{"type":"summon","side":"hero","lane":1,"card_id":"oa-ninth-c01"}]),"two actual native arrival effects enter existing FIFO")
 check(model.state.hero.pendingTarget!=null and model.state.hero.pendingTarget.sourceLane==0 and model._pending_arrivals.size()==1,"second native target choice does not overwrite the first")
 var probe=model._validation_probe()
 check(probe.snapshot()==model.snapshot() and not is_same(probe._pending_arrivals,model._pending_arrivals),"pending arrival and choice source identity are cloned for validation/replay")
 check(model.choose_strike_target("hero",0) and target.hp==2 and model.state.hero.pendingTarget!=null and model.state.hero.pendingTarget.sourceLane==1,"first choice resolves once and exposes second arrival choice")
 check(model.choose_strike_target("hero",0) and model.state.enemy.lanes[0]==null and model.state.hero.pendingTarget==null and model._pending_arrivals.is_empty(),"both original arrival strikes resolve with no lost effect")
 battle()
 var arrivals: Array=[]
 for lane in [0,1,2]:put("hero",lane,"oa-ninth-c01");arrivals.append({"type":"summon","side":"hero","lane":lane,"card_id":"oa-ninth-c01"})
 target=put("enemy",0);target.hp=1
 check(model.enqueue_many(arrivals),"three native target arrivals enqueue")
 check(model.choose_strike_target("hero",0) and model.state.enemy.hp==16 and model.state.hero.pendingTarget==null and model._pending_arrivals.is_empty(),"after last defender dies later arrivals hit hero under existing empty-board rule")
 battle()
 put("hero",0,"oa-ninth-c01");put("hero",1,"oa-ninth-c01");target=put("enemy",0);target.hp=4
 check(model.enqueue_many([{"type":"summon","side":"hero","lane":0,"card_id":"oa-ninth-c01"},{"type":"summon","side":"hero","lane":1,"card_id":"oa-ninth-c01"}]),"stale arrival setup")
 var old_uid: int=model.state.hero.lanes[1].uid
 model._lane_damage("hero",1,99)
 var replacement:=put("hero",1,"oa-ninth-c01")
 check(int(replacement.uid)!=old_uid and model.choose_strike_target("hero",0),"actual native choice can complete after deferred source replacement")
 check(target.hp==2 and model.state.hero.pendingTarget==null and model._pending_arrivals.is_empty() and not model._summoned_uids.has(int(replacement.uid)),"same-ID replacement does not inherit removed source's deferred arrival")
 battle()
 put("hero",0);put("hero",1,"oa-morph-c03");put("hero",2);put("hero",3,"oa-morph-c03")
 check(model.enqueue_many([{"type":"summon","side":"hero","lane":1,"card_id":"oa-morph-c03"},{"type":"summon","side":"hero","lane":3,"card_id":"oa-morph-c03"}]),"two real native shift arrivals enqueue")
 check(model.state.hero.pendingShift!=null and model.state.hero.pendingShift.origin==1,"first shift choice remains visible")
 check(model.skip_shift("hero") and model.state.hero.pendingShift!=null and model.state.hero.pendingShift.origin==3,"skipping first shift exposes second distinct shift")
 check(model.skip_shift("hero") and model.state.hero.pendingShift==null and model._pending_arrivals.is_empty(),"second optional choice closes cleanly")
 battle()
 var summoner: Dictionary={};var summon_a: Dictionary={}
 for card in model.catalog.all_cards():
  if card.get("effect")!="v2":continue
  for a in card.abilities:
   if a.effect=="summon_card":summoner=card;summon_a=a;break
  if not summoner.is_empty():break
 var context:=source_context(summoner,0);context.event_id="first-free-spawn";context.target_lane=4
 var reply: Dictionary=model.effect_runtime.publish(summon_a.trigger,"hero",[summon_a],context)
 check(reply.ok and model.state.hero.lanes[0]!=null and model.state.hero.lanes[0].id==summon_a.params.card_id,"generic summon follows printed first-free lane even when source/selected lane is4")
 battle()
 var moving:=put("hero",0,"oa-morph-c07");put("hero",2)
 context={"source_uid":moving.uid,"source_lane":0,"target_lane":0}
 model.state.hero.lanes[1]=moving;model.state.hero.lanes[0]=null
 var neighbors: Array=model._targets("hero",{"target":"own_neighbors","params":{}},context)
 check(neighbors.size()==1 and neighbors[0].lane==2,"own-neighbor selector follows live source UID after movement")
 model.state.hero.lanes[2].hp=0
 check(model._targets("hero",{"target":"own_neighbors","params":{}},context).is_empty(),"neighbor selectors exclude defeated units")
 var bound: Dictionary=model.production_bind_context("hero",{},context)
 check(bound.source_lane==1 and bound.opposite_enemy_lane==1,"later printed ability captures current source lane after prior movement")

func test_lethal_damage_order() -> void:
 for cause in ["attack","generic"]:
  for initial_hp in [1,4]:
   battle();model.state.hero.hp=initial_hp;model.state.hero.hand=["of-houses-075"]
   check(model.play("hero",0,2),"arm real postdamage healing before "+cause)
   model.state.active="enemy"
   if cause=="attack":
    var attacker:=put("enemy",2);attacker.atk=2
    check(model.attack_phase("enemy"),"real native hero attack")
   else:
    model.state.enemy.hand=["of-stillwatch-072"]
    check(model.play("enemy",0,2),"real generic two-damage impulse")
   if initial_hp==1:check(model.state.hero.hp==0 and model.state.winner=="enemy" and model.armed_impulses("hero").size()==1,"hero HP0 is terminal before postdamage healing for "+cause)
   else:check(model.state.hero.hp==2 and model.state.winner==null and model.armed_impulses("hero").size()==1,"hero-only damage does not satisfy own-creature healing condition for "+cause)
  battle();var dying:=put("hero",2,"of-houses-007");dying.hp=1;model.state.active="enemy"
  if cause=="attack":
   var attacker:=put("enemy",2);attacker.atk=2;model.attack_phase("enemy")
  else:model.state.enemy.hand=["of-stillwatch-072"];model.play("enemy",0,2)
  check(model.state.hero.lanes[2]==null and model.state.hero.block==2,"fatal creature damage still resolves its captured hero-block trigger for "+cause)
  check(model._fatal_damage_sources.is_empty(),"completed fatal-source capability is retired for "+cause)
  battle();dying=put("hero",2,"of-morph-013");dying.hp=1;var before_atk:=int(dying.atk);model.state.active="enemy"
  if cause=="attack":
   var attacker:=put("enemy",2);attacker.atk=2;model.attack_phase("enemy")
  else:model.state.enemy.hand=["of-stillwatch-072"];model.play("enemy",0,2)
  check(model.state.hero.lanes[2]==null and int(dying.atk)==before_atk,"already defeated self cannot receive its own postdamage buff for "+cause)
  check(model._targets("hero",{"effect":"heal_target","target":"self","params":{"amount":3}},{"source_uid":dying.uid,"source_lane":2}).is_empty(),"self-heal target selector excludes a defeated instance for "+cause)
 battle()
 var a: Dictionary={"mode":"triggered","trigger":"on_take_damage","effect":"grant_block","target":"own_hero","params":{"amount":2},"limit":"once_per_turn"}
 var before:=JSON.stringify([model.snapshot(),model.events],"",true)
 var reply: Dictionary=model.effect_runtime.publish("on_take_damage","hero",[a],{"event_id":"forged-fatal","source_card_id":"of-houses-007","source_uid":99999,"source_lane":2,"fatal_damage_source":true})
 check(not reply.ok and JSON.stringify([model.snapshot(),model.events],"",true)==before,"a caller cannot forge trusted fatal source capability for an arbitrary stale UID")
 battle();model.state.hero.hp=1;model.state.hero.hand=["of-stillwatch-070"]
 check(model.play("hero",0,2),"arm real before-hit shield")
 var defender:=put("hero",2);defender.hp=1
 var attacker:=put("enemy",2,"oa-ninth-c02")
 model.attack_phase("enemy")
 check(model.state.hero.hp==1 and model.state.hero.ward==2 and model.state.winner==null,"creature-defense shield prevents lethal native pierce overflow")

func test_weaken_convergence_control() -> void:
 # Arrange an already declared binding; trigger the real printed weakening card.
 # Attack loss cancels a binding only if it actually removes attack readiness.
 for side in ["hero","enemy"]:
  for attack_before in [4,1]:
   battle()
   var other: String=model._other(side)
   var uids: Array=[]
   for lane in [0,1,2]:
    var unit:=put(side,lane);unit.hp=10;unit.atk=4;uids.append(unit.uid)
   var target: Dictionary=model.state[side].lanes[0]
   target.hp=1;target.atk=attack_before
   model.state[side].convergence={"lanes":[0,1,2],"uids":uids.duplicate(),"broken":false}
   var source:=put(other,4,"of-stillwatch-005");source.hp=10
   model._lane_damage(other,4,1)
   check(target.atk==attack_before-1,"real damage trigger weakens the lowest-health opposing creature for "+side)
   check(bool(model.state[side].convergence.broken)==(attack_before==1),"weakening preserves controlled convergence paths and breaks zero-attack paths for "+side)
   check(model.controlled(side,0)==(attack_before>1),"binding follows actual path control after weakening for "+side)
   check(model.state[side].convergence.uids==uids and model.state.error.is_empty(),"weakening neither replaces the bound instances nor errors for "+side)
