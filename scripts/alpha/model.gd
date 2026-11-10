extends "res://scripts/legacy/battle_engine.gd"
## Alpha rule profile. Shared cards/damage/targets/death effects with isolated Legacy kernel.
const AlphaCatalog=preload("res://scripts/alpha/catalog.gd")
var convergence_enabled := true
var longest_chain := 0
var ai_policy: RefCounted = null
func _phase_hook(_trigger: String, _side: String) -> void: pass
func _combat_hook(_trigger: String, _side: String, _lane: int, _unit: Dictionary, _detail: Dictionary = {}) -> void: pass
func _attack_damage_hero(_source_side: String, _source_lane: int, target: Dictionary, amount: int) -> int: return damage(target, amount)
func _has_haste(card: Dictionary) -> bool: return card.effect == "haste"
func _init() -> void:catalog=AlphaCatalog.new()
func summon_limit() -> int:return 0
func reaction_order(order: String) -> String:
	return {"houses":"thorn","stillwatch":"tide","morph":"veil","ninth":"ash"}.get(order,order)
func start_alpha(deck: Array, opponent_deck: Array, seed_value: int, difficulty: int=2) -> bool:
	if not catalog.validate(deck).ok or not catalog.validate(opponent_deck).ok:return false
	rng=Random.new(seed_value)
	state={"seed":seed_value,"level":difficulty,"active":"hero","coin":null,"winner":null,"round":0,"hero":_player(deck,30),"enemy":_player(opponent_deck,30),"stage":"mulligan","origins":{"hero":-1,"enemy":-1},"origin_used":{"hero":false,"enemy":false},"second_path":false,"second_card":false,"delayed":[],"next_uid":1,"error":"","convergence_enabled":convergence_enabled}
	for side in ["hero","enemy"]:
		state[side].phase="opening";state[side].relic=null;state[side].relic_used=false;state[side].convergence=null;state[side].declaring=[]
		draw_cards(side,5)
	events.clear();_queue.clear();_dead_units.clear();_resolving=false;pending_death=null;queue_error=""
	_trace("alpha_start","system")
	return true
func snapshot() -> Dictionary:
	var result=super.snapshot()
	if not state.has("stage"):return result
	for key in ["stage","origins","origin_used","second_path","second_card","delayed","next_uid","error","convergence_enabled"]:
		var value=state[key];result[key]=value.duplicate(true) if value is Array or value is Dictionary else value
	for side in ["hero","enemy"]:
		for key in ["relic","relic_used","convergence","declaring"]:
			var value=state[side][key];result[side][key]=value.duplicate(true) if value is Array or value is Dictionary else value
	return result
func _exchange(side: String, indices: Array) -> void:
	if indices.is_empty():return
	var old: Array=[];var descending=indices.duplicate();descending.sort();descending.reverse()
	for index in descending:old.push_front(state[side].hand.pop_at(int(index)))
	draw_cards(side,indices.size())
	state[side].deck.append_array(old);state[side].deck=rng.shuffle(state[side].deck)
func mulligan(indices: Array) -> bool:
	if state.stage!="mulligan" or indices.size()>5:return false
	var seen: Dictionary={}
	for i in indices:
		if not _integer(i) or i<0 or i>=state.hero.hand.size() or seen.has(i):return false
		seen[i]=true
	_exchange("hero",indices)
	var enemy_indices: Array=[]
	for i in state.enemy.hand.size():
		if catalog.card(state.enemy.hand[i]).cost>3:enemy_indices.append(i)
	_exchange("enemy",enemy_indices)
	state.coin="hero" if rng.next_float()<.5 else "enemy";state.active=state.coin;state.stage="origins"
	_trace("mulligan","system")
	return true
func choose_origin(lane: Variant) -> bool:
	if state.stage!="origins" or not _integer(lane) or lane<0 or lane>4:return false
	state.origins.hero=int(lane);state.origins.enemy=int(floor(rng.next_float()*5));state.stage="second"
	_trace("origins_revealed","system")
	if state.coin=="hero":
		var highest := -1
		for i in state.enemy.hand.size():
			if catalog.card(state.enemy.hand[i]).cost>3:highest=i
		if highest>=0:_exchange("enemy",[highest]);state.second_card=true
		state.origins.enemy=(int(state.origins.enemy)+1)%5;state.second_path=true
		finish_opening()
	return true
func second_change(lane: Variant) -> bool:
	if state.stage!="second" or state.coin!="enemy" or state.second_path or not _integer(lane) or lane<0 or lane>4:return false
	state.origins.hero=int(lane);state.second_path=true;_trace("second_origin","hero");return true
func second_exchange(index: Variant) -> bool:
	if state.stage!="second" or state.coin!="enemy" or state.second_card or not _integer(index) or index<0 or index>=state.hero.hand.size():return false
	_exchange("hero",[int(index)]);state.second_card=true;_trace("second_card","hero");return true
func finish_opening() -> bool:
	if state.stage!="second":return false
	state.stage="battle";state.round=1;begin_turn(state.active)
	if state.active=="enemy" and state.winner==null:ai_turn("enemy")
	return true
func begin_turn(side: String) -> bool:
	if not _valid_side(side) or state.winner!=null or state.active!=side or state.stage!="battle":return false
	check_winner()
	if state.winner!=null:return true
	# Delayed effects resolve first; HP wins precede convergence at this boundary.
	var due: Array=[];var future: Array=[]
	for event in state.delayed:
		if int(event.due)<=int(state.round):due.append(event)
		else:future.append(event)
	state.delayed=future
	for event in due:
		if state.winner!=null:break
		_lane_damage(_other(event.side),int(event.lane),int(event.power));_trace("delayed_resolved",event.side,event);check_winner()
	if state.winner!=null:return true
	var p: Dictionary=state[side]
	if p.convergence!=null:
		var holds: bool=not p.convergence.broken
		for i in 3:
			var lane: int=p.convergence.lanes[i]
			if not controlled(side,lane) or int(p.lanes[lane].uid)!=int(p.convergence.uids[i]):holds=false
		p.convergence=null
		if holds:state.winner=side;_trace("convergence_win",side);return true
		_trace("convergence_failed",side)
	p.block=0;p.burstUsed=false;p.cycled=false;p.tacticUsed=false;p.fortifyUsed=false;p.relic_used=false;p.summons=0;p.attune=null
	p.turns=int(p.turns)+1;p.energy=mini(8,int(p.turns));p.phase="draw";p.drawDone=false
	p.pendingDraw=0 if int(p.turns)==1 and state.coin==side else 1
	_refill_deck(side)
	if state.winner!=null:return true
	_phase_hook("on_turn_start",side)
	_trace("begin",side)
	if side=="enemy":
		while p.hand.size()+mini(int(p.pendingDraw),p.deck.size())>6:_burn_reference(side,0)
		_finish_draw_reference(side)
	elif int(p.pendingDraw)==0:_finish_draw_reference(side)
	return true
func make_unit(side: String, card: Dictionary, lane: int) -> Dictionary:
	var unit=super.make_unit(side,card,lane)
	unit.uid=state.next_uid;state.next_uid=int(state.next_uid)+1;unit.ward=0;unit.extra_attacks=0
	if not state.origin_used[side] and int(state.origins[side])==lane:
		unit.ward=1;state.origin_used[side]=true
	return unit
func hit_unit(unit: Dictionary, amount: int) -> void:
	var absorbed=mini(int(unit.get("ward",0)),maxi(0,amount));unit.ward=int(unit.get("ward",0))-absorbed
	unit.hp=int(unit.hp)-maxi(0,amount-absorbed)
	if int(unit.hp)<=0:_break_uid(int(unit.uid))
func _break_uid(uid: int) -> void:
	for side in ["hero","enemy"]:
		var binding: Variant=state[side].convergence
		if binding!=null and binding.uids.has(uid):binding.broken=true
func _refresh_bindings() -> void:
	for side in ["hero","enemy"]:
		var binding: Variant=state[side].convergence
		if binding!=null:
			for i in 3:
				var u: Variant=state[side].lanes[binding.lanes[i]]
				if u==null or int(u.uid)!=int(binding.uids[i]) or int(u.stun)>0 or (u.summoned and not _has_haste(catalog.card(u.id))) or int(u.atk)<=int(state[side].weak):binding.broken=true
func can_fight(side: String, lane: int) -> bool:
	var u: Variant=state[side].lanes[lane]
	return u!=null and int(u.hp)>0 and int(u.stun)==0 and (not u.summoned or _has_haste(catalog.card(u.id))) and int(u.atk)>int(state[side].weak)
func controlled(side: String, lane: int) -> bool:
	return can_fight(side,lane) and state[_other(side)].lanes[lane]==null
func legal_targets(side: String, index: int) -> Array:
	var result: Array=[]
	for lane in 5:
		if play_support(side,index,lane).is_empty():result.append(lane)
	return result
func play_support(side: String, index: Variant, lane: Variant) -> String:
	if not state.has("stage") or state.stage!="battle" or not state.error.is_empty():return "not_battle"
	if not _valid_side(side) or not _integer(index) or index<0 or index>=state[side].hand.size():return "invalid_index"
	var card: Dictionary=catalog.card(state[side].hand[index])
	if card.kind=="creature":return super.play_support(side,index,lane)
	if card.kind=="event" and not card.effect in ["bolt","heal","stasis","surge","recall","delay","redirect","displace","cascade"]:return "unsupported_effect"
	if card.kind=="relic" and not card.effect in ["relic_res","relic_ward","relic_heal","relic_draw"]:return "unsupported_effect"
	if not card.kind in ["event","relic"]:return "unsupported_card_type"
	var p: Dictionary=state[side]
	if state.winner!=null or state.active!=side or p.phase!="main" or p.pendingTarget!=null or p.pendingShift!=null or int(p.energy)<int(card.cost) or not _integer(lane) or lane<0 or lane>4:return "invalid_action"
	var op: Dictionary=state[_other(side)]
	match str(card.effect):
		"stasis":
			if op.lanes[lane]==null:return "missing_enemy"
		"surge":
			if not can_fight(side,int(lane)):return "not_ready"
		"recall":
			if p.lanes[lane]!=null or _discard_unit(side)<0:return "no_recall_target"
		"redirect":
			var found := false
			for e in state.delayed:
				if e.side==side:found=true
			if not found:return "no_delayed_event"
		"displace":
			if op.lanes[lane]==null:return "missing_enemy"
			var free := false
			for to in [lane-1,lane+1]:
				if to>=0 and to<5 and op.lanes[to]==null:free=true
			if not free:return "no_free_neighbor"
	return ""
func _discard_unit(side: String) -> int:
	for i in range(state[side].discard.size()-1,-1,-1):
		if catalog.card(state[side].discard[i]).kind=="creature":return i
	return -1
func play(side: String, index: Variant, lane: Variant) -> bool:
	if not play_support(side,index,lane).is_empty():return false
	var p: Dictionary=state[side]
	var card: Dictionary=catalog.card(p.hand[index])
	if card.kind=="creature":
		var ok=super.play(side,index,lane);_refresh_bindings();return ok
	p.energy=int(p.energy)-int(card.cost);p.hand.remove_at(index)
	if card.kind=="relic":
		if p.relic!=null:p.discard.append(p.relic.id)
		p.relic={"id":card.id};_trace("relic_installed",side,{"card_id":card.id})
		_after_card_played(side,card,int(lane));return true
	_resolve_event_effect(side,card,int(lane))
	p.discard.append(card.id);_refresh_bindings();_trace("event",side,{"card_id":card.id,"lane":lane});check_winner();return true
func _resolve_event_effect(side: String, card: Dictionary, lane: int) -> void:
	# Default original effect dispatcher. Optional profiles may replace this single
	# effect boundary while preserving play validation/payment/zone transitions.
	var p: Dictionary=state[side]
	var op: Dictionary=state[_other(side)]
	match str(card.effect):
		"bolt":_lane_damage(_other(side),int(lane),int(card.power))
		"heal":p.hp=mini(int(p.maxHp),int(p.hp)+int(card.power))
		"stasis":op.lanes[lane].stun=maxi(int(op.lanes[lane].stun),int(card.power));_break_uid(int(op.lanes[lane].uid))
		"surge":p.lanes[lane].extra_attacks=int(p.lanes[lane].extra_attacks)+1
		"recall":
			var i=_discard_unit(side);var id: String=p.discard[i];p.discard.remove_at(i)
			var recalled: Dictionary=catalog.card(id);p.lanes[lane]=make_unit(side,recalled,int(lane))
			_trace("recall",side,{"lane":lane,"card_id":id});enqueue({"type":"summon","side":side,"lane":lane,"card_id":id})
		"delay":state.delayed.append({"side":side,"lane":int(lane),"due":int(state.round)+2,"power":int(card.power)})
		"redirect":
			for e in state.delayed:
				if e.side==side:e.lane=int(lane);break
		"displace":
			for to in [lane-1,lane+1]:
				if to>=0 and to<5 and op.lanes[to]==null:
					var u: Dictionary=op.lanes[lane];_break_uid(int(u.uid));op.lanes[to]=u;op.lanes[lane]=null;break
		"cascade":enqueue({"type":"echo","side":side,"remaining":int(card.power)})
func _lane_damage(side: String, lane: int, power: int) -> void:
	var p: Dictionary=state[side]
	if p.lanes[lane]==null:damage(p,power);return
	var unit: Dictionary=p.lanes[lane];hit_unit(unit,power)
	if int(unit.hp)<=0:
		p.lanes[lane]=null;enqueue({"type":"death","side":side,"lane":lane,"unit":unit})
func activate_relic(side: String) -> bool:
	if not _valid_side(side) or state.winner!=null or state.stage!="battle" or state.active!=side:return false
	var p: Dictionary=state[side]
	if p.phase!="main" or p.pendingTarget!=null or p.pendingShift!=null or p.relic==null or p.relic_used or int(p.energy)<1:return false
	var card: Dictionary=catalog.card(p.relic.id)
	if card.effect=="relic_draw" and (p.hand.size()>=6 or p.deck.is_empty()):return false
	p.energy=int(p.energy)-1;p.relic_used=true
	match str(card.effect):
		"relic_res":add_res(p,1)
		"relic_ward":p.ward=mini(25,int(p.ward)+2)
		"relic_heal":p.hp=mini(int(p.maxHp),int(p.hp)+2)
		"relic_draw":draw_cards(side,1)
	_trace("relic_activated",side,{"card_id":card.id});return true
func enqueue_many(batch: Array) -> bool:
	if state.is_empty() or state.winner!=null or not state.error.is_empty():return false
	for e in batch:
		if not e is Dictionary or not e.get("type","") in ["death","summon","formation","echo"] or not _valid_side(str(e.get("side",""))):return false
		if e.type=="echo" and (not _integer(e.get("remaining")) or int(e.remaining)<1):return false
		if e.type!="echo":
			var lane: Variant=e.get("to") if e.type=="formation" else e.get("lane")
			if not _integer(lane) or lane<0 or lane>4:return false
			if e.type=="death" and (not e.get("unit") is Dictionary or catalog.card(str(e.unit.get("id",""))).is_empty() or int(e.unit.get("hp",1))>0):return false
			if e.type=="summon":
				var card: Dictionary=catalog.card(str(e.get("card_id","")))
				if card.is_empty() or card.kind!="creature" or not supports_creature_effect(card):return false
	_queue.append_array(batch)
	if _resolving:return true
	_resolving=true
	var seen: Dictionary={};var processed := 0
	while not _queue.is_empty() and state.winner==null:
		var fingerprint=JSON.stringify([snapshot(),_queue],"",true).sha256_text()
		if seen.has(fingerprint) or processed>=10000:
			state.error="Effektzyklus oder technischer Sicherheitsfehler; Partie angehalten.";queue_error="effect_cycle";_queue.clear();_trace("error","system");break
		seen[fingerprint]=true;processed+=1
		var e: Dictionary=_queue.pop_front()
		_dispatch_effect(e)
	longest_chain=maxi(longest_chain,processed)
	_queue.clear();_resolving=false
	return state.error.is_empty()
func _dispatch_effect(e: Dictionary) -> void:
	match str(e.type):
		"death":_resolve_death(e)
		"summon":_resolve_summon(e);_refresh_bindings()
		"formation":_resolve_formation(e)
		"echo":
			damage(state[_other(e.side)],1);_trace("echo",e.side);check_winner()
			if int(e.remaining)>1:enqueue({"type":"echo","side":e.side,"remaining":int(e.remaining)-1})
func attack_phase(side: String) -> bool:
	if not _valid_side(side) or state.winner!=null or not state.error.is_empty():return false
	var p: Dictionary=state[side];var op: Dictionary=state[_other(side)]
	for lane in 5:
		if state.winner!=null:break
		var u: Variant=p.lanes[lane]
		if u==null:continue
		var c: Dictionary=catalog.card(u.id)
		if int(u.stun)>0:u.stun=int(u.stun)-1;u.summoned=false;u.extra_attacks=0;_trace("stun_skip",side,{"lane":lane});continue
		if u.summoned and not _has_haste(c):u.summoned=false;u.extra_attacks=0;_trace("summon_wait",side,{"lane":lane});continue
		u.summoned=false
		var count: int=1+int(u.extra_attacks);u.extra_attacks=0
		for _strike in count:
			if state.winner!=null or p.lanes[lane]==null:break
			_combat_hook("on_attack",side,lane,u)
			if p.lanes[lane]==null or int(p.lanes[lane].uid)!=int(u.uid) or state.winner!=null:break
			var target: Variant=op.lanes[lane]
			_combat_hook("on_defend",_other(side),lane,target if target!=null else {},{"attacker_side":side,"attacker_lane":lane,"attacker_uid":u.uid})
			if p.lanes[lane]==null or int(p.lanes[lane].uid)!=int(u.uid) or int(u.hp)<=0 or int(u.stun)>0 or state.winner!=null:break
			target=op.lanes[lane]
			var amount: int=maxi(0,int(u.atk)-int(p.weak))
			if target==null:_attack_damage_hero(side,lane,op,amount)
			else:
				var target_hp: int=int(target.hp)
				hit_unit(target,amount)
				if int(target.hp)<target_hp:_combat_hook("on_deal_damage",side,lane,u,{"amount":target_hp-int(target.hp)})
				if amount>0 and target.hp>0 and catalog.card(target.id).effect=="retaliate":hit_unit(u,int(catalog.card(target.id).power))
				if target.hp<=0:
					if c.effect=="pierce":damage(op,maxi(0,-int(target.hp)))
					if _remove_attack_casualty(_other(side),lane,target):_combat_hook("on_kill",side,lane,u,{"defeated_uid":target.uid})
				if u.hp<=0:_remove_attack_casualty(side,lane,u)
			_trace("attack",side,{"lane":lane,"amount":amount,"hero_target":target==null});check_winner()
	p.weak=0;_refresh_bindings();return true
func _remove_attack_casualty(side: String, original_lane: int, unit: Dictionary) -> bool:
	for lane in 5:
		var current: Variant=state[side].lanes[lane]
		if current!=null and int(current.uid)==int(unit.uid):
			state[side].lanes[lane]=null;enqueue({"type":"death","side":side,"lane":lane,"unit":unit});return true
	return false
func declare_convergence(side: String, lanes: Array) -> bool:
	if not state.convergence_enabled or state.winner!=null or state.stage!="battle" or state.active!=side or state[side].phase!="main" or int(floor(float(state.round-1)/2))<5 or lanes.size()!=3 or state[side].convergence!=null:return false
	var seen: Dictionary={}
	for lane in lanes:
		if not _integer(lane) or lane<0 or lane>4 or seen.has(lane) or not controlled(side,int(lane)):return false
		seen[lane]=true
	if state[side].pendingTarget!=null or state[side].pendingShift!=null:return false
	state[side].declaring=lanes.duplicate()
	return end_turn(side)
func _advance_unchecked(side: String) -> bool:
	state[side].phase="attack";_trace("phase_attack",side);attack_phase(side)
	if state.winner!=null or not state.error.is_empty():return true
	var p: Dictionary=state[side];p.phase="end"
	_phase_hook("on_turn_end",side)
	if not p.declaring.is_empty():
		var valid := true;var ids: Array=[]
		for lane in p.declaring:
			if not controlled(side,int(lane)):valid=false
			else:ids.append(int(p.lanes[lane].uid))
		if valid:p.convergence={"lanes":p.declaring.duplicate(),"uids":ids,"broken":false};_trace("convergence_declared",side)
		p.declaring=[]
	p.energy=0;_trace("phase_end",side)
	state.active=_other(side);state.round=int(state.round)+1;begin_turn(state.active);return true
func end_turn(side: String) -> bool:
	if state.stage!="battle" or not state.error.is_empty():return false
	if not advance_turn(side):return false
	if state.active=="enemy" and state.winner==null and state.error.is_empty():ai_turn("enemy")
	return true
func ai_turn(side: String) -> void:
	if ai_policy!=null:ai_policy.take_turn(self,side);return
	var p: Dictionary=state[side];var op: Dictionary=state[_other(side)]
	if p.phase=="draw":
		while p.hand.size()+mini(int(p.pendingDraw),p.deck.size())>6:_burn_reference(side,0)
		finish_draw(side)
	if state.winner!=null:return
	for _step in 12:
		if state.winner!=null or not state.error.is_empty():return
		if p.pendingTarget!=null:
			var target := -1
			for lane in 5:
				if op.lanes[lane]!=null and (target<0 or op.lanes[lane].hp<op.lanes[target].hp):target=lane
			if target>=0:choose_strike_target(side,target)
			continue
		if p.pendingShift!=null:skip_shift(side);continue
		var best: Dictionary={}
		for index in p.hand.size():
			var c: Dictionary=catalog.card(p.hand[index])
			for lane in legal_targets(side,index):
				var score: float=float(c.atk)+float(c.hp)*.45-float(c.cost)*.2
				if c.kind=="relic":score=3 if p.relic==null else -1
				if c.kind=="event":score=2
				if c.effect=="heal":score=5 if p.hp<20 else -1
				if c.effect=="recall":score=6
				if c.effect=="redirect":score=1
				if c.effect=="stasis" or c.effect=="bolt" or c.effect=="displace":score=4
				if int(state.level)>=5 and c.kind=="creature" and op.lanes[lane]!=null:
					score+=(3 if int(c.atk)>=int(op.lanes[lane].hp) else 0)+(2 if int(c.hp)>int(op.lanes[lane].atk) else 0)
				if int(state.level)<=1:score=float(c.atk)+float(c.hp)*.2+(2 if c.kind=="creature" else .1)
				if c.kind=="creature" and op.lanes[lane]==null:score+=float(c.atk)*.5
				if op.convergence!=null and op.convergence.lanes.has(lane) and (c.kind=="creature" or c.effect in ["stasis","bolt","displace"]):score+=6 if int(state.level)<=1 else 20
				if best.is_empty() or score>best.score:best={"index":index,"lane":lane,"score":score}
		if best.is_empty() or best.score<0:break
		if not play(side,best.index,best.lane):state.error="KI schlug eine illegale Aktion vor.";return
	if p.relic!=null and int(p.energy)>0:
		var effect: String=catalog.card(p.relic.id).effect
		if (effect=="relic_heal" and int(p.hp)<int(p.maxHp)) or (effect=="relic_ward" and int(p.ward)<25) or (effect=="relic_res" and int(p.resonance)<15) or effect=="relic_draw":activate_relic(side)
	if int(p.resonance)>=15:
		for faction in catalog.deck_ids():
			if burst(side,faction):break
	var lanes: Array=[]
	for lane in 5:
		if controlled(side,lane):lanes.append(lane)
	if lanes.size()>=3 and state.convergence_enabled and int(floor(float(state.round-1)/2))>=5:
		if declare_convergence(side,lanes.slice(0,3)):return
	end_turn(side)
func execute(command: String, args: Array) -> Dictionary:
	if state.is_empty() or not state.get("error","").is_empty():return {"ok":false,"reason":"error_state"}
	var ok := false
	match command:
		"mulligan":
			if args.size()==1 and args[0] is Array:ok=mulligan(args[0])
		"origin":
			if args.size()==1:ok=choose_origin(args[0])
		"secondOrigin":
			if args.size()==1:ok=second_change(args[0])
		"secondCard":
			if args.size()==1:ok=second_exchange(args[0])
		"openingDone":
			if args.is_empty():ok=finish_opening()
		"activateRelic":
			if args.size()==1 and args[0] is String:ok=activate_relic(args[0])
		"converge":
			if args.size()==2 and args[0] is String and args[1] is Array:ok=declare_convergence(args[0],args[1])
		_:return super.execute(command,args)
	return {"ok":ok,"reason":"" if ok else "invalid_action"}

func burst(side: String, order: Variant) -> bool:
	if not order is String or not order in catalog.deck_ids():return false
	return super.burst(side,order)
