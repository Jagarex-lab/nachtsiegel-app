extends RefCounted
## Pure collection mutation. The transaction coordinator persists the entire draft.
var config: Dictionary
var catalog: Dictionary
func _init(settings: Dictionary, cards: Dictionary) -> void:
	config = settings
	catalog = cards
func cap(id: String) -> int:
	if not catalog.has(id): return 0
	return int(config.collection_rules.copy_limits.get(catalog[id].rarity, 0))
func add(state: Dictionary, id: String, count: int = 1, bound: bool = false) -> Array:
	var results: Array = []
	if not catalog.has(id) or count < 1: return results
	var rarity: String = catalog[id].rarity
	var entry: Dictionary = state.collection.get(id, {"count":0,"bound":0,"locked":false}).duplicate(true)
	for _i in range(count):
		var duplicate: bool = int(entry.count) > 0
		var converted := 0
		if int(entry.count) < cap(id):
			entry.count = int(entry.count) + 1
			if bound: entry.bound = int(entry.bound) + 1
		elif not bound:
			converted = int(config.crafting.salvage[rarity])
			state.wallet.crafting = int(state.wallet.crafting) + converted
		results.append({"id":id,"rarity":rarity,"duplicate":duplicate,"converted":converted,"bound":bound})
	state.collection[id] = entry
	return results
func playable_count(state: Dictionary) -> int:
	var total := 0
	for id in state.collection:
		total += mini(int(state.collection[id].count), cap(id))
	return total
func summary(state: Dictionary) -> Dictionary:
	var unique := 0
	var by_rarity := {"common":0,"rare":0,"epic":0,"legendary":0}
	for id in state.collection:
		if int(state.collection[id].count) > 0:
			unique += 1
			by_rarity[catalog[id].rarity] += int(state.collection[id].count)
	return {"unique":unique,"catalog_size":catalog.size(),"playable_copies":playable_count(state),"by_rarity":by_rarity}
