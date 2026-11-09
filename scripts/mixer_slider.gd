extends HSlider
## Native Range keyboard/touch behaviour with the same opaque material as other UI.
const T=preload("res://scripts/ui_tokens.gd")
var contrast_regions: Array=[]
func _ready() -> void:
	for state in ["slider","grabber_area","grabber_area_highlight"]:add_theme_stylebox_override(state,StyleBoxEmpty.new())
	var img=Image.create_empty(1,1,false,Image.FORMAT_RGBA8);img.fill(Color.TRANSPARENT)
	var texture=ImageTexture.create_from_image(img)
	for state in ["grabber","grabber_highlight","grabber_disabled"]:add_theme_icon_override(state,texture)
	value_changed.connect(_changed);focus_entered.connect(queue_redraw);focus_exited.connect(queue_redraw)
func _changed(_value: float) -> void:queue_redraw()
func contrast_samples() -> Array:return contrast_regions
func _draw() -> void:
	contrast_regions.clear()
	draw_style_box(T.panel(T.METAL,T.SURFACE),Rect2(Vector2.ZERO,size))
	var y=size.y/2;var x=20+(size.x-40)*(value-min_value)/maxf(.001,max_value-min_value)
	var edge=T.FOCUS if has_focus() else T.SECONDARY
	contrast_regions.append(T.sample(Rect2(20,y-2,size.x-40,4),edge,"mixer track",3))
	contrast_regions.append(T.sample(Rect2(x-11,y-11,22,22),T.ENERGY,"mixer thumb",3))
	if T.ink_visible:
		draw_line(Vector2(20,y),Vector2(size.x-20,y),edge,4,true)
		draw_line(Vector2(20,y),Vector2(x,y),T.ENERGY,5,true)
		draw_circle(Vector2(x,y),11,T.ENERGY)
