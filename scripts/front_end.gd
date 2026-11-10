extends Node
## Front-end routing owns the local session; battle rules remain in BattleModel.
const T = preload("res://scripts/ui_tokens.gd")
const Brand = preload("res://scripts/brand_identity.gd")
const Catalog = preload("res://scripts/campaign_catalog.gd")
const Lore = preload("res://scripts/narrative_catalog.gd")
const Cards = preload("res://data/card_definitions.gd")
const Face = preload("res://scripts/card_face.gd")
const ButtonFace = preload("res://scripts/ritual_button.gd")
var store
var screen: Control
var layer: CanvasLayer
var current_page := "start"
var actions: Dictionary = {}
var labels: Array = []
var scale_factor := .8
var density := 1.0
var logical_width := 1600.0
var battle_node
var run_id := ""
var run_mode := "quick"
var current_chapter := 0
var search_query := ""
var faction_filter := 0
var show_concepts := false
var collection_grid: GridContainer
var collection_scroll: ScrollContainer
var results_label: Label
var search_field: LineEdit
var visible_card_ids: Array = []
var leaving_battle := false
var keyboard_layout := false
var qa_enabled := false
var clock := 0.0
var audio_sliders: Dictionary={}
func _ready() -> void:
	if store==null: store=preload("res://scripts/progress_store.gd").new()
	get_node("/root/GameAudio").apply(store.data.settings.audio)
	Brand.apply_window_title()
	get_tree().quit_on_go_back=false
	layer=CanvasLayer.new();add_child(layer)
	screen=Control.new();layer.add_child(screen)
	get_viewport().size_changed.connect(_resize)
	if get_tree().root.has_signal("go_back_requested"):get_tree().root.connect("go_back_requested",_go_back)
	if OS.has_feature("web"): qa_enabled=bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('qa')==='1'"))
	_resize()
func _safe_rect(available: Vector2) -> Rect2:
	if OS.has_feature("web"):
		var css_width=float(JavaScriptBridge.eval("document.querySelector('canvas').getBoundingClientRect().width"))
		density=maxf(1,available.x/maxf(1,css_width))
		var d=JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify(window.nachtsiegelInsets?window.nachtsiegelInsets():{})")))
		if d is Dictionary:
			return Rect2(float(d.get("left",0))*density,float(d.get("top",0))*density,available.x-float(d.get("left",0)+d.get("right",0))*density,available.y-float(d.get("top",0)+d.get("bottom",0))*density)
	elif OS.has_feature("android") or OS.has_feature("ios"):
		density=maxf(1,DisplayServer.screen_get_dpi()/160.0)
		var full=DisplayServer.screen_get_size();var safe=DisplayServer.get_display_safe_area()
		if full.x>0 and safe.size.x>0:
			var ratio=available/Vector2(full);return Rect2(Vector2(safe.position)*ratio,Vector2(safe.size)*ratio)
	return Rect2(Vector2.ZERO,available)
func _resize() -> void:
	if screen==null:return
	var available=get_viewport().get_visible_rect().size
	if current_page=="collection" and is_instance_valid(search_field) and search_field.has_focus() and available.y/density<300:
		keyboard_layout=true
		for label in labels:
			if is_instance_valid(label):label.visible=false
		for id in ["filter","concepts"]:
			if actions.has(id):actions[id].visible=false
		search_field.position.y=10/scale_factor;search_field.size.x=logical_width-430
		collection_scroll.position.y=search_field.position.y+search_field.size.y+20
		var typing_safe=_safe_rect(available)
		collection_scroll.size.y=maxf(60,(typing_safe.end.y-screen.position.y)/screen.scale.y-collection_scroll.position.y-15)
		return
	keyboard_layout=false
	var safe=_safe_rect(available)
	var physical=minf(safe.size.x/1600,safe.size.y/900)
	scale_factor=physical/density;logical_width=maxf(1600,safe.size.x/physical)
	screen.scale=Vector2.ONE*physical;screen.position=safe.position;screen.size=Vector2(logical_width,900)
	if current_page!="battle": show_page(current_page)
func _put(node: Control, rect: Rect2, parent: Node = null) -> void:
	node.position=rect.position;node.size=rect.size;(parent if parent!=null else screen).add_child(node)
func _label(text: String, rect: Rect2, fs: int = 30, color: Color = T.TEXT, serif: bool = false, minimum: float = 12) -> Label:
	var node=Label.new();node.mouse_filter=Control.MOUSE_FILTER_IGNORE;node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_override("font",T.DISPLAY if serif else T.FONT);node.add_theme_font_size_override("font_size",T.font_size(fs,scale_factor,minimum));node.add_theme_color_override("font_color",color)
	var plate=T.panel(Color.TRANSPARENT,Color.TRANSPARENT if serif else Color(T.SURFACE,.97));plate.set_border_width_all(0);node.add_theme_stylebox_override("normal",plate)
	var font=T.DISPLAY if serif else T.FONT
	var actual_fs=T.font_size(fs,scale_factor,minimum)
	var needed=font.get_multiline_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-16,actual_fs).y+8
	rect.size.y=minf(rect.size.y,needed)
	_put(node,rect);node.text=text;labels.append(node);return node
func _button(id: String, title: String, rect: Rect2, callback: Callable, disabled: bool = false) -> Button:
	var b=ButtonFace.new();b.caption=title;b.view_scale=scale_factor;b.emphasis=id in ["begin","play","start_duel","start_tutorial"];b.disabled=disabled
	b.pressed.connect(func():get_node("/root/GameAudio").cue("ui");callback.call_deferred());rect.size.y=maxf(rect.size.y,ceil(44/scale_factor));_put(b,rect);actions[id]=b;return b
func _panel(rect: Rect2) -> Panel:
	var p=Panel.new();p.add_theme_stylebox_override("panel",T.panel(T.BRONZE,T.SURFACE));p.mouse_filter=Control.MOUSE_FILTER_IGNORE;_put(p,rect);return p
func _atlas(index: int) -> AtlasTexture:
	var a=AtlasTexture.new();a.atlas=preload("res://assets/art/atlas.png");var cell=a.atlas.get_size()/3;a.region=Rect2(Vector2(index%3,index/3)*cell,cell);return a
func _portrait(index: int, rect: Rect2, active: bool = false) -> Control:
	var f=Face.new();f.heroic=true;f.active=active;f.art=_atlas(index);f.view_scale=scale_factor;f.mouse_filter=Control.MOUSE_FILTER_IGNORE;_put(f,rect);return f
func _heading(title: String, subtitle: String = "") -> void:
	_label(title,Rect2(72,44,logical_width-420,100),54,T.TEXT,true,20)
	if not subtitle.is_empty():_label(subtitle,Rect2(76,154,logical_width-470,100),28,T.SECONDARY)
	_button("back","ZURÜCK",Rect2(logical_width-290,36,220,104),_go_back)
func show_page(page: String) -> void:
	get_node("/root/GameAudio").set_music("collection" if page=="collection" else "menu")
	current_page=page;screen.visible=true
	for c in screen.get_children():screen.remove_child(c);c.queue_free()
	actions.clear();labels.clear();audio_sliders.clear()
	var bg=TextureRect.new();bg.texture=preload("res://assets/art/arena_painted.png");bg.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;bg.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;bg.modulate=Color(.30,.35,.42,1);_put(bg,Rect2(0,0,logical_width,900));bg.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var mist=preload("res://scripts/atmosphere.gd").new();mist.reduced_motion=store.data.settings.reduced_motion;mist.low_effects=store.data.settings.low_effects;_put(mist,Rect2(0,0,logical_width,900))
	var theme=Theme.new();theme.default_font=T.FONT;theme.set_stylebox("panel","TooltipPanel",T.panel());screen.theme=theme
	if page=="start":_start_screen()
	elif page=="home":_home()
	elif page=="intro":_intro()
	elif page=="heroes":_heroes()
	elif page=="campaign":_campaign()
	elif page=="chapter":_chapter()
	elif page=="collection":_collection()
	elif page=="settings":_settings()
	elif page=="av":_audio_settings()
	elif page=="inspect":_inspect_card(str(get_meta("inspect_id","ash_watch")))
func _start_screen() -> void:
	var x=logical_width/2
	_panel(Rect2(x-600,160,1200,570))
	var name=_label(Brand.display_name(),Rect2(x-560,210,1120,145),80,T.TEXT,true,24);name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var subtitle=_label("Fünf Pfade. Dein nächster Zug.",Rect2(x-500,370,1000,70),34,T.SECONDARY);subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_button("begin","BEGINNEN",Rect2(x-390,490,780,115),func():show_page("home" if store.data.tutorial_completed else "intro"))
	_button("home","HAUPTMENÜ",Rect2(x-390,650,780,110),func():show_page("home"))
func _play() -> void:
	if store.data.tutorial_completed:_start_battle("quick")
	else:show_page("intro")
func _home() -> void:
	_heading(Brand.display_name(),"Lokales Kartenduell · Fortschritt auf diesem Gerät")
	actions.back.caption="ZUM START"
	var h=maxf(104,ceil(44/scale_factor));var y=250.0
	for row in [["play","SPIELEN",_play],["campaign","KAMPAGNE",func():show_page("campaign")],["collection","KARTENSAMMLUNG",func():show_page("collection")],["settings","EINSTELLUNGEN",func():show_page("settings")]]:
		_button(row[0],row[1],Rect2(76,y,590,h),row[2]);y+=h+14
	var x=logical_width*.53;var width=logical_width-x-72
	_panel(Rect2(x,250,width,590))
	_portrait(Catalog.hero(store.data.selected_hero).portrait,Rect2(x+width-240,285,200,230))
	_label("DEIN WEG",Rect2(x+32,277,width-290,65),36,T.GOLD,true,16)
	_label("Siege: %d\nKapitel freigeschaltet: %d / 5\nTutorial: %s" % [store.data.wins,store.data.unlocked_chapter,"abgeschlossen" if store.data.tutorial_completed else "noch offen"],Rect2(x+32,366,width-290,210),31,T.TEXT)
	_label("Fortschritt und Einstellungen bleiben auf diesem Gerät.\nLaufende Duelle werden nicht gespeichert.",Rect2(x+32,635,width-64,160),27,T.SECONDARY)
func _intro() -> void:
	_heading("EIN WEG DURCH ARVESS","Einführung · überspringbar")
	_panel(Rect2(76,260,logical_width-152,340))
	_label(Lore.text("world.arvess.premise")+"\n\nDu führst ein Bündnis durch fünf Pfade. Wähle Karten, sichere freie Wege und entscheide, wann du angreifst.",Rect2(110,295,logical_width-220,285),34,T.TEXT,false,14)
	_button("intro_continue","WEITER",Rect2(76,690,620,110),func():show_page("heroes"))
	_button("intro_skip","ÜBERSPRINGEN",Rect2(logical_width-710,690,620,110),func():show_page("heroes"))
func _heroes() -> void:
	_heading("WÄHLE DEINEN HELDEN","Zwei Helden · je 35 Leben · gleiches Startdeck · keine Sonderfähigkeit")
	var heroes=Catalog.heroes();var width=(logical_width-220)/2
	for i in heroes.size():
		var hero: Dictionary=heroes[i];var x=76+i*(width+68)
		_panel(Rect2(x,260,width,355));_portrait(hero.portrait,Rect2(x+18,275,210,210),store.data.selected_hero==hero.id)
		_label(hero.name,Rect2(x+250,290,width-275,90),34,T.TEXT,true,14)
		_label(hero.story_name,Rect2(x+250,405,width-275,65),27,T.SECONDARY)
		_button("hero_"+hero.id,"AUSGEWÄHLT" if store.data.selected_hero==hero.id else "AUSWÄHLEN",Rect2(x+25,490,width-50,110),func():store.choose_hero(hero.id);show_page("heroes"))
	_button("start_tutorial","TUTORIAL BEGINNEN",Rect2(logical_width/2-390,720,780,110),func():_start_battle("tutorial"))
func _campaign() -> void:
	_heading("DIE ERSTE OFFENE RECHNUNG","Fünf Begegnungen mit bestehenden Karten. Schwierigkeit verändert nur KI-Entscheidungen.")
	var width=(logical_width-200)/5
	for c in Catalog.chapters():
		var x=76+(int(c.number)-1)*width;var unlocked=int(c.number)<=int(store.data.unlocked_chapter)
		_panel(Rect2(x,285,width-14,310))
		_label("%02d" % int(c.number),Rect2(x+15,305,width-45,65),40,T.GOLD,true,16)
		_label(Lore.text(c.title_key),Rect2(x+15,395,width-45,150),30,T.TEXT,false,13)
		if store.data.tutorial_completed:
			_button("chapter_"+str(int(c.number)),"ÖFFNEN" if unlocked else "GESPERRT",Rect2(x,650,width-14,110),func():current_chapter=int(c.number);show_page("chapter"),not unlocked)
		else:_label("GESPERRT",Rect2(x+15,540,width-45,54),24,T.MUTED)
	if not store.data.tutorial_completed:_button("tutorial","ZUERST TUTORIAL ABSCHLIESSEN",Rect2(76,700,logical_width-152,110),func():show_page("intro"))
func _chapter() -> void:
	var c=Catalog.chapter(current_chapter)
	if c.is_empty():show_page("campaign");return
	_heading("%02d · %s" % [current_chapter,Lore.text(c.title_key)],c.opponent+" · "+c.opponent_type+" · KI: "+c.difficulty)
	_panel(Rect2(76,275,logical_width-152,345))
	_label(Lore.text(c.story_key),Rect2(110,310,logical_width-220,260),33,T.TEXT,false,14)
	_button("start_duel","BEGEGNUNG BEGINNEN",Rect2(76,710,logical_width-152,110),func():_start_battle("campaign",current_chapter))
func _settings() -> void:
	_heading("EINSTELLUNGEN","Anzeige und Bewegung · auf diesem Gerät gespeichert")
	_panel(Rect2(76,265,logical_width-152,430))
	_button("motion","BEWEGUNG: REDUZIERT" if store.data.settings.reduced_motion else "BEWEGUNG: NORMAL",Rect2(110,280,logical_width-220,110),func():store.set_motion(not store.data.settings.reduced_motion);show_page("settings"))
	var supports=not OS.has_feature("web") or bool(JavaScriptBridge.eval("!!document.documentElement.requestFullscreen"))
	_button("fullscreen","VOLLBILD" if supports else "VOLLBILD NICHT VERFÜGBAR",Rect2(110,425,logical_width-220,110),_fullscreen,not supports)
	_button("av_settings","AUDIO UND EFFEKTE",Rect2(110,570,logical_width-220,110),func():show_page("av"))
	if OS.has_feature("web"):_label("Vollbild auf dem iPhone: Teilen → Zum Home-Bildschirm.",Rect2(110,705,logical_width-220,65),28,T.SECONDARY)
	if not OS.has_feature("web") and not OS.has_feature("ios"):_button("quit","SPIEL VERLASSEN",Rect2(110,888-maxf(95,44/scale_factor),logical_width-220,95),func():get_node("/root/GameAudio").request_quit())
func _audio_settings() -> void:
	_heading("AUDIO UND EFFEKTE","Lautstärke je Kanal · 0 % schaltet stumm")
	var names={"Music":"MUSIK","SFX":"EFFEKTE","UI":"OBERFLÄCHE"}
	var row=0
	for bus in ["Music","SFX","UI"]:
		var y=260+row*145;row+=1
		var label=_label("%s · %d %%" % [names[bus],roundi(store.data.settings.audio[bus]*100)],Rect2(76,y,490,110),32,T.TEXT,false,14)
		var slider=preload("res://scripts/mixer_slider.gd").new();slider.min_value=0;slider.max_value=1;slider.step=.05;slider.value=store.data.settings.audio[bus];slider.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		slider.add_theme_stylebox_override("slider",T.panel(T.SECONDARY,T.SURFACE));slider.add_theme_stylebox_override("grabber_area",T.panel(T.ENERGY,T.ENERGY));slider.add_theme_stylebox_override("grabber_area_highlight",T.panel(T.FOCUS,T.FOCUS))
		_put(slider,Rect2(600,y,logical_width-680,maxf(110,ceil(44/scale_factor))));audio_sliders[bus]=slider
		slider.value_changed.connect(func(value):store.set_audio(bus,value);get_node("/root/GameAudio").apply(store.data.settings.audio);get_node("/root/GameAudio").preview(bus);label.text="%s · %d %%" % [names[bus],roundi(value*100)])
	_button("effects","EFFEKTE: SPARSAM" if store.data.settings.low_effects else "EFFEKTE: VOLL",Rect2(76,735,logical_width-152,110),func():store.set_low_effects(not store.data.settings.low_effects);show_page("av"))
func _fullscreen() -> void:
	if OS.has_feature("web"):JavaScriptBridge.eval("if(document.fullscreenElement){document.exitFullscreen()}else if(document.documentElement.requestFullscreen){document.documentElement.requestFullscreen().catch(()=>{})}")
	else:DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
func _collection() -> void:
	_heading("KARTENSAMMLUNG","7 spielbare Karten · 13 Entwürfe · durchsuche deine Sammlung")
	search_field=LineEdit.new();search_field.text=search_query;search_field.placeholder_text="Karte suchen";search_field.add_theme_font_size_override("font_size",T.font_size(28,scale_factor,13));search_field.add_theme_stylebox_override("normal",T.panel());search_field.add_theme_color_override("font_color",T.TEXT);search_field.add_theme_color_override("font_placeholder_color",T.SECONDARY);search_field.add_theme_color_override("caret_color",T.ENERGY);search_field.add_theme_color_override("selection_color",T.STONE_LIGHT);search_field.text_changed.connect(func(value):search_query=value;_render_collection());_put(search_field,Rect2(76,265,logical_width*.38, maxf(100,44/scale_factor)))
	var filter_titles=["ALLE","SCHMELZKONVENT","PFROPFKAMMERN","PEGELBUND","NAMENKOLLEG"]
	_button("filter","FRAKTION: "+filter_titles[faction_filter],Rect2(logical_width*.44,265,logical_width*.28,110),func():faction_filter=(faction_filter+1)%5;show_page("collection"))
	_button("concepts","KONZEPTE: AN" if show_concepts else "KONZEPTE: AUS",Rect2(logical_width*.75,265,logical_width*.20,110),func():show_concepts=not show_concepts;show_page("collection"))
	results_label=_label("",Rect2(76,435,logical_width-152,66),26,T.SECONDARY)
	collection_scroll=ScrollContainer.new();_put(collection_scroll,Rect2(76,535,logical_width-152,350))
	collection_grid=GridContainer.new();collection_grid.columns=maxi(2,int((logical_width-152)/250));collection_grid.add_theme_constant_override("h_separation",12);collection_grid.add_theme_constant_override("v_separation",16);collection_scroll.add_child(collection_grid)
	_render_collection()
func _render_collection() -> void:
	if not is_instance_valid(collection_grid):return
	for c in collection_grid.get_children():collection_grid.remove_child(c);c.queue_free()
	visible_card_ids.clear()
	for key in actions.keys():
		if str(key).begins_with("card_"):actions.erase(key)
	for entry in Lore.manifest().collections.cards:
		var implemented=entry.has("legacy_pool_index")
		if not implemented and not show_concepts:continue
		var name=Lore.text(entry.texts.name)
		if not search_query.strip_edges().is_empty() and not name.to_lower().contains(search_query.strip_edges().to_lower()):continue
		if faction_filter>0 and entry.faction_id!=["","crucible","graft","concord","names"][faction_filter]:continue
		visible_card_ids.append(entry.id)
		var cell=Control.new();cell.custom_minimum_size=Vector2(238,330);collection_grid.add_child(cell)
		var card: Button
		if implemented:
			card=Face.new();card.data=Cards.POOL[int(entry.legacy_pool_index)];card.art=_atlas(int(entry.legacy_pool_index));card.view_scale=scale_factor
		else:
			card=Button.new();
			for state in ["normal","hover","pressed","focus","disabled"]:card.add_theme_stylebox_override(state,T.panel(T.FOCUS if state=="focus" else T.MUTED));card.add_theme_color_override("font_color",T.TEXT)
			card.text=name+"\n\nKONZEPT\nNicht spielbar";card.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;card.add_theme_font_size_override("font_size",T.font_size(26,scale_factor,12))
		actions["card_"+entry.id]=card
		cell.add_child(card);card.position=Vector2(4,4);card.size=Vector2(230,272);card.pressed.connect(func():set_meta("inspect_id",entry.id);call_deferred("show_page","inspect"))
		var badge=Label.new();badge.text="SPIELBAR" if implemented else "ENTWURF";badge.add_theme_font_size_override("font_size",T.font_size(22,scale_factor,12));badge.add_theme_color_override("font_color",T.SUCCESS if implemented else T.WARNING);badge.position=Vector2(4,285);badge.size=Vector2(230,45);badge.mouse_filter=Control.MOUSE_FILTER_IGNORE;badge.add_theme_stylebox_override("normal",T.panel(Color.TRANSPARENT,T.SURFACE));cell.add_child(badge)
	results_label.text="%d Treffer" % visible_card_ids.size()
func _inspect_card(id: String) -> void:
	var entry=Lore.entity("cards",id)
	if entry.is_empty():show_page("collection");return
	_heading(Lore.text(entry.texts.name),"Karten-Großansicht")
	var implemented=entry.has("legacy_pool_index")
	_panel(Rect2(76,270,logical_width-152,590))
	if implemented:
		var index=int(entry.legacy_pool_index);var data: Dictionary=Cards.POOL[index];var card=Face.new();card.data=data;card.art=_atlas(index);card.view_scale=scale_factor;card.mouse_filter=Control.MOUSE_FILTER_IGNORE;_put(card,Rect2(115,300,330,480))
		_label(Catalog.faction(index)+"\nKosten: %d · Angriff: %d" % [data.cost,data.attack]+("\nLeben: %d" % data.hp if data.kind=="unit" else "\nZauber: 3 Schaden an einer gegnerischen Kreatur."),Rect2(510,315,logical_width-630,230),32,T.TEXT,false,14)
		_label("Keine Sonderfähigkeit." if data.kind=="unit" else "Kein Held als Zauberziel.",Rect2(510,560,logical_width-630,85),29,T.SECONDARY)
	else:
		var faction_name=Lore.text("factions."+str(entry.faction_id)+".name") if entry.faction_id!="independent" else "Ungebunden"
		_label("KONZEPT · NICHT SPIELBAR\nFraktion: "+faction_name+"\nNoch keine Werte, Illustration oder Fähigkeit implementiert.",Rect2(115,310,logical_width-230,320),34,T.WARNING,false,14)
	_label(Lore.text(entry.texts.flavor),Rect2(510 if implemented else 115,680,logical_width-(630 if implemented else 230),130),29,T.SECONDARY)
	_button("collection_back","ZUR SAMMLUNG",Rect2(logical_width-650,790,530,100),func():show_page("collection"))
func _go_back() -> void:
	if current_page=="battle" and is_instance_valid(battle_node):
		if battle_node.modal!=null:battle_node._close_modal()
		else:battle_node._show_menu()
		return
	if current_page=="collection" and keyboard_layout and is_instance_valid(search_field):search_field.release_focus();return
	show_page({"home":"start","inspect":"collection","chapter":"campaign","heroes":"intro","intro":"start","av":"settings"}.get(current_page,"home"))
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:_go_back();get_viewport().set_input_as_handled()

func _start_battle(mode: String, chapter_number: int = 0) -> void:
	get_node("/root/GameAudio").set_music("duel")
	var id=store.begin_run(mode,chapter_number)
	if id.is_empty():return
	run_id=id;run_mode=mode;current_chapter=chapter_number
	if OS.has_feature("web"):JavaScriptBridge.eval("delete window.nachtsiegelQA",true)
	if is_instance_valid(battle_node):remove_child(battle_node);battle_node.queue_free()
	battle_node=preload("res://scenes/arena.tscn").instantiate()
	battle_node.low_effects=store.data.settings.low_effects
	battle_node.managed_session=true
	battle_node.continuation_label="NEUES DUELL" if mode=="quick" else ("KAPITELÜBERSICHT" if mode=="campaign" and chapter_number==5 else "WEITER")
	var hero=Catalog.hero(store.data.selected_hero)
	battle_node.player_portrait_index=int(hero.portrait);battle_node.opponent_portrait_index=8 if int(hero.portrait)==7 else 7; battle_node.player_title=hero.name
	battle_node.opponent_title="Übungshüter" if mode=="tutorial" else (Catalog.chapter(chapter_number).opponent+" · Porträt-Platzhalter" if mode=="campaign" else "Rivalisierender Hüter")
	battle_node.battle_seed=int(Catalog.chapter(chapter_number).seed) if mode=="campaign" else 8802026
	battle_node.battle_profile="easy" if mode=="tutorial" else (str(Catalog.chapter(chapter_number).ai_profile) if mode=="campaign" else "standard")
	battle_node.completed.connect(_battle_completed);battle_node.main_menu_requested.connect(func():call_deferred("_leave_battle"));battle_node.retry_requested.connect(func():call_deferred("_start_battle",run_mode,current_chapter));battle_node.continue_requested.connect(func():call_deferred("_continue_campaign"));battle_node.preferences_updated.connect(func(value):store.set_motion(value))
	current_page="battle";screen.visible=false;add_child(battle_node)
	battle_node._set_reduced_motion(store.data.settings.reduced_motion,false);battle_node.onboarding_step=0 if mode=="tutorial" else 3
func _battle_completed(victory: bool, _reason: String) -> void:
	if not store.record_result(run_id,victory):
		if not store.last_error.is_empty():battle_node.result_summary=store.last_error
		return
	battle_node.result_summary=("Tutorial abgeschlossen. Kapitel 1 ist frei." if run_mode=="tutorial" else ("Kapitel geschafft. Nächste Begegnung freigeschaltet." if run_mode=="campaign" and current_chapter<5 else ("Kampagne abgeschlossen." if run_mode=="campaign" else "Sieg lokal gespeichert."))) if victory else "Du kannst erneut antreten. Kein Kapitel geht verloren."
	if not store.last_error.is_empty():battle_node.result_summary=store.last_error
func _leave_battle() -> void:
	if leaving_battle:return
	leaving_battle=true
	while is_instance_valid(battle_node) and battle_node.busy:await get_tree().process_frame
	if is_instance_valid(battle_node):remove_child(battle_node);battle_node.queue_free()
	battle_node=null;leaving_battle=false;show_page("home")
func _continue_campaign() -> void:
	if run_mode=="quick":_start_battle("quick");return
	if run_mode=="campaign" and current_chapter==5:
		_leave_battle();show_page("campaign");return
	var next=1 if run_mode=="tutorial" else mini(5,current_chapter+1)
	_leave_battle()
	if run_mode in ["tutorial","campaign"]:current_chapter=next;show_page("chapter")
func _process(delta: float) -> void:
	if not qa_enabled:return
	clock+=delta
	if clock<.1:return
	clock=0
	var result={"page":current_page,"actions":{},"tutorial_completed":store.data.tutorial_completed,"wins":store.data.wins,"unlocked_chapter":store.data.unlocked_chapter,"selected_hero":store.data.selected_hero,"visible_cards":visible_card_ids,"reduced_motion":store.data.settings.reduced_motion,"keyboard_layout":keyboard_layout,"audio":store.data.settings.audio,"low_effects":store.data.settings.low_effects,"audio_sliders":{}}
	for bus in audio_sliders:
		var r=audio_sliders[bus].get_global_rect();result.audio_sliders[bus]=[r.position.x/density,r.position.y/density,r.size.x/density,r.size.y/density]
	for id in actions:
		if not is_instance_valid(actions[id]):continue
		var r=actions[id].get_global_rect();result.actions[id]={"rect":[r.position.x/density,r.position.y/density,r.size.x/density,r.size.y/density],"disabled":actions[id].disabled}
	if current_page=="collection" and is_instance_valid(search_field):
		var r=search_field.get_global_rect();result.search_rect=[r.position.x/density,r.position.y/density,r.size.x/density,r.size.y/density]
	JavaScriptBridge.eval("window.nachtsiegelHub="+JSON.stringify(result),true)
