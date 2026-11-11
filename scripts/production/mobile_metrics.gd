extends RefCounted
## Map one CSS viewport snapshot into the current Godot backing viewport.
## The backing buffer may still have its pre-rotation shape on Safari.
static func web_layout(viewport: Vector2, snapshot: Dictionary) -> Dictionary:
	var width=_positive(snapshot.get("width"),viewport.x)
	var height=_positive(snapshot.get("height"),viewport.y)
	var scale_value=Vector2(viewport.x/_positive(snapshot.get("canvasWidth"),width),viewport.y/_positive(snapshot.get("canvasHeight"),height))
	var insets: Dictionary=snapshot.get("insets",{}) if snapshot.get("insets",{}) is Dictionary else {}
	var safe=Rect2(Vector2(_nonnegative(insets.get("left")),_nonnegative(insets.get("top"))),Vector2.ZERO)
	safe.size=Vector2(maxf(1,width-safe.position.x-_nonnegative(insets.get("right"))),maxf(1,height-safe.position.y-_nonnegative(insets.get("bottom"))))
	var visible=Rect2(Vector2(_nonnegative(snapshot.get("visibleLeft")),_nonnegative(snapshot.get("visibleTop"))),Vector2(_positive(snapshot.get("visibleWidth"),width),_positive(snapshot.get("visibleHeight"),height)))
	var usable=safe.intersection(visible).intersection(Rect2(0,0,width,height))
	if usable.size.x<=0 or usable.size.y<=0:usable=Rect2(0,0,width,height)
	return {"position":usable.position*scale_value,"size":usable.size,"scale":scale_value,"portrait":bool(snapshot.get("portrait",height>width))}

static func _positive(value: Variant, fallback: float) -> float:
	if not value is float and not value is int:return maxf(1,fallback)
	return float(value) if is_finite(float(value)) and float(value)>0 else maxf(1,fallback)

static func _nonnegative(value: Variant) -> float:
	if not value is float and not value is int:return 0
	return maxf(0,float(value)) if is_finite(float(value)) else 0

## Native physical pixels -> logical touch units. Web uses measured canvas/CSS ratio.
static func native_density(scale_value: float, dpi: float, mobile: bool) -> float:
	if not mobile:return 1.0
	if is_finite(scale_value) and scale_value>1.01:return clampf(scale_value,1.0,4.0)
	# Android may report screen scale1; its display DPI still supplies dp density.
	if is_finite(dpi) and dpi>=120:return clampf(dpi/160.0,1.0,4.0)
	return 1.0

static func safe_insets(viewport: Vector2, safe: Rect2, window_origin: Vector2, density: float) -> Dictionary:
	var none={"left":0.0,"right":0.0,"top":0.0,"bottom":0.0}
	if density<=0 or not is_finite(density) or safe.size.x<=0 or safe.size.y<=0:return none
	var local=Rect2(safe.position-window_origin,safe.size).intersection(Rect2(Vector2.ZERO,viewport))
	if local.size.x<=0 or local.size.y<=0:return none
	return {"left":maxf(0,local.position.x)/density,"right":maxf(0,viewport.x-local.end.x)/density,"top":maxf(0,local.position.y)/density,"bottom":maxf(0,viewport.y-local.end.y)/density}
