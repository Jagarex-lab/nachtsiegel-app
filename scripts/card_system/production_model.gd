extends "res://scripts/card_system/trigger_model.gd"
## Production profile over the existing Alpha/Legacy kernel and its one effect FIFO.
## Native 55 cards keep their original handlers. Generic cards have explicit V2 operations.
const Generic = preload("res://scripts/card_system/production_effects.gd")
const ProductionCatalog = preload("res://scripts/production/catalog.gd")
const PROFILE_ID := "production-550-v1"
var _configuration_error := ""
var _ability_uses: Dictionary = {}
var _condition_latches: Dictionary = {}
var _checking_conditions := false
var _publishing := 0
var _damage_depth := 0
var _armed: Array=[]
var _armed_serial := 0
var _relic_serial := 0
var _play_serial := 0

func _init(probe_from: RefCounted=null) -> void:
 if probe_from!=null:
  catalog=probe_from.catalog;_bindings=probe_from._bindings;_binding_hash=probe_from._binding_hash
  effect_runtime=ObservedRuntime.new(self);ai_policy=probe_from.ai_policy;return
 catalog = ProductionCatalog.new()
 ai_policy = preload("res://scripts/production/ai_policy.gd").new()
 var definitions: Array=[]
 for card in catalog.all_cards():
  if card.get("effect")=="v2":definitions.append(card)
 var result:=configure_v2(definitions)
 if not result.ok:_configuration_error=result.reason

func configure_v2(cards: Array) -> Dictionary:
 if not state.is_empty():return {"ok":false,"reason":"configure_before_match"}
 var candidate: Dictionary={}
 for definition: Variant in cards:
  if not definition is Dictionary or not definition.get("id") is String or definition.get("effect")!="v2":return {"ok":false,"reason":"invalid_generic_card"}
  if candidate.has(definition.id):return {"ok":false,"reason":"duplicate_binding"}
  var actual: Dictionary=catalog.card(definition.id)
  if actual.is_empty() or actual.get("effect")!="v2":return {"ok":false,"reason":"catalog_binding_required"}
  if definition!=actual:return {"ok":false,"reason":"catalog_definition_mismatch"}
  if not definition.get("abilities") is Array or definition.abilities.is_empty() or definition.abilities.size()>4:return {"ok":false,"reason":"invalid_abilities"}
  for ability in definition.abilities:
   var reason:=Generic.validate(ability)
   if not reason.is_empty():return {"ok":false,"reason":reason}
   if ability.effect=="summon_card":
    var summoned: Dictionary=catalog.card(ability.params.card_id)
    if summoned.is_empty() or summoned.kind!="creature":return {"ok":false,"reason":"unknown_summon_card"}
   if ability.mode=="activated" and definition.kind!="relic":return {"ok":false,"reason":"activated_relic_only"}
   if ability.mode=="passive" and definition.kind!="creature":return {"ok":false,"reason":"passive_creature_only"}
   if definition.kind=="event" and ability.mode=="reactive" and definition.abilities.size()!=1:return {"ok":false,"reason":"single_reactive_impulse_ability_required"}
  candidate[definition.id]=definition.duplicate(true)
 _bindings=candidate
 _binding_hash=JSON.stringify(candidate,"",true).sha256_text()
 effect_runtime=ObservedRuntime.new(self)
 if not effect_runtime.bind_species(cards):return {"ok":false,"reason":"invalid_species"}
 return {"ok":true,"reason":"","bound_cards":candidate.size()}

func start_alpha(deck: Array, opponent_deck: Array, seed_value: int, difficulty: int=2) -> bool:
 if not _configuration_error.is_empty():return false
 _ability_uses={};_condition_latches={};_checking_conditions=false;_publishing=0;_armed=[];_armed_serial=0;_relic_serial=0;_play_serial=0
 return super.start_alpha(deck,opponent_deck,seed_value,difficulty)

func snapshot() -> Dictionary:
 var result:=super.snapshot()
 if not result.is_empty():result["production"]={"profile":PROFILE_ID,"ability_uses":_ability_uses.duplicate(true),"condition_latches":_condition_latches.duplicate(true),"armed":_armed.duplicate(true),"armed_serial":_armed_serial,"relic_serial":_relic_serial,"play_serial":_play_serial}
 return result

func _validation_probe():
 # Immutable catalog/configuration are shared; only mutable battle/FIFO state is cloned.
 # Validation must not rebuild and revalidate 550 definitions on every turn/draw.
 var probe=get_script().new(self)
 probe.state=state.duplicate(true)
 probe._probe_instance=true
 probe._trigger_serial=_trigger_serial
 probe.trigger_journal=trigger_journal.duplicate(true)
 probe._journal_ids=_journal_ids.duplicate(true)
 probe._runtime_log_cursor=_runtime_log_cursor
 probe._summoned_uids=_summoned_uids.duplicate(true)
 probe._dead_uids=_dead_uids.duplicate(true)
 probe.effect_runtime.log=effect_runtime.log.duplicate(true)
 probe.effect_runtime._seen=effect_runtime._seen.duplicate(true)
 probe.effect_runtime._chain=effect_runtime._chain
 probe._ability_uses=_ability_uses.duplicate(true)
 probe._condition_latches=_condition_latches.duplicate(true)
 probe._armed=_armed.duplicate(true);probe._armed_serial=_armed_serial;probe._relic_serial=_relic_serial;probe._play_serial=_play_serial
 return probe

func supports_creature_effect(card: Dictionary) -> bool:
 return card.get("effect")=="v2" and _bindings.has(card.get("id")) or super.supports_creature_effect(card)

func _has_haste(card: Dictionary) -> bool:
 if super._has_haste(card):return true
 for ability in card.get("abilities",[]):
  if ability.get("mode")=="passive" and ability.get("effect")=="haste":return true
 return false

func capabilities() -> Dictionary:
 return {"profile":PROFILE_ID,"production_session_uses_profile":true,"source_bound_only":false,"configured_cards":_bindings.keys(),"automatic_ability_triggers":Generic.TRIGGERS.duplicate(),"effects":Generic.OPS.keys(),"reaction_windows":"automatic before attack/defense; declaration order, printed cost, once-per-turn limits; no hidden player interrupt"}

func target_side_for_card(card: Dictionary) -> String:
 if card.get("kind")=="creature":return "ally"
 if card.get("effect")!="v2":return "enemy" if card.get("effect") in ["bolt","stasis","delay","redirect","displace"] else "ally" if card.get("effect")=="surge" else "none"
 for a in card.get("abilities",[]):
  if a.get("trigger")!="on_play":continue
  if a.target in ["enemy_lane","opposite_enemy_unit","enemy_lowest_health","enemy_all"]:return "enemy"
  if a.target in ["own_lowest_health","own_neighbors","own_all","own_species"]:return "ally"
 return "none"

func play_support(side: String, index: Variant, lane: Variant) -> String:
 if not _valid_side(side) or not _integer(index) or index<0 or index>=state[side].hand.size():return "invalid_index"
 var card: Dictionary=catalog.card(state[side].hand[index])
 if card.get("effect")!="v2":return super.play_support(side,index,lane)
 var p: Dictionary=state[side]
 if state.get("stage")!="battle" or state.winner!=null or not state.get("error","").is_empty() or state.active!=side or p.phase!="main" or p.pendingTarget!=null or p.pendingShift!=null:return "invalid_phase_or_pending"
 if not _integer(lane) or lane<0 or lane>4:return "invalid_lane"
 if not _bindings.has(card.id) or int(p.energy)<int(card.cost) or int(p.resonance)<int(card.get("resonance_cost",0)):return "invalid_resources"
 if card.kind=="creature" and p.lanes[lane]!=null:return "occupied_lane"
 if card.kind=="event":
  var has_play := false
  for i in card.abilities.size():
   var a: Dictionary=card.abilities[i]
   if a.get("trigger")!="on_play":continue
   has_play=true
   var context: Dictionary={"event_id":"preflight","playing_from_hand":true,"source_card_id":card.id,"target_lane":int(lane),"ability_index":i}
   var reason:=production_preflight(side,a,context)
   if not reason.is_empty():return reason
  if not has_play:
   var reactive:=false
   for a in card.abilities:
    if a.mode=="reactive":reactive=true
   if not reactive:return "impulse_requires_on_play_or_reactive"
   var own_armed:=0
   for armed in _armed:
    if armed.side==side:own_armed+=1
   if own_armed>=3:return "maximum_armed_impulses"
 return ""

func play(side: String, index: Variant, lane: Variant) -> bool:
 var reason:=play_support(side,index,lane)
 if not reason.is_empty():return false
 var p: Dictionary=state[side]
 var card: Dictionary=catalog.card(p.hand[index])
 if card.get("effect")!="v2":
  var ok:=super.play(side,index,lane)
  if ok and card.kind=="relic":_relic_serial+=1;p.relic["uid"]=_relic_serial
  return ok
 # Existing native creature play owns payment, attunement/reactions, unit creation and summon queue.
 if card.kind=="creature":
  var resonance_cost:=int(card.get("resonance_cost",0))
  p.resonance=int(p.resonance)-resonance_cost
  var ok:=super.play(side,index,lane)
  if ok and resonance_cost>0:_publish_watchers("on_spend_resonance",side,{})
  _evaluate_conditions()
  return ok
 p.energy=int(p.energy)-int(card.cost)
 var res_cost:=int(card.get("resonance_cost",0));p.resonance=int(p.resonance)-res_cost
 p.hand.remove_at(int(index))
 if card.kind=="relic":
  if p.relic!=null:p.discard.append(p.relic.id)
  _relic_serial+=1;p.relic={"id":card.id,"uid":_relic_serial}
  _trace("relic_installed",side,{"card_id":card.id})
  _emit_trigger("on_play",side,card.id,{"source_relic":true,"source_relic_uid":int(state[side].relic.get("uid",0)),"target_lane":int(lane)},{"cause":"card_play"})
 else:
  var reactive:=false
  for a in card.abilities:
   if a.mode=="reactive":reactive=true
  if reactive:
   _armed_serial+=1
   _armed.append({"serial":_armed_serial,"side":side,"id":card.id,"lane":int(lane),"expires_turn":int(p.turns)+1})
   _trace("impulse_armed",side,{"card_id":card.id,"serial":_armed_serial,"lane":int(lane)})
  else:
   _resolve_event_effect(side,card,int(lane))
   p.discard.append(card.id)
   _trace("event",side,{"card_id":card.id,"lane":int(lane)})
 if res_cost>0:_publish_watchers("on_spend_resonance",side,{})
 _refresh_bindings();check_winner();_evaluate_conditions()
 return true

func _after_card_played(side: String, card: Dictionary, lane: int) -> void:
 if card.get("effect")!="v2":return
 var unit: Variant=state[side].lanes[lane]
 if unit!=null:_emit_trigger("on_play",side,card.id,{"source_lane":lane,"source_uid":unit.uid,"target_lane":lane},{"cause":"card_play"})

func _resolve_event_effect(side: String, card: Dictionary, lane: int) -> void:
 if card.get("effect")!="v2":super._resolve_event_effect(side,card,lane);return
 _play_serial+=1
 _emit_trigger("on_play",side,card.id,{"target_lane":lane,"source_instance":_play_serial},{"cause":"card_play"})

func _emit_trigger(trigger: String, side: String, card_id: String, context: Dictionary, detail: Dictionary) -> void:
 if not _bindings.has(card_id) or state.get("stage")!="battle" or state.winner!=null:return
 if _publishing>=128:
  state.error="Generische Auslöserkette überschreitet die Sicherheitsgrenze."
  return
 _publishing+=1
 var card: Dictionary=_bindings[card_id]
 for i in card.abilities.size():
  if state.winner!=null or not state.error.is_empty():break
  var a: Dictionary=card.abilities[i]
  if not a.get("mode") in ["triggered","reactive"] or a.get("trigger")!=trigger:continue
  var c:=context.duplicate(true);c.source_card_id=card_id;c.ability_index=i
  var record:=_note_trigger(trigger,side,card_id,c,detail,"published")
  c.event_id=record.event_id
  var reason:=production_preflight(side,a,c)
  if not reason.is_empty():
   record.status="fizzled";record.reason=reason
   _trace("v2_trigger_fizzled",side,{"event_id":record.event_id,"reason":reason})
   continue
  _journal_ids[record.event_id]=trigger_journal.size()-1
  var result: Dictionary=effect_runtime.publish(trigger,side,[a],c)
  _sync_runtime_log()
  if not result.ok:
   record.status="error";record.reason=result.reason
   state.error="Generische Effektkette angehalten: "+str(result.reason)
  elif record.status=="published":record.status="queued"
 _publishing-=1

func _context_for(side: String, lane: int, unit: Dictionary) -> Dictionary:
 return {"source_lane":lane,"source_uid":int(unit.uid),"target_lane":lane}

func _publish_watchers(trigger: String, side: String, detail: Dictionary) -> void:
 if not _valid_side(side) or state.get("stage")!="battle":return
 # Snapshot instances first; replacements cannot inherit another unit's queued trigger.
 var sources: Array=[]
 for lane in 5:
  var unit: Variant=state[side].lanes[lane]
  if unit!=null and _bindings.has(unit.id):sources.append({"id":unit.id,"context":_context_for(side,lane,unit)})
 if state[side].relic!=null and _bindings.has(state[side].relic.id):sources.append({"id":state[side].relic.id,"context":{"source_relic":true,"source_relic_uid":int(state[side].relic.get("uid",0)),"target_lane":0}})
 for source in sources:_emit_trigger(trigger,side,source.id,source.context,detail)
 _publish_armed(trigger,side,0)

func _phase_hook(trigger: String, side: String) -> void:
 if trigger=="on_turn_start":
  # Keys include round; discard old counters only at a real boundary, not during a probe.
  for unit in state[side].lanes:
   if unit!=null:unit["block"]=0
  var remaining: Array=[]
  for armed in _armed:
   if armed.side==side and int(state[side].turns)>=int(armed.expires_turn):
    state[side].discard.append(armed.id);_trace("impulse_expired",side,{"card_id":armed.id,"serial":armed.serial})
   else:remaining.append(armed)
  _armed=remaining
 _publish_watchers(trigger,side,{"cause":"turn_boundary"})
 _evaluate_conditions()

func _combat_hook(trigger: String, side: String, lane: int, unit: Dictionary, detail: Dictionary={}) -> void:
 if not unit.is_empty() and _bindings.has(unit.id):_emit_trigger(trigger,side,unit.id,_context_for(side,lane,unit),detail)
 var relic: Variant=state[side].relic
 if relic!=null and _bindings.has(relic.id):_emit_trigger(trigger,side,relic.id,{"source_relic":true,"source_relic_uid":int(state[side].relic.get("uid",0)),"target_lane":lane},detail)
 _publish_armed(trigger,side,lane)

func _attack_damage_hero(side: String, lane: int, target: Dictionary, amount: int) -> int:
 var lost:=damage(target,amount)
 if lost>0 and state[side].lanes[lane]!=null:_combat_hook("on_deal_damage",side,lane,state[side].lanes[lane],{"hero":true,"amount":lost})
 if lost>0:_publish_relic("on_take_damage",_other(side),lane)
 return lost

func hit_unit(unit: Dictionary, amount: int) -> void:
 var old_hp:=int(unit.hp)
 var absorbed:=mini(maxi(0,amount),int(unit.get("block",0)))
 unit["block"]=int(unit.get("block",0))-absorbed
 super.hit_unit(unit,maxi(0,amount)-absorbed)
 if int(unit.hp)>=old_hp or _damage_depth>=32:return
 _damage_depth+=1
 for side in ["hero","enemy"]:
  for lane in 5:
   var live: Variant=state[side].lanes[lane]
   if live!=null and int(live.uid)==int(unit.uid):_combat_hook("on_take_damage",side,lane,unit,{"amount":old_hp-int(unit.hp)})
 _damage_depth-=1

func _publish_relic(trigger: String, side: String, lane: int) -> void:
 var relic: Variant=state[side].relic
 if relic!=null and _bindings.has(relic.id):_emit_trigger(trigger,side,relic.id,{"source_relic":true,"source_relic_uid":int(state[side].relic.get("uid",0)),"target_lane":lane},{})

func draw_cards(side: String, count: int) -> int:
 var before: int=state[side].hand.size() if _valid_side(side) else 0
 var actual:=super.draw_cards(side,count)
 if state.get("stage")=="battle":
  for _i in actual:_publish_watchers("on_draw",side,{"cause":"card_draw","previous_hand_size":before})
 return actual

func _burn_reference(side: String, index: Variant) -> bool:
 var ok:=super._burn_reference(side,index)
 if ok:_publish_watchers("on_discard",side,{"cause":"mandatory_burn"})
 return ok

func _trace(kind: String, side: String, detail: Dictionary={}) -> void:
 super._trace(kind,side,detail)
 if kind in ["shift","tactical_move"] and detail.has("to") and _valid_side(side):
  var unit: Variant=state[side].lanes[int(detail.to)]
  if unit!=null:_combat_hook("on_lane_change",side,int(detail.to),unit,{"from":detail.get("from"),"to":detail.to})

func _use_key(side: String, a: Dictionary, context: Dictionary) -> String:
 return side+":"+str(context.get("source_uid",context.get("source_armed",context.get("source_relic_uid",context.get("source_instance","card:"+str(context.get("source_card_id","")))))))+":"+str(context.get("ability_index",0))+":"+str(state.round)

func _source_valid(side: String, context: Dictionary, trigger: String) -> bool:
 if context.has("source_armed"):
  for armed in _armed:
   if int(armed.serial)==int(context.source_armed) and armed.side==side:return true
  return false
 if context.get("source_relic",false):return state[side].relic!=null and state[side].relic.id==context.get("source_card_id") and int(state[side].relic.get("uid",0))==int(context.get("source_relic_uid",-1))
 if context.has("source_uid"):
  for unit in state[side].lanes:
   if unit!=null and int(unit.uid)==int(context.source_uid):return int(unit.hp)>0 or trigger in ["on_take_damage","on_death"]
  return trigger=="on_death"
 return true

func production_preflight(side: String, a: Dictionary, context: Dictionary) -> String:
 if not _valid_side(side) or state.get("stage")!="battle" or state.winner!=null or not state.get("error","").is_empty():return "not_battle"
 var reason:=Generic.validate(a)
 if not reason.is_empty():return reason
 if not _source_valid(side,context,str(a.get("trigger",""))):return "stale_source"
 if a.limit=="once_per_turn" and _ability_uses.has(_use_key(side,a,context)):return "ability_already_used"
 if a.mode=="activated" and (state.active!=side or state[side].phase!="main" or state[side].pendingTarget!=null or state[side].pendingShift!=null or state[side].relic==null or state[side].relic_used):return "invalid_activation_phase"
 if a.mode in ["activated","reactive"]:
  if int(state[side].energy)<int(a.activation.energy):return "insufficient_energy"
  if int(state[side].resonance)<int(a.activation.resonance):return "insufficient_resonance"
 if a.effect=="summon_card":
  if not catalog.card(a.params.card_id).get("kind")=="creature":return "unknown_summon_card"
  var free:=false
  for unit in state[side].lanes:
   if unit==null:free=true
  if not free:return "no_effect_target"
 var future_hand_size: int=state[side].hand.size()-(1 if context.get("playing_from_hand",false) else 0)
 if a.effect=="return_card" and (_discard_unit(side)<0 or future_hand_size>=6):return "no_effect_target"
 if a.effect=="draw_cards" and (state[side].deck.is_empty() or future_hand_size>=6):return "no_effect_target"
 if a.effect=="discard_card" and future_hand_size<=0:return "no_effect_target"
 if a.effect in ["deal_damage","grant_shield","grant_block","heal_target","modify_attack","weaken_unit","move_unit","stun_unit"] and a.target in ["self","opposite_enemy_unit","own_lowest_health","enemy_lowest_health","own_neighbors","own_all","enemy_all","own_species"] and _targets(side,a,context).is_empty():return "no_effect_target"
 if a.effect=="move_unit":
  var can_move:=false
  for target in _targets(side,a,context):
   var to:=int(target.lane)+int(a.params.steps)
   if to>=0 and to<5 and state[target.side].lanes[to]==null:can_move=true
  if not can_move:return "no_effect_target"
 return ""

func _targets(side: String, a: Dictionary, context: Dictionary) -> Array:
 var result: Array=[]
 var lane:=int(context.get("target_lane",context.get("source_lane",0)))
 var source_lane:=int(context.get("source_lane",lane))
 if context.has("source_uid"):
  for i in 5:
   if state[side].lanes[i]!=null and int(state[side].lanes[i].uid)==int(context.source_uid):source_lane=i;break
 var own: Dictionary=state[side];var other:=_other(side);var op: Dictionary=state[other]
 match str(a.target):
  "own_hero":result.append({"side":side,"lane":-1})
  "enemy_hero":result.append({"side":other,"lane":-1})
  "enemy_lane":result.append({"side":other,"lane":lane if op.lanes[lane]!=null else -1})
  "self":
   for i in 5:
    if own.lanes[i]!=null and int(own.lanes[i].uid)==int(context.get("source_uid",-1)):result.append({"side":side,"lane":i})
  "opposite_enemy_unit":
   if op.lanes[source_lane]!=null:result.append({"side":other,"lane":source_lane})
  "own_lowest_health","enemy_lowest_health":
   var chosen_side:=side if a.target=="own_lowest_health" else other
   var chosen: int=-1
   for i in 5:
    var unit: Variant=state[chosen_side].lanes[i]
    if unit!=null and int(unit.hp)>0 and (chosen<0 or int(unit.hp)<int(state[chosen_side].lanes[chosen].hp)):chosen=i
   if chosen>=0:result.append({"side":chosen_side,"lane":chosen})
  "own_neighbors":
   for i in [source_lane-1,source_lane+1]:
    if i>=0 and i<5 and own.lanes[i]!=null:result.append({"side":side,"lane":i})
  "own_all","enemy_all","own_species":
   var chosen_side:=other if a.target=="enemy_all" else side
   for i in 5:
    var unit: Variant=state[chosen_side].lanes[i]
    if unit!=null and int(unit.hp)>0:
     if a.target=="own_species" and not catalog.card(unit.id).get("species",[]).has(a.params.species):continue
     result.append({"side":chosen_side,"lane":i})
 for target in result:
  if int(target.lane)>=0 and state[target.side].lanes[int(target.lane)]!=null:target["uid"]=int(state[target.side].lanes[int(target.lane)].uid)
 return result

func production_apply(side: String, a: Dictionary, context: Dictionary) -> Dictionary:
 var p: Dictionary=state[side]
 if context.has("source_armed"):
  for i in _armed.size():
   if int(_armed[i].serial)==int(context.source_armed):
    var armed: Dictionary=_armed.pop_at(i);p.discard.append(armed.id);_trace("impulse_triggered",side,{"card_id":armed.id,"serial":armed.serial});break
 if a.limit=="once_per_turn":_ability_uses[_use_key(side,a,context)]=true
 if a.mode in ["activated","reactive"]:
  p.energy=int(p.energy)-int(a.activation.energy);p.resonance=int(p.resonance)-int(a.activation.resonance)
  if int(a.activation.resonance)>0:_publish_watchers("on_spend_resonance",side,{"cause":"ability_cost"})
 var amount:=int(a.params.get("amount",0))
 var actual: Dictionary={"effect":a.effect,"targets":[]}
 var targets:=_targets(side,a,context)
 for target in targets:
  var tp: Dictionary=state[target.side]
  var unit: Variant=tp.lanes[target.lane] if int(target.lane)>=0 else null
  if target.has("uid") and (unit==null or int(unit.uid)!=int(target.uid)):continue
  match str(a.effect):
   "deal_damage":
    if unit==null:
     var lost:=damage(tp,amount);actual["hero_hp_lost"]=lost
     if lost>0:
      _publish_relic("on_take_damage",target.side,int(context.get("target_lane",0)))
      _publish_source("on_deal_damage",side,context)
    else:
     var hp_before:=int(unit.hp);hit_unit(unit,amount)
     if unit.hp<=0 and _remove_attack_casualty(target.side,int(target.lane),unit):
      _publish_source("on_kill",side,context)
     if int(unit.hp)<hp_before:_publish_source("on_deal_damage",side,context)
   "grant_shield":
    if unit!=null:unit.ward=mini(25,int(unit.ward)+amount)
    else:tp.ward=mini(25,int(tp.ward)+amount)
   "grant_block":
    if unit!=null:unit["block"]=mini(25,int(unit.get("block",0))+amount)
    else:tp.block=mini(25,int(tp.block)+amount)
   "heal_target":
    if unit!=null:unit.hp=mini(int(catalog.card(unit.id).hp),int(unit.hp)+amount)
    else:tp.hp=mini(int(tp.maxHp),int(tp.hp)+amount)
   "modify_attack":
    if unit!=null:unit.atk=mini(40,int(unit.atk)+amount)
   "weaken_unit":
    if unit!=null:unit.atk=maxi(0,int(unit.atk)-amount);_break_uid(int(unit.uid))
   "stun_unit":
    if unit!=null:unit.stun=maxi(int(unit.stun),int(a.params.count));_break_uid(int(unit.uid))
   "move_unit":
    if unit!=null:
     var to:=int(target.lane)+int(a.params.steps)
     if to>=0 and to<5 and tp.lanes[to]==null:
      _break_uid(int(unit.uid));tp.lanes[to]=unit;tp.lanes[target.lane]=null
      _trace("generic_move",target.side,{"from":target.lane,"to":to,"uid":unit.uid})
      _combat_hook("on_lane_change",target.side,to,unit,{"from":target.lane,"to":to})
  actual.targets.append(target.duplicate(true))
 # Side-wide operations deliberately execute once, not once per matching unit.
 match str(a.effect):
  "gain_resonance":add_res(p,amount)
  "gain_energy":p.energy=mini(8,int(p.energy)+amount)
  "draw_cards":actual.drawn=draw_cards(side,int(a.params.count))
  "discard_card":
   if not p.hand.is_empty():
    var id: String=p.hand.pop_front();p.discard.append(id);_trace("generic_discard",side,{"card_id":id});_publish_watchers("on_discard",side,{"card_id":id})
  "return_card":
   var index:=_discard_unit(side)
   if index>=0 and p.hand.size()<6:
    var id: String=p.discard.pop_at(index);p.hand.append(id);actual.returned=id;_trace("generic_return",side,{"card_id":id})
  "summon_card":
   var lane:=int(context.get("target_lane",0))
   if p.lanes[lane]!=null:
    for i in 5:
     if p.lanes[i]==null:lane=i;break
   if p.lanes[lane]==null:
    var id: String=a.params.card_id;p.lanes[lane]=make_unit(side,catalog.card(id),lane)
    _trace("effect_summon",side,{"card_id":id,"lane":lane});actual.summon_resolved=enqueue({"type":"summon","side":side,"card_id":id,"lane":lane})
  "delay_damage":state.delayed.append({"side":side,"lane":int(context.get("target_lane",0)),"due":int(state.round)+int(a.params.turn_changes),"power":amount})
 _refresh_bindings();check_winner();_evaluate_conditions()
 return actual

func _publish_source(trigger: String, side: String, context: Dictionary) -> void:
 var id:=str(context.get("source_card_id",""))
 if _bindings.has(id):_emit_trigger(trigger,side,id,context,{"cause":"generic_damage"})

func _evaluate_conditions() -> void:
 if _checking_conditions or state.get("stage")!="battle" or state.winner!=null:return
 _checking_conditions=true
 for side in ["hero","enemy"]:
  var sources: Array=[]
  for lane in 5:
   var unit: Variant=state[side].lanes[lane]
   if unit!=null and _bindings.has(unit.id):sources.append({"id":unit.id,"context":_context_for(side,lane,unit)})
  if state[side].relic!=null and _bindings.has(state[side].relic.id):sources.append({"id":state[side].relic.id,"context":{"source_relic":true,"source_relic_uid":int(state[side].relic.get("uid",0)),"target_lane":0}})
  for source in sources:
   var card: Dictionary=_bindings[source.id]
   for i in card.abilities.size():
    var a: Dictionary=card.abilities[i]
    if a.get("trigger")!="on_condition":continue
    var p: Dictionary=state[side];var value:=0
    match str(a.condition.resource):
     "resonance":value=int(p.resonance)
     "energy":value=int(p.energy)
     "hand":value=p.hand.size()
     "controlled_paths":
      for lane in 5:
       if controlled(side,lane):value+=1
    var key: String=side+":"+str(source.context.get("source_uid",source.id))+":"+str(i)
    var holds:=value>=int(a.condition.at_least)
    var previous: bool=_condition_latches.get(key,false);_condition_latches[key]=holds
    if holds and not previous:_emit_trigger("on_condition",side,source.id,source.context,{"resource":a.condition.resource,"value":value})
 _checking_conditions=false

func relic_activation_cost(side: String) -> Dictionary:
 if not _valid_side(side) or state[side].relic==null:return {"energy":0,"resonance":0}
 var card: Dictionary=catalog.card(state[side].relic.id)
 for a in card.get("abilities",[]):
  if a.mode=="activated":return a.activation.duplicate(true)
 return {"energy":1,"resonance":0}

func can_activate_relic(side: String) -> bool:
 if not _valid_side(side) or state.get("stage")!="battle" or state.winner!=null or state.active!=side:return false
 var p: Dictionary=state[side]
 if p.phase!="main" or p.pendingTarget!=null or p.pendingShift!=null or p.relic==null or p.relic_used:return false
 var card: Dictionary=catalog.card(p.relic.id)
 if card.get("effect")!="v2":return int(p.energy)>=1 and not (card.effect=="relic_draw" and (p.hand.size()>=6 or p.deck.is_empty()))
 for i in card.abilities.size():
  var a: Dictionary=card.abilities[i]
  if a.mode=="activated":return production_preflight(side,a,{"source_card_id":card.id,"source_relic":true,"source_relic_uid":int(p.relic.get("uid",0)),"target_lane":0,"ability_index":i}).is_empty()
 return false

func activate_relic(side: String) -> bool:
 if not can_activate_relic(side):return false
 var p: Dictionary=state[side];var card: Dictionary=catalog.card(p.relic.id)
 if card.get("effect")!="v2":
  var ok:=super.activate_relic(side)
  if ok:_publish_watchers("on_relic_activate",side,{"card_id":card.id})
  return ok
 for i in card.abilities.size():
  var a: Dictionary=card.abilities[i]
  if a.mode!="activated":continue
  _trigger_serial+=1
  var result: Dictionary=effect_runtime.activate(side,a,{"event_id":"activate:"+str(_trigger_serial),"source_card_id":card.id,"source_relic":true,"source_relic_uid":int(p.relic.get("uid",0)),"target_lane":0,"ability_index":i})
  if not result.ok:return false
  p.relic_used=true;_trace("relic_activated",side,{"card_id":card.id,"cost":a.activation})
  _publish_watchers("on_relic_activate",side,{"card_id":card.id});_evaluate_conditions()
  return true
 return false

func execute(command: String, args: Array) -> Dictionary:
 var reply:=super.execute(command,args)
 if reply.ok:_evaluate_conditions()
 return reply

func _resonance_action_finished(side: String, before: int, ok: bool, cause: String) -> bool:
 if ok and int(state[side].resonance)<before:_publish_watchers("on_spend_resonance",side,{"cause":cause})
 if ok:_evaluate_conditions()
 return ok
func recover(side: String) -> bool:
 var before:=int(state[side].resonance) if _valid_side(side) else 0
 return _resonance_action_finished(side,before,super.recover(side),"recover")
func burst(side: String, order: Variant) -> bool:
 var before:=int(state[side].resonance) if _valid_side(side) else 0
 return _resonance_action_finished(side,before,super.burst(side,order),"burst")
func tactical_move(side: String, from: Variant, to: Variant) -> bool:
 var before:=int(state[side].resonance) if _valid_side(side) else 0
 return _resonance_action_finished(side,before,super.tactical_move(side,from,to),"tactical_move")
func fortify(side: String, lane: Variant) -> bool:
 var before:=int(state[side].resonance) if _valid_side(side) else 0
 return _resonance_action_finished(side,before,super.fortify(side,lane),"fortify")

func _publish_armed(trigger: String, side: String, lane: int) -> void:
 var sources:=_armed.duplicate(true)
 for armed in sources:
  if armed.side==side and _bindings.has(armed.id):_emit_trigger(trigger,side,armed.id,{"source_armed":armed.serial,"target_lane":lane},{"cause":"armed_impulse"})

func armed_impulses(side: String) -> Array:
 var result: Array=[]
 for armed in _armed:
  if armed.side==side:result.append(armed.duplicate(true))
 return result

func _lane_damage(side: String, lane: int, power: int) -> void:
 var p: Dictionary=state[side]
 if p.lanes[lane]==null:
  var lost:=damage(p,power)
  if lost>0:_publish_relic("on_take_damage",side,lane)
  return
 var unit: Dictionary=p.lanes[lane]
 hit_unit(unit,power)
 if int(unit.hp)<=0:_remove_attack_casualty(side,lane,unit)
