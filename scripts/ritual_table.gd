extends Control
## Obsidian altar: original, scalable, hand-drawn ornamental playmat.
## Decorative only; combat slots remain interactive siblings.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _poly(points: PackedVector2Array, fill: Color, edge: Color, thick: float = 2.0) -> void:
	draw_colored_polygon(points, fill)
	draw_polyline(points, edge, thick, true)

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 2.0 or h < 2.0:
		return
	var center := Vector2(w * 0.5, h * 0.5)
	draw_rect(Rect2(Vector2.ZERO,size),Color("#0a1019"))
	# Layered stone and aged brass, not a flat rectangular UI.
	for ring in 9:
		var pad := float(ring) * 5.0
		draw_rect(Rect2(pad,pad,w-pad*2.0,h-pad*2.0),Color("#b58a55",0.25-float(ring)*0.022),false,2.0)
	for row in 14:
		var y := h * float(row) / 14.0
		draw_line(Vector2(0,y),Vector2(w,y),Color("#7e6c66",0.13),2.0)
		for col in 8:
			var x := w * (float(col) + (0.5 if row % 2 == 0 else 0.0)) / 8.0
			draw_line(Vector2(x,y),Vector2(x+9.0,y+4.0),Color("#d5ad73",0.13),1.0)
	# Carved lanes, translucent ritual wells and illuminated brass filigree.
	for lane in 5:
		var cx := w * (float(lane)+0.5)/5.0
		var half := w * 0.094
		var p := PackedVector2Array([
			Vector2(cx-half,h*0.07),Vector2(cx+half,h*0.07),
			Vector2(cx+half*0.93,h*0.93),Vector2(cx-half*0.93,h*0.93)
		])
		_poly(p,Color("#18232b",0.7),Color("#b99261",0.53),2.0)
		draw_line(Vector2(cx-half+5,h*0.10),Vector2(cx-half+5,h*0.9),Color("#f1cf92",0.24),1.5)
		draw_line(Vector2(cx+half-5,h*0.10),Vector2(cx+half-5,h*0.9),Color("#f1cf92",0.24),1.5)
		for side in [-1,1]:
			var sy := h*(0.27 if side < 0 else 0.73)
			var hue := Color("#d96e70",0.13) if side < 0 else Color("#65c3b9",0.13)
			draw_circle(Vector2(cx,sy),minf(w/12.0,h/4.5),hue)
			draw_arc(Vector2(cx,sy),minf(w/15.0,h/6.0),0,TAU,48,Color("#d6ad74",0.36),2.0)
			for k in 8:
				var a := TAU*float(k)/8.0
				var v := Vector2(cos(a),sin(a))
				draw_line(Vector2(cx,sy)+v*14.0,Vector2(cx,sy)+v*21.0,Color("#e7bc7d",0.45),2.0)
	# Central dividing seal: two opposed crescent arcs and compass spikes.
	draw_rect(Rect2(0,h*0.47,w,h*0.06),Color("#070b12",0.94))
	draw_line(Vector2(0,h*0.47),Vector2(w,h*0.47),Color("#e3b77d",0.75),3.0)
	draw_line(Vector2(0,h*0.53),Vector2(w,h*0.53),Color("#e3b77d",0.75),3.0)
	var radius := minf(w,h)*0.085
	draw_circle(center,radius*1.55,Color("#10131c"))
	draw_arc(center,radius*1.38,0,TAU,64,Color("#b48756",0.88),5.0)
	draw_arc(center,radius*1.05,0,TAU,64,Color("#f1d39a",0.85),2.0)
	for k in 12:
		var a := TAU*float(k)/12.0
		var v := Vector2(cos(a),sin(a))
		draw_line(center+v*radius*0.88,center+v*radius*1.58,Color("#e6c08a",0.75),2.0)
	_poly(PackedVector2Array([
		center+Vector2(0,-radius*0.8),
		center+Vector2(radius*0.55,0),
		center+Vector2(0,radius*0.8),
		center+Vector2(-radius*0.55,0)
	]),Color("#2a4650"),Color("#f4d39b"),3.0)
	draw_circle(center,radius*0.22,Color("#e8b76e"))
	# Eight metal corner clasps and tiny inset gemstones.
	for x in [19.0,w-19.0]:
		for y in [19.0,h-19.0]:
			draw_circle(Vector2(x,y),10.0,Color("#463224"))
			draw_arc(Vector2(x,y),9.0,0,TAU,32,Color("#c99b62"),3.0)
			draw_circle(Vector2(x,y),4.0,Color("#72c2bb"))
