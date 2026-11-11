extends Control
## Developer-only, identical read-only composition fixture in three real renderers.
## No Session, RNG or battle-model mutation: this is visual evidence, not a duel test.
const Stage=preload("res://scripts/premium/arena_stage.gd")
const CardView=preload("res://scripts/alpha/card_view.gd")
const FullCard=preload("res://scripts/card_system/card_face.gd")
const Catalog=preload("res://scripts/production/catalog.gd")
const Style=preload("res://scripts/alpha/style.gd")
const ART=preload("res://scripts/production/art_resolver.gd")
const BOARD_IDS: Array[String]=["oa-ninth-c01","oa-ninth-c05","oa-ninth-c06","oa-neutral-c05","oa-neutral-c01","oa-houses-c01","oa-houses-c05","oa-houses-c06","oa-neutral-c02","oa-neutral-c03"]
const HAND_IDS: Array[String]=["oa-houses-c02","oa-houses-c07","of-houses-051","oa-neutral-c04","oa-houses-e01","oa-houses-r01"]
var catalog=Catalog.new()
var stage:Control
var mode:="spatial"
var output:=""
var frame_limit:=180
var warmup:=60
var frames:=0
var deltas:Array[float]=[]
var process_times:Array[float]=[]
var draw_calls:Array[int]=[]
var board_views:Array[Control]=[]
var hand_views:Array[Control]=[]
var inspector:Control
var _saved:=false
var _started_usec:=0
var _first_draw_ms:=-1.0
var _all_art_bound_ms:=-1.0
var fixture:Array=[]
var hud:HBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--arena-mode="):mode=argument.get_slice("=",1)
		elif argument.begins_with("--out="):output=argument.trim_prefix("--out=")
		elif argument.begins_with("--frames="):frame_limit=maxi(8,int(argument.get_slice("=",1)))
		elif argument.begins_with("--warmup="):warmup=maxi(0,int(argument.get_slice("=",1)))
	if mode not in Stage.MODES or catalog.cards.size()!=550:
		push_error("Invalid comparison mode or production catalog");get_tree().quit(1);set_process(false);return
	for card_id in BOARD_IDS+HAND_IDS:
		if not catalog.cards.has(card_id):
			push_error("Missing actual production fixture card: "+card_id);get_tree().quit(1);set_process(false);return
	for index in BOARD_IDS.size():
		var card:Dictionary=catalog.cards[BOARD_IDS[index]].duplicate(true)
		fixture.append({"side":"enemy" if index<5 else "hero","lane":index%5,"card":card,"unit":{"id":card.id,"atk":card.atk,"hp":card.hp,"ward":2 if index==6 else 0,"block":1 if index==0 else 0,"stun":0,"summoned":false}})
	_started_usec=Time.get_ticks_usec()
	_build()
	resized.connect(_layout)
	_mark_first_draw.call_deferred()

func _build() -> void:
	var back:=ColorRect.new();back.color=Color("080f18");back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);back.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(back)
	stage=Stage.new();stage.mode=mode;stage.origins={"hero":2,"enemy":2};add_child(stage);stage.configure(fixture)
	hud=HBoxContainer.new();hud.add_theme_constant_override("separation",14);hud.position=Vector2(12,5);add_child(hud)
	for caption in ["ORAFOLD", "DU 30 ♥  ·  2 ◇", "ENERGIE 6  ·  RESONANZ 8", "DEIN ZUG  ·  AKTIONEN", "KI 24 ♥"]:
		var label:=Label.new();label.text=caption;label.add_theme_font_override("font",Style.font);label.add_theme_font_size_override("font_size",12 if caption!="ORAFOLD" else 16);label.add_theme_color_override("font_color",Color("cddce1"));hud.add_child(label)
	for item in fixture:
		var view:Control
		if mode=="three_d":
			var button:=Button.new();button.text="";button.tooltip_text=str(item.card.name)
			button.add_theme_font_override("font",Style.font);button.add_theme_font_size_override("font_size",10)
			for state in ["normal","hover","pressed","focus"]:button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
			button.pressed.connect(func():_inspect(item.card));view=button
		else:
			var face=CardView.new();face.card=item.card;face.unit=item.unit;face.color=Style.color(item.card);face.lane=item.lane;face.combat_ready=true;face.origin=item.lane==2;face.owner_label="KI" if item.side=="enemy" else "DU"
			if "display_role" in face:face.display_role="board"
			face.pressed.connect(func():_inspect(item.card));view=face
		add_child(view);board_views.append(view)
	for card_id in HAND_IDS:
		var card:Dictionary=catalog.cards[card_id];var face=CardView.new();face.card=card;face.color=Style.color(card);face.library=true
		if "display_role" in face:face.display_role="hand"
		face.pressed.connect(func():_inspect(card));add_child(face);hand_views.append(face)
	var action:=Button.new();action.name="PrimaryAction";action.text="KARTE BETRACHTEN";action.tooltip_text="Entwicklervergleich: eingefrorene Darstellung, keine Spielzüge.";action.add_theme_font_override("font",Style.font);action.add_theme_font_size_override("font_size",14);add_child(action)
	action.pressed.connect(func():_inspect(catalog.cards[HAND_IDS[0]]))
	var secondary:=Label.new();secondary.name="Secondary";secondary.text="Karten antippen: Details\n1 / 2 / 3: Arena wechseln";secondary.add_theme_font_override("font",Style.font);secondary.add_theme_font_size_override("font_size",11);secondary.add_theme_color_override("font_color",Color("98aebd"));add_child(secondary)
	_layout()

func _layout() -> void:
	if not is_instance_valid(stage):return
	var hand_height:=clampf(size.y*.32,112,160)
	var area:=Rect2(Vector2(12,43),Vector2(size.x-24,maxf(112,size.y-hand_height-57)))
	stage.position=area.position;stage.size=area.size
	for index in board_views.size():
		var item:Dictionary=fixture[index]
		var slot:Rect2=stage.projected_card_rect(item.side,item.lane) if mode=="three_d" else Stage.slot_rect(item.side,item.lane,Rect2(Vector2.ZERO,area.size),mode)
		if mode=="three_d":
			# Text stays upright below the real 3D artwork; the actual projected art
			# is the hit target, not a guessed rectangular 2D table cell.
			board_views[index].position=area.position+slot.position;board_views[index].size=slot.size
		else:board_views[index].position=area.position+slot.position;board_views[index].size=slot.size
	var card_height:=hand_height-4;var card_width:=card_height*63.0/88.0
	var action_width:=190.0;var hand_width:=size.x-action_width-30
	var spacing:=minf(card_width+8,(hand_width-card_width)/5.0)
	var start:=12+maxf(0,(hand_width-(spacing*5+card_width))/2)
	for index in hand_views.size():hand_views[index].position=Vector2(start+spacing*index,size.y-hand_height+1);hand_views[index].size=Vector2(card_width,card_height)
	get_node("PrimaryAction").position=Vector2(size.x-action_width-12,size.y-56);get_node("PrimaryAction").size=Vector2(action_width,44)
	get_node("Secondary").position=Vector2(size.x-action_width-12,size.y-hand_height+14);get_node("Secondary").size=Vector2(action_width,48)

func _inspect(card: Dictionary) -> void:
	if is_instance_valid(inspector):inspector.queue_free();inspector=null;return
	inspector=ColorRect.new();inspector.color=Color(.015,.025,.045,.98);inspector.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(inspector)
	var height:=minf(size.y-16,480);var width:=height*63.0/88.0
	var face:=FullCard.new();face.card=card;face.size=Vector2(width,height);face.position=Vector2((size.x-width)*.5,8);inspector.add_child(face)
	var close:=Button.new();close.text="ZURÜCK";close.size=Vector2(110,44);close.position=Vector2(size.x-122,12);inspector.add_child(close);close.pressed.connect(func():inspector.queue_free();inspector=null)

func _unhandled_key_input(event:InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:return
	var requested={KEY_1:"flat",KEY_2:"spatial",KEY_3:"three_d"}.get(event.keycode,"")
	if requested.is_empty() or requested==mode:return
	mode=requested
	for child in get_children():remove_child(child);child.queue_free()
	board_views.clear();hand_views.clear();inspector=null;_build();frames=0;deltas.clear();process_times.clear();draw_calls.clear();_started_usec=Time.get_ticks_usec();_first_draw_ms=-1;_all_art_bound_ms=-1;_mark_first_draw.call_deferred()

func _mark_first_draw() -> void:
	await RenderingServer.frame_post_draw
	_first_draw_ms=(Time.get_ticks_usec()-_started_usec)/1000.0

func _art_reports() -> Array:
	var reports:Array=stage.art_reports() if mode=="three_d" else []
	if mode!="three_d":
		for view in board_views:reports.append(view.art_report())
	for view in hand_views:reports.append(view.art_report())
	return reports

func _process(delta:float) -> void:
	frames+=1
	if _all_art_bound_ms<0 and is_instance_valid(stage):
		var bound:=_art_reports()
		var ready:=bound.size()==16
		for report in bound:
			if report.pending or report.pixels.is_empty():ready=false
		if ready:_all_art_bound_ms=(Time.get_ticks_usec()-_started_usec)/1000.0
	if mode=="three_d" and frames<4:_layout()
	if frames>warmup:
		deltas.append(delta*1000.0);process_times.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0);draw_calls.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	if frames>=warmup+frame_limit and not output.is_empty() and not _saved:
		_saved=true;_save.call_deferred()

func _save() -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output)
	var image:=get_viewport().get_texture().get_image()
	var screenshot_error:=image.save_png(output.path_join("arena-"+mode+".png"))
	var metrics:Dictionary=stage.metrics()
	var reports:Array=_art_reports()
	metrics.visible_card_art=reports
	metrics.first_draw_since_ready_ms=_first_draw_ms
	metrics.all_visible_art_bound_since_ready_ms=_all_art_bound_ms
	metrics.framebuffer=_framebuffer_report(image)
	if mode!="three_d":
		var art_area:=0.0;var measured:=0
		for view in board_views:
			if view.has_method("layout_report"):
				var report:Dictionary=view.layout_report()
				art_area+=report.outer.get_area()*float(report.get("art_fraction",0));measured+=1
		metrics.visible_art_area_px2=art_area if measured==10 else -1;metrics.visible_art_measured_count=measured
	metrics.merge({"fixture_board_ids":BOARD_IDS,"fixture_hand_ids":HAND_IDS,"fixture_projection_sha256":JSON.stringify(fixture,"",true).sha256_text(),"viewport":[size.x,size.y],"frames":deltas.size(),"warmup_frames":warmup,"frame_wall_ms_p50":_percentile(deltas,.5),"frame_wall_ms_p95":_percentile(deltas,.95),"godot_process_ms_p50":_percentile(process_times,.5),"draw_calls_last":draw_calls[-1] if not draw_calls.is_empty() else -1,"video_memory_monitor_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"process_rss_kib_linux":_rss_kib(),"adapter":RenderingServer.get_video_adapter_name(),"driver":RenderingServer.get_current_rendering_method(),"godot":Engine.get_version_info().string,"startup_to_capture_ms":(Time.get_ticks_usec()-_started_usec)/1000.0,"gpu_timer":"unavailable: compatibility renderer exposes no per-stage GPU timestamp here","physical_device":false,"screenshot_error":screenshot_error,"art_cache":ART.stats()},true)
	var file:=FileAccess.open(output.path_join("arena-"+mode+".json"),FileAccess.WRITE);file.store_string(JSON.stringify(metrics,"\t",true));file.close()
	print("ARENA_COMPARISON "+JSON.stringify(metrics));get_tree().quit(0 if screenshot_error==OK else 1)

func _framebuffer_report(image:Image) -> Dictionary:
	var sum:=0.0;var squares:=0.0;var lit:=0;var samples:=0
	for row in 16:
		for column in 24:
			var color:=image.get_pixel(clampi(roundi((column+.5)*image.get_width()/24.0),0,image.get_width()-1),clampi(roundi((row+.5)*image.get_height()/16.0),0,image.get_height()-1))
			var luminance:=color.r*.2126+color.g*.7152+color.b*.0722
			sum+=luminance;squares+=luminance*luminance;samples+=1
			if luminance>.12:lit+=1
	return {"samples":samples,"luminance_variance":squares/samples-pow(sum/samples,2),"lit_samples":lit,"not_blank":lit>=20 and squares/samples-pow(sum/samples,2)>.001}

func _percentile(values:Array[float], fraction:float) -> float:
	if values.is_empty():return -1
	var copy:=values.duplicate();copy.sort();return copy[clampi(int(round((copy.size()-1)*fraction)),0,copy.size()-1)]

func _rss_kib() -> int:
	if not FileAccess.file_exists("/proc/self/status"):return -1
	for line in FileAccess.get_file_as_string("/proc/self/status").split("\n"):
		if line.begins_with("VmRSS:"):
			for part in line.split(" ",false):
				if part.is_valid_int():return int(part)
	return -1
