extends Node
## QA-only exported entry scene: official native templates cannot execute --script.
## It uses the same packed catalog, model and policy; normal Linux QA keeps the game menu.
const Catalog=preload("res://scripts/production/catalog.gd")
const Model=preload("res://scripts/card_system/production_model.gd")
var assertions:=0
var failures:=0
func _ready() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
	assertions+=1
	if not value:failures+=1;printerr("FAIL: ",label)
func run() -> void:
	check(OS.has_feature("native_smoke_qa") and OS.has_feature("debug"),"explicit native debug QA feature")
	var catalog=Catalog.new()
	check(catalog.load_error.is_empty() and catalog.all_cards().size()==550,"all550 definitions actually included in export")
	for power in catalog.deck_ids():check(catalog.validate(catalog.deck(power)).ok,"exported starter "+power)
	check(FileAccess.file_exists("res://data/production/art_manifest.json"),"actual art manifest in exported resources")
	check(FileAccess.file_exists("res://assets/fonts/Cinzel-OFL.txt") and FileAccess.file_exists("res://assets/fonts/LICENSE"),"font redistribution licenses packaged")
	var model=Model.new()
	check(model.start_alpha(catalog.deck("morph"),catalog.deck("stillwatch"),777,2),"exported runtime starts real duel")
	check(model.mulligan([]),"exported mulligan")
	check(model.choose_origin(2),"exported origin")
	if model.state.stage=="second":check(model.finish_opening(),"exported second player opening")
	for _turn in 500:
		if model.state.winner!=null or not model.state.error.is_empty():break
		model.ai_turn("hero")
	check(model.state.winner!=null and model.state.error.is_empty(),"complete exported real AI duel without forced winner")
	print(JSON.stringify({"suite":"production_native_exported","assertions":assertions,"failures":failures,"winner":model.state.winner,"round":model.state.round,"catalog_fingerprint":catalog.fingerprint()}))
	get_tree().root.get_node("GameAudio").request_quit(1 if failures else 0)
