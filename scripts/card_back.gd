extends Control
const FRAME = preload("res://assets/art/reliquary_frame.png")
const T = preload("res://scripts/ui_tokens.gd")
func _ready() -> void: mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	for layer in range(3,-1,-1):
		var r = Rect2(Vector2(layer*3,-layer*3),size)
		draw_style_box(T.panel(T.BRONZE,T.SURFACE_RAISED),r)
	draw_texture_rect(FRAME,Rect2(Vector2.ZERO,size),false,Color(.6,.66,.72,.65))
	var c = size/2
	var points = PackedVector2Array([c+Vector2(0,-42),c+Vector2(31,0),c+Vector2(0,42),c+Vector2(-31,0),c+Vector2(0,-42)])
	draw_polyline(points,T.BRONZE,3,true)
	for i in 5:
		var x = c.x-22+i*11
		draw_line(Vector2(x,c.y-14),Vector2(x,c.y+14),T.BRONZE,2,true)
