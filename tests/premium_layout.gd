extends SceneTree
const T = preload("res://scripts/ui_tokens.gd")
var assertions := 0
var failures := 0
func check(value: bool, reason: String) -> void:
	assertions += 1
	if not value: failures += 1; printerr("FAIL: ",reason)
func polygon(control: Control, rect: Rect2) -> PackedVector2Array:
	var result = PackedVector2Array()
	for p in [rect.position,rect.position+Vector2(rect.size.x,0),rect.end,rect.position+Vector2(0,rect.size.y)]: result.append(control.get_global_transform()*p)
	return result
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var source = load("res://scripts/arena.gd")
	if source == null or not source.can_instantiate(): quit(1); return
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena._set_reduced_motion(true,false)
	arena.onboarding_step = 3
	for dimensions in [Vector2i(844,390),Vector2i(915,412),Vector2i(1280,720),Vector2i(1600,900)]:
		root.size = dimensions
		await process_frame; await process_frame
		arena.hand = [0,1,2,3,4,5]
		arena.energy = 10
		arena.selected = -1
		arena.allies = [null,null,null,null,null]
		arena.foes = [null,null,null,null,null]
		arena._refresh()
		await process_frame; await RenderingServer.frame_post_draw
		var viewport = Rect2(Vector2.ZERO,Vector2(dimensions))
		var first = arena.lane_faces[0].get_global_rect()
		var last = arena.lane_faces[4].get_global_rect()
		check((last.end.x-first.position.x)/dimensions.x >= .70,"Battlefield uses landscape width "+str(dimensions))
		for i in 5:
			check(absf(arena.foe_faces[i].get_global_rect().get_center().x-arena.lane_faces[i].get_global_rect().get_center().x)<first.size.x*.5,"Same path stays visually paired")
		for control in arena.hero_medallions+[arena.end_button,arena.help_button]:
			check(control.get_global_rect().size.x>=44 and control.get_global_rect().size.y>=44,"Hero/main action touch dimensions")
		for selection in [0,2,5]:
			arena._select_card(selection)
			await process_frame; await process_frame
			arena.notification_clock = .001
			await create_timer(.03).timeout
			await RenderingServer.frame_post_draw
			check(arena.card_buttons[selection].scale.x>=1.2,"Selection enlarged at least 20 percent")
			check(arena.info_label.visible and arena.info_label.text==arena.CARD_POOL[arena.hand[selection]].name,"Full selected identity in header")
			for card in arena.card_buttons:
				for p in polygon(card,Rect2(Vector2.ZERO,card.size)):check(viewport.has_point(p),"Selected/fanned corner inside viewport")
				for sample in card.contrast_samples():
					if sample.role=="card name (focus available)":
						var full = T.FONT.get_string_size(str(card.data.name),HORIZONTAL_ALIGNMENT_LEFT,-1,T.font_size(20,arena.ui_scale,12)).x
						check(sample.rect.size.x>=full-.1,"Full six-card names at required viewports")
					if not sample.role in ["energy cost","attack or spell damage","health","card name (focus available)"]: continue
					var ink = polygon(card,sample.rect)
					for other in arena.card_buttons:
						if other==card or other.z_index<card.z_index: continue
						check(Geometry2D.intersect_polygons(ink,polygon(other,Rect2(Vector2.ZERO,other.size))).is_empty(),"Critical hand information not covered by neighboring card")
					for action in [arena.end_button,arena.detail_button]:
						check(Geometry2D.intersect_polygons(ink,polygon(action,Rect2(Vector2.ZERO,action.size))).is_empty(),"Hand info clear of command actions")
	print("PREMIUM: %d assertions, %d failures; 4 landscape sizes; six cards, selection and actual ink visibility" % [assertions,failures])
	quit(1 if failures else 0)
