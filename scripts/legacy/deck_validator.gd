extends RefCounted
## Pure deck validation. Optional owned counts are caller-supplied facts,
## not a purchase/entitlement service. null means no ownership restriction.
const Catalog = preload("res://scripts/legacy/catalog.gd")
var _catalog: RefCounted
func _init() -> void:
	_catalog = Catalog.new()
func validate(deck: Variant, owned: Variant = null) -> Dictionary:
	if not deck is Array or deck.size()<20 or deck.size()>25:
		return _reject("deck_size","Deck benötigt 20–25 Kreaturen.")
	# The public domain is JSON arrays of string IDs and optional nonnegative
	# integer counts. Reject JS property-key coercions at this typed boundary.
	if owned!=null:
		if not owned is Dictionary: return _reject("ownership_format","Ungültiger Besitzbestand.")
		for id in owned:
			var count: Variant = owned[id]
			if not id is String or not (count is int or count is float):
				return _reject("ownership_format","Ungültiger Besitzbestand.")
			if not is_finite(float(count)) or float(count)<0 or float(count)!=floor(float(count)) or float(count)>9007199254740991.0:
				return _reject("ownership_format","Ungültiger Besitzbestand.")
	var counts: Dictionary = {}
	for id in deck:
		if not id is String or not _catalog.has_card(id):
			return _reject("unknown_card","Unbekannte Karte.")
		var card: Dictionary = _catalog.card(id)
		counts[id] = int(counts.get(id,0))+1
		var limit := 1 if card.rarity=="legendary" else 3
		if int(counts[id])>limit:
			return _reject("copy_limit","Kopienlimit überschritten.")
		if owned!=null and int(counts[id])>float(owned.get(id,0)):
			return _reject("not_owned","Karte nicht im Besitz.")
	return {"ok":true,"code":"","message":""}
func _reject(code: String, message: String) -> Dictionary:
	return {"ok":false,"code":code,"message":message}
