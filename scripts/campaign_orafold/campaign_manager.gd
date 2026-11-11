extends RefCounted
## Standalone orchestration, independent of combat, production UI and old profiles.
signal changed
const State = preload("res://scripts/campaign_orafold/campaign_state.gd")
const Dialogue = preload("res://scripts/campaign_orafold/dialogue_manager.gd")
const Events = preload("res://scripts/campaign_orafold/narrative_event_router.gd")
const Rewards = preload("res://scripts/campaign_orafold/reward_adapter.gd")
const Validator = preload("res://scripts/campaign_orafold/campaign_validator.gd")
var content: Dictionary = {}
var state
var dialogue
var events = Events.new()
var rewards = Rewards.new()
var last_error := ""
var validation: Dictionary = {}
var bundle_path: String
var _loaded := false
var load_notice := ""

func _init(path: String = "res://data/campaign_orafold/prototype.json", save_path: String = State.DEFAULT_PATH) -> void:
	bundle_path = path
	state = State.new(save_path)
	load_notice = state.last_error
	var raw: Variant = _json(path)
	if raw is Dictionary: content = raw
	var locales := {"de":_json(path.get_base_dir()+"/locales/de.json"),"en":_json(path.get_base_dir()+"/locales/en.json")}
	for language in locales:
		if not locales[language] is Dictionary: locales[language] = {}
	dialogue = Dialogue.new(state,locales)
	dialogue.locale = str(state.data.settings.locale)
	validation = Validator.validate(raw,locales)
	if not validation.ok: last_error = "content.invalid"

static func _json(path: String) -> Variant:
	if not FileAccess.file_exists(path): return null
	var parser := JSON.new()
	return parser.data if parser.parse(FileAccess.get_file_as_string(path)) == OK else null

func load_campaign(id: String = "") -> bool:
	if not validation.get("ok",false): return _fail("content.invalid")
	if state.read_only: return _fail(state.last_error)
	var backup: Variant = _json(state.path+".bak")
	if backup is Dictionary and backup.get("format") == State.FORMAT and State._integer(backup.get("content_version")) and int(backup.content_version) > int(content.content_version):
		state.read_only = true
		return _fail("content.future_version")
	if int(state.data.content_version) > int(content.content_version):
		state.read_only = true
		return _fail("content.future_version")
	if id.is_empty(): id = str(content.default_campaign)
	if not content.campaigns.has(id): return _fail("campaign.unknown")
	var before: Dictionary = state.data.duplicate(true)
	if not state.data.active.is_empty() and state.data.active.get("campaign_id","") != id:
		_restore_replay()
		state.data.active = {}
		state.data.checkpoint = {}
	state.data.campaign_id = id
	state.data.content_version = int(content.content_version)
	_unlock_available()
	if not _active_valid(state.data.active):
		var was_replay: bool = state.data.active.get("replay",false)
		_restore_replay()
		state.data.active = state.data.checkpoint.duplicate(true) if not was_replay and not state.data.checkpoint.get("replay",false) and _active_valid(state.data.checkpoint) else {}
		state.data.checkpoint = state.data.active.duplicate(true)
	# Opening the menu must not overwrite corrupt evidence. A later explicit
	# chapter start can save a new run; the recovery notice stays visible.
	if load_notice == "save.invalid_data":
		_loaded = true
		last_error = load_notice
		return true
	_loaded = _commit(before)
	return _loaded

func _active_valid(active: Dictionary) -> bool:
	if active.is_empty(): return true
	if active.get("campaign_id","") != state.data.campaign_id: return false
	var chapter_id: String = str(active.get("chapter_id",""))
	var scene_id: String = str(active.get("scene_id",""))
	if not content.campaigns.has(active.get("campaign_id","")) or not content.chapters.has(chapter_id) or not content.scenes.has(scene_id): return false
	if not content.campaigns[active.campaign_id].chapters.has(chapter_id) or not content.chapters[chapter_id].scenes.has(scene_id): return false
	var battle: Dictionary = active.get("battle",{})
	return battle.is_empty() or (content.encounters.has(battle.get("encounter_id","")) and content.scenes[scene_id].get("encounter_id","") == battle.encounter_id)

func chapters() -> Array:
	var result: Array = []
	if not content.get("campaigns",{}).has(state.data.campaign_id): return result
	for id in content.campaigns[state.data.campaign_id].chapters:
		var chapter: Dictionary = content.chapters[id].duplicate(true)
		chapter.unlocked = state.data.unlocked_chapters.has(id) and Dialogue.conditions_met(_prerequisites(chapter),state.data)
		chapter.completed = state.data.completed_chapters.has(id)
		result.append(chapter)
	return result

static func _prerequisites(chapter: Dictionary) -> Array:
	var result: Array = []
	for id in chapter.get("requires",[]): result.append({"chapter_completed":id})
	return result

func _unlock_available() -> void:
	for id in content.campaigns[state.data.campaign_id].chapters:
		if Dialogue.conditions_met(_prerequisites(content.chapters[id]),state.data) and not state.data.unlocked_chapters.has(id): state.data.unlocked_chapters.append(id)

func current_scene() -> Dictionary:
	if state.data.active.is_empty(): return {}
	return content.scenes.get(state.data.active.get("scene_id",""),{}).duplicate(true)

func start_chapter(id: String, replay: bool = false) -> bool:
	if not _loaded or not content.campaigns.has(state.data.campaign_id) or not content.chapters.has(id) or not content.campaigns[state.data.campaign_id].chapters.has(id): return _fail("chapter.unknown")
	var chapter: Dictionary = content.chapters[id]
	if not state.data.unlocked_chapters.has(id) or not Dialogue.conditions_met(_prerequisites(chapter),state.data): return _fail("chapter.locked")
	if replay and (not state.data.completed_chapters.has(id) or not chapter.get("replayable",false)): return _fail("chapter.not_replayable")
	if not replay and state.data.completed_chapters.has(id): return _fail("chapter.use_replay")
	if not replay and state.data.active.get("chapter_id","") == id and not state.data.active.get("replay",false):
		changed.emit()
		return true
	var before: Dictionary = state.data.duplicate(true)
	_restore_replay()
	var baseline := {}
	if replay:
		for key in ["flags","decisions","relationships","character_info","unlocked_chapters"]: baseline[key] = state.data[key].duplicate(true)
	state.data.active = {"campaign_id":state.data.campaign_id,"chapter_id":id,"scene_id":"","battle":{},"replay":replay,"replay_baseline":baseline,"run_choices":{},"entered_scenes":[],"completed_scenes":[]}
	_enter(chapter.entry_scene)
	if not _commit(before): return false
	events.publish("story.scene_start",{"scene_id":chapter.entry_scene,"chapter_id":id})
	return true

func replay_chapter(id: String) -> bool:
	return start_chapter(id,true)

func available_choices() -> Array:
	var scene := current_scene()
	var result: Array = []
	if not scene.has("decision_id"): return result
	var decision: Dictionary = content.decisions[scene.decision_id]
	var taken: String = str(state.data.active.get("run_choices",{}).get(scene.decision_id,""))
	for choice in decision.choices:
		if (taken.is_empty() or taken == choice.id) and Dialogue.conditions_met(choice.get("conditions",[]),state.data): result.append(choice.duplicate(true))
	return result

func choose(choice_id: String) -> bool:
	var scene := current_scene()
	if not scene.has("decision_id") or not state.data.active.get("battle",{}).is_empty(): return _fail("choice.unavailable")
	for choice in available_choices():
		if choice.id != choice_id: continue
		var before: Dictionary = state.data.duplicate(true)
		_finish_scene(scene)
		if not state.data.active.run_choices.has(scene.decision_id):
			state.data.decisions[scene.decision_id] = choice.id
			state.data.active.run_choices[scene.decision_id] = choice.id
			_apply_effects(choice.get("effects",[]))
		_enter(choice.next_scene)
		if not _commit(before): return false
		events.publish("story.choice_selected",{"decision_id":scene.decision_id,"choice_id":choice_id})
		events.publish("story.scene_start",{"scene_id":choice.next_scene})
		return true
	return _fail("choice.unavailable")

func advance() -> bool:
	var scene := current_scene()
	if scene.is_empty() or scene.has("decision_id") or scene.has("encounter_id"): return _fail("scene.awaiting_input")
	var before: Dictionary = state.data.duplicate(true)
	_finish_scene(scene)
	var complete: bool = scene.get("complete_chapter",false)
	var chapter_id: String = state.data.active.chapter_id
	if complete:
		if not state.data.active.replay and not state.data.completed_chapters.has(chapter_id): state.data.completed_chapters.append(chapter_id)
		_restore_replay()
		state.data.active = {}
		state.data.checkpoint = {}
		_unlock_available()
	elif scene.has("next_scene"):
		_enter(scene.next_scene)
	else:
		state.data = before
		return _fail("scene.no_exit")
	if not _commit(before): return false
	events.publish("story.dialogue_advance",{"scene_id":scene.id})
	if complete: events.publish("story.chapter_complete",{"chapter_id":chapter_id})
	else: events.publish("story.scene_start",{"scene_id":scene.next_scene})
	return true

func request_battle() -> Dictionary:
	var scene := current_scene()
	if not scene.has("encounter_id"): _fail("battle.unavailable"); return {}
	var encounter: Dictionary = content.encounters[scene.encounter_id]
	if not state.data.active.get("battle",{}).is_empty():
		var resumed: Dictionary = encounter.duplicate(true)
		resumed.token = state.data.active.battle.token
		return resumed
	if not state.data.active.get("replay",false) and not encounter.get("repeatable",false) and state.data.encounters.get(encounter.id,{}).get("attempts",0) > 0: _fail("battle.not_repeatable"); return {}
	var before: Dictionary = state.data.duplicate(true)
	_finish_scene(scene)
	state.data.sequence = int(state.data.sequence)+1
	var token := "orafold-"+str(state.data.sequence)+"-"+str(encounter.id)
	state.data.active.battle = {"token":token,"encounter_id":encounter.id}
	# Safe checkpoint contains the token, so a reload can resume the same request.
	state.data.checkpoint = state.data.active.duplicate(true)
	if not _commit(before): return {}
	var request: Dictionary = encounter.duplicate(true)
	request.token = token
	events.publish("story.battle_start",request)
	return request

func resolve_battle(token: String, outcome: String) -> bool:
	if outcome not in ["victory","defeat"]: return _fail("battle.invalid_outcome")
	var battle: Dictionary = state.data.active.get("battle",{})
	if token.is_empty() or battle.get("token","") != token: return _fail("battle.stale_result")
	var encounter: Dictionary = content.encounters[battle.encounter_id]
	var before: Dictionary = state.data.duplicate(true)
	var stats: Dictionary = state.data.encounters.get(encounter.id,{"attempts":0,"victories":0,"defeats":0})
	stats.attempts = int(stats.attempts)+1
	var counter := "victories" if outcome == "victory" else "defeats"
	stats[counter] = int(stats[counter])+1
	stats.last_token = token
	stats.last_outcome = outcome
	state.data.encounters[encounter.id] = stats
	state.data.active.battle = {}
	var target: String = encounter.on_victory if outcome == "victory" else encounter.on_defeat
	_enter(target)
	if not _commit(before): return false
	events.publish("story.battle_complete",{"token":token,"outcome":outcome,"encounter_id":encounter.id})
	events.publish("story.scene_start",{"scene_id":target})
	return true

func _enter(scene_id: String) -> void:
	state.data.active.scene_id = scene_id
	state.data.active.battle = {}
	if not state.data.active.entered_scenes.has(scene_id):
		state.data.active.entered_scenes.append(scene_id)
		_apply_effects(content.scenes[scene_id].get("on_enter",[]))
	state.data.checkpoint = state.data.active.duplicate(true)

func _finish_scene(scene: Dictionary) -> void:
	dialogue.record(scene,state.data)
	if not state.data.active.completed_scenes.has(scene.id):
		state.data.active.completed_scenes.append(scene.id)
		_apply_effects(scene.get("on_complete",[]))

func _apply_effects(effects: Array) -> void:
	for effect in effects:
		match effect.type:
			"set_flag": state.data.flags[effect.key] = effect.value
			"relationship": state.data.relationships[effect.character_id] = clampi(int(state.data.relationships.get(effect.character_id,0))+int(effect.delta),-100,100)
			"unlock_info":
				if not state.data.character_info.has(effect.id): state.data.character_info.append(effect.id)
			"unlock_chapter":
				if not state.data.unlocked_chapters.has(effect.id): state.data.unlocked_chapters.append(effect.id)
			"reward":
				if not state.data.active.get("replay",false): rewards.stage(effect.id,content.rewards[effect.id],state.data)

func _restore_replay() -> void:
	if not state.data.active.get("replay",false): return
	var baseline: Dictionary = state.data.active.get("replay_baseline",{})
	for key in ["flags","decisions","relationships","character_info","unlocked_chapters"]:
		if baseline.has(key): state.data[key] = baseline[key].duplicate(true)

func character(id: String) -> Dictionary:
	if not content.get("characters",{}).has(id): return {}
	var result: Dictionary = content.characters[id].duplicate(true)
	var known: Array = []
	for entry in result.get("knowledge",[]):
		var public: bool = entry.get("visibility","private") == "public" and not result.get("protected",false)
		if not public and not state.data.character_info.has(entry.id): continue
		if Dialogue.conditions_met(entry.get("conditions",[]),state.data): known.append(entry)
	result.knowledge = known
	result.relationship = int(state.data.relationships.get(id,0))
	return result

func set_setting(key: String, value: Variant) -> bool:
	if not state.data.settings.has(key): return _fail("setting.unknown")
	var before: Dictionary = state.data.duplicate(true)
	state.data.settings[key] = value
	if not State.valid(state.data): state.data = before; return _fail("setting.invalid")
	if not _commit(before): return false
	dialogue.locale = str(state.data.settings.locale)
	return true

func acknowledge_reward(id: String, idempotency_key: String) -> bool:
	var before: Dictionary = state.data.duplicate(true)
	if not rewards.acknowledge(state.data,id,idempotency_key): return _fail("reward.invalid_acknowledgement")
	return _commit(before)

func _commit(before: Dictionary) -> bool:
	if not state.save():
		last_error = state.last_error
		state.data = before
		return false
	last_error = state.last_error
	dialogue.locale = str(state.data.settings.locale)
	changed.emit()
	rewards.publish_pending(state.data)
	return true

func _fail(code: String) -> bool:
	last_error = code
	return false
