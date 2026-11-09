extends Node
## Central transform owner. Named callbacks avoid retained lambda/tween cycles.
var reduced_motion := false
var low_effects := false
var canvas
var tweens: Dictionary={}
var targets: Dictionary={}
var peak_tweens := 0
func setup(root: Control) -> void:
	canvas=preload("res://scripts/ritual_fx.gd").new();root.add_child(canvas);canvas.z_index=2
func configure(reduced: bool, low: bool) -> void:
	if reduced and not reduced_motion:cancel_all(true)
	reduced_motion=reduced;low_effects=low
	if is_instance_valid(canvas):canvas.reduced_motion=reduced;canvas.low_effects=low
func _cancel_id(id: int) -> void:
	if tweens.has(id):
		if tweens[id].is_valid():tweens[id].kill()
	_release(id)
func cancel(control: Control) -> void:_cancel_id(control.get_instance_id())
func _release(id: int) -> void:tweens.erase(id);targets.erase(id)
func cancel_all(snap: bool=false) -> void:
	for id in targets.keys():
		var record=targets[id];var node=record.node.get_ref()
		if snap and is_instance_valid(node):
			for property in record.values:node.set(property,record.values[property])
	for id in tweens.keys():_cancel_id(id)
func animate(control: Control, property: String, target: Variant, duration: float, delay: float=0.0) -> void:
	animate_properties(control,{property:target},duration,delay)
func animate_properties(control: Control, values: Dictionary, duration: float, delay: float=0.0) -> void:
	cancel(control)
	if reduced_motion:
		for property in values:control.set(property,values[property])
		return
	var id=control.get_instance_id();var tween=control.create_tween().set_parallel(true)
	tweens[id]=tween;targets[id]={"node":weakref(control),"values":values};peak_tweens=maxi(peak_tweens,tweens.size())
	for property in values:tween.tween_property(control,property,values[property],duration).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(_release.bind(id))
	if not control.has_meta("presenter_exit"):
		control.set_meta("presenter_exit",true);control.tree_exiting.connect(_cancel_id.bind(id),CONNECT_ONE_SHOT)
func effect(family: String, kind: String, origin: Vector2, destination: Vector2, duration: float=.55) -> void:
	canvas.emit_effect(family,kind,origin,destination,.18 if reduced_motion else duration)
func _exit_tree() -> void:cancel_all()
func strike(control: Control, forward: float) -> void:
	cancel(control)
	if reduced_motion:return
	var id=control.get_instance_id();var start=control.position;var tween=control.create_tween()
	tweens[id]=tween;targets[id]={"node":weakref(control),"values":{"position":start}};peak_tweens=maxi(peak_tweens,tweens.size())
	tween.tween_property(control,"position",start-Vector2(0,forward*.3),.06).set_trans(Tween.TRANS_SINE)
	tween.tween_property(control,"position",start+Vector2(0,forward),.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(control,"position",start,.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_release.bind(id))
	if not control.has_meta("presenter_exit"):
		control.set_meta("presenter_exit",true);control.tree_exiting.connect(_cancel_id.bind(id),CONNECT_ONE_SHOT)
