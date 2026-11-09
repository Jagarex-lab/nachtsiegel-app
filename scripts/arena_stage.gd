extends Control
const T = preload("res://scripts/ui_tokens.gd")
var concept := "mobile"
var layout: Dictionary = {}
var chosen := -1
const SLATE = preload("res://assets/art/premium_slate.png")
func _ready() -> void: mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	if layout.is_empty(): return
	var w = size.x
	# Real table silhouette, drop, cast shadow and lit upper bevel.
	var plane = PackedVector2Array([Vector2(180,160),Vector2(w-180,160),Vector2(w-85,612),Vector2(85,612)])
	if concept == "ritual": plane = PackedVector2Array([Vector2(330,155),Vector2(w-300,155),Vector2(w-155,625),Vector2(260,625)])
	if concept == "table": plane = PackedVector2Array([Vector2(235,148),Vector2(w-100,148),Vector2(w-90,626),Vector2(220,626)])
	for i in range(18,0,-3):
		var shadow = PackedVector2Array()
		for p in plane: shadow.append(p+Vector2(0,14+i))
		draw_colored_polygon(shadow,Color(0,0,0,.07))
	var drop = PackedVector2Array([plane[3],plane[2],plane[2]+Vector2(0,25),plane[3]+Vector2(0,25)])
	draw_colored_polygon(drop,T.INK)
	draw_line(plane[3]+Vector2(0,25),plane[2]+Vector2(0,25),T.BRONZE.darkened(.5),2,true)
	draw_colored_polygon(plane,T.FELT if concept == "table" else T.STONE)
	var uv = PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)])
	draw_polygon(plane,PackedColorArray([Color(.78,.84,.91,1) if concept != "table" else Color(.65,.85,.8,1)]),uv,SLATE)
	var outline = PackedVector2Array(plane); outline.append(plane[0])
	draw_polyline(outline,T.WOOD if concept == "table" else T.BRONZE,8,true)
	draw_line(plane[0]+Vector2(4,5),plane[1]+Vector2(-4,5),T.STONE_LIGHT.lightened(.2),3,true)
	# Low contrast material detail is decorative, never a text underlay.
	for i in 5:
		var a: Rect2 = layout.enemy[i]
		var b: Rect2 = layout.ally[i]
		var top = Vector2(a.get_center().x,171)
		var bottom = Vector2(b.get_center().x,599)
		var half = a.size.x*.55
		var road = PackedVector2Array([top+Vector2(-half*.82,0),top+Vector2(half*.82,0),bottom+Vector2(half,0),bottom+Vector2(-half,0)])
		draw_colored_polygon(road,Color(0,0,0,.055))
		for side in [-1,1]:
			draw_line(top+Vector2(side*half*.82,0),bottom+Vector2(side*half,0),Color(T.BRONZE,.20),1.5,true)
		var mid = top.lerp(bottom,.51)
		draw_line(mid+Vector2(-40,0),mid+Vector2(40,0),Color(T.BRONZE,.45),2,true)
		# Each column continues through both creature bases, rather than two grids.
		for pos in [Vector2(a.get_center().x,a.end.y-20),Vector2(b.get_center().x,b.end.y-20)]:
			draw_ellipse_base(pos,Vector2(a.size.x*.5,18),T.FOE if pos.y<380 else T.PLAYER)
	# Hand is held above a separate near rail, leaving the center battlefield unobscured.
	draw_rect(Rect2(0,657,w,243),Color(T.INK,.60))
	draw_line(Vector2(205,656),Vector2(w-270,656),Color(T.BRONZE,.6),2,true)
func draw_ellipse_base(at: Vector2, radius: Vector2, hue: Color) -> void:
	var points = PackedVector2Array()
	for i in 65: points.append(at+Vector2(cos(TAU*i/64),sin(TAU*i/64))*radius)
	for depth in [8,5,2]:
		var lower = PackedVector2Array()
		for p in points: lower.append(p+Vector2(0,depth))
		draw_colored_polygon(lower,T.INK.lightened(depth*.006))
	draw_colored_polygon(points,T.STONE)
	var uvs = PackedVector2Array()
	for p in points: uvs.append((p-(at-radius))/(radius*2))
	draw_polygon(points,PackedColorArray([Color(.6,.65,.7,1)]),uvs,SLATE)
	draw_polyline(points,T.BRONZE.darkened(.35),2,true)
	var edge = PackedVector2Array()
	for i in 33: edge.append(at+Vector2(cos(PI*i/32),sin(PI*i/32))*radius+Vector2(0,5))
	draw_polyline(edge,Color(hue,.55),2,true)
