extends SceneTree
var arena
func _initialize() -> void:
	call_deferred("run")
func capture(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(path)
func run() -> void:
	arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
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
	quit()
