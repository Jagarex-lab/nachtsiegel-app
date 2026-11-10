extends RefCounted
## Alpha-only visual language. Original game data and archive UI are untouched.
const T=preload("res://scripts/ui_tokens.gd")
const POWER_COLORS={"houses":Color("d59b7f"),"stillwatch":Color("a9dfef"),"morph":Color("81d4ad"),"ninth":Color("c5b7ef"),"neutral":Color("bdc9d8")}
const SYMBOLS={"houses":"Ⅻ","stillwatch":"◇","morph":"❧","ninth":"Ⅸ","neutral":"○"}
const STYLES={"houses":"Erinnerung · Wiederherstellung","stillwatch":"Schutz · Verzögerung","morph":"Anpassung · Positionswechsel","ninth":"Kausalität · Vorhersage"}
const DIFFICULTY={"houses":"Zugänglich · 1/3","stillwatch":"Bedacht · 2/3","morph":"Flexibel · 2/3","ninth":"Anspruchsvoll · 3/3"}
const RARITIES={"common":"Gewöhnlich","rare":"Selten","epic":"Episch","legendary":"Legendär"}
const KINDS={"creature":"Wesen","event":"Impuls","relic":"Relikt"}
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
	return "%s %s\n%s · %s" % [SYMBOLS.get(card.get("faction","neutral"),"○"),power_names.get(card.faction,"Neutral") if card.has("faction") else str(card.get("order","")).to_upper(),KINDS.get(card.get("kind",""),"Wesen"),RARITIES.get(card.get("rarity","common"),"Gewöhnlich")]
const RESOURCE_HELP="Energie bezahlt Karten und Relikte. Zu Beginn deines eigenen Zuges wird sie auf 1, 2, … bis 8 erneuert; Rest verfällt am Zugende.\n\nResonanz bleibt zwischen Zügen erhalten (maximal 15). Quellen: Machtwechsel bei aufeinanderfolgenden Beschwörungen +2, Nachbarformation +1, Weben, Puls, Ernte und die auf Karten angegebenen Fähigkeiten, Reaktionen und Relikte. Impulse bilden keine Beschwörungskette.\n\nPfadwacht: 2 Resonanz für 2 Heldenschild und bis zu 1 Heilung eines eigenen Wesens. Pfadmanöver: 3 für einen freien Nachbarpfad. Rückholung: 5 für eine zufällige Karte aus der Ablage, wenn die Hand Platz hat. Diese Sonderaktionen sind je einmal pro Zug möglich. Entfesselung: benötigt 15 und verbraucht 8; passendes eigenes Wesen erforderlich. Wechsel zwischen deiner Macht und neutralen Beschwörungen erzeugen ebenfalls Resonanz. Energie und Resonanz sind nicht austauschbar.\n\nSchaden gegen einen Helden verbraucht zuerst Block, dann Schild, dann Leben. Schild bleibt bis höchstens 25 bestehen. Block verfällt zu Beginn deines nächsten eigenen Zuges. Ein freies gegenüberliegendes Feld bedeutet einen direkten Heldenangriff. Durchdringung beim Beschwören ignoriert Block und Schild; Angriffsüberlauf bleibt geschützt."
const KEYWORDS="Bereit: kann am Zugende angreifen. Neu: wartet normalerweise bis zum nächsten eigenen Zug. Eile: kann schon im Beschwörungszug angreifen. Stasis: verhindert Angriffe für ganze eigene Angriffsphasen; es gilt die längere verbleibende Dauer. Durchdringung beim Beschwören ignoriert Block und Schild. Überzähliger Angriffsschaden verbraucht dagegen Block und Schild. Ursprung: Das erste eigene Wesen dort erhält einmalig 1 Schild. Konvergenz: ab der sechsten Runde drei bereite unbestrittene Wesen erklären und bis zum nächsten eigenen Zug mit denselben Wesen halten."
const GLOSSARY={
	"beschwören":"Beschwören: Ein Wesen kommt auf einen eigenen Pfad. Beschwörungseffekte gelten auch bei Wiederkehr aus der Ablage; Ausspielen aus der Hand ist ein eigener Vorgang.",
	"ausspielen":"Ausspielen: Eine Karte aus der Hand bezahlen und einsetzen. Ein Impuls wirkt und wird abgelegt; ein Relikt bleibt im eigenen Reliktplatz.",
	"eile":"Eile: Dieses Wesen kann bereits im Beschwörungszug angreifen, sofern keine Stasis oder andere Kampfregel den Angriff verhindert.",
	"stasis":"Stasis: Das Wesen setzt die angegebene Zahl eigener Angriffsphasen aus. Die längere bestehende Dauer bleibt erhalten; Dauern werden nicht addiert.",
	"schild":"Schild: Absorbiert Schaden vor Lebensverlust. Heldenschild bleibt bis höchstens 25 bestehen und wirkt nach Block; Wesenschild schützt nur das jeweilige Wesen.",
	"block":"Block: Absorbiert Schaden vor Schild und Leben beim geschützten Helden oder Wesen. Verfällt zu Beginn des nächsten eigenen Zuges.",
	"resonanz":"Resonanz: Gespeicherte Reserve für Sonderaktionen und Entfesselungen, maximal 15. Bleibt zwischen Zügen erhalten.",
	"heile":"Heilung: Stellt Leben bis zum ursprünglichen Höchstwert wieder her und erhöht diesen Höchstwert nicht.",
	"schwächung":"Schwächung: Verringert den Angriff betroffener Wesen in ihrer nächsten Angriffsphase, mindestens auf 0. Es gilt nur der stärkste Wert; danach endet die Schwächung.",
	"ziehe":"Effektziehen: Nur vorhandene Karten bis zum Handlimit 6 ziehen. Diese Effekte lösen selbst keinen Kreislauf und keine Erschöpfung aus.",
	"zugwechsel":"Verzögerung: 2 Zugwechsel sind das Ende dieses Zuges und das Ende des folgenden gegnerischen Zuges. Getroffen wird die dann aktuelle Belegung des vorgemerkten Pfades.",
	"reliktaktivierung":"Relikt: Höchstens 1 aktiv, außerhalb der Kampfpfade. Ein neues Relikt legt das alte ab. Die Aktivierung bezahlt die auf der Karte angegebenen Energie- und Resonanzkosten und ist je eigenem Zug insgesamt nur einmal möglich; Ersetzen erneuert diese Möglichkeit nicht.",
	"durchdringung":"Durchdringung: Der Beschwörungstreffer ignoriert Block und Schild. Überzähliger Schaden beim Angreifen trifft den Helden durch dessen Block und Schild.",
	"vor schild":"Vergeltung: Der Angriff muss nach Schwächung stärker als 0 sein und das verteidigende Wesen muss überleben. Vollständige Schildabsorption verhindert den Gegenschaden nicht.",
	"nacheinander":"Echokette: Jeder Treffer wird einzeln in Reihenfolge abgewickelt. Gewöhnlicher Heldenschaden verbraucht Block, dann Schild, dann Leben; eine entschiedene Partie beendet die Kette.",
}

static func card_keywords(card: Dictionary) -> String:
	var result: Array=[]
	var content=str(card.get("description","")).to_lower()
	for term in GLOSSARY:
		if content.contains(term) or term=="durchdringung" and card.get("effect","")=="pierce":result.append(GLOSSARY[term])
	result.append("Freier Gegenpfad: Ein kampfbereites Wesen trifft am Zugende den gegnerischen Helden. Block schützt vor Schild und Leben. Details schließen, um zur Auswahl zurückzukehren.")
	return "\n\n".join(result)
