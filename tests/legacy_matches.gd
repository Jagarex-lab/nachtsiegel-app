extends "res://tests/legacy_engine.gd"
func run() -> void:
	var f=read("res://tests/fixtures/legacy/full_matches_v1.json")
	var transitions := 0
	for c in f.cases:
		var m=EngineModel.new()
		check(m.start_match(c.deck,int(c.seed),int(c.level)),"match start")
		same(c.initial,m.snapshot(),"full opening "+str(c.seed)+"/"+str(c.level))
		for step in c.steps:
			same(step.before,m.snapshot(),"before "+step.command)
			var result: Dictionary=m.execute(step.command,step.args)
			same(step.value,result.ok,"accepted "+step.command)
			same(step.after,m.snapshot(),"after "+step.command)
			transitions+=1
		same(c.winner,m.state.winner,"terminal winner")
		var before=m.snapshot()
		check(not m.end_turn("hero"),"terminal lock")
		same(before,m.snapshot(),"terminal immutable")
	print("LEGACY MATCHES: %d assertions, %d failures; 24 full duels, %d command transitions" % [assertions,failures,transitions])
	root.get_node("GameAudio").request_quit(1 if failures else 0)
