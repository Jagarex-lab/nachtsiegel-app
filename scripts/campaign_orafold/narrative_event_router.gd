extends RefCounted
## Optional subscribers may route to the existing audio system; silence is valid.
signal narrative_event(event_name: String, payload: Dictionary)
const ALLOWED := ["story.scene_start","story.dialogue_advance","story.choice_selected","story.reveal","story.chapter_complete","story.battle_start","story.battle_complete"]
func publish(event_name: String, payload: Dictionary = {}) -> void:
	if event_name in ALLOWED: narrative_event.emit(event_name,payload.duplicate(true))
