extends "res://scripts/card_system/trigger_model.gd"
## Production profile over the existing Alpha/Legacy kernel and its one effect FIFO.
## Native 55 cards keep their original handlers. Generic cards have explicit V2 operations.
const Generic = preload("res://scripts/card_system/production_effects.gd")
const ProductionCatalog = preload("res://scripts/production/catalog.gd")
const PROFILE_ID := "production-550-v1"
static var _cached_bindings: Dictionary={}
static var _cached_binding_hash := ""
static var _cached_catalog_fingerprint := ""
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
var _share_event_snapshots := true
var _last_history_state: Dictionary={}
var _pending_arrivals: Array=[]
var _native_choice_uids: Dictionary={}
var _draining_arrivals := false
var _resolving_native_choice := false
var _fatal_damage_sources: Dictionary={}

func _init(probe_from: RefCounted=null) -> void:
 if probe_from!=null:
  catalog=probe_from.catalog;_bindings=probe_from._bindings;_binding_hash=probe_from._binding_hash
  effect_runtime=ObservedRuntime.new(self);ai_policy=probe_from.ai_policy;return
 catalog = ProductionCatalog.new()
 ai_policy = preload("res://scripts/production/ai_policy.gd").new()
 var fingerprint: String=catalog.fingerprint()
 if not _cached_bindings.is_empty() and _cached_catalog_fingerprint==fingerprint:
  _bindings=_cached_bindings;_binding_hash=_cached_binding_hash;return
 var definitions: Array=[]
 for card in catalog.all_cards():
  if card.get("effect")=="v2":definitions.append(card)
 var result:=configure_v2(definitions)
 if not result.ok:_configuration_error=result.reason
 else:
  _cached_bindings=_bindings;_cached_binding_hash=_binding_hash;_cached_catalog_fingerprint=fingerprint

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
 var mechanics: Array=[]
 for definition in candidate.values():mechanics.append(ProductionCatalog.mechanical_card(definition))
 mechanics.sort_custom(func(a: Dictionary,b: Dictionary):return str(a.id)<str(b.id))
 _binding_hash=JSON.stringify(mechanics,"",true).sha256_text()
 effect_runtime=ObservedRuntime.new(self)
 if not effect_runtime.bind_species(cards):return {"ok":false,"reason":"invalid_species"}
 return {"ok":true,"reason":"","bound_cards":candidate.size()}

func start_alpha(deck: Array, opponent_deck: Array, seed_value: int, difficulty: int=2) -> bool:
 if not _configuration_error.is_empty():return false
 _ability_uses={};_condition_latches={};_checking_conditions=false;_publishing=0;_armed=[];_armed_serial=0;_relic_serial=0;_play_serial=0;longest_chain=0;_last_history_state={};_pending_arrivals=[];_native_choice_uids={};_draining_arrivals=false;_resolving_native_choice=false;_fatal_damage_sources={}
 return super.start_alpha(deck,opponent_deck,seed_value,difficulty)

func snapshot() -> Dictionary:
 var result:=super.snapshot()
 if not result.is_empty():result["production"]={"profile":PROFILE_ID,"ability_uses":_ability_uses.duplicate(true),"condition_latches":_condition_latches.duplicate(true),"armed":_armed.duplicate(true),"armed_serial":_armed_serial,"relic_serial":_relic_serial,"play_serial":_play_serial,"pending_arrivals":_pending_arrivals.duplicate(true),"native_choice_uids":_native_choice_uids.duplicate(true),"fatal_damage_sources":_fatal_damage_sources.duplicate(true)}
 return result

func _validation_probe():
 # Immutable catalog/configuration are shared; only mutable battle/FIFO state is cloned.
 # Validation must not rebuild and revalidate 550 definitions on every turn/draw.
 var probe=get_script().new(self)
 probe.state=state.duplicate(true)
 probe._probe_instance=true
 probe._trigger_serial=_trigger_serial
 var deep_history: bool=effect_runtime._resolving or _resolving
 probe.trigger_journal=trigger_journal.duplicate(deep_history)
 probe._journal_ids=_journal_ids.duplicate()
 probe._runtime_log_cursor=_runtime_log_cursor
 probe._summoned_uids=_summoned_uids.duplicate(true)
 probe._dead_uids=_dead_uids.duplicate(true)
 probe.effect_runtime.log=effect_runtime.log.duplicate(deep_history)
 probe.effect_runtime._seen=effect_runtime._seen.duplicate()
 probe.effect_runtime._chain=effect_runtime._chain
 probe._ability_uses=_ability_uses.duplicate(true)
 probe._condition_latches=_condition_latches.duplicate(true)
 probe._armed=_armed.duplicate(true);probe._armed_serial=_armed_serial;probe._relic_serial=_relic_serial;probe._play_serial=_play_serial
 probe.effect_runtime._publication_digest=effect_runtime._publication_digest
 probe._pending_arrivals=_pending_arrivals.duplicate(true);probe._native_choice_uids=_native_choice_uids.duplicate(true)
 probe._fatal_damage_sources=_fatal_damage_sources.duplicate(true)
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
  var c:=production_bind_context(side,a,context);c.source_card_id=card_id;c.ability_index=i
  var record:=_note_trigger(trigger,side,card_id,c,detail,"published")
  c.event_id=record.event_id
  var reason:=production_preflight(side,a,c)
  if not reason.is_empty():
   record.status="fizzled";record.reason=reason
   _trace("v2_trigger_fizzled",side,{"event_id":record.event_id,"reason":reason})
   continue
  _journal_ids[record.event_id]=trigger_journal.size()-1
  var fatal_uid:=int(c.get("source_uid",-1))
  if c.get("fatal_damage_source",false) and _fatal_damage_sources.has(fatal_uid):_fatal_damage_sources[fatal_uid].pending+=1
  var result: Dictionary=effect_runtime.publish(trigger,side,[a],c)
  _sync_runtime_log()
  if int(result.get("queued",0))==0 and c.get("fatal_damage_source",false):_retire_fatal_publication(fatal_uid)
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
  _prune_rule_caches()
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
 # These printed hooks describe a creature acting/receiving damage. An empty
 # defending lane is a hero attack, not an own creature defending.
 if unit.is_empty():return
 if _bindings.has(unit.id):
  var context:=_context_for(side,lane,unit)
  if detail.get("fatal_damage_source",false):context.fatal_damage_source=true
  _emit_trigger(trigger,side,unit.id,context,detail)
 var relic: Variant=state[side].relic
 if relic!=null and _bindings.has(relic.id):_emit_trigger(trigger,side,relic.id,{"source_relic":true,"source_relic_uid":int(state[side].relic.get("uid",0)),"target_lane":lane},detail)
 _publish_armed(trigger,side,lane)

func _attack_damage_hero(side: String, lane: int, target: Dictionary, amount: int) -> int:
 var lost:=_hero_damage(target,amount)
 if lost>0 and state[side].lanes[lane]!=null:_combat_hook("on_deal_damage",side,lane,state[side].lanes[lane],{"hero":true,"amount":lost})
 return lost

func hit_unit(unit: Dictionary, amount: int) -> void:
 var old_hp:=int(unit.hp)
 var absorbed:=mini(maxi(0,amount),int(unit.get("block",0)))
 unit["block"]=int(unit.get("block",0))-absorbed
 super.hit_unit(unit,maxi(0,amount)-absorbed)
 if old_hp<=0 or int(unit.hp)>=old_hp or _damage_depth>=32:return
 _damage_depth+=1
 for side in ["hero","enemy"]:
  for lane in 5:
   var live: Variant=state[side].lanes[lane]
   if live==null or int(live.uid)!=int(unit.uid):continue
   var fatal:=int(unit.hp)<=0
   if fatal:_fatal_damage_sources[int(unit.uid)]={"side":side,"id":unit.id,"lane":lane,"publishing":true,"pending":0}
   _combat_hook("on_take_damage",side,lane,unit,{"amount":old_hp-int(unit.hp),"fatal_damage_source":fatal})
   if fatal and _fatal_damage_sources.has(int(unit.uid)):
    _fatal_damage_sources[int(unit.uid)].publishing=false
    _cleanup_fatal_source(int(unit.uid))
 _damage_depth-=1

func _publish_relic(trigger: String, side: String, lane: int) -> void:
 var relic: Variant=state[side].relic
 if relic!=null and _bindings.has(relic.id):_emit_trigger(trigger,side,relic.id,{"source_relic":true,"source_relic_uid":int(state[side].relic.get("uid",0)),"target_lane":lane},{})
 _publish_armed(trigger,side,lane)

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
 if _share_event_snapshots and not events.is_empty():
  var event: Dictionary=events[-1]
  _share_closed_snapshot(event.state,_last_history_state)
  _last_history_state=event.state
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
  if trigger=="on_take_damage" and context.get("fatal_damage_source",false):
   var captured: Dictionary=_fatal_damage_sources.get(int(context.source_uid),{})
   if captured.get("side")==side and captured.get("id")==context.get("source_card_id"):return true
  for unit in state[side].lanes:
   if unit!=null and int(unit.uid)==int(context.source_uid):return int(unit.hp)>0 or trigger=="on_death"
  return trigger=="on_death"
 return true

func production_preflight(side: String, a: Dictionary, context: Dictionary) -> String:
 if not _valid_side(side) or state.get("stage")!="battle" or state.winner!=null or not state.get("error","").is_empty():return "not_battle"
 var reason:=Generic.validate(a)
 if not reason.is_empty():return reason
 if not _source_valid(side,context,str(a.get("trigger",""))):return "stale_source"
 if a.target in ["enemy_lane","opposite_enemy_unit"]:
  var prefix: String="selected" if a.target=="enemy_lane" else "opposite"
  if context.has(prefix+"_enemy_uid"):
   var bound_lane:=int(context[prefix+"_enemy_lane"])
   var bound_uid:=int(context[prefix+"_enemy_uid"])
   var current: Variant=state[_other(side)].lanes[bound_lane]
   if bound_uid==0 and current!=null:return "stale_target"
   if bound_uid>0 and (current==null or int(current.uid)!=bound_uid or int(current.hp)<=0):return "stale_target"
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
 # Hand/deck steps resolve in printed order after the played card leaves hand.
 # Optional steps may fizzle; an earlier discard can supply a later return.
 # Only command preflight defers these availability checks. FIFO publication
 # and late resolution still validate the actual state for each step.
 if not context.get("playing_from_hand",false):
  if a.effect=="return_card" and (_discard_unit(side)<0 or future_hand_size>=6):return "no_effect_target"
  if a.effect=="draw_cards" and (state[side].deck.is_empty() or future_hand_size>=6):return "no_effect_target"
  if a.effect=="discard_card" and future_hand_size<=0:return "no_effect_target"
 if a.effect in ["deal_damage","grant_shield","grant_block","heal_target","modify_attack","weaken_unit","move_unit","stun_unit"] and a.target in ["self","opposite_enemy_unit","own_lowest_health","enemy_lowest_health","own_neighbors","own_all","enemy_all","own_species"] and _targets(side,a,context).is_empty():return "no_effect_target"
 if a.effect=="move_unit" and not context.get("playing_from_hand",false):
  var can_move:=false
  for target in _targets(side,a,context):
   var to:=int(target.lane)+int(a.params.steps)
   if to>=0 and to<5 and state[target.side].lanes[to]==null:can_move=true
  if not can_move:return "no_effect_target"
 return ""

func _targets(side: String, a: Dictionary, context: Dictionary) -> Array:
 var result: Array=[]
 var lane:=int(context.get("selected_enemy_lane",context.get("target_lane",context.get("source_lane",0))))
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
    if own.lanes[i]!=null and int(own.lanes[i].hp)>0 and int(own.lanes[i].uid)==int(context.get("source_uid",-1)):result.append({"side":side,"lane":i})
  "opposite_enemy_unit":
   var bound_lane:=int(context.get("opposite_enemy_lane",source_lane))
   if op.lanes[bound_lane]!=null:result.append({"side":other,"lane":bound_lane})
  "own_lowest_health","enemy_lowest_health":
   var chosen_side:=side if a.target=="own_lowest_health" else other
   var chosen: int=-1
   for i in 5:
    var unit: Variant=state[chosen_side].lanes[i]
    if unit!=null and int(unit.hp)>0 and (chosen<0 or int(unit.hp)<int(state[chosen_side].lanes[chosen].hp)):chosen=i
   if chosen>=0:result.append({"side":chosen_side,"lane":chosen})
  "own_neighbors":
   for i in [source_lane-1,source_lane+1]:
    if i>=0 and i<5 and own.lanes[i]!=null and int(own.lanes[i].hp)>0:result.append({"side":side,"lane":i})
  "own_all","enemy_all","own_species":
   var chosen_side:=other if a.target=="enemy_all" else side
   for i in 5:
    var unit: Variant=state[chosen_side].lanes[i]
    if unit!=null and int(unit.hp)>0:
     if a.target=="own_species" and not catalog.cards.get(unit.id,{}).get("species",[]).has(a.params.species):continue
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
     var lost:=_hero_damage(tp,amount);actual["hero_hp_lost"]=lost
     if lost>0:_publish_source("on_deal_damage",side,context)
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
    if unit!=null:unit.hp=mini(int(catalog.cards[unit.id].hp),int(unit.hp)+amount)
    else:tp.hp=mini(int(tp.maxHp),int(tp.hp)+amount)
   "modify_attack":
    if unit!=null:unit.atk=mini(40,int(unit.atk)+amount)
   "weaken_unit":
    if unit!=null:unit.atk=maxi(0,int(unit.atk)-amount)
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
  "gain_energy":p.energy=mini(energy_limit(),int(p.energy)+amount)
  "draw_cards":actual.drawn=draw_cards(side,int(a.params.count))
  "discard_card":
   if not p.hand.is_empty():
    var id: String=p.hand.pop_front();p.discard.append(id);_trace("generic_discard",side,{"card_id":id});_publish_watchers("on_discard",side,{"card_id":id})
  "return_card":
   var index:=_discard_unit(side)
   if index>=0 and p.hand.size()<6:
    var id: String=p.discard.pop_at(index);p.hand.append(id);actual.returned=id;_trace("generic_return",side,{"card_id":id})
  "summon_card":
   var lane: int=-1
   for i in 5:
    if p.lanes[i]==null:lane=i;break
   if lane>=0:
    var id: String=a.params.card_id;p.lanes[lane]=make_unit(side,catalog.card(id),lane)
    _trace("effect_summon",side,{"card_id":id,"lane":lane});actual.summon_resolved=enqueue({"type":"summon","side":side,"card_id":id,"lane":lane})
  "delay_damage":
   var delayed: Dictionary={"side":side,"lane":int(context.get("target_lane",context.get("source_lane",0))),"due":int(state.round)+int(a.params.turn_changes),"power":amount}
   if context.has("source_uid") and catalog.cards.get(str(context.get("source_card_id","")),{}).get("kind")=="creature":
    delayed.creature_source={"owner":side,"source_card_id":context.source_card_id,"source_uid":int(context.source_uid),"source_lane":int(context.get("source_lane",0))}
   state.delayed.append(delayed)
 _refresh_bindings();check_winner();_evaluate_conditions();_drain_pending_arrivals()
 return actual

func _publish_source(trigger: String, side: String, context: Dictionary) -> void:
 var id:=str(context.get("source_card_id",""))
 if _bindings.has(id):_emit_trigger(trigger,side,id,context,{"cause":"generic_damage"})
 # A creature's printed damage is still damage/defeat caused by that creature.
 # Relics watching own creatures must observe it just like a native attack.
 # Impulse/relic damage does not satisfy the printed own-creature condition.
 if trigger in ["on_deal_damage","on_kill"] and catalog.cards.get(id,{}).get("kind")=="creature":
  var relic: Variant=state[side].relic
  if relic!=null and _bindings.has(relic.id):
   _emit_trigger(trigger,side,relic.id,{"source_relic":true,"source_relic_uid":int(relic.get("uid",0)),"target_lane":int(context.get("source_lane",0))},{"cause":"generic_creature_damage"})

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
  var lost:=_hero_damage(p,power)
  return
 var unit: Dictionary=p.lanes[lane]
 hit_unit(unit,power)
 if int(unit.hp)<=0:_remove_attack_casualty(side,lane,unit)

func _resolve_delayed_damage(event: Dictionary) -> void:
 var target_side:=_other(str(event.side));var lane:=int(event.lane)
 var target: Variant=state[target_side].lanes[lane]
 var before: int=int(target.hp) if target!=null else int(state[target_side].hp)
 _lane_damage(target_side,lane,int(event.power))
 # Delayed damage stays on its scheduled path and outlives its creator. Only
 # the captured source UID can receive personal damage triggers; a later copy
 # never inherits them. Relics can still observe a creature-caused defeat.
 if not event.get("creature_source") is Dictionary:return
 if event.creature_source.get("owner")!=event.side:return
 var after: int=int(target.hp) if target!=null else int(state[target_side].hp)
 if after>=before:return
 var context: Dictionary=event.creature_source.duplicate(true)
 context.erase("owner")
 if target!=null and int(target.hp)<=0 and _arrival_lane(target_side,int(target.uid))<0:_publish_source("on_kill",str(event.side),context)
 _publish_source("on_deal_damage",str(event.side),context)

func _hero_damage(player: Dictionary, amount: float, pierce: bool=false) -> int:
 var lost:=super._hero_damage(player,amount,pierce)
 # Hero damage is terminal before later effects, but never satisfies the
 # printed "own creature takes damage" condition on relics/armed impulses.
 if lost>0:check_winner()
 return lost

func production_bind_context(side: String, _ability: Dictionary, context: Dictionary) -> Dictionary:
 var result:=context.duplicate(true)
 var selected:=int(result.get("target_lane",result.get("source_lane",0)))
 var opposite:=int(result.get("source_lane",selected))
 if result.has("source_uid"):
  for lane in 5:
   if state[side].lanes[lane]!=null and int(state[side].lanes[lane].uid)==int(result.source_uid):opposite=lane;result.source_lane=lane;break
 for pair in [["selected",selected],["opposite",opposite]]:
  if result.has(str(pair[0])+"_enemy_uid"):continue
  var unit: Variant=state[_other(side)].lanes[int(pair[1])]
  result[str(pair[0])+"_enemy_lane"]=int(pair[1]);result[str(pair[0])+"_enemy_uid"]=0 if unit==null else int(unit.uid)
 return result

func _bridge_snapshot_metadata() -> Dictionary:
 var summoned: Array=_summoned_uids.keys();summoned.sort()
 var dead: Array=_dead_uids.keys();dead.sort()
 return {"version":2,"history_algorithm":"sha256-event-chain-v1","binding_sha256":_binding_hash,"trigger_serial":_trigger_serial,
  "summoned_uids":summoned,"dead_uids":dead,"runtime_event_count":effect_runtime._seen.size(),
  "runtime_history_sha256":effect_runtime._publication_digest,"runtime_chain":effect_runtime._chain}

func _prune_rule_caches() -> void:
 # Old-round usage can never block an ability in this or any future round.
 # Keep all current-round usage, including the opponent's reactions.
 var suffix:=":"+str(state.round)
 var current: Dictionary={}
 for key in _ability_uses:
  if str(key).ends_with(suffix):current[key]=true
 _ability_uses=current
 # Latches only belong to living condition sources. Re-entered creatures receive
 # a new UID; no future source may consult a departed instance's condition key.
 var valid: Dictionary={}
 for side in ["hero","enemy"]:
  var sources: Array=[]
  for unit in state[side].lanes:
   if unit!=null and int(unit.hp)>0 and _bindings.has(unit.id):sources.append([unit.id,str(unit.uid)])
  if state[side].relic!=null and _bindings.has(state[side].relic.id):sources.append([state[side].relic.id,str(state[side].relic.id)])
  for source in sources:
   var card: Dictionary=_bindings[source[0]]
   for i in card.abilities.size():
    if card.abilities[i].get("trigger")=="on_condition":valid[side+":"+str(source[1])+":"+str(i)]=true
 var live: Dictionary={}
 for key in _condition_latches:
  if valid.has(key):live[key]=_condition_latches[key]
 _condition_latches=live

func _snapshot_definition(id: String) -> Dictionary:
 # Read-only hot path: snapshots need only base HP/attack, never mutate card data.
 return catalog.cards.get(id,{})

func _share_closed_snapshot(current: Dictionary, previous: Dictionary) -> void:
 # Historical event snapshots are immutable after publication. Reuse unchanged
 # branches rather than storing hundreds of copies of the same hand/lanes/card.
 # Every event still exposes its complete ordinary Dictionary snapshot and order.
 if previous.is_empty():return
 for side in ["hero","enemy"]:
  var now: Dictionary=current[side];var old: Dictionary=previous[side]
  for key in ["deck","hand","discard","lanes","declaring","relic","convergence"]:
   if not now.has(key) or not old.has(key):continue
   if now[key]==old[key]:now[key]=old[key]
   elif key=="lanes":
    for lane in 5:
     if now.lanes[lane]==old.lanes[lane]:now.lanes[lane]=old.lanes[lane]
  if now==old:current[side]=old
 for key in ["origins","origin_used","delayed","production","v2_bridge"]:
  if not current.has(key) or not previous.has(key):continue
  if current[key]==previous[key]:current[key]=previous[key]
  elif key in ["production","v2_bridge"]:
   for field in current[key]:
    if previous[key].has(field) and current[key][field]==previous[key][field]:current[key][field]=previous[key][field]

func enqueue_many(batch: Array) -> bool:
 var captured: Array=[]
 for item in batch:
  if not item is Dictionary:return false
  var event: Dictionary=item.duplicate(false)
  if event.get("type")=="summon":
   var side:=str(event.get("side",""));var lane: Variant=event.get("lane")
   if not _valid_side(side) or not _integer(lane) or lane<0 or lane>4:return false
   var unit: Variant=state[side].lanes[int(lane)]
   if unit==null or unit.id!=event.get("card_id"):return false
   if event.has("production_source_uid"):
    if not Generic.integer(event.production_source_uid,1,9007199254740991):return false
   else:event.production_source_uid=int(unit.uid)
  captured.append(event)
 var ok:=super.enqueue_many(captured)
 if ok:_drain_pending_arrivals()
 return ok

func _any_native_choice() -> bool:
 for side in ["hero","enemy"]:
  if state[side].pendingTarget!=null or state[side].pendingShift!=null:return true
 return false

func _arrival_lane(side: String, uid: int) -> int:
 for lane in 5:
  var unit: Variant=state[side].lanes[lane]
  if unit!=null and int(unit.uid)==uid and int(unit.hp)>0:return lane
 return -1

func _resolve_summon(event: Dictionary) -> void:
 if _any_native_choice():
  if _pending_arrivals.size()>=EffectRegistry.MAX_CHAIN:
   state.error="Zu viele wartende Beschwörungen; Partie angehalten.";_trace("error","system");return
  _pending_arrivals.append(event.duplicate(true))
  _trace("arrival_deferred",event.side,{"card_id":event.card_id,"uid":event.get("production_source_uid"),"lane":event.lane})
  return
 var side:=str(event.side);var uid:=int(event.get("production_source_uid",event.get("v2_source_uid",-1)))
 var lane:=_arrival_lane(side,uid)
 if lane<0 or state[side].lanes[lane].id!=event.card_id:
  _trace("arrival_fizzled",side,{"card_id":event.card_id,"uid":uid,"reason":"stale_source"});return
 if _summoned_uids.has(uid):
  _trace("arrival_fizzled",side,{"card_id":event.card_id,"uid":uid,"reason":"duplicate_instance"});return
 var current:=event.duplicate(true);current.lane=lane
 if _bindings.has(str(event.card_id)):super._resolve_summon(current)
 else:
  _summoned_uids[uid]=true
  super._resolve_summon(current)
 _refresh_bindings()
 if state[side].pendingTarget!=null or state[side].pendingShift!=null:_native_choice_uids[side]=uid

func _refresh_native_choices() -> void:
 for side in ["hero","enemy"]:
  var p: Dictionary=state[side]
  if p.pendingTarget==null and p.pendingShift==null:_native_choice_uids.erase(side);continue
  if _native_choice_uids.has(side):
   var uid:=int(_native_choice_uids[side]);var lane:=_arrival_lane(side,uid)
   if lane<0:
    p.pendingTarget=null;p.pendingShift=null;_native_choice_uids.erase(side)
    _trace("arrival_choice_fizzled",side,{"source_uid":uid,"reason":"stale_source"});continue
   if p.pendingTarget!=null:p.pendingTarget.sourceLane=lane
   if p.pendingShift!=null:p.pendingShift.origin=lane
  if p.pendingTarget!=null:
   var has_enemy:=false
   for unit in state[_other(side)].lanes:
    if unit!=null and int(unit.hp)>0:has_enemy=true
   if not has_enemy:
    var amount:=int(p.pendingTarget.power)
    p.pendingTarget=null;_native_choice_uids.erase(side)
    _hero_damage(state[_other(side)],amount);_trace("strike_hero",side,{"reason":"selected_window_no_enemy_units","amount":amount});check_winner()

func _drain_pending_arrivals() -> void:
 if _draining_arrivals or _resolving or _resolving_native_choice or state.is_empty() or state.get("stage")!="battle":return
 _draining_arrivals=true
 _refresh_native_choices()
 while not _pending_arrivals.is_empty() and not _any_native_choice() and state.winner==null and state.error.is_empty():
  var event: Dictionary=_pending_arrivals.pop_front()
  _resolve_summon(event)
  _refresh_native_choices()
 _draining_arrivals=false

func choose_strike_target(side: String,lane: Variant) -> bool:
 _resolving_native_choice=true
 var ok:=super.choose_strike_target(side,lane)
 _resolving_native_choice=false
 if ok:_native_choice_uids.erase(side);_drain_pending_arrivals()
 return ok

func move_creature(side: String,from: Variant,to: Variant) -> bool:
 _resolving_native_choice=true
 var ok:=super.move_creature(side,from,to)
 _resolving_native_choice=false
 if ok:_native_choice_uids.erase(side);_drain_pending_arrivals()
 return ok

func skip_shift(side: String) -> bool:
 _resolving_native_choice=true
 var ok:=super.skip_shift(side)
 _resolving_native_choice=false
 if ok:_native_choice_uids.erase(side);_drain_pending_arrivals()
 return ok

func _strike_target(side: String,lane: Variant,power: int,source_lane: int) -> bool:
 if not _valid_side(side) or not _integer(lane) or lane<0 or lane>4:return false
 var other:=_other(side);var target: Variant=state[other].lanes[int(lane)]
 if target==null:return false
 var source: Variant=state[side].lanes[source_lane]
 var hp_before:=int(target.hp)
 hit_unit(target,power);_trace("strike_hit",side,{"lane":lane})
 if int(target.hp)<hp_before and source!=null:_combat_hook("on_deal_damage",side,source_lane,source,{"amount":hp_before-int(target.hp),"cause":"arrival_strike"})
 if int(target.hp)<=0:
  _trace("removed",other,{"lane":lane})
  if _remove_attack_casualty(other,int(lane),target) and source!=null:
   _combat_hook("on_kill",side,source_lane,source,{"defeated_uid":target.uid,"cause":"arrival_strike"})
 check_winner()
 return true

func _sync_runtime_log() -> void:
 var previous:=_runtime_log_cursor
 super._sync_runtime_log()
 for i in range(previous,_runtime_log_cursor):
  var entry: Dictionary=effect_runtime.log[i]
  if entry.context.get("fatal_damage_source",false):_retire_fatal_publication(int(entry.context.get("source_uid",-1)))

func _retire_fatal_publication(uid: int) -> void:
 if not _fatal_damage_sources.has(uid):return
 _fatal_damage_sources[uid].pending=maxi(0,int(_fatal_damage_sources[uid].pending)-1)
 _cleanup_fatal_source(uid)

func _cleanup_fatal_source(uid: int) -> void:
 if _fatal_damage_sources.has(uid) and not _fatal_damage_sources[uid].publishing and int(_fatal_damage_sources[uid].pending)==0:_fatal_damage_sources.erase(uid)
