extends SceneTree
## Reproducible PRESENTATION fixture, never a gameplay/replay parity claim.
## Instantiates the actual Shell/CardView and records unchanged UI source hashes.
const Shell=preload("res://scripts/alpha/shell.gd")
const Catalog=preload("res://scripts/production/catalog.gd")
class PresentationShell extends Shell:
	# The deliberately arranged visual fixture is not a replayable game. Never
	# write its modified model into the active-duel save introduced by the PWA.
	func _checkpoint_duel() -> void:pass
var app
var output := "res://work/premium-mobile/before"
var records: Array=[]
var include_opening := false
var catalog=Catalog.new()
var chosen: Array=[]
func _initialize() -> void:call_deferred("run")
func settle(frames: int=8) -> void:
	for i in frames:await process_frame
func capture(label: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	var destination=output+"/"+label+".png"
	assert(root.get_texture().get_image().save_png(destination)==OK)
	var geometry: Dictionary={}
	for key in app.board_views:geometry[key]=rect_values(app.board_views[key].get_global_rect())
	var hand: Array=[]
	for view in app.hand_views:hand.append({"id":view.card.id,"rect":rect_values(view.get_global_rect()),"art":view.art_report()})
	records.append({"file":destination,"viewport":[root.size.x,root.size.y],"page":app.page,"modal":is_instance_valid(app.modal),"board":geometry,"hand":hand,"snapshot":app.session.model.snapshot() if app.session.model!=null else null})
func rect_values(rect: Rect2) -> Array:return [rect.position.x,rect.position.y,rect.size.x,rect.size.y]
func build_fixture() -> void:
	app.close_modal();app.faction="houses";app.mode="alpha";app.deck=catalog.deck("houses")
	assert(app.session.start_match("alpha",app.deck,22031,2,catalog.deck("ninth")))
	var model=app.session.model
	model.state.stage="battle";model.state.active="hero";model.state.coin="hero";model.state.round=9
	model.state.origins={"hero":2,"enemy":3}
	for side in ["hero","enemy"]:
		var player: Dictionary=model.state[side]
		player.phase="main";player.energy=6;player.resonance=9;player.hp=24 if side=="hero" else 19
		player.ward=3;player.block=2;player.turns=5;player.pendingDraw=0;player.pendingTarget=null;player.pendingShift=null
		for lane in 5:
			var offset=lane if side=="hero" else lane+5
			var unit=model.make_unit(side,catalog.card(chosen[offset]),lane)
			unit.summoned=false;unit.stun=1 if lane==4 else 0;unit.ward=2 if lane==1 else 0;unit.block=1 if lane==3 else 0
			player.lanes[lane]=unit
	model.state.hero.hand=chosen.slice(10,16)
	app.page="battle";app.selected=-1;app.action_mode="";app.source_lane=-1;app.render();await settle()
func capture_effect_families() -> Dictionary:
	# Three genuine Godot rasterizations use the SAME white pigment and age.
	# Distinct silhouettes therefore prove more than different faction colours.
	var viewport := SubViewport.new();viewport.size=Vector2i(512,160)
	viewport.disable_3d=true;viewport.world_2d=World2D.new()
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var ground := ColorRect.new();ground.size=Vector2(viewport.size);ground.color=Color("07111b");viewport.add_child(ground)
	var effects=preload("res://scripts/alpha/feedback.gd").new();viewport.add_child(effects)
	effects.set_process(false)
	var families := ["shield","block","heal"]
	var centers := [Vector2(86,70),Vector2(256,70),Vector2(426,70)]
	for index in families.size():
		effects.emit(families[index],centers[index],centers[index],Color.WHITE,"")
		var label := Label.new();label.text=["SCHILD","BLOCK","HEILUNG"][index]
		label.position=centers[index]+Vector2(-60,42);label.size=Vector2(120,28)
		label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.add_theme_font_size_override("font_size",16)
		viewport.add_child(label)
	await settle(3);await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var masks: Array=[];var measurements: Array=[]
	for index in families.size():
		var rectangle := Rect2i(Vector2i(centers[index])-Vector2i(32,32),Vector2i(64,64))
		var region := image.get_region(rectangle)
		var bright := 0
		for y in region.get_height():
			for x in region.get_width():
				if region.get_pixel(x,y).get_luminance()>.2:bright+=1
		assert(bright>8,"Actual defense silhouette must contain visible pixels")
		var digest := region.get_data().hex_encode().sha256_text()
		masks.append(digest);measurements.append({"kind":families[index],"bright_pixels":bright,"mask_sha256":digest})
	assert(masks[0]!=masks[1] and masks[0]!=masks[2] and masks[1]!=masks[2],"Shield/block/heal must have distinguishable geometry even with the same colour")
	var destination := output+"/effects-shield-block-heal.png"
	assert(image.save_png(destination)==OK)
	var result := {"file":destination,"viewport":[512,160],"same_pigment":true,"age":0,"families":measurements,"sha256":FileAccess.get_sha256(destination),"scope":"Actual offscreen Godot presentation fixture; no battle command, fake damage or physical-device claim."}
	viewport.queue_free();await settle()
	return result

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
		elif argument=="--include-opening":include_opening=true
	DirAccess.make_dir_recursive_absolute(output)
	# Fixed deterministic selection and full IDs are recorded, allowing the same
	# physical cards/state to be rendered before and after presentation changes.
	for power in ["houses","stillwatch","morph","ninth","neutral"]:
		for rarity in ["common","legendary"]:
			var eligible=catalog.all_cards().filter(func(card):return card.faction==power and card.rarity==rarity and card.kind=="creature")
			assert(not eligible.is_empty());chosen.append(eligible[0].id)
	for rarity in ["common","rare","epic","legendary"]:
		var eligible=catalog.all_cards().filter(func(card):return card.faction=="houses" and card.rarity==rarity)
		chosen.append(eligible[0].id)
	for kind in ["event","relic"]:
		var eligible=catalog.all_cards().filter(func(card):return card.faction=="houses" and card.kind==kind)
		chosen.append(eligible[0].id)
	app=PresentationShell.new();root.add_child(app);await settle()
	for dimensions in [Vector2i(844,390),Vector2i(852,393),Vector2i(932,430),Vector2i(1024,768),Vector2i(1600,900)]:
		root.size=dimensions;await settle();await build_fixture();await capture("battle-%dx%d" % [dimensions.x,dimensions.y])
		if dimensions==Vector2i(844,390):
			app.inspect(catalog.card(chosen[13]));await capture("inspection-844x390");app.close_modal()
			if include_opening:
				# Real opening commands, unlike the deliberately arranged full field.
				app.match_use_starter=true;app.session.profile.last_seed=23
				app.start_battle();await settle();await capture("opening-free-paths-844x390")
	root.size=Vector2i(390,844);await settle();app.page="lobby";app.render();await capture("menu-390x844")
	app.page="decks";app.render();await capture("starters-390x844")
	app.page="builder";app.collection_mode="alpha";app.collection_only=false;app.deck=catalog.deck("houses");app.render();await capture("deckbuilder-390x844")
	var effects_report := await capture_effect_families()
	var version: Array=[];assert(OS.execute("git",["rev-parse","HEAD"],version)==0)
	var manifest={"source_commit":str(version[0]).strip_edges(),"fixture_sha256":FileAccess.get_sha256("res://tools/premium/render_arena_qa.gd"),"shell_sha256":FileAccess.get_sha256("res://scripts/alpha/shell.gd"),"card_view_sha256":FileAccess.get_sha256("res://scripts/alpha/card_view.gd"),"catalog_sha256":FileAccess.get_sha256(Catalog.SOURCE_PATH),"godot":Engine.get_version_info().string,"scope":"Actual native Godot presentation fixture with deliberately arranged full fields and six hand cards. Not a legal game, browser test, performance benchmark or physical device test.","card_ids":chosen,"records":records,"effects_fixture":effects_report,"feedback_sha256":FileAccess.get_sha256("res://scripts/alpha/feedback.gd")}
	var file=FileAccess.open(output+"/manifest.json",FileAccess.WRITE);file.store_string(JSON.stringify(manifest,"  "));file.close()
	app.close_modal();app.queue_free();await settle()
	print("PREMIUM PRESENTATION: %d actual Shell captures; source and fixture hashes recorded" % records.size())
	root.get_node("GameAudio").request_quit(0)
