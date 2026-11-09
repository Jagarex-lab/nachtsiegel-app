extends Button
const T = preload("res://scripts/ui_tokens.gd")
var caption := ""
var emphasis := false
var hover := false
var view_scale := .8
var contrast_regions: Array = []
func _ready() -> void:
	for state in ["normal","hover","pressed","disabled","focus"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = caption
	mouse_entered.connect(func(): hover = true; queue_redraw())
	mouse_exited.connect(func(): hover = false; queue_redraw())
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
func contrast_samples() -> Array: return contrast_regions
func _draw() -> void:
	contrast_regions.clear()
	var w = size.x
	var h = size.y
	var edge = T.GOLD if emphasis else T.SECONDARY
	if hover or has_focus(): edge = T.FOCUS
	if disabled: edge = T.MUTED
	var polygon = PackedVector2Array([Vector2(13,3),Vector2(w-13,3),Vector2(w-3,h/2),Vector2(w-13,h-3),Vector2(13,h-3),Vector2(3,h/2),Vector2(13,3)])
	draw_colored_polygon(polygon,T.SURFACE)
	draw_polyline(polygon,T.INK,9,true)
	if T.ink_visible: draw_polyline(polygon,edge,maxf(2,1.5/view_scale),true)
	contrast_regions.append(T.sample(Rect2(w*.35,1,w*.3,4),edge,"action boundary",3))
	var fs = T.font_size(23,view_scale,13)
	var lines: PackedStringArray = PackedStringArray([caption])
	if T.FONT.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x > w-30:
		lines = caption.split(" ",false,1)
	var line_h = fs*1.22
	var top = h/2-lines.size()*line_h/2
	for i in lines.size():
		var line = lines[i]
		var width = T.FONT.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x
		var baseline = top+i*line_h+fs
		var rect = Rect2((w-width)/2,baseline-T.FONT.get_ascent(fs),width,T.FONT.get_height(fs))
		contrast_regions.append(T.sample(rect,T.TEXT,"action text"))
		if T.ink_visible: draw_string(T.FONT,Vector2((w-width)/2,baseline),line,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,T.TEXT)
