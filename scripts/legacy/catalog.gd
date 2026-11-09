extends RefCounted
## Isolated legacy rule data. Not used by the arena or the current seven-card pool.
## Names/flavor, ownership, persistence and purchase policy are deliberately absent.
const RULESET_ID := "duel-deck-34b3062"
const SOURCE_COMMIT := "34b3062c3f22c0950d9323ad9b97b17c41d1d14f"
var _cards: Dictionary = {}
var _decks: Dictionary = {}
var _ids: Array[String] = []
func _init() -> void:
	var cards: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/legacy/cards.json"))
	var decks: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/legacy/decks.json"))
	assert(cards.source.commit == SOURCE_COMMIT and decks.source.commit == SOURCE_COMMIT)
	assert(cards.ruleset_id == RULESET_ID and decks.ruleset_id == RULESET_ID)
	for entry: Dictionary in cards.cards:
		var id: String = entry.id
		assert(not _cards.has(id))
		_ids.append(id)
		_cards[id] = entry.duplicate(true)
	for entry: Dictionary in decks.decks:
		_decks[str(entry.id)] = entry.cards.duplicate()
func ids() -> Array[String]:
	return _ids.duplicate()
func has_card(id: String) -> bool:
	return _cards.has(id)
func card(id: String) -> Dictionary:
	return _cards.get(id,{}).duplicate(true)
func all_cards() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in _ids: result.append(card(id))
	return result
func deck_ids() -> Array[String]:
	return ["start","ash","tide","thorn","veil"]
func deck(id: String) -> Array:
	return _decks.get(id,[]).duplicate()
