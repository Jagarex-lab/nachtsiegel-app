extends RefCounted
## No resource sale, currency exchange or trade pathway exists in the local alpha.
const Collection = preload("res://scripts/economy/collection_manager.gd")
var config: Dictionary
var catalog: Dictionary
var collection: RefCounted
func _init(settings: Dictionary, cards: Dictionary) -> void:
	config = settings
	catalog = cards
	collection = Collection.new(config, catalog)
func craft(state: Dictionary, id: String) -> Dictionary:
	if not catalog.has(id): return {"ok":false,"code":"unknown_card"}
	var entry: Dictionary = state.collection.get(id, {"count":0})
	if int(entry.count) >= collection.cap(id): return {"ok":false,"code":"copy_limit"}
	var cost: int = int(config.crafting.costs[catalog[id].rarity])
	if int(state.wallet.crafting) < cost: return {"ok":false,"code":"insufficient_crafting"}
	state.wallet.crafting = int(state.wallet.crafting) - cost
	return {"ok":true,"cards":collection.add(state, id, 1, bool(config.crafting.get("crafting_output_bound", false))),"cost":cost}
func salvage(state: Dictionary, id: String, confirmed: bool = false) -> Dictionary:
	if not catalog.has(id): return {"ok":false,"code":"unknown_card"}
	if not confirmed: return {"ok":false,"code":"confirmation_required"}
	var entry: Dictionary = state.collection.get(id, {"count":0,"bound":0,"locked":false})
	if entry.locked: return {"ok":false,"code":"card_locked"}
	if int(entry.count) <= int(entry.bound): return {"ok":false,"code":"card_bound_or_missing"}
	if config.crafting.get("manual_preserve_deck_copies", false) and int(entry.count) <= int(state.get("reserved_copies", {}).get(id, 0)): return {"ok":false,"code":"card_reserved_for_deck"}
	var amount: int = int(config.crafting.salvage[catalog[id].rarity])
	entry.count = int(entry.count) - 1
	state.collection[id] = entry
	state.wallet.crafting = int(state.wallet.crafting) + amount
	return {"ok":true,"id":id,"crafting":amount}
