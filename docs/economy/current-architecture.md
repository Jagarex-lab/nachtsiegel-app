# Tatsächlicher Bestand und Migrationsgrenzen

## Untersuchte Quellen

Sauberer Repository-Status vor Beginn: `feature/legacy-foundations`, keine lokalen Änderungen. Nach Fetch: neuer eigener Branch aus `origin/develop` bei `b1f5ea59a4754bac19df31e279bff8a295cb6ea8`. Keine fremden Änderungen übernommen. Alle Aussagen beziehen sich auf diesen fixierten Stand oder die ausdrücklich benannten offenen PRs, nicht auf die Live-Seite.

| Quelle | Stand / Nachweis | Einordnung |
|---|---|---|
| develop | [b1f5ea5](https://github.com/Jagarex-lab/nachtsiegel-app/tree/b1f5ea59a4754bac19df31e279bff8a295cb6ea8) | Stabiler Dokumentationsausgangspunkt, nicht main oder ein Featurebranch |
| Audit-PR #1 | [OPEN, 51ad544](https://github.com/Jagarex-lab/nachtsiegel-app/pull/1); [Bericht](https://github.com/Jagarex-lab/nachtsiegel-app/blob/51ad544087dba200846b4420e493fcbe656c634f/docs/migration/LEGACY_PARITY_AUDIT.md), [Plan](https://github.com/Jagarex-lab/nachtsiegel-app/blob/51ad544087dba200846b4420e493fcbe656c634f/docs/migration/IMPLEMENTATION_PLAN.md) | Gelesene Referenz; nicht gemergt, nicht verändert, nicht lokal in develop vorhanden |
| Grundlagen-PR #2 | [OPEN, 2ff7054](https://github.com/Jagarex-lab/nachtsiegel-app/pull/2); [Katalog/Validator](https://github.com/Jagarex-lab/nachtsiegel-app/tree/2ff70549d3c5e1c95f4b54c7990acd4d8970363d/scripts/legacy) | Separater 100-Karten-Katalog und Testreferenz vorgeschlagen/implementiert auf Featurebranch, **nicht auf develop**; keine produktive Legacy-Kampfintegration |
| Legacy-JS | [duel-deck 34b3062](https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js) | Tatsächliche historische Kartendaten und Regeln; kein aktueller Godot-Regelvertrag |

Keine dieser Quellen war gesperrt. PR-Status zum Analysezeitpunkt 2026-11-09: beide offen, `mergedAt:null`. Quellen werden nur gelesen; der Architekturbranch enthält keine Kopie oder Integration ihrer Implementierung.

## Implementierungen und Einschränkungen

Dateilinks im folgenden Abschnitt pinnen den develop-Commit.

| Bereich | Nachweisbarer Bestand | Lücke / spätere Migration |
|---|---|---|
| Karten | [data/card_definitions.gd](https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/data/card_definitions.gd): sechs Einheiten, ein Zauber, Arrayindex statt stabiler Kampf-ID, Name/Kosten/ATK/HP/sigil/tint | Kein Besitz, keine Instanzen, keine Kaufseltenheit. Gegen Legacy-Namen nicht automatisch mappen. `cost` ist Energie, kein Preis. |
| Legacy | JS erzeugt 100 Kreaturen: 25 je ash/tide/thorn/veil, 44 common/32 rare/20 epic/4 legendary; 16 Fähigkeiten | Laut PR #1 keine vollständige produktive Übernahme: 98 fehlen, zwei namensgleich aber abweichend; ID-Parität 0/100. Das ist kein Hindernis für einen isolierten Datenvertrag, aber ein Gate für spielbare Legacy-Modi. |
| Fähigkeiten | strike, guard, ward, mend, weave, drain, rally, silence, pierce, shift, harvest, retaliate, draw, haste, weaken, pulse in JS | Godot-Prototyp enthält keine entsprechenden Effektfelder/Dispatches. Quelle PR #1 Effekttabelle; Animation ist keine Regelausführung. |
| Decks | [battle_model.gd:22](https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/scripts/battle_model.gd#L22): festes 25er-Indexmuster, RNG-Shuffle, vier Startkarten | Keine Deckwerkstatt oder Besitzvalidierung auf develop. JS: START + vier Presets je 25; Validator 20–25, max3/nichtlegendär und max1/legendär, optional Besitz. PR #2 kapselt diesen Validator separat. Spätere Modusregeln dürfen diesen Zielvertrag nur bewusst versioniert abändern. |
| Kampf | [battle_model.gd](https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/scripts/battle_model.gd): fünf gegenüberliegende Pfade, lokale Logik; [arena.gd:861](https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/scripts/arena.gd#L861) delegiert | Gegner ohne eigenes Deck/Hand/Energie; kein serververifiziertes Matchresultat. Freier Gegenpfad trifft Held, aber Legacy-Block/Schild/Bereitschaft fehlen. Kein Reward auf bloße Client-Siegmeldung. |
| Persistenz | [progress_store.gd](https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/scripts/progress_store.gd): `progress_v1.json`, temp/rename/Backup, schema1; Web zusätzlich `nachtsiegel.progress.v1` localStorage | Tutorial, Kapitel, Siege, Niederlagen, Held, Audio/Motion; keine Währung, Serveridentität oder Inventar. `recorded_runs` auf 32 begrenzt und lokal manipulierbar; kein dauerhafter wirtschaftlicher Idempotenznachweis. |
| Sammlung/Kampagne | [front_end.gd:202](https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/scripts/front_end.gd#L202), [content.json](https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/data/narrative/content.json), [chapters.json](https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/data/campaign/chapters.json) | Sieben spielbare Ansichten plus 13 explizite Konzepte, fünf Kapitel, Heldwahl; kein handelbares Sammelinventar. Narrative IDs/legacy_pool_index sind keine Legacy-Regel-IDs oder Besitznachweise. |
| Formate/Abhängigkeiten | Godot GDScript/RefCounted, JSON-Manifest/schema1, de/en Textkeys; [project.godot](https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/project.godot) nur GameAudio-Autoload; Tests Godot4.6.3, Python/Pillow, Browser-QA Node/Playwright | Kein API-/DB-/Zahlungsdienst. Neue große Inventarzahlen nicht unbedacht über JSON-Floats senden. Exportfilter für Daten explizit; docs/tests ausgeschlossen. Neue Verträge benötigen später Pakettests. |
| Tests | [tools/test.sh](https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/tools/test.sh), rules/reference_rules, experience/input/layout/presentation, Kontrast/Audio | Godot-Regression ist kein JS-Oracle. Audit meldet 9547 Godot-Assertions und 250 JS-Replays, aber keine Cross-Engine-Parität; keine Wirtschaftssicherheit. Das sind vorliegende frühere Ergebnisse, keine in diesem Dokumentationsauftrag neu ausgeführten Spielläufe. |

## Raum und Zeit: belegter Status

Suche in versionierten `scripts/`, `data/`, `docs/` ergibt keinen implementierten Raum-Zeit-Modus, keine Zeitumkehr-API oder festgelegte neue Fähigkeitsliste. Legacy `shift`/Pfadmanöver sind räumliche Bewegungsregeln, kein Nachweis allgemeiner Raum-Zeit-Manipulation. Die vorhandene Weltbeschreibung (`data/narrative/locales/de.json`, `world.arvess.limits`; `docs/creative/03-world-bible.md`) sagt sogar, Gegenmaß verändere keine Vergangenheit. Dieser mögliche Lorekonflikt wird hier nicht aufgelöst.

Folgerung: spätere technische Capability-/Modusverträge vorschlagen, keine vorhandenen Mechaniken erfinden oder Lore ändern. Fünf Pfade bleiben Basistopologie. Eine abweichende Topologie oder zeitliche Aktionsregel braucht eigene Rulesetversion, Simulation, UI- und Servertests. Wirtschaftstransaktionen bleiben außerhalb jedes Kampf-Rewinds.

## Notwendige Migrationsreihenfolge

1. PR #2 separat reviewen; stabilen Katalog-/Modusvertrag beschließen. Original-IDs/Parameter erhalten, Anzeigetexte abtrennen. Keine Übernahme durch diesen PR.
2. Legacy-Regelarbeit gemäß PR #1 P02d–P11 unabhängig durchführen, falls Legacy spielbares Ziel wird. Wirtschaft kann offline mit Testdefinitionen entstehen, darf fehlende Kampfregeln nicht als vorhanden deklarieren.
3. Definitionen/Regelrevisionen, Besitzinstanzen und Leihrechte trennen. Aktuelle Indexdecks nur nach ausdrücklich geprüftem Mapping; keine Namensheuristik.
4. Lokalen Fortschritt als lokale Komfortdaten erhalten. Keine automatisch konvertierten Siege, Kopien oder Währungen als Serververmögen. Optional serverseitig einmalige, begrenzte Welcome-Rewards unabhängig von untrusted Clientwerten.
5. Simulationsadapter durch API ersetzen; Authentisierung, Serverbelohnungsquellen, Ledger und Recovery vor jedem Echtgeld-/Handelsbetrieb abnehmen. Aktuelle Spielstände in diesem Auftrag nicht migrieren.
