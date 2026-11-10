extends RefCounted
## Alpha-only visual language. Original game data and archive UI are untouched.
const T=preload("res://scripts/ui_tokens.gd")
const POWER_COLORS={"houses":Color("d8b780"),"stillwatch":Color("a9dfef"),"morph":Color("81d4ad"),"ninth":Color("c5b7ef"),"neutral":Color("bdc9d8")}
const SYMBOLS={"houses":"Ⅻ","stillwatch":"◇","morph":"❧","ninth":"Ⅸ","neutral":"○"}
const STYLES={"houses":"Erinnerung · Wiederherstellung","stillwatch":"Schutz · Verzögerung","morph":"Anpassung · Positionswechsel","ninth":"Kausalität · Vorhersage"}
const DIFFICULTY={"houses":"Zugänglich · 1/3","stillwatch":"Bedacht · 2/3","morph":"Flexibel · 2/3","ninth":"Anspruchsvoll · 3/3"}
const RARITIES={"common":"Gewöhnlich","rare":"Selten","epic":"Episch","legendary":"Legendär"}
const KINDS={"creature":"Kreatur","event":"Ereignis","relic":"Relikt"}
static var power_names: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/alpha/cards.json")).powers
static var font: FontFile=make_font()
static func make_font() -> FontFile:
	var f: FontFile=T.FONT.duplicate()
	f.multichannel_signed_distance_field=true
	f.msdf_size=64
	return f
static func color(card: Dictionary) -> Color:
	if not card.has("faction"):return {"ash":T.WARNING,"tide":T.ENERGY,"thorn":T.SUCCESS,"veil":Color("c5b7ef")}.get(card.get("order",""),T.PLAYER)
	return POWER_COLORS.get(card.faction,T.PLAYER)
static func caption(card: Dictionary) -> String:
	return "%s %s\n%s · %s" % [SYMBOLS.get(card.get("faction","neutral"),"○"),power_names.get(card.faction,"Neutral") if card.has("faction") else str(card.get("order","")).to_upper(),KINDS.get(card.get("kind",""),"Kreatur"),RARITIES.get(card.get("rarity","common"),"Gewöhnlich")]
const RESOURCE_HELP="Energie bezahlt Karten und Relikte. Alpha: Zu Beginn deines eigenen Zuges wird sie auf 1, 2, … bis 8 erneuert; Rest verfällt am Zugende.\n\nResonanz bleibt zwischen Zügen erhalten (maximal 15). Quellen: Machtwechsel bei aufeinanderfolgenden Beschwörungen +2, Nachbarformation +1, Weben, Puls, Ernte und passende Reaktionen bzw. Relikte. Ereignisse bilden keine Beschwörungskette.\n\nPfadwacht: 2 Resonanz für 2 Heldenschild und bis zu 1 Heilung einer eigenen Kreatur. Pfadmanöver: 3 für einen freien Nachbarpfad. Rückholung: 5 für eine zufällige Karte aus der Ablage, wenn die Hand Platz hat. Diese Sonderaktionen sind je einmal pro Zug möglich. Entfesselung: benötigt 15 und verbraucht 8; passende eigene Kreatur erforderlich. Wechsel zwischen deiner Macht und neutralen Beschwörungen erzeugen ebenfalls Resonanz. Energie und Resonanz sind nicht austauschbar.\n\nSchild bleibt bestehen und absorbiert nach Block. Block verfällt zu Beginn deines nächsten eigenen Zuges. Ein freies gegenüberliegendes Feld bedeutet einen direkten Heldenangriff."
const KEYWORDS="Bereit: kann am Zugende angreifen. Neu: wartet normalerweise bis zum nächsten eigenen Zug. Eile: kann sofort kämpfen. Stasis: verhindert Kampfbereitschaft. Schild absorbiert Schaden; Durchdringender Ankunftsschaden umgeht Heldenschild, aber nicht Block. Ursprung: erste eigene Kreatur dort erhält einmalig 1 Schild. Konvergenz: ab der sechsten Runde drei bereite unbestrittene Kreaturen erklären und bis zum nächsten eigenen Zug mit denselben Instanzen halten."

static func card_keywords(card: Dictionary) -> String:
	var result: Array=[]
	var content=str(card.get("description","")).to_lower()
	var terms={"ankunft":"Ankunft: wird beim Beschwören ausgelöst.","eile":"Eile: kann bereits im Beschwörungszug kämpfen.","stasis":"Stasis: verhindert Kampfbereitschaft für die angegebene Dauer.","schild":"Schild: bleibt über Züge bestehen und absorbiert nach Block.","block":"Block: absorbiert zuerst und verfällt zu Beginn des nächsten eigenen Zuges.","resonanz":"Resonanz: gespeicherte Sonderaktionsreserve, maximal 15.","echo":"Echokette: einzelne geschützte Heldentreffer werden nacheinander vollständig abgewickelt."}
	for term in terms:
		if content.contains(term):result.append(terms[term])
	result.append("Freier Gegenpfad: eine kampfbereite Kreatur trifft am Zugende den gegnerischen Helden. Details schließen, um zur Auswahl zurückzukehren.")
	return "\n\n".join(result)
