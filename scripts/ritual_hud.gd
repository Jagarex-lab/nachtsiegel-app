extends Control
const T = preload("res://scripts/ui_tokens.gd")
var energy := 3
func _ready() -> void: mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	draw_style_box(T.panel(T.METAL),Rect2(1355,106,235,682))
	var c = Vector2(1475,205)
	draw_circle(c,49,T.INK)
	draw_circle(c,43,T.SURFACE)
	if T.ink_visible: draw_arc(c,45,0,TAU,72,T.ENERGY,3,true)
	for i in 10:
		var p = Vector2(1380+i*20,267)
		var gem = PackedVector2Array([p+Vector2(0,-6),p+Vector2(4,0),p+Vector2(0,6),p+Vector2(-4,0),p+Vector2(0,-6)])
		draw_colored_polygon(gem,T.ENERGY if i < energy else T.SURFACE_RAISED)
		if T.ink_visible: draw_polyline(gem,T.ENERGY if i < energy else T.SECONDARY,1,true)
