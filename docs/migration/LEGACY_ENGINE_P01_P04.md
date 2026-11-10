# Legacy-Kampfkernel P01–P04

Stand: 2026-11-09. **Isolierter, nicht in die Arena integrierter Legacy-Kernel. Keine vollständige Legacy-Parität und noch kein automatisches vollständiges Duell.** Produktive Arena, Prototypkarten, Story/Fraktionen, Assets, Pages-/Exportkonfiguration und F2P-Architektur bleiben unverändert.

## Basis, offene PRs und Mergefolge

| Referenz | Tatsächlich geprüft zu Arbeitsbeginn | Verwendung |
|---|---|---|
| PR #1 Audit/Plan | OPEN, `51ad544087dba200846b4420e493fcbe656c634f`, QA SUCCESS, Deployment SKIPPED | Bereits über PR #2 enthaltene Dokumentationsreferenz |
| PR #2 Grundlagen | OPEN, `2ff70549d3c5e1c95f4b54c7990acd4d8970363d`, Foundation-CI und beide QA-Läufe SUCCESS, Deployment SKIPPED | **Verbindlicher direkter Branchausgangspunkt** |
| PR #3 F2P-Architektur | OPEN, `d3634b462444760665ba169dcd2be7df86baddfe`, QA SUCCESS, Deployment SKIPPED | Unabhängig; nicht übernommen oder verändert |
| Legacy-JS | `Jagarex-lab/duel-deck` bei `34b3062c3f22c0950d9323ad9b97b17c41d1d14f` | Unveränderte Testengine, Originalwerte und Übergänge |

Arbeitsbranch `feature/legacy-engine-p01-p04`, Basis nicht develop, sondern der geprüfte Commit von PR #2. Der Folge-PR richtet sich für einen kleinen reviewbaren Stack-Diff gegen **`feature/legacy-foundations`**. Keine fremden Features/Produktmodelle kopiert, keine Auto-Merges.

Empfohlene Reihenfolge: Audit PR #1, dann Grundlagen PR #2, danach dieser Kernel-PR. Die Auditdateien wurden von PR #2 bereits explizit übernommen; identische Dokumentdateien bei Integration prüfen. **Nach Merge von PR #2 diesen PR auf develop retargeten und CI erneut prüfen; nicht vorab in den offenen Grundlagenbranch mergen.** PR #3 hat keine technische Abhängigkeit und benötigt keine Integration für den Kernel. In diesem Auftrag wird keiner dieser PRs gemergt oder deployt.

## Was vollständig vorhanden ist — und was nicht

P01a–c/P02a–c aus [LEGACY_FOUNDATIONS.md](LEGACY_FOUNDATIONS.md) wiederverwendet, nicht dupliziert. Neue Regelimplementierung ausschließlich in [`scripts/legacy/battle_engine.gd`](../../scripts/legacy/battle_engine.gd), RNG in [`rng.gd`](../../scripts/legacy/rng.gd). Katalog und Deckvalidator bleiben dieselben bestehenden Komponenten. Godot-Prototyp und sein alter Testoracle sind weiterhin separat.

| Teilpaket | Stand / präziser Vertrag |
|---|---|
| P01a | Verifizierte unveränderte JS-Bytes, Commit/Blob/SHA-Pin und frische VM weiterbenutzt. Optionaler beobachtender `Math.imul`-Hook liefert native Resultate unverändert und prüft tatsächliche RNG-Aufrufzahlen. Instrumentierte und uninstrumentierte Initialzustände werden verglichen. |
| P01b–c | Alte Goldens unverändert; separate neue, reproduzierbare Goldens für RNG, Eröffnungsgrenzen, Phasen, Schaden, gemischte Kämpfe, Todeszustände und Queue. Struktureller Vergleich unverändert streng. Manipulierte Werte/fehlende Felder/Deck- und ID-Änderungen sowie Referenzkorruption werden erkannt. |
| P02a–c | Alle 100 Karten und fünf Originallisten erneut gegen fixierte JS-Daten geprüft; unveränderte IDs/Werte, Anzeige separat, keine Zuordnung zu den sieben Prototypkarten. |
| P02d | JS-LCG mit unsigned32-Maske, Fisher–Yates, Deckanfangziehen und originale Konsumreihenfolge einschließlich zweier Mischvorgänge des Gegnerdecks. Exakte Zustände/Aufrufzahlen/folgender RNG-Wert geprüft. |
| P03a | Beide vollständigen Spielerzustände mit Deck/Hand/Ablage/Pfaden, HP/maxHP, Block/Schild/Resonanz/Energie, Pendingzuständen und sämtlichen Originalflags. |
| P03b | Originaler Münzwurf, levelabhängiger Gegnerpool/HP, ursprüngliche komplette Deckreihenfolgen, +4 Schild für zweiten Spieler und erster begin/3er-Nachzug. **Grenze vor automatischem enemyTurn**; dessen Umsetzung gehört laut Plan zu P10. |
| P03c | begin/draw/main/attack/end und Halbzug-Roundcounter; manuelle Orchestrierung beider Seiten bis zur nächsten begin-/Nachziehgrenze. P05-Sonderfälle werden vor Mutation abgewiesen. Vollständige JS-Komfortwrapper createBattle/endTurn mit automatischer KI bleiben offen. |
| P03d | Originalformel: Basis2 + Hard-Gegnerbonus + einmaliger Zweitspielerbonus + Resonanzschwellen5/10/15; alle Resetflags und +2 Schild bei Resonanz15, cap25. Keine rundenbasierte Prototypenergie. |
| P04a | Schaden floor/max0, Block → Schild → HP, HP-Clamp und tatsächlicher HP-Verlust; expliziter Schutzignorierungsmodus nur für definierte zukünftige Aufrufe. |
| P04b | Beschwörungsverzögerung, Eile, Betäubung vor Warteprüfung, Flagreset und Schwächung für die nächste Angriffsphase. |
| P04c | Sequentiell Pfad0–4; Gegenkreatur sonst **Gegnerheld durch Schutzpipeline**, beide Seiten. Keine allgemeine Gegenwehr/kein allgemeiner Überlauf; Vergeltung nur bei positivem nichttödlichem Treffer, Durchbruch nur für pierce. |
| P04d | Entfernung vor Tod, Ablage, FIFO-Todesevents und harvest nach Ablage; cap100 je Drain, Reentranzschutz, Gewinnerabbruch, defensive Doppelverarbeitungs-/Batchvalidierung. |

**Abnahmegrenze:** P01/P02 sind umgesetzt und verifiziert. P03/P04 stellen den geprüften Kern gemäß diesen Grenzen bereit. Ein uneingeschränktes „P01–P04 vollständig als altes createBattle/endTurn spielbar“ wäre falsch: Eröffnungs-/Zugkomfortwrapper über die automatische KI und Nachziehsonderfälle sind abhängig von Folgepaketen. Diese APIs werden weder durch kostenlose Gegnerbeschwörung noch automatische Leerzüge ersetzt.

## API, Daten und ursprüngliche Grenzen

- `start(deck,seed,level)` erzeugt exakt den ursprünglichen Snapshot **vor begin** und validiert ein reguläres Legacy-Deck. `initial` ist eine eigenständige Kopie. Danach `begin_turn(state.coin)` für die originale erste Nachziehgrenze aufrufen.
- `begin_turn` ist eine vertrauenswürdige Schedulerprimitive, keine Spieler-/Netzwerkaktion. Der ursprüngliche begin setzt nach Ressourcenberechnung direkt `phase=draw`; „begin“ ist ein Ereignis, kein zusätzlicher erfundener gespeicherter Phasenwert.
- `finish_draw` unterstützt reguläres Nachziehen und Reset einer vorhandenen Erschöpfungsserie bei vollständigem Nachzug. Überlauf/Verbrennen, Kreislauf und Schaden bei Fehlkarten sind P05 und werden vor Mutation gestoppt.
- `advance_turn`/`execute("advanceTurnBoundary",[side])` führt eigene Angriffe, Ende und nächsten begin aus. Vor optionaler KI hält der Treiber an. Für verweigerte nächste P05-Grenzen simuliert eine **zweite Instanz desselben Kernels** auf einer Zustandskopie den Übergang vorab; es gibt keine zweite konkurrierende Regelimplementierung. Dadurch kann ein abgelehnter Halbzug nicht trotzdem Schaden oder Todeseffekte hinterlassen.
- `execute` ist eine geschlossene Orchestrierungsfläche: play, finishDraw, advanceTurnBoundary. Historisches `endTurn` mit KI, burn/recover/targets/tactics/burst und unbekannte Kommandos liefern ausdrücklich unsupported. Keine teilweise erfolgreiche stille Aktion.
- `play_support` erklärt Ablehnung vor Aufruf. Aktuell vollständige Beschwörung nur für die drei Kartenfähigkeiten ohne Ankunftsaktion: harvest/retaliate/haste. Ein Ordenswechsel mit Folgereaktion bleibt P07. Damit sind18 der100 originalen Karten für direkte Beschwörung unterstützt; alle100 bleiben als unveränderte Definitionen vorhanden. Aktive Beschwörungseffekte werden **nicht** zu Vanillaeinheiten degradiert.
- `attack_phase`, `damage`, `draw_cards`, `check_winner` und enqueue sind interne Test-/Regelprimitive, kein ungesicherter Onlinemodus. `state` ist im isolierten Modell für Tests zugänglich; kein Save-/Netzwerkdecoder und kein autoritativer Serverimport implementiert.
- Snapshot liefert alle Originalfelder inkl. ordered decks, deckCount/handCount, Basis-/aktueller Einheitenwerte und Pendingflags. Die separate typisierte Ereignisspur ist noch **kein** kompatibles P11-Audit/Replayschema. Todeszwischenzustände werden trotzdem gegen Originalereignisse geprüft.

```gdscript
var engine = preload("res://scripts/legacy/battle_engine.gd").new()
var deck = engine.catalog.deck("start")
if engine.start(deck, 12345, 2):
    engine.begin_turn(engine.state.coin)
# Noch kein UI-Aufruf und keine automatische KI. Unsupported-Karten sind
# vor Mutation an engine.play_support(side,index,lane) erkennbar.
```

Die Queue ist absichtlich geschlossen auf `type:death` und `type:summon` für die drei unterstützten passiven Beschwörungen; aktive Effekte werden vor Einreihung abgewiesen. P06 erweitert denselben Dispatcher. Unbekannte Typen werden abgelehnt. Keine frei ladbaren Raum-/Zeitfunktionen oder erfundenen Karten. Ein künftiger Rewind braucht zusätzlich explizite RNG-/Queue-/Identitätscheckpointverträge; `snapshot()` allein ist keine entsprechende vollständige Wiederherstellung.

### Originale Sonderregeln mit Bedeutung für P04

1. Leerer Gegenslot trifft gegnerischen Helden, nicht einen Nachbarpfad. Block wird zuerst konsumiert, danach permanenter Schild, danach HP.
2. Block verfällt erst bei **eigenem** begin, Schild bleibt bis Verbrauch und wird gedeckelt. Heldenprotektion schützt keine Kreatur.
3. pierce-Ankunft würde p+2 Schutz ignorieren (P06 noch unsupported); pierce-**Angriffsüberlauf** läuft dagegen durch Block/Schild. Kein Durchbruch bei exaktem Kill.
4. Ein getöteter Verteidiger vergilt nicht; nur überlebende retaliate-Einheit bei positivem Treffer. Angreifertod wird als eigenes Todesevent abgelegt.
5. stun wird vor summoned geprüft und löscht dabei ebenfalls summoned; Eile übergeht keine Betäubung. Die komplette Schwächung wird nach der eigenen Phase zurückgesetzt.
6. Nach jeder ursprünglichen Pfadprüfung sofort HP-Ergebnis und Abbruch; keine zusätzliche normative Prüfung an anderen Stellen erfunden. Die originale Pfadkontrolle/seals-Prüfung am Ende der Angriffsphase ist als notwendige P04-Abhängigkeit bereits enthalten, sonst wären dessen Endzustände falsch.

## Neue und wiederverwendete Testdaten

Alte Fixtures aus PR #2 (`cards.json`, `decks.json`, `transitions.json`) sowie vendorte Engine/Lockdatei bleiben **byteidentisch**. Bestehende Generatorprodukte werden weiter geprüft. Neue Dateien besitzen eigene Source-Metadaten:

| Datei unter tests/fixtures/legacy | Inhalt / gezählte Differentialfälle |
|---|---|
| engine_p01_p04.json | 54 RNG-/Shufflevectors,36 Eröffnungen,28 begin-Ressourcengrenzen,10 Halbzuggrenzen,56 reine Schadensfälle =184 |
| combat_p04_v1.json | 120 deterministisch erzeugte gemischte Felder, zwei Draw-Fälle, acht FIFO-/Reentranz-/100/101-Limitfälle =130 |
| turns_p03_v1.json | Zwei zusammenhängende Folgen mit insgesamt31 Übergängen und manueller Steuerung beider Seiten =2 |
| queue_winner_p04_v1.json | Zwei originale Queue-Ergebnisabbrüche nach passiver Beschwörung; nachfolgender Tod wird nicht mehr verarbeitet =2 |
| rng_consumption_v1.json |36 beobachtete RNG-Konsum-/End-/Folgezustände, innerhalb der36 Eröffnungsfälle geprüft, **nicht noch einmal als36 zusätzliche Fälle gezählt** |
| bestehendes transitions.json |52 vollständig ausgeführte Szenarien;72 explizit nicht unterstützt, nicht als bestandene Fälle gezählt |

Gesamt **370 Differentialfälle**:318 neue Fälle plus52 bestehende. Ein Fall kann mehrere Zustände und Assertions prüfen. Assertions sind keine unabhängigen Duelle. Für beide Seiten: Schutz, freie/belegte Pfade, Beschwörungszug, Eile/Stun, Vergeltung, Durchbruch, Tode/Ablage/harvest, Blockablauf, Caps und sofortige Ergebnisse. Alle Vergleiche behalten vollständige Zustände; keine weggefilterten fehlenden Spielressourcen.

RNG-Floatnachweis: Godots JSON-Dezimalparser rundet manche exakt binären JS-Brüche um eine ULP anders. Deshalb prüft Godot den tatsächlichen **Original-Uint32-Zustand /2^32**, nicht den erneut ungenau geparsten Dezimaltext. Node prüft zusätzlich jedes Original-Float gegen diesen Zustand und die fixierte Engine. Keine Epsilonaufweichung des Vergleichers, keine geänderten Originalgoldens.

Die zusätzlichen Generatoren erzeugen neue Dateien nur mit `--write-new`, solange die Datei nicht existiert; sonst harter Fehler. Normalaufruf ist bytegenauer Check. Änderungen an neuen Goldens erfordern ausdrücklich reviewte Versionierung/Erweiterung; kein automatisches Überschreiben. Testbeobachtung von Math.imul verändert weder die Referenzbytes noch den nativen Rückgabewert.

## Tatsächlich ausgeführte Prüfungen und Korrekturen

Umgebung: Node24.22.1, Godot4.6.3.stable.official.7d41c59c4, Linux/Xvfb/Mesa-Softwaretreiber. [Ergebnis-/Dateihashmanifest](p01-p04-evidence/results.json), [vollständige Fallklassifikation](p01-p04-evidence/engine-results.json), [Protokolle](p01-p04-evidence/), [geprüfte PR-/CI-Status](p01-p04-evidence/pr-status.json). Abschließende Log-Leerzeichen sind für Review normalisiert, Inhalte nicht gekürzt.

| Tatsächlicher Befehl | Resultat / Grenze |
|---|---|
| `tools/test_legacy.sh` | **Exit0;15 Node-Testgruppen**, davon8 bestehende und7 neue; **2171 bestehende +2099 neue Godot-Assertions,0 Fehler** |
| Darin `tests/legacy_engine.gd` | **370 Differentialfälle**,52 alte vollständig ausgeführt,72 ausdrücklich unsupported. Keine übersprungenen Fälle als Erfolge gezählt. |
| Alle fünf neuen `generate_*.cjs`-Checker | Byteidentische neue Goldens; wiederholte Erzeugung im Speicher identisch. `--write-new` gegen bestehende Dateien im Negativtest zuverlässig abgelehnt. |
| `generate.cjs --check --verify-checkout /workspace/duel-deck` | Pin/Checkout/SHA/Git-Blob und ursprüngliche sechs Generatorprodukte bestätigt |
| `DISPLAY=:99 bash tools/test.sh` | **Exit0;9547 Assertions,0 Fehler**, vollständige bestehende Regel-/Daten-/Erlebnis-/Eingabe-/Layout-/UX-/Präsentationssuite |
| Darin Audio/Kontrast |11 Originalcues bestanden;89 gerenderte Zustände/3837 Regionen,0 Kontrastfehler |
| Fixiertes JS `node test.js` | **Exit0;250 vollständige Partien mit250 Replayverifikationen**,45 Heldensiege/205 Gegnersiege, errors[] leer. Nur JS-interner Nachweis. |
| Fixiertes JS `node tests.js` | **Exit1**, erwartete START-Länge20 statt25; bestehender Upstreamfehler |
| Fixiertes JS `node ui-smoke.test.js` | **Exit1**, fehlendes document.body.classList im Mock; bestehender Upstreamfehler |
| Fixiertes JS `node check.js` | **Exit1**, `/mnt/data/nachtsiegel-kampf-2162621497.json` fehlt; bekannte externe Eingabeabhängigkeit |

Keine `SCRIPT ERROR`-/`ERROR:`-/`FAIL:`-Meldung im finalen Godot-Suitenlauf. Nicht erreichbarer ADB-Daemon/V-Sync-Warnung des Softwaretreibers sind Umgebungswarnungen, kein Mobilgerätetest. Die produktiven Godot-Tests vergleichen weiterhin den alten Godot-Oracle, während die neuen370 Fälle tatsächlich die fixierte JavaScript-Referenz verwenden.

### Gefundene Fehler und bewusste Vertragsunterschiede

- Erster Kernel-Testlauf:108 Fehlprüfungen. Neu eingefügte Godot-Snapshotschlüssel waren teilweise StringName statt JSON-Strings; zusätzlich die oben beschriebene JSON-Floatrundung, ein falscher Kontrollzustand im Test und eine alte raw-begin-Sonderlage. Zweiter Lauf reduzierte auf30 Schlüssel-/Typfehler; explizite Stringschlüssel auch für baseHp/baseAtk korrigiert. Danach gesamte Suite wiederholt grün.
- Erster neuer Node-Lauf: drei Testgruppen scheiterten an VM-Prototypen im noch nicht serialisierten Generatorergebnis, nicht an abweichenden JS-Spielwerten. Der Generator normalisiert seine Rückgabe über unverändertes JSON, genau wie die bestehende P01-Grenze; der strenge Vergleich bleibt unverändert. Eingecheckte Goldenbytes änderten sich dadurch nicht.
- Nach den Korrekturen wurden im unterstützten regulären Datenbereich keine verbleibenden RNG-/Zustandsabweichungen gefunden. Das ist **keine** Aussage über noch nicht implementierte Folgefälle.
- **Defensive Queue-Abweichung ausdrücklich:** Dieselbe physische Einheiten-Dictionaryreferenz wird nur einmal als Tod abgelegt. Die alte rohe enqueue-API kann künstlich doppelt injizierte Tode zweimal verarbeiten. Der verlangte Schutz ist hier bewusst strenger. Wertgleiche, aber unterschiedliche Kopien werden nicht verwechselt. Gleiches gilt für unbekannte/malformed Batches: Ablehnung vor Mutation statt beliebiger Raw-API-Nebenwirkung. In regulären Originalangriffen bleiben Queuezustände und FIFO-Reihenfolge identisch.
- **Guarded begin:** Raw JS `begin` lässt sich auch für die nicht aktive Seite aufrufen. Der neue Scheduler verweigert das. Ein entsprechendes altes Kontrollszenario ist deshalb explizit unsupported statt als Regelparität ausgegeben. Gewöhnliche aktive Phasengrenzen stimmen vollständig.
- Ereignislimit: JS wirft nach100 verarbeiteten Ereignissen eine Exception, Kernel liefert false mit `queue_error:event_limit`; beide behalten dieselben ersten100 Änderungen und räumen Queue/resolving auf. Das ist eine diagnostische APIabweichung, keine rückwirkende Halbmutation einer Spieleraktion.
- Ungültige argument types, nichtendlicher Schaden und nichtpositive Level sind außerhalb des unterstützten Eingabevertrags und ohne Zustandsänderung abgewiesen. Keine JavaScript-Coercion-Vollparität.
- Upstream-Testschuld bleibt getrennt: tests.js erwartet20 statt25 START-Karten; UI-smoke hat keinen vollständigen DOM-Mock; check.js benötigt eine nicht versionierte externe Aufzeichnung. Keine dieser roten Altprüfungen wird als neue Regression kaschiert oder „repariert“.

## Fortschrittsmatrix P01–P12

| Paket | Stand dieses Branches | Noch erforderlich |
|---|---|---|
| P01 | Referenz, Fixtures, Vergleich und neue Kernel-Differentialtests umgesetzt | Erweiterung mit jeder Folgefunktion; noch kein vollständiges Duell-/Replay-Paritätsclaim |
| P02 | a–d umgesetzt,100 Karten/fünf Decks unverändert | Keine Arena-/Exportaktivierung |
| P03 | a–d Kern implementiert und getestet, explizite before-AI-/P05-Grenzen | Vollständige alte Komfortwrapper erst mit P05/P10; kein uneingeschränkter Ganzpartie-Claim |
| P04 | Schaden/Bereitschaft/Pfadkampf/Todesqueue umgesetzt, reguläre Zustände differentialgrün | Zusätzliche Effektränder mit P06; defensive Raw-API-Abweichungen oben |
| P05 | Basisziehen und erfolgreicher Serienreset als P03-Abhängigkeit | Pflichtverbrennen, Erschöpfungsschaden, Kreislauf, Rückholung |
| P06 | Kampfpassives haste/retaliate/harvest als P04-Abhängigkeiten | Aktive Ankunftseffekte, Ziele/Shift, pierce-Ankunft und restlicher Dispatch |
| P07 | Resonanz-/Schildcaps und begin-Schwellen als notwendige Basis |12 Reaktionen, Manöver, Wacht, Entfesselungen und Bedienpfade |
| P08 | HP-/Draw- und beidseitige seals-Entscheidung im P04-Angriffsablauf | Komplettprüfung an künftig eingeführten Effekt-/Commandgrenzen |
| P09 | Nicht integriert | Arena-/Touch-/Zielwahl-/Ressourcenprojektion; derzeitige Arena unverändert |
| P10 | Explizit unsupported | Ressourcenbasierte originale KI, automatische Eröffnung und Folgezüge |
| P11 | Struktur-/Todeszustandsvergleich, eigene typed trace; kein kompatibles Replay | Vollständige Ereignisse, Commandwrapper, JSON/FNV-Hashes, Import/Export |
| P12 | Unverändert / nicht Bestandteil | Sammlung/Deckwerkstatt/Speicher-/Altstandmigration; keine Wirtschaftsimplementierung |

## Nächster sicherer Schritt P05–P08

1. P05a–d: bestehende Drawprimitive erweitern um Pflichtverbrennen, vollständiges finishDraw mit Erschöpfung und deterministischem Ablagekreislauf. Erst jede bisher als P05-unsupported geführte Originalfixture aktivieren, Grenzfälle ergänzen und alle370 Kernfälle unverändert bestehen lassen. Vorab prüfen, welche Raw-JS-Ablehnungen selbst mutieren; keine stillen Regelhärtungen.
2. P05e/P07a: Rückholung mit separatem Originalseed und einmaligem Flag; vorhandene Ressourcencaps weiterbenutzen. Noch keine KI erzwingen.
3. P06 in kleinen originalen Effektpaketen: jeweils Admissionguard erst entfernen, wenn vollständige Wirkung/Ziele/Queue/Negativtests gegen dieselbe Quelle bestehen. Kein stummes Ausspielen als Vanilla. Für pierce-Ankunft Schutzignorierung explizit anders als Angriffsüberlauf testen.
4. P07-Reaktionen/aktive Aktionen und P08-Ergebniskontrolle an allen neuen Mutationsgrenzen; source-winner kann einen folgenden Beschwörungseffekt unterdrücken. Erst danach P10-Automatik und P11-Replay; bestehende Godot-Regressionen parallel erhalten.

## Reproduktion und Grenzen

```bash
# Node24, Godot4.6.3, Linux/Coreutils timeout; offline nach Checkout:
tools/test_legacy.sh
# Die zusätzliche Fixtureprüfung schreibt nichts:
node tools/legacy/generate_engine.cjs
node tools/legacy/generate_combat.cjs
node tools/legacy/generate_turns.cjs
node tools/legacy/generate_rng_consumption.cjs
node tools/legacy/generate_queue_winner.cjs
# Optional tatsächlichen Legacy-Checkout prüfen:
node tools/legacy/generate.cjs --check --verify-checkout /path/to/duel-deck
# Vorhandene vollständige Desktop-Regressionssuite, z.B. Xvfb:
DISPLAY=:99 tools/test.sh
```

Kein neuer Web-/Android-/iOS-Export oder physischer Gerätetest in diesem Auftrag, keine Behauptung PCK-Verfügbarkeit der isolierten Legacy-JSON-Daten. Desktop-/Headless-/Xvfb-Tests sind keine Gerätetests. Keine Änderung/Veröffentlichung der Live-Version. Der dedizierte Legacy-CI-Workflow ist für den gestapelten Basisbranch ergänzt, hat keine Deployrechte und verändert nicht den Pages-Workflow.
