extends Button
const FONT = preload("res://assets/fonts/Cinzel.ttf")
var caption := ""
var emphasis := false
var hover := false
func _ready() -> void:
	for state in ["normal","hover","pressed","disabled","focus"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = caption
	mouse_entered.connect(func(): hover = true; queue_redraw())
	mouse_exited.connect(func(): hover = false; queue_redraw())
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
func _draw() -> void:
	var w = size.x
	var h = size.y
	var y = 16.0
	var bh = h-32
	var edge = Color("#cfb17e") if emphasis or hover else Color("#8e8369")
	if disabled: edge = Color("#686b69")
	var polygon = PackedVector2Array([Vector2(17,y),Vector2(w-17,y),Vector2(w-4,h/2),Vector2(w-17,y+bh),Vector2(17,y+bh),Vector2(4,h/2),Vector2(17,y)])
	var shadow = PackedVector2Array()
	for p in polygon: shadow.append(p+Vector2(0,5))
	draw_colored_polygon(shadow,Color(0,0,0,.8))
	draw_colored_polygon(polygon,Color("#242a2b") if not emphasis else Color("#3d3024"))
	draw_polyline(polygon,edge,2,true)
	var inset = PackedVector2Array([Vector2(23,y+5),Vector2(w-23,y+5),Vector2(w-11,h/2),Vector2(w-23,y+bh-5),Vector2(23,y+bh-5),Vector2(11,h/2),Vector2(23,y+5)])
	draw_colored_polygon(inset,Color("#12222a") if not emphasis else Color("#443729"))
	draw_polyline(inset,Color("#584c3a"),1,true)
	draw_line(Vector2(26,y+7),Vector2(w-26,y+7),Color("#d2ba89",.45),1,true)
	draw_line(Vector2(28,y+bh-8),Vector2(w-28,y+bh-8),Color(0,0,0,.65),3,true)
	for x in [20.0,w-20]:
		var jewel = PackedVector2Array([Vector2(x,h/2-7),Vector2(x+4,h/2),Vector2(x,h/2+7),Vector2(x-4,h/2),Vector2(x,h/2-7)])
		draw_colored_polygon(jewel,Color("#84c6bc") if emphasis or hover else Color("#8c9d94"))
	var fs = 22
	while FONT.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x > w-48 and fs > 11: fs -= 1
	var length = FONT.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x
	draw_string(FONT,Vector2((w-length)/2,h/2+fs*.32+1),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,Color("#ead9b7") if not disabled else Color("#8d9a99"))
	if has_focus(): draw_polyline(polygon,Color("#9edbd1"),2,true)
