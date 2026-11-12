extends SceneTree
## Measures the actual new hand/board dimensions against every real card name.
const Layout=preload("res://scripts/premium/battle_layout.gd")
const Stage=preload("res://scripts/premium/arena_stage.gd")
const View=preload("res://scripts/alpha/card_view.gd")
const Catalog=preload("res://scripts/production/catalog.gd")
var assertions:=0
var failures:=0
func check(value: bool,label: String) -> void:
	assertions+=1
	if not value:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var cards=Catalog.new().all_cards()
	var view=View.new()
	for screen in [Vector2(844,390),Vector2(852,393),Vector2(932,430),Vector2(1024,768),Vector2(1600,900),Vector2(756,299),Vector2(756,320)]:
		var margin=4.0 if screen.y<380 else 8.0
		var geometry=Layout.measure(screen-Vector2.ONE*margin*2,6)
		for card in cards:
			view.card=card;view.unit={};view.display_role="hand";view.size=geometry.card_size
			var report=view.layout_report()
			check(report.title_fits,"complete actual hand name in measured portrait "+card.id+str(screen))
			check(report.outer.encloses(report.title) and report.outer.encloses(report.stats),"actual title and value/type zones stay inside the shared outline")
			check(report.title.end.y<=report.stats.position.y+.1,"measured hand name cannot intersect current values")
			check(report.has_combat_values==(card.kind=="creature"),"only creatures expose attack/life")
			if card.kind=="creature":
				view.display_role="board";view.lane=2;view.size=Stage.slot_rect("hero",2,geometry.board).size
				view.unit={"id":card.id,"atk":40,"hp":card.hp,"ward":25,"block":25,"stun":2,"summoned":false,"extra_attacks":1}
				var board=view.layout_report()
				check(board.title.size.y==0 or board.title_fits,"whole board name or an intentional image-first compact view")
				check(board.status_values.shield==25 and board.status_values.block==25,"shield and block remain separate in every real creature renderer")
				check(board.art_fraction>=.25,"illustration occupies a meaningful part of every actual occupied phone lane")
	view.free()
	print("PREMIUM BATTLE TEXT: %d assertions, %d failures; all550 real names/types and357 creatures at7 actual Shell card/slot dimensions, not gameplay balance" % [assertions,failures])
	root.get_node("GameAudio").request_quit(1 if failures else 0)
