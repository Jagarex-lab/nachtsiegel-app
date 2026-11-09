extends RefCounted
## Three deliberately distinct layouts, all using the live arena components.
static func compose(width: float, scale: float, concept: String) -> Dictionary:
	var touch = maxf(103,ceil(44.0/scale))
	var result = {
		"title":Rect2(24,12,390,64),"menu":Rect2(width-220,10,210,touch),
		"enemy_hero":Rect2(width/2-85,6,150,145),"enemy_hp":Rect2(width/2+70,75,98,68),
		"enemy_label":Rect2(width/2+70,10,230,56),
		"player_hero":Rect2(15,662,170,206),"player_hp":Rect2(48,818,104,68),
		"player_label":Rect2(12,604,180,56),
		"round":Rect2(width-490,12,250,56),"phase":Rect2(width-490,74,250,56),
		"energy":Rect2(width-220,445,210,76),"energy_label":Rect2(width-220,523,210,56),
		"details":Rect2(width-250,594,240,touch),"end":Rect2(width-250,756-touch/2,240,touch),
		"status":Rect2(width-250,830,240,60),"info":Rect2(24,76,680,78),
		"message":Rect2(24,76,680,78),
		"hand":Rect2(220,680,width-500,220),
		"deck":Rect2(28,390,118,148),"stage":Rect2(0,0,width,900),
		"ally":[],"enemy":[],"paths":[]}
	var left = 180.0
	var right = width-180
	var enemy_y = 158.0
	var ally_y = 414.0
	if concept == "ritual":
		left = 335; right = width-290
		result.enemy_hero = Rect2(70,130,180,200)
		result.enemy_hp = Rect2(108,292,104,68)
		result.enemy_label = Rect2(40,72,250,56)
		result.player_hero = Rect2(70,401,180,200)
		result.player_hp = Rect2(108,562,104,68)
		result.player_label = Rect2(40,343,250,56)
		result.energy = Rect2(width-220,270,210,76)
		result.energy_label = Rect2(width-220,350,210,56)
		result.deck = Rect2(60,688,118,156)
	elif concept == "table":
		left = 285; right = width-145
		result.enemy_hero = Rect2(30,150,180,200)
		result.enemy_hp = Rect2(68,312,104,68)
		result.enemy_label = Rect2(18,90,230,56)
		result.player_hero = Rect2(30,414,180,200)
		result.player_hp = Rect2(68,576,104,68)
		result.player_label = Rect2(18,354,230,56)
		result.energy = Rect2(470,10,150,76)
		result.energy_label = Rect2(625,20,240,56)
		result.deck = Rect2(48,690,118,156)
	for i in 5:
		var x = lerpf(left,right,(i+.5)/5.0)
		var card_w = clampf((right-left)/5*.80,158,218)
		var enemy_x = width/2+(x-width/2)*(.86 if concept == "ritual" else .96)
		result.enemy.append(Rect2(enemy_x-card_w/2,enemy_y,card_w,196))
		result.ally.append(Rect2(x-card_w/2,ally_y,card_w,196))
		result.paths.append(Rect2(x-42,359,84,54))
	result.deck_count = Rect2(result.deck.position.x-16,result.deck.end.y+6,result.deck.size.x+32,50)
	return result
