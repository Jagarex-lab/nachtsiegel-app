extends RefCounted
## Shared legacy kernel. No scene/UI/network/economy dependencies.
## start/begin_turn/advance_turn expose original boundaries BEFORE optional AI.
## start_match/end_turn add the P10 original AI; the P11 original JS audit ABI remains unsupported.
const Catalog = preload("res://scripts/legacy/catalog.gd")
const Validator = preload("res://scripts/legacy/deck_validator.gd")
const Random = preload("res://scripts/legacy/rng.gd")
const LANES := 5
const EVENT_LIMIT := 100
const PASSIVE_SUMMONS := ["harvest","retaliate","haste"]
const EFFECTS := ["strike","guard","ward","mend","weave","drain","rally","silence","pierce","shift","harvest","retaliate","draw","haste","weaken","pulse"]
const PLAYER_FIELDS := ["phase","pendingDraw","drawDone","hp","maxHp","ward","block","resonance","energy","turns","attune","pendingShift","pendingTarget","weak","fatigue","burstUsed","cycled","summons","seals","cycles","tacticUsed","fortifyUsed"]
var catalog = Catalog.new()
var state: Dictionary = {}
var initial: Dictionary = {}
var rng: RefCounted
var events: Array = []
var pending_death: Variant = null
var queue_error := ""
var _queue: Array = []
var _resolving := false
var _dead_units: Array = []
func capabilities() -> Dictionary:
	return {"packages":["P01","P02","P03-core","P04","P05","P06","P07"],"summon_effects":EFFECTS.duplicate(),"automatic_enemy_controller":true,"unsupported":["P11 original JS audit ABI"]}
func _valid_side(side: String) -> bool:
	return side in ["hero","enemy"] and state.has(side)
func _other(side: String) -> String:
	return "enemy" if side=="hero" else "hero"
func _player(deck: Array, hp: int) -> Dictionary:
	return {"phase":"draw","pendingDraw":0,"drawDone":false,"hp":hp,"maxHp":hp,"ward":0,"block":0,"resonance":0,"energy":0,"deck":rng.shuffle(deck),"hand":[],"discard":[],"lanes":[null,null,null,null,null],"turns":0,"attune":null,"pendingShift":null,"pendingTarget":null,"weak":0,"fatigue":0,"burstUsed":false,"cycled":false,"summons":0,"seals":0,"cycles":0,"tacticUsed":false,"fortifyUsed":false}
func start(deck: Array, seed_value: int = 12345, level: int = 1) -> bool:
	if not Validator.new().validate(deck).ok or level<1:return false
	var random = Random.new(seed_value)
	var coin := "hero" if random.next_float()<.5 else "enemy"
	var pool: Array = []
	for card in catalog.all_cards():
		if card.rarity!="legendary" and int(card.cost)<=(2 if level<=2 else 3):pool.append(card.id)
	var enemy_deck: Array = random.shuffle(pool).slice(0,25)
	rng = random
	state = {"seed":seed_value,"level":level,"active":coin,"coin":coin,"winner":null,"hero":_player(deck,35),"enemy":_player(enemy_deck,mini(43,33+int(floor(float(level)/3)))),"round":1}
	state[_other(coin)].ward=4
	initial=snapshot()
	events.clear();_queue.clear();_dead_units.clear();_resolving=false;pending_death=null;queue_error=""
	return true
func snapshot() -> Dictionary:
	if state.is_empty():return {}
	var result: Dictionary={}
	for side: String in ["hero","enemy"]:
		var p: Dictionary=state[side]
		var part: Dictionary={}
		for key in PLAYER_FIELDS:
			var value: Variant=p[key]
			part[key]=value.duplicate(true) if value is Dictionary or value is Array else value
		part["deck"]=p.deck.duplicate();part["deckCount"]=p.deck.size()
		part["hand"]=p.hand.duplicate();part["handCount"]=p.hand.size();part["discard"]=p.discard.duplicate()
		var lanes: Array=[]
		for unit: Variant in p.lanes:
			if unit==null:lanes.append(null);continue
			var copy: Dictionary=unit.duplicate(true)
			var definition: Dictionary=catalog.card(unit.id)
			copy["baseHp"]=definition.hp;copy["baseAtk"]=definition.atk
			lanes.append(copy)
		part["lanes"]=lanes;result[side]=part
	for key: String in ["active","coin","round","winner","seed","level"]:result[key]=state[key]
	return result
func _trace(kind: String, side: String, detail: Dictionary = {}) -> void:
	var event: Dictionary=detail.duplicate(true)
	event["kind"]=kind;event["side"]=side;event["seq"]=events.size();event["state"]=snapshot();event["pendingDeath"]=pending_death.duplicate(true) if pending_death is Dictionary else null
	events.append(event)
func check_winner() -> void:
	if state.is_empty() or state.winner!=null:return
	if int(state.hero.hp)<=0 or int(state.enemy.hp)<=0:
		state.winner="draw" if int(state.hero.hp)<=0 and int(state.enemy.hp)<=0 else ("hero" if int(state.hero.hp)>0 else "enemy")
		_trace("result","system",{"winner":state.winner})
static func damage(player: Dictionary, amount: float, pierce: bool = false) -> int:
	if not is_finite(amount) or abs(amount)>9007199254740991.0:return -1
	var before := int(player.hp)
	var n := maxi(0,int(floor(amount)))
	if not pierce:
		var k := mini(int(player.block),n)
		player.block=int(player.block)-k;n-=k
		k=mini(int(player.ward),n)
		player.ward=int(player.ward)-k;n-=k
	player.hp=maxi(0,int(player.hp)-n)
	return before-int(player.hp)
func _hero_damage(player: Dictionary, amount: float, pierce: bool=false) -> int:
	return damage(player,amount,pierce)
func begin_support(side: String) -> String:
	return "" if _valid_side(side) else "invalid_side"
func begin_turn(side: String) -> bool:
	if not _valid_side(side) or state.winner!=null or state.active!=side:return false
	var p: Dictionary=state[side]
	p.block=0;p.burstUsed=false;p.cycled=false;p.tacticUsed=false;p.fortifyUsed=false;p.summons=0
	p.energy=2+(1 if side=="enemy" and int(state.level)>=5 else 0)+(1 if int(p.turns)==0 and state.coin!=side else 0)
	for threshold in [5,10,15]:
		if int(p.resonance)>=threshold:p.energy+=1
	if int(p.resonance)==15:p.ward=mini(25,int(p.ward)+2)
	p.attune=null;p.turns=int(p.turns)+1;p.phase="draw";p.drawDone=false;p.pendingDraw=3 if int(p.turns)==1 else 1
	_refill_deck(side)
	if state.winner!=null:return true
	_trace("begin",side)
	if side=="enemy":
		while p.hand.size()+mini(int(p.pendingDraw),p.deck.size())>6 and not p.hand.is_empty():
			var weakest := 0
			var score := INF
			for i in p.hand.size():
				var card: Dictionary=catalog.card(p.hand[i])
				var value: float=float(card.atk)+float(card.hp)*.25+float(card.power)-float(card.cost)
				if value<score:weakest=i;score=value
			_burn_reference(side,weakest)
		_finish_draw_reference(side)
		return true
	if int(p.turns)==1:_finish_draw_reference(side)
	return true
func _refill_deck(side: String) -> bool:
	var p: Dictionary=state[side]
	if not p.deck.is_empty() or p.discard.is_empty():return false
	p.cycles=int(p.cycles)+1
	var derived: int=(int(state.seed) ^ Random.mul_u32(int(p.cycles),2654435761) ^ (0x1234abcd if side=="hero" else 0x5678dcba)) & Random.MASK
	p.deck=Random.new(derived).shuffle(p.discard);p.discard=[]
	p.hp=maxi(0,int(p.hp)-mini(3,int(p.cycles)))
	_trace("recycle",side)
	check_winner()
	return true
func draw_cards(side: String, count: int) -> int:
	if not _valid_side(side) or count<0:return 0
	var p: Dictionary=state[side]
	var actual := 0
	for i in count:
		if p.hand.size()>=6 or p.deck.is_empty():break
		p.hand.append(p.deck.pop_front());actual+=1
	return actual
func _finish_draw_reference(side: String) -> bool:
	# Exact trusted raw-helper order, including legacy refill-before-rejection.
	if not _valid_side(side) or state.winner!=null or state.active!=side:return false
	var p: Dictionary=state[side]
	if p.phase!="draw":return false
	_refill_deck(side)
	if state.winner!=null:return true
	if p.hand.size()+mini(int(p.pendingDraw),p.deck.size())>6:return false
	var requested := int(p.pendingDraw)
	var available := mini(requested,p.deck.size())
	draw_cards(side,requested)
	var missing := requested-available
	p.pendingDraw=0;p.phase="main";p.drawDone=true
	_trace("draw_finished",side)
	if missing>0:
		p.fatigue=mini(3,int(p.fatigue)+1);p.hp=maxi(0,int(p.hp)-int(p.fatigue))
		_trace("fatigue",side);check_winner()
	elif int(p.fatigue)>0:
		p.fatigue=0;_trace("fatigue_reset",side)
	return true
func finish_draw(side: String) -> bool:
	var probe=_validation_probe()
	if not probe._finish_draw_reference(side):return false
	return _finish_draw_reference(side)
func _validation_probe():
	# Profile extension point: optional instance configuration must be cloned too.
	# The default remains the original disposable state-only validation kernel.
	var probe=get_script().new();probe.state=state.duplicate(true)
	return probe
func _burn_reference(side: String, index: Variant) -> bool:
	if not _valid_side(side) or state.active!=side:return false
	var p: Dictionary=state[side]
	if p.phase!="draw" or not _integer(index) or index<0 or index>=p.hand.size() or p.hand.size()+mini(int(p.pendingDraw),p.deck.size())<=6:return false
	p.discard.append(p.hand.pop_at(int(index)));_trace("burn",side)
	return true
func burn(side: String, index: Variant) -> bool:
	if not _valid_side(side) or state.winner!=null:return false
	return _burn_reference(side,index)
func recover(side: String) -> bool:
	if not _valid_side(side) or state.winner!=null or state.active!=side:return false
	var p: Dictionary=state[side]
	if p.phase!="main" or bool(p.cycled) or int(p.resonance)<5 or p.hand.size()>=6 or p.discard.is_empty():return false
	p.resonance=int(p.resonance)-5;p.cycled=true
	var derived: int=(int(state.seed)+Random.mul_u32(int(state.round),7919)+p.discard.size()*17) & Random.MASK
	p.discard=Random.new(derived).shuffle(p.discard);p.hand.append(p.discard.pop_back())
	_trace("recover",side)
	return true
func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and abs(float(value))<=9007199254740991.0
func supports_creature_effect(card: Dictionary) -> bool:
	return card.get("effect") in EFFECTS
func play_support(side: String, index: Variant, lane: Variant) -> String:
	if not _valid_side(side):return "invalid_side"
	var p: Dictionary=state[side]
	if state.winner!=null or state.active!=side or p.phase!="main" or p.pendingShift!=null or p.pendingTarget!=null:return "invalid_phase_or_pending"
	if not _integer(index) or not _integer(lane) or index<0 or index>=p.hand.size() or lane<0 or lane>=LANES:return "invalid_index"
	var card: Dictionary=catalog.card(str(p.hand[index]))
	if card.is_empty():return "unknown_card"
	if (summon_limit()>0 and int(p.summons)>=summon_limit()) or int(p.energy)<int(card.cost) or p.lanes[lane]!=null:return "invalid_resources_or_lane"
	if not supports_creature_effect(card):return "unknown_effect"
	return ""
func play(side: String, index: Variant, lane: Variant) -> bool:
	if not play_support(side,index,lane).is_empty():return false
	var p: Dictionary=state[side]
	var card: Dictionary=catalog.card(p.hand[index])
	p.hand.remove_at(index);p.energy=int(p.energy)-int(card.cost);p.summons=int(p.summons)+1
	p.lanes[lane]=make_unit(side,card,int(lane))
	var played_unit: Dictionary=p.lanes[lane]
	_trace("summon",side,{"lane":lane,"card_id":card.id})
	if p.attune!=null and p.attune!=card.order:
		add_res(p,2);_reaction(side,str(p.attune),str(card.order))
	p.attune=card.order
	check_winner()
	if state.winner==null:_after_card_played(side,card,int(lane))
	if state.winner==null:
		for current_lane in LANES:
			if p.lanes[current_lane]!=null and is_same(p.lanes[current_lane],played_unit):
				enqueue({"type":"summon","side":side,"card_id":card.id,"lane":lane if current_lane==int(lane) else current_lane});break
	return true
func _after_card_played(_side: String, _card: Dictionary, _lane: int) -> void:
	# Empty unless a separately instantiated rule profile explicitly opts in.
	pass
func _death_seen(unit: Dictionary) -> bool:
	for previous: Dictionary in _dead_units:
		if is_same(previous,unit):return true
	return false
func enqueue(event: Dictionary) -> bool:
	return enqueue_many([event])
func enqueue_many(batch: Array) -> bool:
	if state.is_empty():return false
	# Reject malformed/unsupported batches before touching the queue/state.
	for event: Variant in batch:
		if not event is Dictionary or not event.get("type","") in ["death","summon","formation"] or not _valid_side(str(event.get("side",""))):return false
		var lane: Variant=event.get("to") if event.type=="formation" else event.get("lane")
		if not _integer(lane) or int(lane)<0 or int(lane)>=LANES:return false
		if event.type=="death":
			if not event.get("unit") is Dictionary or catalog.card(str(event.unit.get("id",""))).is_empty() or int(event.unit.get("hp",1))>0:return false
		elif event.type=="summon":
			var card: Dictionary=catalog.card(str(event.get("card_id","")))
			if card.is_empty() or not card.effect in EFFECTS:return false
	if state.winner!=null:return false
	_queue.append_array(batch)
	if _resolving:return true
	_resolving=true
	var processed := 0
	queue_error=""
	while not _queue.is_empty():
		if state.winner!=null:_queue.clear();break
		processed+=1
		if processed>EVENT_LIMIT:
			_queue.clear();queue_error="event_limit";break
		var event: Dictionary=_queue.pop_front()
		if event.type=="death":_resolve_death(event)
		elif event.type=="summon":_resolve_summon(event)
		else:_resolve_formation(event)
	_resolving=false
	return queue_error.is_empty()
func _resolve_death(event: Dictionary) -> void:
	var unit: Dictionary=event.unit
	if _death_seen(unit):return
	_dead_units.append(unit)
	var p: Dictionary=state[event.side]
	var card: Dictionary=catalog.card(unit.id)
	pending_death={"side":event.side,"lane":event.get("lane"),"card":unit.id,"overkill":maxi(0,-int(unit.hp))}
	p.discard.append(unit.id)
	_trace("death",event.side,{"pendingDeath":pending_death})
	_apply_death_effect(event,card)
	pending_death=null
func _apply_death_effect(event: Dictionary, card: Dictionary) -> void:
	var p: Dictionary=state[event.side]
	var unit: Dictionary=event.unit
	if card.effect=="harvest":
		p.resonance=mini(15,int(p.resonance)+int(card.power)+1)
		_trace("harvest",event.side,{"card_id":unit.id})
func attack_phase(side: String) -> bool:
	if not _valid_side(side) or state.winner!=null:return false
	var p: Dictionary=state[side]
	var other := _other(side)
	var opponent: Dictionary=state[other]
	for lane in LANES:
		if state.winner!=null:break
		var unit: Variant=p.lanes[lane]
		if unit==null:continue
		var card: Dictionary=catalog.card(unit.id)
		if int(unit.stun)>0:
			unit.stun=int(unit.stun)-1;unit.summoned=false;_trace("stun_skip",side,{"lane":lane});continue
		if bool(unit.summoned) and card.effect!="haste":
			unit.summoned=false;_trace("summon_wait",side,{"lane":lane});continue
		unit.summoned=false
		var attack := maxi(0,int(unit.atk)-int(p.weak))
		var target: Variant=opponent.lanes[lane]
		if target!=null:
			hit_unit(target,attack)
			_trace("unit_hit",side,{"lane":lane,"amount":attack})
			var target_card: Dictionary=catalog.card(target.id)
			if attack>0 and int(target.hp)>0 and target_card.effect=="retaliate":
				hit_unit(unit,int(target_card.power))
				_trace("retaliate",other,{"lane":lane,"amount":int(target_card.power)})
			if int(target.hp)<=0:
				var excess := maxi(0,-int(target.hp))
				if card.effect=="pierce" and excess>0:
					_hero_damage(opponent,excess);_trace("pierce_overflow",side,{"lane":lane})
				opponent.lanes[lane]=null
				_trace("removed",other,{"lane":lane})
				enqueue({"type":"death","side":other,"unit":target,"lane":lane})
			if int(unit.hp)<=0:
				p.lanes[lane]=null
				_trace("removed",side,{"lane":lane})
				enqueue({"type":"death","side":side,"unit":unit,"lane":lane})
		else:
			_hero_damage(opponent,attack)
			_trace("hero_hit",side,{"lane":lane,"amount":attack})
		check_winner()
	p.weak=0
	if state.winner==null:
		var held := 0
		for lane in LANES:
			if p.lanes[lane]!=null and opponent.lanes[lane]==null:held+=1
		p.seals=mini(2,int(p.seals)+1) if held>=3 else 0
		_trace("path_control",side)
		if int(p.seals)>=2:
			state.winner=side;_trace("result","system",{"winner":side})
	return true
func advance_turn(side: String) -> bool:
	# Transactional preflight on a disposable kernel prevents partial effects if
	# a future next-boundary validator rejects the transition. The same methods execute; no second ruleset.
	if not _valid_side(side) or state.winner!=null or state.active!=side:return false
	var p: Dictionary=state[side]
	if p.phase!="main" or p.pendingShift!=null or p.pendingTarget!=null or p.hand.size()>6:return false
	var probe = _validation_probe()
	if not probe._advance_unchecked(side):return false
	return _advance_unchecked(side)
func _advance_unchecked(side: String) -> bool:
	state[side].phase="attack";_trace("phase_attack",side)
	attack_phase(side)
	if state.winner!=null:return true
	state[side].phase="end";_trace("phase_end",side)
	state.active=_other(side);state.round=int(state.round)+1
	if not begin_turn(state.active):return false
	check_winner()
	# Deliberately stop at original boundary before enemyTurn (P10).
	return true
func execute(command: String, args: Array) -> Dictionary:
	# Player-facing facade rejects finished operations and partial raw-helper failures.
	var arities := {"play":3,"finishDraw":1,"advanceTurnBoundary":1,"burn":2,"recover":1,"chooseStrikeTarget":2,"moveCreature":3,"skipShift":1,"burst":2,"tacticalMove":3,"fortify":2,"endTurn":1}
	if not arities.has(command):return {"ok":false,"reason":"unsupported_command:"+command}
	if args.size()!=int(arities[command]) or not args[0] is String or not _valid_side(args[0]):return {"ok":false,"reason":"invalid_arguments"}
	if state.winner!=null:return {"ok":false,"reason":"finished"}
	if command=="play":
		var reason := play_support(args[0],args[1],args[2])
		if not reason.is_empty():return {"ok":false,"reason":reason}
	var ok := false
	match command:
		"play":ok=play(args[0],args[1],args[2])
		"finishDraw":ok=finish_draw(args[0])
		"advanceTurnBoundary":ok=advance_turn(args[0])
		"burn":ok=burn(args[0],args[1])
		"recover":ok=recover(args[0])
		"chooseStrikeTarget":ok=choose_strike_target(args[0],args[1])
		"moveCreature":ok=move_creature(args[0],args[1],args[2])
		"skipShift":ok=skip_shift(args[0])
		"burst":ok=burst(args[0],args[1])
		"tacticalMove":ok=tactical_move(args[0],args[1],args[2])
		"fortify":ok=fortify(args[0],args[1])
		"endTurn":ok=end_turn(args[0])
	return {"ok":ok,"reason":"" if ok else "invalid_action"}
func add_res(player: Dictionary, amount: int) -> void:
	player.resonance=mini(15,int(player.resonance)+amount)
func _resolve_summon(event: Dictionary) -> void:
	if state.winner!=null:return
	var side: String=event.side
	var p: Dictionary=state[side]
	var op: Dictionary=state[_other(side)]
	var card: Dictionary=catalog.card(event.card_id)
	var lane := int(event.lane)
	var power := int(card.power)
	match str(card.effect):
		"strike":
			var targets: Array=[]
			for i in LANES:
				if op.lanes[i]!=null:targets.append(i)
			if targets.is_empty():
				_hero_damage(op,power+1);_trace("strike_hero",side)
			elif side=="hero":
				p.pendingTarget={"power":power+1,"sourceLane":lane};_trace("strike_pending",side)
			else:
				# Original effect-side target rule, NOT an enemy-turn controller.
				var target := int(targets[0])
				for i in targets:
					if int(op.lanes[i].hp)<int(op.lanes[target].hp):target=i
				_strike_target(side,target,power+1,lane)
		"guard":p.block=int(p.block)+power+2
		"ward":p.ward=mini(25,int(p.ward)+power+1)
		"mend":p.hp=mini(int(p.maxHp),int(p.hp)+power+2)
		"weave":add_res(p,power+1)
		"drain":
			var lost := _hero_damage(op,power+1)
			p.hp=mini(int(p.maxHp),int(p.hp)+lost);_trace("drain",side)
		"rally":
			var friend: Variant=p.lanes[lane-1] if lane>0 else null
			if friend==null and lane<LANES-1:friend=p.lanes[lane+1]
			if friend!=null:friend.atk=int(friend.atk)+power
		"silence":
			if op.lanes[lane]!=null:op.lanes[lane].stun=maxi(int(op.lanes[lane].stun),1)
		"pierce":_hero_damage(op,power+2,true);_trace("pierce_arrival",side)
		"shift":
			var choices := shift_choices(side,lane)
			if choices.is_empty():_trace("shift_no_target",side)
			else:
				p.pendingShift={"origin":lane}
				if side=="hero":_trace("shift_pending",side)
				else:
					var best: Dictionary=choices[0]
					for option: Dictionary in choices:
						if op.lanes[option.to]!=null and op.lanes[option.from]==null:best=option;break
					move_creature(side,best.from,best.to)
		"draw":draw_cards(side,1);_trace("effect_draw",side)
		"weaken":op.weak=maxi(int(op.weak),power)
		"pulse":
			add_res(p,power);p.ward=mini(25,int(p.ward)+power)
			for i in [lane-1,lane+1]:
				if i>=0 and i<LANES and p.lanes[i]!=null:p.lanes[i].atk=int(p.lanes[i].atk)+1
	if not card.effect in ["harvest","retaliate","haste","shift","pierce"]:_trace("effect",side,{"effect":card.effect})
	check_winner()
func _strike_target(side: String, lane: Variant, power: int, _source_lane: int) -> bool:
	if not _valid_side(side) or not _integer(lane) or lane<0 or lane>=LANES:return false
	var op: Dictionary=state[_other(side)]
	var target: Variant=op.lanes[lane]
	if target==null:return false
	hit_unit(target,power)
	_trace("strike_hit",side,{"lane":lane})
	if int(target.hp)<=0:
		op.lanes[lane]=null;_trace("removed",_other(side),{"lane":lane})
		enqueue({"type":"death","side":_other(side),"unit":target,"lane":lane})
	check_winner()
	return true
func choose_strike_target(side: String, lane: Variant) -> bool:
	if not _valid_side(side) or state.winner!=null or state.active!=side or state[side].pendingTarget==null:return false
	var pending: Dictionary=state[side].pendingTarget
	if not _strike_target(side,lane,int(pending.power),int(pending.sourceLane)):return false
	state[side].pendingTarget=null;_trace("target_complete",side)
	return true
func shift_choices(side: String, origin: int) -> Array:
	var result: Array=[]
	if not _valid_side(side):return result
	var p: Dictionary=state[side]
	for from in [origin-1,origin+1]:
		if from<0 or from>=LANES or p.lanes[from]==null:continue
		for to in LANES:
			if p.lanes[to]==null:result.append({"from":from,"to":to})
	return result
func move_creature(side: String, from: Variant, to: Variant) -> bool:
	if not _valid_side(side) or state.winner!=null or state.active!=side or not _integer(from) or not _integer(to):return false
	var p: Dictionary=state[side]
	if p.pendingShift==null or not shift_choices(side,int(p.pendingShift.origin)).has({"from":int(from),"to":int(to)}):return false
	p.lanes[to]=p.lanes[from];p.lanes[from]=null;p.pendingShift=null
	_trace("shift",side,{"from":from,"to":to})
	enqueue({"type":"formation","side":side,"to":int(to)})
	return true
func _skip_shift_reference(side: String) -> bool:
	if not _valid_side(side) or state.active!=side or state[side].pendingShift==null:return false
	state[side].pendingShift=null;_trace("shift_skipped",side)
	return true
func skip_shift(side: String) -> bool:
	if not _valid_side(side) or state.winner!=null:return false
	return _skip_shift_reference(side)
func _resolve_formation(event: Dictionary) -> void:
	if state.winner!=null:return
	var p: Dictionary=state[event.side]
	var to := int(event.to)
	if p.lanes[to]==null:return
	for neighbor in [to-1,to+1]:
		if neighbor>=0 and neighbor<LANES and p.lanes[neighbor]!=null:
			add_res(p,1);_trace("formation",event.side);return

func _reaction(side: String, from: String, to: String) -> void:
	var p: Dictionary=state[side]
	var enemy: Dictionary=state[_other(side)]
	var key := reaction_order(from)+">"+reaction_order(to)
	match key:
		"ash>tide","ash>veil":_hero_damage(enemy,2)
		"tide>thorn":p.ward=mini(25,int(p.ward)+3)
		"thorn>veil":p.hp=mini(int(p.maxHp),int(p.hp)+2)
		"veil>ash":enemy.weak=maxi(int(enemy.weak),1)
		"tide>veil":p.energy=int(p.energy)+1
		"ash>thorn":p.block=int(p.block)+3
		"thorn>ash","veil>thorn":p.ward=mini(25,int(p.ward)+2)
		"veil>tide":p.block=int(p.block)+2
		"thorn>tide","tide>ash":add_res(p,1)
		_:return
	_trace("reaction",side,{"pair":key})
func burst(side: String, order: Variant) -> bool:
	if not _valid_side(side) or state.winner!=null or state.active!=side:return false
	var p: Dictionary=state[side]
	if p.phase!="main" or int(p.resonance)<15 or bool(p.burstUsed) or not order is String:return false
	var units: Array=[]
	for unit: Variant in p.lanes:
		if unit!=null and catalog.card(unit.id).order==order:units.append(unit)
	if units.is_empty():return false
	# Original burst deliberately permits a pending strike/shift choice.
	p.resonance=int(p.resonance)-8;p.burstUsed=true
	var enemy: Dictionary=state[_other(side)]
	match reaction_order(str(order)):
		"ash":_hero_damage(enemy,4+units.size()*3)
		"tide":p.ward=mini(25,int(p.ward)+6+units.size()*2)
		"thorn":
			for unit: Variant in p.lanes:
				if unit!=null:unit.hp=mini(int(catalog.card(unit.id).hp),int(unit.hp)+3)
			p.hp=mini(int(p.maxHp),int(p.hp)+3+units.size())
		"veil":
			enemy.weak=2
			for unit: Dictionary in units:unit.atk=int(unit.atk)+2
	_trace("burst",side,{"order":order,"units":units.size()})
	check_winner()
	return true
func tactical_move(side: String, from: Variant, to: Variant) -> bool:
	if not _valid_side(side) or state.winner!=null or state.active!=side:return false
	var p: Dictionary=state[side]
	if p.phase!="main" or p.pendingTarget!=null or p.pendingShift!=null or bool(p.tacticUsed) or int(p.resonance)<3 or not _integer(from) or not _integer(to):return false
	if from<0 or from>=LANES or to<0 or to>=LANES or abs(int(from)-int(to))!=1 or p.lanes[from]==null or p.lanes[to]!=null:return false
	p.lanes[to]=p.lanes[from];p.lanes[from]=null;p.resonance=int(p.resonance)-3;p.tacticUsed=true
	_trace("tactical_move",side,{"from":from,"to":to})
	return true
func fortify(side: String, lane: Variant) -> bool:
	if not _valid_side(side) or state.winner!=null or state.active!=side:return false
	var p: Dictionary=state[side]
	if p.phase!="main" or p.pendingTarget!=null or p.pendingShift!=null or bool(p.fortifyUsed) or int(p.resonance)<2 or not _integer(lane) or lane<0 or lane>=LANES or p.lanes[lane]==null:return false
	var unit: Dictionary=p.lanes[lane]
	p.resonance=int(p.resonance)-2;p.fortifyUsed=true;p.ward=mini(25,int(p.ward)+2)
	unit.hp=mini(int(catalog.card(unit.id).hp),int(unit.hp)+1)
	_trace("fortify",side,{"lane":lane})
	return true

func start_match(deck: Array, seed_value: int = 12345, level: int = 1) -> bool:
	if not start(deck,seed_value,level):return false
	_trace("match_start","system")
	begin_turn(state.coin);check_winner()
	if state.winner==null and state.coin=="enemy":preload("res://scripts/legacy/opponent.gd").take_turn(self)
	return true
func end_turn(side: String) -> bool:
	if not advance_turn(side):return false
	if state.winner==null and state.active=="enemy":preload("res://scripts/legacy/opponent.gd").take_turn(self)
	return true

# Rule-profile extension points; default behavior remains the fixed Legacy contract.
func summon_limit() -> int:return 2
func reaction_order(order: String) -> String:return order
func make_unit(_side: String, card: Dictionary, _lane: int) -> Dictionary:
	return {"id":card.id,"hp":card.hp,"atk":card.atk,"summoned":true,"stun":0}
func hit_unit(unit: Dictionary, amount: int) -> void:unit.hp=int(unit.hp)-amount
