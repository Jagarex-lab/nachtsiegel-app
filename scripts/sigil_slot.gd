extends Button
var legal := false
var occupied := false
var enemy := false
var elapsed := 0.0
func _ready() -> void:
	for state in ["normal","hover","pressed","disabled","focus"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
func _process(delta: float) -> void:
	if legal:
		elapsed += delta
		queue_redraw()
func _draw() -> void:
	if occupied: return
	var center = size/2
	var radius = minf(size.x*.40,size.y*.36)
	var hue = Color("#73d8c0") if legal else Color("#b5a174",.30)
	if enemy: hue = Color("#b48c78",.20)
	var shadow = PackedVector2Array()
	for i in 64:
		var unit = Vector2(cos(TAU*i/64.0),sin(TAU*i/64.0))
		shadow.append(center+unit*Vector2(radius,radius*1.12))
	draw_colored_polygon(shadow,Color(.02,.04,.05,.17))
	for ring in [0.80,1.0]:
		var line = PackedVector2Array()
		for i in 65:
			var unit = Vector2(cos(TAU*i/64.0),sin(TAU*i/64.0))
			line.append(center+unit*Vector2(radius,radius*1.12)*ring)
		draw_polyline(line,hue,1.2 if not legal else 2.0,true)
	for i in 12:
		var v = Vector2(cos(TAU*i/12.0),sin(TAU*i/12.0))*Vector2(1,1.12)
		draw_line(center+v*radius*.87,center+v*radius*.93,hue,1,true)
	var rune = PackedVector2Array([center+Vector2(0,-16),center+Vector2(10,0),center+Vector2(0,16),center+Vector2(-10,0),center+Vector2(0,-16)])
	draw_polyline(rune,hue,1.5,true)
	if legal:
		var pulse = .5+.5*sin(elapsed*3)
		draw_circle(center,5+pulse*3,Color(.5,1,.83,.2))
		draw_string(ThemeDB.fallback_font,center+Vector2(-18,39),"ZIEL",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("#cff1d5"))
