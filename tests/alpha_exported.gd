extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var catalog=load("res://scripts/alpha/catalog.gd").new()
	var legacy=load("res://scripts/legacy/catalog.gd").new()
	var model=load("res://scripts/alpha/model.gd").new()
	var ok: bool=catalog.all_cards().size()==55 and legacy.all_cards().size()==100 and model.start_alpha(catalog.deck("houses"),catalog.deck("stillwatch"),12345)
	ok=ok and model.state.hero.hp==30 and model.state.hero.hand.size()==5 and OS.has_feature("alpha_build") and str(ProjectSettings.get_setting_with_override("application/run/main_scene")).ends_with("alpha_shell.tscn")
	print("ALPHA EXPORTED: "+("PASS" if ok else "FAIL"))
	root.get_node("GameAudio").request_quit(0 if ok else 1)
