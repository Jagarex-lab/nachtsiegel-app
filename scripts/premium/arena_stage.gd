extends Control
## Presentation only. Logical lane indices and hit boxes never depend on perspective.
## Three live comparison modes; the production view uses the selected spatial floor.
const MODES := ["flat", "spatial", "three_d"]
const CardFace = preload("res://scripts/alpha/card_view.gd")
const CardStyle = preload("res://scripts/alpha/style.gd")
const INK := Color("0a111b")
const STONE := Color("15232e")
const METAL := Color("657984")
const PLAYER := Color("75cad0")
const FOE := Color("c998a5")
var mode := "spatial":
	set(value):
		if value not in MODES: return
		if mode == value: return
		mode = value
		if is_node_ready(): _rebuild_world()
		queue_redraw()
var origins: Dictionary = {"hero": -1, "enemy": -1}
var controlled: Dictionary = {"hero": [], "enemy": []}
var cards: Array = []
var world_viewport: SubViewport
var camera: Camera3D
var world: Node3D
var _surface: TextureRect
var _face_viewports: Array[SubViewport] = []
var _face_items:Array=[]
var _world_frames:=0
var _faces_frozen:=false

static func slot_rect(side: String, lane: int, area: Rect2, view_mode:String="spatial") -> Rect2:
	# Far-row depth changes only size/placement, never logical lane identity.
	# Controls remain upright, so every hit target matches its visible card.
	var row_area:=area
	if view_mode=="spatial" and side=="enemy":
		row_area.position.x+=area.size.x*.025;row_area.size.x*=.95
	var gap := minf(8.0, area.size.x * .012)
	var median := 0.0 if area.size.y<=100.0 else minf(14.0, area.size.y * .10)
	var width := (row_area.size.x - gap * 4.0) / 5.0
	var height := maxf(0.0, (area.size.y - median) / 2.0)
	return Rect2(row_area.position + Vector2((width + gap) * clampi(lane,0,4), 0.0 if side == "enemy" else height + median), Vector2(width,height))

static func slot_hit(at: Vector2, area: Rect2, view_mode:String="spatial") -> Dictionary:
	for side in ["enemy", "hero"]:
		for lane in 5:
			if slot_rect(side, lane, area,view_mode).has_point(at): return {"side":side,"lane":lane}
	return {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_resize_world)
	_rebuild_world()

func configure(value: Array) -> void:
	cards = value.duplicate(true)
	if is_node_ready() and mode == "three_d": _rebuild_world()
	queue_redraw()

func _draw() -> void:
	if size.x <= 1 or size.y <= 1 or mode == "three_d": return
	var plane := _floor_polygon()
	# One continuous, carved causeway. Geometry is visual only: the ten upright
	# hit rectangles above this floor still use the unchanged slot_rect contract.
	for depth in [7.0, 4.0, 1.5]:
		draw_colored_polygon(_offset_polygon(plane,Vector2(0,depth)),Color(0,0,0,.18))
	draw_colored_polygon(plane,Color("080e16"))
	if mode == "spatial":
		draw_colored_polygon(PackedVector2Array([plane[3],plane[2],plane[2]+Vector2(0,7),plane[3]+Vector2(0,7)]),Color("070b11"))
	# The fractured dark channels separate five full-length paths, rather than
	# ten independent UI panels. Every facet shares a top-left key light.
	for lane in 5:
		_draw_causeway(lane)
	_draw_fold()
	var border := PackedVector2Array(plane);border.append(plane[0])
	draw_polyline(border,Color("46525a"),1.2,true)
	draw_line(plane[0],plane[1],Color("93a4ae"),1.2,true)
	for side in ["enemy","hero"]:
		for lane in 5:
			_draw_berth(side,lane)

func _offset_polygon(points: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var shifted := PackedVector2Array()
	for point in points:shifted.append(point+by)
	return shifted

func _stone_patch(x0: float, x1: float, y0: float, y1: float, inset: float=3.0) -> PackedVector2Array:
	var a := _floor_point(x0,y0)+Vector2(inset,1)
	var b := _floor_point(x1,y0)+Vector2(-inset,1)
	var c := _floor_point(x1,y1)+Vector2(-inset,-1)
	var d := _floor_point(x0,y1)+Vector2(inset,-1)
	var cut := minf(8.0,maxf(2.0,(d.y-a.y)*.19))
	return PackedVector2Array([a+Vector2(cut,0),b-Vector2(cut,0),b+Vector2(0,cut),c-Vector2(0,cut),c-Vector2(cut,0),d+Vector2(cut,0),d-Vector2(0,cut),a+Vector2(0,cut)])

func _draw_causeway(lane: int) -> void:
	var left := float(lane)/5.0
	var right := float(lane+1)/5.0
	var path := _stone_patch(left,right,.025,.975,2.0)
	draw_colored_polygon(_offset_polygon(path,Vector2(0,3)),Color(0,0,0,.50))
	draw_colored_polygon(path,Color("202932"))
	var rows := [Vector2(.035,.255),Vector2(.26,.48),Vector2(.52,.74),Vector2(.745,.965)]
	for index in rows.size():
		var interval: Vector2=rows[index]
		var tint := Color("30313b") if index<2 else Color("263a3e")
		if lane%2==1:tint=tint.darkened(.08)
		var slab := _stone_patch(left,right,interval.x,interval.y,4.0)
		draw_colored_polygon(slab,tint)
		# A narrow mineral inclusion and two broad facets read as material even
		# at phone resolution. They require no shader, texture or particle emitter.
		var shine := PackedVector2Array([slab[0],slab[1],slab[1].lerp(slab[4],.34),slab[0].lerp(slab[5],.46)])
		draw_colored_polygon(shine,Color(.65,.74,.79,.055))
		draw_line(slab[0],slab[1],Color(.64,.71,.76,.26),1,true)
		draw_line(slab[7],slab[6],Color(.55,.68,.74,.13),1,true)
		draw_line(slab[4],slab[5],Color(0,0,0,.42),1.6,true)
		var crack_x := left+(right-left)*(.31 if (index+lane)%2==0 else .67)
		var crack := PackedVector2Array([_floor_point(crack_x,interval.x+.035),_floor_point(crack_x+.018,lerpf(interval.x,interval.y,.49)),_floor_point(crack_x-.008,interval.y-.025)])
		draw_polyline(crack,Color("101b22"),1.3,true)
	var trench_x := float(lane+1)/5.0
	if lane<4:
		var top := _floor_point(trench_x,.035)
		var middle := _floor_point(trench_x,.5)
		var bottom := _floor_point(trench_x,.965)
		draw_line(top,bottom,Color("04090f"),3,true)
		draw_line(top.lerp(middle,.10),middle,Color(.66,.44,.64,.23),1,true)
		draw_line(middle,bottom.lerp(middle,.10),Color(.28,.72,.76,.25),1,true)

func _draw_fold() -> void:
	var seam := PackedVector2Array()
	for section in 21:
		seam.append(_floor_point(float(section)/20.0,.5)+Vector2(0,-2 if section%2==0 else 2))
	draw_polyline(seam,Color("03070d"),8,true)
	draw_polyline(seam,Color("466470"),2.5,true)
	draw_polyline(seam,Color(.64,.80,.84,.35),.8,true)
	var numerals := ["I","II","III","IV","V"]
	for lane in 5:
		var at := _floor_point((float(lane)+.5)/5.0,.5)
		var rx := minf(20.0,size.x*.024)
		var ry := minf(8.0,size.y*.045)
		var seal := PackedVector2Array([at+Vector2(-rx,0),at+Vector2(-rx*.63,-ry),at+Vector2(rx*.63,-ry),at+Vector2(rx,0),at+Vector2(rx*.63,ry),at+Vector2(-rx*.63,ry)])
		draw_colored_polygon(seal,Color("101b24"))
		var edge := PackedVector2Array(seal);edge.append(seal[0])
		draw_polyline(edge,Color("9e8e71"),1,true)
		var font_size := 10
		var text_size := CardStyle.font.get_string_size(numerals[lane],HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
		draw_string(CardStyle.font,at+Vector2(-text_size.x*.5,CardStyle.font.get_ascent(font_size)*.38),numerals[lane],HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("ddcfaa"))

func _draw_berth(side: String, lane: int) -> void:
	var slot := slot_rect(side,lane,Rect2(Vector2.ZERO,size),mode)
	var hue := PLAYER if side=="hero" else FOE
	var base := Vector2(slot.get_center().x,slot.end.y-4)
	var radius := Vector2(slot.size.x*.33,minf(8,slot.size.y*.11))
	_ellipse(base+Vector2(0,2),radius,Color(0,0,0,.33))
	_ellipse(base,radius,Color(hue,.10))
	_ellipse_outline(base,radius,Color(hue,.32))
	if int(origins.get(side,-1))==lane:
		draw_line(base-Vector2(19,0),base+Vector2(19,0),Color("d3b16f"),2,true)
		var origin_mark := PackedVector2Array([base+Vector2(-5,-3),base+Vector2(0,-7),base+Vector2(5,-3)])
		draw_polyline(origin_mark,Color("edcf8f"),1.4,true)
	if controlled.get(side,[]).has(lane):
		draw_line(Vector2(slot.position.x+8,base.y),Vector2(slot.end.x-8,base.y),Color(hue,.72),2,true)
	for item in cards:
		if str(item.get("side",""))!=side or int(item.get("lane",-1))!=lane:continue
		if item.get("unit",{}).is_empty():continue
		if bool(item.get("combat_ready",false)):
			var direction := -1.0 if side=="hero" else 1.0
			var arrow_at := base+Vector2(0,-3)
			draw_polyline(PackedVector2Array([arrow_at+Vector2(-8,-direction*3),arrow_at+Vector2(0,direction*2),arrow_at+Vector2(8,-direction*3)]),Color(hue,.9),1.7,true)
		break

func _floor_polygon() -> PackedVector2Array:
	var inset := size.x*.035 if mode=="spatial" else 0.0
	return PackedVector2Array([Vector2(inset,2),Vector2(size.x-inset,2),Vector2(size.x,size.y-7),Vector2(0,size.y-7)])

func _floor_point(x: float, y: float) -> Vector2:
	var p := _floor_polygon()
	return p[0].lerp(p[1],x).lerp(p[3].lerp(p[2],x),y)

func _ellipse(at: Vector2, radius: Vector2, tint: Color) -> void:
	var points := PackedVector2Array()
	for index in 32: points.append(at+Vector2(cos(TAU*index/32),sin(TAU*index/32))*radius)
	draw_colored_polygon(points,tint)

func _process(_delta:float) -> void:
	if mode!="three_d" or _faces_frozen:return
	_world_frames+=1
	if _world_frames<8:return
	for face_view in _face_viewports:
		if face_view.get_child_count()==0:return
		var face=face_view.get_child(0)
		if not face.card.is_empty() and face.art_report().pending:return
	for face_view in _face_viewports:face_view.render_target_update_mode=SubViewport.UPDATE_ONCE
	_faces_frozen=true

func _ellipse_outline(at:Vector2,radius:Vector2,tint:Color) -> void:
	var points:=PackedVector2Array()
	for index in 33:points.append(at+Vector2(cos(TAU*index/32),sin(TAU*index/32))*radius)
	draw_polyline(points,tint,1,true)

func _resize_world() -> void:
	if is_instance_valid(world_viewport):
		world_viewport.size=Vector2i(maxi(1,roundi(size.x)),maxi(1,roundi(size.y)))
	if is_instance_valid(camera) and size.x>0 and size.y>0:
		# Preserve the full outer lanes at changing aspect ratios. A fixed FOV
		# otherwise clips the near-row cards on narrow/tall viewports.
		# 29 degrees is the vertical safe-fit limit for these camera/row poses;
		# never zoom in below it just to fill a wider aspect ratio.
		camera.fov=clampf(rad_to_deg(2.0*atan(tan(deg_to_rad(14.5))*(size.y/size.x)/(208.2/820.0))),29,100)
		for index in _face_viewports.size():
			var item:Dictionary=_face_items[index]
			var projected:=projected_card_rect(str(item.side),int(item.lane))
			var pixels:=Vector2i(maxi(44,roundi(projected.size.x)),maxi(44,roundi(projected.size.y)))
			var face_view:=_face_viewports[index]
			face_view.size=pixels;face_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
			if face_view.get_child_count()>0:face_view.get_child(0).size=Vector2(pixels)
		_world_frames=0;_faces_frozen=false
	queue_redraw()

func _rebuild_world() -> void:
	_world_frames=0;_faces_frozen=false;set_process(mode=="three_d")
	_face_viewports.clear();_face_items.clear()
	if is_instance_valid(_surface): remove_child(_surface); _surface.queue_free()
	if is_instance_valid(world_viewport): remove_child(world_viewport); world_viewport.queue_free()
	world_viewport=null; camera=null; world=null; _surface=null
	if mode != "three_d": return
	world_viewport=SubViewport.new();world_viewport.name="Real3DViewport"
	world_viewport.own_world_3d=true;world_viewport.transparent_bg=true
	world_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	world_viewport.msaa_3d=Viewport.MSAA_DISABLED
	add_child(world_viewport);_resize_world()
	_surface=TextureRect.new();_surface.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_surface.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;_surface.texture=world_viewport.get_texture();add_child(_surface)
	world=Node3D.new();world.name="PerspectiveBoard";world_viewport.add_child(world)
	var environment:=WorldEnvironment.new();var settings:=Environment.new()
	settings.background_mode=Environment.BG_COLOR;settings.background_color=Color("0a111b")
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_color=Color("9db5ca");settings.ambient_light_energy=.72
	environment.environment=settings;world.add_child(environment)
	camera=Camera3D.new();camera.name="TiltedCamera";camera.position=Vector3(0,12,7);camera.fov=29
	world.add_child(camera);camera.look_at(Vector3(0,.35,0),Vector3.UP);camera.current=true;_resize_world()
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-25,0);light.light_energy=1.15;light.shadow_enabled=false;world.add_child(light)
	var ground:=BoxMesh.new();ground.size=Vector3(24,.18,7.0)
	var table:=MeshInstance3D.new();table.name="PhysicalArena";table.mesh=ground;table.position.y=-.12
	table.material_override=_material(Color("172a37"));world.add_child(table)
	for lane in 5:
		var path:=BoxMesh.new();path.size=Vector3(4.45,.025,6.65)
		var mesh:=MeshInstance3D.new();mesh.name="Path%d"%lane;mesh.mesh=path;mesh.position=Vector3((lane-2)*4.74,0,0)
		mesh.material_override=_material(Color("14232e") if lane%2==0 else Color("20323c"));world.add_child(mesh)
		for side in ["enemy","hero"]:
			var disc:=CylinderMesh.new();disc.top_radius=.69;disc.bottom_radius=.75;disc.height=.07;disc.radial_segments=20
			var pedestal:=MeshInstance3D.new();pedestal.mesh=disc;pedestal.position=Vector3((lane-2)*4.74,.03,-2.4 if side=="enemy" else 2.4)
			pedestal.material_override=_material(Color("527181") if side=="hero" else Color("785765"));world.add_child(pedestal)
	for item in cards:
		if not item is Dictionary or not item.get("card") is Dictionary:continue
		var side:=str(item.get("side","hero"));var lane:=int(item.get("lane",0))
		var quad:=QuadMesh.new();quad.size=Vector2(4.5,2.4)
		var mesh:=MeshInstance3D.new();mesh.name=side+str(lane);mesh.mesh=quad
		mesh.position=Vector3((lane-2)*4.74,.75,-2.4 if side=="enemy" else 2.4)
		var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		material.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED;material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		material.cull_mode=BaseMaterial3D.CULL_DISABLED;mesh.material_override=material
		world.add_child(mesh)
		# The exact same Godot card component renders the 3D face. No baked
		# screenshot, alternate illustration or second card renderer is used.
		var face_view:=SubViewport.new();face_view.size=Vector2i(160,92);face_view.disable_3d=true
		face_view.transparent_bg=true;face_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		world_viewport.add_child(face_view);_face_viewports.append(face_view);_face_items.append(item)
		var face:=CardFace.new();face.card=item.card;face.unit=item.get("unit",{});face.color=CardStyle.color(item.card)
		face.lane=lane;face.owner_label="KI" if side=="enemy" else "DU";face.origin=bool(item.get("origin",int(origins.get(side,-1))==lane));face.size=Vector2(160,92)
		face.color=item.get("color",CardStyle.color(item.card) if not item.card.is_empty() else PLAYER if side=="hero" else FOE)
		face.combat_ready=bool(item.get("combat_ready",true));face.attack_penalty=int(item.get("attack_penalty",0))
		face.selected=bool(item.get("selected",false));face.target=bool(item.get("target",false));face.invalid_target=bool(item.get("invalid_target",false))
		face.convergence=bool(item.get("convergence",false));face.broken_convergence=bool(item.get("broken_convergence",false))
		if "reduced_motion" in face:face.reduced_motion=bool(item.get("reduced_motion",false))
		if "display_role" in face:face.display_role="board"
		face_view.add_child(face);material.albedo_texture=face_view.get_texture()
	_resize_world()

func _material(tint: Color) -> StandardMaterial3D:
	var material:=StandardMaterial3D.new();material.albedo_color=tint;material.roughness=.8;material.metallic=.2
	return material

func projected_card_rect(side: String, lane: int) -> Rect2:
	if not is_instance_valid(camera):return slot_rect(side,lane,Rect2(Vector2.ZERO,size),mode)
	var at:=Vector3((lane-2)*4.74,.75,-2.4 if side=="enemy" else 2.4)
	var basis:=camera.global_transform.basis
	var points:Array[Vector2]=[]
	for x in [-2.25,2.25]:
		for y in [-1.2,1.2]:points.append(camera.unproject_position(at+basis.x*x+basis.y*y))
	var result:=Rect2(points[0],Vector2.ZERO)
	for point in points:result=result.expand(point)
	return result

func art_reports() -> Array:
	var reports:Array=[]
	for face_view in _face_viewports:
		if face_view.get_child_count()>0:reports.append(face_view.get_child(0).art_report())
	return reports

func metrics() -> Dictionary:
	var rows:Array=[];var min_dimension:=INF;var total_area:=0.0;var visible_art_area:=0.0;var art_measured:=0
	for side in ["enemy","hero"]:
		for lane in 5:
			var slot:=projected_card_rect(side,lane) if mode=="three_d" else slot_rect(side,lane,Rect2(Vector2.ZERO,size),mode)
			rows.append({"side":side,"lane":lane,"rect":[slot.position.x,slot.position.y,slot.size.x,slot.size.y]})
			min_dimension=minf(min_dimension,minf(slot.size.x,slot.size.y));total_area+=slot.get_area()
			if mode=="three_d":
				var index:=lane+(0 if side=="enemy" else 5)
				if index<_face_viewports.size() and _face_viewports[index].get_child_count()>0:
					var face:=_face_viewports[index].get_child(0)
					if face.has_method("layout_report"):
						var report:Dictionary=face.layout_report()
						visible_art_area+=slot.get_area()*report.outer.get_area()/maxf(1,face.size.x*face.size.y)*float(report.get("art_fraction",0));art_measured+=1
	return {"mode":mode,"size":[size.x,size.y],"slots":rows,"minimum_card_dimension":min_dimension,"card_surface_px2":total_area,"real_3d_camera":is_instance_valid(camera),"mesh_count":world.find_children("*","MeshInstance3D",true,false).size() if is_instance_valid(world) else 0,"card_face_subviewports":_face_viewports.size(),"card_textures_frozen":_faces_frozen,"visible_art_area_px2":visible_art_area if art_measured==10 else -1,"visible_art_measured_count":art_measured,"perspective_affects_production_hitboxes":false}
