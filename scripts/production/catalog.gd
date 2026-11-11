extends "res://scripts/alpha/catalog.gd"
## Active production pool. The archived 55-card and Legacy catalogs keep their
## own constructors so historical rules tests/replays never silently change pool.
const PROFILE_ID := "production-550-v1"
const SOURCE_PATH := "res://data/production/cards.json"
static var _parsed: Dictionary={}
static var _fingerprint := ""
var load_error := ""

func _init() -> void:
	# Parent default initialization deliberately validates the archived overlay.
	# Only this explicitly selected profile replaces the active runtime source.
	if _parsed.is_empty():
		var raw=FileAccess.get_file_as_string(SOURCE_PATH)
		var value: Variant=JSON.parse_string(raw)
		if not value is Dictionary or not value.get("cards") is Array or not value.get("starters") is Dictionary:
			load_error="Produktionskatalog fehlt oder ist beschädigt."
			source={"cards":[],"starters":{}};cards.clear();return
		_parsed=value
		var mechanics: Array=[]
		for card_data in value.cards:
			if not card_data is Dictionary:continue
			mechanics.append(mechanical_card(card_data))
		mechanics.sort_custom(func(a: Dictionary,b: Dictionary):return str(a.get("id",""))<str(b.get("id","")))
		_fingerprint=JSON.stringify({"profile":PROFILE_ID,"cards":mechanics},"",true).sha256_text()
	source=_parsed.duplicate(true)
	cards.clear()
	for c in source.cards:
		if not c is Dictionary or not c.get("id") is String or cards.has(c.id):
			load_error="Ungültige oder doppelte Kartenidentität."
			cards.clear();source={"cards":[],"starters":{}};return
		cards[c.id]=c

static func mechanical_card(card_data: Dictionary) -> Dictionary:
	var result: Dictionary={}
	for key in ["id","faction","order","kind","rarity","cost","atk","hp","species","effect","power","abilities","resonance_cost","reaction_window"]:
		if card_data.has(key):result[key]=card_data[key].duplicate(true) if card_data[key] is Array or card_data[key] is Dictionary else card_data[key]
	if result.get("species") is Array:result.species.sort()
	return result

func fingerprint() -> String:return _fingerprint

func validate(deck_value: Variant) -> Dictionary:
	if not load_error.is_empty():return {"ok":false,"message":load_error}
	var result=super.validate(deck_value)
	if result.ok and result.faction=="neutral":
		return {"ok":false,"message":"Wähle genau eine Macht; neutrale Karten ergänzen sie."}
	return result
