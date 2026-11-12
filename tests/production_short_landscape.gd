extends SceneTree
## Explicit LAYOUT FIXTURE: six real catalog IDs and ten populated unit slots are
## arranged for rendering only. It is not counted as a played duel or legal
## transition. The browser companion reaches six cards via actual turn commands.
const Shell=preload("res://scripts/alpha/shell.gd")
class PresentationShell extends Shell:
	# Arranged layout states are not replayable games and must not be saved.
	func _checkpoint_duel() -> void:pass
const Session=preload("res://scripts/alpha/session.gd")
var app
var safe_host: Control
var assertions:=0
var failures:=0
var captures: Array=[]
var lifecycle_metrics: Array=[]
const OUT="res://work/production-short-landscape"
func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
	assertions+=1
	if not value:failures+=1;printerr("FAIL: ",label)
func settle() -> void:
	for frame in 6:await process_frame
func tap(control: Control) -> void:
	var at=control.get_global_rect().get_center()
	var event=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=true;Input.parse_input_event(event);await settle()
	event=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=false;Input.parse_input_event(event);await settle()
func geometry(dimensions: Vector2i,bottom: float=0.0) -> void:
	root.size=dimensions
	if dimensions.x>dimensions.y:
		safe_host.position=Vector2(44,0);safe_host.size=Vector2(dimensions.x-88,dimensions.y-bottom)
	else:safe_host.position=Vector2.ZERO;safe_host.size=Vector2(dimensions)
	await settle()
	app.render();await settle()
func in_safe(control: Control,safe: Rect2,label: String) -> void:
	var rect=control.get_global_rect()
	check(rect.size.x>=43.9 and rect.size.y>=43.9,label+" remains44CSS")
	check(safe.grow(.1).encloses(rect),label+" inside simulated safe area "+str(rect)+" in "+str(safe))
func screenshot(name: String) -> void:
	await settle();await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image();var path=OUT.path_join(name+".png")
	check(image.get_width()==root.size.x and image.get_height()==root.size.y,"native capture dimensions "+name)
	check(image.save_png(path)==OK,"real rendered screenshot "+name);captures.append(path)
func fixture_battle() -> void:
	var model=app.session.model;var source: Array=app.alpha_catalog.all_cards()
	var candidates: Array=[]
	for c in source:
		if c.faction in ["houses","neutral"]:candidates.append(c)
	candidates.sort_custom(func(a,b):return str(a.name).length()>str(b.name).length())
	model.state.stage="battle";model.state.active="hero";model.state.round=11
	model.state.origins={"hero":2,"enemy":2};model.state.origin_used={"hero":true,"enemy":true}
	for side in ["hero","enemy"]:
		var p: Dictionary=model.state[side];p.phase="main";p.pendingDraw=0;p.drawDone=true;p.pendingTarget=null;p.pendingShift=null;p.energy=8;p.resonance=15;p.lanes=[null,null,null,null,null]
		var pool: Array=[]
		for c in source:
			if c.kind=="creature" and c.faction in (["houses","neutral"] if side=="hero" else ["stillwatch","neutral"]):pool.append(c)
		pool.sort_custom(func(a,b):return str(a.name).length()>str(b.name).length())
		for lane in 5:
			var unit: Dictionary=model.make_unit(side,pool[lane],lane);unit.summoned=false;unit.ward=2;unit["block"]=3
			if lane==3:unit.stun=1
			p.lanes[lane]=unit
	model.state.hero.hand=[]
	for index in 6:model.state.hero.hand.append(candidates[index].id)
	app.selected=-1;app.source_lane=-1;app.action_mode="";app.render();await settle()
func controls(label: String,safe: Rect2) -> void:
	check(not app.actions.has("rotate_menu"),label+" usable landscape is not blocked by orientation guard")
	check(app.short_landscape,label+" production short tier selected")
	check(app.board_views.size()==10 and app.hand_views.size()==6,label+" ten units and all six real hand cards rendered")
	for id in ["menu","end","actions","inspect"]:
		check(app.actions.has(id),label+" primary/secondary action exists "+id)
		if app.actions.has(id):in_safe(app.actions[id],safe,label+" "+id)
	for key in app.board_views:
		in_safe(app.board_views[key],safe,label+" board "+str(key))
		var marks=app.board_views[key].board_status()
		check(marks.shield==2 and marks.block==3,label+" shield and block remain separate "+str(key))
	for view in app.hand_views:
		in_safe(view,safe,label+" hand "+view.card.id)
		var face=view.layout_report()
		check(face.role=="hand" and is_equal_approx(view.size.x/view.size.y,63.0/88.0),label+" genuine portrait hand, not a text strip "+view.card.id)
		check(face.outer.encloses(face.stats) and face.stats.size.y>=16,label+" separate bounded value/type footer "+view.card.id)
		check(face.title.end.y<=face.stats.position.y+.1,label+" name zone never overlaps current values "+view.card.id)
func lifecycle_checks() -> void:
	# Repeated real UI transitions, with the labelled layout state held fixed.
	# Warm once before comparing native resource counts; no font-cache clearing.
	var before=Session.digest(app.session.model.snapshot());var command_count=app.session.commands.size()
	var warm: Dictionary={}
	for cycle in 6:
		app.inspect(app.session.card(app.session.model.state.hero.hand[0]));await settle()
		check(is_instance_valid(app.modal),"lifecycle inspector opens "+str(cycle))
		app.close_modal();await settle()
		app.page="lobby";app.render();await settle()
		app.page="battle";app.render();await settle()
		var metrics={"cycle":cycle,"objects":int(Performance.get_monitor(Performance.OBJECT_COUNT)),"resources":int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),"orphans":int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),"texture_bytes":int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)),"art":preload("res://scripts/production/art_resolver.gd").stats()}
		lifecycle_metrics.append(metrics)
		if cycle==1:warm=metrics
		elif cycle>1:
			check(metrics.objects<=warm.objects+8,"native objects bounded across battle/inspector cycles "+str(cycle))
			check(metrics.resources<=warm.resources+2,"native resources bounded across battle/inspector cycles "+str(cycle))
			check(metrics.orphans<=warm.orphans,"no new orphan nodes across battle/inspector cycles "+str(cycle))
			check(metrics.texture_bytes<=warm.texture_bytes+1048576,"native texture memory bounded across battle/inspector cycles "+str(cycle))
		check(Session.digest(app.session.model.snapshot())==before and app.session.commands.size()==command_count,"lifecycle presentation never mutates model "+str(cycle))
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	safe_host=Control.new();root.add_child(safe_host);safe_host.size=Vector2(root.size)
	app=PresentationShell.new();safe_host.add_child(app);await settle()
	for item in [{"height":270,"bottom":21},{"height":249,"bottom":0},{"height":248,"bottom":0}]:
		await geometry(Vector2i(844,int(item.height)),float(item.bottom));app.page="lobby";app.render();await settle();app.start_battle();await settle()
		var safe=Rect2(44,0,756,float(item.height)-float(item.bottom))
		check(app.session.model.state.stage=="mulligan","real initial opening stage")
		check(app.board_views.size()==10 and app.hand_views.size()==5,"short opening still uses actual battlefield and five cards")
		for key in app.board_views:in_safe(app.board_views[key],safe,"opening "+str(item.height)+" "+str(key))
		for view in app.hand_views:in_safe(view,safe,"opening "+str(item.height)+" "+view.card.id)
		in_safe(app.actions.mulligan_done,safe,"opening confirmation");in_safe(app.actions.menu,safe,"opening menu")
		await screenshot("opening-844x"+str(item.height))
		await fixture_battle()
		var before=Session.digest(app.session.model.snapshot());var count=app.session.commands.size()
		controls("844x"+str(item.height),safe)
		await tap(app.actions.actions)
		for id in ["log","restart"]:
			check(app.actions.has(id),"secondary control reachable through More: "+id)
			in_safe(app.actions[id],safe,"More "+id)
		await tap(app.actions.modal_close)
		await tap(app.hand_views[0]);await settle();check(app.selected==0,"actual short-hand touch selects card")
		await tap(app.actions.inspect);check(is_instance_valid(app.modal),"actual short inspector opens");in_safe(app.actions.modal_close,safe,"short inspector close");await tap(app.actions.modal_close)
		await tap(app.actions.menu);check(is_instance_valid(app.modal),"actual safe menu opens through touch");in_safe(app.actions.modal_close,safe,"short menu close");await tap(app.actions.modal_close)
		check(Session.digest(app.session.model.snapshot())==before and app.session.commands.size()==count,"short touch/inspection/menu never mutate fixture combat")
		await screenshot("battle-six-hand-ten-units-844x"+str(item.height))
		await geometry(Vector2i(390,844))
		check(app.actions.has("rotate_menu") and app.board_views.is_empty(),"portrait keeps intentional orientation guard")
		check(Session.digest(app.session.model.snapshot())==before and app.session.commands.size()==count,"portrait roundtrip preserves all model fields")
		await geometry(Vector2i(844,int(item.height)),float(item.bottom))
		check(Session.digest(app.session.model.snapshot())==before and app.board_views.size()==10,"returning to short landscape restores ten fields without a command")
	await lifecycle_checks()
	# The honest below-minimum message keeps a reachable safe menu, not a false
	# request to rotate an already horizontal viewport.
	await geometry(Vector2i(844,247))
	check(app.actions.has("rotate_menu") and app.board_views.is_empty(),"247px insufficient height uses explicit space guard")
	in_safe(app.actions.rotate_menu,Rect2(44,0,756,247),"below-minimum pinned safe menu")
	app.close_modal();app.queue_free();app=null;safe_host.queue_free();safe_host=null;await settle()
	preload("res://scripts/production/art_resolver.gd").clear_cache()
	await settle()
	print(JSON.stringify({"suite":"production_short_landscape","assertions":assertions,"failures":failures,"scope":"labelled layout fixture, not a full duel or physical iPhone test","cases":["844x270/safe756x249","844x249/safe756x249","844x248/safe756x248","portrait roundtrip","247px pinned-menu guard"],"screenshots":captures,"lifecycle_metrics":lifecycle_metrics}))
	root.get_node("GameAudio").request_quit(1 if failures else 0)
