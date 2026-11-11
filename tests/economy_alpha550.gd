extends SceneTree
const Facade = preload("res://scripts/economy/alpha550_economy.gd")
const Catalog = preload("res://scripts/production/catalog.gd")
const EconomyPanel = preload("res://scripts/economy/alpha550_panel.gd")
var assertions := 0
var failures := 0
var path := "user://economy_alpha550_test.json"
func check(value: bool, label: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		printerr("FAIL: " + label)
func clean(target: String) -> void:
	for suffix in ["", ".bak", ".tmp", ".corrupt"]:
		if FileAccess.file_exists(target + suffix): DirAccess.remove_absolute(target + suffix)
	if DirAccess.dir_exists_absolute(target + ".lock"): DirAccess.remove_absolute(target + ".lock")
func write_json(target: String, value: Variant) -> void:
	var file := FileAccess.open(target, FileAccess.WRITE)
	file.store_string(JSON.stringify(value))
	file.close()
func _initialize() -> void: call_deferred("run")
func run() -> void:
	clean(path)
	var catalog := Catalog.new()
	var custom := catalog.deck("houses")
	var replacement := ""
	for id in catalog.cards:
		var card: Dictionary = catalog.cards[id]
		if card.faction == "houses" and card.rarity == "epic" and id not in custom:
			replacement = id
			break
	custom[0] = replacement
	check(catalog.validate(custom).ok, "legal custom migration source")
	var source := {"version":2,"catalog_profile":"production-550-v1","decks":{"saved":{"mode":"alpha","cards":custom,"catalog_profile":"production-550-v1"}}}
	var source_bytes := JSON.stringify(source)
	var economy := Facade.new(path)
	var initialized: Dictionary = economy.configure_profile(source)
	check(initialized.ok, "migration initializes economy: " + str(initialized) + economy.manager.last_error)
	if not initialized.ok:
		quit(1)
		return
	check(JSON.stringify(source) == source_bytes, "source profile remains unchanged")
	check(economy.catalog.size() == 550, "real550 catalog")
	for id in economy.catalog:
		check(catalog.cards.has(id) and not id.begins_with("economy-fixture"), "only published real IDs")
	for faction in catalog.deck_ids():
		check(catalog.validate(catalog.deck(faction)).ok, "30card legal starter")
		check(economy.validate_owned_deck(catalog.deck(faction)).ok, "free starter fully owned")
	check(economy.validate_owned_deck(custom).ok and economy.owned_count(replacement) == 1, "saved deck protected during migration")
	check(economy.manager.state.collection[replacement].bound == 1, "migration copies bound")
	check(economy.snapshot().wallet.gold == 350 and economy.snapshot().wallet.crafting == 1200, "existing onboarding and level amounts")
	var reload := Facade.new(path)
	check(reload.configure_profile(source).ok, "repeat migration succeeds")
	check(reload.snapshot().wallet == economy.snapshot().wallet, "repeat onboarding does not mint")
	var result := {"winner":"hero","cards_played":10,"turns":8,"day":20000}
	check(economy.reward_match("match-one", result).ok, "match reward commits")
	var wallet: Dictionary = economy.snapshot().wallet
	check(economy.reward_match("match-one", result).get("replayed", false), "match replay receipt")
	check(reload.reward_match("match-one", result).get("replayed", false), "second writer stale receipt reloads")
	check(reload.snapshot().wallet == wallet, "two writers cannot duplicate payout")
	check(not economy.reward_match("match-one", {"cards_played":1,"day":20000}).ok, "same match changed payload rejected")
	check(economy.reward_campaign("campaign-outbox-one", {"reward_id":"campaign_chapter","chapter":1}).ok, "configured campaign reward")
	wallet = economy.snapshot().wallet
	check(reload.reward_campaign("other-request", {"reward_id":"campaign_chapter","chapter":1}).get("replayed", false), "campaign dedup independent request")
	check(reload.snapshot().wallet == wallet, "campaign cannot mint twice")
	check(not economy.reward_campaign("arbitrary", {"reward_id":"campaign_chapter","chapter":2,"gold":999}).ok, "arbitrary campaign amounts rejected")
	for index in range(2, 41):
		check(economy.reward_match("progress-%d" % index, {"cards_played":0,"day":20000 + int(index / 10)}).ok, "protected path match")
	for checkpoint in [10,20,30,40]: check("target_path:%d" % checkpoint in economy.manager.state.claimed_rewards, "permanent target milestone")
	check(economy.snapshot().wallet.crafting >= 2400, "existing free path yields target legendary plus two epic budget")
	var target := ""
	for id in economy.catalog:
		if economy.catalog[id].rarity == "legendary" and economy.owned_count(id) == 0:
			target = id
			break
	var before: int = economy.snapshot().wallet.crafting
	check(economy.craft(target).ok, "real target legendary craft")
	check(economy.snapshot().wallet.crafting == before - 1200 and economy.owned_count(target) == 1, "craft debits existing legendary cost")
	check(not economy.craft(target).ok, "legendary copy cap")
	before = economy.snapshot().wallet.gold
	check(economy.buy_pack().ok and economy.snapshot().wallet.gold == before - 100, "standard pack existing gold price")
	var opened: Dictionary = economy.open_pack("standard", "stable-pack-unit")
	check(opened.ok and opened.cards.size() == 5, "five real card draws")
	for entry in opened.cards: check(catalog.cards.has(entry.id), "pack IDs from real550")
	wallet = economy.snapshot().wallet
	check(economy.open_pack("standard", "stable-pack-unit").cards == opened.cards, "same pack receipt same reveal")
	check(economy.snapshot().wallet == wallet, "reveal retry no spend")
	var after_reload := Facade.new(path)
	check(after_reload.configure_profile(source).ok, "full save reload")
	check(after_reload.snapshot().last_open_result == opened.cards, "persisted reveal restored without opening")
	# Force only local test state to exercise exact dry-pack and duplicate edges.
	after_reload.manager.state.pity.standard.legendary = 19
	after_reload.manager.state.pity.standard.epic = 4
	after_reload.manager.state.boosters.standard += 1
	check(after_reload.manager.save(), "pity fixture saved")
	var forced: Dictionary = after_reload.open_pack()
	var legendary := false
	for entry in forced.cards:
		if entry.rarity == "legendary": legendary = true
	check(forced.ok and legendary, "twentieth dry pack guarantees legendary")
	check(after_reload.snapshot().pity.standard.legendary == 0, "legendary resets pity")
	var common := ""
	for id in economy.catalog:
		if economy.catalog[id].rarity == "common": common = id; break
	after_reload.manager.state.collection[common] = {"count":3,"bound":0,"locked":false}
	before = after_reload.manager.state.wallet.crafting
	var duplicates: Array = after_reload.manager.collection.add(after_reload.manager.state, common)
	check(duplicates[0].converted == 5 and after_reload.manager.state.wallet.crafting == before + 5, "fourth common converts existing essence amount")
	check(after_reload.manager.save(), "duplicate state saves")
	var saved: Dictionary = after_reload.manager.state.duplicate(true)
	after_reload.manager.store.fail_writes = true
	check(not after_reload.reward_match("failed-commit", {"day":20010}).ok, "failed save never reports reward success")
	check(after_reload.manager.state == saved, "failed save leaves balances receipts unchanged")
	after_reload.manager.store.fail_writes = false
	check(after_reload.reward_match("failed-commit", {"day":20010}).ok, "failed save retry grants once")
	# A stale manager cannot overwrite a committed wallet even with direct save.
	var stale := Facade.new(path)
	check(stale.configure_profile(source).ok, "stale writer loads")
	check(after_reload.reward_match("concurrent-writer", {"day":20010}).ok, "other writer commits")
	stale.manager.state.wallet.gold += 1
	check(not stale.manager.save(), "compare-and-save rejects stale writer")
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(path + ".lock"))
	check(not after_reload.reward_match("busy-writer", {"day":20010}).ok, "concurrent native writer lock blocks payout")
	DirAccess.remove_absolute(path + ".lock")
	check(after_reload.reward_match("busy-writer", {"day":20010}).ok, "blocked concurrent receipt retries once")
	var panel := EconomyPanel.new()
	panel.configure(after_reload)
	root.add_child(panel)
	await process_frame
	for viewport in [Vector2i(390,844), Vector2i(1440,900)]:
		root.size = viewport
		await process_frame
		panel.render()
		check(panel.actions.has("open") and panel.actions.has("craft"), "responsive panel controls")
		check(panel.actions.open.custom_minimum_size.y >= 44, "touch target")
	panel.queue_free()
	# Corruption recovery preserves bad bytes and a valid last-good backup.
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("broken-primary")
	file.close()
	var recovered := Facade.new(path)
	check(recovered.manager.ready and recovered.manager.recovered_backup, "corrupt primary recovers backup")
	check(recovered.configure_profile(source).ok, "recovered profile configures")
	check(recovered.reward_match("recovered-operation", {"day":20010}).ok, "recovery can safely commit")
	check(FileAccess.get_file_as_string(path + ".corrupt") == "broken-primary", "corrupt source quarantined")
	var preserved := FileAccess.get_file_as_string(path + ".bak")
	write_json(path, {"schema_version":999,"wallet":{"gold":999}})
	var future_bytes := FileAccess.get_file_as_string(path)
	var future := Facade.new(path)
	check(not future.configure_profile(source).ok, "future schema blocks fallback to old backup")
	check(FileAccess.get_file_as_string(path) == future_bytes and FileAccess.get_file_as_string(path + ".bak") == preserved, "future slots untouched")
	clean(path)
	var safe_primary := Facade.new(path)
	check(safe_primary.configure_profile(source).ok, "fresh valid primary for foreign backup case")
	var primary_bytes := FileAccess.get_file_as_string(path)
	write_json(path + ".bak", {"schema_version":999})
	var foreign_backup := Facade.new(path)
	check(not foreign_backup.configure_profile(source).ok and FileAccess.get_file_as_string(path) == primary_bytes, "future backup blocks rotation without touching primary")
	clean(path)
	var blocked := Facade.new(path)
	check(not blocked.configure_profile(source, false).ok and not FileAccess.file_exists(path), "blocked source profile cannot initialize balances")
	clean(path)
	print("ECONOMY ALPHA550: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures else 0)
