extends Button
const T = preload("res://scripts/ui_tokens.gd")
var legal := false
var occupied := false
var enemy := false
var choosing := false
var reduced_motion := false
var view_scale := .8
var hovered := false
var elapsed := 0.0
var contrast_regions: Array = []
func _ready() -> void:
	for state in ["normal","hover","pressed","disabled","focus"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func(): hovered = true; queue_redraw())
	mouse_exited.connect(func(): hovered = false; queue_redraw())
	focus_entered.connect(queue_redraw); focus_exited.connect(queue_redraw)
func _process(delta: float) -> void:
	if legal and not reduced_motion: elapsed += delta; queue_redraw()
func contrast_samples() -> Array: return contrast_regions
func _draw() -> void:
	contrast_regions.clear()
	if occupied: return
	var center = Vector2(size.x/2,size.y*.42)
	var r = minf(size.x*.25,size.y*.25)
	var hue = T.SUCCESS if legal else (T.WARNING if choosing else T.MUTED)
	var ring = PackedVector2Array()
	for i in 65: ring.append(center+Vector2(cos(TAU*i/64),sin(TAU*i/64))*r)
	draw_colored_polygon(ring,Color(T.SURFACE,.94))
	draw_polyline(ring,T.INK,9,true)
	if T.ink_visible: draw_polyline(ring,hue,3 if choosing or hovered or has_focus() else 2,true)
	contrast_regions.append(T.sample(Rect2(center.x+r-1,center.y-2,2,4),hue,"target boundary",3))
	var fs = T.font_size(28,view_scale,13)
	var mark = "+" if not choosing else ("✓" if legal else "×")
	var width = T.FONT.get_string_size(mark,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x
	var baseline = center.y+fs*.3
	var text_r = Rect2(center.x-width/2,baseline-T.FONT.get_ascent(fs),width,T.FONT.get_height(fs))
	draw_rect(text_r.grow(2),T.SURFACE)
	contrast_regions.append(T.sample(text_r,hue,"target symbol"))
	if T.ink_visible: draw_string(T.FONT,Vector2(center.x-width/2,baseline),mark,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,hue)
	if legal and not reduced_motion: draw_arc(center,r+8,elapsed,elapsed+PI*.65,32,Color(T.SUCCESS,.6),2,true)
