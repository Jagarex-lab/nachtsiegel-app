extends SceneTree
const Shell=preload("res://scripts/alpha/shell.gd")
class PresentationShell extends Shell:
 # Arranged layout states are not replayable games and must not be saved.
 func _checkpoint_duel() -> void:pass
var assertions:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 assertions+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func settle() -> void:
 for _frame in 5:await process_frame
func bounded(c: Control) -> bool:return Rect2(Vector2.ZERO,Vector2(root.size)).encloses(c.get_global_rect()) and c.size.x>=44 and c.size.y>=44
func run() -> void:
 DirAccess.make_dir_recursive_absolute("res://work/production/desktop-hand")
 var app=PresentationShell.new();root.add_child(app);await settle()
 app.session.profile.reduced_motion=true;app.mode="alpha";app.faction="houses";app.start_battle();await settle()
 for dimensions in [Vector2i(844,390),Vector2i(915,412),Vector2i(844,320),Vector2i(1280,720),Vector2i(1600,900)]:
  root.size=dimensions;app.render();await settle()
  var expected:=160 if dimensions.y>=620 else 80 if dimensions.y<380 else 112
  check(app.hand_views.size()==5,"five real opening cards remain on actual battlefield")
  for v in app.hand_views:
   check(bounded(v) and v.size.y>=expected,"opening portraits fit and retain44px hit area "+str(dimensions))
   check(v.layout_report().role=="hand" and is_equal_approx(v.size.x/v.size.y,63.0/88.0),"opening uses canonical illustrated portrait cards")
  for v in app.board_views.values():check(bounded(v),"allten paired paths remain usable in opening "+str(dimensions))
  check(bounded(app.actions.mulligan_done),"opening confirmation remains visible "+str(dimensions))
 # This arranged UI boundary fills six legal card identities and puts ten real
 # creature views on the board. It is geometry evidence, not an additional duel.
 var m=app.session.model;m.state.stage="battle";m.state.active="hero";m.state.round=13;m.state.hero.phase="main"
 m.state.hero.hand=["oa-houses-c01","oa-houses-c02","oa-houses-c03","oa-houses-c04","oa-houses-c05","oa-houses-c06"]
 m.state.origins={"hero":2,"enemy":2}
 for side in ["hero","enemy"]:
  for lane in 5:
   var c: Dictionary=m.catalog.card("oa-houses-c01" if side=="hero" else "oa-stillwatch-c01")
   var u: Dictionary=m.make_unit(side,c,lane);u.summoned=false;m.state[side].lanes[lane]=u
 for dimensions in [Vector2i(844,390),Vector2i(915,412),Vector2i(844,320),Vector2i(1280,720),Vector2i(1600,900)]:
  root.size=dimensions;app.selected=-1;app.render();await settle()
  var expected:=160 if dimensions.y>=800 else 144 if dimensions.y>=620 else 66 if dimensions.y<380 else 80
  check(app.hand_views.size()==6,"all six real hand cards visible "+str(dimensions))
  for v in app.hand_views:
   check(bounded(v) and v.size.y>=expected,"actual battle hand height and44px hit area "+str(dimensions))
   check(v.layout_report().role=="hand" and is_equal_approx(v.size.x/v.size.y,63.0/88.0),"all six portrait costs, names and values remain distinct")
  for v in app.board_views.values():check(bounded(v),"allten occupied paths remain usable "+str(dimensions))
  check(bounded(app.actions.end) and bounded(app.actions.actions),"primary action and resource menu stay visible "+str(dimensions))
  check(app.board_views.hero0.large_board_portrait()==(dimensions.y>=620),"desktop portrait and mobile compact branch chosen from actual slot size")
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://work/production/desktop-hand/arranged-full-board-%dx%d.png" % [dimensions.x,dimensions.y])
 app.queue_free();await settle()
 print("PRODUCTION DESKTOP HAND: ",assertions," assertions, ",failures," failures;five native sizes,actual opening,arranged six-card/ten-unit layout")
 root.get_node("GameAudio").request_quit(1 if failures else 0)
