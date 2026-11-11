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
	var safari={"width":844,"height":390,"canvasWidth":844,"canvasHeight":390,"portrait":false,"visibleWidth":844,"visibleHeight":390,"insets":{"left":47,"right":47,"bottom":21}}
	var fitted=Metrics.web_layout(Vector2(390,844),safari)
	check(not fitted.portrait,"landscape CSS viewport wins over stale portrait backing buffer")
	check(fitted.size==Vector2(750,369),"notch and home indicator bound the landscape UI")
	check(fitted.position.is_equal_approx(Vector2(47*390.0/844,0)),"safe origin maps to stale backing buffer")
	check(fitted.scale.is_equal_approx(Vector2(390.0/844,844.0/390)),"each backing axis maps independently during Safari rotation")
	check(is_equal_approx(44*fitted.scale.x/(390.0/844),44) and is_equal_approx(44*fitted.scale.y/(844.0/390),44),"44 CSS pixel targets survive stale nonuniform backing buffer")
	safari.merge({"visibleLeft":60,"visibleTop":80,"visibleWidth":700,"visibleHeight":220},true)
	fitted=Metrics.web_layout(Vector2(1688,780),safari)
	check(fitted.size==Vector2(700,220) and fitted.position==Vector2(120,160),"visual offset intersects safe area without charging insets twice")
	check(not fitted.portrait and fitted.size.y<248,"short landscape remains landscape and selects space guidance")
	safari.merge({"width":390,"height":310,"canvasWidth":390,"canvasHeight":310,"portrait":true,"visibleLeft":0,"visibleTop":0,"visibleWidth":390,"visibleHeight":310,"insets":{}},true)
	fitted=Metrics.web_layout(Vector2(1170,930),safari)
	check(fitted.portrait,"keyboard-shrunken portrait retains viewport snapshot orientation")
	for invalid in [NAN,INF,-INF,-1.0,0.0,"bad",null]:
		fitted=Metrics.web_layout(Vector2(844,390),{"width":invalid,"height":invalid,"canvasWidth":invalid,"canvasHeight":invalid})
		check(fitted.size==Vector2(844,390) and fitted.scale==Vector2.ONE,"invalid web metrics fall back safely")
	print("PRODUCTION MOBILE METRICS: %d assertions, %d failures; deterministic coordinate policy, not physical-device verification" % [assertions,failures])
	quit(1 if failures else 0)
