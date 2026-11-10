extends RefCounted
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
