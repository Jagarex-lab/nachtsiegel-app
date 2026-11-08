extends Control
## Procedural, resolution-independent tabletop illustration. No external assets.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 1.0 or h < 1.0:
		return
	var center := Vector2(w*0.5,h*0.5)
	draw_rect(Rect2(Vector2.ZERO,size),Color("#191821"))
	# Repeating basalt slabs, weathered grooves and gold inlay.
	for i in 16:
		var y := float(i)*h/16.0
		draw_line(Vector2(0,y),Vector2(w,y),Color("#46313a",0.55),2.0)
		if i % 2 == 0:
			draw_line(Vector2(w*0.12,y+4),Vector2(w*0.24,y+4),Color("#b58455",0.19),1.0)
	for i in 7:
		var x := float(i)*w/6.0
		draw_line(Vector2(x,0),Vector2(x,h),Color("#6a4b4d",0.28),2.0)
	# Five luminous channels with engraved edges.
	for lane in 5:
		var x := w*(float(lane)+0.5)/5.0
		var edge := w*0.094
		draw_rect(Rect2(Vector2(x-edge,h*0.055),Vector2(edge*2,h*0.88)),Color("#221c29",0.72))
		draw_line(Vector2(x-edge,h*0.04),Vector2(x-edge,h*0.96),Color("#b58c60",0.4),2.0)
		draw_line(Vector2(x+edge,h*0.04),Vector2(x+edge,h*0.96),Color("#b58c60",0.4),2.0)
		draw_line(Vector2(x,h*0.1),Vector2(x,h*0.9),Color("#c49a60",0.16),2.0)
		for j in 5:
			var y := h*(0.17+float(j)*0.16)
			draw_circle(Vector2(x,y),2.5,Color("#d7ad75",0.5))
	# The central seal separates the two armies.
	draw_rect(Rect2(Vector2(0,h*0.47),Vector2(w,h*0.06)),Color("#0d1118",0.86))
	draw_line(Vector2(0,h*0.47),Vector2(w,h*0.47),Color("#c09b67",0.75),3.0)
	draw_line(Vector2(0,h*0.53),Vector2(w,h*0.53),Color("#c09b67",0.75),3.0)
	var radius := minf(w,h)*0.095
	draw_arc(center,radius,0,TAU,64,Color("#d2ac74",0.85),3.0)
	draw_arc(center,radius*0.72,0,TAU,64,Color("#d2ac74",0.52),2.0)
	for i in 8:
		var a := TAU*float(i)/8.0
		var direction := Vector2(cos(a),sin(a))
		draw_line(center+direction*radius*0.75,center+direction*radius*1.24,Color("#e3bc7d",0.75),2.0)
	draw_circle(center,radius*0.24,Color("#e6b979",0.38))
	# Corner rivets.
	for x in [16.0,w-16.0]:
		for y in [16.0,h-16.0]:
			draw_circle(Vector2(x,y),5.0,Color("#b78a54"))
			draw_circle(Vector2(x,y),2.0,Color("#493323"))
