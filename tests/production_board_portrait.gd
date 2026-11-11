extends SceneTree
const View=preload("res://scripts/alpha/card_view.gd")
const Style=preload("res://scripts/alpha/style.gd")
var assertions:=0
var failures:=0
var viewport: SubViewport
var view
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 assertions+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func unit_for(card: Dictionary) -> Dictionary:
 return {"id":card.id,"atk":40,"hp":int(card.hp),"ward":25,"block":25,"stun":2,"summoned":false,"extra_attacks":1}
func capture(card: Dictionary,dimensions: Vector2i,filename: String) -> void:
 viewport.size=dimensions;view.size=dimensions;view.card=card;view.unit=unit_for(card)
 view.queue_redraw()
 for _frame in 3:await process_frame
 await RenderingServer.frame_post_draw
 var image=viewport.get_texture().get_image()
 check(image.get_size()==dimensions,"actual portrait framebuffer dimensions")
 check(image.save_png("res://work/production/board-portraits/"+filename)==OK,"save real framebuffer evidence")
 # The old 66px strip left these three distant art columns uniformly dark.
 # This is measured from the actual rendered image, separate from the layout API.
 if dimensions.y>=160 and dimensions.x>=170:
  var varied_columns:=0
  for x in [int(dimensions.x*.35),int(dimensions.x*.6),int(dimensions.x*.85)]:
   var minimum:=1.0;var maximum:=0.0
   for y in range(47,dimensions.y-65,3):
    var c=image.get_pixel(x,y);var light=(c.r+c.g+c.b)/3.0
    minimum=minf(minimum,light);maximum=maxf(maximum,light)
   if maximum-minimum>.025:varied_columns+=1
  check(varied_columns>=2,"illustration visibly spans the wide portrait, beyond the obsolete narrow side strip")
func run() -> void:
 var cards: Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/production/cards.json")).cards
 var measured:=0
 var sample: Dictionary={}
 view=View.new();view.lane=2
 for card in cards:
  if card.kind!="creature":continue
  measured+=1;view.card=card;view.unit=unit_for(card);view.origin=true;view.convergence=true
  if card.id=="oa-houses-c01":sample=card
  for dimensions in [Vector2i(170,160),Vector2i(240,260),Vector2i(310,340)]:
   view.size=dimensions
   check(view.large_board_portrait(),"actual large field slot gets full portrait "+card.id)
   var title=view.title_paragraph(view.board_title_width(),12,32)
   check(title.get_line_count()<=2 and title.get_size().y<=32,"whole actual creature name fits opaque header "+card.id)
   for line in title.get_line_count():check(title.get_line_size(line).x<=view.board_title_width(),"actual name ink stays clear of occupied path badge "+card.id)
   var labels=view.tall_board_labels()
   check(labels.combat_text.contains("40 ANG") and labels.combat_text.contains(str(int(card.hp))+" LP"),"current attack/life retained "+card.id)
   check(labels.status.contains("Schild 25") and labels.status.contains("Block 25") and labels.status.contains("Z2"),"shield/block/readiness remain separately labelled "+card.id)
   check(Style.font.get_string_size(labels.combat_text,HORIZONTAL_ALIGNMENT_LEFT,-1,labels.value_font).x<=dimensions.x-20,"actual value ink fits "+card.id)
   check(Style.font.get_string_size(labels.status,HORIZONTAL_ALIGNMENT_LEFT,-1,labels.status_font).x<=dimensions.x-20,"actual status ink fits "+card.id)
  for dimensions in [Vector2i(144,60),Vector2i(144,80),Vector2i(160,90),Vector2i(240,119)]:
   view.size=dimensions;check(not view.large_board_portrait(),"small mobile field keeps its compact arrangement "+card.id)
   if dimensions.y>=72:
    var width=dimensions.x-minf(66,dimensions.x*.35)-17
    var layout=view.title_layout(width,12,maxf(20,dimensions.y-47))
    check(layout.fits and layout.font_size>=10,"whole actual compact creature name fits at10px or larger "+card.id)
    for line in layout.paragraph.get_line_count():check(layout.paragraph.get_line_size(line).x<=width,"actual compact name ink stays above values "+card.id)
 check(measured==357,"all357 actual production creatures measured")
 check(not sample.is_empty(),"real individually illustrated render sample exists")
 DirAccess.make_dir_recursive_absolute("res://work/production/board-portraits")
 viewport=SubViewport.new();viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(viewport);viewport.add_child(view)
 for dimensions in [Vector2i(170,160),Vector2i(240,260),Vector2i(310,340),Vector2i(160,90),Vector2i(144,60)]:
  await capture(sample,dimensions,"actual-unit-%dx%d.png" % [dimensions.x,dimensions.y])
 for card in cards:
  if card.id in ["oa-stillwatch-c07","of-morph-064","of-neutral-056"]:
   await capture(card,Vector2i(144,80),"compact-name-"+str(card.id)+".png")
 view.queue_free();viewport.queue_free()
 for _frame in 3:await process_frame
 print("PRODUCTION BOARD PORTRAIT: ",assertions," assertions, ",failures," failures;357 real compact/tall creature names and combat labels,8 actual native renders")
 root.get_node("GameAudio").request_quit(1 if failures else 0)
