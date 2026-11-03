extends Control
## Procedural original card vignette; scalable and license-safe.
@export var accent: Color = Color("#d76e43")
@export var archetype: String = "ASH"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 58)

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 1.0 or h < 1.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("#0c0b17"))
	for i in 7:
		var y := h * float(i) / 7.0
		draw_line(Vector2(0,y),Vector2(w,y-12),accent.darkened(0.74),1.0)
	draw_circle(Vector2(w*0.5,h*0.49),h*0.37,accent.darkened(0.73))
	draw_arc(Vector2(w*0.5,h*0.49),h*0.35,0.0,TAU,44,accent,2.0,true)
	match archetype:
		"ASH":
			var pts := PackedVector2Array([Vector2(w*0.5,h*0.08),Vector2(w*0.72,h*0.65),Vector2(w*0.52,h*0.87),Vector2(w*0.29,h*0.63)])
			draw_colored_polygon(pts,accent)
			draw_colored_polygon(PackedVector2Array([Vector2(w*0.5,h*0.39),Vector2(w*0.60,h*0.70),Vector2(w*0.42,h*0.75)]),Color("#ffdc92"))
		"THORN":
			for i in 5:
				var x := w*(0.25+float(i)*0.125)
				draw_line(Vector2(w*0.5,h*0.85),Vector2(x,h*0.17+float(i%2)*h*0.2),accent,5.0,true)
			draw_circle(Vector2(w*0.5,h*0.55),h*0.13,Color("#c6e8b3"))
		"TIDE":
			for i in 3:
				draw_arc(Vector2(w*0.5,h*(0.42+float(i)*0.12)),h*(0.16+float(i)*0.07),0.1,PI-0.1,24,accent,4.0,true)
			draw_circle(Vector2(w*0.5,h*0.30),h*0.13,Color("#c1f1f2"))
		"VEIL":
			draw_circle(Vector2(w*0.5,h*0.45),h*0.23,accent)
			draw_circle(Vector2(w*0.58,h*0.35),h*0.22,Color("#0c0b17"))
			for i in 4:
				draw_circle(Vector2(w*(0.25+0.17*float(i)),h*0.79),3.0,Color("#d8c2ff"))
		_:
			draw_circle(Vector2(w*0.5,h*0.48),h*0.23,accent)
			draw_line(Vector2(w*0.5,h*0.1),Vector2(w*0.5,h*0.85),Color("#f8dfb5"),4.0,true)
			draw_line(Vector2(w*0.22,h*0.5),Vector2(w*0.78,h*0.5),Color("#f8dfb5"),4.0,true)
