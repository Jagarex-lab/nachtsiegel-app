extends "res://tests/ux_audit.gd"
func run() -> void:
	root.size=Vector2i(1280,720)
	arena=load("res://scenes/arena.tscn").instantiate();root.add_child(arena);arena.onboarding_step=3
	await settle();arena._set_reduced_motion(false,false)
	# Authored stress fixture, explicitly not a claim of a naturally dealt hand.
	arena.hand=[0,1,2,3,4,6];arena.energy=10;arena._refresh();await create_timer(.5).timeout
	for i in 4:
		arena._select_card([0,2,1,3][i]);await settle()
		arena.presenter.effect(["ASH","TIDE","THORN","VEIL"][i],"summon",Vector2(600,280),Vector2(600,280),.8)
		await create_timer(.16).timeout;await capture("d-family-"+str(i))
	arena.selected=-1
	arena.allies=[arena.CARD_POOL[4].duplicate(true),arena.CARD_POOL[1].duplicate(true),arena.CARD_POOL[2].duplicate(true),arena.CARD_POOL[3].duplicate(true),arena.CARD_POOL[4].duplicate(true)]
	arena.foes=[arena.CARD_POOL[1].duplicate(true),null,arena.CARD_POOL[0].duplicate(true),null,arena.CARD_POOL[2].duplicate(true)]
	arena._refresh();await settle();await capture("d-sequence-00-before")
	arena._end_turn();await create_timer(.12).timeout;await capture("d-sequence-01-windup")
	await create_timer(.14).timeout;await capture("d-sequence-02-impact")
	await create_timer(.35).timeout;await capture("d-sequence-03-enemy-summon")
	await create_timer(.45).timeout;await capture("d-sequence-04-counterattack")
	var deadline=Time.get_ticks_msec()+8000
	while arena.busy and Time.get_ticks_msec()<deadline:await process_frame
	await create_timer(.4).timeout;await capture("d-sequence-05-next-turn")
	print("COMBAT SEQUENCE: %d assertions, %d failures; 4 family renders and 6 causal frames" % [assertions,failures])
	finish_test(1 if failures else 0)

func finish_test(code: int=0) -> void:
	root.get_node("GameAudio").request_quit(code)
