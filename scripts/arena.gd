extends Node3D
## NACHTSIEGEL mobile arena, milestone 1.
## Original 2.5D visual prototype with local combat; NOT a verified port of the legacy rules.
const CardVignette = preload("res://scripts/card_vignette.gd")
const RitualTable = preload("res://scripts/ritual_table.gd")
const CreaturePortrait = preload("res://scripts/creature_portrait.gd")
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
var enemy_labels: Array[Label] = []
var enemy_portraits: Array = []
var ally_portraits: Array = []
var hero_player: Label
var hero_enemy: Label
var energy_label: Label
var round_label: Label
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
	style.bg_color = Color("#211a23")
	style.border_color = Color("#ead3a0") if active else accent.lightened(0.18)
	style.set_border_width_all(4 if active else 3)
	style.border_width_top = 7
	style.border_width_bottom = 5
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0,0,0,0.6)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0,3)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style

func _arena_frame_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#17121d")
	style.border_color = Color("#98714a")
	style.set_border_width_all(2)
	style.border_width_top = 4
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0,0,0,0.8)
	style.shadow_size = 12
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _board_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0,Color("#31212b"))
	gradient.set_color(1,Color("#10131c"))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5,0.5)
	texture.fill_to = Vector2(0.5,0.95)
	texture.width = 1024
	texture.height = 512
	return texture

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

func _position(control:Control, left:float, top:float, right:float, bottom:float) -> void:
	control.anchor_left = left
	control.anchor_top = top
	control.anchor_right = right
	control.anchor_bottom = bottom
	control.offset_left = 0
	control.offset_top = 0
	control.offset_right = 0
	control.offset_bottom = 0

func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	root_ui = Control.new()
	ui_layer.add_child(root_ui)
	root_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = Color("#0c0c13")
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Full-width tabletop, with side panels for the heroes.
	var table := Panel.new()
	table.mouse_filter = Control.MOUSE_FILTER_IGNORE
	table.add_theme_stylebox_override("panel",_gold_panel(Color("#231c24"),Color("#755338")))
	root_ui.add_child(table)
	_position(table,0.018,0.025,0.982,0.975)
	var board := Panel.new()
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_theme_stylebox_override("panel",_gold_panel(Color("#29202b"),Color("#b58a50")))
	root_ui.add_child(board)
	_position(board,0.165,0.075,0.875,0.745)
	var background := RitualTable.new()
	board.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Five lanes are now continuous columns rather than isolated oversized tiles.
	var lanes := HBoxContainer.new()
	lanes.add_theme_constant_override("separation",8)
	root_ui.add_child(lanes)
	_position(lanes,0.184,0.105,0.856,0.716)
	for i in LANES:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation",5)
		lanes.add_child(column)
		var foe_slot := PanelContainer.new()
		foe_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
		foe_slot.size_flags_stretch_ratio = 1.0
		foe_slot.add_theme_stylebox_override("panel",_gold_panel(Color("#3d2735",0.68),Color("#795342",0.65)))
		column.add_child(foe_slot)
		var foe_label := _label("FREI",15)
		foe_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		foe_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		foe_slot.add_child(foe_label)
		foe_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		foe_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		var foe_portrait := CreaturePortrait.new()
		foe_slot.add_child(foe_portrait)
		_position(foe_portrait,0.16,0.04,0.84,0.73)
		enemy_portraits.append(foe_portrait)
		enemy_labels.append(foe_label)
		var number := _label("%d" % (i+1),14)
		number.add_theme_color_override("font_color",Color("#d9b477"))
		column.add_child(number)
		var ally_slot := Button.new()
		ally_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
		ally_slot.size_flags_stretch_ratio = 1.0
		ally_slot.add_theme_font_size_override("font_size",15)
		ally_slot.add_theme_stylebox_override("normal",_gold_panel(Color("#234044",0.62),Color("#71938d",0.8)))
		ally_slot.add_theme_stylebox_override("hover",_gold_panel(Color("#375e61",0.9),Color("#e6c58e")))
		ally_slot.add_theme_stylebox_override("pressed",_gold_panel(Color("#446e68",0.9),Color("#e6c58e")))
		ally_slot.pressed.connect(_choose_lane.bind(i))
		column.add_child(ally_slot)
		var ally_portrait := CreaturePortrait.new()
		ally_slot.add_child(ally_portrait)
		_position(ally_portrait,0.16,0.04,0.84,0.73)
		ally_portraits.append(ally_portrait)
		lane_buttons.append(ally_slot)
	# Hero portraits: visual placeholders, but with distinct HUD.
	var enemy_frame := PanelContainer.new()
	enemy_frame.add_theme_stylebox_override("panel",_gold_panel(Color("#3c222c"),Color("#c1906d")))
	root_ui.add_child(enemy_frame)
	_position(enemy_frame,0.025,0.09,0.153,0.365)
	var enemy_box := VBoxContainer.new()
	enemy_box.alignment = BoxContainer.ALIGNMENT_CENTER
	enemy_frame.add_child(enemy_box)
	enemy_box.add_child(_label("GEGNER",15))
	var enemy_icon := CreaturePortrait.new()
	enemy_icon.heroic = true
	enemy_icon.accent = Color("#d3a48f")
	enemy_icon.custom_minimum_size = Vector2(80,80)
	enemy_icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	enemy_box.add_child(enemy_icon)
	hero_enemy = _label("35 LP",22)
	enemy_box.add_child(hero_enemy)
	var player_frame := PanelContainer.new()
	player_frame.add_theme_stylebox_override("panel",_gold_panel(Color("#22363c"),Color("#7da8a3")))
	root_ui.add_child(player_frame)
	_position(player_frame,0.025,0.385,0.153,0.665)
	var player_box := VBoxContainer.new()
	player_box.alignment = BoxContainer.ALIGNMENT_CENTER
	player_frame.add_child(player_box)
	player_box.add_child(_label("DEIN HELD",15))
	var player_icon := CreaturePortrait.new()
	player_icon.heroic = true
	player_icon.accent = Color("#9ecac5")
	player_icon.custom_minimum_size = Vector2(80,80)
	player_icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	player_box.add_child(player_icon)
	hero_player = _label("35 LP",22)
	player_box.add_child(hero_player)
	var right_hud := PanelContainer.new()
	right_hud.add_theme_stylebox_override("panel",_gold_panel(Color("#211924")))
	root_ui.add_child(right_hud)
	_position(right_hud,0.885,0.09,0.974,0.49)
	var hud_col := VBoxContainer.new()
	hud_col.alignment = BoxContainer.ALIGNMENT_CENTER
	right_hud.add_child(hud_col)
	hud_col.add_child(_label("RUNDE",15))
	round_label = _label("1",30)
	hud_col.add_child(round_label)
	hud_col.add_child(_label("ENERGIE",15))
	energy_label = _label("3",30)
	energy_label.add_theme_color_override("font_color",Color("#83c4e2"))
	hud_col.add_child(energy_label)
	status_label = _label("",13)
	status_label.visible = false
	root_ui.add_child(status_label)
	# Hand occupies a dedicated, generous region below the arena.
	var hand_panel := PanelContainer.new()
	hand_panel.add_theme_stylebox_override("panel",_gold_panel(Color("#18131d"),Color("#a17b4d")))
	root_ui.add_child(hand_panel)
	_position(hand_panel,0.165,0.750,0.875,0.983)
	var hand_col := VBoxContainer.new()
	hand_col.add_theme_constant_override("separation",3)
	hand_panel.add_child(hand_col)
	message_label = _label("Karte wählen, dann einen Pfad antippen",14)
	hand_col.add_child(message_label)
	hand_row = HBoxContainer.new()
	hand_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_row.add_theme_constant_override("separation",10)
	hand_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_col.add_child(hand_row)
	end_button = Button.new()
	end_button.text = "ZUG BEENDEN"
	end_button.add_theme_font_size_override("font_size",19)
	end_button.add_theme_stylebox_override("normal",_gold_panel(Color("#725033"),Color("#dfb46c")))
	end_button.add_theme_stylebox_override("hover",_gold_panel(Color("#94613c"),Color("#ffe0a0")))
	end_button.pressed.connect(_end_turn)
	root_ui.add_child(end_button)
	_position(end_button,0.885,0.53,0.974,0.70)
	title_label = _label("N A C H T S I E G E L",17)
	root_ui.add_child(title_label)
	_position(title_label,0.32,0.028,0.72,0.074)
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
	var accent := Color(str(data["tint"]))
	var button := Button.new()
	button.custom_minimum_size = Vector2(155,145)
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.disabled = finished or energy < int(data["cost"])
	button.add_theme_stylebox_override("normal",_card_style(accent,index == selected))
	button.add_theme_stylebox_override("disabled",_card_style(accent.darkened(0.5)))
	button.add_theme_stylebox_override("hover",_card_style(accent,true))
	button.add_theme_stylebox_override("pressed",_card_style(accent,true))
	var contents := VBoxContainer.new()
	contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contents.add_theme_constant_override("separation",0)
	button.add_child(contents)
	contents.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cost := _label("%d   %s" % [int(data["cost"]),str(data["sigil"])],13)
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contents.add_child(cost)
	var art := CreaturePortrait.new()
	art.accent = accent
	art.archetype = str(data["sigil"])
	art.custom_minimum_size = Vector2(0,85)
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contents.add_child(art)
	var name_label := _label(str(data["name"]),14)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contents.add_child(name_label)
	var stats := "ZAUBER %d" % int(data["attack"]) if str(data["kind"]) == "spell" else "%d ANG  /  %d LP" % [int(data["attack"]),int(data["hp"])]
	var stats_label := _label(stats,13)
	stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contents.add_child(stats_label)
	button.pressed.connect(_select_card.bind(index))
	return button

func _refresh() -> void:
	if status_label == null:
		return
	status_label.text = "DU %d  ·  ENERGIE %d  ·  RUNDE %d  ·  GEGNER %d" % [player_hp,energy,round_number,foe_hp]
	hero_player.text = "%d LP" % player_hp
	hero_enemy.text = "%d LP" % foe_hp
	energy_label.text = "%d / 10" % energy
	round_label.text = "%d" % round_number
	for i in LANES:
		lane_buttons[i].text = "LEER" if allies[i] == null else "%s\n%d ANG  /  %d LP" % [str(allies[i]["name"]),int(allies[i]["attack"]),int(allies[i]["hp"])]
		enemy_labels[i].text = "LEER" if foes[i] == null else "%s\n%d ANG  /  %d LP" % [str(foes[i]["name"]),int(foes[i]["attack"]),int(foes[i]["hp"])]
		ally_portraits[i].visible = allies[i] != null
		enemy_portraits[i].visible = foes[i] != null
		if allies[i] != null:
			ally_portraits[i].archetype = str(allies[i]["sigil"])
			ally_portraits[i].accent = Color(str(allies[i]["tint"]))
			ally_portraits[i].queue_redraw()
		if foes[i] != null:
			enemy_portraits[i].archetype = str(foes[i]["sigil"])
			enemy_portraits[i].accent = Color(str(foes[i]["tint"]))
			enemy_portraits[i].queue_redraw()
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
