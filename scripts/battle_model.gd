extends RefCounted
## Pure local battle state and commands. No scene, filesystem, UI or network dependencies.
const LANES := 5
const MAX_HP := 35
const CARD_POOL = preload("res://data/card_definitions.gd").POOL
var rng := RandomNumberGenerator.new()
var deck: Array = []
var hand: Array = []
var allies: Array = [null,null,null,null,null]
var foes: Array = [null,null,null,null,null]
var player_hp := 35
var foe_hp := 35
var energy := 3
var round_number := 1
var summons := 0
var selected := -1
var finished := false
var streak := 0
var result := ""
var ai_profile := "standard"
func start(seed_value: int = 8802026, profile: String = "standard") -> void:
	deck.clear();hand.clear();allies=[null,null,null,null,null];foes=[null,null,null,null,null]
	player_hp=35;foe_hp=35;energy=3;round_number=1;summons=0;selected=-1;finished=false;streak=0;result=""
	rng.seed = seed_value
	ai_profile = profile
	for i in 25: deck.append(i % CARD_POOL.size())
	for i in range(deck.size()-1,0,-1):
		var j = rng.randi_range(0,i)
		var swap = deck[i]; deck[i] = deck[j]; deck[j] = swap
	for i in 4: draw_card()
func draw_card() -> void:
	if not deck.is_empty() and hand.size()<6: hand.append(deck.pop_back())
func play(lane: int) -> Dictionary:
	if finished or lane<0 or lane>=5 or selected<0 or selected>=hand.size(): return {"ok":false,"reason":"Wähle zuerst eine Handkarte"}
	var card: Dictionary = CARD_POOL[int(hand[selected])].duplicate(true)
	if int(card.cost)>energy: return {"ok":false,"reason":"Nicht genügend Energie"}
	var spell = card.kind=="spell"
	if not spell:
		if summons>=2: return {"ok":false,"reason":"Limit: 2 Beschwörungen/Runde"}
		if allies[lane]!=null: return {"ok":false,"reason":"Dieses eigene Feld ist besetzt"}
		allies[lane] = card; summons += 1
	else:
		if foes[lane]==null: return {"ok":false,"reason":"Wähle eine gegnerische Kreatur"}
		foes[lane].hp = int(foes[lane].hp)-int(card.attack)
		if int(foes[lane].hp)<=0: foes[lane]=null
	energy -= int(card.cost); hand.remove_at(selected); selected=-1
	return {"ok":true,"spell":spell,"message":("Funkenstoß · −3 Leben auf Pfad %d" % (lane+1)) if spell else ("%s · Pfad %d" % [card.name,lane+1])}
func finish(value: String) -> void:
	finished = true; result = value
func choose_enemy_lane(options: Array) -> int:
	if ai_profile in ["tactical","challenging"] and rng.randf() < (.75 if ai_profile=="challenging" else .65):
		var best = -1; var threat = -1
		for lane in options:
			if allies[lane]!=null and int(allies[lane].attack)>threat: best=lane; threat=int(allies[lane].attack)
		if best>=0: return best
	return int(options[rng.randi_range(0,options.size()-1)])
func choose_enemy_card(lane: int) -> int:
	if ai_profile=="easy": return rng.randi_range(0,2)
	if ai_profile=="standard": return rng.randi_range(0,5)
	var best = 0; var score = -1
	for sample in 2:
		var i=rng.randi_range(0,5)
		var card: Dictionary = CARD_POOL[i]
		var value = int(card.hp)*2+int(card.attack) if ai_profile=="defensive" else int(card.attack)*2+int(card.hp)
		if ai_profile=="tactical" and allies[lane]!=null and int(card.hp)>int(allies[lane].attack): value+=8
		if ai_profile=="challenging" and allies[lane]!=null and int(card.attack)>=int(allies[lane].hp): value+=12
		if value>score: score=value; best=i
	return best
func combat_phase(attacker:Array, defender:Array, attacking_player:bool) -> void:
	var damage: Array = [0,0,0,0,0]
	for i in LANES:
		if attacker[i] == null:
			continue
		if defender[i] != null:
			damage[i] = int(attacker[i]["attack"])
		else:
			if attacking_player:
				foe_hp = max(0,foe_hp-int(attacker[i]["attack"]))
			else:
				player_hp = max(0,player_hp-int(attacker[i]["attack"]))
	for i in LANES:
		if damage[i] > 0 and defender[i] != null:
			defender[i]["hp"] = int(defender[i]["hp"]) - int(damage[i])
			if int(defender[i]["hp"]) <= 0:
				defender[i] = null

func resolve_turn() -> void:
	if finished:
		return
	result = ""
	combat_phase(allies,foes,true)
	if foe_hp <= 0:
		finish("SIEG · Der gegnerische Held fällt!")
		return
	var free_paths := 0
	for i in LANES:
		if allies[i] != null and foes[i] == null:
			free_paths += 1
	streak = streak + 1 if free_paths >= 3 else 0
	if streak >= 2:
		finish("SIEG · Drei Pfade zweimal gehalten!")
		return
	# Enemy summons into a free enemy field.
	var options: Array = []
	for i in LANES:
		if foes[i] == null:
			options.append(i)
	if not options.is_empty():
		var lane: int = choose_enemy_lane(options)
		foes[lane] = CARD_POOL[choose_enemy_card(lane)].duplicate(true)
	combat_phase(foes,allies,false)
	if player_hp <= 0:
		finish("NIEDERLAGE · Dein Held ist gefallen.")
		return
	round_number += 1
	energy = min(10,2+round_number)
	summons = 0
	selected = -1
	draw_card()

