extends Control
## Original painted-style vector placeholder art; no third-party IP.
@export var accent: Color = Color("#d76e43")
@export var archetype: String = "ASH"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0,58)
	resized.connect(queue_redraw)

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 2.0 or h < 2.0:
		return
	var c := Vector2(w*0.5,h*0.47)
	var r := minf(w*0.38,h*0.46)
	draw_rect(Rect2(Vector2.ZERO,size),Color("#0d111d"))
	# Atmospheric rays and concentric etched medallions.
	for i in 17:
		var a := TAU*float(i)/17.0
		var d := Vector2(cos(a),sin(a))
		draw_line(c+d*r*0.55,c+d*r*1.45,Color(accent,0.12),3.0)
	draw_circle(c,r*1.17,Color(accent,0.11))
	draw_circle(c,r*0.98,Color("#121927"))
	draw_arc(c,r*1.10,0,TAU,64,Color("#e2c18b",0.75),3.0)
	draw_arc(c,r*0.91,0,TAU,64,Color(accent,0.85),3.0)
	for i in 12:
		var a := TAU*float(i)/12.0
		var d := Vector2(cos(a),sin(a))
		draw_circle(c+d*r*1.1,2.1,Color("#f1d39d"))
	match archetype:
		"ASH":
			# Armored sentinel and burning helm.
			var helm := PackedVector2Array([c+Vector2(-r*0.32,-r*0.40),c+Vector2(0,-r*0.85),c+Vector2(r*0.32,-r*0.40),c+Vector2(r*0.25,r*0.12),c+Vector2(-r*0.25,r*0.12)])
			draw_colored_polygon(helm,accent.darkened(0.35))
			draw_polyline(helm,Color("#ffe2a7"),3.0,true)
			draw_line(c+Vector2(-r*0.22,-r*0.12),c+Vector2(r*0.22,-r*0.12),Color("#fff0c5"),3.0)
			draw_colored_polygon(PackedVector2Array([c+Vector2(-r*0.64,r*0.85),c+Vector2(-r*0.46,r*0.15),c+Vector2(r*0.46,r*0.15),c+Vector2(r*0.64,r*0.85)]),accent.darkened(0.5))
			draw_line(c+Vector2(0,r*0.18),c+Vector2(0,r*0.79),Color("#ffd38d"),5.0)
		"THORN":
			var wolf := PackedVector2Array([c+Vector2(-r*0.8,-r*0.82),c+Vector2(-r*0.42,-r*0.28),c+Vector2(0,-r*0.45),c+Vector2(r*0.42,-r*0.28),c+Vector2(r*0.8,-r*0.82),c+Vector2(r*0.52,r*0.36),c+Vector2(0,r*0.88),c+Vector2(-r*0.52,r*0.36)])
			draw_colored_polygon(wolf,accent.darkened(0.28))
			draw_polyline(wolf,Color("#c8e6b5"),2.5,true)
			for s in [-1,1]:
				draw_line(c+Vector2(s*r*0.48,-r*0.06),c+Vector2(s*r*0.14,r*0.06),Color("#f3f8c8"),4.0)
			draw_circle(c+Vector2(0,r*0.46),r*0.11,Color("#10221c"))
		"TIDE":
			draw_circle(c+Vector2(0,-r*0.2),r*0.58,accent.darkened(0.22))
			draw_arc(c+Vector2(0,-r*0.21),r*0.48,PI,TAU,32,Color("#d8f8ff"),4.0)
			for i in 5:
				var x := (float(i)-2.0)*r*0.23
				draw_line(c+Vector2(x,r*0.11),c+Vector2(x*1.3,r*0.82),accent,4.0)
			draw_circle(c+Vector2(0,-r*0.25),r*0.19,Color("#d8f8ff"))
		"VEIL":
			draw_circle(c+Vector2(0,-r*0.13),r*0.64,accent)
			draw_circle(c+Vector2(r*0.23,-r*0.31),r*0.63,Color("#121927"))
			for i in 5:
				draw_circle(c+Vector2((float(i)-2.0)*r*0.3,r*0.66+float(i%2)*r*0.09),2.8,Color("#eee0ff"))
		_:
			# Spell focus, suspended rune with intersecting rings.
			draw_arc(c,r*0.55,0,TAU,48,accent,5.0)
			draw_line(c+Vector2(0,-r*0.87),c+Vector2(0,r*0.87),Color("#ffe2aa"),5.0)
			draw_line(c+Vector2(-r*0.82,0),c+Vector2(r*0.82,0),Color("#ffe2aa"),5.0)
			draw_circle(c,r*0.15,Color("#fff0c7"))
	# Fine gilded inner picture-frame lines.
	draw_line(Vector2(5,5),Vector2(w-5,5),Color("#e6bc83",0.52),1.0)
	draw_line(Vector2(5,h-5),Vector2(w-5,h-5),Color("#e6bc83",0.52),1.0)
