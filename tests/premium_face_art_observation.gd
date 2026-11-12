extends SceneTree
## Readonly QA boundary: cache/normalization cannot stand in for a real draw.
## Actual framebuffer/binding checks belong to the graphical illustration chain.
const Face=preload("res://scripts/card_system/card_face.gd")
const ART=preload("res://scripts/production/art_resolver.gd")
var assertions:=0
var failures:=0
func check(ok: bool,message: String) -> void:
 assertions+=1
 if not ok:failures+=1;printerr("FAIL: ",message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var cards: Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/production/cards.json")).cards
 var face=Face.new();face.card=cards[0];face.size=Vector2(240,336)
 var before:=ART.stats()
 var first=face.art_report()
 check(first.status=="unbound" and first.pixels.is_empty() and first.card_id.is_empty(),"undrawn face cannot claim available cached pixels")
 check(ART.stats()==before,"observation performs no resolve/cache/request side effect")
 var actual=face.normalized()
 check(actual.illustration is Texture2D,"actual original illustration is available to the canonical renderer")
 var cached:=ART.stats()
 var measured=face.layout_report();var after_measure=face.art_report()
 check(measured.title_fits and after_measure.status=="unbound" and after_measure.pixels.is_empty(),"loading and measuring real art still cannot masquerade as a drawn image")
 var stable:=ART.stats()
 for i in 50:face.art_report()
 check(ART.stats()==stable,"repeated bound-pixel observation does not advance delivery/cache state")
 face.card=cards[1]
 check(face.art_report().status=="unbound" and face.art_report().requested_card_id==cards[1].id,"changed identity stays unbound until its own draw")
 face.face_down=true
 check(face.art_report().card_id.is_empty() and face.art_report().requested_card_id.is_empty() and face.art_report().pixels.is_empty(),"hidden face report leaks no front identity or old pixels")
 face.free()
 print("PREMIUM FACE ART OBSERVATION: ",assertions," assertions, ",failures," failures; readonly observer, normalization is not a draw, changed/hidden identity")
 root.get_node("GameAudio").request_quit(1 if failures else 0)
