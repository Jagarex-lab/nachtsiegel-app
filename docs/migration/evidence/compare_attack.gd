extends SceneTree
## Audit-only controlled subcases. Unsupported protection/readiness are explicitly
## omitted from the Godot projection because the current model has no such state.
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; printerr("FAIL: ",message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://docs/migration/evidence/legacy_export.json"))
	var outcomes: Array=[]
	var matches := 0
	var differences := 0
	for vector in source.vectors:
		var model=load("res://scripts/battle_model.gd").new()
		model.start(1)
		model.allies=[null,null,null,null,null];model.foes=[null,null,null,null,null]
		var player: bool=vector.side=="hero"
		var attacker: Array=model.allies if player else model.foes
		var defender: Array=model.foes if player else model.allies
		attacker[0]={"attack":int(vector.attack),"hp":4}
		if vector.target_hp!=null:defender[0]={"attack":1,"hp":int(vector.target_hp)}
		model.combat_phase(attacker,defender,player)
		var hp: int=model.foe_hp if player else model.player_hp
		var expected_match: bool=vector.mode in ["empty","occupied"]
		var same: bool=hp==int(vector.legacy_hp)
		check(same==expected_match,"known comparison "+vector.side+"/"+vector.mode)
		check(defender[0]==null,"empty/dead target "+vector.side+"/"+vector.mode)
		if same:matches+=1
		else:differences+=1
		outcomes.append({"side":vector.side,"mode":vector.mode,"legacy_hp":vector.legacy_hp,"godot_hp":hp,"same_hp":same,"unsupported_state":vector.mode if not expected_match else "none"})
	var result={"assertions":checks,"failures":failures,"matching_subcases":matches,"known_divergent_subcases":differences,"outcomes":outcomes}
	var file=FileAccess.open("res://work/migration/attack-comparison.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  ")+"\n");file.close()
	print("ATTACK AUDIT: %d assertions, %d failures; %d matching, %d known divergent subcases" % [checks,failures,matches,differences])
	root.get_node("GameAudio").request_quit(1 if failures else 0)
