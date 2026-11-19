extends SceneTree
## Genuine touch inspection/opening commands plus explicitly labelled text-layout checks.
## This is not a physical-device test and does not claim 550 played matches.
const Shell=preload("res://scripts/alpha/shell.gd")
const Catalog=preload("res://scripts/production/catalog.gd")
const Session=preload("res://scripts/alpha/session.gd")
const Face=preload("res://scripts/alpha/inspection_card.gd")
const Style=preload("res://scripts/alpha/style.gd")
const Art=preload("res://scripts/production/art_resolver.gd")
class PresentationShell extends Shell:
	func _checkpoint_duel() -> void:pass
var app
var assertions:=0
var failures:=0
func check(value: bool,label: String) -> void:
	assertions+=1
	if not value:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func settle() -> void:
	for frame in 6:await process_frame
func touch(at: Vector2,pressed: bool,canceled: bool=false) -> void:
	var event=InputEventScreenTouch.new();event.position=at;event.index=0;event.pressed=pressed;event.canceled=canceled
	Input.parse_input_event(event);await settle()
func tap(node: Control) -> void:
	var at=node.get_global_rect().get_center();await touch(at,true);await touch(at,false)
func gameplay() -> String:
	return Session.digest({"model":app.session.model.snapshot(),"events":app.session.model.events,"commands":app.session.commands,"rng":app.session.model.rng.state,"rng_calls":app.session.model.rng.calls})
func intent() -> String:
	return Session.digest({"selected":app.selected,"lane":app.source_lane,"mode":app.action_mode,"mulligan":app.mulligan_indices})
func bounded(node: Control) -> bool:
	return Rect2(Vector2.ZERO,Vector2(root.size)).grow(.2).encloses(node.get_global_rect())
func shot(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"):return
	DirAccess.make_dir_recursive_absolute("res://work/mobile-inspection")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://work/mobile-inspection/"+label+".png")
func run() -> void:
	root.size=Vector2i(844,390);app=PresentationShell.new();root.add_child(app);await settle()
	app.match_use_starter=true;app.faction="houses";app.session.profile.last_seed=23;app.start_battle();await settle()
	var before=gameplay();var before_intent=intent();var first=app.hand_views[0]
	await tap(first)
	check(is_instance_valid(app.modal) and app.inspector_face is Face,"first real hand tap opens the actual collectible card")
	check(app.inspector_card_id==app.session.model.state.hero.hand[0],"inspector owns the tapped original card ID")
	check(before==gameplay() and before_intent==intent(),"first inspection tap never marks, selects, pays or changes RNG/commands")
	check(app.actions.has("inspect_mulligan") and app.actions.modal_close.size.x>=44 and app.actions.modal_close.size.y>=44,"explicit mulligan mark and44CSSclose are reachable")
	await tap(app.actions.inspect_mulligan)
	check(app.mulligan_indices==[0] and app.selected==0 and before==gameplay(),"explicit mulligan action only marks the card, without an engine command")
	await tap(app.hand_views[0]);await tap(app.actions.inspect_mulligan)
	check(app.mulligan_indices.is_empty() and before==gameplay(),"explicit Keep reverses only the local mulligan mark")
	await tap(app.hand_views[1]);var snapshot=gameplay();var saved_intent=intent()
	for dimensions in [Vector2i(390,844),Vector2i(844,390),Vector2i(412,915),Vector2i(915,412),Vector2i(320,568),Vector2i(756,248)]:
		root.size=dimensions;await settle()
		check(is_instance_valid(app.modal) and app.modal.is_visible_in_tree(),"inspection remains visible across portrait/landscape: "+str(dimensions))
		check(bounded(app.inspector_face) and is_equal_approx(app.inspector_face.size.x/app.inspector_face.size.y,63.0/88.0),"whole undistorted card remains inside usable viewport: "+str(dimensions))
		check(bounded(app.actions.modal_close),"close remains within viewport: "+str(dimensions))
		check(snapshot==gameplay() and saved_intent==intent(),"rotation/inspection changes no gameplay or selection intent")
		check(app.inspector_face.inspection_report().rules_font_size>=13,"printed rules retain readable13CSSminimum")
		var face=app.inspector_face;var face_bounds=Rect2(Vector2.ZERO,face.size)
		for node in [face.attack_label,face.health_label,face.rarity_label]:
			check(face_bounds.encloses(node.get_rect()),"complete combat footer stays inside the card at short browser height")
			check(node.get_minimum_size().y<=node.size.y+.1,"footer text has its actual complete line height")
		check(face.attack_label.get_rect().end.y<=face.rarity_label.position.y and face.rules_scroll.get_rect().end.y<=face.attack_label.position.y,"rules, combat values and rarity never overlap")
		check(face.identity_label.get_rect().end.y<=face.rules_scroll.position.y,"power and type remain separate from ability text")
		await shot("inspection-%dx%d" % [dimensions.x,dimensions.y])
	root.size=Vector2i(844,390);await settle()
	# Touching the outside mask must dismiss and consume the same input packet.
	await touch(Vector2(5,5),true);await touch(Vector2(5,5),false)
	check(not is_instance_valid(app.modal) and snapshot==gameplay() and saved_intent==intent(),"outside tap closes read-only, without passing through to the battlefield")
	await tap(app.hand_views[0]);await touch(Vector2(5,5),true);await touch(Vector2(5,5),false,true)
	check(is_instance_valid(app.modal) and snapshot==gameplay(),"canceled outside tap cannot dismiss or issue an action")
	await tap(app.actions.modal_close)
	# Separate keyword help uses whole words: 'Heile' is not the Eile keyword.
	var healing=Catalog.new().card("of-houses-013")
	check(Style.keyword_terms(healing).has("heile") and not Style.keyword_terms(healing).has("eile"),"healing card never receives the unrelated Eile definition")
	check(not Style.card_keywords(healing).contains("Freier Gegenpfad"),"card help does not append an unrelated universal combat paragraph")
	app.inspect(healing);await settle();snapshot=gameplay();saved_intent=intent()
	check(app.inspector_rules.text==healing.description and not app.inspector_rules.text.contains("Eile:"),"only actual original ability text is printed on the card")
	await tap(app.actions.inspect_keywords)
	check(is_instance_valid(app.inspector_help) and app.inspector_help_text.text.contains("Heilung:") and not app.inspector_help_text.text.contains("Eile:"),"small separate help displays only related glossary entries")
	await tap(app.actions.inspect_help_close)
	check(is_instance_valid(app.modal) and not is_instance_valid(app.inspector_help) and snapshot==gameplay() and saved_intent==intent(),"closing help returns to the same actual card without changing any command")
	await tap(app.actions.modal_close)
	# Exact original commands, no forged model state, start the real battle.
	await tap(app.actions.mulligan_done);await tap(app.actions.origin_2)
	if app.session.model.state.stage=="second":
		await tap(app.actions.second_card_0)
		check(app.actions.has("inspect_select"),"second possibility also starts with card inspection")
		await tap(app.actions.inspect_select)
		check(app.selected==0 and not is_instance_valid(app.modal),"second-card selection needs a separate explicit inspector action")
		await tap(app.actions.opening_done)
	while app.session.model.state.hero.phase=="draw":
		var p: Dictionary=app.session.model.state.hero
		if p.hand.size()+mini(int(p.pendingDraw),p.deck.size())>6:
			await tap(app.hand_views[0]);await tap(app.actions.inspect_select)
		await tap(app.actions.end)
	var selected_card=-1;var chosen_lane=-1
	for index in app.session.model.state.hero.hand.size():
		var targets: Array=app.session.model.legal_targets("hero",index)
		if not targets.is_empty():selected_card=index;chosen_lane=int(targets[0]);break
	check(selected_card>=0,"original seeded session supplies a legal real-card play")
	if selected_card>=0:
		snapshot=gameplay();var commands=app.session.commands.size()
		await tap(app.hand_views[selected_card])
		check(is_instance_valid(app.modal) and snapshot==gameplay(),"combat tap only inspects before any play")
		await tap(app.actions.inspect_select)
		check(app.selected==selected_card and not is_instance_valid(app.modal) and snapshot==gameplay(),"explicit selection arms targets but never plays or pays")
		var card=app.session.card(app.session.model.state.hero.hand[selected_card])
		var target=app.actions.relic_slot if card.kind=="relic" else app.board_views[app.card_target_side(card)+str(chosen_lane)]
		await tap(target)
		check(app.session.commands.size()==commands+1 and app.session.commands[-1].name=="play","a subsequent real valid target emits exactly one existing play command")
		check(Session.replay(app.session.audit()).ok,"opening and explicit target play replay identically")
	# All550 original descriptions and mechanics are preserved. Hidden layout
	# probe intentionally does not fetch550 images or count these as played games.
	app.close_modal();var catalog=Catalog.new();var all_cards=catalog.all_cards();var mechanics: Array=[]
	for card in all_cards:mechanics.append(Catalog.mechanical_card(card))
	var original=Session.digest({"cards":mechanics})
	var text_probe=Face.new();text_probe.visible=false;root.add_child(text_probe)
	for dimensions in [Vector2(242,338),Vector2(366,366*88.0/63.0)]:
		text_probe.size=dimensions
		for card in all_cards:
			text_probe.card=card
			# Explicit text-only layout fixture: bypass the art request, not the
			# real normalized text or actual printed Controls. Real art is tested
			# above/from visible browser captures, not counted by these checks.
			text_probe._illustration_binding=Art.binding_key(card)
			text_probe._illustration_data={"texture":null,"status":"text_layout_only","label":""}
			text_probe._refresh_print();text_probe._fit_print()
			check(text_probe.rules_label.text==str(card.get("text_de",card.description)),"every complete source trigger/target/value/limit is preserved: "+card.id)
			check(text_probe.rules_label.get_theme_font_size("font_size")>=13,"every source ability uses readable13CSSminimum: "+card.id)
			check(Rect2(Vector2.ZERO,dimensions).encloses(text_probe.rules_scroll.get_rect()),"long rules scroll only within the original card outline: "+card.id)
	var after: Array=[]
	for card in all_cards:after.append(Catalog.mechanical_card(card))
	check(Session.digest({"cards":after})==original,"all550 full mechanical definitions remain byte-equivalent through presentation")
	text_probe.free()
	var longest=catalog.card("of-stillwatch-097")
	app.inspect(longest);await settle()
	var scrolling=app.inspector_face.rules_scroll;scrolling.scroll_vertical=100000;await settle()
	var report=app.inspector_face.inspection_report()
	check(report.rules_scroll.can_scroll and scrolling.scroll_vertical>0,"longest real relic text is reachable with inside-card scrolling")
	check(app.inspector_rules.text==longest.description and bounded(app.inspector_face),"scrolling retains the complete original text and visible card")
	await shot("longest-rules-scrolled")
	app.close_modal();app.queue_free();await settle()
	print("MOBILE CARD INSPECTION: %d assertions, %d failures; real tap/mark/close/help/rotation/selection/target/replay plus550 source-text layouts, no physical-device or550-match claim" % [assertions,failures])
	root.get_node("GameAudio").request_quit(1 if failures else 0)
