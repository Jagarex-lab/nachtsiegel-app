extends RefCounted
## Strict executable generic operations. The existing Runtime remains the only FIFO.
const OPS := {
 "deal_damage": {"category":"damage","params":{"amount":[1,10]}},
 "grant_shield": {"category":"protection","params":{"amount":[1,8]}},
 "grant_block": {"category":"protection","params":{"amount":[1,8]}},
 "heal_target": {"category":"healing","params":{"amount":[1,8]}},
 "modify_attack": {"category":"enhancement","params":{"amount":[1,4]}},
 "weaken_unit": {"category":"weakening","params":{"amount":[1,4]}},
 "move_unit": {"category":"movement","params":{"steps":[-1,1]}},
 "summon_card": {"category":"summoning","params":{"card_id":"card"}},
 "return_card": {"category":"recurrence","params":{"count":[1,1]}},
 "gain_resonance": {"category":"resources","params":{"amount":[1,4]}},
 "gain_energy": {"category":"resources","params":{"amount":[1,3]}},
 "draw_cards": {"category":"card_manipulation","params":{"count":[1,2]}},
 "discard_card": {"category":"card_manipulation","params":{"count":[1,1]}},
 "delay_damage": {"category":"time_manipulation","params":{"amount":[1,8],"turn_changes":[1,3]}},
 "stun_unit": {"category":"control","params":{"count":[1,2]}},
 "haste": {"category":"time_manipulation","params":{}}
}
const TARGETS := ["self","own_hero","enemy_hero","enemy_lane","opposite_enemy_unit","own_lowest_health","enemy_lowest_health","own_neighbors","own_all","enemy_all","own_species"]
const TRIGGERS := ["on_play","on_summon","on_attack","on_defend","on_deal_damage","on_take_damage","on_kill","on_death","on_turn_start","on_turn_end","on_lane_change","on_draw","on_discard","on_spend_resonance","on_relic_activate","on_condition"]
const SPECIES := ["human","beast","spirit","construct","plant","amalgam","morphid","paradox","revenant","elemental","devourer","mechanoid"]
static func integer(v: Variant, lo: int, hi: int) -> bool:
 return (v is int or v is float) and is_finite(float(v)) and float(v)==floor(float(v)) and v>=lo and v<=hi
static func validate(a: Variant) -> String:
 if not a is Dictionary:return "invalid_ability"
 for key in ["mode","effect","target","params","limit"]:
  if not a.has(key):return "missing_ability_field:"+key
 for key in a:
  if not key in ["mode","effect","target","params","limit","trigger","activation","condition"]:return "unknown_ability_field:"+str(key)
 if not OPS.has(a.effect):return "unknown_generic_effect"
 if not a.mode in ["triggered","reactive","passive","activated"]:return "invalid_mode"
 if not a.target in TARGETS:return "invalid_target_rule"
 if not a.limit in ["once_per_event","once_per_turn","while_on_board"]:return "invalid_limit"
 if a.mode in ["triggered","reactive"]:
  if not a.get("trigger") in TRIGGERS:return "invalid_trigger"
 elif a.has("trigger"):return "unexpected_trigger"
 if a.mode=="passive" and (a.effect!="haste" or a.target!="self" or a.limit!="while_on_board"):return "unsupported_passive"
 if a.effect=="haste" and a.mode!="passive":return "haste_is_passive"
 if a.effect in ["modify_attack","weaken_unit","move_unit","stun_unit"] and a.target in ["own_hero","enemy_hero"]:return "unit_target_required"
 if a.effect=="delay_damage" and a.target!="enemy_lane":return "delayed_lane_required"
 if a.mode in ["activated","reactive"]:
  if not a.get("activation") is Dictionary or a.activation.size()!=2:return "invalid_activation"
  if not integer(a.activation.get("energy"),0,8) or not integer(a.activation.get("resonance"),0,15):return "invalid_cost"
 elif a.has("activation"):return "unexpected_activation"
 if not a.params is Dictionary:return "invalid_params"
 var expected: Dictionary=OPS[a.effect].params
 if a.params.size()!=expected.size()+(1 if a.target=="own_species" else 0):return "invalid_params"
 for key in expected:
  var rule: Variant=expected[key]
  if rule is String:
   if not a.params.get(key) is String or a.params[key].is_empty():return "invalid_param:"+key
  elif not integer(a.params.get(key),int(rule[0]),int(rule[1])):return "invalid_param:"+key
 if a.effect=="move_unit" and not int(a.params.steps) in [-1,1]:return "invalid_param:steps"
 if a.target=="own_species" and not a.params.get("species") in SPECIES:return "unknown_species"
 if a.get("trigger")=="on_condition":
  if not a.get("condition") is Dictionary or a.condition.size()!=2:return "invalid_condition"
  if not a.condition.get("resource") in ["resonance","energy","hand","controlled_paths"] or not integer(a.condition.get("at_least"),1,15):return "invalid_condition"
 elif a.has("condition"):return "unexpected_condition"
 return ""
