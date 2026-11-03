extends Node3D
## NACHTSIEGEL: first playable 2.5D arena interaction prototype.
## Five lanes, two sides, selectable summon cards, attack and end turn.
## The original v2.5 rules have NOT yet been ported.

const LANES := 5
const MAX_HEALTH := 35
const SUMMON_COST := 2

var turn := 1
var energy := 3
var hero_hp := MAX_HEALTH
var enemy_hp := MAX_HEALTH
var selected_card := -1
var hand := ["Aschenwache", "Dornenwolf", "Nebelqualle"]
var ally_units: Array = [null, null, null, null, null]
var enemy_units: Array = [null, null, null, null, null]
var message_label: Label
var status_label: Label
var hand_row: HBoxContainer
var lane_buttons: Array[Button] = []
var camera: Camera3D

func _ready() -> void:
	_build_world()
	_build_ui()
	_refresh()
	_announce("Wähle eine Karte und danach einen freien Pfad.")

func _build_world() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#0b0a13")
	environment.ambient_light_source = Environment.AMBIENT_COLOR
	environment.ambient_light_color = Color("#51435d")
	environment.ambient_light_energy = 0.7
	world.environment = environment
	add_child(world)
	camera = Camera3D.new()
	camera.position = Vector3(0, 9.8, 12.5)
	camera.rotation_degrees = Vector3(-38, 0, 0)
	camera.fov = 48
	camera.current = true
	add_child(camera)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -25, 0)
	light.light_color = Color("#d4b78a")
	light.light_energy = 1.6
	add_child(light)
	_box("Obsidian", Vector3(0, -0.35, 0), Vector3(12.5, 0.65, 10), Color("#1b1724"))
	for i in LANES:
		var x := float(i - 2) * 2.3
		_box("Pfad_%d" % (i + 1), Vector3(x, 0.015, 0), Vector3(2.05, 0.12, 8.4), Color("#302b39"))
		_box("Runen_%d" % (i + 1), Vector3(x, 0.09, 0), Vector3(0.065, 0.035, 7.5), Color("#b28b55"))
		_box("Gegnerfeld_%d" % (i + 1), Vector3(x, 0.14, -2.2), Vector3(1.8, 0.08, 2.0), Color("#4a273c"))
		_box("Spielerfeld_%d" % (i + 1), Vector3(x, 0.14, 2.2), Vector3(1.8, 0.08, 2.0), Color("#24424b"))
	_box("Mittelrune", Vector3(0, 0.11, 0), Vector3(11.8, 0.03, 0.07), Color("#d3ad6a"))

func _box(node_name: String, pos: Vector3, dimensions: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.35
	material.roughness = 0.45
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = pos
	add_child(instance)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var top := PanelContainer.new()
	root.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 84
	var header := VBoxContainer.new()
	top.add_child(header)
	var title := Label.new()
	title.text = "✦ NACHTSIEGEL  ·  DIE OBSIDIAN-ARENA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	header.add_child(title)
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 18)
	header.add_child(status_label)
	var bottom := PanelContainer.new()
	root.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -192
	var column := VBoxContainer.new()
	bottom.add_child(column)
	message_label = Label.new()
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(message_label)
	var lanes_row := HBoxContainer.new()
	lanes_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(lanes_row)
	for i in LANES:
		var lane := Button.new()
		lane.custom_minimum_size = Vector2(112, 42)
		lane.pressed.connect(_on_lane_pressed.bind(i))
		lanes_row.add_child(lane)
		lane_buttons.append(lane)
	hand_row = HBoxContainer.new()
	hand_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(hand_row)
	var end_button := Button.new()
	end_button.text = "ZUG BEENDEN  →"
	end_button.pressed.connect(_end_turn)
	column.add_child(end_button)

func _refresh() -> void:
	status_label.text = "DU %d ♥     ·     ENERGIE %d     ·     ZUG %d     ·     GEGNER %d ♥" % [hero_hp, energy, turn, enemy_hp]
	for i in LANES:
		var ally_text := "FREI" if ally_units[i] == null else str(ally_units[i])
		var enemy_text := "—" if enemy_units[i] == null else str(enemy_units[i])
		lane_buttons[i].text = "%d · %s / %s" % [i + 1, ally_text, enemy_text]
	for child in hand_row.get_children():
		child.queue_free()
	for i in hand.size():
		var card := Button.new()
		card.custom_minimum_size = Vector2(176, 58)
		card.text = "%s\n✦ %d Energie" % [hand[i], SUMMON_COST]
		card.disabled = energy < SUMMON_COST
		card.pressed.connect(_select_card.bind(i))
		hand_row.add_child(card)

func _select_card(index: int) -> void:
	selected_card = index
	_announce("%s gewählt – tippe auf einen freien Pfad." % hand[index])

func _on_lane_pressed(index: int) -> void:
	if selected_card < 0:
		_announce("Wähle zuerst eine Karte.")
		return
	if ally_units[index] != null:
		_announce("Dieser Pfad ist bereits besetzt.")
		return
	if energy < SUMMON_COST:
		_announce("Nicht genügend Energie.")
		return
	var unit_name: String = hand[selected_card]
	ally_units[index] = unit_name
	energy -= SUMMON_COST
	hand.remove_at(selected_card)
	selected_card = -1
	_announce("%s auf Pfad %d beschworen!" % [unit_name, index + 1])
	_refresh()

func _end_turn() -> void:
	for i in LANES:
		if ally_units[i] != null and enemy_units[i] == null:
			enemy_hp = max(0, enemy_hp - 1)
	if enemy_hp == 0:
		_announce("SIEG! Der gegnerische Held ist gefallen.")
		_refresh()
		return
	turn += 1
	energy = min(10, 2 + turn)
	hand.append(["Aschenwache", "Dornenwolf", "Nebelqualle"][turn % 3])
	if turn % 2 == 0:
		var index := randi_range(0, LANES - 1)
		if enemy_units[index] == null:
			enemy_units[index] = "Schattenwolf"
	_announce("Neuer Zug – die Runen erwachen.")
	_refresh()

func _announce(value: String) -> void:
	if message_label != null:
		message_label.text = value
