extends SceneTree
## Configuration boundary tests: malformed economic inputs must fail before runtime use.
const Config = preload("res://scripts/economy/config.gd")
const Catalog = preload("res://scripts/economy/catalog_adapter.gd")
var assertions := 0
var failures := 0
var config
func check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + label)
func reject(section: String, path: Array, value: Variant, label: String) -> void:
	var candidate: Dictionary = config.data.duplicate(true)
	var parent: Dictionary = candidate[section]
	for index in range(path.size() - 1): parent = parent[path[index]]
	parent[path[-1]] = value
	check(not config.validate(candidate).is_empty(), label)
func _initialize() -> void:
	config = Config.new()
	check(config.errors.is_empty(), "valid provisional config")
	var fixture = Catalog.new()
	check(fixture.errors.is_empty(), "fixture catalog valid")
	check(fixture.cards.size() == 550, "synthetic catalog550")
	check(config.validate_catalog(fixture).is_empty(), "all configured pools resolve")
	check(fixture.catalog_id.begins_with("ORAFOLD-ECONOMY-FIXTURE"), "fixture separate namespace")
	check(fixture.starters.size() == 4, "four starter definitions")
	for power in fixture.starters:
		check(fixture.starters[power].size() == 30, "30card starter:" + power)
		check(fixture.actual_starters[power].size() == 30, "actual starter adapter:" + power)
	var alpha = Catalog.new("alpha")
	check(alpha.cards.size() == 55, "actual alpha catalog remains55")
	check(alpha.errors.has("booster_pool_missing_rarity:epic"), "Alpha missing epic blocks runtime")
	check(not config.validate_catalog(alpha).is_empty(), "Alpha cannot silently renormalize rates")
	reject("currencies", ["currencies", "gold", "initial_balance"], -1, "negative initialgold")
	reject("currencies", ["currencies", "gold", "initial_balance"], 0.5, "fractional initialgold")
	reject("currencies", ["currencies", "gold", "initial_balance"], "1", "string initialgold")
	reject("currencies", ["currencies", "gold", "initial_balance"], true, "boolean initialgold")
	reject("currencies", ["currencies", "gold", "maximum_balance"], -1, "negative maxbalance")
	reject("currencies", ["currencies", "premium"], [], "malformed premium object")
	reject("currencies", ["currencies", "premium", "enabled"], true, "premium remains disabled")
	reject("currencies", ["currencies", "premium", "purchasable"], true, "premium remains unpurchasable")
	reject("booster_pools", ["pools"], [], "pool map required")
	reject("booster_pools", ["pools", "standard", "price_gold"], -5, "negative boosterprice")
	reject("booster_pools", ["pools", "standard", "price_gold"], 0.5, "fractional boosterprice")
	reject("booster_pools", ["pools", "standard", "card_filter"], [], "invalid filter type")
	reject("booster_pools", ["pools", "standard", "card_filter"], {"catalog": "ignored"}, "unsupported catalog filter rejected")
	reject("booster_pools", ["pools", "standard", "card_filter"], {"set": 7}, "invalid filterset")
	reject("booster_pools", ["pools", "standard", "card_filter"], {"ids": ["missing", "missing"]}, "duplicate explicit poolids")
	reject("booster_rules", ["cards_per_booster"], 6, "slotcount mismatch")
	reject("booster_rules", ["slots"], [{"count": 5, "rates": {"common": 0.8, "rare": 0.2, "epic": 0.1, "legendary": 0.0}}], "rates sum aboveone")
	reject("booster_rules", ["slots"], [{"count": 5, "rates": {"common": 0.8, "rare": 0.1, "epic": 0.0, "legendary": 0.0}}], "rates sum belowone")
	reject("booster_rules", ["slots"], [{"count": 5, "rates": {"common": 0.8, "rare": 0.2, "epic": 0.0, "legendary": 0.0, "mythic": 0.0}}], "unknown rarity")
	reject("booster_rules", ["slots"], [{"count": 5, "rates": {"common": 1.1, "rare": -0.1, "epic": 0.0, "legendary": 0.0}}], "negative rate")
	reject("booster_rules", ["slots"], [{"count": 5, "rates": {"common": "1.0", "rare": 0.0, "epic": 0.0, "legendary": 0.0}}], "string rate")
	reject("booster_rules", ["slots"], [{"count": 0.5, "rates": {"common": 1.0, "rare": 0.0, "epic": 0.0, "legendary": 0.0}}], "fractional slotcount")
	reject("booster_rules", ["slots"], [null], "malformed slot")
	reject("booster_rules", ["pity", "legendary"], 0, "zero pity")
	reject("booster_rules", ["pity", "epic"], 21, "unreachable ordered pity")
	reject("booster_rules", ["duplicate_protection"], ["mythic"], "unknown protected rarity")
	reject("collection_rules", ["copy_limits", "legendary"], -1, "negative copylimit")
	reject("crafting", ["costs", "legendary"], 240, "crafting loop equalcost")
	reject("crafting", ["salvage", "epic"], 401, "profitable crafting loop")
	reject("crafting", ["costs", "rare"], 10.5, "fractional craftcost")
	reject("rewards", ["definitions", "onboarding"], {"golf": 10}, "unknown rewardfield")
	reject("rewards", ["definitions", "onboarding", "gold"], -1, "negative reward")
	reject("rewards", ["definitions", "onboarding", "gold"], "10", "string reward")
	reject("rewards", ["definitions", "onboarding", "boosters"], {"unknown": 1}, "unknown rewardpool")
	reject("rewards", ["definitions", "onboarding", "boosters"], {"standard": 1.5}, "fractional rewardboosters")
	reject("rewards", ["definitions", "onboarding", "cosmetics"], ["same", "same"], "duplicate cosmetic reward")
	reject("progression", ["xp_curve", "base"], 0, "unreachable zeroxp")
	reject("progression", ["xp_curve", "per_level"], -10, "decreasing xpcurve")
	reject("progression", ["xp_curve", "max_level"], 0, "unreachable maxlevel")
	reject("progression", ["milestones"], [{"level": 101, "reward": "challenge"}], "unreachable milestone")
	reject("progression", ["match", "daily_gold_cap"], -1, "negative dailycap")
	reject("quests", ["definitions", "daily_play", "reward"], "missing", "unknown questreward")
	reject("quests", ["definitions", "daily_play", "target"], 0, "zero questtarget")
	reject("quests", ["definitions", "daily_play", "event"], "unknown", "unknown questevent")
	reject("quests", ["definitions", "daily_play", "period"], "hourly", "unsupported questperiod")
	reject("quests", ["event_allowlist"], "match_completed", "malformed eventallowlist")
	reject("scenarios", ["catalog", "card_count"], 551, "synthetic countmismatch")
	var old_filter: Dictionary = config.data.booster_pools.pools.standard.card_filter.duplicate(true)
	config.data.booster_pools.pools.standard.card_filter = {"ids": ["missing-id"]}
	check(config.validate_catalog(fixture).has("pool_card_missing:missing-id"), "missing explicit cardID")
	config.data.booster_pools.pools.standard.card_filter = old_filter
	config.data.rewards.definitions.onboarding.cards = {"missing-id": 1}
	check(config.validate_catalog(fixture).has("reward_card_missing:missing-id"), "missing rewardcardID")
	print("ECONOMY CONFIG: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures else 0)
