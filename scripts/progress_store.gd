extends RefCounted
## Versioned local progress, atomic replacement and last-good backup; no account/cloud claims.
var path: String
var data: Dictionary
var last_error := ""
func _init(file_path: String = "user://progress_v1.json") -> void:
	path = file_path
	data = defaults()
	load_progress()
func defaults() -> Dictionary:
	return {"schema_version":1,"tutorial_completed":false,"unlocked_chapter":0,"chapter_wins":[],"wins":0,"defeats":0,"selected_hero":"keeper","settings":{"reduced_motion":false},"run_sequence":0,"active_run":{},"recorded_runs":[]}
func _number(value: Variant) -> int:
	return int(value) if value is int or value is float else 0
func _read(file: String) -> Variant:
	if not FileAccess.file_exists(file): return null
	var parser=JSON.new()
	if parser.parse(FileAccess.get_file_as_string(file))!=OK:return null
	return parser.data
func load_progress() -> void:
	var saved = _read(path)
	# Browser IDBFS flush is asynchronous. A synchronous local mirror closes the reload gap.
	if OS.has_feature("web") and path=="user://progress_v1.json":
		var text=JavaScriptBridge.eval("(()=>{try{return localStorage.getItem('nachtsiegel.progress.v1')||''}catch(e){return ''}})()")
		if text is String and not text.is_empty():
			var parser=JSON.new()
			if parser.parse(text)==OK and parser.data is Dictionary and parser.data.get("schema_version")==1:saved=parser.data
	if not saved is Dictionary or saved.get("schema_version")!=1: saved = _read(path+".bak")
	if not saved is Dictionary or saved.get("schema_version")!=1:
		var old = ConfigFile.new()
		if old.load("user://ux.cfg")==OK: data.settings.reduced_motion=bool(old.get_value("accessibility","reduced_motion",false))
		elif OS.has_feature("web"): data.settings.reduced_motion=bool(JavaScriptBridge.eval("matchMedia('(prefers-reduced-motion: reduce)').matches"))
		return
	data = defaults()
	data.tutorial_completed = saved.get("tutorial_completed",false)==true
	data.unlocked_chapter = clampi(_number(saved.get("unlocked_chapter",1)),1,5) if data.tutorial_completed else 0
	data.selected_hero = str(saved.get("selected_hero","keeper")) if saved.get("selected_hero") in ["keeper","ash_king"] else "keeper"
	for key in ["wins","defeats","run_sequence"]: data[key] = clampi(_number(saved.get(key,0)),0,999999)
	if saved.get("settings") is Dictionary: data.settings.reduced_motion=saved.settings.get("reduced_motion",false)==true
	if saved.get("chapter_wins") is Array:
		for id in saved.chapter_wins:
			if id is int or id is float:
				var number = int(id)
				if number>=1 and number<=5 and not data.chapter_wins.has(number): data.chapter_wins.append(number)
	if saved.get("recorded_runs") is Array: data.recorded_runs=saved.recorded_runs.slice(-32)
	if saved.get("active_run") is Dictionary: data.active_run=saved.active_run.duplicate(true)
func save() -> bool:
	var writer = FileAccess.open(path+".tmp",FileAccess.WRITE)
	if writer==null: last_error="Speichern fehlgeschlagen"; return false
	writer.store_string(JSON.stringify(data,"  "));writer.flush();writer.close()
	if FileAccess.file_exists(path): DirAccess.copy_absolute(path,path+".bak")
	var result = DirAccess.rename_absolute(path+".tmp",path)
	if result!=OK: last_error="Speichern fehlgeschlagen"; return false
	if OS.has_feature("web") and path=="user://progress_v1.json":
		var quoted=JSON.stringify(JSON.stringify(data))
		var stored=JavaScriptBridge.eval("(()=>{try{localStorage.setItem('nachtsiegel.progress.v1',"+quoted+");return true}catch(e){return false}})()")
		if not bool(stored):last_error="Browser-Speicher nicht verfügbar; Fortschritt kann beim Schließen verloren gehen";return false
	last_error="";return true
func choose_hero(id: String) -> void:
	if id in ["keeper","ash_king"]: data.selected_hero=id;save()
func set_motion(reduced: bool) -> void: data.settings.reduced_motion=reduced;save()
func begin_run(mode: String, chapter: int = 0) -> String:
	if mode not in ["tutorial","quick","campaign"]: return ""
	if mode=="campaign" and (chapter<1 or chapter>data.unlocked_chapter): return ""
	data.run_sequence+=1
	var id = "local-"+str(data.run_sequence)
	data.active_run={"id":id,"mode":mode,"chapter":chapter}
	save();return id
func record_result(id: String, victory: bool) -> bool:
	if id.is_empty() or data.recorded_runs.has(id) or data.active_run.get("id","")!=id: return false
	var run: Dictionary = data.active_run
	if victory:
		data.wins+=1
		if run.mode=="tutorial": data.tutorial_completed=true;data.unlocked_chapter=maxi(data.unlocked_chapter,1)
		if run.mode=="campaign":
			var chapter = int(run.chapter)
			if not data.chapter_wins.has(chapter): data.chapter_wins.append(chapter)
			data.unlocked_chapter=maxi(data.unlocked_chapter,mini(5,chapter+1))
	else: data.defeats+=1
	data.recorded_runs.append(id);data.recorded_runs=data.recorded_runs.slice(-32);data.active_run={}
	return save()
