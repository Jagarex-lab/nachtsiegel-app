extends Node
## QA-only exported entry scene: official native templates cannot execute --script.
## It uses the same packed catalog, model and policy; normal Linux QA keeps the game menu.
const Catalog=preload("res://scripts/production/catalog.gd")
const Model=preload("res://scripts/card_system/production_model.gd")
const Shell=preload("res://scripts/alpha/shell.gd")
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
	var menu=Shell.new()
	add_child(menu)
	for _frame in 3:await get_tree().process_frame
	var main_menu_verified: bool=menu.page=="lobby" and menu.actions.size()>=4
	check(main_menu_verified,"actual exported Alpha Shell starts in the main lobby")
	for action in {"start":"decks","collection":"collection","builder":"builder","settings":"settings"}:
		var control: Variant=menu.actions.get(action)
		var usable: bool=control is BaseButton and not control.disabled and not control.pressed.get_connections().is_empty()
		if usable:
			control.pressed.emit()
			for _frame in 2:await get_tree().process_frame
			usable=menu.page=={"start":"decks","collection":"collection","builder":"builder","settings":"settings"}[action]
		check(usable,"actual exported main menu action opens its page: "+action)
		main_menu_verified=main_menu_verified and usable
		menu.page="lobby";menu.render()
		for _frame in 2:await get_tree().process_frame
	menu.queue_free()
	for _frame in 2:await get_tree().process_frame
	print(JSON.stringify({"suite":"production_native_exported","assertions":assertions,"failures":failures,"winner":model.state.winner,"round":model.state.round,"catalog_fingerprint":catalog.fingerprint(),"main_menu_verified":main_menu_verified}))
	get_tree().root.get_node("GameAudio").request_quit(1 if failures else 0)
