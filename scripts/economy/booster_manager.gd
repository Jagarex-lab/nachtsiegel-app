extends RefCounted
## Deterministic, persisted RNG; outputs are committed before any reveal animation.
const Collection = preload("res://scripts/economy/collection_manager.gd")
const RARITIES = ["common", "rare", "epic", "legendary"]
var config: Dictionary
var catalog: Dictionary
var collection: RefCounted
func _init(settings: Dictionary, cards: Dictionary) -> void:
	config = settings
	catalog = cards
	collection = Collection.new(config, catalog)
func _pool_cards(pool: String, rarity: String) -> Array:
	var result: Array = []
	var definition: Dictionary = config.booster_pools.pools.get(pool, {})
	var filter: Dictionary = definition.get("card_filter", {})
	for id in catalog:
		var card: Dictionary = catalog[id]
		if card.rarity != rarity: continue
		if filter.has("faction") and card.get("faction", "") != filter.faction: continue
		if filter.has("set") and card.get("set", "") != filter.set: continue
		if filter.has("ids") and id not in filter.ids: continue
		result.append(id)
	result.sort()
	return result
func validate_pool(pool: String) -> bool:
	var definition: Dictionary = config.booster_pools.pools.get(pool, {})
	if definition.is_empty() or not definition.get("enabled", false): return false
	for rarity in RARITIES:
		if _pool_cards(pool, rarity).is_empty(): return false
	return true
func _random(state: Dictionary) -> float:
	state.rng = (1664525 * int(state.rng) + 1013904223) & 0xffffffff
	return float(state.rng) / 4294967296.0
func _rarity(state: Dictionary, rates: Dictionary) -> String:
	var roll := _random(state)
	var cumulative := 0.0
	for rarity in RARITIES:
		cumulative += float(rates.get(rarity, 0.0))
		if roll < cumulative: return rarity
	return "legendary"
func buy(state: Dictionary, pool: String = "standard") -> Dictionary:
	if not validate_pool(pool): return {"ok":false,"code":"invalid_pool"}
	var price: int = int(config.booster_pools.pools[pool].price_gold)
	if int(state.wallet.gold) < price: return {"ok":false,"code":"insufficient_gold"}
	state.wallet.gold = int(state.wallet.gold) - price
	state.boosters[pool] = int(state.boosters.get(pool, 0)) + 1
	return {"ok":true,"pool":pool,"price_gold":price}
func open(state: Dictionary, pool: String = "standard") -> Dictionary:
	if not validate_pool(pool): return {"ok":false,"code":"invalid_pool"}
	if int(state.boosters.get(pool, 0)) < 1: return {"ok":false,"code":"missing_booster"}
	var rarities: Array = []
	for slot in config.booster_rules.slots:
		for _i in range(int(slot.count)):
			rarities.append(_rarity(state, slot.rates))
	var pity: Dictionary = state.pity.get(pool, {"epic":0,"legendary":0}).duplicate(true)
	var forced := ""
	if not rarities.has("legendary") and int(pity.legendary) + 1 >= int(config.booster_rules.pity.legendary):
		rarities[-1] = "legendary"
		forced = "legendary"
	elif not rarities.has("legendary") and not rarities.has("epic") and int(pity.epic) + 1 >= int(config.booster_rules.pity.epic):
		rarities[-1] = "epic"
		forced = "epic"
	pity.legendary = 0 if rarities.has("legendary") else int(pity.legendary) + 1
	pity.epic = 0 if rarities.has("legendary") or rarities.has("epic") else int(pity.epic) + 1
	var cards: Array = []
	for rarity in rarities:
		var choices := _pool_cards(pool, rarity)
		if rarity in config.booster_rules.duplicate_protection:
			var missing: Array = []
			for id in choices:
				if int(state.collection.get(id, {"count":0}).count) < collection.cap(id): missing.append(id)
			if not missing.is_empty(): choices = missing
		var index: int = mini(int(_random(state) * choices.size()), choices.size() - 1)
		cards.append_array(collection.add(state, str(choices[index])))
	state.boosters[pool] = int(state.boosters[pool]) - 1
	state.pity[pool] = pity
	return {"ok":true,"pool":pool,"cards":cards,"pity":pity.duplicate(true),"forced":forced}
