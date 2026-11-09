# Legacy-Grundlagen P01a–P01c / P02a–P02c

Stand: 2026-11-09. Feature-Branch `feature/legacy-foundations`, Basis `develop` bei `b1f5ea59a4754bac19df31e279bff8a295cb6ea8`. Referenz: [übernommener Implementierungsplan](IMPLEMENTATION_PLAN.md). Herkunft und ausdrückliche Übernahme aus dem **nicht gemergten** Audit-PR #1: [REFERENCE_PROVENANCE.md](REFERENCE_PROVENANCE.md).

## Ergebnis und strikte Umfangsgrenze

Implementiert sind ausschließlich Testreferenz, reproduzierbare Fixtures, struktureller Zustandsvergleich, separater Datenkatalog, Deckvalidierung und die fünf ursprünglichen Decklisten. **Keine produktive Arena-/Kampflogik wurde geändert oder aktiviert.** Auch Story, bestehende Anzeigenamen, Design, Kampagnen, Assets, sieben Prototypkarten, bestehender Godot-Testoracle, Projekt-/Exportkonfiguration und Pages-Workflow bleiben unverändert.

Die 100 Legacy-Karten sind jetzt als **Regeldaten** in Godot lesbar. Ihre Fähigkeiten sind dadurch **nicht** in der Arena spielbar. Die frühere Auditmatrix beschreibt produktive Kampfparität; deren fehlende Fähigkeiten werden durch diesen Datenimport nicht nachträglich zu vollständig erklärt.

## Implementierte Pakete und Nachweise

| Paket | Umsetzung | Nachweis / Begrenzung |
|---|---|---|
| P01a | Byteidentische JS-Engine als reine Testreferenz, Commit-/Blob-/SHA-Pin, Schema-Lock, frische VM pro Ladevorgang | Tests lehnen falschen Commit, Blob und veränderte Bytes ab; lokaler Checkout am Originalcommit zusätzlich verifiziert. Kein Zugriff auf mutable `main` beim Testlauf. |
| P01b | Deterministischer Generator für sechs Daten-/Fixturedateien; 124 synthetische Kontrollszenarien mit 152 Schritten; sechs tatsächliche Eröffnungen;24 Deckprüffälle | Generator läuft wiederholt identisch; `--check` vergleicht alle sechs Dateien bytegenau. Ergebnisse stammen aus echter alter Engine, nicht nachgebauten Regelberechnungen. |
| P01c | Node- und Godot-Helfer für vollständigen strukturellen JSON-Vergleich | Schlüsselreihenfolge egal, Arrays/fehlende Felder/Typen/IDs nicht; mutierte HP-/Deck-/Zielfelder werden erkannt. Kein Replayhash und noch kein Godot-Kampf-Differentialtest. |
| P02a | 100 Original-IDs und alle originalen Regelfelder unter `data/legacy/`, RefCounted-Katalog; Originalanzeigetexte separat | Alle 100 Datensätze feldweise gegen Originalexport geprüft, einschließlich Namen/Beschreibungen in separater Datei. Unbekannte IDs werden nicht erraten; zurückgegebene Daten sind Kopien. |
| P02b | Deckvalidator:20–25, bekannte String-IDs, Kopienlimits, optional übergebener Besitzbestand | 24 JS-Golden-Fälle plus Godot-Tests für ungültige Typen und unveränderte Eingabedaten. Kein gespeicherter Besitz oder Kaufdienst. |
| P02c | START plus vier gemischte Standarddecks, jeweils Originalreihenfolge und 25 Karten | Alle fünf Listen exakt verglichen und validiert; keine automatische Verknüpfung zu heutigen Godot-Decks oder neuen Fraktionen. |

### Dateistruktur

- [`tests/reference/duel_deck/`](../../tests/reference/duel_deck/README.md): unveränderte Referenzengine und `source.lock.json`.
- [`tools/legacy/`](../../tools/legacy/README.md): Referenzadapter, Generator, Eingabeszenarien und Node-Vergleich.
- [`tests/fixtures/legacy/`](../../tests/fixtures/legacy/): Referenzdaten/Deckfälle/Übergänge; nicht mit der alten sieben-Karten-Datei `legacy_card_pool.json` verwechseln.
- [`data/legacy/`](../../data/legacy/README.md): separates Schema für Regeldaten, Anzeige und Decklisten.
- [`scripts/legacy/`](../../scripts/legacy/): Katalog, Deckvalidator, Displayzugriff; kein Autoload, keine UI-/Sammlungs-/Speicher-/Commerce-Abhängigkeit.
- [`tests/legacy_foundations.test.cjs`](../../tests/legacy_foundations.test.cjs), [`tests/legacy_foundations.gd`](../../tests/legacy_foundations.gd), [`tests/legacy_fixture_compare.gd`](../../tests/legacy_fixture_compare.gd): gezielte Prüfungen und Godot-Vergleichshelfer.
- [`tools/test_legacy.sh`](../../tools/test_legacy.sh): offline reproduzierbare neue Suite; zusätzlicher isolierter PR-Workflow `legacy-foundations.yml`, **ohne Deployment**. Bestehender Pages-Workflow nicht geändert.

## Importierte Karten und Decks

Unveränderlicher Ursprung: [duel-deck Commit 34b3062c3f22c0950d9323ad9b97b17c41d1d14f](https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js). Engine-SHA-256 `abf880e049080a7ec39a43fefa805ba9e8de18f7638633bef6d7096dc5a78dd1`, Git-Blob `d3f48929c334052b2e4062264fe5c9ac39b49c6a`.

| Original-order | Originalbezeichnung | Original-IDs | Anzahl | Legendäre ID |
|---|---|---|---:|---|
| ash | Aschenpakt | ash-0 bis ash-24 | 25 | ash-24 |
| tide | Gezeitenorden | tide-0 bis tide-24 | 25 | tide-24 |
| thorn | Dornenzirkel | thorn-0 bis thorn-24 | 25 | thorn-24 |
| veil | Nachtkonklave | veil-0 bis veil-24 | 25 | veil-24 |

Alle 100 sind `kind: creature`:44 common,32 rare,20 epic,4 legendary. Effektverteilung: weave12, pulse4, die übrigen14 Effektarten je6. Vollständige Einzelwerte stehen im [originalen Kartenfixture](../../tests/fixtures/legacy/cards.json); [reiner Regelkatalog](../../data/legacy/cards.json), [separate Originaltexte](../../data/legacy/display_de.json). Die100 Zeilen des übernommenen Audits bleiben als historische Runtime-Bestandsaufnahme erhalten.

Importierte Decklisten: `start` (START), `ash` (Aschensturm), `tide` (Gezeitenwall), `thorn` (Dornenwacht), `veil` (Nachtgewebe), je 25 Original-IDs. Das sind gemischte Listen, keine25er-Monofraktionsdecks. Der Validator akzeptiert entsprechend Originalregel20–25 Karten, obwohl die mitgelieferten Listen25 enthalten.

**Identität bleibt unabhängig vom Namen:** `catalog.card("tide-12")` liefert unter anderem `atk:2`, `effect:pierce`; die heutige Prototyp-Nebelqualle bleibt Index2 / Angriff1 ohne Effekt. `veil-18` bleibt Kosten2 / Angriff1 / HP7 / ward; der heutige Schattenwolf bleibt Index3 / Kosten3 / Angriff3 / HP4. Es gibt keine Zuordnung per Namensgleichheit und keine Veränderung dieser produktiven Karten. Funkenstoß bleibt ausschließlich im bestehenden Prototyppool.

## Fixture- und Testabdeckung

Die124 kontrollierten Zustände sind **synthetische Testeingaben**, keine behaupteten natürlichen Ziehfolgen und keine vollständigen Replayexporte. Jede Ausgabe wird von der fixierten JS-Engine berechnet. Die sechs Eröffnungen sind dagegen unveränderte `createBattle`-Aufrufe für zwei Startseiten und Level 1/2/5. Der vollständige Zustandsvergleich entfernt keine Ressourcen, Flags, Ziele, Deckreihenfolgen oder Pendingfelder.

| Bereich | Nachweis |
|---|---|
| Referenz und Datenreproduktion | falscher Pin/Blob/Bytes rot; VM-Mutation nicht auf Folgelauf übertragen; sechs Ausgaben wiederholt und gegen eingecheckte Bytes gleich |
| Karten | alle 100 IDs und sämtliche neun Regelfelder sowie Originalnamen/-beschreibungen gegen JS; 4 × 25, vier Legendäre, ausschließlich Kreaturen; keine Aliaszuordnung zur Arena |
| Decks | Länge19/20/25/26, null/String, unbekannte ID, Grenze/Überschreitung für alle vier Seltenheiten, Besitz passend/leer/fehlend/zu wenig, alle fünf Originaldecks |
| Kommandos | alle11 aufgezeichneten Commands jeweils angenommen und abgelehnt, mit Before/After/Ereignissen; zusätzlich ausgewählte Enginehelfer |
| Effekte / Ziele | alle 16 Fähigkeiten als Ankunftsfall, ausgewählte Randfälle, strike-Fallback/Zielwahl, shift-Auswahl/Skip/Formation, zwölf gerichtete Reaktionen |
| Angriffe / Status | beide Seiten, leer/belegt/geschützt, Wartezeit/Eile/Stun, Vergeltung, Pierce-Ankunft versus Überlauf, Schwächung, früher Siegstop |
| Ziehen / Ressourcen | Handcap, Pflichtverbrennen, Bestätigung, leeres Effektziehen, Erschöpfungssteigerung/Reset, Kreislaufpreise, Rückholung, Resonanz-/Schildcaps, Energieschwellen |
| Andere Aktionen / Ergebnis | Manöver, Wacht, vier Entfesselungen und Gates, Helden- und beidseitiger Pfadsieg, unterbrochene Kontrollserie |
| Vergleichshelfer | Objektfeldreihenfolge und1/1.0 gleich; fehlende HP, zusätzliche Felder, Arrayreihenfolge, String/Zahl, bool/Zahl und falsche Ziel-ID ungleich; unsichere Zahlen nicht akzeptiert |
| Isolierung | Produktionsskripte/Szenen/Autoloadkonfiguration referenzieren keine neuen Legacy-Pfade; bestehender Pool unverändert; neue APIs verändern zurückgegebene Kopien oder Eingabedaten nicht rückwirkend |

### Aktuelle Testergebnisse

Alle folgenden Läufe wurden für diesen Featurestand neu ausgeführt (Node24.22.1, Godot4.6.3, Linux/Xvfb/Mesa-Softwaretreiber). [Maschinenlesbare Ergebnisse und geprüfte Dateihashes](foundations-evidence/results.json), [Nachweisdateien](foundations-evidence/). Abschließende Leerzeilen/Leerzeichen der neuen Logkopien sind für die Reviewansicht normalisiert, Fehlertexte nicht gekürzt.

| Prüfung | Ergebnis | Aussagegrenze |
|---|---|---|
| `tools/test_legacy.sh` | **Exit0; acht Node-Testgruppen und2171 Godot-Assertions, 0 Fehler** | Neue Katalog-/Validator-/Fixturegrundlage, kein Legacy-Kampf in Godot |
| `generate.cjs --check --verify-checkout …` | **Exit0; sechs Ausgaben byteidentisch**, Originalcheckout-Commit und Enginebytes stimmen | Offline reproduzierbarer Pin und Import, kein Port des RNG |
| Bestehende `DISPLAY=:99 tools/test.sh` | **Exit0; 9547 Assertions, 0 Fehler** | Aktuelle Godot-Regressionen; der bisherige Oracle bleibt Godot-intern |
| Darin Regeln/Creative/Narrative | 684 /2253 /97 Assertions, je0 Fehler | Originale sieben Godot-Karten und Datenverträge unverändert |
| Darin Experience/Input/Premium | 707 /380 /1720 Assertions, je0 Fehler | Menü/Fortschritt und simulierte Touch-/Querformatlayouts |
| Darin UX/Combat/Sequence | 2350 /725 /631 Assertions, je0 Fehler | Desktop-Renders, vollständige Prototypduelle und Präsentation |
| Audio/Kontrast | 11 Cues bestanden;89 gerenderte Zustände/3836 Regionen, 0 Fehler | Darstellungs-/Signalprüfung, keine zusätzlichen Regelassertions |
| Fixiertes Upstream-`test.js` | **Exit0;250 vollständige Partien /250 Replayprüfungen**,45 Helden-/205 Gegnersiege | Nur Reproduzierbarkeit innerhalb JS |
| Fixiertes Upstream-`tests.js` | **Exit1; bekannte START-Längenassertion20 statt25** | Suite veraltet, nachfolgende Checks nicht erfolgreich gezählt |
| Fixiertes Upstream-`ui-smoke.test.js` | **Exit1; unvollständiger DOM-Mock** | Kein echter Browsertest, keine Aussage über reale Browserfunktion |
| Fixiertes Upstream-`check.js` | **Exit1; externe Aufzeichnung fehlt** | Diese Inhaltsprüfung bleibt nicht ausführbar |

Die erfolgreichen vollständigen Godot-Suiten enthalten keine `SCRIPT ERROR`-/`ERROR:`-/`FAIL:`-Meldungen. Erwartete Umgebungswarnungen betreffen den nicht erreichbaren Android-ADB-Daemon und V-Sync des Softwaretreibers; daraus wird kein Android-Gerätetest abgeleitet.

### Entdeckte Fehler und bewusst erhaltene Abweichungen

1. **Korrigierter eigener Fixturefehler:** Im ersten Node-Lauf ergaben Seeds1 und4294967295 beide `coin:hero`; die Abdeckungsprüfung erwartete zu Recht zwei Startseiten (1 statt2). Zweiter Seed auf2147483648 geändert; Originalengine liefert damit `coin:enemy`. Danach neue Goldens erzeugt und vollständige neue Suite erneut bestanden. [Fehlerprotokoll des ersten Laufs](foundations-evidence/initial-node-failure.log).
2. **Bestehende Upstream-Testschuld erneut bestätigt:** `tests.js` erwartet20 statt tatsächlich25 START-Karten; `ui-smoke.test.js` scheitert am unvollständigen `document.body.classList`-Mock; `check.js` verlangt die nicht versionierte externe Datei `/mnt/data/nachtsiegel-kampf-2162621497.json`. Nichts daran geändert; die erfolgreichen250 Replayduelle kommen aus `test.js`, nicht diesen roten Prüfungen. [Einzelprotokolle](foundations-evidence/).
3. **Bewusst typisierte neue Deck-API:** Reguläre JSON-Decks und nichtnegative ganzzahlige Bestandswerte folgen dem Referenzvertrag. Die JavaScript-Coercion einzelner Array-/Objekt-IDs und beliebiger falsy-/String-`owned`-Werte wird nicht übernommen. Solche ungültigen Typen werden mit strukturiertem Fehler abgewiesen; kein uneingeschränkter Gleichheitsclaim für beliebige JavaScript-Werte. Diese neue isolierte API verändert kein Produktionsverhalten.
4. **Alte API-Eigenheiten bleiben Fixtures:** `burn` und `skipShift` haben keinen eigenen Gewinnercheck; `recover` prüft keine Pendingziel-Sperre. Entsprechende angenommene Übergänge werden eingefroren, nicht stillschweigend gehärtet.
5. **Keine bekannten Abweichungen bei regulären importierten Kartendaten/Decklisten:** Alle 100 Datensätze und fünf Listen stimmen innerhalb des geprüften Schemas überein. Das sagt nichts über spielbare Effekte oder Kampfparität aus.

## Architektur für späteres Free-to-play

Regelkatalog und Deckvalidierung kennen weder Preise noch Kaufstatus, Accounts, Bezahlplattformen, Booster oder Währungen. Vollständiger Kartenkatalog ist nicht gleich Nutzerbesitz. Optionaler `owned`-Input ist eine explizite Bestandsaufnahme einer späteren Anwendungsschicht, unabhängig davon, ob Karten frei, erspielt oder optional erworben sind. Ohne `owned` gilt wie in JS keine Bestandsbeschränkung; das aktiviert keine Freischaltung in der vorhandenen Sammlung.

IDs sind dauerhafte Regelidentität; Anzeigenamen, Sammlung, Fortschritt und mögliche spätere Kaufberechtigungen dürfen darauf verweisen, aber bestimmen keine Kartenwerte. Es gibt keine monetarisierungsabhängige Kampflogik und keine vorgetäuschte Zahlungs-/Accountinfrastruktur.

## Offene Abhängigkeiten und nicht behauptete Leistungen

- **P02d offen:** kein portierter JS-RNG/Shuffle/Ziehrichtungsvertrag in Godot. Eröffnungen stehen nur als Referenzzustände bereit.
- **P03–P10 offen:** kein neues symmetrisches Kampfmodell, Phasenscheduler, Effektqueue, Schaden-/Statussystem, Resonanz, KI oder Arena-Integration. Vor einer späteren Aktivierung bewusste Entscheidung über Regelmodus und bestehende Godot-Zusätze erforderlich.
- **P11 offen:** keine JS-kompatiblen Snapshot-/Replayhashes, Commandhistorie oder produktive Replayimporte. Strukturell gleicher JSON-Inhalt ist nicht gleich JS-FNV-Hash nach originaler Schlüsselreihenfolge.
- **P12 offen:** keine neue Sammlung, Deckwerkstatt, Speicher-/Altstandmigration oder lokale Ökonomie. Bestehende sieben Karten und13 Konzepte bleiben wie bisher.
- 124 Szenarien sind ausgewählte Grenzfälle, kein Beweis aller Effektekombinationen oder vollständiger engineübergreifender Partien. Godot liest und vergleicht die Fixtures, führt deren Kampfkommandos aber nicht aus.
- Keine Aktivierung/Änderung von Exportfiltern und kein neuer Web-/Android-/iOS-Export in diesem Auftrag; Verfügbarkeit der isolierten JSON-Dateien im produktiven PCK nicht geprüft. Vor Aktivierung separat verpacken und gegen exportiertes Paket testen.
- Keine neuen Browser-/physischen Gerätetests; Xvfb-Eingabe-/Rendertests sind Desktopprüfungen. Kein GitHub-Pages-Deployment.
- Der fixierte Upstream enthält keine versionierte LICENSE-/COPYING-Datei. Die Testreferenz wahrt Herkunft und Bytes, behauptet aber keine zusätzliche kommerzielle Rechtefreigabe; siehe Referenz-README.

## Reproduktion und PR-Grenze

```bash
# Node24, Godot4.6.3; neue Suite ohne Netzwerk oder Display:
tools/test_legacy.sh
# Optional: vorhandenen Checkout zusätzlich gegen Commit und Dateibytes prüfen:
node tools/legacy/generate.cjs --check --verify-checkout /path/to/duel-deck
# Bestehende produktive Regressionen einschließlich Render/Input, z.B. unter Xvfb:
DISPLAY=:99 tools/test.sh
```

Der neue PR geht gegen `develop`, ohne Auto-Merge. PR #1 bleibt offen und ungemergt; die Referenzübernahme ist im neuen PR explizit aufgeführt. Keine automatische Integration oder Veröffentlichung.
