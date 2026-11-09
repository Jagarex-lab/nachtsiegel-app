extends RefCounted
## Semantic UI palette. Texture/illustration pigments are decorative, never text colours.
const SURFACE = Color("#10141d")
const SURFACE_RAISED = Color("#1c2532")
const TEXT = Color("#f3ede2")
const SECONDARY = Color("#bfc4ce")
const GOLD = Color("#f3d48a")
const PLAYER = Color("#79ddd4")
const FOE = Color("#edabb7")
const ENERGY = Color("#81ddff")
const SUCCESS = Color("#a0edb8")
const WARNING = Color("#ffc57d")
const DANGER = Color("#ffaaa4")
const FOCUS = Color("#d6e3ff")
const MUTED = Color("#9eaaba")
const INK = Color("#080c13")
const METAL = Color("#877351")
const SHADOW = Color(0,0,0,0.85)
const FONT = preload("res://assets/fonts/Body.ttf")
const DISPLAY = preload("res://assets/fonts/Cinzel.ttf")
static var ink_visible := true

static func luminance(color: Color) -> float:
	var linear = color.srgb_to_linear()
	return .2126*linear.r+.7152*linear.g+.0722*linear.b
static func contrast(a: Color, b: Color) -> float:
	return (maxf(luminance(a),luminance(b))+.05)/(minf(luminance(a),luminance(b))+.05)
static func font_size(base: int, scale: float, minimum_css: float = 12.0) -> int:
	return maxi(base,int(ceil(minimum_css/maxf(scale,.2))))
static func panel(edge: Color = METAL, fill: Color = SURFACE) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style
static func palette() -> Dictionary:
	return {"surface":SURFACE,"raised":SURFACE_RAISED,"text":TEXT,"secondary":SECONDARY,"action":GOLD,"player":PLAYER,"foe":FOE,"energy":ENERGY,"success":SUCCESS,"warning":WARNING,"damage":DANGER,"focus":FOCUS,"muted":MUTED,"ink":INK}
static func sample(rect: Rect2, color: Color, role: String, threshold: float = 4.5) -> Dictionary:
	return {"rect":rect,"color":color.to_html(false),"role":role,"threshold":threshold}

# Premium material grammar: light from upper left; dark lower/right bevels.
const STONE = Color("#202b35")
const STONE_LIGHT = Color("#3b4a53")
const BRONZE = Color("#a18b65")
const WOOD = Color("#372c29")
const FELT = Color("#1b3034")
const SPACE := 12.0
const TOUCH_CSS := 44.0
const HAND_WIDTH := 178.0
const HAND_HEIGHT := 204.0
const SELECT_SCALE := 1.24
const SELECT_LIFT := 10.0
const MOTION_SELECT := .16
const MOTION_DRAW := .24
const MOTION_ATTACK := .18
const BORDER := 3.0
const SHADOW_OFFSET := Vector2(5,9)
