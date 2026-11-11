extends RefCounted
const RULESET_ID := "orafold-alpha-0.1"
var source: Dictionary
var cards: Dictionary={}
func _init(source_path: String="res://data/alpha/cards.json") -> void:
	source=JSON.parse_string(FileAccess.get_file_as_string(source_path))
	# Editorial identity metadata is separate from the pinned mechanical pool.
	# Every listed species has equal rank; this adds no automatic combat triggers.
	var metadata: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/card_system/alpha_species.json"))
	var known_species: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/card_system/registry.json")).species
	for c in source.cards:
		if c.kind=="creature" and not c.has("species"):
			assert(metadata.species_by_card_id.has(c.id),"Missing species metadata: "+c.id)
			var types: Array=metadata.species_by_card_id[c.id]
			assert(types.size() in [1,2],"Invalid species count: "+c.id)
			for type in types:assert(known_species.has(type),"Unknown species: "+str(type))
			c.species=types.duplicate()
	for c in source.cards:cards[c.id]=c
func card(id: String) -> Dictionary:return cards.get(id,{}).duplicate(true)
func all_cards() -> Array:
	return source.cards.duplicate(true)
func deck(id: String) -> Array:return source.starters.get(id,[]).duplicate()
func deck_ids() -> Array:return ["houses","stillwatch","morph","ninth"]
func validate(deck_value: Variant) -> Dictionary:
	if not deck_value is Array or deck_value.size()!=30:return {"ok":false,"message":"Genau30 Karten erforderlich."}
	var faction := "neutral"
	var counts: Dictionary={}
	for id in deck_value:
		if not id is String or not cards.has(id):return {"ok":false,"message":"Unbekannte Karte."}
		var c: Dictionary=cards[id]
		if c.faction!="neutral":
			if faction!="neutral" and faction!=c.faction:return {"ok":false,"message":"Nur eine Macht plus neutrale Karten."}
			faction=c.faction
		counts[id]=counts.get(id,0)+1
		if counts[id]>(1 if c.rarity=="legendary" else 3):return {"ok":false,"message":"Kopienlimit überschritten: "+c.name}
	return {"ok":true,"message":"","faction":faction}
