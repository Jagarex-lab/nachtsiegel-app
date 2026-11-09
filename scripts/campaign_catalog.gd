extends RefCounted
const CONTENT = preload("res://data/campaign/chapters.json")
const Lore = preload("res://scripts/narrative_catalog.gd")
static func chapters() -> Array: return CONTENT.data.chapters.duplicate(true)
static func chapter(number: int) -> Dictionary:
	for item in CONTENT.data.chapters:
		if int(item.number)==number: return item.duplicate(true)
	return {}
static func heroes() -> Array:
	return [{"id":"keeper","name":"Siegelhüterin","story_name":"Mara Sen","portrait":7,"bio_key":"characters.mara.biography"},{"id":"ash_king","name":"Aschenkönig","story_name":"Varo Kest","portrait":8,"bio_key":"characters.varo.biography"}]
static func hero(id: String) -> Dictionary:
	for item in heroes():
		if item.id==id: return item
	return heroes()[0]
static func title(number: int) -> String: return Lore.text(chapter(number).title_key)
static func faction(index: int) -> String:
	var id = ["crucible","graft","concord","names","crucible","concord","crucible"][index]
	return Lore.text("factions."+id+".name")
