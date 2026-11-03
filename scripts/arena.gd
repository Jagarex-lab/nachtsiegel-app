extends Node3D
## NACHTSIEGEL mobile arena, milestone 1.
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
	world_root = Node3D.new()
	world_root.name = "ObsidianWorld"
	add_child(world_root)
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#0d0b17")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#75617f")
	environment.ambient_light_energy = 1.05
	environment_node.environment = environment
	world_root.add_child(environment_node)
	camera = Camera3D.new()
	camera.position = Vector3(0, 10.6, 12.8)
	camera.rotation_degrees = Vector3(-44, 0, 0)
	camera.fov = 52
	camera.current = true
	world_root.add_child(camera)
	var sunlight := DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-60,-25,0)
	sunlight.light_color = Color("#f4d7ad")
	sunlight.light_energy = 1.65
	world_root.add_child(sunlight)
	_mesh_box(Vector3(0,-0.45,0),Vector3(12.7,0.8,10.6),Color("#16121e"),world_root)
	_mesh_box(Vector3(0,0.03,-5.0),Vector3(13.1,0.32,0.55),Color("#85613e"),world_root)
	_mesh_box(Vector3(0,0.03,5.0),Vector3(13.1,0.32,0.55),Color("#85613e"),world_root)
	for i in LANES:
		var x := float(i-2)*2.35
		_mesh_box(Vector3(x,0.02,0),Vector3(2.15,0.12,9.5),Color("#2a2432"),world_root)
		_mesh_box(Vector3(x,0.11,0),Vector3(0.065,0.03,8.8),Color("#b98b58"),world_root)
		_mesh_box(Vector3(x,0.14,-2.35),Vector3(1.88,0.10,2.0),Color("#553041"),world_root)
		_mesh_box(Vector3(x,0.14,2.35),Vector3(1.88,0.10,2.0),Color("#285058"),world_root)
		_mesh_box(Vector3(x,0.15,0),Vector3(1.85,0.03,0.055),Color("#b78b50"),world_root)
		unit_nodes.append({"ally":null,"foe":null})
	_refresh_units()
	_announce("Arena bereit · Karte wählen, dann einen Pfad antippen.")

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
	var body := SphereMesh.new()
	body.radius = 0.51
	body.height = 1.05
	var body_instance := MeshInstance3D.new()
	body_instance.mesh = body
	body_instance.position.y = 0.84
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(str(data["tint"]))
	mat.metallic = 0.25
	mat.roughness = 0.32
	body_instance.material_override = mat
	holder.add_child(body_instance)
	var crest := SphereMesh.new()
	crest.radius = 0.21
	crest.height = 0.42
	var eye := MeshInstance3D.new()
	eye.mesh = crest
	eye.position = Vector3(0,1.03,0.44)
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color("#fff0bb")
	eye_mat.emission_enabled = true
	eye_mat.emission = Color("#f0bc75")
	eye.material_override = eye_mat
	holder.add_child(eye)
	var text3d := Label3D.new()
	text3d.text = "%d / %d" % [int(data["attack"]),int(data["hp"])]
	text3d.font_size = 45
	text3d.pixel_size = 0.008
	text3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	text3d.position = Vector3(0,1.8,0)
	holder.add_child(text3d)
	holder.scale = Vector3(0.05,0.05,0.05)
	holder.create_tween().tween_property(holder,"scale",Vector3.ONE,0.27).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return holder

func _refresh_units() -> void:
	if world_root == null:
		return
	for i in LANES:
		for side in ["ally","foe"]:
			var data = allies[i] if side == "ally" else foes[i]
			var old = unit_nodes[i][side]
			if old != null:
				old.queue_free()
			unit_nodes[i][side] = null
			if data != null:
				unit_nodes[i][side] = _create_creature(data,i,side == "foe")

func _panel(color:Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("#aa885d")
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
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
	var header := PanelContainer.new()
	root_ui.add_child(header)
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_bottom = 105
	header.add_theme_stylebox_override("panel",_panel(Color("#17121fe9")))
	var header_column := VBoxContainer.new()
	header_column.add_theme_constant_override("separation",5)
	header.add_child(header_column)
	title_label = _label("N A C H T S I E G E L    ·    OBSIDIAN-ARENA",25)
	header_column.add_child(title_label)
	status_label = _label("",21)
	header_column.add_child(status_label)
	var bottom := PanelContainer.new()
	root_ui.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -220
	bottom.add_theme_stylebox_override("panel",_panel(Color("#17121ff2")))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",7)
	bottom.add_child(column)
	message_label = _label("",19)
	column.add_child(message_label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation",12)
	column.add_child(row)
	for i in LANES:
		var lane := Button.new()
		lane.custom_minimum_size = Vector2(172,42)
		lane.add_theme_font_size_override("font_size",16)
		lane.add_theme_stylebox_override("normal",_panel(Color("#252030")))
		lane.pressed.connect(_choose_lane.bind(i))
		row.add_child(lane)
		lane_buttons.append(lane)
	hand_row = HBoxContainer.new()
	hand_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_row.add_theme_constant_override("separation",9)
	column.add_child(hand_row)
	end_button = Button.new()
	end_button.text = "ZUG BEENDEN  →"
	end_button.custom_minimum_size = Vector2(260,35)
	end_button.add_theme_font_size_override("font_size",17)
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
	button.custom_minimum_size = Vector2(178,90)
	button.add_theme_font_size_override("font_size",17)
	button.text = "%s  ✦%d\n%s\n%s" % [str(data["sigil"]),int(data["cost"]),str(data["name"]),("ZAUBER · %d SCHADEN" % int(data["attack"])) if str(data["kind"]) == "spell" else "%d ANGRIFF  ·  %d LEBEN" % [int(data["attack"]),int(data["hp"])]]
	button.disabled = finished or energy < int(data["cost"])
	button.add_theme_stylebox_override("normal",_panel(Color(str(data["tint"])).darkened(0.64)))
	button.add_theme_stylebox_override("hover",_panel(Color(str(data["tint"])).darkened(0.38)))
	button.add_theme_stylebox_override("pressed",_panel(Color(str(data["tint"])).darkened(0.22)))
	if index == selected:
		button.add_theme_stylebox_override("normal",_panel(Color(str(data["tint"])).darkened(0.30)))
	button.pressed.connect(_select_card.bind(index))
	return button

func _refresh() -> void:
	if status_label == null:
		return
	status_label.text = "DU  %d ♥     ·     ENERGIE  %d     ·     RUNDE  %d     ·     BESCHWÖRUNGEN  %d/2     ·     GEGNER  %d ♥" % [player_hp,energy,round_number,summons,foe_hp]
	for i in LANES:
		var ally_str := "—" if allies[i] == null else "%d/%d" % [int(allies[i]["attack"]),int(allies[i]["hp"])]
		var foe_str := "—" if foes[i] == null else "%d/%d" % [int(foes[i]["attack"]),int(foes[i]["hp"])]
		lane_buttons[i].text = "PFAD %d   %s | %s" % [i+1,ally_str,foe_str]
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
