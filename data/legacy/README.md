# Separater Legacy-Katalog (nicht aktiv in der Arena)

Quelle: `duel-deck` bei `34b3062c3f22c0950d9323ad9b97b17c41d1d14f`. Alle JSON-Dateien werden durch `node tools/legacy/generate.cjs` reproduziert; nicht von Hand ändern. `--check` verifiziert bytegenau ohne Schreibzugriff.

- `cards.json`: 100 Original-IDs und originale Regelfelder `id`, `kind`, `cost`, `atk`, `hp`, `power`, `order`, `rarity`, `effect`. `cost` ist Energie im Kampf, kein Preis. `runtime_enabled:false` kennzeichnet den nicht integrierten Datenstand; keine automatische Aktivierung.
- `display_de.json`: unveränderte deutsche Originalnamen/-beschreibungen, separat nach derselben ID. Namen sind keine Schlüssel für Regelzugriff. Ordens-/Deckbezeichnungen sind reine Anzeigedaten; keine neue Lore oder neue Übersetzung.
- `decks.json`: START (`start`) und vier Presets (`ash`, `tide`, `thorn`, `veil`) in Originalreihenfolge, je 25 IDs. `ash` als Deck-ID bezeichnet das gemischte Preset, kein monofarbenes Deck.

Die bisherigen sieben Godot-Karten und `tests/fixtures/legacy_card_pool.json` bleiben ein anderer, unveränderter Pool. Nebelqualle/Schattenwolf werden nicht per Namensgleichheit zugeordnet. Der zusätzliche Zauber Funkenstoß wird nicht importiert, weil der JS-Katalog ausschließlich Kreaturen enthält.

API unter `scripts/legacy/` (RefCounted, kein Autoload, keine UI-/Sammlungs-/Speicherabhängigkeit):

```gdscript
var catalog = preload("res://scripts/legacy/catalog.gd").new()
var validator = preload("res://scripts/legacy/deck_validator.gd").new()
var labels = preload("res://scripts/legacy/display_catalog.gd").new()
var card = catalog.card("ash-0") # Regelidentität und Werte, kein Anzeigename
var title = labels.display_name("ash-0") # "Glutwächter"
var deck = catalog.deck("start")
var result = validator.validate(deck) # {ok:true,code:"",message:""}
# Optionaler, explizit gelieferter Bestand; keine Kaufabfrage:
var unavailable = validator.validate(deck,{}) # not_owned
```

Alle öffentlichen Datenausgaben sind Kopien; Mutation einer zurückgegebenen Karte, Deckliste oder Textdaten ändert den Katalog nicht. Unbekannte IDs liefern `{}`/`[]`/leeren Namen und werden vom Validator abgelehnt. Vollständige importierte Werte sind unabhängig davon zugänglich, ob ein Spieler eine Karte besitzt. Der Katalog selbst vergibt keinen Besitz.

Deckvertrag: 20–25, nur bekannte String-IDs, max. 3 pro nichtlegendärer Karte / max. 1 pro legendärer. Optional `owned` als Dictionary nichtnegativer ganzzahliger Anzahlen; `null` bedeutet wie bei JS keine Besitzbeschränkung. Die Funktion ist für feste Katalogdaten rein: Sie liest/schreibt keinen Spielstand und verändert weder Deck noch Bestandsargument. Ergebnis `code` ist unabhängig von späterer UI-Lokalisierung, `message` entspricht bei gültigen Eingabetypen den alten Fehlermeldungen.

**Typgrenze:** JavaScript-Eigenschaftsschlüssel-Coercion wird nicht nachgebaut: `["ash-0"]` als einzelner Deckeintrag ist keine String-ID; `false`, Strings, negative oder gebrochene Bestandszahlen sind kein gültiger `owned`-Bestand. Solche Eingaben werden vor der Validierung abgewiesen. Für diesen ungültigen Eingabebereich wird keine JS-Parität behauptet. Reguläre JSON-Decks und Bestandsdaten sind durch 24 originale Vergleichsfälle geprüft.

Für ein späteres Free-to-play-Spiel mit optionalen In-App-Käufen bleibt die Besitzherkunft eine separate Anwendungsschicht: erspielt, frei verfügbar oder später erworben ist keine Eigenschaft der Regelkarte. Hier gibt es keine Preise, Kaufkennzeichen, Währung, Booster, Konten, Zahlungs- oder Berechtigungsdienste. Vorhandene Sammlung und lokale Fortschritte werden nicht verändert.

Kein Runtime-Regelmodus oder Exportfilter wurde umgeschaltet. Die Daten werden in Tests aus dem Projekt gelesen; Vorhandensein im produktiven Exportpaket wird nicht behauptet. Vor späterer Aktivierung sind Verpackung, Regelmodell und UI ausdrücklich zu integrieren und zu testen.
