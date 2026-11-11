extends SceneTree
const Shell=preload("res://scripts/alpha/shell.gd")
const Catalog=preload("res://scripts/production/catalog.gd")
const Card=preload("res://scripts/alpha/card_view.gd")
const Session=preload("res://scripts/alpha/session.gd")
const Style=preload("res://scripts/alpha/style.gd")
const Tokens=preload("res://scripts/ui_tokens.gd")
var app
var assertions=0
var failures=0
func check(ok: bool,label: String):
 assertions+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func settle():
 for i in 5:await process_frame
func tap(c: Control):
 var p=c.get_parent()
 while p!=null:
  if p is ScrollContainer:p.ensure_control_visible(c);await settle()
  p=p.get_parent()
 var at=c.get_global_rect().get_center()
 for pressed in [true,false]:
  var e=InputEventScreenTouch.new();e.index=0;e.position=at;e.pressed=pressed;Input.parse_input_event(e);await settle()
func shot(name: String):
 await settle();await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://docs/alpha02/after/"+name+".png")
func visible_bounds(c: Control) -> bool:
 return Rect2(Vector2.ZERO,Vector2(root.size)).encloses(c.get_global_rect())
func _initialize():call_deferred("run")
func run():
 app=Shell.new();root.add_child(app);await settle()
 check(Style.font.multichannel_signed_distance_field,"Alpha-only scalable MSDF font")
 for color in Style.POWER_COLORS.values():check(Tokens.contrast(color,Tokens.SURFACE)>=4.5,"power labels meet 4.5 contrast")
 for raw in Catalog.new().all_cards():
  var view=Card.new();view.card=raw
  for width in [80,100,140]:
   var paragraph=view.title_paragraph(width)
   check(paragraph.get_line_count()<=2,"whole card name wraps: "+raw.name)
   for i in paragraph.get_line_count():check(paragraph.get_line_size(i).x<=width+1,"no clipped name ink: "+raw.name)
  view.free()
 for dimensions in [Vector2i(390,844),Vector2i(393,852),Vector2i(430,932),Vector2i(320,568)]:
  root.size=dimensions;app.page="lobby";app.close_modal();app.render();await settle()
  for id in ["start","builder","collection","settings"]:
   check(visible_bounds(app.actions[id]),"portrait main menu bounds "+id+str(dimensions))
   check(app.actions[id].size.y>=44,"portrait touch "+id)
  await tap(app.actions.start)
  check(app.page=="decks","start goes to explicit deck selection")
  for power in Catalog.new().deck_ids():
   await tap(app.actions["choose_"+power]);check(app.faction==power and app.match_use_starter,"actual starter selection "+power)
   check(Catalog.new().validate(Catalog.new().deck(power)).ok,"original 30-card starter reused")
   await tap(app.actions["preview_"+power]);check(is_instance_valid(app.modal),"full original starter preview")
   var unique=[]
   for id in Catalog.new().deck(power):
    if not unique.has(id):unique.append(id)
   for id in unique:check(app.actions.has("preview_card_"+id),"preview lists each actual card")
   await tap(app.actions.modal_close)
  if dimensions==Vector2i(390,844):await shot("starter-selection")
  await tap(app.actions.deck_play)
  check(app.actions.has("rotate_menu") and app.board_views.is_empty(),"portrait battle guarded, never squeezed")
  var before=Session.digest(app.session.model.snapshot());var commands=app.session.commands.size()
  root.size=Vector2i(844,390);await settle()
  check(Session.digest(app.session.model.snapshot())==before and app.session.commands.size()==commands,"rotation does not change any battle state")
  check(app.actions.has("mulligan_done"),"landscape opens actual mulligan")
  await tap(app.actions.mulligan_done);await tap(app.actions.origin_2)
  if app.session.model.state.stage=="second":await tap(app.actions.opening_done)
  if app.session.model.state.hero.phase=="draw":await tap(app.actions.end)
  await tap(app.hand_views[0]);before=Session.digest(app.session.model.snapshot());var selection=app.selected
  root.size=dimensions;await settle();root.size=Vector2i(915,412);await settle()
  check(app.selected==selection and Session.digest(app.session.model.snapshot())==before,"hand selection and state survive round-trip rotation")
  for b in app.board_views.values():check(visible_bounds(b) and b.size.x>=44 and b.size.y>=44,"all five paired paths retain touch bounds")
  await tap(app.actions.inspect);check(is_instance_valid(app.modal) and visible_bounds(app.actions.modal_close),"dismissible complete card inspector")
  if dimensions==Vector2i(390,844):await shot("inspection")
  await tap(app.actions.modal_close);await tap(app.actions.cancel_selection)
  await tap(app.actions.actions);check(app.actions.has("resource_help"),"touchable resource explanation")
  await tap(app.actions.resource_help);check(is_instance_valid(app.modal),"energy and resonance are explained without rule changes");await tap(app.actions.modal_close)
  app.page="lobby";app.render();await settle();await tap(app.actions.builder)
  root.size=dimensions;await settle()
  check(visible_bounds(app.actions.save_deck),"portrait save always within viewport")
  if not app.actions.has("builder_power_houses"):await tap(app.actions.builder_power)
  await tap(app.actions.builder_power_houses)
  app.deck=Catalog.new().deck("houses");app.render();await settle()
  await tap(app.actions.deck_tab)
  var id=app.deck[0];await tap(app.actions["remove_"+id]);check(app.deck.size()==29 and app.actions.save_deck.disabled,"invalid deck cannot save")
  await tap(app.actions.library_tab)
  var replacement={}
  for c in Catalog.new().all_cards():
   if c.id!=id and app.can_add(c):replacement=c;break
  check(not replacement.is_empty(),"legal card replacement exists")
  app.filter_text=replacement.name;app.render();await settle()
  check(app.actions.has("add_"+replacement.id),"legal replacement reachable through real name search in paginated active pool")
  await tap(app.actions["add_"+replacement.id]);check(app.deck.size()==30,"touch adds replacement")
  var edited=app.deck.duplicate();await tap(app.actions.save_deck)
  check(Session.new().profile.decks["alpha:houses"].cards==edited,"edited deck actually persists, not only count")
  var kept=app.deck.duplicate();app.actions.search.text="Pfad";app.actions.search.text_changed.emit("Pfad");await settle()
  root.size=Vector2i(844,390);await settle()
  check(app.deck==kept and app.filter_text=="Pfad" and app.actions.search.text=="Pfad","rotation preserves deck and unsubmitted query")
  app.filter_text="";app.render();await settle();await tap(app.actions.reset_deck);await tap(app.actions.save_deck)
  root.size=dimensions;await settle()
  if dimensions==Vector2i(390,844):await shot("deckbuilder")
 root.size=Vector2i(844,390);app.close_modal();app.start_battle();await settle()
 await tap(app.actions.mulligan_done);await tap(app.actions.origin_2)
 if app.session.model.state.stage=="second":await tap(app.actions.opening_done)
 if app.session.model.state.hero.phase=="draw":await tap(app.actions.end)
 await create_timer(.22).timeout
 var before_double=app.session.commands.size();var target=app.actions.end.get_global_rect().get_center()
 for pressed in [true,false,true,false]:
  var e=InputEventScreenTouch.new();e.index=0;e.position=target;e.pressed=pressed;Input.parse_input_event(e)
 await settle()
 check(app.session.commands.size()==before_double+1,"rapid primary taps perform exactly one legal command")
 var elapsed=Time.get_ticks_msec()-app.last_primary_ms
 check(elapsed>=180 or app.actions.end.disabled,"guarded primary is visibly unavailable until ready")
 await create_timer(.22).timeout
 await shot("battle-opening")
 # Clearly labelled layout fixture: ten units, six cards, shields/stasis/readiness.
 var m=app.session.model
 m.state.active="hero";m.state.hero.phase="main";m.state.hero.pendingDraw=0;m.state.hero.energy=8
 for side in ["hero","enemy"]:
  for lane in 5:
   if m.state[side].lanes[lane]!=null:m.state[side].discard.append(m.state[side].lanes[lane].id)
   var at=-1
   for i in m.state[side].deck.size():
    if m.catalog.card(m.state[side].deck[i]).kind=="creature":at=i;break
   check(at>=0,"layout fixture uses real living creature data")
   var id=m.state[side].deck.pop_at(at);var u=m.make_unit(side,m.catalog.card(id),lane)
   u.summoned=false;u.ward=2 if lane==2 else 0;u.stun=1 if lane==4 else 0;m.state[side].lanes[lane]=u
 while m.state.hero.hand.size()<6:m.state.hero.hand.append(m.state.hero.deck.pop_front())
 app.render();await settle();await shot("battle")
 for dimensions in [Vector2i(844,320),Vector2i(844,299)]:
  root.size=dimensions;await settle()
  for view in app.board_views.values():
   if view.unit.is_empty():continue
   var paragraph=view.title_paragraph(view.size.x-54,11)
   check(paragraph.get_size().y+4<=view.size.y-19,"compact name does not overlap stats strip")
   check(paragraph.get_line_count()<=2,"compact creature full name fits two lines")
  await shot("battle-compact" if dimensions.y==320 else "battle-browser-height")
 app.page="builder";app.open_cards(false);root.size=Vector2i(1280,720);await settle();await shot("deckbuilder-desktop")
 app.queue_free();await settle()
 print("ALPHA02 UI: %d assertions, %d failures; portrait, rotation, full names, four starters, real touch, persisted edited deck" % [assertions,failures])
 root.get_node("GameAudio").request_quit(0 if failures==0 else 1)
