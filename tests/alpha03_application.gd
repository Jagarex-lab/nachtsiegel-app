extends SceneTree
const Shell=preload("res://scripts/alpha/shell.gd")
const Session=preload("res://scripts/alpha/session.gd")
const Services=preload("res://scripts/alpha/integrated_services.gd")
var assertions:=0
var failures:=0
var app
func check(ok: bool,label: String) -> void:
	assertions+=1
	if not ok:failures+=1;printerr("FAIL: "+label)
func settle() -> void:
	for i in 8:await process_frame
func clean(path: String) -> void:
	for suffix in ["", ".bak", ".tmp", ".corrupt"]:
		if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(path+suffix)
	if DirAccess.dir_exists_absolute(path+".lock"):DirAccess.remove_absolute(path+".lock")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(390,844)
	app=Shell.new();root.add_child(app);await settle()
	app.services.economy_path="user://alpha03_application_economy.json";clean(app.services.economy_path)
	for id in ["start","campaign","builder","collection","economy","online","settings"]:
		check(app.actions.has(id),"main navigation has real action "+id)
		if app.actions.has(id):check(app.actions[id].size.y>=44,"44px main touch target "+id)
	app.actions.economy.pressed.emit();await settle()
	check(app.page=="economy" and is_instance_valid(app.hosted_page),"main menu opens actual economy scene")
	check(app.services.economy.ready and app.services.economy.catalog.size()==550,"economy uses actual550")
	var economy=app.hosted_page
	var wallet=app.services.economy.snapshot().wallet.duplicate(true)
	for dimensions in [Vector2i(844,390),Vector2i(390,844),Vector2i(915,412)]:
		root.size=dimensions;app.render();await settle()
		check(app.hosted_page==economy,"rotation retains economy Control instance")
		check(app.services.economy.snapshot().wallet==wallet,"rotation cannot mint onboarding rewards")
		check(not app.outer_margin.visible,"underlying menu hidden while feature open")
	app.hosted_page.back_requested.emit();await settle()
	check(app.page=="lobby" and not is_instance_valid(app.hosted_page),"economy back returns to main menu")
	app.open_feature("campaign");await settle()
	check(app.page=="campaign" and app.hosted_page.manager.validation.ok,"actual campaign loads valid provisional content")
	var manager=app.hosted_page.manager
	var checkpoint=JSON.stringify(manager.state.data,"",true)
	root.size=Vector2i(390,844);app.render();await settle()
	check(app.hosted_page.manager==manager and JSON.stringify(manager.state.data,"",true)==checkpoint,"campaign panel/checkpoint survives host resize")
	app.hosted_page.exit_requested.emit();await settle()
	check(app.page=="lobby","campaign exit signal returns to main menu")
	check(root.get_node("GameAudio").snapshot().music.context=="menu","campaign exit restores actual menu music")
	app.open_feature("online");await settle()
	check(app.page=="online" and is_instance_valid(app.hosted_page),"actual online connection panel opens")
	app.hosted_page.back_requested.emit();await settle()
	check(app.page=="lobby","online back works without a public server")
	app.open_cards(true);await settle()
	check(app.library_total==550,"all550 remain visible independently of collectible ownership")
	app.page="lobby";app.render();await settle()
	app.start_battle();await settle()
	check(app.session.model.state.stage=="mulligan" and app.session.model.state.hero.hp==30,"AI play still starts real30HP on-board mulligan")
	check(not app.services.reward_completed_duel().ok,"unfinished AI match cannot grant completion reward")
	app.queue_free();await settle()
	clean("user://alpha03_application_economy.json")
	print("ALPHA03 APPLICATION: %d assertions, %d failures; actual hosted navigation, resize retention, real550 collection, AI entry; no simulated public multiplayer" % [assertions,failures])
	root.get_node("GameAudio").request_quit(1 if failures else 0)
