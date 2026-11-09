extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var source = load("res://scripts/arena.gd")
	if source == null or not source.can_instantiate(): finish_test(1); return
	for concept in ["ritual","table","mobile"]:
		for dimensions in [Vector2i(1600,900),Vector2i(844,390)]:
			root.size = dimensions
			var arena = load("res://scenes/arena.tscn").instantiate()
			arena.layout_concept = concept
			root.add_child(arena)
			arena._set_reduced_motion(true,false)
			arena.onboarding_step = 3
			arena.energy = 10
			arena.hand = [0,1,2,3,4,5]
			arena.allies = [arena.CARD_POOL[0].duplicate(true),null,arena.CARD_POOL[1].duplicate(true),null,arena.CARD_POOL[5].duplicate(true)]
			arena.foes = [null,arena.CARD_POOL[3].duplicate(true),arena.CARD_POOL[2].duplicate(true),arena.CARD_POOL[4].duplicate(true),null]
			arena.selected = 2
			arena._refresh()
			await process_frame; await process_frame
			arena.message_label.visible = false
			arena.info_label.visible = true
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://work/premium/concept-%s-%dx%d.png" % [concept,dimensions.x,dimensions.y])
			arena.queue_free(); await process_frame
	print("CONCEPTS: 3 live layouts, identical six-card state, 2 landscape sizes")
	finish_test()

func finish_test(code: int=0) -> void:
	root.get_node("GameAudio").request_quit(code)
