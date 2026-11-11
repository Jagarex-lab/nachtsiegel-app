extends SceneTree
const Metrics=preload("res://scripts/production/mobile_metrics.gd")
var assertions:=0
var failures:=0
func check(ok: bool,label: String) -> void:
	assertions+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void:
	check(Metrics.native_density(3,460,true)==3,"native Retina scale wins over DPI approximation")
	check(Metrics.native_density(1,440,true)==2.75,"Android dp fallback handles physical display")
	check(Metrics.native_density(2,320,false)==1,"desktop geometry remains unchanged")
	for invalid in [NAN,INF,-INF,-1.0,0.0]:check(Metrics.native_density(invalid,invalid,true)==1,"invalid native metrics fall back safely")
	check(Metrics.native_density(8,1000,true)==4,"bounded staging density")
	var native_view=Vector2(2532,1170)
	var insets=Metrics.safe_insets(native_view,Rect2(132,0,2268,1107),Vector2.ZERO,3)
	check(insets.left==44 and insets.right==44 and insets.bottom==21 and insets.top==0,"physical notch and home indicator map to logical units")
	var shifted=Metrics.safe_insets(native_view,Rect2(232,200,2268,1107),Vector2(100,200),3)
	check(shifted==insets,"screen-space safe area subtracts window position")
	for rectangle in [Rect2(),Rect2(-10,-10,2600,1300),Rect2(10000,0,100,100)]:
		var value=Metrics.safe_insets(native_view,rectangle,Vector2.ZERO,3)
		check(value.left==0 and value.right==0 and value.top==0 and value.bottom==0,"unsupported/outside/oversize safe rectangles cannot push UI off screen")
	check(Metrics.safe_insets(native_view,Rect2(1,1,100,100),Vector2.ZERO,0).left==0,"zero density cannot divide")
	print("PRODUCTION MOBILE METRICS: %d assertions, %d failures; deterministic coordinate policy, not physical-device verification" % [assertions,failures])
	quit(1 if failures else 0)
