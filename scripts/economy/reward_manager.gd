extends RefCounted
var config: Dictionary
var collection: RefCounted
var progression: RefCounted
func _init(data: Dictionary, collection_service: RefCounted, progression_service: RefCounted) -> void:
	config = data
	collection = collection_service
	progression = progression_service
func apply(state: Dictionary, reward: Dictionary) -> Dictionary:
	state.wallet.gold += int(reward.get("gold", 0))
	state.wallet.crafting += int(reward.get("crafting", 0))
	progression.add_xp(state, int(reward.get("xp", 0)))
	for pool in reward.get("boosters", {}):
		state.boosters[pool] = int(state.boosters.get(pool, 0)) + int(reward.boosters[pool])
	var cards: Array = []
	for id in reward.get("cards", {}):
		cards.append_array(collection.add(state, id, int(reward.cards[id])))
	for key in ["cosmetics", "unlocks"]:
		for id in reward.get(key, []):
			if id not in state[key]: state[key].append(id)
	return {"ok": true, "cards": cards}
func claim(state: Dictionary, id: String) -> Dictionary:
	if not config.rewards.definitions.has(id): return {"ok": false, "code": "unknown_reward"}
	if id in state.claimed_rewards: return {"ok": false, "code": "reward_already_claimed"}
	var result := apply(state, config.rewards.definitions[id])
	state.claimed_rewards.append(id)
	return result
