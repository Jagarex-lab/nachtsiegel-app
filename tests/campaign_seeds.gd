extends SceneTree
func _initialize() -> void:
	for c in preload("res://scripts/campaign_catalog.gd").chapters():
		for delta in 32:
			var seed_value=8802026+int(c.number)*17+delta
			var model=preload("res://scripts/battle_model.gd").new();model.start(seed_value,c.ai_profile)
			if preload("res://tests/auto_player.gd").finish(model):
				print("VALIDATED ",c.number," seed ",seed_value," rounds ",model.round_number," hp ",model.player_hp)
				break
	quit()
