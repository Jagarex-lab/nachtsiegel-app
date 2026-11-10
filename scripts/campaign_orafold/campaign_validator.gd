extends RefCounted
## Structural/editorial gate. This validates declared status, not prose canon approval.
const COLLECTIONS = ["campaigns", "chapters", "scenes", "characters", "encounters", "decisions", "rewards"]
const STATUSES = ["KANON", "ARBEITSSTAND", "VORSCHLAG", "ALTENTWURF", "VERWORFEN", "OFFEN", "PROTOTYPE", "prototype"]

static func validate(value: Variant, locales: Dictionary = {}) -> Dictionary:
	var errors: Array = []
	var warnings: Array = []
	if not value is Dictionary:
		return {"ok": false, "errors": ["bundle: expected dictionary"], "warnings": []}
	var data: Dictionary = value
	if data.get("schema_version") != 1: errors.append("bundle.schema_version: unsupported")
	if not _integer_number(data.get("content_version")):
		errors.append("bundle.content_version: expected number")
	for collection in COLLECTIONS:
		if not data.get(collection) is Dictionary:
			errors.append(collection + ": expected dictionary")
	if not errors.is_empty(): return {"ok": false, "errors": errors, "warnings": warnings}
	if not data.campaigns.has(data.get("default_campaign", "")): errors.append("bundle.default_campaign: missing campaign")
	var text_ids: Dictionary = {}
	for collection in COLLECTIONS:
		for id in data[collection]:
			var item = data[collection][id]
			var where: String = str(collection) + "." + str(id)
			if not item is Dictionary:
				errors.append(where + ": expected dictionary")
				continue
			if not id is String or str(id).is_empty(): errors.append(where + ": invalid id")
			if item.get("id") != id: errors.append(where + ": id/key mismatch")
			_editorial(item, where, errors)
			var required_texts: Array = ["title_id"] if collection in ["campaigns", "chapters", "scenes"] else (["name_id", "description_id"] if collection == "characters" else [])
			for field in required_texts:
				if not item.get(field) is String or str(item.get(field, "")).is_empty(): errors.append(where + "." + field + ": text id required")
			_collect_texts(item, text_ids)
	# Stop before dereferencing malformed records.
	if not errors.is_empty(): return {"ok": false, "errors": errors, "warnings": warnings}
	for id in data.campaigns:
		var item: Dictionary = data.campaigns[id]
		_array_refs(item.get("chapters"), data.chapters, "campaigns." + id + ".chapters", errors, true)
	for id in data.chapters:
		var item: Dictionary = data.chapters[id]
		var where: String = "chapters." + id
		_array_refs(item.get("scenes"), data.scenes, where + ".scenes", errors, true)
		if not item.get("replayable", false) is bool: errors.append(where + ".replayable: expected boolean")
		_array_refs(item.get("requires", []), data.chapters, where + ".requires", errors)
		_ref(item.get("entry_scene"), data.scenes, where + ".entry_scene", errors)
		if item.get("requires", []) is Array and item.get("requires", []).has(id): errors.append(where + ": self prerequisite")
		if item.get("scenes") is Array:
			if not item.scenes.has(item.get("entry_scene")): errors.append(where + ": entry_scene not in chapter")
			for scene_id in item.scenes:
				if data.scenes.has(scene_id) and data.scenes[scene_id].get("chapter_id") != id:
					errors.append(where + ": scene belongs to another chapter: " + str(scene_id))
	for id in data.scenes:
		var item: Dictionary = data.scenes[id]
		var where: String = "scenes." + id
		_ref(item.get("chapter_id"), data.chapters, where + ".chapter_id", errors)
		if data.chapters.has(item.get("chapter_id")):
			var members = data.chapters[item.chapter_id].get("scenes", [])
			if members is Array and not members.has(id): errors.append(where + ": omitted from chapter scenes")
		_asset(item.get("background", ""), where + ".background", errors)
		if not item.get("dialogue", []) is Array:
			errors.append(where + ".dialogue: expected array")
		else:
			for line in item.get("dialogue", []):
				if not line is Dictionary:
					errors.append(where + ".dialogue: expected object")
					continue
				if not str(line.get("speaker_id", "")).is_empty(): _ref(line.speaker_id, data.characters, where + ".speaker_id", errors)
				if not line.get("text_id") is String: errors.append(where + ".dialogue: missing text_id")
				_conditions(line.get("conditions", []), data, where + ".dialogue.conditions", errors)
		for field in ["decision_id", "encounter_id", "next_scene"]:
			if item.has(field):
				var refs: Dictionary = data.decisions if field == "decision_id" else (data.encounters if field == "encounter_id" else data.scenes)
				_ref(item[field], refs, where + "." + field, errors)
		if item.has("complete_chapter") and not item.complete_chapter is bool: errors.append(where + ".complete_chapter: expected boolean")
		var exits := int(item.has("decision_id")) + int(item.has("encounter_id")) + int(item.has("next_scene")) + int(item.get("complete_chapter", false) == true)
		if exits != 1: errors.append(where + ": exactly one decision, encounter, next_scene or completion required")
		_effects(item.get("on_enter", []), data, where + ".on_enter", errors)
		_effects(item.get("on_complete", []), data, where + ".on_complete", errors)
	for id in data.decisions:
		var item: Dictionary = data.decisions[id]
		var where: String = "decisions." + id
		if not item.get("choices") is Array or item.get("choices", []).is_empty():
			errors.append(where + ": choices required")
			continue
		var choices: Array = []
		var fallback := false
		for choice in item.choices:
			if not choice is Dictionary:
				errors.append(where + ": expected choice dictionary")
				continue
			if not choice.get("id") is String or str(choice.get("id", "")).is_empty() or choices.has(choice.get("id")): errors.append(where + ": duplicate/invalid choice id")
			choices.append(choice.get("id"))
			if not choice.get("text_id") is String: errors.append(where + ": choice text_id required")
			_ref(choice.get("next_scene"), data.scenes, where + ".next_scene", errors)
			_conditions(choice.get("conditions", []), data, where + ".conditions", errors)
			_effects(choice.get("effects", []), data, where + ".effects", errors)
			if choice.get("conditions", []) is Array and choice.get("conditions", []).is_empty(): fallback = true
		if not fallback: warnings.append(where + ": no unconditional choice; verify every reachable state has an exit")
	for id in data.encounters:
		var item: Dictionary = data.encounters[id]
		for outcome in ["on_victory", "on_defeat"]: _ref(item.get(outcome), data.scenes, "encounters." + id + "." + outcome, errors)
		for field in ["deck_profile", "enemy_profile", "ai_profile"]:
			if not item.get(field) is String or str(item.get(field, "")).is_empty(): errors.append("encounters." + id + "." + field + ": required")
		if not _integer_number(item.get("seed")): errors.append("encounters." + id + ".seed: expected nonnegative integer")
		if not item.get("repeatable", false) is bool: errors.append("encounters." + id + ".repeatable: expected boolean")
	var all_knowledge_ids: Array = []
	for id in data.characters:
		var item: Dictionary = data.characters[id]
		var where: String = "characters." + id
		_asset(item.get("portrait", ""), where + ".portrait", errors)
		if id == "eira":
			if item.get("protected") != true: errors.append(where + ": Eira must be protected")
			if not str(item.get("portrait", "")).is_empty(): errors.append(where + ": Eira appearance is undecided; no portrait allowed")
		if not item.get("knowledge", []) is Array:
			errors.append(where + ".knowledge: expected array")
			continue
		var known: Array = []
		for entry in item.get("knowledge", []):
			if not entry is Dictionary:
				errors.append(where + ".knowledge: expected dictionary")
				continue
			_editorial(entry, where + ".knowledge", errors)
			if not entry.get("id") is String or known.has(entry.get("id")): errors.append(where + ".knowledge: duplicate/invalid id")
			known.append(entry.get("id"))
			if all_knowledge_ids.has(entry.get("id")): errors.append(where + ".knowledge: globally duplicate information id")
			all_knowledge_ids.append(entry.get("id"))
			if not entry.get("category") in ["fact", "belief", "player", "canon"]: errors.append(where + ".knowledge: unknown category")
			if not entry.get("text_id") is String: errors.append(where + ".knowledge: text_id required")
			if entry.get("category") == "canon" and entry.get("status") != "KANON": errors.append(where + ".knowledge: canon category needs KANON status")
			if entry.has("visibility") and not entry.visibility in ["public", "private"]: errors.append(where + ".knowledge: unknown visibility")
			if item.get("protected", false) and entry.get("visibility", "private") == "public": errors.append(where + ".knowledge: protected information cannot be public")
			_conditions(entry.get("conditions", []), data, where + ".knowledge.conditions", errors)
	for id in data.rewards:
		var item: Dictionary = data.rewards[id]
		if not item.get("payload", {}) is Dictionary: errors.append("rewards." + id + ".payload: expected dictionary")
		if not item.get("type") in ["character_info", "chapter", "external"]: errors.append("rewards." + id + ": unknown reward type")
		if not item.get("target") is String or str(item.get("target", "")).is_empty(): errors.append("rewards." + id + ": target required")
		if item.get("type") == "chapter": _ref(item.get("target"), data.chapters, "rewards." + id + ".target", errors)
		if item.get("type") == "character_info" and not _has_info(data, item.get("target")): errors.append("rewards." + id + ": unknown character info")
	if errors.is_empty():
		for id in data.scenes:
			for target in _edges(data, id):
				if data.scenes[target].chapter_id != data.scenes[id].chapter_id: errors.append("scenes." + id + ": cross-chapter edge; unlock chapter through an effect")
		_graph(data, errors)
	# UI labels share the locale files; a key present in either language also needs its counterpart.
	for translations in locales.values():
		if translations is Dictionary:
			for text_id in translations: text_ids[text_id] = true
	for language in ["de", "en"]:
		if not locales.get(language) is Dictionary:
			errors.append("locales." + language + ": required dictionary")
			continue
		for text_id in text_ids:
			if not locales[language].get(text_id) is String or str(locales[language].get(text_id, "")).strip_edges().is_empty(): errors.append("locales." + language + ": missing " + str(text_id))
		for text_id in locales[language]:
			if not locales[language][text_id] is String: errors.append("locales." + language + "." + str(text_id) + ": expected string")
	return {"ok": errors.is_empty(), "errors": errors, "warnings": warnings}

static func _editorial(item: Dictionary, where: String, errors: Array) -> void:
	if not item.get("status") in STATUSES: errors.append(where + ": missing/unknown lore status")
	if not item.get("source") is String or str(item.get("source", "")).strip_edges().is_empty(): errors.append(where + ": source required")

static func _collect_texts(value: Variant, found: Dictionary) -> void:
	if value is Dictionary:
		for key in value:
			if str(key).ends_with("_id") and key in ["text_id", "title_id", "summary_id", "name_id", "description_id"] and value[key] is String: found[value[key]] = true
			else: _collect_texts(value[key], found)
	elif value is Array:
		for entry in value: _collect_texts(entry, found)

static func _ref(id: Variant, table: Dictionary, where: String, errors: Array) -> void:
	if not id is String or not table.has(id): errors.append(where + ": unknown reference " + str(id))

static func _array_refs(value: Variant, table: Dictionary, where: String, errors: Array, nonempty: bool = false) -> void:
	if not value is Array:
		errors.append(where + ": expected array")
		return
	if nonempty and value.is_empty(): errors.append(where + ": empty")
	var seen: Array = []
	for id in value:
		_ref(id, table, where, errors)
		if seen.has(id): errors.append(where + ": duplicate reference " + str(id))
		seen.append(id)

static func _asset(path: Variant, where: String, errors: Array) -> void:
	if not path is String:
		errors.append(where + ": expected path string")
	# Imported textures are remapped in exported PCKs; their source SVG/PNG may
	# intentionally be absent while the resource remains fully loadable.
	elif not path.is_empty() and (not path.begins_with("res://") or not ResourceLoader.exists(path)):
		errors.append(where + ": missing asset " + path)

static func _has_info(data: Dictionary, id: Variant) -> bool:
	for character in data.characters.values():
		if character.get("knowledge", []) is Array:
			for entry in character.get("knowledge", []):
				if entry is Dictionary and entry.get("id") == id: return true
	return false

static func _conditions(value: Variant, data: Dictionary, where: String, errors: Array) -> void:
	if not value is Array:
		errors.append(where + ": expected array")
		return
	var flags: Dictionary = {}
	for item in value:
		if not item is Dictionary:
			errors.append(where + ": expected dictionary")
			continue
		if item.has("flag"):
			if not item.flag is String or not item.has("equals") or not _scalar(item.get("equals")): errors.append(where + ": flag requires scalar equals")
			elif flags.has(item.flag) and flags[item.flag] != item.equals: errors.append(where + ": contradictory flag " + str(item.flag))
			else: flags[item.flag] = item.get("equals")
		elif item.has("chapter_completed"): _ref(item.chapter_completed, data.chapters, where, errors)
		elif item.has("character_info"):
			if not _has_info(data, item.character_info): errors.append(where + ": unknown character info")
		else: errors.append(where + ": unknown condition")

static func _scalar(value: Variant) -> bool:
	return value is String or value is bool or value is int or (value is float and is_finite(value))

static func _integer_number(value: Variant, signed: bool = false) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and (signed or float(value) >= 0)

static func _effects(value: Variant, data: Dictionary, where: String, errors: Array) -> void:
	if not value is Array:
		errors.append(where + ": expected array")
		return
	var flags: Dictionary = {}
	for item in value:
		if not item is Dictionary:
			errors.append(where + ": expected dictionary")
			continue
		match item.get("type"):
			"set_flag":
				if not item.get("key") is String or not item.has("value") or not _scalar(item.get("value")): errors.append(where + ": invalid flag effect")
				elif flags.has(item.key) and flags[item.key] != item.value: errors.append(where + ": contradictory flag effects")
				else: flags[item.key] = item.value
			"relationship":
				_ref(item.get("character_id"), data.characters, where, errors)
				if not _integer_number(item.get("delta"), true): errors.append(where + ": integer relationship delta required")
			"unlock_info":
				if not _has_info(data, item.get("id")): errors.append(where + ": unknown character info")
			"unlock_chapter": _ref(item.get("id"), data.chapters, where, errors)
			"reward": _ref(item.get("id"), data.rewards, where, errors)
			_: errors.append(where + ": unknown consequence type")

static func _edges(data: Dictionary, id: String) -> Array:
	var item: Dictionary = data.scenes[id]
	var result: Array = []
	if data.scenes.has(item.get("next_scene")): result.append(item.next_scene)
	if data.decisions.has(item.get("decision_id")):
		var choices = data.decisions[item.decision_id].get("choices", [])
		if choices is Array:
			for choice in choices:
				if choice is Dictionary and data.scenes.has(choice.get("next_scene")): result.append(choice.next_scene)
	if data.encounters.has(item.get("encounter_id")):
		for key in ["on_victory", "on_defeat"]:
			var target = data.encounters[item.encounter_id].get(key)
			if data.scenes.has(target): result.append(target)
	return result

static func _graph(data: Dictionary, errors: Array) -> void:
	var reached: Dictionary = {}
	var queue: Array = []
	for chapter in data.chapters.values():
		if data.scenes.has(chapter.get("entry_scene")): queue.append(chapter.entry_scene)
	while not queue.is_empty():
		var id: String = queue.pop_front()
		if reached.has(id): continue
		reached[id] = true
		queue.append_array(_edges(data, id))
	var finishing: Dictionary = {}
	for id in data.scenes:
		if data.scenes[id].get("complete_chapter", false) == true: finishing[id] = true
	var changed := true
	while changed:
		changed = false
		for id in data.scenes:
			if finishing.has(id): continue
			for target in _edges(data, id):
				if finishing.has(target):
					finishing[id] = true
					changed = true
					break
	for id in data.scenes:
		if not reached.has(id): errors.append("scenes." + id + ": unreachable from chapter entry")
		if not finishing.has(id): errors.append("scenes." + id + ": no route to chapter completion")
		# A deterministic next_scene cycle cannot expose a new choice or result.
		var chain: Array = []
		var cursor: String = id
		while data.scenes.has(cursor):
			if chain.has(cursor):
				errors.append("scenes." + id + ": endless next_scene cycle")
				break
			chain.append(cursor)
			var next = data.scenes[cursor].get("next_scene")
			if not next is String: break
			cursor = next
	# Chapter prerequisites must be acyclic, even though all scene graphs are loaded.
	for id in data.chapters:
		var pending: Array = data.chapters[id].get("requires", []).duplicate() if data.chapters[id].get("requires", []) is Array else []
		var seen: Array = []
		while not pending.is_empty():
			var other = pending.pop_back()
			if other == id:
				errors.append("chapters." + id + ": cyclic prerequisites")
				break
			if seen.has(other) or not data.chapters.has(other): continue
			seen.append(other)
			if data.chapters[other].get("requires", []) is Array: pending.append_array(data.chapters[other].get("requires", []))
