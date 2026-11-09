extends SceneTree
func _initialize() -> void:
 var campaign=load("res://scripts/campaign_catalog.gd")
 var cards=load("res://data/card_definitions.gd")
 var model=load("res://scripts/battle_model.gd").new()
 var errors: Array=[]
 if campaign.chapters().size()!=5:errors.append("five exported chapters")
 if campaign.heroes().size()!=2:errors.append("two exported heroes")
 if cards.POOL.size()!=7:errors.append("seven existing cards")
 for chapter in campaign.chapters():
  if campaign.title(int(chapter.number)).is_empty():errors.append("localized chapter title")
  model.start(int(chapter.seed),str(chapter.ai_profile))
  if model.hand.size()!=4 or model.player_hp!=35:errors.append("existing initial rules")
 if not ResourceLoader.exists("res://scenes/front_end.tscn"):errors.append("exported entry scene")
 for error in errors:printerr("FAIL: ",error)
 print("EXPORTED EXPERIENCE: campaign, heroes, cards, narrative and entry scene; %d failures" % errors.size())
 quit(0 if errors.is_empty() else 1)
