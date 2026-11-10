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
| Strategievorlagen | Zehn unterschiedliche, validierte 30er-Testdecks mit jeweils mindestens neun ausgetauschten Kopien Unterschied. Über „Testdecks“ in der Deckwerkstatt laden, bearbeiten und ausdrücklich speichern. |
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

Entwicklungsnachweise vor der abschließenden Integrations-CI:

| Prüfpaket | Tatsächlich beobachtetes Ergebnis |
|---|---|
| Node: Text, Vertrag, Arten, Assets, Export-Fehlerpfade | 44 Testgruppen, null Fehler, null übersprungen |
| Expliziter Effektadapter | 314 Assertions, null Fehler |
| Kartenmaster | 374 Assertions, null Fehler; 20 Material-/Machtansichten und identische Rückseiten |
| Öffnung / Touch / Drag | 852 Assertions, null Fehler; Safe-Area-Fullboard-Fixture eingeschlossen |
| Bibliothek mit aktivem Artenoverlay | 677 Assertions, null Fehler |
| Zehn Strategievorlagen | 2.031 Assertions, null Fehler; 20 vollständige KI-Partien; tatsächliche Control-/Scrollgeometrie bei 390×844, 844×390, 320×568 und 756×320 |
| Unveränderter Gesamtwrapper nach allen Runtimekorrekturen | Exitcode 0; alle fünf nativen Suiten zusammen 4.248 Assertions und alle 44 Node-Testgruppen bestanden |
| Neuer Export, Chromium und WebKit | Je 493 Assertions, null Fehler: beide Eröffnungslose, drei Kartentypen per Maus/Touch, Abbruch/ungültiges Ziel/Rotation, identisches Replay und offene Inspektion; Runtime-Commit `5597b187`, danach nur Markdownänderung bis `67f89fd4` |
| Ressourcenexperiment | 1.125 Assertions, null Fehler; 192 Matrixpartien + sieben Verifikationspartien |
| Release-Sicherheit | Acht Python-Tests, null Fehler |
| Vollständiger Legacy-Wrapper | Erneut mit Exitcode 0; reproduziert die fixierte JavaScript-Referenz und vorhandene Kernel-/KI-/Replay-Prüfungen |
| Echter Web-Export mit neuem Staging | Erfolgreich; einzelner Kandidat rund 45 MB statt sieben angesammelten Exporten; keine Test-/Toolassets im PCK |

Die Anzahl der Assertions ist kein Maß für die Anzahl fertiger Karten. Ein erster lokaler Gesamtwrapper endete nach drei erfolgreichen nativen Teilsuiten mit Shell-Exit 2, weil seine Datei während der Ausführung parallel geändert wurde. Dieser Versuch zählt nicht als erfolgreicher Gesamtlauf. Die endgültige Integrationsentscheidung verlangt die unverändert ausgeführte CI; lokale Teilnachweise allein reichen dafür nicht. Browserresultate und veröffentlichter SHA werden erst nach tatsächlicher Verifikation bestätigt.

Die erste echte neue Drag-Browserprüfung fand einen kritischen, zuvor nativ nicht sichtbaren Eingabefehler: Godot 4.6.3 Web bildet DOM-`touchcancel` und `touchend` auf denselben Release-Typ ab. Dadurch konnte ein abgebrochener Touch eine Karte ausspielen. Der neue Capture-Listener erhält einen monotonen Abbruchzähler; die Godot-UI prüft ihn synchron vor jeder Freigabe. Blur und Hintergrundwechsel brechen dieselbe Geste ab. Der Browserfall bleibt streng: ein Abbruch auf einem gültigen Ziel darf weder Zustand noch Befehlszahl ändern. Erst seine erfolgreiche Wiederholung erlaubt die Freigabe des neuen Drag-Standes.

Diese strenge Wiederholung bestand anschließend in beiden Browsern. Je Engine entstanden zehn unterschiedliche PNG-Dateien aus elf Aufnahmen. WebKit-Touch wurde ausdrücklich als synthetischer DOM-Touch und Chromium-Touch über das Browserprotokoll geprüft; kein echter Gerätetest.

Ein zusätzlicher adversarialer Test fand anschließend denselben Web-Adapterfehler im alternativen Tap-Ablauf: Karte auswählen, gültigen Pfad berühren, Touch abbrechen. Auf dem vorherigen Build stieg die Befehlszahl dabei unzulässig von sechs auf sieben. Ein zentraler Press-Binder schützt deshalb inzwischen auch normale Menüs, Ursprungswahl, Hand-/Feldkarten und Bibliothek: `button_down` merkt den Abbruchzähler, `pressed` ruft den Callback nur bei unverändertem Zähler auf. Godot kann den gehaltenen Buttonzustand dabei normal zurücksetzen. Die Browsersuite enthält nun ausdrücklich abgebrochene Menü-, Ursprungs- und ausgewählte Ziel-Taps, einschließlich unmittelbarem Abbruch ohne Haltewartezeit. Die früheren 493er-Ergebnisse werden nicht als Nachweis dieser erst danach hinzugefügten Fälle umgedeutet.

Eine weitere CI fand eine veraltete Testannahme in der Sammlung: Der feste Pfadkundiger war nach der neuen Energie-/Namenssortierung die fünfte Karte. Bei 844×390 lag sein Mittelpunkt bei y=426 außerhalb des sichtbaren Bereichs. Der unveränderte Sammlungsscroll war funktionsfähig. Der Harness wählt nun eine tatsächlich vollständig sichtbare Karte und prüft weiterhin echten Touch, Modal-/Schließenaktionen und unveränderte Deckdaten. Zwei gezielte WebKit-Profile (844×390/DPR3 sowie 844×320 mit Safe Areas) bestanden; sie ersetzen nicht die vollständige abschließende CI.

Die Release-CI trennt nun Native-/Exportprüfungen von einer Chromium-/WebKit-Matrix. Keine Suite entfällt. Beide Browser prüfen denselben vorher exportierten Kandidaten; der manuelle Release-Guard verlangt unverändert den erfolgreichen **Gesamtrun**. Ein bereits hochgeladenes Kandidat-Artefakt allein erlaubt keine Veröffentlichung.

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

PR #9 wurde nach grüner CI gemäß der ausdrücklichen aktuellen Nutzerfreigabe integriert. Der manuelle Pages-Lauf **42836632754** veröffentlichte Commit **5d37cd937d7fcc50912a565e96f3cc4aa87f506d** unter <https://jagarex-lab.github.io/nachtsiegel-app/>. Diese Basis hat inzwischen beide vollständigen öffentlichen Browserprüfungen bestanden: [Live-Nachweis](LIVE_VERIFICATION.md). Sie ist nicht automatisch der gesamte neue Masterauftrag.

Der neue Meilenstein liegt in [PR #10](https://github.com/Jagarex-lab/nachtsiegel-app/pull/10). Nur ein erfolgreich geprüfter Integrationscommit darf anschließend über den vorhandenen ausdrücklich manuell ausgelösten Releaseprozess veröffentlicht werden. Es gibt keine automatische Veröffentlichung durch diesen PR und keine Änderung von GitHub-Schutzregeln.
