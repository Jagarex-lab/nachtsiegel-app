extends SceneTree
const FACE = preload("res://scripts/card_system/card_face.gd")
var assertions := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok: failures += 1; printerr("FAIL: ", message)
func run() -> void:
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/production/cards.json"))
	var face = FACE.new()
	var overflow: Array = []
	check(parsed.cards.size() == 550, "all actual 550 production candidate records inspected")
	for card in parsed.cards:
		face.card = card
		var report = face.layout_report()
		check(report.title_fits, "complete title fits master: " + str(card.id))
		check(report.rules_fit, "complete rules fit master: " + str(card.id))
		check(report.has_combat_values == (card.kind == "creature"), "correct type information: " + str(card.id))
		check(FACE.OUTER.encloses(report.title) and FACE.OUTER.encloses(report.rules) and FACE.OUTER.encloses(report.art), "all fixed panels remain in identical contour: " + str(card.id))
		if not report.rules_fit: overflow.append({"id": card.id, "name": card.name, "text": face.normalized().text, "actual_height": report.rules_actual.y, "available_height": report.rules.size.y})
	DirAccess.make_dir_recursive_absolute("res://work/production-art")
	var output = FileAccess.open("res://work/production-art/text-layout.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"source_catalog_sha256": FileAccess.get_sha256("res://data/production/cards.json"), "cards": parsed.cards.size(), "assertions": assertions, "failures": failures, "overflow": overflow}, "  ")); output.close()
	face.free()
	print("PRODUCTION CARD TEXT LAYOUT: %d assertions, %d failures; all 550 actual candidate names, rules, type slots and invariant panels" % [assertions, failures])
	root.get_node("GameAudio").request_quit(0 if failures == 0 else 1)
