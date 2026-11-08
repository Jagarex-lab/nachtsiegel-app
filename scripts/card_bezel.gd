extends Control
## Decorative card bezel. Keeps the art area as a replaceable placeholder.
@export var accent: Color = Color("#b98b62")
@export var selected: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 10.0 or h < 10.0:
		return
	var gold := Color("#ead2a2") if selected else Color("#947557")
	draw_rect(Rect2(1,1,w-2,h-2),Color("#16131b"),false,2)
	draw_rect(Rect2(5,5,w-10,h-10),gold,false,1)
	draw_rect(Rect2(9,25,w-18,h*0.55),accent.darkened(0.86),true)
	draw_rect(Rect2(9,25,w-18,h*0.55),accent.darkened(0.22),false,2)
	draw_rect(Rect2(8,h-34,w-16,1),gold,true)
	for x in [12.0,w-12.0]:
		for y in [12.0,h-12.0]:
			var p := Vector2(x,y)
			draw_colored_polygon(PackedVector2Array([p+Vector2(0,-4),p+Vector2(4,0),p+Vector2(0,4),p+Vector2(-4,0)]),gold)
