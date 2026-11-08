extends Node3D
## NACHTSIEGEL mobile arena, milestone 1.
## Original 2.5D visual prototype with local combat; NOT a verified port of the legacy rules.
const CardVignette = preload("res://scripts/card_vignette.gd")
const RitualBoard = preload("res://scripts/ritual_board.gd")
const CardBezel = preload("res://scripts/card_bezel.gd")
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
var unit_nodes: Array = []
var ui_layer: CanvasLayer
var root_ui: Control
var title_label: Label
var status_label: Label
var message_label: Label
var hand_row: HBoxContainer
var lane_buttons: Array[Button] = []
var end_button: Button
var landscape_panel: ColorRect
var card_buttons: Array[Button] = []
var camera: Camera3D
var world_root: Node3D

func _ready() -> void:
	rng.seed = 8802026
	for i in 25:
		deck.append(i % CARD_POOL.size())
	deck.shuffle()
	for i in 4:
		_draw_card()
	_build_ui()
	_refresh()
	call_deferred("_start_world")

func _start_world() -> void:
	# The 3D test arena is deliberately retired. The game now uses a
	# deterministic, iPhone-friendly 2D card-table presentation.
	_announce("Wähle eine Karte und anschließend einen der fünf Pfade.")

func _mesh_box(pos:Vector3, dims:Vector3, color:Color, parent:Node3D) -> void:
	var mesh := BoxMesh.new()
	mesh.size = dims
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.2
	mat.roughness = 0.55
	mesh.material = mat
	var item := MeshInstance3D.new()
	item.mesh = mesh
	item.position = pos
	parent.add_child(item)

func _create_creature(data:Dictionary, lane:int, enemy:bool) -> Node3D:
	var holder := Node3D.new()
	holder.position = Vector3(float(lane-2)*2.35,0.28,-2.35 if enemy else 2.35)
	world_root.add_child(holder)
	var pedestal := CylinderMesh.new()
	pedestal.top_radius = 0.62
	pedestal.bottom_radius = 0.72
	pedestal.height = 0.23
	var base := MeshInstance3D.new()
	base.mesh = pedestal
	base.position.y = 0.15
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color("#8b4b62") if enemy else Color("#4c8890")
	base.material_override = base_mat
	holder.add_child(base)
	var tint := Color(str(data["tint"]))
	var name := str(data["name"])
	var body_mesh: PrimitiveMesh
	if name == "Nebelqualle" or name == "Gezeitenhüter":
		var dome := SphereMesh.new()
		dome.radius = 0.64
		dome.height = 0.75
		body_mesh = dome
	elif name == "Dornenwolf" or name == "Schattenwolf":
		var beast := CapsuleMesh.new()
		beast.radius = 0.38
		beast.height = 1.38
		body_mesh = beast
	else:
		var knight := CylinderMesh.new()
		knight.top_radius = 0.28
		knight.bottom_radius = 0.53
		knight.height = 1.25
		body_mesh = knight
	var body_instance := MeshInstance3D.new()
	body_instance.mesh = body_mesh
	body_instance.position.y = 0.93
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.metallic = 0.42
	mat.roughness = 0.33
	body_instance.material_override = mat
	holder.add_child(body_instance)
	if name == "Dornenwolf" or name == "Schattenwolf":
		for side in [-1,1]:
			var ear := CylinderMesh.new()
			ear.top_radius = 0.01
			ear.bottom_radius = 0.22
			ear.height = 0.67
			var ear_node := MeshInstance3D.new()
			ear_node.mesh = ear
			ear_node.position = Vector3(float(side)*0.26,1.72,0)
			ear_node.material_override = mat
			holder.add_child(ear_node)
	elif name == "Nebelqualle" or name == "Gezeitenhüter":
		for j in 5:
			var tendril := CylinderMesh.new()
			tendril.top_radius = 0.045
			tendril.bottom_radius = 0.07
			tendril.height = 0.66
			var strand := MeshInstance3D.new()
			strand.mesh = tendril
			strand.position = Vector3((float(j)-2.0)*0.20,0.36,0)
			strand.material_override = mat
			holder.add_child(strand)
	else:
		var helm := SphereMesh.new()
		helm.radius = 0.31
		helm.height = 0.53
		var helm_node := MeshInstance3D.new()
		helm_node.mesh = helm
		helm_node.position.y = 1.78
		helm_node.material_override = mat
		holder.add_child(helm_node)
	var eye := MeshInstance3D.new()
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.12
	eye_mesh.height = 0.24
	eye.mesh = eye_mesh
	eye.position = Vector3(0,1.13,0.43)
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color("#ffe6aa")
	eye_mat.emission_enabled = true
	eye_mat.emission = tint
	eye.material_override = eye_mat
	holder.add_child(eye)
	var text3d := Label3D.new()
	text3d.text = "%d / %d" % [int(data["attack"]),int(data["hp"])]
	text3d.font_size = 45
	text3d.pixel_size = 0.008
	text3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	text3d.position = Vector3(0,2.23,0)
	holder.add_child(text3d)
	holder.scale = Vector3(0.05,0.05,0.05)
	holder.create_tween().tween_property(holder,"scale",Vector3.ONE,0.27).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return holder

func _refresh_units() -> void:
	# Lane cards are updated in _refresh; no primitive 3D creatures.
	pass

func _panel(color:Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("#a7895e")
	style.shadow_color = Color(0.02,0.01,0.03,0.55)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0,2)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

func _slot_style(friendly:bool, active:bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#263e42") if friendly else Color("#412b38")
	if active:
		style.bg_color = Color("#36585b")
	style.border_color = Color("#a99169") if active else Color("#76604f")
	style.set_border_width_all(2)
	style.border_width_top = 4
	style.set_corner_radius_all(4)
	style.shadow_color = Color(0.01,0.01,0.02,0.45)
	style.shadow_size = 4
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

func _card_style(accent:Color, active:bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#2b2430")
	style.border_color = Color("#ead3a0") if active else accent.lightened(0.18)
	style.set_border_width_all(3 if active else 2)
	style.set_corner_radius_all(7)
	style.shadow_color = Color(0,0,0,0.6)
	style.shadow_size = 7
	style.shadow_offset = Vector2(0,3)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style

func _label(value:String,size:int) -> Label:
	var item := Label.new()
	item.text = value
	item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item.add_theme_font_size_override("font_size",size)
	item.add_theme_color_override("font_color",Color("#f4e8d8"))
	return item

func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	root_ui = Control.new()
	ui_layer.add_child(root_ui)
	root_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = Color("#100e19")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(backdrop)
	var frame := PanelContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 16
	frame.offset_right = -16
	frame.offset_top = 12
	frame.offset_bottom = -12
	frame.add_theme_stylebox_override("panel", _panel(Color("#241b2b")))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(frame)
	var header := PanelContainer.new()
	root_ui.add_child(header)
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 28
	header.offset_right = -28
	header.offset_top = 20
	header.offset_bottom = 94
	header.add_theme_stylebox_override("panel", _panel(Color("#17131f")))
	var header_column := VBoxContainer.new()
	header.add_child(header_column)
	title_label = _label("N A C H T S I E G E L    /    OBSIDIAN-ARENA",25)
	header_column.add_child(title_label)
	status_label = _label("",20)
	header_column.add_child(status_label)
	var board := PanelContainer.new()
	root_ui.add_child(board)
	board.anchor_left = 0.5
	board.anchor_right = 0.5
	board.offset_left = -508
	board.offset_right = 508
	board.offset_top = 104
	board.offset_bottom = 454
	board.add_theme_stylebox_override("panel",_panel(Color("#211d2a")))
	var board_art := RitualBoard.new()
	board_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(board_art)
	var board_col := VBoxContainer.new()
	board_col.add_theme_constant_override("separation",9)
	board_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(board_col)
	var opponent := _label("G E G N E R",17)
	opponent.add_theme_color_override("font_color",Color("#e9a7a2"))
	board_col.add_child(opponent)
	var enemy_row := HBoxContainer.new()
	enemy_row.alignment = BoxContainer.ALIGNMENT_CENTER
	enemy_row.add_theme_constant_override("separation",9)
	board_col.add_child(enemy_row)
	for i in LANES:
		var enemy_slot := PanelContainer.new()
		enemy_slot.custom_minimum_size = Vector2(185,111)
		enemy_slot.add_theme_stylebox_override("panel",_slot_style(false))
		enemy_slot.modulate.a = 0.91
		enemy_row.add_child(enemy_slot)
		var enemy_label := _label("LEER",16)
		enemy_label.name = "Enemy"
		enemy_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		enemy_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		enemy_slot.add_child(enemy_label)
	var divider_label := _label("I     ·     II     ·     III     ·     IV     ·     V",17)
	divider_label.add_theme_color_override("font_color",Color("#e8c48c"))
	board_col.add_child(divider_label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation",9)
	board_col.add_child(row)
	for i in LANES:
		var lane := Button.new()
		lane.custom_minimum_size = Vector2(185,115)
		lane.add_theme_font_size_override("font_size",17)
		lane.add_theme_stylebox_override("normal",_slot_style(true))
		lane.add_theme_stylebox_override("hover",_slot_style(true,true))
		lane.add_theme_stylebox_override("pressed",_slot_style(true,true))
		lane.pressed.connect(_choose_lane.bind(i))
		row.add_child(lane)
		lane_buttons.append(lane)
	var bottom := PanelContainer.new()
	root_ui.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 28
	bottom.offset_right = -28
	bottom.offset_top = -244
	bottom.offset_bottom = -20
	bottom.add_theme_stylebox_override("panel",_panel(Color("#17131f")))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",5)
	bottom.add_child(column)
	message_label = _label("",17)
	column.add_child(message_label)
	hand_row = HBoxContainer.new()
	hand_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_row.add_theme_constant_override("separation",9)
	column.add_child(hand_row)
	end_button = Button.new()
	end_button.text = "ZUG BEENDEN"
	end_button.custom_minimum_size = Vector2(260,35)
	end_button.add_theme_font_size_override("font_size",17)
	end_button.add_theme_stylebox_override("normal",_panel(Color("#65415a")))
	end_button.pressed.connect(_end_turn)
	column.add_child(end_button)
	landscape_panel = ColorRect.new()
	landscape_panel.color = Color("#100c18")
	landscape_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root_ui.add_child(landscape_panel)
	landscape_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var landscape_text := _label("NACHTSIEGEL\nBitte iPhone ins Querformat drehen",32)
	landscape_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	landscape_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	landscape_panel.add_child(landscape_text)
	get_viewport().size_changed.connect(_update_orientation)
	_update_orientation()

func _update_orientation() -> void:
	if landscape_panel == null:
		return
	var size_now := get_viewport().get_visible_rect().size
	landscape_panel.visible = size_now.y > size_now.x

func _draw_card() -> void:
	if deck.is_empty() or hand.size() >= 6:
		return
	hand.append(deck.pop_back())

func _card_button(index:int) -> Button:
	var data:Dictionary = CARD_POOL[int(hand[index])]
	var button := Button.new()
	button.custom_minimum_size = Vector2(174,138)
	button.text = ""
	button.disabled = finished or energy < int(data["cost"])
	var accent := Color(str(data["tint"]))
	button.add_theme_stylebox_override("normal",_card_style(accent, index == selected))
	button.add_theme_stylebox_override("hover",_card_style(accent,true))
	button.add_theme_stylebox_override("pressed",_card_style(accent,true))
	if index == selected:
		button.add_theme_stylebox_override("normal",_card_style(accent,true))
	var bezel := CardBezel.new()
	bezel.accent = accent
	bezel.selected = index == selected
	button.add_child(bezel)
	bezel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_theme_constant_override("separation",1)
	var heading := _label("%d ENERGIE    /    %s" % [int(data["cost"]),str(data["sigil"])],15)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(heading)
	var art := CardVignette.new()
	art.accent = accent
	art.archetype = str(data["sigil"])
	art.custom_minimum_size = Vector2(0,70)
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(art)
	var name_label := _label(str(data["name"]),17)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(name_label)
	var stats := "ZAUBER  /  %d SCHADEN" % int(data["attack"]) if str(data["kind"]) == "spell" else "ANGRIFF %d   /   LEBEN %d" % [int(data["attack"]),int(data["hp"])]
	var stats_label := _label(stats,15)
	stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(stats_label)
	button.pressed.connect(_select_card.bind(index))
	return button

func _refresh() -> void:
	if status_label == null:
		return
	status_label.text = "DU  %d LP    ·    ENERGIE  %d    ·    RUNDE  %d    ·    BESCHWÖRUNGEN  %d/2    ·    GEGNER  %d LP" % [player_hp,energy,round_number,summons,foe_hp]
	for i in LANES:
		var ally_str := "LEER" if allies[i] == null else "%s\nANG %d   /   LP %d" % [str(allies[i]["name"]),int(allies[i]["attack"]),int(allies[i]["hp"])]
		lane_buttons[i].text = "PFAD %d\n%s" % [i+1,ally_str]
		var enemy_label:Label = lane_buttons[i].get_parent().get_parent().get_child(1).get_child(i).get_node("Enemy")
		enemy_label.text = "LEER" if foes[i] == null else "%s\nANG %d   /   LP %d" % [str(foes[i]["name"]),int(foes[i]["attack"]),int(foes[i]["hp"])]
	for child in hand_row.get_children():
		hand_row.remove_child(child)
		child.queue_free()
	for i in hand.size():
		hand_row.add_child(_card_button(i))
	end_button.disabled = finished

func _announce(value:String) -> void:
	if message_label != null:
		message_label.text = value

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
