extends SceneTree
const Session=preload("res://scripts/alpha/session.gd")
const Checkpoint=preload("res://scripts/premium/duel_checkpoint.gd")
var checks := 0
var failures := 0
var path := "user://premium_checkpoint_test.json"
class FailingCheckpoint:
	extends "res://scripts/premium/duel_checkpoint.gd"
	var clock := 0
	var attempts := 0
	var allow_write := false
	func _now_ms() -> int:return clock
	func _write(value: Variant) -> bool:
		attempts+=1
		if not allow_write:issue="Test-Speicherquote erreicht.";return false
		return super._write(value)
class RacingCheckpoint:
	extends "res://scripts/premium/duel_checkpoint.gd"
	var reads := 0
	var change_on_read := 0
	func _read_text() -> Variant:
		reads+=1
		if reads==change_on_read:
			var file=FileAccess.open(path,FileAccess.WRITE)
			file.store_string("{\"another_tab\":true}");file.close()
		return super._read_text()
func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures+=1;printerr("FAIL: "+label)
func cleanup() -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
func write_text(value: String) -> void:
	var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(value);file.close()
func run() -> void:
	cleanup()
	var store=Checkpoint.new(path)
	check(not store.load_checkpoint().available,"empty store")
	var s=Session.new()
	check(s.start_match("alpha",s.active_catalog().deck("houses"),44033,2,s.active_catalog().deck("ninth")),"match starts")
	check(store.capture(s,{"faction":"houses"}),"opening checkpoint stored")
	var original=Session.digest(s.model.snapshot())
	var restored=Session.new()
	check(store.restore_into(restored).ok,"opening restores")
	check(Session.digest(restored.model.snapshot())==original,"opening state exact")
	check(restored.model.rng.state==s.model.rng.state and restored.model.rng.calls==s.model.rng.calls,"opening RNG exact")
	restored.profile.last_seed=99999
	check(store.restore_into(restored).ok and restored.profile.last_seed==99999,"resume never rolls back the next-match seed counter")
	check(s.command("mulligan",[[0,2]]).ok,"mulligan legal")
	check(s.command("origin",[2]).ok,"origin legal")
	check(store.capture(s,{"faction":"houses"}),"later command checkpoint")
	var resumed=Checkpoint.new(path)
	check(resumed.load_checkpoint().available,"reload offers resume")
	check(resumed.restore_into(restored).ok,"journal verifies and restores")
	check(Session.digest(restored.model.snapshot())==Session.digest(s.model.snapshot()),"later state exact")
	check(Session.event_digest(restored.model.events)==Session.event_digest(s.model.events),"events exact")
	check(restored.model.rng.state==s.model.rng.state and restored.model.rng.calls==s.model.rng.calls,"RNG exact")
	check(Session.replay(restored.audit()).ok,"restored journal remains replayable")
	check(restored.profile.wins==s.profile.wins,"restoring does not grant wins")
	# A second tab has changed storage: do not clobber that other active duel.
	write_text("{\"another_tab\":true}")
	check(not store.clear(),"stale checkpoint cannot clear other tab")
	check(FileAccess.get_file_as_string(path)=="{\"another_tab\":true}","other tab bytes retained")
	check(store.blocked and not store.available,"stale writer offers no outdated resume")
	var broken=Checkpoint.new(path)
	check(not broken.load_checkpoint().available and broken.blocked,"corrupt data blocked")
	check(not broken.capture(s),"corrupt bytes not overwritten")
	# A supported shape but changed journal must fail verified reconstruction.
	var record={"format":Checkpoint.FORMAT,"version":1,"catalog_profile":"production-550-v1","replay":s.audit(),"ui":{}}
	record.replay.commands[0].after="0".repeat(64)
	write_text(JSON.stringify(record))
	var altered=Checkpoint.new(path);altered.load_checkpoint()
	check(not altered.restore_into(restored).ok,"altered journal rejected")
	check(altered.blocked,"invalid journal preserved and blocked")
	write_text(JSON.stringify({"format":Checkpoint.FORMAT,"version":2,"catalog_profile":"production-550-v1"}))
	var future=Checkpoint.new(path);future.load_checkpoint()
	check(future.blocked and not future.capture(s),"future format retained")
	# Do not replay stale cached documents from an already-open menu.
	cleanup()
	var stale=Checkpoint.new(path);stale.load_checkpoint();check(stale.capture(s),"create resume CAS fixture")
	var untouched=Session.new();untouched.start_match("alpha",s.active_catalog().deck("stillwatch"),7788,2,s.active_catalog().deck("houses"))
	var live_engine=untouched.model
	var live_digest=Session.digest(untouched.model.snapshot())
	var live_wins=int(untouched.profile.wins)
	write_text("{\"another_tab\":true}")
	check(not stale.restore_into(untouched).ok,"resume rejects a document changed before verification")
	check(untouched.model==live_engine and Session.digest(untouched.model.snapshot())==live_digest and int(untouched.profile.wins)==live_wins,"stale resume leaves the live session untouched")
	check(FileAccess.get_file_as_string(path)=="{\"another_tab\":true}","stale resume preserves other tab data")
	cleanup()
	var racing=RacingCheckpoint.new(path);racing.load_checkpoint();check(racing.capture(s),"create late-resume CAS fixture")
	racing.change_on_read=racing.reads+2
	check(not racing.restore_into(untouched).ok,"resume rechecks storage after potentially slow verification")
	check(untouched.model==live_engine and Session.digest(untouched.model.snapshot())==live_digest,"late conflict cannot replace a live engine")
	check(FileAccess.get_file_as_string(path)=="{\"another_tab\":true}" and racing.blocked and not racing.available,"late conflict preserves storage and disables stale resume")
	# No sleeps: deterministic clock proves that a failed browser write cannot
	# trigger a complete audit/serialization on every0.2-second UI poll.
	cleanup()
	var retry=FailingCheckpoint.new(path);retry.load_checkpoint()
	var stable_state=Session.digest(s.model.snapshot())
	var stable_events=Session.event_digest(s.model.events)
	var stable_rng=[s.model.rng.state,s.model.rng.calls]
	check(not retry.capture(s) and retry.attempts==1,"first failed write is reported")
	for repeat in 25:retry.capture(s)
	check(retry.attempts==1 and not retry.issue.is_empty(),"same-journal rapid polls preserve warning and back off")
	retry.clock=999;retry.capture(s);check(retry.attempts==1,"no premature retry")
	retry.clock=1000;retry.capture(s);check(retry.attempts==2,"bounded retry becomes available")
	retry.clock=2999;retry.capture(s);check(retry.attempts==2,"repeated failures increase delay")
	check(Session.digest(s.model.snapshot())==stable_state and Session.event_digest(s.model.events)==stable_events and [s.model.rng.state,s.model.rng.calls]==stable_rng,"failed saves never mutate state events or RNG")
	var next_action="openingDone" if s.model.state.stage=="second" else "finishDraw" if s.model.state.hero.phase=="draw" else "endTurn"
	var next_args=[] if next_action=="openingDone" else ["hero"]
	check(s.command(next_action,next_args).ok,"new legal action remains playable while storage is unavailable")
	retry.capture(s);check(retry.attempts==3,"a new command permits an immediate save attempt")
	retry.allow_write=true;retry.clock=60000
	check(retry.capture(s) and retry.attempts==4 and retry.issue.is_empty(),"storage recovery succeeds and clears the warning")
	for repeat in 25:retry.capture(s)
	check(retry.attempts==4,"successful unchanged journal remains cheap")
	cleanup()
	var clearable=Checkpoint.new(path);clearable.load_checkpoint();check(clearable.capture(s),"fresh capture")
	check(clearable.clear() and not clearable.available,"explicit normal clear")
	cleanup()
	check(load("res://scripts/alpha/shell.gd")!=null,"Shell integration parses")
	print("PREMIUM CHECKPOINT: %d assertions, %d failures" % [checks,failures])
	var audio=get_root().get_node_or_null("GameAudio")
	if audio!=null:audio.request_quit(1 if failures else 0)
	else:quit(1 if failures else 0)
