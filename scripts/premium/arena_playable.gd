extends "res://scripts/alpha/shell.gd"
## Developer-only playable variants. The normal start scene never routes here.
## All menu, four starter decks, opening, actions, AI, replay and result handling
## are inherited unchanged from the production Shell and its existing Session.
const CLI_MODES: Array[String] = ["flat","spatial","three_d"]

func _ready() -> void:
	var requested := "spatial"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--arena-mode="):requested=argument.get_slice("=",1)
	if requested not in CLI_MODES:
		push_error("Unknown developer arena variant: "+requested);get_tree().quit(1);return
	set("arena_mode",requested)
	super._ready()
