# M7 – wiederverwendbare Bibliotheksabfrage

`scripts/card_system/library_filter.gd` ist ein zustandsloses Datenmodul. Es verändert weder Karten, Decks, Speicherung noch Spielregeln. Deckbuilder und Sammlung in `scripts/alpha/shell.gd` verwenden es für die tatsächlich angezeigten Karten; bestehende Aktions-IDs bleiben erhalten. Neue Schaltflächen bieten die drei implementierten Sortierungen. Kostenoptionen werden aus den tatsächlich vorhandenen Karten erzeugt, einschließlich höherer Kosten bis 10, sobald diese real vorkommen.

```gdscript
const Library = preload("res://scripts/card_system/library_filter.gd")
var choices = Library.choice_options(catalog.all_cards())
var result = Library.select(catalog.all_cards(), {
    "power": "morph", "kind": "creature", "rarity": "common",
    "species": "plant", "cost": "2", "query": "Resonanz", "sort": "cost_asc"
})
if result.ok:
    show_cards(result.cards)
else:
    show_error(result.error)
```

Alle Filter sind optional. `all` bedeutet keine Einschränkung. Gültige Schlüssel: `power`, `kind`, `rarity`, `species`, `cost`, `query` und `sort`. Kosten können als Ganzzahl oder Auswahltext übergeben werden. Unbekannte Filter, eine vierte Hauptkartenart, unbekannte Arten, ungültige Kosten oder Sortierungen liefern `ok=false`, eine leere Ergebnisliste und einen ausdrücklichen Fehler. Unmögliche gültige Kombinationen liefern dagegen ehrlich `ok=true` mit null Treffern.

`normalized(card)` liest bestehende V1-Felder `faction`, `cost`, `description` sowie V2-Felder `power`, `energy_cost`, `text_de` und `abilities`. Die numerische V1-Effektstärke `power` wird niemals als Macht interpretiert. Der historische Legacy-`order`-Fallback bleibt lesbar, ohne Pools automatisch zusammenzuführen.

Die drei Haupttyp-IDs bleiben `creature`, `event` und `relic`, angezeigt als Wesen, Impuls und Relikt. Nur tatsächlich vorhandene, bekannte Arten in einer Wesenkarte werden gelesen. Beide Einträge einer Doppelart sind gleichwertige Mitgliedschaften; weder Namen noch Illustration führen zur automatischen Erfindung von Arten. Die unveränderte mechanische Quelldatei enthält keine Arten. `AlphaCatalog` ergänzt inzwischen das gesondert kuratierte [Artenoverlay](../../data/card_system/alpha_species.json): alle 37 Wesen besitzen eine oder zwei explizit begründete Arten. Dies ist eine neue redaktionelle Festlegung, keine angeblich schon vorhandene Lore. Die acht V2-Piloten bleiben getrennte Ansichten bestehender IDs.

Die reale Alpha-Filteransicht bietet die tatsächlich im Overlay vorkommenden Arten aus den zwölf verbindlichen Definitionen an. Beim weiterhin unveränderten Legacy-Pool ohne Arten zeigt sie einen deaktivierten Eintrag „Wesensart: noch keine zugewiesen“ samt Erklärung. Keine leeren Artoptionen werden als funktionales Feature dargestellt. Das Setzen und Zurücksetzen aller neuen Filter verändert ausschließlich die Bibliotheksansicht; Macht- und Kopienregeln des Decks bleiben bestehen. Automatische Kampf-Synergieauslöser wurden durch die Klassifikation nicht hinzugefügt.

Die Suche ignoriert Groß-/Kleinschreibung. Alle durch Leerzeichen getrennten Suchwörter müssen irgendwo im gemeinsamen Text aus Name, Fähigkeitstext, vorhandenen Effekt-IDs, Typbezeichnung und tatsächlich vorhandenen Arten vorkommen. Bei V2 werden zusätzlich die deutschen Auslöserbezeichnungen durchsucht. Die Suche `Konstrukte Schild` findet beispielsweise den im Overlay als Mensch/Konstrukt festgelegten Prismaträger. Eine Fähigkeit allein weist niemals automatisch eine Art zu.

Sortierungen: `cost_asc`, `cost_desc`, `name_asc`. Bei gleicher Energie folgen Name und stabile ID aufsteigend; exakt gleiche Ansichten derselben ID behalten ihre Eingabereihenfolge. Zurückgegebene Karten sind tiefe Kopien. `choice_options` enthält nur wirklich vorkommende Mächte, Typen, Seltenheiten, Arten und Kosten; `sort` enthält die drei implementierten Sortierungen. Die UI ergänzt bei Bedarf ihren sichtbaren Eintrag „Alle“.

Native Prüfung:

```sh
XDG_DATA_HOME="$PWD/work/xdg/data" XDG_CONFIG_HOME="$PWD/work/xdg/config" XDG_CACHE_HOME="$PWD/work/xdg/cache" \
  godot --headless --path . --script tests/master550_library_filter.gd
```

Die Tests lesen alle 55 aktiven Karten und acht echten V2-Piloten. Sie prüfen kombinierte Filter, beide gleichwertigen Arten, deutsche Fähigkeits-/Artensuche, beide Energierichtungen, stabile Gleichstände, Fehlerfälle und unveränderte Quelldaten. Ein zusätzlicher Lesecheck verwendet die bestehenden 100 Legacy-Referenzkarten. Eine tatsächliche Shell-Instanz prüft sichtbare Karten-IDs und Reihenfolge, dynamische Kostenoptionen, Sortierauswahl, ehrlichen Artenstatus, Reset und bestehende Machtbeschränkung im Deckbuilder. Diese Tests sind keine physische Mobilgeräteprüfung. Der erste versehentlich ohne beschreibbare XDG-Pfade gestartete Lauf scheiterte vor dem Skriptstart am Godot-Benutzerverzeichnis; er zählt nicht als bestandener Test.

Abschluss vor dem gesonderten Artenoverlay: **644 Assertions, 0 Fehler** sowohl mit `--headless` als auch in einem Desktop-Lauf auf Xvfb `DISPLAY=:99`/Mesa. Der native Test fand zunächst einen ungültigen GDScript-Vergleich zwischen Ganzzahl-Kostenfilter und dem Text `all`; der Vergleich wurde typgeprüft und beide vollständigen Läufe anschließend erfolgreich wiederholt. V-Sync ist in dieser virtuellen Grafiktreiberumgebung nicht umschaltbar; fehlende ALSA-Hardware führte zur bekannten Dummy-Audioausgabe. Keine echten iPhone- oder Android-Tests. Der Arten-UI-Test berücksichtigt sowohl einen Pool ohne Zuweisungen als auch tatsächlich geladene separate Artenmetadaten; ein Overlay ist damit nicht ohne entsprechenden Daten-Nachweis als vorhanden behauptet.

Nach Integration des Overlays erneut tatsächlich ausgeführt: **677 Assertions, 0 Fehler**. Zusätzlich prüfen zwei Node-Testgruppen die vollständige Zuordnung aller 37 Wesen, gültige und gleichwertige Arten, fehlende Nichtwesen-Zuordnungen, Begründungen und die unveränderten fünf Pilot-Wesenzuordnungen.
