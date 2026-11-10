extends RefCounted
## Original display text, keyed by stable IDs. No rule, deck or ownership dependency.
var _labels: Dictionary
func _init() -> void:
	_labels = JSON.parse_string(FileAccess.get_file_as_string("res://data/legacy/display_de.json"))
func card_text(id: String) -> Dictionary:
	return _labels.cards.get(id,{}).duplicate(true)
func display_name(id: String) -> String:
	return str(card_text(id).get("name",""))
