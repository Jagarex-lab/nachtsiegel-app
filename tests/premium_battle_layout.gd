extends SceneTree
const Layout=preload("res://scripts/premium/battle_layout.gd")
const Stage=preload("res://scripts/premium/arena_stage.gd")
var assertions:=0
var failures:=0
func check(value: bool,label: String) -> void:
	assertions+=1
	if not value:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void:
	for viewport in [Vector2(844,390),Vector2(852,393),Vector2(932,430),Vector2(1024,768),Vector2(1280,720),Vector2(1600,900),Vector2(756,248),Vector2(756,299),Vector2(756,320)]:
		var margin=4.0 if viewport.y<380 else 8.0
		var area=Rect2(Vector2.ZERO,viewport-Vector2.ONE*margin*2)
		for count in range(1,7):
			for selection in range(-1,count):
				var geometry=Layout.measure(area.size,count,selection)
				for region in ["header","board","hand","dock"]:check(area.grow(.01).encloses(geometry[region]),"bounded "+region+str(viewport))
				for index in count:
					var tile=Layout.hand_rect(geometry,index,count,index==selection)
					check(area.encloses(tile),"every card and lifted selection stays within safe pixels "+str(viewport))
					check(tile.size.x>=44 and tile.size.y>=44,"complete portrait remains a44px touch target")
					check(is_equal_approx(tile.size.x/tile.size.y,63.0/88.0),"actual hand preserves63:88")
					if index<count-1:check(not tile.intersects(Layout.hand_rect(geometry,index+1,count,index+1==selection)),"selection never covers neighbouring cost, name or stats")
				for side in ["enemy","hero"]:
					for lane in 5:
						var slot=Stage.slot_rect(side,lane,geometry.board)
						check(area.encloses(slot) and slot.size.x>=44 and slot.size.y>=44,"ten visible upright44px lane targets "+str(viewport))
				check(geometry.dock.size.y>=91,"two44px action rows plus separator fit the dock")
	print("PREMIUM BATTLE LAYOUT: %d assertions, %d failures; 9 viewport/safe-area sizes,1–6 cards,all selections,canonical ratio,no occlusion,ten44px lanes; presentation only" % [assertions,failures])
	quit(1 if failures else 0)
