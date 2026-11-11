extends SceneTree
## Run with --path an empty directory against the actual embedded native pack.
const Shell=preload("res://scripts/alpha/shell.gd")
var assertions:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	assertions+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func run() -> void:
	var audio=root.get_node("GameAudio")
	check(audio.snapshot().events==52 and audio.snapshot().cached_streams==153,"actual exported52events/153effects load without source checkout")
	check(audio.snapshot().pool_size==16,"actual exported owner budget")
	check(FileAccess.file_exists("res://assets/audio/ORAFOLD-LICENSES.md"),"asset rights notice packaged")
	check(FileAccess.file_exists("res://data/audio/asset_manifest.json"),"original asset provenance packaged")
	check(audio.play_event("card.draw"),"actual exported original draw plays")
	var app=Shell.new();root.add_child(app)
	app.page="settings";app.render()
	for i in 5:await process_frame
	check(app.audio_settings.sliders.size()==5,"actual exported AlphaSettings has independent channels")
	app.confirm_menu();check(audio.snapshot().suspended,"exported actual pause calls owner")
	app.close_modal();check(not audio.snapshot().suspended,"exported actual resume calls owner")
	app.queue_free();await process_frame
	print("AUDIO NATIVE PRODUCT EXPORT: %d assertions, %d failures" % [assertions,failures])
	audio.request_quit(1 if failures else 0)
