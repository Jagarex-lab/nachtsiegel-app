extends "res://scripts/alpha/session.gd"
const HumanProduction = preload("res://scripts/online/authority_model.gd")
## Server sessions do not read or write account progress. AlphaSession still
## supplies the production setup and its canonical accepted-command audit.
func _init() -> void:pass
func save_profile() -> bool:return true
func start_duel(decks: Array, seed_value: int) -> bool:
	model=HumanProduction.new();mode="alpha";commands=[]
	if not model.start_alpha(decks[0],decks[1],seed_value,2):return false
	setup={"mode":"alpha","deck":decks[0].duplicate(),"enemy_deck":decks[1].duplicate(),"seed":seed_value,"difficulty":2,"convergence":true,"rules_profile":PRODUCTION_PROFILE,"catalog_sha256":model.catalog.fingerprint()}
	return true
