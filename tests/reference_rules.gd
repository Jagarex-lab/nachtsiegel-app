extends RefCounted
## Frozen gameplay oracle from origin/develop 0e15ac4; presentation hooks removed.
const LANES := 5
const MAX_HP := 35
const CARD_POOL := [
	{"name":"Aschenwache","cost":2,"attack":2,"hp":4,"kind":"unit","tint":"#d76e43","sigil":"ASH"},
	{"name":"Dornenwolf","cost":2,"attack":3,"hp":2,"kind":"unit","tint":"#83b27c","sigil":"THORN"},
	{"name":"Nebelqualle","cost":2,"attack":1,"hp":5,"kind":"unit","tint":"#72b9c5","sigil":"TIDE"},
	{"name":"Schattenwolf","cost":3,"attack":3,"hp":4,"kind":"unit","tint":"#a48acb","sigil":"VEIL"},
	{"name":"Glutritter","cost":4,"attack":4,"hp":5,"kind":"unit","tint":"#f1a55d","sigil":"ASH"},
	{"name":"Gezeitenhüter","cost":3,"attack":2,"hp":6,"kind":"unit","tint":"#6b9ddd","sigil":"TIDE"},
	{"name":"Funkenstoß","cost":2,"attack":3,"hp":0,"kind":"spell","tint":"#ed9165","sigil":"SPELL"}
]
var rng := RandomNumberGenerator.new()
var deck: Array = []
var hand: Array = []
var allies: Array = [null,null,null,null,null]
var foes: Array = [null,null,null,null,null]
var player_hp := MAX_HP
var foe_hp := MAX_HP
var energy := 3
var round_number := 1
var summons := 0
var selected := -1
var finished := false
var streak := 0

func _refresh() -> void: pass
func _refresh_units() -> void: pass
func _announce(_value: String) -> void: pass
func _draw_card() -> void:
	if deck.is_empty() or hand.size() >= 6:
		return
	hand.append(deck.pop_back())

func _select_card(index:int) -> void:
	if finished or index >= hand.size():
		return
	selected = index
	var data:Dictionary = CARD_POOL[int(hand[index])]
	_announce("%s gewählt · Zielpfad antippen" % str(data["name"]))
	_refresh()

func _choose_lane(lane:int) -> void:
	if finished or selected < 0 or selected >= hand.size():
		_announce("Wähle zuerst eine Karte.")
		return
	var data:Dictionary = CARD_POOL[int(hand[selected])].duplicate(true)
	if int(data["cost"]) > energy:
		_announce("Nicht genügend Energie.")
		return
	if str(data["kind"]) == "unit":
		if summons >= 2:
			_announce("Maximal zwei Beschwörungen pro Runde.")
			return
		if allies[lane] != null:
			_announce("Dein Feld ist bereits besetzt.")
			return
		allies[lane] = data
		summons += 1
		_announce("%s auf Pfad %d beschworen." % [str(data["name"]),lane+1])
	else:
		# Spells require an enemy creature. Never deal summon/spell target damage to the hero.
		if foes[lane] == null:
			_announce("Zauber benötigt eine gegnerische Kreatur als Ziel.")
			return
		foes[lane]["hp"] = int(foes[lane]["hp"]) - int(data["attack"])
		if int(foes[lane]["hp"]) <= 0:
			foes[lane] = null
		_announce("Funkenstoß trifft gegnerische Kreatur auf Pfad %d." % (lane+1))
	energy -= int(data["cost"])
	hand.remove_at(selected)
	selected = -1
	_refresh_units()
	_refresh()

func _combat_phase(attacker:Array, defender:Array, attacking_player:bool) -> void:
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

func _end_turn() -> void:
	if finished:
		return
	_combat_phase(allies,foes,true)
	if foe_hp <= 0:
		_finish("SIEG · Der gegnerische Held fällt!")
		return
	var free_paths := 0
	for i in LANES:
		if allies[i] != null and foes[i] == null:
			free_paths += 1
	streak = streak + 1 if free_paths >= 3 else 0
	if streak >= 2:
		_finish("SIEG · Drei Pfade zweimal gehalten!")
		return
	# Enemy summons into a free enemy field.
	var options: Array = []
	for i in LANES:
		if foes[i] == null:
			options.append(i)
	if not options.is_empty():
		var lane:int = int(options[rng.randi_range(0,options.size()-1)])
		foes[lane] = CARD_POOL[rng.randi_range(0,5)].duplicate(true)
	_combat_phase(foes,allies,false)
	if player_hp <= 0:
		_finish("NIEDERLAGE · Dein Held ist gefallen.")
		return
	round_number += 1
	energy = min(10,2+round_number)
	summons = 0
	selected = -1
	_draw_card()
	_refresh_units()
	_refresh()
	_announce("Runde %d · Dein Zug. Freie Pfade: %d · Kontrollserie: %d/2" % [round_number,free_paths,streak])

func _finish(value:String) -> void:
	finished = true
	_refresh_units()
	_refresh()
	_announce(value)
