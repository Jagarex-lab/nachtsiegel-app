# ORAFOLD – geprüfter Zwischenstand des 550-Karten-Auftrags

Stand: 10.11.2026. Dies ist ein zusammenhängender Entwicklungsmeilenstein, **keine Abnahme von 550 fertigen oder ausgewogenen Karten**. Die laufende Entwicklung folgt dem [Implementierungsplan](IMPLEMENTATION_PLAN.md).

## Tatsächlicher Umfang

| Bereich | Umsetzung und Grenze |
|---|---|
| Aktiver Alpha-Pool | Weiterhin **55 eigenständige IDs**: 37 Wesen, zwölf Impulse, sechs Relikte. Keine neuen Kartenwerte oder Starterlisten in diesem Meilenstein. |
| Legacy | 100 getrennte Originalkarten und fixierte Referenz bleiben erhalten; sie werden nicht als zusätzliche Alpha-Karten gezählt. |
| Kartentexte | Alle 55 deutschen Texte aus den tatsächlichen Handlern erzeugt und validiert; insbesondere Durchdringen, Wiederkehr und verzögerte Treffer präzisiert. |
| Wesensarten | Alle 37 vorhandenen Wesen haben eine oder zwei redaktionell begründete, gleichwertige Arten in einem separaten Metadatenoverlay. Zwölf Arten sind technisch zulässig; nicht jede muss schon im kleinen Pool vorkommen. Noch keine automatischen Arten-Synergieauslöser. |
| V2-Vertrag | Drei Haupttypen, zwölf Arten, zwölf Effektkategorien und 16 Trigger-IDs beschrieben. Acht Pilotansichten bestehender IDs; **keine acht zusätzlichen Karten**. Strikte Parameter-, Namens-, Text- und Assetprüfung. |
| Effekte | Explizit aufgerufener FIFO-Adapter für 25 vorhandene Effekte und eine definierte Beschwörungsprimitive. Native Kernelabwicklung wird wiederverwendet. Automatische Ereignis-Hooks, dauerhafte Effekte und allgemeine Reaktionsfenster sind noch offen. |
| Darstellung | Gemeinsame 756×1056-Masterkontur, diagonaler Rahmen, Machtzeichen, Seltenheitstiefe und identische neutrale Rückseite. Der Vollkarten-Inspektor verwendet diesen Renderer. Kleine Kampf-/Handkarten bleiben auf schnelle Lesbarkeit optimiert. |
| Kampfstart | Mulligan, Ursprung und Zweite Möglichkeit auf dem tatsächlichen Fünf-Pfade-Spielfeld. Karten markieren, vollständig lesen und bestätigen. |
| Kartenbedienung | Maus-/Touch-Drag-and-drop zusätzlich zum Antippen; gültige Ziele, Reliktbereich, Abbruch bei ungültiger Ablage, Rotation oder veraltetem Zustand. Kein neuer Kampfregelpfad. |
| Deckbibliothek | Reale Macht-/Typ-/Kosten-/Seltenheits-/Artenfilter, Fähigkeits-/Artensuche und drei stabile Sortierungen; Quelle der Optionen sind tatsächlich vorhandene Karten. |
| Ressourcen | Drei isolierte Testmodelle, 192 Matrixpartien und sieben Wiederholungs-/Referenzpartien. Produktiv bleiben Energie 8 und Resonanz 15. |
| Illustrationen | Bestehende geteilte Konzeptbilder. Keine 550 Einzelillustrationen erzeugt. Die Pipeline lehnt fehlende oder vorgetäuschte fertige Bilddateien ab. |

Die ausführliche [Bestandsaufnahme](STATE_AUDIT.md), [Effektabgrenzung](EFFECT_FOUNDATION.md), [Inhaltsplanung](CONTENT_PLAN.md), [Ressourcenmessung](RESOURCE_EXPERIMENTS.md), [Kartenrichtlinie](CARD_STYLE_GUIDE.md) und [Bedienungsbeschreibung](OPENING_UX.md) unterscheiden bestehende Funktion von vorbereitetem Vertrag.

## Sichtbare Nachweise

Die Bilder wurden tatsächlich in Godot gerendert. Die volle Spielfeldbelegung ist ein ausdrücklich kontrolliertes Layoutfixture; sie behauptet keine zufällig so gespielte Partie. Die Materialstudie verwendet Testkarten zur Darstellung aller Seltenheiten, keine zusätzlichen kommerziellen Karten.

| Ansicht | Vorher / Referenz | Neuer Stand |
|---|---|---|
| Kampf und Öffnung | [Alpha 0.2 Kampf](../alpha02/after/battle-opening.png) | [Mulligan direkt im Spielfeld](qa/mulligan-after.png) |
| Kleine Safe Area | [Alpha 0.2 kompakt](../alpha02/after/battle-compact.png) | [Zehn Wesen und sechs Handkarten bei 756×299](qa/safe-area-full-board.png) |
| Inspektion | [Alpha 0.2 Details](../alpha02/after/inspection.png) | [Diagonale Vollkarte im Hochformat](qa/card-inspection-after.png) |
| Rahmen / Rückseite | Bisherige kompakte Kartendarstellung | [Macht-/Materialstudie](qa/card-material-study.png), [einheitliche Rückseite](qa/card-back.png) |

## Bekannte Inhalts- und Balancerisiken

* In allen drei kleinen Ressourcen-Stichproben gewann Neunte Stunde 24/24 Nichtspiegelpaarungen. Das ist eine deutliche Warnung, keine belastbare menschliche Siegrate und keine Ursache-Wirkungsanalyse.
* `oa-ninth-e01` (Umleitung) benötigt einen eigenen verzögerten Treffer. Die einzige aktuelle Quelle liegt in Stillwacht. Ein legales Neunte-Stunde-Deck kann diese Voraussetzung derzeit nicht selbst herstellen. Keine Behauptung, alle 55 Karten seien in legalen Decks vollständig nutzbar.
* Kosten neun und zehn sind unter der bestehenden gewöhnlichen Energieauffüllung nicht regulär erreichbar. Die Empfehlung Energie 10 / Resonanz 15 ist bislang ein Versuchsprofil.
* Die zwölf gerichteten Legacy-Reaktionen verlangen verschiedene nichtneutrale Ordnungen. Der aktuelle Ein-Macht-Alpha-Pool erzeugt diese Kombinationen regulär nicht. Der Kernel bleibt erhalten; ein noch fehlendes Alpha-Inhaltskonzept wird nicht als fertige Mechanik bezeichnet.
* 550 kuratierte Einträge, allgemeine Produktions-Hooks, neue Archetypdecks, darauf ausgerichtete KI und ausreichende Balanceprüfungen stehen weiterhin aus. Der Zielwert 550 in einem Validator erzeugt keine Karten.

## Reproduzieren

```bash
tools/test_legacy.sh
xvfb-run -a -s '-screen 0 1600x1200x24' tools/test_alpha.sh
xvfb-run -a -s '-screen 0 1600x1200x24' tools/test_master550.sh
tools/test_master550_resources.sh
python3 -m unittest discover -s tests/release -v
tools/build_alpha.sh
# Gegen einen lokal oder isoliert bereitgestellten Export:
GAME_URL=http://127.0.0.1:8890/ node tools/master550_browser_qa.cjs
```

Godot 4.6.3, Node 24 und passende Exportvorlagen werden verwendet. Browserprüfungen benötigen Playwright 1.65.0 und dessen Chromium-/WebKit-Laufzeiten. `work/master550/` enthält lokale Rohdaten und wird von CI als Artefakt aufbewahrt. Ein Quelltexttest ersetzt weder einen Exporttest noch die Browserprüfung des veröffentlichten Commits.

Die Testumgebung bietet keine physischen iPhone-/Android-Geräte. WebKit mit Touch-/Viewportprofil ist eine Simulation. Eine erfolgreiche Emulation wird nicht als echter Safari-Gerätetest ausgegeben.

## Integration und Veröffentlichung

PR #9 wurde nach grüner CI gemäß der ausdrücklichen aktuellen Nutzerfreigabe integriert. Der manuelle Pages-Lauf **42836632754** veröffentlichte Commit **5d37cd937d7fcc50912a565e96f3cc4aa87f506d** unter <https://jagarex-lab.github.io/nachtsiegel-app/>. Dies ist die freigegebene Alpha-0.2-Basis, nicht automatisch der gesamte neue Masterauftrag.

Der neue Meilenstein liegt in [PR #10](https://github.com/Jagarex-lab/nachtsiegel-app/pull/10). Nur ein erfolgreich geprüfter Integrationscommit darf anschließend über den vorhandenen ausdrücklich manuell ausgelösten Releaseprozess veröffentlicht werden. Es gibt keine automatische Veröffentlichung durch diesen PR und keine Änderung von GitHub-Schutzregeln.
