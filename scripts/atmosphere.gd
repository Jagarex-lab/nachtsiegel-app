extends Control
var clock := 0.0
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _process(delta: float) -> void:
	clock += delta
	queue_redraw()
func _draw() -> void:
	for i in 42:
		var x = fmod(float(i)*157.7+sin(clock*0.15+i)*18,1600)
		var y = fposmod(float(i)*93.1-clock*(5+i%4),900)
		var alpha = 0.12+0.17*(0.5+sin(clock+i)*0.5)
		draw_circle(Vector2(x,y),1.0+float(i%3)*0.5,Color(0.6,0.85,0.82,alpha))
	for x in [58.0,1542.0]:
		var flame = Vector2(x,350)
		for r in range(7,0,-1):
			draw_circle(flame,float(r)*9,Color(0.97,0.42,0.15,0.009))
		draw_circle(flame,5+sin(clock*5)*1.5,Color("#f9cb80"))
