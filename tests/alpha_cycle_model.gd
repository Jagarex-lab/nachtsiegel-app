extends "res://scripts/alpha/model.gd"
func _dispatch_effect(e: Dictionary) -> void:
	# Deliberately broken trigger used only to verify the cycle detector.
	enqueue(e)
