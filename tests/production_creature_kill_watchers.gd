extends SceneTree
## Explicit battle-boundary fixtures. Compare real attack/effect/impulse causes;
## these are not complete games or extra production cards.
const Model=preload("res://scripts/card_system/production_model.gd")
var model
var assertions:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	assertions+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func battle(side: String,power: String,relic_id: String) -> void:
	model=Model.new()
	check(model.start_alpha(model.catalog.deck(power),model.catalog.deck(power),12345),"real legal decks initialize")
	model.ai_policy=null;model.state.stage="battle";model.state.active=side;model.state.round=11
	model.state.origins={"hero":4,"enemy":4};model.state.origin_used={"hero":true,"enemy":true}
	for owner in ["hero","enemy"]:
		var player: Dictionary=model.state[owner]
		player.phase="main";player.pendingDraw=0;player.drawDone=true;player.energy=8;player.resonance=2
		player.pendingTarget=null;player.pendingShift=null;player.lanes=[null,null,null,null,null]
		player.relic=null;player.hp=30;player.ward=0;player.block=0
	model._relic_serial+=1;model.state[side].relic={"id":relic_id,"uid":model._relic_serial}
func put(side: String,lane: int,id: String) -> Dictionary:
	var unit: Dictionary=model.make_unit(side,model.catalog.card(id),lane);unit.summoned=false
	model.state[side].lanes[lane]=unit;return unit
func run() -> void:
	for side in ["hero","enemy"]:
		for relic_id in ["of-neutral-093","of-neutral-094","of-neutral-095"]:
			for cause in ["native_attack","generic_creature","impulse"]:
				battle(side,"stillwatch" if cause=="impulse" else "houses",relic_id)
				var other: String=model._other(side)
				for lane in [1,3]:
					var victim:=put(other,lane,"oa-neutral-c02");victim.hp=1;victim.ward=0;victim["block"]=0
					if cause!="impulse":
						var source:=put(side,lane,"of-houses-009" if cause=="generic_creature" else "oa-neutral-c02");source.atk=2
				if cause=="impulse":
					model.state[side].hand=["of-stillwatch-072"]
					check(model.execute("play",[side,0,1]).ok,"real impulse command kills a selected creature")
				else:check(model.attack_phase(side),"actual native attack phase for "+cause)
				var applied:=0
				for event in model.effect_runtime.log:
					if event.status=="applied" and event.trigger=="on_kill" and event.context.get("source_card_id")==relic_id:applied+=1
				var expected:=0 if cause=="impulse" else 1
				check(applied==expected,"printed own-creature kill watcher fires once for "+side+" "+relic_id+" "+cause)
				check(model.state[side].resonance==2+expected,"creature kills gain resonance but impulse kills do not for "+side+" "+relic_id+" "+cause)
				check(model.state.error.is_empty(),"kill cause produces no engine error")
	print("PRODUCTION KILL WATCHERS: %d assertions, %d failures; 18 explicitly arranged source/side/relic boundaries" % [assertions,failures])
	quit(1 if failures else 0)
