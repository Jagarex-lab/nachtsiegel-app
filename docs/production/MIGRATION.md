# ORAFOLD – Kartenbereinigung und Migration

## Aktiver und historischer Bestand

Der Produktionskatalog ist `data/production/cards.json` und wird ausschließlich über `scripts/production/catalog.gd` gewählt. Er enthält exakt 550 Karten. Historische Pools werden nicht automatisch beigemischt.

| Bestand | Behandlung | Grund |
|---|---|---|
| 55 Alpha-Identitäten | Alle IDs und Namen bleiben im Produktionspool gültig; elf werden ausdrücklich überarbeitet | Bestehende gespeicherte Decks behalten ihre Referenzen |
| `data/alpha/cards.json` mit 55 alten Definitionen | Unverändert als historisches Regelprofil erhalten | Alpha-Regressionen und alte Replays bleiben nachvollziehbar |
| `data/legacy/cards.json` mit 100 Karten | Außerhalb des aktiven Produktionskatalogs erhalten | Fixierte JavaScript-Parität und Legacy-Tests |
| `data/card_definitions.gd` mit sieben frühen Prototypkarten | Nicht Bestandteil der Produktionssammlung | Historische Arena-Regressionen |
| `data/lore/card-concepts.json` mit 550 Konzepten | Historische Vorschläge, nicht automatisch ausführbare oder kanonische Karten | Herkunft und verworfene Entwurfsentscheidungen bleiben sichtbar |
| 495 neue Produktionskarten | Neue stabile `of-…`-IDs, Namen, Werte, Arten und kombinierte Regeln | Keine Wortpermutation der alten Vorlagen, kein automatischer Import von Lorebehauptungen |

**Physisch gelöschte Referenzdaten: keine. Entfernte aktive Alpha-IDs: keine.** Der Sicherheitsgewinn entsteht durch explizite Katalogauswahl statt unkontrolliertem Löschen. Alle 55 alten IDs werden in `data/production/migration.json` einzeln aufgeführt.

## Elf ausdrücklich überarbeitete Alpha-Identitäten

Die Originaldefinitionen verbleiben im Alpha-Archiv. Folgende Änderungen gelten ausschließlich für das Produktionsprofil. Die Zahlen sind erste Balancing-Entwürfe und keine aus großen Stichproben abgeleitete Endbalance.

| ID | Name | Änderungen |
|---|---|---|
| oa-houses-c02 | Eidärztin | atk: `2` → `1`; hp: `4` → `5` |
| oa-houses-c04 | Erinnerungsleserin | atk: `2` → `1`; hp: `4` → `5` |
| oa-houses-c07 | Die letzte Erbin | atk: `5` → `4`; hp: `8` → `7`; effect: `pulse` → `v2`; power: `3` → `0`; neue generische Fähigkeiten: Beim Beschwören: Nimm das zuletzt abgelegte eigene Wesen auf die Hand, falls Platz ist.<br>Zu deinem Zugbeginn: Heile das eigene Wesen mit dem wenigsten Leben um 2 Leben. 1× pro Zug.<br>Wenn dieses Wesen besiegt wird: Beschwöre Namenhüter auf dem ersten freien eigenen Pfad. |
| oa-stillwatch-c07 | Die unbewegte Königin | atk: `5` → `3`; effect: `pulse` → `v2`; power: `3` → `0`; neue generische Fähigkeiten: Beim Beschwören: Gewähre allen eigenen Wesen 2 Schild.<br>Beim Verteidigen: Betäube das direkt gegenüberliegende gegnerische Wesen für 1 Angriffsphase. 1× pro Zug.<br>Zu deinem Zugbeginn: Gewähre deinem Helden 2 Block bis zu deinem Zugbeginn. 1× pro Zug. |
| oa-morph-c07 | Die Vielstimmige | hp: `8` → `5`; effect: `pulse` → `v2`; power: `3` → `0`; neue generische Fähigkeiten: Dauerhaft: Dieses Wesen kann im Zug seiner Beschwörung angreifen.<br>Beim Ausspielen: Versetze dieses Wesen um einen Pfad nach rechts, falls dort Platz ist.<br>Beim Pfadwechsel: Gewähre allen eigenen Wesen der Art Pflanzen +1 Angriff. 1× pro Zug. |
| oa-ninth-c01 | Kausaljäger | atk: `1` → `2`; hp: `3` → `2` |
| oa-ninth-c06 | Möglichkeitsweber | atk: `3` → `4`; hp: `5` → `4` |
| oa-stillwatch-e02 | Konservierung | effect: `stasis` → `v2`; power: `2` → `0`; neue generische Fähigkeiten: Beim Ausspielen: Betäube das gegnerische Wesen mit dem wenigsten Leben für 1 Angriffsphase.<br>Beim Ausspielen: Gewähre dem eigenen Wesen mit dem wenigsten Leben 1 Schild. |
| oa-morph-e02 | Rascher Wandel | cost: `3` → `2` |
| oa-stillwatch-r01 | Bewahrungsuhr | effect: `relic_ward` → `v2`; power: `1` → `0`; neue generische Fähigkeiten: Aktivieren (1 Energie, 1 Resonanz): Gewähre deinem Helden 2 Schild.<br>Zu deinem Zugbeginn: Gewähre deinem Helden 1 Block bis zu deinem Zugbeginn.<br>Jede Fähigkeit 1× pro Zug. |
| oa-morph-r01 | Schwarmknoten | cost: `2` → `1` |

Die drei früher gleichen Puls-Legenden erfüllen nun verschiedene Rollen: Die letzte Erbin arbeitet mit Wiederkehr und Nachlass, die unbewegte Königin mit Schild und Kontrolle, die Vielstimmige mit Bewegung und Pflanzen. Der neunte Zeuge behält als einzige dieser vier Karten den nativen Puls. Die Titel begründen weiterhin keine bestätigte Führungsrolle in der Welt.

## Decks und Spielstände

Die vier neuen Starter stammen aus `data/production/starters.json`. Sie ersetzen die Vorlagen, nicht automatisch bereits gespeicherte individuelle Decks. Alte 30-Karten-Decks mit den 55 erhaltenen IDs bleiben nach der ursprünglichen Macht- und Kopienregel gültig. Laufende Partien und Replays benötigen zusätzlich das passende mechanische Regelprofil; eine Karten-ID allein beweist keine replayfähige Gleichheit.

Die neue Neunte-Stunde-Vorlage enthält tatsächliche Erzeuger verzögerter Ereignisse und Umleitung. Der Datencheck beweist diese Voraussetzung im Deck; erst der zugehörige Engine-Test beweist, dass Vorbereitung, Umleitung und spätere Auflösung in richtiger Reihenfolge funktionieren. Ein altes individuelles Deck ohne Erzeuger wird nicht ungefragt umgebaut.

## Herkunft und Grenzen

`data/production/authoring.json` ordnet die 495 neuen Karten den bisherigen Konzeptvorschlägen zu, soweit Typ und Macht passen. Eine fehlende Zuordnung ist eine neue Redaktion, keine behauptete historische Karte. Andere Typverteilungen wurden bewusst gewählt: Vielgestalt enthält mehr Wesen, Neunte Stunde mehr Impulse; Relikte sind wegen des einzelnen aktiven Reliktplatzes begrenzt.

Die Bereinigung entfernt keine für Tests, Archivkampagne oder Migration benötigten Referenzen. Die alte Arvess-Kampagne bleibt ein historischer Prototyp und wird nicht durch Kartendaten nachträglich zu ORAFOLD-Kanon. Verwaiste Illustrationen werden erst nach vollständiger Herkunfts- und Referenzprüfung gelöscht; dieser Schritt behauptet keine bislang ungeprüfte Löschung.

## Reproduzierbare Datenprüfungen

```sh
python3 tools/production/build_catalog.py --check
python3 tools/production/build_starters.py --check
python3 tools/production/build_test_decks.py --check
python3 tools/production/validate_catalog.py
python3 tools/production/test_catalog.py
python3 tools/production/build_docs.py --check
```

Der Python-Katalogtest umfasst 31 Testgruppen einschließlich negativer Datendefinitionen, Ziel- und Parameterfehlern, unerreichbarer Bedingungen, Textbeispielen, alten Deckreferenzen und Reproduzierbarkeit. Er zählt keine unsupported Runtime-Szenarien als bestanden.
