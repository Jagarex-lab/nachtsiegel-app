extends RefCounted
## P01-P04 legacy kernel. No scene/UI/network/economy dependencies.
## start/begin_turn/advance_turn expose original boundaries BEFORE optional AI.
## Unsupported P05/P06/P07/P10 work is rejected, never silently approximated.
const Catalog = preload("res://scripts/legacy/catalog.gd")
const Validator = preload("res://scripts/legacy/deck_validator.gd")
const Random = preload("res://scripts/legacy/rng.gd")
const LANES := 5
const EVENT_LIMIT := 100
const PASSIVE_SUMMONS := ["harvest","retaliate","haste"]
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
	return {"packages":["P01","P02","P03-core","P04"],"summon_effects":PASSIVE_SUMMONS.duplicate(),"automatic_enemy_controller":false,"unsupported":["P05 overflow/fatigue/recycle/recover","P06 active summon effects/targets","P07 order reactions/active tactics/burst","P10 automatic AI","P11 replay audit"]}
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
	event["kind"]=kind;event["side"]=side;event["seq"]=events.size();event["state"]=snapshot()
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
func _draw_requirements(p: Dictionary, requested: int) -> String:
	if p.deck.is_empty() and not p.discard.is_empty():return "P05:recycle"
	if requested>p.deck.size():return "P05:fatigue"
	if p.hand.size()+mini(requested,p.deck.size())>6:return "P05:overflow"
	return ""
func begin_support(side: String) -> String:
	if not _valid_side(side):return "invalid_side"
	var p: Dictionary=state[side]
	if p.deck.is_empty() and not p.discard.is_empty():return "P05:recycle"
	var auto_draw: bool=side=="enemy" or int(p.turns)==0
	return _draw_requirements(p,3 if int(p.turns)==0 else 1) if auto_draw else ""
func begin_turn(side: String) -> bool:
	if not _valid_side(side) or state.winner!=null or state.active!=side or not begin_support(side).is_empty():return false
	var p: Dictionary=state[side]
	p.block=0;p.burstUsed=false;p.cycled=false;p.tacticUsed=false;p.fortifyUsed=false;p.summons=0
	p.energy=2+(1 if side=="enemy" and int(state.level)>=5 else 0)+(1 if int(p.turns)==0 and state.coin!=side else 0)
	for threshold in [5,10,15]:
		if int(p.resonance)>=threshold:p.energy+=1
	if int(p.resonance)==15:p.ward=mini(25,int(p.ward)+2)
	p.attune=null;p.turns=int(p.turns)+1;p.phase="draw";p.drawDone=false;p.pendingDraw=3 if int(p.turns)==1 else 1
	_trace("begin",side)
	if side=="enemy" or int(p.turns)==1:return finish_draw(side)
	return true
func draw_cards(side: String, count: int) -> int:
	if not _valid_side(side) or count<0:return 0
	var p: Dictionary=state[side]
	var actual := 0
	for i in count:
		if p.hand.size()>=6 or p.deck.is_empty():break
		p.hand.append(p.deck.pop_front());actual+=1
	return actual
func finish_draw(side: String) -> bool:
	if not _valid_side(side) or state.winner!=null or state.active!=side:return false
	var p: Dictionary=state[side]
	if p.phase!="draw" or not _draw_requirements(p,int(p.pendingDraw)).is_empty():return false
	draw_cards(side,int(p.pendingDraw))
	p.pendingDraw=0;p.phase="main";p.drawDone=true
	if int(p.fatigue)>0:p.fatigue=0
	_trace("draw_finished",side)
	return true
func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and abs(float(value))<=9007199254740991.0
func play_support(side: String, index: Variant, lane: Variant) -> String:
	if not _valid_side(side):return "invalid_side"
	var p: Dictionary=state[side]
	if state.winner!=null or state.active!=side or p.phase!="main" or p.pendingShift!=null or p.pendingTarget!=null:return "invalid_phase_or_pending"
	if not _integer(index) or not _integer(lane) or index<0 or index>=p.hand.size() or lane<0 or lane>=LANES:return "invalid_index"
	var card: Dictionary=catalog.card(str(p.hand[index]))
	if card.is_empty():return "unknown_card"
	if int(p.summons)>=2 or int(p.energy)<int(card.cost) or p.lanes[lane]!=null:return "invalid_resources_or_lane"
	if not card.effect in PASSIVE_SUMMONS:return "P06:summon_"+str(card.effect)
	if p.attune!=null and p.attune!=card.order:return "P07:order_reaction"
	return ""
func play(side: String, index: Variant, lane: Variant) -> bool:
	if not play_support(side,index,lane).is_empty():return false
	var p: Dictionary=state[side]
	var card: Dictionary=catalog.card(p.hand[index])
	p.hand.remove_at(index);p.energy=int(p.energy)-int(card.cost);p.summons=int(p.summons)+1
	p.lanes[lane]={"id":card.id,"hp":card.hp,"atk":card.atk,"summoned":true,"stun":0}
	p.attune=card.order
	_trace("summon",side,{"lane":lane,"card_id":card.id})
	check_winner()
	if state.winner==null:enqueue({"type":"summon","side":side,"card_id":card.id,"lane":lane})
	return true
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
		if not event is Dictionary or not event.get("type","") in ["death","summon"] or not _valid_side(str(event.get("side",""))):return false
		if not _integer(event.get("lane")) or int(event.lane)<0 or int(event.lane)>=LANES:return false
		if event.type=="death":
			if not event.get("unit") is Dictionary or catalog.card(str(event.unit.get("id",""))).is_empty() or int(event.unit.get("hp",1))>0:return false
		else:
			var card: Dictionary=catalog.card(str(event.get("card_id","")))
			if card.is_empty() or not card.effect in PASSIVE_SUMMONS:return false
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
		else:check_winner() # Original passive summon: no arrival effect, then check.
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
	if card.effect=="harvest":
		p.resonance=mini(15,int(p.resonance)+int(card.power)+1)
		_trace("harvest",event.side,{"card_id":unit.id})
	pending_death=null
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
			target.hp=int(target.hp)-attack
			_trace("unit_hit",side,{"lane":lane,"amount":attack})
			var target_card: Dictionary=catalog.card(target.id)
			if attack>0 and int(target.hp)>0 and target_card.effect=="retaliate":
				unit.hp=int(unit.hp)-int(target_card.power)
				_trace("retaliate",other,{"lane":lane,"amount":int(target_card.power)})
			if int(target.hp)<=0:
				var excess := maxi(0,-int(target.hp))
				if card.effect=="pierce" and excess>0:damage(opponent,excess)
				opponent.lanes[lane]=null
				enqueue({"type":"death","side":other,"unit":target,"lane":lane})
			if int(unit.hp)<=0:
				p.lanes[lane]=null
				enqueue({"type":"death","side":side,"unit":unit,"lane":lane})
		else:
			damage(opponent,attack)
			_trace("hero_hit",side,{"lane":lane,"amount":attack})
		check_winner()
	p.weak=0
	if state.winner==null:
		var held := 0
		for lane in LANES:
			if p.lanes[lane]!=null and opponent.lanes[lane]==null:held+=1
		p.seals=mini(2,int(p.seals)+1) if held>=3 else 0
		if int(p.seals)>=2:
			state.winner=side;_trace("result","system",{"winner":side})
	return true
func advance_turn(side: String) -> bool:
	# Transactional preflight on a disposable kernel prevents partial effects if
	# the next begin requires P05. The same methods execute; no second ruleset.
	if not _valid_side(side) or state.winner!=null or state.active!=side:return false
	var p: Dictionary=state[side]
	if p.phase!="main" or p.pendingShift!=null or p.pendingTarget!=null or p.hand.size()>6:return false
	var probe = get_script().new()
	probe.state=state.duplicate(true)
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
	# Closed orchestration surface. Internal primitives are not player commands.
	# advanceTurnBoundary is deliberately NOT the legacy endTurn+automatic-AI API.
	if command=="play":
		if args.size()!=3 or not args[0] is String:return {"ok":false,"reason":"invalid_arguments"}
		var reason := play_support(args[0],args[1],args[2])
		if not reason.is_empty():return {"ok":false,"reason":reason}
		return {"ok":play(args[0],args[1],args[2]),"reason":""}
	if command in ["finishDraw","advanceTurnBoundary"]:
		if args.size()!=1 or not args[0] is String:return {"ok":false,"reason":"invalid_arguments"}
		var ok: bool=finish_draw(args[0]) if command=="finishDraw" else advance_turn(args[0])
		return {"ok":ok,"reason":"" if ok else "invalid_or_unsupported_boundary"}
	return {"ok":false,"reason":"unsupported_command:"+command}
