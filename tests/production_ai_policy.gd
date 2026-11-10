extends SceneTree
const Alpha = preload("res://scripts/alpha/model.gd")
const Policy = preload("res://scripts/production/ai_policy.gd")
var assertions := 0
var failures := 0
class PolicyModel extends Alpha:
	var policy = Policy.new()
	func ai_turn(side: String) -> void: policy.take_turn(self,side)
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)
func fixture(side := "hero"):
	var m = PolicyModel.new()
	m.start_alpha(m.catalog.deck("houses"),m.catalog.deck("stillwatch"),12,5)
	m.state.stage="battle";m.state.active=side;m.state.coin=side;m.state.round=13
	m.state.origins={"hero":2,"enemy":2}
	for name in ["hero","enemy"]:
		m.state[name].phase="main";m.state[name].energy=8;m.state[name].resonance=0;m.state[name].hand=[];m.state[name].lanes=[null,null,null,null,null]
	return m
func unit(m, side: String, id: String, lane: int) -> Dictionary:
	var u: Dictionary = m.make_unit(side,m.catalog.card(id),lane)
	u.summoned=false
	m.state[side].lanes[lane]=u
	return u
func test_choices() -> void:
	for side in ["hero","enemy"]:
		var m=fixture(side)
		var other: String=m._other(side)
		m.state[side].hand=["oa-neutral-e01","oa-neutral-c02"]
		m.state[other].hp=1
		var before: Dictionary=m.snapshot()
		var best: Dictionary=m.policy.choose_play(m,side)
		check(best.card_id=="oa-neutral-e01","lethal native bolt prioritized "+side)
		check(before==m.snapshot(),"choice evaluation is immutable "+side)
		var generic: Dictionary={"id":"fixture-policy-damage","kind":"event","cost":1,"abilities":[{"mode":"triggered","trigger":"on_play","effect":"deal_damage","target":"opposite_enemy_unit","params":{"amount":3}}]}
		check(m.policy.card_score(m,side,generic,0)<1.0,"empty unit-only target is not scored as hero lethal "+side)
		generic.abilities[0].target="enemy_hero"
		check(m.policy.card_score(m,side,generic,0)>100.0,"explicit generic hero lethal recognized "+side)
		generic.abilities[0].target="own_hero"
		check(m.policy.card_score(m,side,generic,0)<0.0,"self-damage is not confused with enemy damage "+side)
		# The policy may read only opponent public values. Unseen card identities
		# and their ordering cannot affect this decision.
		m.state[other].hand=["NOT_A_REAL_CARD"]
		m.state[other].deck=["NOT_A_REAL_CARD","UNKNOWN"]
		check(best==m.policy.choose_play(m,side),"no hidden opponent card identity dependence "+side)
		m=fixture(side)
		m.state[side].hand=["oa-neutral-c02"]
		unit(m,other,"oa-neutral-c02",1)
		unit(m,other,"oa-neutral-c02",2)
		unit(m,other,"oa-neutral-c02",3)
		m.state[other].convergence={"lanes":[1,2,3],"uids":[1,2,3],"broken":false}
		best=m.policy.choose_play(m,side)
		check(best.lane in [1,2,3],"blocks prepared convergence lane "+side)
		m=fixture(side)
		var heal: Dictionary={}
		for c in m.catalog.all_cards():
			if c.kind=="event" and c.effect=="heal":heal=c;break
		check(not heal.is_empty(),"native heal exists")
		if not heal.is_empty():
			check(m.policy.card_score(m,side,heal,0)<0,"does not waste heal at full HP "+side)
			m.state[side].hp=5
			check(m.policy.card_score(m,side,heal,0)>0,"values emergency heal "+side)
		m=fixture(side)
		var u:=unit(m,side,"oa-neutral-c07",0)
		u.atk=6
		unit(m,other,"oa-neutral-c02",0)
		check(m.policy._lane_value(m,side,0,1)>m.policy._lane_value(m,side,0,0),"values free-path hero attack "+side)
		m.state[side].resonance=3
		m.policy._try_tactic(m,side)
		check(m.state[side].lanes[1]!=null and m.state[side].lanes[0]==null,"real tactical move seeks free path "+side)
		check(m.state[side].resonance==0,"movement pays original resonance cost "+side)
		check(m.state[side].lanes[1]==u,"movement retains unit identity "+side)
func complete(a: String,b: String,seed_value: int,difficulty: int):
	var m=PolicyModel.new()
	m.policy.record_decisions=true
	check(m.start_alpha(m.catalog.deck(a),m.catalog.deck(b),seed_value,difficulty),"legal native start")
	var exchange: Array=[]
	for i in m.state.hero.hand.size():
		if m.catalog.card(m.state.hero.hand[i]).cost>3:exchange.append(i)
	check(m.mulligan(exchange),"mulligan")
	check(m.choose_origin(2),"origin")
	if m.state.stage=="second":check(m.finish_opening(),"opening completed")
	var calls:=0
	while m.state.winner==null and m.state.error.is_empty() and calls<400:
		m.ai_turn("hero");calls+=1
	check(m.state.error.is_empty(),"AI complete duel no engine errors "+a+b+str(seed_value))
	check(m.state.winner!=null,"AI complete duel result "+a+b+str(seed_value))
	check(m.policy.action_limit_reached==0,"no runaway AI pass "+a+b+str(seed_value))
	return m
func run() -> void:
	test_choices()
	var initial: Dictionary={}
	for difficulty in [1,2,5]:
		var same=PolicyModel.new()
		check(same.start_alpha(same.catalog.deck("houses"),same.catalog.deck("stillwatch"),9102,difficulty),"same-seed fair start")
		var snapshot: Dictionary=same.snapshot()
		snapshot.erase("level")
		if initial.is_empty():initial=snapshot
		else:check(initial==snapshot,"difficulty supplies no rule/resource/card advantage "+str(difficulty))
	for difficulty in [1,2,5]:
		for a in ["houses","stillwatch","morph","ninth"]:
			complete(a,"ninth",1204,difficulty)
	for a in ["houses","stillwatch","morph","ninth"]:
		var first=complete(a,"morph",781,5)
		var replay=complete(a,"morph",781,5)
		check(first.snapshot()==replay.snapshot(),"deterministic AI final state "+a)
		check(first.events==replay.events,"deterministic AI event sequence "+a)
		check(first.policy.decisions==replay.policy.decisions,"deterministic AI decisions "+a)
	print("PRODUCTION AI POLICY: ",assertions," assertions; ",failures," failures; 20 actual native55-card games")
	quit(0 if failures==0 else 1)
