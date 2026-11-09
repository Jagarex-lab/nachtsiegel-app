extends SceneTree
var arena
func _initialize() -> void:
	call_deferred("run")
func capture(path: String) -> void:
	await create_timer(0.4).timeout
	await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(path)
func run() -> void:
	var source = load("res://scripts/arena.gd")
	if source == null or not source.can_instantiate():
		printerr("FAIL: Arena cannot instantiate")
		finish_test(1)
		return
	arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena._set_reduced_motion(false,false)
	arena.onboarding_step = 0
	arena._introduce()
	await create_timer(0.6).timeout
	await capture("res://work/arena-initial.png")
	arena.hand = [0,1,2,3,4,5]
	arena.energy = 10
	arena.allies = [arena.CARD_POOL[0].duplicate(true),null,arena.CARD_POOL[1].duplicate(true),null,arena.CARD_POOL[5].duplicate(true)]
	arena.foes = [null,arena.CARD_POOL[3].duplicate(true),arena.CARD_POOL[2].duplicate(true),arena.CARD_POOL[4].duplicate(true),null]
	arena._refresh()
	await capture("res://work/arena-battle.png")
	arena._select_card(2)
	await capture("res://work/arena-selected.png")
	arena._show_card()
	await capture("res://work/card-inspection.png")
	arena._close_modal()
	arena.hand = [0,1,2,3,4,5]
	arena._refresh()
	await capture("res://work/arena-six-cards.png")
	arena.hand = [6]
	arena.energy = 10
	arena.selected = -1
	arena.foes[0] = arena.CARD_POOL[0].duplicate(true)
	arena._refresh()
	arena._select_card(0)
	await process_frame
	await process_frame
	arena._choose_lane(0)
	await capture("res://work/spell-impact.png")
	finish_test()

func finish_test(code: int=0) -> void:
	root.get_node("GameAudio").request_quit(code)
