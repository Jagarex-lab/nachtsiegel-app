extends SceneTree
const Catalog = preload("res://scripts/legacy/catalog.gd")
const Display = preload("res://scripts/legacy/display_catalog.gd")
const Validator = preload("res://scripts/legacy/deck_validator.gd")
const Compare = preload("res://tests/legacy_fixture_compare.gd")
var assertions := 0
var failures := 0
func check(value: bool, message: String) -> void:
	assertions+=1
	if not value:failures+=1;printerr("FAIL: ",message)
func read(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))
func same(expected: Variant, actual: Variant, message: String) -> void:
	var delta: Dictionary=Compare.difference(expected,actual)
	check(delta.is_empty(),message+" "+JSON.stringify(delta))
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var catalog=Catalog.new()
	var display=Display.new()
	var validator=Validator.new()
	for file: String in ["data/legacy/cards.json","data/legacy/decks.json","data/legacy/display_de.json","tests/fixtures/legacy/cards.json","tests/fixtures/legacy/decks.json","tests/fixtures/legacy/transitions.json"]:
		var envelope=read("res://"+file)
		check(envelope.schema_version==1,"versioned data "+file)
		check(envelope.source.commit==Catalog.SOURCE_COMMIT,"pinned source "+file)
	var fixture=read("res://tests/fixtures/legacy/cards.json")
	var expected_ids: Array=[]
	var legendary := 0
	var by_order: Dictionary={}
	for card: Dictionary in fixture.cards:
		expected_ids.append(card.id)
		var actual: Dictionary=catalog.card(card.id)
		var expected: Dictionary=card.duplicate(true)
		expected.erase("name");expected.erase("desc")
		same(expected,actual,"all rule fields for "+card.id)
		for field: String in ["id","kind","cost","atk","hp","power","order","rarity","effect"]:
			same(expected[field],actual[field],card.id+"/"+field)
		check(not actual.has("name") and not actual.has("desc"),"rule identity excludes display fields")
		same({"name":card.name,"description":card.desc},display.card_text(card.id),"separate original labels")
		check(display.display_name(card.id)==card.name,"display name uses stable id")
		check(actual.kind=="creature","all legacy cards are creatures")
		if actual.rarity=="legendary":legendary+=1
		by_order[actual.order]=int(by_order.get(actual.order,0))+1
		actual.hp=999
		check(catalog.card(card.id).hp==expected.hp,"returned record cannot mutate catalog")
	same(expected_ids,catalog.ids(),"100 original ordered IDs")
	check(catalog.ids().size()==100 and legendary==4,"100 unique records and four legendaries")
	same({"ash":25,"tide":25,"thorn":25,"veil":25},by_order,"25 per original order")
	check(catalog.card("missing-id").is_empty(),"unknown ID returns no rule")
	check(not catalog.has_card("Aschenwache") and not catalog.has_card("Nebelqualle"),"no automatic name-to-ID alias")
	check(display.card_text("missing-id").is_empty() and display.display_name("missing-id")=="","unknown display ID")
	var copied=catalog.all_cards();copied[0].cost=999;copied.clear()
	check(catalog.all_cards().size()==100 and catalog.card("ash-0").cost==2,"all_cards gives deep copies")
	var ids=catalog.ids();ids.clear();check(catalog.ids().size()==100,"ids gives a copy")
	var labels=display.card_text("ash-0");labels.name="LOCAL TEST LABEL"
	check(display.display_name("ash-0")=="Glutwächter" and catalog.card("ash-0").id=="ash-0","changing display copy cannot alter rule identity")
	var decks=read("res://tests/fixtures/legacy/decks.json")
	same(["start","ash","tide","thorn","veil"],catalog.deck_ids(),"five original deck identities")
	same(decks.start,catalog.deck("start"),"START exact order")
	for preset: Dictionary in decks.presets:same(preset.cards,catalog.deck(preset.id),"preset exact order "+preset.id)
	for id: String in catalog.deck_ids():
		check(catalog.deck(id).size()==25,"deck length25 "+id)
		check(validator.validate(catalog.deck(id)).ok,"original deck validates "+id)
		var copy=catalog.deck(id);copy.clear();check(catalog.deck(id).size()==25,"deck returns copy "+id)
	check(catalog.deck("unknown").is_empty(),"unknown deck is empty")
	for item: Dictionary in decks.validation_cases:
		var before_deck: Variant=item.deck.duplicate(true) if item.deck is Array else item.deck
		var before_owned: Variant=item.owned.duplicate(true) if item.owned is Dictionary else item.owned
		var result: Dictionary=validator.validate(item.deck,item.owned)
		check(result.message==item.expected_error,item.id+" exact reference error")
		check(result.ok==str(item.expected_error).is_empty(),item.id+" accept/reject")
		same(before_deck,item.deck,item.id+" input deck immutable")
		same(before_owned,item.owned,item.id+" ownership immutable")
	for owned: Variant in [false,[],{"ash-0":-1},{"ash-0":1.5},{"ash-0":"1"},{"ash-0":true}]:
		check(validator.validate(catalog.deck("start"),owned).code=="ownership_format","invalid typed ownership rejected")
	var non_string: Array=catalog.deck("start");non_string[0]=["ash-0"]
	check(validator.validate(non_string).code=="unknown_card","no JS array property-key coercion")
	same({"hp":1,"target":{"id":"ash-0"}}, {"target":{"id":"ash-0"},"hp":1.0},"object order and JSON numeric representation")
	check(Compare.difference({"hp":null},{}).reason=="missing_or_extra_field","null is not missing")
	check(not Compare.difference([1,2],[2,1]).is_empty(),"array order is meaningful")
	check(Compare.difference(1,"1").reason=="type","number/string not coerced")
	check(Compare.difference(true,1).reason=="type","boolean/number not coerced")
	check(Compare.difference({"id":"ash-0"},{"id":"ash-1"}).path=="$/id","target identity mismatch reported")
	check(Compare.difference({"a/b~":1},{"a/b~":2}).path=="$/a~1b~0","diagnostic pointer escaping")
	check(Compare.difference(INF,INF).reason=="unsupported_number","infinite values rejected")
	check(Compare.difference(9007199254740992,9007199254740992).reason=="unsupported_number","unsafe JSON integers rejected")
	var transitions=read("res://tests/fixtures/legacy/transitions.json")
	var step_count := 0
	for scenario: Dictionary in transitions.cases:
		for step: Dictionary in scenario.steps:
			step_count+=1
			# Parsing fixtures is not implementing these transitions in Godot.
			same(step.before,JSON.parse_string(JSON.stringify(step.before)),scenario.id+" full before roundtrip")
			same(step.after,JSON.parse_string(JSON.stringify(step.after)),scenario.id+" full after roundtrip")
			same(step.events,JSON.parse_string(JSON.stringify(step.events)),scenario.id+" events roundtrip")
			if not step.accepted:same(step.before,step.after,scenario.id+" rejected command unchanged")
	var baseline: Dictionary=transitions.cases[0].steps[0].after
	var changed=baseline.duplicate(true);changed.hero.erase("hp")
	check(not Compare.difference(baseline,changed).is_empty(),"missing real snapshot HP detected")
	changed=baseline.duplicate(true);changed.hero.deck.reverse()
	check(not Compare.difference(baseline,changed).is_empty(),"changed real deck order detected")
	changed=baseline.duplicate(true);changed.hero.lanes[0].id="veil-1"
	check(not Compare.difference(baseline,changed).is_empty(),"changed real target ID detected")
	for opening: Dictionary in transitions.openings:
		same(opening.initial,JSON.parse_string(JSON.stringify(opening.initial)),"complete initial snapshot roundtrip")
		same(opening.ready,JSON.parse_string(JSON.stringify(opening.ready)),"complete ready snapshot roundtrip")
	var prototype: Array=preload("res://data/card_definitions.gd").POOL
	check(prototype.size()==7,"current seven-card pool remains separate")
	check(prototype[2].attack==1 and catalog.card("tide-12").atk==2,"same name is not automatic mapping")
	print("LEGACY FOUNDATIONS: %d assertions, %d failures; 100 cards, 5 decks, %d validation vectors, %d fixture steps inspected; no combat port" % [assertions,failures,decks.validation_cases.size(),step_count])
	root.get_node("GameAudio").request_quit(1 if failures else 0)
