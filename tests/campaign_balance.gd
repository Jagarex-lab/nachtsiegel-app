extends SceneTree
func _initialize() -> void:
	for c in preload("res://scripts/campaign_catalog.gd").chapters():
		var model=preload("res://scripts/battle_model.gd").new();model.start(int(c.seed),c.ai_profile)
		var win=preload("res://tests/auto_player.gd").finish(model)
		print("CHAPTER ",c.number," ",win," rounds ",model.round_number," hp ",model.player_hp," enemy ",model.foe_hp)
	quit()
