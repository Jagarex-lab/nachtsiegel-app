extends Control
var clock := 0.0
var candle_glow: GradientTexture2D
const CANDLES = [Vector2(125,329),Vector2(1529,501)]
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gradient = Gradient.new()
	gradient.set_color(0,Color(.9,.48,.17,.17))
	gradient.set_color(1,Color(.9,.48,.17,0))
	candle_glow = GradientTexture2D.new()
	candle_glow.gradient = gradient
	candle_glow.fill = GradientTexture2D.FILL_RADIAL
	candle_glow.fill_from = Vector2(.5,.5)
	candle_glow.fill_to = Vector2(1,.5)
func _process(delta: float) -> void:
	clock += delta
	queue_redraw()
func _draw() -> void:
	for i in 42:
		var x = fmod(float(i)*157.7+sin(clock*.15+i)*18,1600)
		var y = fposmod(float(i)*93.1-clock*(5+i%4),900)
		var alpha = .10+.15*(.5+sin(clock+i)*.5)
		draw_circle(Vector2(x,y),.6+float(i%3)*.4,Color(.64,.78,.8,alpha))
	for source in CANDLES:
		var flicker = .7+.15*sin(clock*3.7)+.1*sin(clock*7.1)
		if candle_glow: draw_texture_rect(candle_glow,Rect2(source-Vector2(65,75),Vector2(130,150)),false,Color(1,1,1,flicker))
		for i in 7:
			var age = fposmod(clock*.25+i*.17,1.0)
			var p = source+Vector2(sin(i*7+clock)*6,-age*55)
			draw_circle(p,.8,Color(.95,.57,.23,(1-age)*.25))
