extends Control
## Diagnostic scene: isolates the Godot 2D/UI pipeline from the 3D arena.
## This is temporary and does not replace the game implementation.

var label: Label

func _ready() -> void:
	print("NACHTSIEGEL_SMOKE_TEST_READY")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("#15101f")
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 24)
	center.add_child(panel)

	label = Label.new()
	label.text = "NACHTSIEGEL\nGODOT-STARTTEST"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 36)
	panel.add_child(label)

	var status := Label.new()
	status.text = "Wenn du diesen Text siehst, funktioniert Godots 2D-Oberfläche."
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 18)
	panel.add_child(status)

	var button := Button.new()
	button.text = "TEST ERFOLGREICH · ANTIPPEN"
	button.custom_minimum_size = Vector2(350, 72)
	button.pressed.connect(_on_pressed)
	panel.add_child(button)

func _on_pressed() -> void:
	label.text = "TOUCH FUNKTIONIERT ✓"
	print("NACHTSIEGEL_SMOKE_TEST_TOUCH_OK")
