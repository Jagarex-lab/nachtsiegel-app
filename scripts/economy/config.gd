extends RefCounted
## Central provisional configuration. No rates or economic amounts belong in UI code.
const FILES := ["currencies", "booster_pools", "booster_rules", "rewards", "progression", "crafting", "collection_rules", "quests", "scenarios"]
const RARITIES := ["common", "rare", "epic", "legendary"]
var data: Dictionary = {}
var errors: Array = []
var root_path: String

func _init(directory: String = "res://data/economy") -> void:
	root_path = directory
	for key in FILES:
		var path: String = directory.path_join(key + ".json")
		if not FileAccess.file_exists(path):
			errors.append("config_missing:" + key)
			continue
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary:
			errors.append("config_invalid_json:" + key)
			continue
		data[key] = parser.data
	if errors.is_empty(): errors = validate()

func validate(candidate: Dictionary = {}) -> Array:
	var source: Dictionary = data if candidate.is_empty() else candidate
	var issues: Array = []
	for key in FILES:
		if not source.get(key) is Dictionary:
			issues.append("config_section_missing:" + key)
		elif source[key].get("schema_version") != 1:
			issues.append("config_schema_invalid:" + key)
	if not issues.is_empty(): return issues
	for path in [["currencies", "currencies"], ["currencies", "currencies", "premium"], ["booster_pools", "pools"], ["booster_rules", "pity"], ["collection_rules", "copy_limits"], ["crafting", "costs"], ["crafting", "salvage"], ["rewards", "definitions"], ["progression", "xp_curve"], ["progression", "match"], ["progression", "level_reward"], ["quests", "definitions"], ["scenarios", "catalog"], ["scenarios", "catalog", "rarity_counts"]]:
		var value: Variant = source
		for key in path:
			value = value.get(key) if value is Dictionary else null
		if not value is Dictionary: issues.append("config_object_invalid:" + ".".join(path))
	if not source.quests.get("event_allowlist") is Array: issues.append("quest_event_allowlist_invalid")
	if not source.progression.get("milestones") is Array: issues.append("milestones_invalid")
	if not issues.is_empty(): return issues
	var currencies = source.currencies.get("currencies", {})
	if not currencies is Dictionary: return ["currencies_invalid"]
	for key in ["gold", "crafting", "premium"]:
		var value = currencies.get(key, {})
		if not value is Dictionary or not _natural(value.get("initial_balance")) or not _natural(value.get("maximum_balance")):
			issues.append("currency_invalid:" + key)
		elif float(value.initial_balance) > float(value.maximum_balance): issues.append("currency_initial_exceeds_max:" + key)
	if currencies.get("premium", {}).get("enabled") != false or currencies.get("premium", {}).get("purchasable") != false: issues.append("premium_must_remain_disabled")
	for key in ["energy", "resonance"]:
		if currencies.has(key): issues.append("combat_resource_is_not_currency:" + key)
	var pools = source.booster_pools.get("pools", {})
	if not pools is Dictionary or pools.is_empty(): issues.append("booster_pools_empty")
	else:
		for key in pools:
			var pool_data = pools[key]
			if not pool_data is Dictionary or not _natural(pool_data.get("price_gold")) or not pool_data.get("enabled") is bool or not pool_data.get("card_filter") is Dictionary:
				issues.append("booster_pool_invalid:" + str(key))
				continue
			var filter: Dictionary = pool_data.card_filter
			for field in filter:
				if field not in ["set", "faction", "ids", "catalog"]: issues.append("pool_filter_unknown:" + str(field))
			for field in ["set", "faction", "catalog"]:
				if filter.has(field) and (not filter[field] is String or str(filter[field]).is_empty()): issues.append("pool_filter_invalid:" + field)
			if filter.has("ids"):
				if not filter.ids is Array or filter.ids.is_empty(): issues.append("pool_ids_invalid:" + str(key))
				else:
					var seen: Dictionary = {}
					for id in filter.ids:
						if not id is String or str(id).is_empty() or seen.has(id): issues.append("pool_id_duplicate_or_invalid:" + str(key))
						seen[id] = true
	var rules = source.booster_rules
	var slots = rules.get("slots", [])
	var slot_total := 0
	if not slots is Array or slots.is_empty(): issues.append("slots_missing")
	else:
		for slot in slots:
			if not slot is Dictionary or not _positive(slot.get("count")) or not slot.get("rates") is Dictionary:
				issues.append("slot_invalid")
				continue
			slot_total += int(slot.count)
			var total := 0.0
			for rarity in RARITIES:
				var rate = slot.rates.get(rarity)
				if not _number(rate) or float(rate) < 0 or float(rate) > 1:
					issues.append("rate_invalid:" + rarity)
				else: total += float(rate)
			for rarity in slot.rates:
				if rarity not in RARITIES: issues.append("rarity_invalid:" + str(rarity))
			if absf(total - 1.0) > 0.000000001: issues.append("probabilities_must_sum_to_one")
	if not _positive(rules.get("cards_per_booster")) or slot_total != rules.get("cards_per_booster"): issues.append("cards_per_booster_mismatch")
	var pity = rules.get("pity", {})
	if not pity is Dictionary or not _positive(pity.get("epic")) or not _positive(pity.get("legendary")): issues.append("pity_invalid")
	elif pity.epic > pity.legendary: issues.append("epic_pity_above_legendary")
	if not rules.get("duplicate_protection") is Array: issues.append("duplicate_protection_invalid")
	else:
		for rarity in rules.duplicate_protection:
			if rarity not in RARITIES: issues.append("protection_rarity_invalid")
	var caps = source.collection_rules.get("copy_limits", {})
	var costs = source.crafting.get("costs", {})
	var salvage = source.crafting.get("salvage", {})
	if not caps is Dictionary or not costs is Dictionary or not salvage is Dictionary: issues.append("crafting_or_caps_invalid")
	else:
		for rarity in RARITIES:
			if not _positive(caps.get(rarity)): issues.append("copy_limit_invalid:" + rarity)
			if not _positive(costs.get(rarity)) or not _natural(salvage.get(rarity)):
				issues.append("crafting_values_invalid:" + rarity)
			elif float(costs[rarity]) <= float(salvage[rarity]): issues.append("crafting_loop:" + rarity)
	var definitions = source.rewards.get("definitions", {})
	if not definitions is Dictionary or definitions.is_empty(): issues.append("rewards_empty")
	else:
		for key in definitions:
			issues.append_array(_validate_reward(definitions[key], pools, "reward:" + str(key)))
	var curve = source.progression.get("xp_curve", {})
	if not curve is Dictionary or not _positive(curve.get("base")) or not _natural(curve.get("per_level")) or not _positive(curve.get("max_level")):
		issues.append("unreachable_progression_curve")
	var match_data = source.progression.get("match", {})
	if not match_data is Dictionary: issues.append("match_reward_invalid")
	else:
		for key in ["gold", "xp", "daily_gold_cap"]:
			if not _natural(match_data.get(key)): issues.append("match_reward_invalid:" + key)
	var level_reward = source.progression.get("level_reward", {})
	if not level_reward is Dictionary or not _natural(level_reward.get("gold")): issues.append("level_reward_invalid")
	if not definitions.has(source.progression.get("onboarding_reward", "")): issues.append("onboarding_reward_missing")
	var previous_milestone := 0
	for milestone in source.progression.milestones:
		if not milestone is Dictionary or not _positive(milestone.get("level")) or not definitions.has(milestone.get("reward", "")):
			issues.append("milestone_invalid")
		elif milestone.level <= previous_milestone or milestone.level > curve.get("max_level", 0): issues.append("milestone_unreachable_or_duplicate")
		else: previous_milestone = int(milestone.level)
	var quests = source.quests.get("definitions", {})
	if not quests is Dictionary: issues.append("quests_invalid")
	else:
		for key in quests:
			var quest = quests[key]
			if not quest is Dictionary or quest.get("period") not in ["daily", "weekly"] or not _positive(quest.get("target")) or not definitions.has(quest.get("reward", "")) or quest.get("event") not in source.quests.get("event_allowlist", []):
				issues.append("quest_invalid:" + str(key))
	var counts = source.scenarios.get("catalog", {}).get("rarity_counts", {})
	if not counts is Dictionary: issues.append("simulation_catalog_invalid")
	else:
		var total := 0
		for rarity in RARITIES:
			if not _positive(counts.get(rarity)): issues.append("simulation_rarity_missing:" + rarity)
			else: total += int(counts[rarity])
		if total != source.scenarios.get("catalog", {}).get("card_count"): issues.append("simulation_catalog_count_mismatch")
	return issues

func validate_catalog(catalog: Object) -> Array:
	var issues: Array = catalog.errors.duplicate()
	for pool_id in data.booster_pools.pools:
		var definition: Dictionary = data.booster_pools.pools[pool_id]
		if not definition.enabled: continue
		if definition.card_filter.has("ids"):
			for id in definition.card_filter.ids:
				if not catalog.cards.has(id): issues.append("pool_card_missing:" + str(id))
		var ids: Array = catalog.pool(definition.card_filter)
		if ids.is_empty(): issues.append("booster_pool_empty:" + pool_id)
		for rarity in RARITIES:
			var found := false
			for id in ids:
				if not catalog.cards.has(id): issues.append("pool_card_missing:" + str(id))
				elif catalog.cards[id].get("rarity") == rarity: found = true
			if not found: issues.append("booster_pool_rarity_missing:" + pool_id + ":" + rarity)
	for reward_id in data.rewards.definitions:
		for id in data.rewards.definitions[reward_id].get("cards", {}):
			if not catalog.cards.has(id): issues.append("reward_card_missing:" + str(id))
	return issues

func _validate_reward(reward: Variant, pools: Dictionary, label: String) -> Array:
	var issues: Array = []
	if not reward is Dictionary: return [label + ":invalid"]
	for key in reward:
		if key not in ["gold", "xp", "crafting", "boosters", "cards", "cosmetics", "unlocks"]: issues.append(label + ":unknown_field:" + str(key))
	for key in ["gold", "xp", "crafting"]:
		if not _natural(reward.get(key, 0)): issues.append(label + ":invalid_amount:" + key)
	for key in ["boosters", "cards"]:
		var entries = reward.get(key, {})
		if not entries is Dictionary:
			issues.append(label + ":invalid_entries:" + key)
			continue
		for id in entries:
			if not id is String or not _positive(entries[id]): issues.append(label + ":invalid_item:" + str(id))
			if key == "boosters" and not pools.has(id): issues.append(label + ":unknown_pool:" + str(id))
	for key in ["cosmetics", "unlocks"]:
		var entries = reward.get(key, [])
		if not entries is Array: issues.append(label + ":invalid_list:" + key)
		else:
			var seen: Dictionary = {}
			for id in entries:
				if not id is String or str(id).is_empty() or seen.has(id): issues.append(label + ":duplicate_or_invalid:" + key)
				seen[id] = true
	return issues

func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func _natural(value: Variant) -> bool:
	return _number(value) and float(value) >= 0 and float(value) == floorf(float(value)) and float(value) <= 1000000000

func _positive(value: Variant) -> bool:
	return _natural(value) and float(value) > 0
