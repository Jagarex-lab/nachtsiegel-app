extends RefCounted
var config: Dictionary
func _init(data: Dictionary) -> void:
	config = data
func level_for(xp: int) -> int:
	var curve: Dictionary = config.progression.xp_curve
	var level := 1
	var remaining := xp
	while level < int(curve.max_level):
		var needed := int(curve.base) + int(curve.per_level) * (level - 1)
		if remaining < needed: break
		remaining -= needed
		level += 1
	return level
func add_xp(state: Dictionary, amount: int) -> void:
	var previous: int = state.progression.level
	state.progression.xp += amount
	state.progression.level = level_for(int(state.progression.xp))
	var levels: int = state.progression.level - previous
	state.wallet.gold += levels * int(config.progression.level_reward.get("gold", 0))
