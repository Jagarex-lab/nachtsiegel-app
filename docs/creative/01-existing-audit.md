# A1 – Tatsächlicher Bestand und Bewertung

Untersucht wurde der vollständige getrackte Dateibaum von `develop` bei `927ae10`, insbesondere sämtliche GDScripts und Szenen, Projekt-/Exportmetadaten, README, Roadmap, Art Direction, Assetmanifest und QA-Dokumente. `work/` ist ein ignorierter Arbeitsbereich; alte Testbelege sind keine neue Lorequelle. Es gibt vor dieser Änderung kein `data/`-Loremodell, keinen Dialogbaum und keine Worldbuilding-Bibel. Die folgenden Befunde beziehen sich ausschließlich auf den Ausgangsstand.

## Belegte Namen und Inhalte

| Bestand | Quelle | Tatsächliche Bedeutung |
|---|---|---|
| NACHTSIEGEL | `project.godot`, `arena.gd`, `export_presets.cfg`, `web/shell.html`, README | Angezeigter Spielname; noch keine begründete Weltdefinition des Siegels |
| Mondheiligtum | `docs/QA-SANCTUM-2026-11-08.md`, Assetmanifest | Name einer visuellen Überarbeitung; nicht als historischer oder geografischer Weltort beschrieben |
| Aschensturm, Gezeitenwall, Dornenwacht, Nachtgewebe | `docs/ART_DIRECTION_AND_QA.md`, Abschnitt Art Direction | Vier visuelle Fraktionssprachen: Glut/Kupfer, Tiefsee/Türkis, Moos/Dornen, Violett/Silber. Keine belegten Kulturen, Regierungsformen oder Gründungsgeschichten |
| Siegelhüterin | `arena.gd`, Heldenaufbau und `_show_hero`; Atlaszelle 7 | Spielerporträt, 35 Leben; keine persönliche Biografie, Herkunft oder Heldenfähigkeit |
| Aschenkönig | dieselben Stellen; Atlaszelle 8 | Gegnerporträt, 35 Leben; keine belegte Königsdynastie, Motivation oder Geschichte |
| Fünf Pfade | `arena.gd`: `LANES`, Lane-Aufbau und Kontrollsieg; alte Arenaressourcen | Positionsmechanik und visuelle Siegel; Pfade bislang I–V ohne individuelle Namen oder Effekte |
| ASH, THORN, TIDE, VEIL, SPELL | `CARD_POOL`, ältere Portrait-/Vignettenskripte | Visuelle Kennungen. `SPELL` ist keine belegte fünfte Fraktion |
| Obsidianarena / Kathedralenmotiv | Art Direction, Assetmanifest, Shader und Bilder | Atmosphärische Gestaltung, keine bestätigte Religion oder historische Katastrophe |

## Vollständiger aktueller Kartenpool

Quelle: `scripts/arena.gd`, `CARD_POOL`. Werte in Reihenfolge **Kosten / Angriff / Leben**. Die sieben Namen bleiben auch technisch unverändert.

| Index | Name | Werte | Typ / Kennung | Vorhandener Beschreibungstext |
|---|---|---|---|---|
| 0 | Aschenwache | 2 / 2 / 4 | unit / ASH | Generische Ausspielregel im Inspector |
| 1 | Dornenwolf | 2 / 3 / 2 | unit / THORN | dito |
| 2 | Nebelqualle | 2 / 1 / 5 | unit / TIDE | dito |
| 3 | Schattenwolf | 3 / 3 / 4 | unit / VEIL | dito |
| 4 | Glutritter | 4 / 4 / 5 | unit / ASH | dito |
| 5 | Gezeitenhüter | 3 / 2 / 6 | unit / TIDE | dito |
| 6 | Funkenstoß | 2 / 3 / 0 | spell / SPELL | Ziel gegnerische Kreatur, kein Held; 0 Leben ist ein Datenplatzhalter, kein Zauber-Lebenswert |

Der Inspector enthält kurze Regelhinweise sowie die Kennzeichnung KI-Konzeptillustration. Es gibt keine individuellen Flavor-Texte und keine kartenspezifischen Fähigkeiten außer dem normalen Schadenszauber. Alle Illustrationen sind laut Assetmanifest Konzept-Platzhalter. Ältere prozedurale Grafikscripts sind erhalten, werden aber von der aktuellen Arena nicht geladen; ihre Kommentare sind keine verborgene Geschichte.

## Was ausdrücklich noch nicht existiert

Keine Schöpfungserzählung, keine Weltkarte, keine benannte Epoche, keine belegte Fraktionspolitik, kein ausformuliertes Magiesystem, keine Kampagne, kein Introfilm, kein Bosscontroller, keine Biografien für sechs Helden, keine zusätzlichen 13 Karten und keine englische Lokalisierung der gesamten Spieloberfläche. Auch eine vollständige Umsetzung der historischen Webregeln ist laut README nicht nachgewiesen. Diese Lücken werden nicht nachträglich als alter Kanon ausgegeben.

## Bewertung

Skala: 1 = schwach, 5 = stark. Dies sind redaktionelle Einschätzungen, keine Nutzerstudie oder Marktkennzahl.

| Kriterium | Einschätzung | Begründung und Konsequenz |
|---|---|---|
| Originalität | 2/5 | Nacht, Asche, Dornen, Schatten und König vermitteln Genre, aber noch keinen eigenen erzählerischen Gedanken. Neue Konflikte brauchen konkrete Institutionen und Kosten |
| Wiedererkennung | 3/5 | Fünf Pfade, Metallreliquien und das Sigil schaffen ein konsistentes Bild. Diese Elemente erhalten; austauschbare Elementarfraktionen durch erkennbare Handlungen und Materialformen vertiefen |
| Emotionale Wirkung | 2/5 | Gute Atmosphäre, aber der Gegner ist nur ein Porträt. Bindung entsteht künftig durch Personen, deren Schutzabsicht mit der des Spielers kollidiert |
| Internationale Verständlichkeit | 2/5 | NACHTSIEGEL ist deutsch gut zerlegbar, englisch wegen „ch“, „ie“ und Bedeutungsverlust schwieriger. Eigennamen nicht wörtlich auf Zwang übersetzen; gemeinsame Begriffe und Aussprache anbieten |
| Welt / Mechanik | 2/5 | Die fünf Pfade sind ein starker mechanischer Anker ohne fiktionale Begründung. Gemeinsame Versorgungswege erklären Position und Kontrolle, ohne Pfadboni einzuführen |
| Erweiterbarkeit | 3/5 | Vier visuelle Kennungen und sieben Karten sind überschaubar. Neue Namen sollten Ort, Kampagne und Edition tragen können, statt die Marke auf eine einzelne Nacht oder einen König festzulegen |

## Vier Rollen – präzise Grenze der Übernahme

Der Ausgangsstand definiert **keine vier separaten Fraktionsregelwerke**. Die Aufgabe, die Rollen zu erhalten, wird deshalb konservativ ausgelegt:

- ASH: zuverlässiger Druck durch solide Körper; Aschenwache und Glutritter.
- TIDE: höhere Lebenswerte und geringe bis mittlere Angriffswerte; Nebelqualle und Gezeitenhüter.
- THORN: effizienter, aber verletzlicher Angriff; Dornenwolf.
- VEIL: ausgewogene mittlere Präsenz; Schattenwolf.

Das sind aus den vorhandenen Zahlen abgeleitete Arbeitshypothesen. „Brennen“, „Heilen“, „Gift“, „Tarnung“, Schwarm- oder Kontrollfähigkeiten werden nicht als implementierter Bestand behauptet. Funkenstoß wird nur im neuen Flavor dem Schmelzkonvent zugeordnet; seine bestehende Kennung `SPELL` und seine Wirkung ändern sich nicht.

## Entscheidung

Visuelle Substanz und fünf Pfade erhalten. Die neue Welt soll Rechte, Versorgung und begrenzte Erholung statt einer simplen Licht-gegen-Dunkelheit-Apokalypse erzählen. Bestehende generische Porträtnamen können später als Spitznamen oder Funktionen in Biografien übergehen. Eine solche Zuordnung bleibt bis zur redaktionellen Freigabe ein Vorschlag und wird nicht heimlich im laufenden Spiel aktiviert.
