extends Node3D
## NACHTSIEGEL: original landscape reliquary arena.
## Original 2.5D visual prototype with local combat; NOT a verified port of the legacy rules.
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
var ui_layer: CanvasLayer
var root_ui: Control
var status_label: Label
var message_label: Label
var hand_row: Control
var lane_buttons: Array[Button] = []
var hero_player: Label
var hero_enemy: Label
var energy_label: Label
var round_label: Label
var end_button: Button
var landscape_panel: ColorRect
var card_buttons: Array[Button] = []

func _ready() -> void:
	rng.seed = 8802026
	for i in 25:
		deck.append(i % CARD_POOL.size())
	for i in range(deck.size()-1,0,-1):
		var j = rng.randi_range(0,i)
		var swap = deck[i]
		deck[i] = deck[j]
		deck[j] = swap
	for i in 4:
		_draw_card()
	_build_ui()
	_refresh()
	call_deferred("_introduce")

func _introduce() -> void:
	_announce("Wähle eine Karte und anschließend einen der fünf Pfade.")

func _label(value:String,size:int) -> Label:
	var item := Label.new()
	item.text = value
	item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item.add_theme_font_size_override("font_size",size)
	item.add_theme_color_override("font_color",Color("#f4e8d8"))
	return item

func _gold_panel(base:Color, rim:Color = Color("#a98452")) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = base
	st.border_color = rim
	st.set_border_width_all(2)
	st.border_width_top = 4
	st.set_corner_radius_all(12)
	st.shadow_color = Color(0,0,0,0.7)
	st.shadow_size = 9
	st.content_margin_left = 8
	st.content_margin_right = 8
	st.content_margin_top = 5
	st.content_margin_bottom = 5
	return st

const CardFace = preload("res://scripts/card_face.gd")
const Atmosphere = preload("res://scripts/atmosphere.gd")
const RitualButton = preload("res://scripts/ritual_button.gd")
const SigilSlot = preload("res://scripts/sigil_slot.gd")
const RitualHud = preload("res://scripts/ritual_hud.gd")
const RitualFx = preload("res://scripts/ritual_fx.gd")
const DISPLAY_FONT = preload("res://assets/fonts/Cinzel.ttf")
const BODY_FONT = preload("res://assets/fonts/Body.ttf")
var lane_faces: Array = []
var foe_faces: Array = []
var info_label: Label
var detail_button: Button
var modal: Control
var busy := false
var restart_button: Button
var energy_gems: Label
var hud_art: Control
var hero_medallions: Array = []
var foe_wells: Array = []

func _put(node: Control, rect: Rect2, parent: Node = null) -> void:
	(parent if parent != null else root_ui).add_child(node)
	node.position = rect.position
	node.size = rect.size

func _caption(value: String, rect: Rect2, font_size: int = 18, color: Color = Color("#c4b491"), serif: bool = false) -> Label:
	var label = _label(value, font_size)
	label.add_theme_font_override("font", DISPLAY_FONT if serif else BODY_FONT)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_put(label,rect)
	return label

func _action(value: String, rect: Rect2, callback: Callable) -> Button:
	var button = RitualButton.new()
	button.caption = value
	button.emphasis = value.begins_with("ZUG") or value.begins_with("NEUES")
	button.pressed.connect(callback)
	_put(button,rect)
	return button

func _art(index: int) -> AtlasTexture:
	var texture = AtlasTexture.new()
	texture.atlas = preload("res://assets/art/atlas.png")
	var cell = texture.atlas.get_size()/3.0
	texture.region = Rect2(Vector2(index%3,index/3)*cell,cell)
	return texture

func _face(data: Dictionary, rect: Rect2, index: int, small: bool = false) -> Button:
	var face = CardFace.new()
	face.data = data
	face.art = _art(index)
	face.compact = small
	_put(face,rect)
	return face

func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	root_ui = Control.new()
	ui_layer.add_child(root_ui)
	root_ui.size = Vector2(1600,900)
	var theme = Theme.new()
	theme.default_font = BODY_FONT
	root_ui.theme = theme
	var backdrop = TextureRect.new()
	backdrop.texture = preload("res://assets/art/arena_painted.png")
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var light = ShaderMaterial.new()
	light.shader = preload("res://assets/shaders/arena_light.gdshader")
	backdrop.material = light
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_put(backdrop,Rect2(0,0,1600,900))
	_caption("N A C H T S I E G E L",Rect2(425,12,750,54),36,Color("#e7d4a9"),true)
	_caption("D A S   R I T U A L   D E R   F Ü N F   P F A D E",Rect2(480,64,640,26),11)
	_caption("D U E L L   I M   M O N D H E I L I G T U M",Rect2(25,25,315,35),10)
	hud_art = RitualHud.new()
	_put(hud_art,Rect2(0,0,1600,900))
	_action("?  SPIELHILFE",Rect2(1370,0,210,103),_show_help)
	# Paired sculpted reliquaries sit within the five carved channels.
	for i in LANES:
		var x = 355.0+i*180.0
		var enemy_well = SigilSlot.new()
		enemy_well.enemy = true
		enemy_well.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_put(enemy_well,Rect2(x,145,160,194))
		foe_wells.append(enemy_well)
		var foe = _face({},Rect2(x,145,160,194),0,true)
		foe.visible = false
		foe.pressed.connect(_choose_lane.bind(i))
		foe_faces.append(foe)
		var target = SigilSlot.new()
		target.pressed.connect(_choose_lane.bind(i))
		_put(target,Rect2(x-2,397,164,200))
		lane_buttons.append(target)
		var ally = _face({},Rect2(x,399,160,194),0,true)
		ally.visible = false
		ally.pressed.connect(_choose_lane.bind(i))
		lane_faces.append(ally)
		_caption(["I","II","III","IV","V"][i],Rect2(x+52,343,56,30),17,Color("#e1c893"),true)
	# Tall hero medallions with distinct identities.
	var enemy = _face({"name":"Der Aschenkönig","attack":0,"hp":35,"tint":"#b46753"},Rect2(77,151,174,220),8,true)
	enemy.heroic = true
	enemy.disabled = false
	enemy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var player = _face({"name":"Die Siegelhüterin","attack":0,"hp":35,"tint":"#72beb9"},Rect2(77,426,174,220),7,true)
	hero_medallions = [player,enemy]
	player.heroic = true
	player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_enemy = _caption("35 / 35",Rect2(107,318,114,45),28,Color("#eae5d1"),true)
	hero_player = _caption("35 / 35",Rect2(107,593,114,45),28,Color("#eae5d1"),true)
	hero_enemy.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hero_player.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption("GEGNERISCHER HELD",Rect2(61,112,206,24),11)
	_caption("DEINE HELDIN",Rect2(61,389,206,24),11)
	round_label = _caption("RUNDE 01",Rect2(1370,100,210,33),18,Color("#e0cda6"),true)
	_caption("DEINE ENERGIE",Rect2(1370,139,210,26),11)
	energy_label = _caption("3 / 10",Rect2(1428,167,94,49),34,Color("#9cdcd9"),true)
	energy_gems = _caption("◆ ◆ ◆",Rect2(1370,272,210,22),15,Color("#74c5c8"))
	info_label = _caption("Ein Siegel.\nFünf Wege zum Sieg.\n\nWähle eine Handkarte,\ndann ihren Zielpfad.",Rect2(1371,303,209,117),15)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_button = _action("KARTE ANSEHEN",Rect2(1370,418,210,103),_show_card)
	detail_button.visible = false
	end_button = _action("ZUG BEENDEN  ›",Rect2(1370,530,210,103),_end_turn)
	_caption("DEINE HAND",Rect2(55,718,235,26),14,Color("#e3c998"),true)
	_caption("Illustrationen: Konzept-Platzhalter",Rect2(28,751,280,42),10,Color("#7c918f"))
	hand_row = Control.new()
	_put(hand_row,Rect2(318,655,932,235))
	message_label = _caption("",Rect2(318,612,932,31),14,Color("#bcd5ce"))
	status_label = _caption("",Rect2(1350,641,240,42),12)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	restart_button = _action("NEUES DUELL",Rect2(1370,701,210,103),func(): get_tree().reload_current_scene())
	restart_button.visible = false
	var ambience = Atmosphere.new()
	_put(ambience,Rect2(0,0,1600,900))
	landscape_panel = ColorRect.new()
	landscape_panel.color = Color("#09141e")
	landscape_panel.z_index = 200
	_put(landscape_panel,Rect2(0,0,1600,900))
	var orientation = _label("NACHTSIEGEL\n\nBitte das Gerät\nins Querformat drehen",22)
	orientation.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	orientation.mouse_filter = Control.MOUSE_FILTER_IGNORE
	landscape_panel.add_child(orientation)
	orientation.size = Vector2(1600,900)
	get_viewport().size_changed.connect(_update_orientation)
	_update_orientation()

func _update_orientation() -> void:
	var available = get_viewport().get_visible_rect().size
	var factor = minf(available.x/1600.0,available.y/900.0)
	root_ui.scale = Vector2.ONE*factor
	root_ui.position = (available-Vector2(1600,900)*factor)/2.0
	landscape_panel.top_level = true
	landscape_panel.position = Vector2.ZERO
	landscape_panel.size = available
	landscape_panel.get_child(0).size = available
	landscape_panel.visible = available.y > available.x

func _close_modal() -> void:
	if is_instance_valid(modal): modal.queue_free()
	modal = null

func _modal_shell() -> Control:
	_close_modal()
	modal = Control.new()
	modal.z_index = 100
	_put(modal,Rect2(0,0,1600,900))
	var shade = Button.new()
	shade.add_theme_stylebox_override("normal",_gold_panel(Color(0.01,0.03,0.05,0.94),Color("#82704f")))
	shade.pressed.connect(_close_modal)
	_put(shade,Rect2(0,0,1600,900),modal)
	return modal

func _show_help() -> void:
	var panel = _modal_shell()
	var text = _label("DAS RITUAL DER FÜNF PFADE\n\nKarte antippen → eigenen Pfad antippen.\nZauber treffen eine gegnerische Kreatur auf dem Zielpfad.\nMaximal zwei Beschwörungen pro Runde.\n\nZug beenden: Deine Kreaturen greifen zuerst an.\nDanach beschwört der Gegner und greift an.\nFreie Pfade verursachen Schaden am gegnerischen Helden.\n\nSieg: 35 Lebenspunkte besiegen oder drei freie Pfade\nin zwei aufeinanderfolgenden Runden kontrollieren.\n\nKosten ◆    Angriff ANG    Lebenspunkte LP\n\nTippe außerhalb des Textes, um zurückzukehren.",24)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_put(text,Rect2(280,150,1040,600),panel)
	_action_in_modal("ZURÜCK ZUM DUELL",Rect2(570,776,460,103))

func _action_in_modal(value: String, rect: Rect2) -> void:
	var button = _action(value,rect,_close_modal)
	root_ui.remove_child(button)
	modal.add_child(button)

func _show_card() -> void:
	if selected < 0 or selected >= hand.size(): return
	var data: Dictionary = CARD_POOL[int(hand[selected])]
	var panel = _modal_shell()
	var card = CardFace.new()
	card.data = data
	card.art = _art(int(hand[selected]))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_put(card,Rect2(410,160,360,510),panel)
	var text = _label("%s\n\n%d Energie\n%d Angriff · %d Lebenspunkte\n\n%s\n\nOriginale KI-Konzeptillustration\nVorläufiger Artwork-Platzhalter" % [data.name,data.cost,data.attack,data.hp,"Trifft eine gegnerische Kreatur." if data.kind == "spell" else "Beschwöre auf einem freien eigenen Pfad."],30)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_put(text,Rect2(805,145,480,550),panel)
	_action_in_modal("ZURÜCK · ZIELPFAD WÄHLEN",Rect2(565,742,470,103))

var previous_hand_count := 0

func _draw_card() -> void:
	if deck.is_empty() or hand.size() >= 6:
		return
	hand.append(deck.pop_back())

func _card_button(index:int) -> Button:
	var data: Dictionary = CARD_POOL[int(hand[index])]
	var button = CardFace.new()
	button.size = Vector2(156,212)
	button.pivot_offset = Vector2(78,200)
	button.data = data
	button.art = _art(int(hand[index]))
	button.active = index == selected
	button.disabled = finished or busy
	button.unaffordable = energy < int(data["cost"])
	button.pressed.connect(_select_card.bind(index))
	card_buttons.append(button)
	return button

func _refresh() -> void:
	if status_label == null: return
	hero_player.text = str(player_hp)
	hero_enemy.text = str(foe_hp)
	energy_label.text = str(energy)
	energy_gems.text = "%d / 10 ENERGIE" % energy
	hud_art.energy = energy
	hud_art.queue_redraw()
	round_label.text = "RUNDE %02d" % round_number
	status_label.text = "Kontrollserie %d / 2\n%d Karten im Stapel" % [streak,deck.size()]
	var selection: Dictionary = CARD_POOL[int(hand[selected])] if selected >= 0 and selected < hand.size() else {}
	for i in LANES:
		for pair in [[allies,lane_faces],[foes,foe_faces]]:
			var unit = pair[0][i]
			var face = pair[1][i]
			face.visible = unit != null
			if unit != null:
				face.data = unit
				face.art = _art(_card_index(unit))
				face.active = not selection.is_empty() and selection.kind == "spell" and pair[1] == foe_faces
				face.queue_redraw()
		lane_buttons[i].disabled = finished or busy
		lane_faces[i].disabled = finished or busy
		foe_faces[i].disabled = finished or busy
		var legal = not selection.is_empty() and selection.kind == "unit" and allies[i] == null and summons < 2 and energy >= int(selection.cost)
		lane_buttons[i].legal = legal
		lane_buttons[i].occupied = allies[i] != null
		lane_buttons[i].queue_redraw()
		foe_wells[i].occupied = foes[i] != null
		foe_wells[i].queue_redraw()
	for child in hand_row.get_children():
		hand_row.remove_child(child)
		child.queue_free()
	card_buttons.clear()
	for i in hand.size(): hand_row.add_child(_card_button(i))
	_fan_hand()
	if hand.size() > previous_hand_count:
		call_deferred("_animate_draw")
	previous_hand_count = hand.size()
	end_button.disabled = finished or busy
	end_button.caption = "PFADKAMPF …" if busy else "ZUG BEENDEN"
	end_button.queue_redraw()
	restart_button.visible = finished
	detail_button.visible = selected >= 0
	if selected >= 0 and selected < hand.size():
		var data: Dictionary = CARD_POOL[int(hand[selected])]
		info_label.text = "%s\n%d Energie · %d ANG · %d LP\n\n%s" % [data.name,data.cost,data.attack,data.hp,"Zu wenig Energie" if energy < int(data.cost) else ("Gegnerische Kreatur treffen" if data.kind == "spell" else "Freien Pfad wählen")]
	elif not finished:
		info_label.text = "DEIN ZUG\n\nWähle deinen Pfad."

func _fan_hand() -> void:
	var count = card_buttons.size()
	var span = maxf(0,count-1)*149.0+156.0
	for i in count:
		var card: Control = card_buttons[i]
		var offset = float(i)-(count-1)*.5
		card.position = Vector2((932-span)/2+i*149,absf(offset)*4)
		card.rotation_degrees = offset*2.2
		card.z_index = 20 if i == selected else i

func _animate_draw() -> void:
	if card_buttons.is_empty(): return
	var card: Control = card_buttons.back()
	var target = card.position
	card.position += Vector2(30,40)
	card.modulate.a = 0.0
	var tween = card.create_tween().set_parallel(true)
	tween.tween_property(card,"modulate:a",1.0,0.3)
	tween.tween_property(card,"position",target,0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _card_index(data: Dictionary) -> int:
	for i in CARD_POOL.size():
		if CARD_POOL[i].name == data.name: return i
	return 0

func _pulse_lane(lane: int, spell: bool) -> void:
	var face: Control = foe_faces[lane] if spell else lane_faces[lane]
	var effect = RitualFx.new()
	effect.destination = face.position+face.size/2
	effect.origin = Vector2(800,780)
	if selected >= 0 and selected < card_buttons.size():
		var card: Control = card_buttons[selected]
		effect.origin = root_ui.get_global_transform().affine_inverse()*(card.get_global_transform()*(card.size/2))
		effect.tint = Color(str(CARD_POOL[int(hand[selected])].tint))
	effect.spell = spell
	_put(effect,Rect2(0,0,1600,900))
	effect.z_index = 40
	if face.visible:
		face.pivot_offset = face.size/2
		face.scale = Vector2.ONE*0.86
		face.create_tween().tween_property(face,"scale",Vector2.ONE,0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _turn_banner() -> void:
	var banner = _caption("DEIN ZUG   ·   RUNDE %d" % round_number,Rect2(565,337,470,48),23,Color("#e4d0a5"),true)
	banner.z_index = 45
	var tween = banner.create_tween()
	tween.tween_interval(.8)
	tween.tween_property(banner,"modulate:a",0.0,.4)
	tween.tween_callback(banner.queue_free)

func _announce(value:String) -> void:
	if message_label != null:
		message_label.text = value

func _select_card(index:int) -> void:
	if finished or busy or index < 0 or index >= hand.size():
		return
	selected = -1 if selected == index else index
	var data:Dictionary = CARD_POOL[int(hand[index])]
	_announce("%s · Zielpfad wählen" % str(data["name"]) if selected >= 0 else "Auswahl aufgehoben")
	_refresh.call_deferred()
	if selected >= 0:
		call_deferred("_lift_selection")

func _lift_selection() -> void:
	if selected < 0 or selected >= card_buttons.size(): return
	var card: Control = card_buttons[selected]
	card.create_tween().tween_property(card,"position:y",card.position.y-22.0,0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _choose_lane(lane:int) -> void:
	if finished or busy or lane < 0 or lane >= LANES or selected < 0 or selected >= hand.size():
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
	_pulse_lane(lane,str(data["kind"]) == "spell")
	energy -= int(data["cost"])
	hand.remove_at(selected)
	selected = -1
	_refresh.call_deferred()

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
	if finished or busy: return
	busy = true
	_refresh()
	_announce("Die Pfade erwachen …")
	for face in lane_faces:
		if face.visible:
			var start: Vector2 = face.position
			var tween = face.create_tween()
			tween.tween_property(face,"position",start+Vector2(0,-25),0.18)
			tween.tween_property(face,"position",start,0.19)
	await get_tree().create_timer(0.4).timeout
	var previous_allies = allies.duplicate(true)
	var previous_foes = foes.duplicate(true)
	var previous_player = player_hp
	var previous_foe = foe_hp
	busy = false
	_resolve_turn()
	if not finished: _turn_banner()
	for pair in [[previous_allies,allies,lane_faces],[previous_foes,foes,foe_faces]]:
		for i in LANES:
			if pair[0][i] == null: continue
			if pair[1][i] == null:
				var ghost = _face(pair[0][i],Rect2(pair[2][i].position,pair[2][i].size),_card_index(pair[0][i]),true)
				ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var fade = ghost.create_tween().set_parallel(true)
				fade.tween_property(ghost,"modulate:a",0.0,0.4)
				fade.tween_property(ghost,"position:y",ghost.position.y+28,0.4)
				fade.chain().tween_callback(ghost.queue_free)
			elif int(pair[1][i].hp) < int(pair[0][i].hp):
				pair[2][i].modulate = Color("#f3a07d")
				pair[2][i].create_tween().tween_property(pair[2][i],"modulate",Color.WHITE,0.4)
	for pair in [[hero_player,previous_player-player_hp],[hero_enemy,previous_foe-foe_hp]]:
		if pair[1] > 0:
			var damage = _caption("−%d" % pair[1],Rect2(pair[0].position-Vector2(25,40),Vector2(164,45)),32,Color("#ffc09b"),true)
			var fade = damage.create_tween().set_parallel(true)
			fade.tween_property(damage,"position:y",damage.position.y-30,0.7)
			fade.tween_property(damage,"modulate:a",0.0,0.7)
			fade.chain().tween_callback(damage.queue_free)

func _resolve_turn() -> void:
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
	_refresh()
	_announce("Runde %d · Dein Zug. Freie Pfade: %d · Kontrollserie: %d/2" % [round_number,free_paths,streak])

func _finish(value:String) -> void:
	finished = true
	info_label.text = value
	_refresh()
	_announce(value)
