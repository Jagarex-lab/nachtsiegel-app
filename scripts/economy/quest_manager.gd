extends RefCounted
## Receives normalized adapter events, never imports or observes the combat engine.
var config: Dictionary
var rewards: RefCounted
func _init(data: Dictionary, reward_service: RefCounted) -> void:
	config = data
	rewards = reward_service
func record(state: Dictionary, event: Dictionary) -> Dictionary:
	if event.get("type") not in config.quests.event_allowlist: return {"ok": false, "code": "unsupported_activity"}
	var day_value: Variant = event.get("day", -1)
	if not (day_value is int or day_value is float) or not is_finite(float(day_value)) or float(day_value) != floor(float(day_value)) or day_value < 0 or day_value > 1000000:
		return {"ok": false, "code": "invalid_day"}
	var day := int(day_value)
	if day < int(state.activity.day): return {"ok": false, "code": "clock_rewind"}
	if day != int(state.activity.day):
		state.activity.day = day
		state.activity.daily_gold = 0
		state.activity.daily_matches = 0
	var amount_value: Variant = event.get("amount", 1)
	if not (amount_value is int or amount_value is float) or not is_finite(float(amount_value)) or float(amount_value) != floor(float(amount_value)) or amount_value < 1 or amount_value > 1000:
		return {"ok": false, "code": "invalid_activity_amount"}
	var gold := 0
	if event.type == "match_completed":
		if amount_value != 1: return {"ok": false, "code": "invalid_match_amount"}
		state.activity.daily_matches += 1
		state.activity.matches += 1
		var match_reward: Dictionary = config.progression.match
		gold = mini(int(match_reward.gold), maxi(0, int(match_reward.daily_gold_cap) - int(state.activity.daily_gold)))
		state.activity.daily_gold += gold
		rewards.apply(state, {"gold": gold, "xp": int(match_reward.xp)})
		var protection: Dictionary = config.get("target_protection", {})
		if protection.get("enabled", false):
			for checkpoint in protection.checkpoints:
				var receipt := "target_path:" + str(int(checkpoint))
				if int(state.activity.matches) >= int(checkpoint) and receipt not in state.claimed_rewards:
					rewards.apply(state, {"crafting":int(protection.essence_per_checkpoint)})
					state.claimed_rewards.append(receipt)
	var granted: Array = []
	for quest_id in config.quests.definitions:
		var quest: Dictionary = config.quests.definitions[quest_id]
		if quest.event != event.type: continue
		var period := str(day if quest.get("period", "daily") == "daily" else int(day / 7))
		var key: String = str(quest_id) + ":" + period
		if state.quests.get(key, {}).get("claimed", false): continue
		var progress: Dictionary = state.quests.get(key, {"count": 0, "claimed": false})
		progress.count += int(amount_value)
		if int(progress.count) >= int(quest.target):
			progress.claimed = true
			rewards.apply(state, config.rewards.definitions[quest.reward])
			granted.append(quest_id)
		state.quests[key] = progress
	return {"ok": true, "gold": gold, "quests": granted}
