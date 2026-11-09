extends SceneTree
## MovieMaker driver: actual GUI touches and legal commands, no artificial health/victory.
const Bot=preload("res://tests/auto_player.gd")
var app
var game
func _initialize() -> void:call_deferred("run")
func pause(seconds: float) -> void:await create_timer(seconds).timeout
func tap(control: Control) -> void:
	var p=control.get_global_rect().get_center()
	var event=InputEventScreenTouch.new();event.position=p;event.pressed=true;Input.parse_input_event(event);await process_frame
	event=InputEventScreenTouch.new();event.position=p;event.pressed=false;Input.parse_input_event(event);await process_frame;await process_frame
func run() -> void:
	root.size=Vector2i(1280,720)
	app=load("res://scenes/front_end.tscn").instantiate()
	app.store=preload("res://scripts/progress_store.gd").new("user://qa_movie.json");app.store.data=app.store.defaults();root.add_child(app)
	await pause(.6);await tap(app.actions.begin);await pause(.6);await tap(app.actions.intro_skip);await pause(.6);await tap(app.actions.start_tutorial)
	game=app.battle_node;game._set_reduced_motion(false,false);await pause(.5)
	for turn in 22:
		if game.finished:break
		for move in 8:
			var action=Bot.choice(game.battle)
			if action.index<0 or action.score<0:break
			await tap(game.card_buttons[action.index]);await pause(.2)
			await tap(game.foe_faces[action.lane] if game.CARD_POOL[game.hand[action.index]].kind=="spell" else game.lane_buttons[action.lane]);await pause(.45)
		await tap(game.end_button)
		while game.busy:await process_frame
		await pause(.4)
	await pause(1.4)
	if not game.finished:printerr("FAIL: Movie did not reach a genuine outcome");finish_test(1);return
	print("MOVIE: ",game.battle.result,"; actual touch tutorial; ",game.round_number," rounds")
	await tap(game.modal_actions[0]);await pause(.8)
	finish_test()

func finish_test(code: int=0) -> void:
	root.get_node("GameAudio").request_quit(code)
