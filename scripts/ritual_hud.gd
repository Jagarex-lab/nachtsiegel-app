extends Control
const T = preload("res://scripts/ui_tokens.gd")
var energy := 3
var energy_rect := Rect2(1380,445,210,76)
func _ready() -> void: mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	var r = energy_rect.grow(2)
	draw_style_box(T.panel(T.BRONZE,T.SURFACE),r)
	var center = r.get_center()
	for i in 10:
		var p = Vector2(center.x-90+i*20,r.end.y+8)
		var gem = PackedVector2Array([p+Vector2(0,-4),p+Vector2(3,0),p+Vector2(0,4),p+Vector2(-3,0)])
		draw_colored_polygon(gem,T.ENERGY if i<energy else T.STONE_LIGHT)
