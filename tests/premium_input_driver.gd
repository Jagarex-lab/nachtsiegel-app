extends RefCounted
## Real native input for controlled UI fixtures; no callback/signal shortcut.
static func settle(tree: SceneTree) -> void:
	for frame in 6:await tree.process_frame
static func tap(tree: SceneTree, control: Control) -> void:
	var parent=control.get_parent()
	while parent!=null:
		if parent is ScrollContainer:parent.ensure_control_visible(control);await settle(tree)
		parent=parent.get_parent()
	var visible=control.get_global_rect().intersection(tree.root.get_visible_rect())
	parent=control.get_parent()
	while parent!=null:
		if parent is Control and parent.clip_contents:visible=visible.intersection(parent.get_global_rect())
		parent=parent.get_parent()
	if visible.size.x<43.9 or visible.size.y<43.9:
		push_error("Real native touch target is not visible44px: "+str(control.get_path())+" "+str(visible));tree.quit(1);return
	var point=visible.get_center()
	for pressed in [true,false]:
		var event=InputEventScreenTouch.new();event.index=0;event.position=point;event.pressed=pressed;Input.parse_input_event(event)
		await settle(tree)
