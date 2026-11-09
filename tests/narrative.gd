extends SceneTree
const Brand = preload("res://scripts/brand_identity.gd")
const Catalog = preload("res://scripts/narrative_catalog.gd")
var assertions := 0
var failures := 0
func check(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		printerr("FAIL: ",message)
func _initialize() -> void:
	check(Brand.display_name() == "NACHTSIEGEL","Release identity unchanged")
	check(Brand.preview_name("de").contains("ARBEITSTITEL"),"German draft label")
	check(Brand.preview_name("en").contains("WORKING TITLE"),"English draft label")
	check(Brand.preview_name("fr") == Brand.preview_name("de"),"Explicit preview fallback")
	var identity = Brand.definition()
	identity.legacy_product_name = "Unapproved"
	check(Brand.display_name() == "NACHTSIEGEL","Identity cannot be mutated through returned copy")
	check(Catalog.text("cards.ash_watch.name","de") == "Aschenwache","German card lookup")
	check(Catalog.text("cards.ash_watch.name","en") == "Ash Watch","English card lookup")
	check(Catalog.text("cards.ash_watch.name","en-GB") == "Ash Watch","Regional English locale")
	check(Catalog.text("cards.ash_watch.name","en_US") == "Ash Watch","Underscore locale")
	check(Catalog.text("cards.ash_watch.name","fr") == "Aschenwache","Unsupported locale falls back to German")
	check(Catalog.text("missing.key") == "[missing:missing.key]","Visible missing-key sentinel")
	check(Catalog.text("preview.greeting","en",{"hero":"Mara"}) == "Mara, who pays for your victory?","Named placeholder substitution")
	check(Catalog.entity("characters","mara").hero_candidate,"Stable hero entity lookup")
	check(Catalog.entity("cards","not_present").is_empty(),"Missing entity is empty")
	var copy = Catalog.manifest()
	copy.collections.cards.clear()
	check(Catalog.manifest().collections.cards.size() == 20,"Catalog cannot be mutated through returned copy")
	check(not Catalog.manifest().runtime_enabled,"Creative draft not activated in game")
	check(Catalog.entity("boss","boss_gauge_gate").status == "design_only_not_implemented","Boss not misrepresented as playable")
	for item in Catalog.manifest().collections.cards:
		for key in item.texts.values():
			check(not Catalog.text(key,"de").begins_with("[missing:"),"German runtime resource available")
			check(not Catalog.text(key,"en").begins_with("[missing:"),"English runtime resource available")
	print("NARRATIVE: %d assertions, %d failures; localized draft, immutable identity and resource loading" % [assertions,failures])
	quit(1 if failures else 0)
