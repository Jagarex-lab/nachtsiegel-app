extends RefCounted
## Locale fallback remains visible to the QA validator; no story strings in code.
var locales: Dictionary = {}
var locale := "de"
var state
var missing_translations: Array = []

func _init(campaign_state = null, translations: Dictionary = {}) -> void:
	state = campaign_state
	locales = translations.duplicate(true)

static func conditions_met(conditions: Array, data: Dictionary) -> bool:
	for condition in conditions:
		if not condition is Dictionary: return false
		if condition.has("flag"):
			if not data.get("flags",{}).has(condition.flag) or data.flags[condition.flag] != condition.get("equals"): return false
		elif condition.has("chapter_completed"):
			if not data.get("completed_chapters",[]).has(condition.chapter_completed): return false
		elif condition.has("character_info"):
			if not data.get("character_info",[]).has(condition.character_info): return false
		else: return false
	return true

func text(id: String, requested_locale: String = "") -> String:
	if requested_locale.is_empty(): requested_locale = locale
	var language := requested_locale.replace("-","_").get_slice("_",0).to_lower()
	if locales.get(language,{ }).has(id): return str(locales[language][id])
	var missing := language+":"+id
	if not missing_translations.has(missing): missing_translations.append(missing)
	return str(locales.get("de",{}).get(id,"[missing:"+id+"]"))

func lines(scene: Dictionary, data: Dictionary) -> Array:
	var output: Array = []
	for line in scene.get("dialogue",[]):
		if conditions_met(line.get("conditions",[]),data): output.append(line.duplicate(true))
	return output

func record(scene: Dictionary, data: Dictionary) -> void:
	# Replay alternatives are readable/skip-able but never rewrite the original recap.
	if data.get("active",{}).get("replay",false):
		if not data.seen_scenes.has(scene.id): data.seen_scenes.append(scene.id)
		return
	for previous in data.history:
		if previous.scene_id == scene.id: return
	for line in lines(scene,data):
		data.history.append({"scene_id":scene.id,"speaker_id":line.get("speaker_id",""),"text_id":line.text_id,"emotion":line.get("emotion","neutral"),"status":line.get("status",scene.get("status","VORSCHLAG")),"source":line.get("source",scene.get("source",""))})
	data.history = data.history.slice(-1024)
	if not data.seen_scenes.has(scene.id): data.seen_scenes.append(scene.id)

func history() -> Array:
	return state.data.history.duplicate(true) if state != null else []
