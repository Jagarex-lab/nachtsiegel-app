extends SceneTree
## Contract tests for logical lane targets, independent of visual perspective.
const Stage=preload("res://scripts/premium/arena_stage.gd")
var checked:=0
var failures:Array[String]=[]
func _initialize() -> void:
	for view_mode in ["flat","spatial"]:
		for dimensions in [Vector2(844,390),Vector2(852,393),Vector2(932,430),Vector2(1024,768),Vector2(1600,900)]:
			var hand_height:=clampf(dimensions.y*.32,112,160)
			var area:=Rect2(Vector2(12,43),Vector2(dimensions.x-24,maxf(112,dimensions.y-hand_height-57)))
			var slots:Array[Rect2]=[]
			for side in ["enemy","hero"]:
				for lane in 5:
					var slot:Rect2=Stage.slot_rect(side,lane,area,view_mode)
					check(area.grow(.01).encloses(slot),"Slot remains in area %s/%s/%d"%[dimensions,side,lane])
					check(minf(slot.size.x,slot.size.y)>=44,"Touch dimensions >=44 at %s/%s/%d"%[dimensions,side,lane])
					check(Stage.slot_hit(slot.get_center(),area,view_mode)=={"side":side,"lane":lane},"Center maps to same logical lane")
					for edge in [Vector2(.5,.5),Vector2(slot.size.x-.5,.5),slot.size-Vector2(.5,.5),Vector2(.5,slot.size.y-.5)]:
						check(Stage.slot_hit(slot.position+edge,area,view_mode)=={"side":side,"lane":lane},"All inset corners map to lane")
					for previous in slots:check(not slot.intersects(previous),"No ambiguous overlapping hit targets")
					slots.append(slot)
			for lane in 5:
				var enemy:Rect2=Stage.slot_rect("enemy",lane,area,view_mode);var hero:Rect2=Stage.slot_rect("hero",lane,area,view_mode)
				check(absf(enemy.get_center().x-hero.get_center().x)<=area.size.x*.026,"Opposing lane depth inset stays within an unambiguous 2.6% horizontal budget")
				check(Stage.slot_hit(Vector2(hero.get_center().x,(enemy.end.y+hero.position.y)/2),area,view_mode).is_empty(),"Median cannot accidentally play into a lane")
			for at in [area.position-Vector2.ONE,area.end+Vector2.ONE]:check(Stage.slot_hit(at,area,view_mode).is_empty(),"Outside point is invalid")
	# Extreme Safari toolbar budget: preserve two 44px rows, recovering the
	# decorative median before shrinking any real touch target.
	for view_mode in ["flat","spatial"]:
		for width in [576,720,820]:
			for height in [88,99,100,101]:
				var area:=Rect2(0,0,width,height)
				for side in ["enemy","hero"]:
					for lane in 5:
						var slot:Rect2=Stage.slot_rect(side,lane,area,view_mode)
						check(slot.size.y>=44,"Extreme toolbar budget keeps 44px rows")
						check(Stage.slot_hit(slot.get_center(),area,view_mode)=={"side":side,"lane":lane},"Dense slot center maps to same lane")
						check(area.grow(.01).encloses(slot),"Dense slot stays inside its board")
				for lane in 5:
					var far:Rect2=Stage.slot_rect("enemy",lane,area,view_mode);var near:Rect2=Stage.slot_rect("hero",lane,area,view_mode)
					check(not far.intersects(near),"Dense row targets never overlap")
					check(is_equal_approx(near.position.y-far.end.y,0.0) if height<=100 else near.position.y>far.end.y,"Only decorative median is recovered at <=100px")
	check(Stage.MODES==["flat","spatial","three_d"],"Three runnable variants are explicitly available")
	call_deferred("check_real_camera")

func check_real_camera() -> void:
	for dimensions in [Vector2(844,390),Vector2(852,393),Vector2(932,430),Vector2(1024,768),Vector2(1600,900)]:
		var hand_height:=clampf(dimensions.y*.32,112,160)
		var stage:=Stage.new();stage.size=Vector2(dimensions.x-24,maxf(112,dimensions.y-hand_height-57));stage.mode="three_d";root.add_child(stage)
		await process_frame;await process_frame
		check(stage.world_viewport.get_camera_3d()==stage.camera,"Actual Camera3D is active in its own live SubViewport")
		check(stage.world.get_node("PhysicalArena") is MeshInstance3D,"Actual 3D ground mesh exists")
		var slots:Array[Rect2]=[]
		for side in ["enemy","hero"]:
			var previous_x:=-INF
			for lane in 5:
				var slot:Rect2=stage.projected_card_rect(side,lane)
				check(Rect2(Vector2.ZERO,stage.size).grow(.01).encloses(slot),"Projected card remains inside viewport at %s"%dimensions)
				check(minf(slot.size.x,slot.size.y)>=44,"Projected touch target >=44 at %s"%dimensions)
				check(slot.get_center().x>previous_x,"Projected lane order remains left to right")
				previous_x=slot.get_center().x
				for previous in slots:check(not slot.intersects(previous),"Projected 3D hit areas do not overlap")
				slots.append(slot)
		stage.mode="spatial";check(stage.world_viewport==null,"Selected 2.5D mode releases all 3D viewport resources")
		stage.queue_free();await process_frame
	# Actual production BattleLayout dimensions, including the iPhone board
	# that previously clipped the near row after width-only camera fitting.
	for dimensions in [Vector2(828,194.97),Vector2(720,184),Vector2(576,160)]:
		var stage:=Stage.new();stage.size=dimensions;stage.mode="three_d";root.add_child(stage)
		await process_frame;await process_frame
		var slots:Array[Rect2]=[]
		for side in ["enemy","hero"]:
			for lane in 5:
				var slot:Rect2=stage.projected_card_rect(side,lane)
				check(Rect2(Vector2.ZERO,dimensions).grow(.01).encloses(slot),"Actual production 3D board keeps every projected card inside")
				check(minf(slot.size.x,slot.size.y)>=44,"Actual production 3D touch targets >=44px")
				for previous in slots:check(not slot.intersects(previous),"Actual production 3D hit targets do not overlap")
				slots.append(slot)
		stage.queue_free();await process_frame
	# The 3D face must be the same visible state as its input Control, not a
	# default portrait that loses readiness/targets/defenses after projection.
	var catalog=preload("res://scripts/production/catalog.gd").new()
	var card:Dictionary=catalog.card("oa-houses-c01")
	var projection:Array=[{"side":"hero","lane":1,"card":card,"unit":{"id":card.id,"atk":card.atk,"hp":card.hp,"ward":2,"block":1,"stun":0},"selected":true,"target":true,"invalid_target":false,"combat_ready":false,"attack_penalty":2,"convergence":true,"broken_convergence":false,"origin":true,"reduced_motion":true}]
	var projected_stage:=Stage.new();projected_stage.size=Vector2(828,194.97);projected_stage.mode="three_d";projected_stage.configure(projection);root.add_child(projected_stage)
	await process_frame;await process_frame
	var face=projected_stage._face_viewports[0].get_child(0)
	check(face.card.id==card.id and face.unit.id==card.id,"Real original card identity reaches the real 3D card renderer")
	for key in ["selected","target","invalid_target","combat_ready","attack_penalty","convergence","broken_convergence","origin","reduced_motion"]:
		check(face.get(key)==projection[0][key],"Real 3D face retains presentation intent: "+key)
	check(face.unit.ward==2 and face.unit.block==1,"3D face keeps shield and block separately")
	projection[0].unit.hp=-99
	check(face.unit.hp==card.hp and projected_stage.cards[0].unit.hp==card.hp,"Projection owns a copy instead of mutating or following caller state")
	projected_stage.configure([{"side":"hero","lane":2,"card":{},"unit":{},"target":true,"origin":true}])
	for frame in 10:await process_frame
	check(projected_stage._faces_frozen,"A selectable empty path freezes without waiting forever for nonexistent artwork")
	check(projected_stage._face_viewports[0].get_child(0).target,"Empty 3D path preserves the valid target highlight")
	projected_stage.queue_free();await process_frame
	print("PREMIUM_ARENA_GEOMETRY %d checks, %d failures"%[checked,failures.size()])
	for failure in failures:push_error(failure)
	quit(0 if failures.is_empty() else 1)
func check(condition:bool,label:String) -> void:
	checked+=1
	if not condition:failures.append(label)
