extends SceneTree
const Geometry=preload("res://scripts/premium/library_geometry.gd")
const Shell=preload("res://scripts/alpha/shell.gd")
class LibraryShell extends Shell:
	func _checkpoint_duel() -> void:pass
var assertions := 0
var failures := 0
func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
	assertions+=1
	if not value:failures+=1;printerr("FAIL: "+label)
func settle() -> void:
	for frame in 8:await process_frame
func tap(control: Control) -> void:
	var point=control.get_global_rect().get_center()
	for pressed in [true,false]:
		var event=InputEventScreenTouch.new();event.index=0;event.position=point;event.pressed=pressed;Input.parse_input_event(event)
		await settle()
func run() -> void:
	for desktop in [false,true]:
		for width in [156.0,292.0,362.0,508.0,611.0,775.0,965.0,1264.0]:
			var fitted=Geometry.fit(width,desktop)
			check(fitted.grid_width<=width,"grid stays within assigned pane")
			check(fitted.columns>=1 and fitted.columns<=(6 if desktop else 4),"bounded columns")
			check(fitted.card_width>=156 or width<156,"readable card width")
			check(absf(fitted.card_height*fitted.card_width**-1-88.0/63.0)<.01,"portrait63:88 geometry")
	check(Geometry.fit(362).columns==2,"390px phone has two collectible cards")
	check(Geometry.fit(611,true).columns<Geometry.fit(1264,true).columns,"desktop uses real pane width")
	for dimensions in [Vector2i(390,844),Vector2i(320,568),Vector2i(844,390),Vector2i(1280,720),Vector2i(1600,900)]:
		root.size=dimensions
		var app=LibraryShell.new();root.add_child(app);await settle()
		app.open_cards(true);await settle()
		check(app.library_total==550,"actual550 catalog remains reachable")
		check(app.library_visible_ids.size()<=(24 if dimensions.x>=1000 else 12),"page remains bounded")
		check(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(app.actions.library_next.get_global_rect()),"next page remains visible")
		var found_touch := false
		for id in app.library_visible_ids:
			var card: Control=app.actions["card_"+id]
			check(absf(card.size.y/card.size.x-88.0/63.0)<.02,"real card control retains portrait ratio")
			var clipped=card.get_global_rect().intersection(app._qa_clip_rect(card))
			if clipped.size.x>=44 and clipped.size.y>=44:found_touch=true
		check(found_touch,"clipped library includes a real44px touch area")
		if dimensions.x>=1000:
			app.collection_only=false;app.render();await settle()
			var pane_card: Control=app.actions["card_"+app.library_visible_ids[0]]
			check(pane_card.get_global_rect().end.x<=app.library_scroll.get_global_rect().end.x,"two-panel card fits actual library pane")
		# Search yields one tile: it must not stretch into a text-like strip.
		app.collection_only=true;app.filter_text="^exactly-no-match";app.render();await settle()
		check(app.library_total==0,"empty search remains functional")
		app.filter_text="";app.render();await settle()
		var name: String=app.alpha_catalog.card(app.library_visible_ids[0]).name
		app.filter_text=name;app.render();await settle()
		for id in app.library_visible_ids:
			var card: Control=app.actions["card_"+id]
			check(absf(card.size.y/card.size.x-88.0/63.0)<.02,"short search result keeps same portrait geometry")
		# Builder controls remain separately inspectable and reachable by normal
		# scrolling even where a full-height card cannot fit in one viewport.
		app.filter_text="";app.collection_only=false;app.deck=[];app.render();await settle()
		var add_id: String=app.library_visible_ids[0]
		app.actions["card_"+add_id].pressed.emit();await settle()
		check(app.deck.count(add_id)==1,"tap card still adds one legal copy")
		var details: Control=app.actions["detail_"+add_id]
		app.library_scroll.ensure_control_visible(details);await settle()
		var detail_clip=details.get_global_rect().intersection(app._qa_clip_rect(details))
		check(detail_clip.size.x>=44 and detail_clip.size.y>=44,"details reachable with actual44px clipped target after scrolling")
		app.actions["detail_"+add_id].pressed.emit();await settle()
		check(is_instance_valid(app.modal),"separate details action opens actual inspector")
		app.close_modal();app.queue_free();await settle()
	# One live library must shrink after a previous wide layout. Fresh instances
	# cannot catch a ScrollContainer feeding its old child minimum back into the
	# width measurement used to resize that same child.
	root.size=Vector2i(1280,720)
	var rotating=LibraryShell.new();root.add_child(rotating);await settle()
	rotating.open_cards(false);await settle()
	var retained_deck: Array=rotating.deck.duplicate()
	for dimensions in [Vector2i(915,412),Vector2i(320,568),Vector2i(393,852),Vector2i(844,390),Vector2i(390,844)]:
		root.size=dimensions;await settle()
		var viewport=Rect2(Vector2.ZERO,Vector2(dimensions))
		check(viewport.encloses(rotating.body.get_global_rect()),"existing library shrinks to actual viewport after rotation "+str(dimensions))
		check(viewport.encloses(rotating.library_scroll.get_global_rect()),"library pane never feeds old width into its parent "+str(dimensions))
		var horizontal=rotating.library_scroll.get_h_scroll_bar()
		check(horizontal.max_value<=horizontal.page+1,"fitted library has no hidden horizontal overflow after rotation")
		check(rotating.deck==retained_deck,"rotation never changes the current deck")
		for key in ["builder_back","search","search_apply","filters","save_deck","load_deck","reset_deck"]:
			check(viewport.encloses(rotating.actions[key].get_global_rect()),"real builder action remains in viewport: "+key+str(dimensions))
		if rotating.actions.has("builder_power"):
			var picker: Control=rotating.actions.builder_power
			check(viewport.encloses(picker.get_global_rect()),"power picker remains in narrow rotated viewport")
			if viewport.encloses(picker.get_global_rect()):
				await tap(picker)
				check(rotating.actions.has("builder_power_houses"),"real touch opens the constrained power picker")
				if rotating.actions.has("builder_power_houses"):
					await tap(rotating.actions.modal_close)
	rotating.queue_free();await settle()
	print("PREMIUM LIBRARY: %d assertions, %d failures" % [assertions,failures])
	var audio=get_root().get_node_or_null("GameAudio")
	if audio!=null:audio.request_quit(1 if failures else 0)
	else:quit(1 if failures else 0)
