extends SceneTree
const Model=preload("res://scripts/alpha/model.gd")
const Catalog=preload("res://scripts/alpha/catalog.gd")
const Session=preload("res://scripts/alpha/session.gd")
var assertions := 0
var failures := 0
var simulations: Array=[]
func check(ok: bool, label: String) -> void:
	assertions+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func fresh(seed_value: int=12345):
	var m=Model.new();m.start_alpha(m.catalog.deck("houses"),m.catalog.deck("stillwatch"),seed_value);return m
func battle():
	var m=fresh();m.mulligan([]);m.choose_origin(2)
	if m.state.stage=="second":m.finish_opening()
	m.state.active="hero";m.state.winner=null;m.state.round=11;m.state.delayed=[]
	for side in ["hero","enemy"]:
		var p: Dictionary=m.state[side];p.phase="main";p.energy=20;p.resonance=0;p.lanes=[null,null,null,null,null];p.hand=[];p.discard=[];p.pendingTarget=null;p.pendingShift=null;p.convergence=null;p.hp=30;p.maxHp=30;p.ward=0;p.block=0;p.fatigue=0;p.weak=0;p.relic=null;p.relic_used=false;p.summons=0;p.attune=null
	return m
func unit(m, side: String, lane: int, id: String="oa-neutral-c01") -> Dictionary:
	var u=m.make_unit(side,m.catalog.card(id),lane);u.summoned=false;m.state[side].lanes[lane]=u;return u
func bind(m) -> void:
	var ids: Array=[]
	for lane in [0,2,4]:ids.append(unit(m,"hero",lane).uid)
	m.state.hero.convergence={"lanes":[0,2,4],"uids":ids,"broken":false}
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var catalog=Catalog.new();check(catalog.all_cards().size()==55,"55 distinct cards")
	for f in catalog.deck_ids():check(catalog.validate(catalog.deck(f)).ok,"legal starter "+f)
	var mixed=catalog.deck("houses");mixed[0]="oa-morph-c01";check(not catalog.validate(mixed).ok,"mixed power rejected")
	check(not catalog.validate(catalog.deck("houses").slice(0,29)).ok,"size rejected")
	var seen_coin: Dictionary={}
	for seed_value in range(16):
		var m=fresh(seed_value)
		check(m.state.hero.hp==30 and m.state.enemy.hp==30,"30 HP")
		check(m.state.hero.hand.size()==5 and m.state.enemy.hand.size()==5,"5 opening cards")
		var before=m.snapshot();check(not m.mulligan([0,0]),"duplicate exchange rejected");check(before==m.snapshot(),"rejected opening immutable")
		check(m.mulligan([0,2]),"mulligan valid");check(not m.mulligan([]),"once only")
		for side in ["hero","enemy"]:
			check(m.state[side].deck.size()+m.state[side].hand.size()==30,"mulligan card conservation")
		seen_coin[m.state.coin]=true;check(m.choose_origin(2),"origins chosen")
		if m.state.stage=="second":
			check(m.second_change(4),"second path changed");check(not m.second_change(1),"second change once")
			check(m.second_exchange(0),"second exchange");check(not m.second_exchange(0),"second exchange once")
			check(m.state.hero.deck.size()+m.state.hero.hand.size()==30,"second conservation")
			m.finish_opening()
		check(m.state.active=="hero" or m.state.winner!=null,"AI opening returns control")
		if m.state.coin=="hero":check(m.state.hero.hand.size()==5,"first player no first draw")
		else:
			check(m.state.hero.pendingDraw==1,"second draws first turn");m.finish_draw("hero");check(m.state.hero.hand.size()==6,"second draw performed")
		check(m.state.hero.energy==1,"first own turn energy1")
	check(seen_coin.size()==2,"both start players tested")
	for side in ["hero","enemy"]:
		for c in catalog.all_cards():
			var m=battle();m.state.active=side;var op=m._other(side);m.state[side].hand=[c.id]
			unit(m,side,1);unit(m,side,3);unit(m,op,2).hp=2
			m.state[side].discard=["oa-neutral-c01"];m.state.delayed=[{"side":side,"lane":0,"due":20,"power":4}]
			var targets=m.legal_targets(side,0);check(not targets.is_empty(),"card has actual target "+c.id)
			if targets.is_empty():continue
			check(m.play(side,0,targets[0]),"all cards execute "+side+c.id)
			check(m.state[side].energy==20-int(c.cost),"actual card price "+c.id)
			if c.kind=="relic":check(m.activate_relic(side),"relic activation "+c.id);check(not m.activate_relic(side),"relic once "+c.id)
	var m=battle();m.state.hero.hand=["oa-neutral-c01","oa-neutral-c01"]
	check(m.play("hero",0,2),"origin summon");check(m.state.hero.lanes[2].ward==1,"unit origin shield once")
	m.state.hero.lanes[2]=null;m.play("hero",0,2);check(m.state.hero.lanes[2].ward==0,"origin not repeated")
	m=battle();m.state.hero.turns=7;m.begin_turn("hero");check(m.state.hero.energy==8,"energy curve cap8")
	m.state.hero.turns=20;m.state.hero.phase="main";m.begin_turn("hero");check(m.state.hero.energy==8,"energy stays8")
	for count in [10,25,50,100]:
		m=battle();m.state.enemy.ward=1000;m.events.clear()
		check(m.enqueue({"type":"echo","side":"hero","remaining":count}),"finite chain "+str(count))
		var echoes=0
		for e in m.events:
			if e.kind=="echo":echoes+=1
		check(echoes==count and m.state.enemy.ward==1000-count,"all triggers in order "+str(count))
	var broken=preload("res://tests/alpha_cycle_model.gd").new();broken.state=battle().state.duplicate(true)
	check(not broken.enqueue({"type":"echo","side":"hero","remaining":2}),"broken free cycle rejected")
	check(not broken.state.error.is_empty() and not broken.execute("endTurn",["hero"]).ok,"cycle explicit error and lock")
	m=battle();bind(m);m.state.enemy.hp=1000;m.state.active="enemy";m.state.round=12;m.state.enemy.hand=[];m.state.enemy.deck=[]
	check(m.end_turn("enemy"),"opponent full reaction turn")
	check(m.state.winner=="hero" and m.events[-1].kind=="convergence_win","convergence only owner next begin")
	m=battle();bind(m);m.state.hero.hp=0;m.state.active="hero";m.begin_turn("hero");check(m.state.winner=="enemy","HP win before convergence")
	m=battle();bind(m);m.state.hero.hp=0;m.state.enemy.hp=0;m.begin_turn("hero");check(m.state.winner=="draw","simultaneous collapse draw")
	for kind in ["stasis","move_back","return"]:
		m=battle();bind(m);m.state.active="enemy";m.state.round=12
		if kind=="stasis":m.state.enemy.hand=["oa-neutral-e03"];check(m.play("enemy",0,2),"stasis interrupts")
		elif kind=="move_back":
			m.state.enemy.hand=["oa-morph-e01","oa-morph-e01"];check(m.play("enemy",0,0),"forced displacement");check(m.play("enemy",0,1),"displacement back")
		else:
			var u=m.state.hero.lanes[2];m.hit_unit(u,100);m.state.hero.lanes[2]=null;m.enqueue({"type":"death","side":"hero","lane":2,"unit":u})
			unit(m,"hero",2)
		m.end_turn("enemy");check(m.state.winner==null and m.state.hero.convergence==null,"binding fails after "+kind)
	m=battle()
	for lane in [0,2,4]:unit(m,"hero",lane)
	m.state.round=10;var before=m.snapshot();check(not m.declare_convergence("hero",[0,2,4]),"early convergence rejected");check(before==m.snapshot(),"early reject immutable")
	m.state.round=11;m.state.hero.lanes[2].summoned=true;check(not m.declare_convergence("hero",[0,2,4]),"unready cannot control")
	m.state.hero.lanes[2].summoned=false;m.state.enemy.hp=1000;m.state.enemy.hand=[];m.state.enemy.deck=[];m.state.enemy.discard=[]
	check(m.declare_convergence("hero",[0,2,4]),"declare ends own turn");check(m.state.winner=="hero","real declaration survived full enemy turn")
	boundary_checks()
	# Local deck persistence and native replay format: original and Alpha modes.
	var session=Session.new();var saved=session.profile.duplicate(true)
	check(session.save_deck("qa:houses",catalog.deck("houses"),"alpha").ok,"deck save")
	check(Session.new().profile.decks.has("qa:houses"),"deck survives restart")
	check(not session.save_deck("qa:bad",[],"alpha").ok,"invalid save rejected")
	check(not session.save_deck("alpha:houses",catalog.deck("morph"),"alpha").ok,"wrong selected power rejected")
	session.start_match("alpha",catalog.deck("houses"),12345,2,catalog.deck("morph"))
	session.command("mulligan",[[]]);session.command("origin",[2])
	if session.model.state.stage=="second":session.command("openingDone",[])
	check(Session.replay(session.audit()).ok,"opening replay identical")
	var tampered=session.audit();tampered.commands[0].after="tamper";check(not Session.replay(tampered).ok,"tampering rejected")
	session.profile=saved;session.save_profile()
	# All four powers, every matchup, swapped seed-dependent first players, convergence on/off.
	for enabled in [true,false]:
		for hero in catalog.deck_ids():
			for enemy in catalog.deck_ids():
				for seed_value in [12345,8802026]:
					var began=Time.get_ticks_msec()
					m=Model.new();m.convergence_enabled=enabled;m.start_alpha(catalog.deck(hero),catalog.deck(enemy),seed_value);m.mulligan([]);m.choose_origin(2)
					if m.state.stage=="second":m.finish_opening()
					var turns=0
					while m.state.winner==null and m.state.error.is_empty() and turns<180:
						m.ai_turn("hero");turns+=1
					check(m.state.winner!=null and m.state.error.is_empty(),"complete Alpha AI duel "+hero+enemy+str(enabled)+str(seed_value))
					var attempts=0;var success=0;var failed=0;var chains=0;var direct=0
					var used_cards: Array=[];var energy_spent=0;var hero_damage=0;var previous: Dictionary={}
					for e in m.events:
						if e.has("card_id") and e.kind in ["summon","event","relic_installed"]:used_cards.append(e.card_id)
						if not previous.is_empty():
							for side in ["hero","enemy"]:energy_spent+=maxi(0,int(previous[side].energy)-int(e.state[side].energy)) if e.kind!="phase_end" else 0
							if e.kind=="attack":hero_damage+=maxi(0,int(previous.hero.hp)-int(e.state.hero.hp))+maxi(0,int(previous.enemy.hp)-int(e.state.enemy.hp))
						previous=e.state
						if e.kind=="convergence_declared":attempts+=1
						if e.kind=="convergence_win":success+=1
						if e.kind=="convergence_failed":failed+=1
						if e.kind=="echo":chains+=1
						if e.kind=="attack":direct+=int(e.get("amount",0))
					simulations.append({"mode":"alpha_convergence" if enabled else "alpha_collapse","hero":hero,"enemy":enemy,"seed":seed_value,"first":m.state.coin,"winner":m.state.winner,"turns":m.state.round,"convergence_attempts":attempts,"convergence_success":success,"convergence_failed":failed,"echoes":chains,"max_chain":m.longest_chain,"used_cards":used_cards,"energy_spent":energy_spent,"direct_hero_damage":hero_damage,"runtime_ms":Time.get_ticks_msec()-began,"rule_violations":0 if m.state.error.is_empty() else 1,"error":m.state.error})
	var file=FileAccess.open("res://work/alpha/simulations.json",FileAccess.WRITE);file.store_string(JSON.stringify(simulations,"  "));file.close()
	print("ALPHA RULES: %d assertions, %d failures; 55 cards / 4 starters / 64 full AI simulations" % [assertions,failures])
	root.get_node("GameAudio").request_quit(1 if failures else 0)

func boundary_checks() -> void:
	var m=battle();m.state.hero.hand=["oa-stillwatch-e01"]
	check(m.play("hero",0,2),"delay enqueued")
	check(m.state.delayed.size()==1 and m.state.delayed[0].due==13,"delay exactly two turn transitions")
	m.state.active="enemy";m.state.round=12;m.begin_turn("enemy")
	check(m.state.delayed.size()==1,"not resolved early")
	m.state.active="hero";m.state.round=13;var hp=int(m.state.enemy.hp);m.begin_turn("hero")
	check(m.state.delayed.is_empty() and m.state.enemy.hp==hp-4,"delay resolved at boundary")
	m=battle();m.state.hero.hand=["oa-ninth-e01"]
	m.state.delayed=[{"side":"hero","lane":1,"due":13,"power":4},{"side":"enemy","lane":2,"due":14,"power":5}]
	check(m.play("hero",0,4),"redirect valid")
	check(m.state.delayed[0].lane==4 and m.state.delayed[0].due==13 and m.state.delayed[1].lane==2,"redirect only oldest owned target, time preserved")
	unit(m,"enemy",4,"oa-houses-c01").hp=1;m.state.active="hero";m.state.round=13;hp=int(m.state.enemy.hp);m.begin_turn("hero")
	check(m.state.enemy.lanes[4]==null and m.state.enemy.hp==hp and m.state.enemy.resonance==2,"delayed target death/FIFO harvest, no invented overflow")
	m=battle();m.state.hero.hand=["oa-neutral-r01","oa-neutral-r02"]
	check(m.play("hero",0,0) and m.activate_relic("hero"),"first relic activated")
	check(m.play("hero",0,0) and m.state.hero.discard.has("oa-neutral-r01"),"relic replaces, old goes to discard")
	var before=m.snapshot();check(not m.activate_relic("hero") and before==m.snapshot(),"replacement cannot reset per-player use flag")
	m.begin_turn("hero");m.finish_draw("hero");check(m.activate_relic("hero"),"relic refresh next own turn")
	m=battle();var u=unit(m,"hero",1);u.atk=2;m.state.hero.hand=["oa-neutral-e04","oa-neutral-e04"]
	check(m.play("hero",0,1) and m.play("hero",0,1),"two paid additional attacks")
	m.attack_phase("hero");check(m.state.enemy.hp==24 and u.extra_attacks==0,"three attacks and no retained extras")
	m=battle();u=unit(m,"hero",1);u.summoned=true;m.state.hero.hand=["oa-neutral-e04"]
	before=m.snapshot();check(not m.play("hero",0,1) and before==m.snapshot(),"surge cannot ready waiting unit")
	u=unit(m,"hero",1,"oa-morph-c01");u.summoned=true
	check(m.can_fight("hero",1) and m.controlled("hero",1),"haste is combat capable immediately")
	check(m.play("hero",0,1),"surge legal on hasty unit")
	m=battle();bind(m);unit(m,"enemy",0);m._refresh_bindings()
	check(not m.state.hero.convergence.broken,"temporary contest evaluated at next boundary, unit binding preserved")
	m.state.active="enemy";m.state.round=12;m.end_turn("enemy")
	check(m.state.winner==null and m.state.hero.convergence==null,"remaining contest defeats convergence")
	m=battle();m.state.hero.hand=["oa-neutral-c01"];m.catalog.cards["oa-neutral-c01"].effect="unimplemented"
	before=m.snapshot();check(not m.play("hero",0,0) and before==m.snapshot(),"unknown creature effect rejected")
	for event in [{"type":"death","side":"hero","lane":-1},{"type":"summon","side":"hero","lane":0,"card_id":"unknown"},{"type":"death","side":"hero","lane":1,"unit":{"id":"unknown","hp":0}}]:
		before=m.snapshot();check(not m.enqueue(event) and before==m.snapshot(),"malformed effect queue rejected atomically")
	m=battle();m.state.hero.hand=["oa-stillwatch-e01"];m.state.enemy.hp=1;m.play("hero",0,0);bind(m)
	m.state.active="hero";m.state.round=13;m.begin_turn("hero")
	check(m.state.winner=="hero" and m.events[-1].kind=="result","delayed HP victory takes priority over convergence presentation")
