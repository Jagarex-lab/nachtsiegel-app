extends RefCounted
## Editorial drafts only. The battle engine never loads entities into CARD_POOL.
const CONTENT = preload("res://data/narrative/content.json")
const DE = preload("res://data/narrative/locales/de.json")
const EN = preload("res://data/narrative/locales/en.json")

static func manifest() -> Dictionary:
	return CONTENT.data.duplicate(true)

static func text(key: String, locale: String = "de", values: Dictionary = {}) -> String:
	var language = locale.replace("-","_").get_slice("_",0).to_lower()
	var strings: Dictionary = EN.data if language == "en" else DE.data
	var fallback: Dictionary = DE.data
	var result = str(strings.get(key,fallback.get(key,"[missing:"+key+"]")))
	for name in values:
		result = result.replace("{"+str(name)+"}",str(values[name]))
	return result

static func entity(collection: String, id: String) -> Dictionary:
	for item in CONTENT.data.collections.get(collection,[]):
		if str(item.get("id","")) == id: return item.duplicate(true)
	return {}
