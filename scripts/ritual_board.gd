extends Control
## Original procedural ritual table. No external artwork or third-party assets.
## Drawn at any size; decorative only and never captures touches.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 10 or h < 10:
		return
	draw_rect(Rect2(0,0,w,h),Color("#0e0b14"))
	# Nested obsidian slabs and warm brass inlay.
	for i in 8:
		var t := float(i) / 8.0
		var rect := Rect2(w*0.018+t*3.0,h*0.025+t*2.0,w*0.964-t*6.0,h*0.95-t*4.0)
		draw_rect(rect,Color("#211925").lerp(Color("#100e17"),t),true)
		draw_rect(rect,Color("#6c4a38").lerp(Color("#302635"),t),false,1.0)
	draw_rect(Rect2(w*0.055,h*0.08,w*0.89,h*0.84),Color("#161420"),true)
	# Ritual circular markings, subtle enough to stay behind the cards.
	var c := Vector2(w*0.5,h*0.5)
	for i in 4:
		draw_arc(c,min(w*0.35,h*0.62)+i*12.0,0,TAU,100,Color(0.64,0.43,0.24,0.16),1.3,true)
	for i in 16:
		var a := float(i)*TAU/16.0
		var p: Vector2 = c+Vector2(cos(a),sin(a))*min(w*0.33,h*0.57)
		draw_circle(p,2.1,Color("#866b50"))
	# Five continuous engraved lanes; the slots float above these paths.
	var left := w*0.088
	var lane_w := w*0.824/5.0
	for i in 5:
		var x := left+lane_w*(float(i)+0.5)
		draw_rect(Rect2(x-lane_w*0.43,h*0.16,lane_w*0.86,h*0.68),Color("#241e2a"),true)
		draw_line(Vector2(x-lane_w*0.43,h*0.16),Vector2(x-lane_w*0.43,h*0.84),Color("#634737"),2)
		draw_line(Vector2(x+lane_w*0.43,h*0.16),Vector2(x+lane_w*0.43,h*0.84),Color("#634737"),2)
		draw_line(Vector2(x,h*0.18),Vector2(x,h*0.82),Color(0.79,0.58,0.34,0.23),1)
		for j in 3:
			var y := h*(0.23+0.27*float(j))
			draw_circle(Vector2(x,y),4.0,Color(0.82,0.62,0.38,0.34))
	draw_line(Vector2(w*0.06,h*0.50),Vector2(w*0.94,h*0.50),Color("#b18b5a"),3)
	draw_line(Vector2(w*0.06,h*0.505),Vector2(w*0.94,h*0.505),Color("#44302c"),2)
	# Four engraved corner jewels.
	for px in [w*0.055,w*0.945]:
		for py in [h*0.075,h*0.925]:
			var p := Vector2(px,py)
			draw_colored_polygon(PackedVector2Array([p+Vector2(0,-9),p+Vector2(7,0),p+Vector2(0,9),p+Vector2(-7,0)]),Color("#a27b53"))
			draw_circle(p,2.5,Color("#e1bb7a"))
