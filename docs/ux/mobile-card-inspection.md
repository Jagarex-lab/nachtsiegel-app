# Mobile Karteninspektion – PR 1

## Umfang und Freigabestatus

Basis ist develop `81ec5701d1600f2e80738a2dd0b3a05a9f9973a0`.
Dieser PR korrigiert Karteninspektion, Eingabeabsicherung und die Zuordnung
der separaten Schlüsselworthilfe. Die Arena-/Handanordnung und die
Fractal-Fold-Vergleichsstudie sind getrennte Arbeitspakete.

**Arbeitsstand:** Implementierung vorhanden. Endgültige native, Browser- und
vollständige CI-Nachweise werden nach tatsächlicher Ausführung im PR ergänzt.
Dieser Quellstand ist keine Behauptung eines bereits veröffentlichten Builds.
Die bestehende automatische Alpha-Pipeline bleibt unverändert.

## Tatsächlich geänderte Bedienung

- Ein einzelner Tap auf eine Handkarte öffnet ihre echte vergrößerte Karte,
  auch während Mulligan und Zweiter Möglichkeit. Der Tap verändert keine
  Spielregelzustände, Kartenmarkierungen, Kosten, Ereignisse oder RNG-Aufrufe.
- Die ausdrückliche Aktion **Zum Ausspielen wählen** schließt die Inspektion
  und wählt die Karte aus. Erst ein weiterer gültiger Ziel-Tap spielt sie.
  Unbezahlbare Karten bleiben lesbar; die ursprüngliche Modellvalidierung
  verhindert weiterhin illegales Ausspielen.
- Beim notwendigen Verbrennen nach übergroßer Hand wählt **Zum Ablegen wählen**
  lediglich die Karte aus. Die bestehende Hauptaktion bestätigt das Ablegen.
- Im Mulligan markiert beziehungsweise entmarkiert erst **Zum Tausch markieren /
  Behalten** die Karte. Die vorhandene Starthand-Bestätigung führt anschließend
  den ursprünglichen Mulligan-Befehl aus.
- Bei Zweiter Möglichkeit wählt die ausdrückliche Aktion nur die Karte.
  Die bisherige Tausch-Bestätigung bleibt notwendig.
- Ziehen auf gültige Ziele bleibt als zusätzliche Eingabemethode erhalten.
  Bestehende Abbruch-, Mehrfinger-, Rotations-, Epoch- und Modellidentitäts-
  Prüfungen bleiben aktiv. Ein abgebrochener Drag öffnet keinen Inspector.
- Ein Tap außerhalb, die sichtbare Schließen-Schaltfläche oder Escape schließt
  die Ansicht. Die Außeneingabe wird konsumiert und verzögert abgeschlossen;
  sie darf keinen darunterliegenden Kampfpfad aktivieren.

## Tatsächliche Kartenansicht

`scripts/alpha/inspection_card.gd` erweitert den vorhandenen FullCardFace.
Original-ID, Originalillustration, bestehendes Material, Machtfarbe,
Fraktionszeichen und `Frames.CHOSEN` bleiben erhalten. Die Außenkontur hat
weiterhin exakt 63:88. Eine endgültige neue Rahmenwahl findet nicht statt.

Die Karte zeigt Kosten, vollständigen Namen, Macht, Typ, Wesensarten,
Fähigkeiten, Seltenheit und bei Wesen Angriff/Leben. Beim Inspizieren eines
ausgespielten Wesens werden seine aktuellen Kampfwerte ausschließlich in einer
Darstellungskopie eingesetzt; der Katalog wird nicht verändert.

Die frühere zusätzliche Textspalte mit wiederholtem Namen, Kosten, Werten und
Fähigkeit entfällt. Der Kartentext bleibt vollständig und wortgleich zur
Quelle. Keine Ziele, Auslöser, Zahlen, Bedingungen oder Nutzungslimits werden
zur Platzersparnis entfernt.

### Lesbarkeit in beiden Orientierungen

Ein unverändert verkleinerter 756×1056-Master ergibt bei 340 CSS-Pixel
Kartenhöhe lediglich 7,7–9,7 CSS-Pixel Regeltext (24–30 Masterpixel ×
340/1056). Der vergrößerte Inspector verwendet
deshalb tatsächliche, adaptive Text-Controls innerhalb derselben Karte:

- mindestens 13 CSS-Pixel Fähigkeitstext, bis 18 auf größeren Karten;
- vollständige Karte innerhalb der nutzbaren Fläche;
- volle Illustration im bestehenden Kartenrahmen;
- ausschließlich die innere Informationsfläche kann vertikal gescrollt werden;
- tatsächliche Schriftzeilenhöhen schützen Kampfwerte und Seltenheit bei
  ungewöhnlich kurzer Browserhöhe; nötigenfalls erscheinen ATK/LP statt
  ausgeschriebener Beschriftungen;
- keine seitliche Textspalte und kein gesamtes scrollendes Dialogfenster.

Lange Fähigkeiten bleiben somit vollständig zugänglich, während Karte,
Illustration, Name, Kosten und Schließen sichtbar bleiben. Die längste aktuelle
Beschreibung hat 295 Zeichen; 53 der 550 Beschreibungen überschreiten 220 Zeichen.
Diese Scrollmöglichkeit ist eine Präsentationsentscheidung, keine Kürzung von
Spielmechanik.

Eine offene Kartenansicht bleibt auch dann sichtbar und nutzbar, wenn die
Kampfarena dahinter im Hochformat ihre Orientierungshilfe zeigt. Rotation
schließt die Karte nicht und verwirft keine Auswahl oder Partie.

## Separates, zentrales Glossar

Die kleine **?**-Schaltfläche öffnet eine separate Hilfe zur aktuellen Karte.
Definitionen stammen weiterhin zentral aus `scripts/alpha/style.gd::GLOSSARY`.
Die Hilfe schließt zur selben Karte zurück und führt keine Modellaktion aus.

Die Erkennung verwendet Wortgrenzen. Der belegte alte Fehler, dass **Heile**
die Definition von **Eile** auslöste, wird damit verhindert. Der bisher jeder
Karte ungefragt angehängte Absatz über freie Gegenpfade entfällt aus dieser
kontextbezogenen Hilfe. Die eigentliche direkte Heldenangriffsregel und die
allgemeine Ressourcen-/Regelhilfe bleiben unverändert.

## Entwicklungsprüfungen und gefundene Fehler

| Prüfung | Tatsächliches Ergebnis / Maßnahme |
| --- | --- |
| Erster Godot-4.6.3-Editorimport der neuen UI | Exit 0, keine Script-/Parsefehler. Noch keine vollständige Regression. |
| Erste neue native Suite | Parsefehler: `Session.digest(Dictionary)` wurde in zwei neuen Testzeilen ein Array übergeben. Arrays werden jetzt ausdrücklich als `{cards: …}` gehasht; keine Assertion entfiel. Der fehlerhafte Lauf zählt nicht als bestanden. |
| Statische Prüfung der Zweiten Möglichkeit | Die Karte war zunächst durch eine zu frühe `active == hero`-UI-Prüfung gesperrt. In dieser bestehenden Vorbereitungsphase bleibt regelkonform der beginnende Gegner aktiv. Die Ausnahmeregel für die vorhandene zweite Spielerwahl ist korrigiert; eine ausdrückliche Regression ist ergänzt, deren tatsächlicher Lauf separat nachgewiesen wird. |
| Statische Prüfung sehr kurzer Karten | Mindestschrift und zu kleine Master-Footerflächen konnten sich überlagern. Footerhöhen folgen jetzt tatsächlichen Schriftmetriken; zusätzliche Prüfungen sichern Textzeilen, Kartenkontur und Abstände. |
| Lade-/Offline-/Provenienzkennzeichnung | Der höhere Inspector-Header verdeckte die geerbte Kennzeichnung. Sie erscheint jetzt als eigene sichtbare Beschriftung innerhalb der Illustration. |
| Erste tatsächliche native Voransichten, 844×390 / 390×844 | Originalillustration, bestehender Rahmen und innenliegender lesbarer Kartentext sind sichtbar. Diese Zwischenbilder ersetzen weder die endgültige Head-QA noch physische Gerätetests. |
| `mobile_card_inspection.gd`, vollständige native Ausführung | **3399 Assertions, 0 Fehler.** Reale Eingaben, Originalbefehle, Rotation, Footer, Glossar und sämtliche 550 Quelltexte; keine Behauptung von 550 gespielten Partien. |
| `premium_battle_geometry.gd` | **1018 Assertions, 0 Fehler.** Einschließlich realer Inspector-Geometrie, Reliktbesitz und unverändertem Modell/RNG. |
| `premium_drag_cancel.gd` | **112 Assertions, 0 Fehler.** Vorhandene Abbruch-, Mehrfinger-, Tastatur-, Ereignispaket- und legale Drop-Prüfungen erhalten. |
| `master550_opening_ui.gd`, sichtbarer Godot-Renderer | **3852 Assertions, 0 Fehler.** Öffnung, Zweite Möglichkeit, echte Ziele, Karteninspektion, Ziehen und Replays. Der vorherige irrtümliche Headless-Aufruf des framebufferabhängigen Tests zählt nicht als bestanden. |
| `alpha02_ui.gd`, sichtbarer Godot-Renderer | **4439 Assertions, 0 Fehler.** Porträt, Rotation, Starterdecks, Kartenauswahl und persistierte Deckbearbeitung. |
| Erster direkter `alpha_ui.gd`-Aufruf | 355 Assertions ohne fehlgeschlagene Assertion, aber PNG-Speicherfehler durch fehlendes, normalerweise vom Wrapper erstelltes `work/alpha`-Verzeichnis. Der Lauf zählt wegen der Fehler ausdrücklich nicht als bestanden; das Verzeichnis wurde für die Wiederholung angelegt. |
| `alpha03_orientation.gd` | **96 Assertions, 0 Fehler.** Vollständiges Modell/RNG, Befehle, UI-Auswahl, Mulligan und wiederholter Layoutaufbau bleiben erhalten. |
| `production_short_landscape.gd` | **430 Assertions, 0 Fehler.** Sichere sehr kurze Browserhöhen, Touchaktionen, innere Geometrie, Objekt-/Ressourcenlebenszyklus und Portrait-Rückkehr. |

## Daten, Regeln und Rechte

Keine Kartendaten, Kartenwerte, Fähigkeiten, Zielregeln, Seltenheiten,
Katalog-IDs, Deckregeln, Lore, Illustrationen, Rechtefelder oder Wirtschaftswerte
werden geändert. Die archivierten Alpha-/Legacy-Kataloge bleiben vorhanden.
Es gibt weder eine neue Kampfengine noch eine neue Release-Pipeline.

## Testvertrag und reproduzierbare Befehle

Neue additive native Suite:

```sh
godot --headless --path . --audio-driver Dummy --script tests/mobile_card_inspection.gd
```

Sie prüft echte Eingaben und Originalbefehle für Tap, Mulligan-Markierung,
Außen-Tap, abgebrochene Berührung, separate Hilfe, Hoch-/Querformat,
explizite Auswahl, anschließendes gültiges Ziel und deterministisches Replay.
Zusätzlich werden alle 550 vollständigen Originaltexte und unveränderten
mechanischen Definitionen an zwei Kartengrößen geprüft. Diese reinen
Textlayout-Prüfungen zählen nicht als 550 ausgespielte Karten oder Partien.

Die neue Suite ist zusätzlich in der bestehenden Pflichtschleife von
`tools/test_premium.sh` eingetragen. Sämtliche bisherigen Suites, Timeouts,
Assertions und Leak-Guards bleiben erhalten. Bestehende Eingabetests wurden
auf den ausdrücklich geänderten Bedienvertrag angepasst:

```sh
godot --headless --path . --audio-driver Dummy --script tests/premium_drag_cancel.gd
godot --headless --path . --audio-driver Dummy --script tests/premium_battle_geometry.gd
godot --path . --audio-driver Dummy --script tests/master550_opening_ui.gd
godot --path . --audio-driver Dummy --script tests/alpha_ui.gd
godot --path . --audio-driver Dummy --script tests/alpha02_ui.gd
godot --headless --path . --audio-driver Dummy --script tests/alpha03_orientation.gd
godot --path . --audio-driver Dummy --script tests/production_short_landscape.gd
```

Browserharnesses verwenden die tatsächlichen Schaltflächen
`inspect_select`, `inspect_mulligan`, `inspect_keywords`, `inspect_help_close`
und `modal_close`. QA-Beobachtungen stammen aus den tatsächlich dargestellten
Controls: Karte, Titel, Originaltext, gezeichnete Originalillustration einschließlich sichtbarer Lade-/Offline-/
Provenienzkennzeichnung, sichtbare Scrollfläche, vollständige innere Textfläche und aktueller Scrollwert.
Es existieren keine versteckten Ersatzlabels zur Erfüllung alter Tests.

Vorher-/Nachheraufnahmen müssen aus dem tatsächlichen Godot-/Web-Build stammen.
Automatisierte Viewport- oder WebKit-Prüfungen sind keine physischen
iPhone-/Android-Gerätetests. Eine endgültige Veröffentlichung darf erst nach
vollständiger erfolgreicher Head-QA, regulärer Integration und neuer QA des
exakten Merge-Commits erfolgen.
