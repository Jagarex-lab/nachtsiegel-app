# Legacy Functional Parity Audit

Stand: 2026-11-09. **Reine Bestandsaufnahme; keine Gameplay-, Werte-, Marken-, Lore-, Design- oder Assetänderung.** Getestet und untersucht auf `audit/legacy-functional-parity`, abgezweigt von `origin/develop`.

## 1. Ergebnis und Vergleichsgrundlage

**Das Godot-Spiel ist ein eigenständiger spielbarer Prototyp, kein nachgewiesen vollständiger Port der JavaScript-Regeln.** Sein vorhandener Regressionstest schützt die bisherigen Godot-Regeln. Er verwendet keinen JavaScript-Oracle.

| Quelle | Branch zum Abruf | Unveränderlicher untersuchter Commit |
|---|---|---|
| [duel-deck](https://github.com/Jagarex-lab/duel-deck) | main | `34b3062c3f22c0950d9323ad9b97b17c41d1d14f` |
| [nachtsiegel-app](https://github.com/Jagarex-lab/nachtsiegel-app) | develop | `b1f5ea59a4754bac19df31e279bff8a295cb6ea8` |

Die unten verlinkten Quellen sind auf diese Commits fixiert. Zeilennummern beziehen sich auf den untersuchten Stand, nicht auf künftige Implementierungen. `engine.js` und `game.js` sind stark verdichtet: Eine Zeile kann eine ganze Funktion enthalten.

### Zählweise

- **Vollständig:** Der ausdrücklich abgegrenzte Vertrag stimmt in beiden Implementierungen überein; geeigneter vorhandener Test oder kontrollierter Angriffsteilfall stützt ihn. Keine Aussage über darüber hinausgehende Effekte.
- **Teilweise:** Ein wesentlicher Teil existiert, aber notwendige Regeln, Seiten oder Daten fehlen.
- **Fehlend:** Kein entsprechender ausführbarer Vertrag / keine entsprechende Karte im Godot-Kampfmodell.
- **Abweichend:** Es existiert eine ersetzende, widersprechende Umsetzung oder ein namensgleiches Kartenobjekt mit anderen Werten. Dies ist keine bestätigte Identitätszuordnung.

Karten: **0 vollständig, 0 teilweise, 98 fehlend, 2 abweichend** (insgesamt 100 Legacy-Karten). Streng nach stabiler JS-ID sind **0/100** implementiert: Das Godot-Kampfmodell verwendet Poolindizes statt JS-IDs. Die beiden abweichenden Zeilen sind ausschließlich die belegbaren Namenskollisionen Nebelqualle/Schattenwolf. Ohne Freigabe oder historische Mappingdatei werden sie nicht als tatsächlicher Port dieser IDs ausgegeben. Ähnliche Namen wie Glutwächter/Aschenwache begründen keine Zuordnung.

Mechaniken: **6 vollständig, 12 teilweise, 43 fehlend, 9 abweichend** (70 Anforderungen).

Die Mechanikzahlen zählen die 70 expliziten Anforderungen in Abschnitt 5 gleichgewichtet; sie sind weder Fortschrittsprozent noch Aufwandsschätzung. Die 16 Fähigkeiten sind je ein eigener Vertrag. Schutz, Queue, Daten und UI werden zusätzlich als eigenständige Integrationsverträge erfasst. [Maschinenlesbare Zählgrundlage](evidence/mechanic_inventory.json).

### Besonders dringende Befunde

1. **P0 – Beweisgrundlage:** [reference_rules.gd][R2] bezeichnet sich selbst als eingefrorener Godot-Stand `0e15ac4`. [legacy_card_pool.json][Fixture] enthält exakt die sieben Godot-Prototypkarten. Die 684 Assertions / 30 Duelle testen diesen Godot-gegen-Godot-Vertrag, keine Übernahme von `duel-deck`.
2. **P0 – Regelabweichung:** Godot greift den Helden bei leerem Gegenfeld korrekt an, verarbeitet aber keinen Block/Schild. Beschwörungsverzögerung, 16 Karteneffekte und Resonanz fehlen. Die KI erzeugt Einheiten ohne eigene Hand, Deck oder Energiekosten.
3. **P0 – Daten:** Legacy hat 100 Kreaturen und keine eigenständigen Zauber. Godot hat sechs fähigkeitslose Kreaturen und einen zusätzlichen Zauber; selbst die beiden gleichen Namen haben andere Werte/Effekte.
4. **P1 – Reproduzierbarkeit:** Es gibt keinen kompatiblen Godot-Kampfexport/Replay-Import. Präsentationsframes sind kein vollständiges Befehls- und Zustandsprotokoll.
5. **P1 – Altbestand selbst prüfen:** Zwei vorhandene JS-Testdateien scheitern am heutigen main-Stand; ein Prüfskript verlangt eine nicht mitgelieferte externe Datei. Das wird hier weder repariert noch als Portierungsfehler ausgegeben.

## 2. Tatsächlicher Bestand, Fixtures und Absicht

| Ebene | Beleg | Aussage / Grenze |
|---|---|---|
| Ausführbare JS-Regeln | [engine.js][J], [game.js][U], [index.html][Index] lädt diese Dateien | Aktive Referenz. `CARDS` wird deterministisch aus 4×25 Namen, Effektfolge und Formeln erzeugt, nicht aus den Godot-Fixtures. Sämtliche 100 generierten Definitionen inkl. Originalbeschreibung stehen im [Auditexport](evidence/legacy_export.json). |
| Historisches ZIP im JS-Repo | `nachtsiegel-v25.zip`, `NACHTSIEGEL_v25/engine.js` | Archiv untersucht: Engine byteidentisch zur Root-Engine; SHA-256 für beide `abf880e049080a7ec39a43fefa805ba9e8de18f7638633bef6d7096dc5a78dd1`. Kein zweiter unabhängiger aktiver Kartenkatalog. |
| Ausführbare Godot-Regeln | [battle_model.gd][G], [card_definitions.gd][C] | Tatsächlich verwendeter Pool mit sieben Einträgen. Keine Effekt-, Resonanz-, Block-, Schild- oder Ablagefelder. |
| Arena / Präsentation | [arena.gd][A861], [A935] | Delegiert Spielzüge an `battle.play()` / `battle.resolve_turn()`, visualisiert danach Frames. UI-Effektfamilien führen keine Legacy-Kartenfähigkeiten aus. `phase`/`busy` sind Präsentations- und Eingabezustände, kein vollständiger Legacy-Phasenscheduler. |
| Godot-Testoracle | [reference_rules.gd][R2] | Alter Godot-Prototyp; trotz Begriff „oracle“ kein JS-Referenzmodell. |
| Godot-Testfixture | [legacy_card_pool.json][Fixture] | Sieben Prototypkarten, kein Export der 100 Legacy-Karten. Kommentar „unchanged legacy values“ in [C] ist nur innerhalb der Godot-Historie plausibel, keine Übereinstimmung mit JS main. |
| Narrative Daten / Sammlung | [content.json][N], [front_end.gd][F202] | 7 Einträge mit `legacy_pool_index`, 13 `concept_only`; narrative IDs ersetzen keine `ash-0` usw. Sammlung kennzeichnet Konzepte tatsächlich als nicht spielbar. Kein Konzept als implementierte Fähigkeit gezählt. |
| Neue Kampagne / Speicherung | [chapters.json][Campaign], [progress_store.gd][S12] | Neue fünf Kapitel, Profile, Heldenauswahl und lokaler Fortschritt sind vorhanden. `ruleset: existing_duel` meint aktuellen Godot-Vertrag, keinen belegten Legacy-Port. |
| Dokumentierte Absicht | README, `docs/creative/01-existing-audit.md`, `06-integration-and-qa.md` | Dokumentieren den Godot-Ausgangsstand; Aussagen über „bestehende Regeln“ nicht rückwirkend als JS-Parität lesen. Lore ist kein Regelcode. |
| Nachgewiesene Funktion | Abschnitt 7, mitgelieferte Rohprotokolle | Explizite Trennung zwischen statischer Prüfung (S), tatsächlich ausgeführten Tests (T), innerhalb einer Engine und engineübergreifenden kontrollierten Teilfällen. |

Die tatsächlichen JS-Orden heißen **Aschenpakt / Gezeitenorden / Dornenzirkel / Nachtkonklave** [J4]. **Aschensturm / Gezeitenwall / Dornenwacht / Nachtgewebe** sind die vier gemischten Standarddecks [J13]–[J16]. Daraus werden hier keine vier exklusiven Fraktionsregelwerke erfunden.

## 3. Vollständige Kartenmatrix

Quelle aller Legacy-Werte: tatsächlich ausgeführtes `E.CARDS` aus [J8], unverändert exportiert durch [export_legacy.cjs](evidence/export_legacy.cjs). `creature` entspricht semantisch Godots `unit`; die unterschiedliche Schreibweise allein ist kein Defekt. `A/HP` sind Basiswerte; `P` ist Effektstärke. Keine Karte hat einen selbstständigen Zaubertyp. Tabellen sind nach Regel-order gegliedert; ID und order bleiben Originalwerte. Für jede Zeile gelten zusätzlich die allgemeinen Beschwörungsziele: eigener freier Pfad, bezahlbare Kosten, aktive main-Phase, max. zwei Rufe, keine offene Zielwahl [J74].

**Trigger-/Zielkürzel:** B = Beschwörung; T = eigener Tod; A = eigene Angriffsphase; V = Verteidigung gegen positiven Kreaturentreffer, nur wenn überlebt. „Eigen“ ist stets die ausspielende Seite, „Gegner“ ihre Gegenseite, also auch für KI identisch. Effekte und Sonderfälle sind in Abschnitt 4 vollständig erklärt. Die Originalbeschreibungen im Export sind nicht automatisch eine präzise Beschreibung sämtlicher Laufzeitdetails.

### ash

| ID | Name | Typ | Kosten | A/HP | P | Seltenheit | Effekt | Trigger | Effektziel | Godot-Gegenstück / Status |
|---|---|---|---:|---|---:|---|---|---|---|---|
| `ash-0` | Glutwächter | creature | 2 | 1/4 | 2 | common | `strike` | B | beliebige Gegnerkreatur; sonst Gegnerheld | **fehlend** — kein belegter Laufzeiteintrag |
| `ash-1` | Knochensänger | creature | 1 | 1/4 | 1 | common | `mend` | B | eigener Held: HP | **fehlend** — kein belegter Laufzeiteintrag |
| `ash-2` | Rotbrand-Bestie | creature | 1 | 2/2 | 1 | common | `rally` | B | eigener linker, sonst rechter Nachbar | **fehlend** — kein belegter Laufzeiteintrag |
| `ash-3` | Schmiedegolem | creature | 1 | 1/4 | 1 | common | `shift` | B; Formation nach Bewegung | eigene Nachbarkreatur → beliebiger freier eigener Pfad | **fehlend** — kein belegter Laufzeiteintrag |
| `ash-4` | Schwurträger | creature | 1 | 1/2 | 1 | common | `draw` | B | eigener Deckanfang → Hand | **fehlend** — kein belegter Laufzeiteintrag |
| `ash-5` | Aschenrichter | creature | 2 | 3/6 | 2 | common | `weave` | B | eigene Resonanz | **fehlend** — kein belegter Laufzeiteintrag |
| `ash-6` | Sonnenfalke | creature | 1 | 1/2 | 1 | common | `ward` | B | eigener Held: Schild | **fehlend** — kein belegter Laufzeiteintrag |
| `ash-7` | Scherbenwolf | creature | 1 | 1/4 | 1 | common | `drain` | B | Gegnerheld → eigene HP | **fehlend** — kein belegter Laufzeiteintrag |
| `ash-8` | Vulkanriese | creature | 1 | 2/2 | 1 | common | `pierce` | B + A bei tödlichem Treffer | Gegnerheld; A: Überlauf nach Kreatur | **fehlend** — kein belegter Laufzeiteintrag |
| `ash-9` | Essegeist | creature | 1 | 1/4 | 1 | common | `retaliate` | V | angreifende Gegnerkreatur | **fehlend** — kein belegter Laufzeiteintrag |
| `ash-10` | Blutkomet | creature | 2 | 2/4 | 2 | common | `weaken` | B; Verbrauch bei Gegner-A | alle Kreaturenangriffe der nächsten Gegnerphase | **fehlend** — kein belegter Laufzeiteintrag |
| `ash-11` | Funkenkobold | creature | 2 | 3/6 | 2 | rare | `guard` | B | eigener Held: Block | **fehlend** — kein belegter Laufzeiteintrag |
| `ash-12` | Feuerkönig | creature | 2 | 1/4 | 2 | rare | `weave` | B | eigene Resonanz | **fehlend** — kein belegter Laufzeiteintrag |
| `ash-13` | Rotgold-Ritter | creature | 2 | 2/6 | 2 | rare | `silence` | B | gegenüberliegende Gegnerkreatur | **fehlend** — kein belegter Laufzeiteintrag |
| `ash-14` | Schlackentänzer | creature | 2 | 3/4 | 2 | rare | `harvest` | T | eigene Resonanz | **fehlend** — kein belegter Laufzeiteintrag |
| `ash-15` | Rissjäger | creature | 2 | 1/6 | 2 | rare | `haste` | A im Beschwörungszug | gegenüberliegende Kreatur; sonst Held | **fehlend** — kein belegter Laufzeiteintrag |
| `ash-16` | Aschenhirsch | creature | 2 | 2/4 | 2 | rare | `strike` | B | beliebige Gegnerkreatur; sonst Gegnerheld | **fehlend** — kein belegter Laufzeiteintrag |
| `ash-17` | Kohlenorakel | creature | 2 | 3/6 | 2 | rare | `mend` | B | eigener Held: HP | **fehlend** — kein belegter Laufzeiteintrag |
| `ash-18` | Zunderkrähe | creature | 2 | 1/4 | 2 | rare | `rally` | B | eigener linker, sonst rechter Nachbar | **fehlend** — kein belegter Laufzeiteintrag |
| `ash-19` | Brandläufer | creature | 3 | 3/8 | 3 | epic | `shift` | B; Formation nach Bewegung | eigene Nachbarkreatur → beliebiger freier eigener Pfad | **fehlend** — kein belegter Laufzeiteintrag |
| `ash-20` | Lavakriecher | creature | 3 | 4/6 | 3 | epic | `draw` | B | eigener Deckanfang → Hand | **fehlend** — kein belegter Laufzeiteintrag |
| `ash-21` | Feuerschlund | creature | 3 | 2/8 | 3 | epic | `weave` | B | eigene Resonanz | **fehlend** — kein belegter Laufzeiteintrag |
| `ash-22` | Glutfalter | creature | 3 | 3/6 | 3 | epic | `ward` | B | eigener Held: Schild | **fehlend** — kein belegter Laufzeiteintrag |
| `ash-23` | Rußdrache | creature | 3 | 4/8 | 3 | epic | `drain` | B | Gegnerheld → eigene HP | **fehlend** — kein belegter Laufzeiteintrag |
| `ash-24` | Klingenphönix | creature | 5 | 5/11 | 4 | legendary | `pulse` | B | eigene Resonanz/Schild + beide eigenen Nachbarn | **fehlend** — kein belegter Laufzeiteintrag |
### tide

| ID | Name | Typ | Kosten | A/HP | P | Seltenheit | Effekt | Trigger | Effektziel | Godot-Gegenstück / Status |
|---|---|---|---:|---|---:|---|---|---|---|---|
| `tide-0` | Gezeitenpilger | creature | 2 | 2/5 | 2 | common | `weave` | B | eigene Resonanz | **fehlend** — kein belegter Laufzeiteintrag |
| `tide-1` | Spiegelkrabbe | creature | 1 | 2/5 | 1 | common | `silence` | B | gegenüberliegende Gegnerkreatur | **fehlend** — kein belegter Laufzeiteintrag |
| `tide-2` | Tiefenwächter | creature | 1 | 1/3 | 1 | common | `harvest` | T | eigene Resonanz | **fehlend** — kein belegter Laufzeiteintrag |
| `tide-3` | Flutrochen | creature | 1 | 1/5 | 1 | common | `haste` | A im Beschwörungszug | gegenüberliegende Kreatur; sonst Held | **fehlend** — kein belegter Laufzeiteintrag |
| `tide-4` | Salzpriesterin | creature | 1 | 2/3 | 1 | common | `strike` | B | beliebige Gegnerkreatur; sonst Gegnerheld | **fehlend** — kein belegter Laufzeiteintrag |
| `tide-5` | Perlentaucher | creature | 2 | 1/7 | 2 | common | `mend` | B | eigener Held: HP | **fehlend** — kein belegter Laufzeiteintrag |
| `tide-6` | Sternenwal | creature | 1 | 1/3 | 1 | common | `rally` | B | eigener linker, sonst rechter Nachbar | **fehlend** — kein belegter Laufzeiteintrag |
| `tide-7` | Klangmuschel | creature | 1 | 2/5 | 1 | common | `shift` | B; Formation nach Bewegung | eigene Nachbarkreatur → beliebiger freier eigener Pfad | **fehlend** — kein belegter Laufzeiteintrag |
| `tide-8` | Saphirkrake | creature | 1 | 1/3 | 1 | common | `draw` | B | eigener Deckanfang → Hand | **fehlend** — kein belegter Laufzeiteintrag |
| `tide-9` | Stromnymphe | creature | 1 | 1/5 | 1 | common | `weave` | B | eigene Resonanz | **fehlend** — kein belegter Laufzeiteintrag |
| `tide-10` | Mondsalz-Geist | creature | 2 | 3/5 | 2 | common | `ward` | B | eigener Held: Schild | **fehlend** — kein belegter Laufzeiteintrag |
| `tide-11` | Namenloses Schiff | creature | 2 | 1/7 | 2 | rare | `drain` | B | Gegnerheld → eigene HP | **fehlend** — kein belegter Laufzeiteintrag |
| `tide-12` | Nebelqualle | creature | 2 | 2/5 | 2 | rare | `pierce` | B + A bei tödlichem Treffer | Gegnerheld; A: Überlauf nach Kreatur | **abweichend** — nur Name: Pool 2, 2 / 1 / 5, kein pierce |
| `tide-13` | Flutprophet | creature | 2 | 3/7 | 2 | rare | `retaliate` | V | angreifende Gegnerkreatur | **fehlend** — kein belegter Laufzeiteintrag |
| `tide-14` | Riffschatten | creature | 2 | 1/5 | 2 | rare | `weaken` | B; Verbrauch bei Gegner-A | alle Kreaturenangriffe der nächsten Gegnerphase | **fehlend** — kein belegter Laufzeiteintrag |
| `tide-15` | Stillwasser-Ritter | creature | 2 | 2/7 | 2 | rare | `guard` | B | eigener Held: Block | **fehlend** — kein belegter Laufzeiteintrag |
| `tide-16` | Meeressiegelträger | creature | 2 | 3/5 | 2 | rare | `weave` | B | eigene Resonanz | **fehlend** — kein belegter Laufzeiteintrag |
| `tide-17` | Tränenkompass | creature | 2 | 1/7 | 2 | rare | `silence` | B | gegenüberliegende Gegnerkreatur | **fehlend** — kein belegter Laufzeiteintrag |
| `tide-18` | Wellenhexe | creature | 2 | 2/5 | 2 | rare | `harvest` | T | eigene Resonanz | **fehlend** — kein belegter Laufzeiteintrag |
| `tide-19` | Eiskoralle | creature | 3 | 4/9 | 3 | epic | `haste` | A im Beschwörungszug | gegenüberliegende Kreatur; sonst Held | **fehlend** — kein belegter Laufzeiteintrag |
| `tide-20` | Flusswyrm | creature | 3 | 2/7 | 3 | epic | `strike` | B | beliebige Gegnerkreatur; sonst Gegnerheld | **fehlend** — kein belegter Laufzeiteintrag |
| `tide-21` | Kaltflossenjäger | creature | 3 | 3/9 | 3 | epic | `mend` | B | eigener Held: HP | **fehlend** — kein belegter Laufzeiteintrag |
| `tide-22` | Seelentaucher | creature | 3 | 4/7 | 3 | epic | `rally` | B | eigener linker, sonst rechter Nachbar | **fehlend** — kein belegter Laufzeiteintrag |
| `tide-23` | Abgrundsänger | creature | 3 | 2/9 | 3 | epic | `shift` | B; Formation nach Bewegung | eigene Nachbarkreatur → beliebiger freier eigener Pfad | **fehlend** — kein belegter Laufzeiteintrag |
| `tide-24` | Leviathan | creature | 5 | 5/11 | 4 | legendary | `pulse` | B | eigene Resonanz/Schild + beide eigenen Nachbarn | **fehlend** — kein belegter Laufzeiteintrag |
### thorn

| ID | Name | Typ | Kosten | A/HP | P | Seltenheit | Effekt | Trigger | Effektziel | Godot-Gegenstück / Status |
|---|---|---|---:|---|---:|---|---|---|---|---|
| `thorn-0` | Wurzelhüter | creature | 2 | 3/6 | 2 | common | `pierce` | B + A bei tödlichem Treffer | Gegnerheld; A: Überlauf nach Kreatur | **fehlend** — kein belegter Laufzeiteintrag |
| `thorn-1` | Dornenfüchsin | creature | 1 | 1/2 | 1 | common | `retaliate` | V | angreifende Gegnerkreatur | **fehlend** — kein belegter Laufzeiteintrag |
| `thorn-2` | Hirschmond | creature | 1 | 1/4 | 1 | common | `weaken` | B; Verbrauch bei Gegner-A | alle Kreaturenangriffe der nächsten Gegnerphase | **fehlend** — kein belegter Laufzeiteintrag |
| `thorn-3` | Waldgericht | creature | 1 | 2/2 | 1 | common | `guard` | B | eigener Held: Block | **fehlend** — kein belegter Laufzeiteintrag |
| `thorn-4` | Borkenriese | creature | 1 | 1/4 | 1 | common | `weave` | B | eigene Resonanz | **fehlend** — kein belegter Laufzeiteintrag |
| `thorn-5` | Sporenläufer | creature | 2 | 2/4 | 2 | common | `silence` | B | gegenüberliegende Gegnerkreatur | **fehlend** — kein belegter Laufzeiteintrag |
| `thorn-6` | Eibenrufer | creature | 1 | 2/4 | 1 | common | `harvest` | T | eigene Resonanz | **fehlend** — kein belegter Laufzeiteintrag |
| `thorn-7` | Schwurhirsch | creature | 1 | 1/2 | 1 | common | `haste` | A im Beschwörungszug | gegenüberliegende Kreatur; sonst Held | **fehlend** — kein belegter Laufzeiteintrag |
| `thorn-8` | Lichtungsherz | creature | 1 | 1/4 | 1 | common | `strike` | B | beliebige Gegnerkreatur; sonst Gegnerheld | **fehlend** — kein belegter Laufzeiteintrag |
| `thorn-9` | Morgenranke | creature | 1 | 2/2 | 1 | common | `mend` | B | eigener Held: HP | **fehlend** — kein belegter Laufzeiteintrag |
| `thorn-10` | Farnschatten | creature | 2 | 1/6 | 2 | common | `rally` | B | eigener linker, sonst rechter Nachbar | **fehlend** — kein belegter Laufzeiteintrag |
| `thorn-11` | Dornenspiegel | creature | 2 | 2/4 | 2 | rare | `shift` | B; Formation nach Bewegung | eigene Nachbarkreatur → beliebiger freier eigener Pfad | **fehlend** — kein belegter Laufzeiteintrag |
| `thorn-12` | Urwaldkönig | creature | 2 | 3/6 | 2 | rare | `draw` | B | eigener Deckanfang → Hand | **fehlend** — kein belegter Laufzeiteintrag |
| `thorn-13` | Samenorakel | creature | 2 | 1/4 | 2 | rare | `weave` | B | eigene Resonanz | **fehlend** — kein belegter Laufzeiteintrag |
| `thorn-14` | Wilder Hauer | creature | 2 | 2/6 | 2 | rare | `ward` | B | eigener Held: Schild | **fehlend** — kein belegter Laufzeiteintrag |
| `thorn-15` | Bernsteinwache | creature | 2 | 3/4 | 2 | rare | `drain` | B | Gegnerheld → eigene HP | **fehlend** — kein belegter Laufzeiteintrag |
| `thorn-16` | Blattflüsterin | creature | 2 | 1/6 | 2 | rare | `pierce` | B + A bei tödlichem Treffer | Gegnerheld; A: Überlauf nach Kreatur | **fehlend** — kein belegter Laufzeiteintrag |
| `thorn-17` | Moosrufer | creature | 2 | 2/4 | 2 | rare | `retaliate` | V | angreifende Gegnerkreatur | **fehlend** — kein belegter Laufzeiteintrag |
| `thorn-18` | Wurzelmaul | creature | 2 | 3/6 | 2 | rare | `weaken` | B; Verbrauch bei Gegner-A | alle Kreaturenangriffe der nächsten Gegnerphase | **fehlend** — kein belegter Laufzeiteintrag |
| `thorn-19` | Blütenwespe | creature | 3 | 2/6 | 3 | epic | `guard` | B | eigener Held: Block | **fehlend** — kein belegter Laufzeiteintrag |
| `thorn-20` | Rindenhüter | creature | 3 | 3/8 | 3 | epic | `weave` | B | eigene Resonanz | **fehlend** — kein belegter Laufzeiteintrag |
| `thorn-21` | Pilzhexer | creature | 3 | 4/6 | 3 | epic | `silence` | B | gegenüberliegende Gegnerkreatur | **fehlend** — kein belegter Laufzeiteintrag |
| `thorn-22` | Waldschlange | creature | 3 | 2/8 | 3 | epic | `harvest` | T | eigene Resonanz | **fehlend** — kein belegter Laufzeiteintrag |
| `thorn-23` | Dornenmutter | creature | 3 | 3/6 | 3 | epic | `haste` | A im Beschwörungszug | gegenüberliegende Kreatur; sonst Held | **fehlend** — kein belegter Laufzeiteintrag |
| `thorn-24` | Uralter Titan | creature | 5 | 5/11 | 4 | legendary | `pulse` | B | eigene Resonanz/Schild + beide eigenen Nachbarn | **fehlend** — kein belegter Laufzeiteintrag |
### veil

| ID | Name | Typ | Kosten | A/HP | P | Seltenheit | Effekt | Trigger | Effektziel | Godot-Gegenstück / Status |
|---|---|---|---:|---|---:|---|---|---|---|---|
| `veil-0` | Nachtweber | creature | 2 | 1/7 | 2 | common | `draw` | B | eigener Deckanfang → Hand | **fehlend** — kein belegter Laufzeiteintrag |
| `veil-1` | Litanei-Geist | creature | 1 | 1/3 | 1 | common | `weave` | B | eigene Resonanz | **fehlend** — kein belegter Laufzeiteintrag |
| `veil-2` | Maskendieb | creature | 1 | 2/5 | 1 | common | `ward` | B | eigener Held: Schild | **fehlend** — kein belegter Laufzeiteintrag |
| `veil-3` | Traumfresser | creature | 1 | 1/3 | 1 | common | `drain` | B | Gegnerheld → eigene HP | **fehlend** — kein belegter Laufzeiteintrag |
| `veil-4` | Schattenwächter | creature | 1 | 1/5 | 1 | common | `pierce` | B + A bei tödlichem Treffer | Gegnerheld; A: Überlauf nach Kreatur | **fehlend** — kein belegter Laufzeiteintrag |
| `veil-5` | Leerenmönch | creature | 2 | 3/5 | 2 | common | `retaliate` | V | angreifende Gegnerkreatur | **fehlend** — kein belegter Laufzeiteintrag |
| `veil-6` | Krähenrichter | creature | 1 | 1/5 | 1 | common | `weaken` | B; Verbrauch bei Gegner-A | alle Kreaturenangriffe der nächsten Gegnerphase | **fehlend** — kein belegter Laufzeiteintrag |
| `veil-7` | Morgentrug | creature | 1 | 1/3 | 1 | common | `guard` | B | eigener Held: Block | **fehlend** — kein belegter Laufzeiteintrag |
| `veil-8` | Echoschreiter | creature | 1 | 2/5 | 1 | common | `weave` | B | eigene Resonanz | **fehlend** — kein belegter Laufzeiteintrag |
| `veil-9` | Seelenfenster | creature | 1 | 1/3 | 1 | common | `silence` | B | gegenüberliegende Gegnerkreatur | **fehlend** — kein belegter Laufzeiteintrag |
| `veil-10` | Purpurgeist | creature | 2 | 2/7 | 2 | common | `harvest` | T | eigene Resonanz | **fehlend** — kein belegter Laufzeiteintrag |
| `veil-11` | Der Namenlose | creature | 2 | 3/5 | 2 | rare | `haste` | A im Beschwörungszug | gegenüberliegende Kreatur; sonst Held | **fehlend** — kein belegter Laufzeiteintrag |
| `veil-12` | Dunkelspiegel | creature | 2 | 1/7 | 2 | rare | `strike` | B | beliebige Gegnerkreatur; sonst Gegnerheld | **fehlend** — kein belegter Laufzeiteintrag |
| `veil-13` | Sternenlose | creature | 2 | 2/5 | 2 | rare | `mend` | B | eigener Held: HP | **fehlend** — kein belegter Laufzeiteintrag |
| `veil-14` | Mitternachtsrose | creature | 2 | 3/7 | 2 | rare | `rally` | B | eigener linker, sonst rechter Nachbar | **fehlend** — kein belegter Laufzeiteintrag |
| `veil-15` | Vergessenswurm | creature | 2 | 1/5 | 2 | rare | `shift` | B; Formation nach Bewegung | eigene Nachbarkreatur → beliebiger freier eigener Pfad | **fehlend** — kein belegter Laufzeiteintrag |
| `veil-16` | Wisperklinge | creature | 2 | 2/7 | 2 | rare | `draw` | B | eigener Deckanfang → Hand | **fehlend** — kein belegter Laufzeiteintrag |
| `veil-17` | Mondschleier | creature | 2 | 3/5 | 2 | rare | `weave` | B | eigene Resonanz | **fehlend** — kein belegter Laufzeiteintrag |
| `veil-18` | Schattenwolf | creature | 2 | 1/7 | 2 | rare | `ward` | B | eigener Held: Schild | **abweichend** — nur Name: Pool 3, 3 / 3 / 4, kein ward |
| `veil-19` | Leerenkrähe | creature | 3 | 3/7 | 3 | epic | `drain` | B | Gegnerheld → eigene HP | **fehlend** — kein belegter Laufzeiteintrag |
| `veil-20` | Finsterritter | creature | 3 | 4/9 | 3 | epic | `pierce` | B + A bei tödlichem Treffer | Gegnerheld; A: Überlauf nach Kreatur | **fehlend** — kein belegter Laufzeiteintrag |
| `veil-21` | Spiegelhexe | creature | 3 | 2/7 | 3 | epic | `retaliate` | V | angreifende Gegnerkreatur | **fehlend** — kein belegter Laufzeiteintrag |
| `veil-22` | Nachtmahr | creature | 3 | 3/9 | 3 | epic | `weaken` | B; Verbrauch bei Gegner-A | alle Kreaturenangriffe der nächsten Gegnerphase | **fehlend** — kein belegter Laufzeiteintrag |
| `veil-23` | Seelenbinder | creature | 3 | 4/7 | 3 | epic | `guard` | B | eigener Held: Block | **fehlend** — kein belegter Laufzeiteintrag |
| `veil-24` | Der letzte König | creature | 5 | 5/11 | 4 | legendary | `pulse` | B | eigene Resonanz/Schild + beide eigenen Nachbarn | **fehlend** — kein belegter Laufzeiteintrag |

### Godot-Pool separat: keine erfundene Legacy-Zuordnung

Quelle [C], Laufzeit [G35]. Alle sieben liegen auch in [Fixture]. Die fünf ohne Namensgleichheit sind **Godot-Zusätze**, keine als „fehlend“ gezählten Legacy-Karten.

| Index | Name | Typ | Kosten / A / HP | Fähigkeit / Ziel | Legacy-Befund |
|---:|---|---|---|---|---|
| 0 | Aschenwache | unit | 2 / 2 / 4 | keine; eigener freier Pfad | Kein gleicher Name oder JS-ID-Mapping |
| 1 | Dornenwolf | unit | 2 / 3 / 2 | keine; eigener freier Pfad | Kein gleicher Name oder JS-ID-Mapping |
| 2 | Nebelqualle | unit | 2 / 1 / 5 | keine; eigener freier Pfad | JS `tide-12`: Kosten 2, A 2, HP 5, power 2, pierce; nur Namen gleich |
| 3 | Schattenwolf | unit | 3 / 3 / 4 | keine; eigener freier Pfad | JS `veil-18`: Kosten 2, A 1, HP 7, power 2, ward; nur Namen gleich |
| 4 | Glutritter | unit | 4 / 4 / 5 | keine; eigener freier Pfad | Kein gleicher Name oder JS-ID-Mapping |
| 5 | Gezeitenhüter | unit | 3 / 2 / 6 | keine; eigener freier Pfad | Kein gleicher Name oder JS-ID-Mapping |
| 6 | Funkenstoß | spell | 2 / 3 / 0 | Ausspielen: 3 Schaden auf belegtes Gegnerfeld; kein Held; kein Beschwörungslimitverbrauch | Keine Zauberkarten in JS; insbesondere kein Ersatz für strike |

## 4. Effekte, Trigger und tatsächliche Zielregeln

Hier bezeichnet `p` den jeweiligen `power`-Wert der Kartenmatrix. Alle 16 Effektverträge fehlen im Godot-Pool/-Dispatch; eine ähnlich aussehende Animation oder der unabhängige Zauber gilt nicht als Umsetzung. S = Quellennachweis; die 100 Ankunftssonden prüfen nur Ausspielbarkeit ohne Absturz, nicht diese Einzelwirkungen.

| Effekt | Trigger und Laufzeitwirkung | Wichtige Einschränkungen / Quellennachweis |
|---|---|---|
| strike | B: p+1 Schaden; wenn irgendeine Gegnerkreatur existiert, wählt Spieler eine beliebige davon, nicht zwingend die gegenüberliegende. | Pending-Auswahl blockiert weitere play/endTurn. KI nimmt niedrigste aktuelle HP, erstes Ziel bei Gleichstand. Ohne jede Gegnerkreatur Helden-Fallback durch Block/Schild. Kreaturentreffer ignoriert Heldenprotektion. [J40], [J55], [J56] |
| guard | B: eigener Held erhält p+2 Block. | Additiv, kein expliziter Blockdeckel; gesamter Restblock verfällt am nächsten eigenen begin. [J41], [J68] |
| ward | B: eigener Held erhält p+1 Schild. | Gesamtwert cap 25, bleibt bis Verbrauch bestehen. [J42], [J71] |
| mend | B: eigener Held heilt p+2 HP. | cap maxHp; keine Kreaturenheilung. [J43] |
| weave | B: +p+1 eigene Resonanz. | cap 15. [J44], [J72] |
| drain | B: p+1 Schaden an Gegnerhelden, dann Heilung eigener HP. | Block/Schild zuerst; Heilung nur tatsächlicher HP-Verlust, cap maxHp. Originaltext „denselben Wert“ darf nicht als nominelle Heilung trotz Schutz interpretiert werden. [J45] |
| rally | B: benachbarte eigene Kreatur erhält +p Angriff. | Linker vor rechtem Nachbarn; nicht die beschworene Quelle; ohne Nachbar kein Effekt. [J46] |
| silence | B: gegenüberliegende Kreatur stun=max(stun,1). | Kein beliebiges Ziel, keine Fähigkeitslöschung. Überspringt eine eigene Angriffsphase; stun wird vor Beschwörungsverzögerung geprüft, dabei summoned gelöscht. [J47], [J81] |
| pierce | B: p+2 direkter Helden-HP-Schaden, Schutz bleibt unberührt. Zusätzlich A: Überschuss eines tödlichen Kreaturentreffers gegen Helden. | **Zwei verschiedene Schutzregeln:** Beschwörung ignoriert Block/Schild; Überlauf aus Angriff läuft durch Block/Schild. Exakter tödlicher Treffer ohne Überschuss erzeugt keinen Heldenüberlauf. [J48], [J71], [J81] |
| shift | B: bewegt eine eigene Kreatur, die unmittelbar neben der Quelle steht, auf irgendeinen freien eigenen Pfad. | Ziel muss nicht angrenzen; Quelle selbst kein bewegtes Ziel. Spieler kann Skip wählen; KI bevorzugt freien eigenen Pfad mit Gegner gegenüber, wenn Herkunft ohne Gegner. Nach Bewegung bei irgendeinem eigenen Nachbarn +1 Resonanz (keine Ordensgleichheit nötig). [J38], [J49], [J75]–[J77] |
| harvest | T: +p+1 eigene Resonanz. | Erst Entfernung, Ablage, dann Todeseffekt; kein Ankunftseffekt. [J37] |
| retaliate | V: p Gegenschaden an Angreifer. | Nur wenn Angriff >0 und Verteidiger überlebt; tödlich getroffener Verteidiger vergilt nicht. Auch Angreifertod erzeugt Ablage/Todesevent. [J81] |
| draw | B: zieht bis zu 1 vom Deckanfang. | Handcap 6, bei leerem Stapel kein Kreislauf und keine Erschöpfung durch diesen Effekt; unterscheidet sich von draw-Phase. [J50], [J57] |
| haste | A: greift bereits im Beschwörungszug an. | Übergeht nicht stun; ansonsten dieselben Ziel-/Schutzregeln. [J81] |
| weaken | B: Gegner weak=max(bisher,p). | Alle Kreaturenangriffe der nächsten eigenen Angriffsphase dieser Gegenseite um weak reduziert, mindestens 0; danach Reset. Keine permanente ATK-Änderung. [J51], [J81] |
| pulse | B: +p Resonanz, +p Schild, beide benachbarte eigene Kreaturen +1 Angriff. | Resonanzcap 15 / Schildcap 25; nur vier legendäre Karten haben pulse, p=4. Nichtlegendäre generierte pulse-Kandidaten werden zu weave. [J8], [J52] |

### Ordensreaktionen und Entfesselungen

Alle Reaktionen [J73] entstehen erst bei einem weiteren Ruf eines anderen Ordens innerhalb desselben Zuges. Zusätzlich immer +2 Resonanz (cap 15); erster Ruf und gleiche Folge-order lösen keine Reaktion aus. `attune` wird pro begin zurückgesetzt. Reihenfolge beim Ausspielen: Kosten/Karte/Einheit → Ordenswechsel/Reaktion → Siegprüfung → Beschwörungseffekt → Siegprüfung [J74].

| Von → nach | Reaktion zusätzlich zu +2 Resonanz |
|---|---|
| ash → tide | 2 geschützter Schaden an Gegnerheld |
| tide → thorn | +3 eigener Schild |
| thorn → veil | +2 eigene Helden-HP, maxHp |
| veil → ash | Gegner weak=max(weak,1) |
| tide → veil | +1 eigene Energie |
| ash → thorn | +3 eigener Block |
| thorn → ash | +2 eigener Schild |
| veil → tide | +2 eigener Block |
| ash → veil | 2 geschützter Schaden an Gegnerheld |
| veil → thorn | +2 eigener Schild |
| thorn → tide | +1 eigene Resonanz |
| tide → ash | +1 eigene Resonanz |

Entfesselung [J97]: aktive main-Phase, mindestens 15 Resonanz zur Freigabe, aber **8** Verbrauch; einmal je Zug; mindestens eine eigene Kreatur dieses Ordens. `n` zählt passende eigene Kreaturen. Ash: 4+3n geschützter Heldenschaden. Tide: +6+2n Schild (cap 25). Thorn: alle eigenen Kreaturen +3 HP bis Basis, Held +3+n bis maxHp. Veil: Gegner weak **auf 2 setzen**, nicht max; passende eigene Kreaturen +2 ATK. Diese kleine Differenz ist bei einer Portierung relevant. Die vorhandene JS-KI ruft burst nicht automatisch auf; Vorhandensein des Spielerkommandos bedeutet keine entsprechende KI-Strategie.

### Grenzen der Legacy-Validierung selbst

Die Referenz sperrt nicht pauschal alle exportierten Hilfsfunktionen nach `winner`: `play`, `endTurn`, `recover`, `burst`, `tacticalMove` und `fortify` prüfen den Gewinner, `burn` und `skipShift` haben dagegen keinen eigenen Gewinnercheck; `draw`/`attackPhase` sind ebenfalls direkt exportierte Enginehilfen [J58], [J57], [J77], [J81], [J106]. Ebenso sperren Pendingziele ausdrücklich `play`/`endTurn`/Manöver/Wacht, aber nicht pauschal jede exportierte Funktion (etwa `recover`/`burst`). Die UI blendet nach dem Ergebnis auf den Abschlussbildschirm um. Diese API-Randbedingungen sind nicht als stärkere generelle Sperrregel ausgegeben. Eine spätere Härtung wäre eine gesondert zu entscheidende Regel-/API-Abweichung, kein stillschweigender Paritätsfix.

## 5. Vollständige Regel- und Funktionsmatrix

`S` = beide relevanten Quellverträge geprüft; `T` = tatsächlich ausgeführter Test, mit ausdrücklich begrenztem Aussagebereich. Testresultate im Detail in Abschnitt 7. P0/P1/P2 und Abhängigkeiten stehen im Implementierungsplan; Paketnummern sind vorgeschlagene **zukünftige** Arbeit, keine hier ausgeführte Änderung. Jeder Eintrag benennt ein konkretes späteres Akzeptanzkriterium.

| ID / Vertrag | Status | JavaScript main | Godot develop | Nachweis / Testgrenze | Paket / Akzeptanzkriterium |
|---|---|---|---|---|---|
| M01 Fünf gegenüberliegende Pfade | **vollständig** | 5 Slots pro Seite. [J21], [J81] | 5 Slots pro Seite. [G3], [G72] | S + T: rules, Angriffssonden | P03: Beide Seiten besitzen genau fünf gültige Slots. |
| M02 Angriff auf leeren Gegenpfad | **teilweise** | Gegnerheld wird getroffen; Block → Schild → HP. [J71], [J81] | Richtiges Heldenziel, aber unmittelbar HP-Abzug. [G79] | T: beide Seiten, 4 passende / 4 abweichende Teilfälle | P04: Leerer Gegenpfad trifft ausschließlich den Gegnerhelden und verbraucht Schutz in Reihenfolge. |
| M03 Gewöhnlicher Kreaturentreffer | **vollständig** | Nur gegenüberliegende Kreatur verliert Angriffswert an HP; kein allgemeiner Gegenschlag. [J81] | Identischer enger Basisfall; tote Kreatur wird entfernt. [G77] | T: rules + besetzter Pfad in beiden Richtungen; Fähigkeiten separat | P04: Gegenüberliegendes Ziel nimmt Schaden; ohne Sonderfähigkeit kein Gegenschaden und kein gewöhnlicher Überlauf. |
| M04 Spieler: Kosten / Kartenverbrauch | **vollständig** | Bezahlbarer gültiger Aufruf verbraucht Kosten und eine Handkarte. [J74] | Derselbe Basisvertrag. [G35] | T: rules Summon spends cost and card, Insufficient energy | P03: Gültig genau einmal abbuchen, Ablehnung verändert keine Ressourcen. |
| M05 Spieler: gültiger freier Beschwörungsplatz | **vollständig** | Nur eigene freie Slots 0–4. [J74] | Ebenfalls eigene freie Slots 0–4. [G35] | S + T: rules occupied/no selection; Indexgrenzen statisch | P03: Besetzte und ungültige Slots ablehnen; keine Mutation. |
| M06 Spieler: zwei Beschwörungen je eigenem Zug | **vollständig** | summons < 2. [J74] | summons < 2, Reset beim Rundenwechsel. [G41], [G132] | T: rules zweite erlaubt / dritte abgelehnt | P03: Dritte Kreatur ablehnen, nächster eigener Zug erlaubt wieder zwei. |
| M07 Handobergrenze beim eigentlichen Ziehen | **vollständig** | draw stoppt bei sechs. [J57] | draw_card stoppt bei sechs. [G33] | T: rules Six card hand limit; Überlaufverfahren separat M19 | P05: Bei sechs Handkarten kein zusätzliches Ziehen und kein Verlust einer Deckkarte. |
| M08 Stabile Kartenidentität / Seltenheit / Effektstärke | **fehlend** | 100 IDs, order, rarity, power, effect. [J8] | Kampfpool nur Index/name/kind/sigil und Grundwerte. [C]; narrative IDs sind keine JS-IDs. | S: vollständiger Datenexport | P02: 100 bekannte IDs unverwechselbar auflösen; keine Zuordnung allein nach Namen. |
| M09 Kartenwerte und Katalogumfang | **abweichend** | 100 Kreaturen mit Effekten. [J8] | 6 Kreaturen ohne Fähigkeiten + 1 Zauber; zwei Namenskollisionen mit anderen Werten. [C] | S: Kartenmatrix und exportierte Werte | P02: Für jede übernommene ID Typ/Kosten/ATK/HP/power/rarity/effect exakt vergleichen. |
| M10 Deckprüfung / Kopien / Besitz | **fehlend** | 20–25; gewöhnlich/selten/episch max. 3, legendär max. 1, Besitzlimit. [J99] | Festes indexbasiertes Deck, keine entsprechende Prüfung. [G28] | S; alter tests.js bricht vor weiteren Checks ab | P02: Grenzen 19/20/25/26, unbekannte IDs, 3/4 Kopien, legendär 1/2 und Besitz prüfen. |
| M11 Vier Standarddecks / eigenes Deck | **fehlend** | Vier konkrete gemischte 25er-Listen + START 25. [J12]–[J18] | Ein festes 25er-Muster i % 7; keine Deckwahl. [G28] | S: exportierte Decklisten | P02: Alle vier Presets und START mit identischer Reihenfolge/Multimenge laden. |
| M12 Seed-RNG, Shuffle, Ziehrichtung | **abweichend** | 32-bit LCG, Fisher–Yates, Deckanfang shift; Münze verbraucht RNG zuerst. [J19], [J57], [J69] | Godot RNG, Fisher–Yates mit anderer Zufallsfolge; Deckende pop_back. [G26]–[G34] | S; innerhalb JS 250 Replays erfolgreich, kein Cross-Engine-Seednachweis | P01/P02: Goldene Zufallsfolgen, Münze, beide Deckreihenfolgen und erste Hände stimmen überein. |
| M13 Münzwurf / Startspielerausgleich | **fehlend** | Seed-Münze; zweiter Spieler +4 Schild und einmalig +1 Energie. [J68], [J69] | Spieler beginnt stets; kein Ausgleich. [G22], [G101] | S | P03: Beide Startseiten und ihr erster Energie-/Schutzwert müssen goldene Zustände treffen. |
| M14 Startleben / Gegner-Level | **abweichend** | Held 35, Gegner min(43,33+floor(level/3)). [J69] | Beide stets 35. [G25] | S | P03: Level 1/2/5 sowie Deckelwert mit beiden Anfangszuständen prüfen. |
| M15 Erste Hand / erster Zug | **abweichend** | 3 Karten im ersten eigenen Zug; ggf. automatische gegnerische Eröffnung. [J68], [J69] | 4 Karten direkt bei start; kein gegnerischer Erstzug. [G32] | S | P03/P05: Eröffnung für beide Münzseiten stimmt vor und nach automatischem Gegnerzug überein. |
| M16 Zugphasen / aktive Seite | **teilweise** | begin → draw → main → attack → end, aktive Seite; Round steigt pro Halbzug. [J68], [J82] | UI-Phasen vorhanden, Modell kombiniert Spielerangriff/Gegnerbeschwörung/Gegnerangriff; Round pro ganzem Zyklus. [G101], [A935] | S + T: Godot-Regressionsduelle, kein JS-Phasenvergleich | P03: Jeder Befehl nur in erlaubter Phase/Seite; Zustände je Phasengrenze gleich. |
| M17 Energieformel und Rücksetzung | **abweichend** | Basis 2 + Hard-Gegnerbonus + Zweitspielerbonus + Resonanzschwellen 5/10/15. [J68] | Start 3, danach min(10,2+round_number). [G25], [G133] | S | P03/P07: Schwellen 4/5/9/10/14/15, erster/zweiter Spieler und Hard-Level separat prüfen. |
| M18 Folgezug ziehen / Bestätigung | **teilweise** | 1 Karte, explizite Spieler-Nachziehphase nach Erstzug. [J60], [J68] | 1 Karte automatisch nach Gegnerangriff. [G136] | S + T: Godot-Regressionsduelle, kein expliziter Phasentest gegen JS | P05: Vor Bestätigung kein main-Befehl; nach genau einem Ziehen keine Wiederholung. |
| M19 Pflichtverbrennen bei Überlauf | **fehlend** | Nur draw und nur erforderlicher Überlauf; Hand → Ablage vor Ziehen. [J58] | Volle Hand lässt Nachziehen lediglich ausfallen. [G33] | S | P05: Bei 6+1 muss genau eine Karte gewählt/abgelegt werden; freiwilliges Verbrennen ablehnen. |
| M20 Block: Verbrauch und Ablauf | **fehlend** | Vor Schild verbraucht; bei eigenem begin auf 0. [J41], [J68], [J71] | Kein block-Zustand, keine Absorption. [G79] | T: JS 2/5/10-Schaden; Godot-geschützte Vektoren weichen ab | P04: Teil-/Vollabsorption, mehrere Angriffe und Ablauf erst beim nächsten eigenen begin prüfen. |
| M21 Schild: Verbrauch / Deckel / Persistenz | **fehlend** | Nach Block; cap 25; hält bis Verbrauch, verschiedene Quellen. [J42], [J71] | Kein ward-Zustand. [G79] | T: JS Restschutz + geschützte Vektoren | P04: Cap 25 und Erhalt über Zugwechsel; Schaden konsumiert Rest nach Block. |
| M22 Leerer Stapel / Erschöpfung | **fehlend** | Einmal pro Nachziehphase mit fehlenden Karten 1/2/3 direkter Schaden; Serie bei vollständigem Ziehen zurückgesetzt. [J60]–[J65] | Leeres Deck bewirkt nichts. [G33] | S | P05: Mehrere fehlende Karten nicht mehrfach bestrafen; Schutz ignorieren; Reset und tödlichen Fall prüfen. |
| M23 Ablagestapel / Todeskarte | **fehlend** | Tod und burn legen ID ab; Todesevent nach Entfernung. [J37], [J58], [J81] | Tote Einheiten werden null; keine Ablage. [G47], [G87] | S + T: Godot Ziel verschwindet, keine Ablageassertion | P04/P05: Jede tote/verbrannte Karte exakt einmal in korrekter Reihenfolge ablegen. |
| M24 Deterministischer Erinnerungskreislauf | **fehlend** | Leeres Deck aus Ablage neu mischen, seitenspezifischer Seed, direkter Preis 1/2/3. [J59] | Keine Deckerneuerung. [G33] | S | P05: Deck/Ablage/Reihenfolge/Preis nach mehreren Kreisläufen einschließlich Tod vergleichen. |
| M25 Erinnerungsruf / Rückholung | **fehlend** | main, einmal, −5 Resonanz, Hand < 6, deterministisch zufällige Ablagekarte. [J70] | Keine Rückholung. | S: vollständiges Modell [G35]–[G137] | P05/P07: Bedingungen/Seed/Ablageentfernung und Verbot der zweiten Nutzung prüfen. |
| M26 Beschwörungsverzögerung | **fehlend** | Neu beschworen wartet eine eigene Angriffsphase, außer haste; stun wird vorher geprüft. [J81] | Jede Einheit greift sofort an; keine Flags. [G72] | T: neu beschworen in beiden Richtungen abweichend | P04: Normale Einheit wartet genau einmal; Eile und gleichzeitige Betäubung getrennt prüfen. |
| M27 FIFO-Effektqueue / Todesreihenfolge | **fehlend** | summon/death/formation FIFO, Reentranzschutz, max. 100 Schritte, Stop bei winner. [J35]–[J54] | Keine entsprechende Queue. [G35], [G72] | S | P04/P06: Verschachtelte Effekte/Tode in JS-Reihenfolge; Sicherheitslimit und Gewinnerabbruch prüfen. |
| M28 Kartenfähigkeit strike | **fehlend** | Beliebiges belegtes Gegnerfeld wählen; ohne Kreaturen geschützter Helden-Fallback; KI niedrigste HP. [J40] | Kein Effektfeld oder Dispatch. [C], [G35], [G72] | S; 100 JS-Ankunftssonden sind nur Smoke, keine semantische Einzelabdeckung | P06: Beliebiges belegtes Gegnerfeld wählen; ohne Kreaturen geschützter Helden-Fallback; KI niedrigste HP. |
| M29 Kartenfähigkeit guard | **fehlend** | Bei Beschwörung power+2 Block auf eigenem Helden, nächster eigener Beginn löscht Block. [J41] | Kein Effektfeld oder Dispatch. [C], [G35], [G72] | S; 100 JS-Ankunftssonden sind nur Smoke, keine semantische Einzelabdeckung | P06: Bei Beschwörung power+2 Block auf eigenem Helden, nächster eigener Beginn löscht Block. |
| M30 Kartenfähigkeit ward | **fehlend** | Bei Beschwörung power+1 Schild, gedeckelt bei 25. [J42] | Kein Effektfeld oder Dispatch. [C], [G35], [G72] | S; 100 JS-Ankunftssonden sind nur Smoke, keine semantische Einzelabdeckung | P06: Bei Beschwörung power+1 Schild, gedeckelt bei 25. |
| M31 Kartenfähigkeit mend | **fehlend** | Bei Beschwörung power+2 Heldenheilung, maxHp respektieren. [J43] | Kein Effektfeld oder Dispatch. [C], [G35], [G72] | S; 100 JS-Ankunftssonden sind nur Smoke, keine semantische Einzelabdeckung | P06: Bei Beschwörung power+2 Heldenheilung, maxHp respektieren. |
| M32 Kartenfähigkeit weave | **fehlend** | Bei Beschwörung power+1 Resonanz, cap 15. [J44] | Kein Effektfeld oder Dispatch. [C], [G35], [G72] | S; 100 JS-Ankunftssonden sind nur Smoke, keine semantische Einzelabdeckung | P06/P07: Bei Beschwörung power+1 Resonanz, cap 15. |
| M33 Kartenfähigkeit drain | **fehlend** | Geschützten Helden treffen und nur tatsächlichen HP-Verlust heilen; maxHp. [J45] | Kein Effektfeld oder Dispatch. [C], [G35], [G72] | S; 100 JS-Ankunftssonden sind nur Smoke, keine semantische Einzelabdeckung | P06: Geschützten Helden treffen und nur tatsächlichen HP-Verlust heilen; maxHp. |
| M34 Kartenfähigkeit rally | **fehlend** | Linken Nachbarn vor rechtem wählen und Angriff dauerhaft um power erhöhen. [J46] | Kein Effektfeld oder Dispatch. [C], [G35], [G72] | S; 100 JS-Ankunftssonden sind nur Smoke, keine semantische Einzelabdeckung | P06: Linken Nachbarn vor rechtem wählen und Angriff dauerhaft um power erhöhen. |
| M35 Kartenfähigkeit silence | **fehlend** | Nur gegenüberliegende Kreatur stun=max(stun,1); kein Entfernen von Fähigkeiten. [J47] | Kein Effektfeld oder Dispatch. [C], [G35], [G72] | S; 100 JS-Ankunftssonden sind nur Smoke, keine semantische Einzelabdeckung | P06: Nur gegenüberliegende Kreatur stun=max(stun,1); kein Entfernen von Fähigkeiten. |
| M36 Kartenfähigkeit pierce | **fehlend** | Ankunft power+2 ignoriert Schutz; tödlicher Kreaturentreffer-Überlauf durchläuft Schutz. [J48] | Kein Effektfeld oder Dispatch. [C], [G35], [G72] | S; 100 JS-Ankunftssonden sind nur Smoke, keine semantische Einzelabdeckung | P06: Ankunft power+2 ignoriert Schutz; tödlicher Kreaturentreffer-Überlauf durchläuft Schutz. |
| M37 Kartenfähigkeit shift | **fehlend** | Nachbar der Quelle auf beliebigen freien eigenen Pfad; Skip; Formation +1 bei Nachbar. [J49] | Kein Effektfeld oder Dispatch. [C], [G35], [G72] | S; 100 JS-Ankunftssonden sind nur Smoke, keine semantische Einzelabdeckung | P06: Nachbar der Quelle auf beliebigen freien eigenen Pfad; Skip; Formation +1 bei Nachbar. |
| M38 Kartenfähigkeit harvest | **fehlend** | Beim eigenen Tod power+1 Resonanz nach Ablage/Entfernung; kein Ankunftseffekt. [J37] | Kein Effektfeld oder Dispatch. [C], [G35], [G72] | S; 100 JS-Ankunftssonden sind nur Smoke, keine semantische Einzelabdeckung | P06/P07: Beim eigenen Tod power+1 Resonanz nach Ablage/Entfernung; kein Ankunftseffekt. |
| M39 Kartenfähigkeit retaliate | **fehlend** | Nur bei positivem Treffer und überlebendem Verteidiger power Gegenschaden; Tod des Angreifers. [J81] | Kein Effektfeld oder Dispatch. [C], [G35], [G72] | S; 100 JS-Ankunftssonden sind nur Smoke, keine semantische Einzelabdeckung | P06: Nur bei positivem Treffer und überlebendem Verteidiger power Gegenschaden; Tod des Angreifers. |
| M40 Kartenfähigkeit draw | **fehlend** | Ankunft zieht maximal eine Karte; volle Hand/leeres Deck ohne Erschöpfung oder Kreislauf. [J50] | Kein Effektfeld oder Dispatch. [C], [G35], [G72] | S; 100 JS-Ankunftssonden sind nur Smoke, keine semantische Einzelabdeckung | P06: Ankunft zieht maximal eine Karte; volle Hand/leeres Deck ohne Erschöpfung oder Kreislauf. |
| M41 Kartenfähigkeit haste | **fehlend** | Nur Beschwörungsverzögerung umgehen, nicht Betäubung. [J81] | Kein Effektfeld oder Dispatch. [C], [G35], [G72] | S; 100 JS-Ankunftssonden sind nur Smoke, keine semantische Einzelabdeckung | P06: Nur Beschwörungsverzögerung umgehen, nicht Betäubung. |
| M42 Kartenfähigkeit weaken | **fehlend** | max(weak,power); alle Angriffe nächster eigener Phase reduziert, danach Reset. [J51] | Kein Effektfeld oder Dispatch. [C], [G35], [G72] | S; 100 JS-Ankunftssonden sind nur Smoke, keine semantische Einzelabdeckung | P06: max(weak,power); alle Angriffe nächster eigener Phase reduziert, danach Reset. |
| M43 Kartenfähigkeit pulse | **fehlend** | Ankunft +power Resonanz/+power Schild, beide benachbarten Verbündeten +1 Angriff. [J52] | Kein Effektfeld oder Dispatch. [C], [G35], [G72] | S; 100 JS-Ankunftssonden sind nur Smoke, keine semantische Einzelabdeckung | P06/P07: Ankunft +power Resonanz/+power Schild, beide benachbarten Verbündeten +1 Angriff. |
| M44 Resonanzzustand / cap / Schwellen | **fehlend** | Eigene Resonanz cap 15; bei 15 Zugbeginn +2 Schild. [J68], [J72] | sigil nur Darstellung, keine Resonanz. [C], [G90] | S | P07: Caps und Schwellen plus gleichzeitige Energie-/Schildwirkung vergleichen. |
| M45 Ordenswechsel / 12 gerichtete Reaktionen | **fehlend** | Anderer Folgeruf +2 Resonanz, gerichtete Reaktion, attune je Zug reset. [J73], [J74] | Keine Ordensketten. | S: [C], [G35] | P07: Alle 12 geordneten Paare und gleiches Paar/erster Ruf ohne Reaktion testen. |
| M46 Vier Ordensentfesselungen | **fehlend** | Freigabe bei 15, Kosten 8, einmal/Zug, passende eigene Einheit erforderlich. [J97] | Keine Entfesselung. | S: Modell und Arena-Kommandos | P07: Alle vier Formeln, Schwellen, Kosten, Einheitenbedingung und Wiederholung prüfen. |
| M47 Aktives Pfadmanöver | **fehlend** | Einmal/main, −3 Resonanz, nur benachbart frei, keine Formationsbelohnung. [J79] | Kein Manöverkommando. | S: [A573], [A861], [G35] | P07/P09: Legale Nachbarbewegung und illegale Fern-/Doppelnutzung; keine shift-Formation auslösen. |
| M48 Aktive Pfadwacht | **fehlend** | Einmal/main, −2 Resonanz, +2 Schild und eigene Einheit +1 HP bis Basis. [J80] | Kein Pfadwachtkommando. | S | P07/P09: Auch voll geheilte Einheit kann Schild gewähren; Deckel und Flags vergleichen. |
| M49 Sieg / Niederlage durch Helden-HP | **teilweise** | Nach relevanten Aktionen und jedem Pfad prüfen; reguläres play/endTurn stoppen. [J78], [J81] | Beide Ergebnisse vorhanden, Prüfung erst nach ganzer Angriffsphase. [G106], [G129] | T: rules Sieg/Niederlage; Reihenfolge statisch abweichend | P04/P08: Nach jedem entscheidenden Ereignis korrektes Ergebnis; keine weiteren regulären Angriffe/Spielzüge. |
| M50 Zwei Kontrollphasen mit drei freien Pfaden | **teilweise** | Für beide Seiten getrennte eigene Serien; Unterbrechung reset. [J81] | Nur Spieler-streak und Spielerprüfung, kein gegnerischer Pfadsieg. [G110] | T: rules Spielerpfadsieg; Gegenseite statisch nicht implementiert | P08: Beide Seiten gewinnen im zweiten eigenen Kontrollschritt; Unterbrechung löscht nur eigene Serie. |
| M51 Gleichzeitiger Heldentod / Unentschieden | **fehlend** | check erlaubt draw. [J78] | Nur Textresultat Sieg oder Niederlage. [G107], [G129] | S; JS 250 Replays enthalten keinen Draw-Nachweis | P08: Kontrollierter beidseitiger Null-HP-Zustand ergibt genau draw und sperrt alle Befehle. |
| M52 Sequentielle Angriffe / sofortiger Abbruch | **abweichend** | Pfad 0–4, Treffer/Tod/Trigger/Sieg vollständig vor nächstem Pfad. [J81] | Sammelt Kreaturenschaden; Heldenabzüge zuerst, dann Kreaturentreffer, Sieg später. [G72] | S; bestehender Regressionstest schützt Godot-Verhalten | P04/P08: Mehrpfad-Szenario mit tödlichem frühen Treffer erzeugt keine späteren Schäden/Tode. |
| M53 Gegner: Deck / Hand / Energie / Limit | **abweichend** | KI benutzt dieselben Ressourcen, max. 2 Beschwörungen. [J83] | Pro Zyklus eine kostenlose zufällige Einheit ohne Gegnerdeck/-hand/-energie. [G118] | S + T: Godot-Regressionsduelle | P10: Jede KI-Aktion durch denselben Validator; Ressourcenverbrauch und Hand/Deckstände stimmen. |
| M54 Gegner: Auswahl / Schwierigkeitsstufen | **abweichend** | Level-basierte deterministische Scoring-KI mit Fähigkeiten, Zielwahl, Manöver, Wacht, Recover. [J83]–[J96] | Fünf andere Profile mit Zufalls-/Zweierstichproben; keine Legacy-Effektbewertung. [G53]–[G71] | S; 1000 JS-Simulationen, keine Cross-Engine-KI-Vergleiche | P10: Identische Kandidaten, Sortierung/Tie-Breaks und Aktionen für easy/normal/hard. |
| M55 Deterministische Partie aus Seed | **teilweise** | Seed + Level + HeroDeck reichen zur Rekonstruktion. [J69], [J103] | Seed bestimmt lokale Partie, aber anderer RNG/Start/Katalog; Profile statt Level. [G22] | T: 30 Godot-intern verglichene Duelle; 250 JS-interne Replays | P01/P10/P11: Gleiche Eingabe + Befehle in beiden Engines ergeben gleiche kanonische Zustandsfolge. |
| M56 Vollständige Zustands-Snapshots | **teilweise** | Beide Ressourcen/Deckreihenfolgen/Ablagen/Flags/IDs/aktive Seite/Ergebnis. [J25] | Nur eigener Deck/Handzustand, Felder, HP, Energie, Round und wenige Flags; result/Profil fehlen. [G90] | S + T: rules vergleicht nur zwölf Godot-Felder | P11: Kanonischer Snapshot deckt alle Legacy-Felder inklusive Pending-Auswahl ab. |
| M57 Ereignisprotokoll mit Ursache / Ziel | **teilweise** | Chronologische Ereignisse mit state, seq, side, source, target, actionId, pendingDeath. [J28] | presentation mit before/after/attacks nur letztem Zug; kein vollständiges Legacy-Ereignisformat. [G92], [A941] | S + T: bestehende Präsentationstests betreffen Godot-Frames | P11: Komplette JS-Ereignisfolge einschließlich Todeszwischenzuständen reproduzierbar exportieren. |
| M58 Befehlsprotokoll / Zustands-Hashes | **fehlend** | 11 record-Kommandos, args, beforeHash/afterHash, Eventgrenzen. [J100]–[J102] | Keine Command-Historie oder FNV-Hashes. | S: gesamtes [G] | P11: Angenommene Kommandos und Eventgrenzen gleich; abgelehnte Kommandos nicht aufzeichnen. |
| M59 Versionierter vollständiger Kampfexport | **fehlend** | NACHTSIEGEL-COMBAT-AUDIT v4, replayVersion 2, engine-Label 2.4. [J33] | Keine kompatible Exportfunktion; QA-Bridge ist kein Auditexport. [A642] | S | P11: Alle erforderlichen Felder/versionierten Semantiken aus aktueller JS-Quelle exportieren. |
| M60 Replay-Import / Verifikation | **fehlend** | Neuberechnung aus Deck/Seed/Level; before/after/finalHash prüfen. [J103]–[J105] | Kein kompatibler Import/Verifier. | T: nur JS-Verifier besteht 250 Replays | P11: Goldene JS-Replays und manipulierte Hashes/ungültige Befehle mit gleichem Ergebnis prüfen. |
| M61 Offene Effektziele / Skip / Eingabegates | **fehlend** | pendingTarget/Shift verhindern weiteres play/endTurn; Auswahl/Skip schließt ab. [J56], [J74]–[J82], [U45] | Zauberauswahl direkt auf Gegner möglich; kein Legacy-Pending-Workflow. [A573], [A861] | S; Godot-Spelltests sind kein strike-Nachweis | P09: Erzwungene Zielwahl/Skip mit korrekter Sperre aller betroffenen Aktionen darstellen. |
| M62 Regelbasierte Angriffsvorschau | **fehlend** | Stun, Wartestatus, Ziel, Durchbruch und Schutz je Pfad. [U22] | Zielmarkierung/Animation, keine entsprechende Ressourcen-/Effektvorschau. [A910] | S | P09: Vorschau aus derselben Regelabfrage, kein UI-Nachbau der Kampflogik. |
| M63 Sammlung: Suche / Filter / Details | **teilweise** | 100 Karten, Name/Orden/Effekt/Seltenheit/Besitz, Grundwerte und Fähigkeit. [U24]–[U26] | 7 spielbare +13 explizite Konzepte; Suche und Fraktion, keine Besitz-/Effekt-/Seltenheitsfilter. [F202] | S + T: vorhandene Experience-Suite | P12: Alle tatsächlichen Karten und Filter korrekt; Konzepte bleiben getrennt und nicht spielbar. |
| M64 Deckwerkstatt / Presetwechsel | **fehlend** | Deck hinzufügen/entfernen, Limits/Verfügbarkeit, Presets. [U27], [U28], [U45] | Keine Deckwerkstatt; Sammlung ist Ansicht. [F202] | S | P12: Legales Deck speichern/starten; unzulässige Änderungen und Fehlstart verhindern. |
| M65 Lokaler Fortschritt / Settings | **teilweise** | localStorage: wins/losses/level, owned/deck, Schwierigkeit/Fx; battle absichtlich null. [U3]–[U8] | Eigener versionierter Fortschritt mit Kapiteln/Helden/Audio; kein owned/deck/Legacy-Level. [S12] | S + T: vorhandene Experience-Suite; kein Legacy-Save-Importtest | P12: Bestehende neue Fortschrittsdaten erhalten und Legacy-Felder ausdrücklich abbilden, nicht ersetzen. |
| M66 Spielstand-Import/-Export / Altschema | **fehlend** | JSON Import/Export, Schlüssel v09 und v06/v05-Migration. [U7], [U30], [U45], [U61] | Nur Godot-eigenes Fortschrittsschema / ux.cfg-Migration. [S27] | S | P12: Validen Altstand importieren, ungültigen atomar ablehnen; Besitz/Deck/Settings erhalten. |
| M67 Lokale Währung / Booster / Belohnung | **fehlend** | Start 180, Booster 240/3 Karten, mindestens seltene erste; Siege/Level/Belohnung, Aufgabe ohne Lohn. [U6], [U29], [U45] | Keine entsprechende Währung oder Booster; Siege/Kapitel separat. [S12] | S: implementierter Shop-Code, Navigation und Adminmodus unterscheiden | P12: Kosten, Zufallsrarität, Besitz-/Sieges-/Aufgabebuchung ohne Echtgeld exakt oder bewusst aus Scope nehmen. |
| M68 Ereigniswiedergabe / Überspringen | **teilweise** | Historisches Replaypanel, Geschwindigkeiten off/fast/normal/slow, Skip; Logexport. [U23], [U37]–[U44] | Präsentationsframes und reduced_motion/low_effects; kein Legacy-Replaypanel/Tempoauswahl/Skip. [A935] | S + T: Präsentationstests beweisen nur neue Sequenzen | P09/P11: Regelzustand von Darstellung trennen, Skip/Tempo darf Endzustand/Kommandofolge nie verändern. |
| M69 Eigenständige Zauberkarten | **abweichend** | Keine: alle 100 kind=creature; strike ist Ankunftsfähigkeit. [J8] | Funkenstoß eigenständiger spell, Kosten 2 / Schaden 3 / nur Gegnerkreatur. [C], [G44] | T: rules Zauber gültig/leer; kein Legacy-Gegenstück | P02/P09: Als Godot-Zusatz getrennt kennzeichnen; nicht als Migration einer Legacy-Karte zählen. |
| M70 Vier Orden als Regelidentität | **teilweise** | ash/tide/thorn/veil mit gerichteten Synergien; Presetnamen sind keine Ordensnamen. [J4], [J13] | ASH/TIDE/THORN/VEIL als visuelle sigils, neue narrative Fraktionen nur Metadaten. [C], [N] | S | P02/P07: Stabile Regel-order erhalten; narrative Anzeige darf Regel-ID nicht austauschen. |

## 6. Explizite Prüfung: freier Gegenpfad, Block, Schild

Reproduzierbare kontrollierte Zustände in [legacy_export.json](evidence/legacy_export.json), erzeugt mit der tatsächlichen JS-Engine; Ergebnisse gegen das unveränderte Godot-Modell in [attack-comparison.json](evidence/attack-comparison.json). Keine Kartendaten wurden dafür geändert: Auditproben erzeugen isolierte Testzustände im Speicher. Eine künstliche Einheit mit Angriff 10 isoliert die Schadenregel von unterschiedlichen Kartenwerten.

| Gleiche kontrollierte Angriffslage | Legacy-Resultat | Godot-Resultat | Befund |
|---|---|---|---|
| Bereits bereit, ATK 10, Gegenslot leer, Held 35, Schutz 0 | Gegnerheld 25 | Gegnerheld 25 | Heldenziel stimmt, für beide Angriffsrichtungen getestet |
| Bereits bereit, ATK 10, Gegenkreatur HP 4, Held 35 | Kreatur entfernt, Held bleibt 35 | Kreatur entfernt, Held bleibt 35 | Gewöhnlicher Treffer ohne Durchbruch stimmt, beide Richtungen |
| Bereits bereit, ATK 10, Gegenslot leer, Held 35, Block 3, Schild 4 | Block 0, Schild 0, Held 32 | Held 25; Schutz kann im Modell nicht dargestellt werden | Ziel stimmt, Schutzpipeline fehlt, beide Richtungen |
| Neu beschworen ohne Eile, ATK 10, Gegenslot leer, Held 35 | Wartet, Held bleibt 35 | Greift an, Held 25 | Bereitschaftsregel fehlt, beide Richtungen |

**Die Godot-Projektion lässt nicht darstellbare Schutz-/Bereitschaftsfelder ausdrücklich weg.** Dies ist ein Nachweis einer fehlenden Modellkapazität und des daraus folgenden abweichenden HP-Verlaufs, kein Scheinvergleich mit funktionierenden Godot-Schildfeldern. Die Proben bestätigen vier passende und vier bekannte abweichende Teilfälle; ihre 16 erfolgreichen Prüfungen erwarten ausdrücklich auch die Abweichungen. Sie bedeuten nicht „16 Paritätstests bestanden“.

Zusätzliche JS-Proben mit Held 35 / Block 3 / Schild 4: Schaden 2 → HP 35 / Block 1 / Schild 4; Schaden 5 → HP 35 / Block 0 / Schild 2; Schaden 10 → HP 32 / Block 0 / Schild 0. Durchdringender Schaden 10 → HP 25, Block 3 und Schild 4 unverändert. Quellvertrag [J71]. Keine automatische Gegenwehr gewöhnlicher Kreaturen, kein allgemeiner Heldenüberlauf nach einem tödlichen Kreaturentreffer. Nur `retaliate`/`pierce` ergänzen ihre eigenen Sonderregeln.

## 7. Ausgeführte Tests, Fehler und Einschränkungen

Werkzeuge: Node.js v24.22.1, Godot 4.6.3.stable.official.7d41c59c4, Linux/Xvfb :99, Mesa llvmpipe (Software-Rendering). Alle Ergebnisse neu für diesen Audit ausgeführt. [Maschinenlesbare Ergebnisse](evidence/test_results.json), [Rohprotokolle](evidence/logs/).

| Prüfung | Exit / Resultat | Tatsächliche Aussage |
|---|---|---|
| JS `node test.js` | **0; 250 vollständige Partien, 250 Replayprüfungen**, 45 Heldensiege / 205 Gegnersiege, 0 Fehler, max.82 Aktionen | Reproduzierbarkeit innerhalb JS; keine Godot-Parität. [Log](evidence/logs/js-test.log) |
| JS `node tests.js` | **1; AssertionError bei Zeile7**, erwartet START.length20, tatsächlich25 | Suite veraltet; nachfolgende Checks nicht erreicht. [Log](evidence/logs/js-tests.log) |
| JS `node ui-smoke.test.js` | **1; TypeError**, `document.body.classList` im Mock fehlt | UI-Testsetup veraltet; kein Nachweis einer kaputten echten Browseroberfläche. [Log](evidence/logs/js-ui-smoke-test.log) |
| JS `node check.js` | **1; ENOENT**, externe Datei `/mnt/data/nachtsiegel-kampf-2162621497.json` fehlt | Vorhandenes Skript gestartet, Inhaltsprüfung nicht möglich. [Log](evidence/logs/js-check.log) |
| JS `node simulate.js 1000 0 …` | **0; 1000 Simulationen**, 437 Heldensiege / 561 Gegnersiege / **2 Timeouts**, errors[] leer | 11 Archetypen, Level1/2/5; nur998 abgeschlossene Partien, keine vollständige Regelrandabdeckung. [JSON](evidence/logs/js-simulate-1000.json) |
| Auditexport / JS-Sonden | **0; 120 Assertions, 0 Fehler**, alle100 Karten ausspielbar, 8 Angriffsszenarien +4 reine Schadensfälle | Ankunftssmoke und kontrollierte Schadensbeweise, kein vollständiger Effekt-Test. [Log](evidence/logs/legacy-probes.log) |
| Godot-Angriffssonden | **0; 16 Assertions, 0 Fehler**; 4 passende / **4 bekannte abweichende** Teilfälle | Erwartete Paritätslücken bestätigt, keine100%-Parität. [Log](evidence/logs/attack-probes.log) |
| Godot vollständiges `DISPLAY=:99 bash tools/test.sh` | **0; 9547 Assertions, 0 Fehler**, Import und alle enthaltenen Prüfungen abgeschlossen | Aktuelle Godot-Regressionen bestehen, kein JS-Portierungsnachweis. [Gesamtlog](evidence/logs/godot-full-suite.log) |
| Darin `tests/rules.gd` | 684 Assertions, 0 Fehler;30 Differentialduelle | Godot gegen gefrorenen Godot-Prototyp, zwölf Snapshotfelder |
| Creative / Narrative | 2253 /97 Assertions, je0 Fehler | Daten und Ressourcen; sieben Godot-Karten unverändert |
| Experience / Input-Layout / Premium | 707 /380 /1720 Assertions, je0 Fehler | Neuer Ablauf, Speicherung, Touch-/Layout-Simulation und vier Querformate |
| UX / Combat Presentation / Combat Sequence | 2350 /725 /631 Assertions, je0 Fehler | 62 UX-Zustände, vollständige Godot-Duelle, Event-/Input-/Darstellungsregression; keine Legacy-Fähigkeiten |
| Audio / Kontrast | 11 Originalcues bestanden;89 gerenderte Zustände /3836 Regionen, 0 Kontrastfehler | Audio-/Darstellungsprüfung; keine zusätzliche gezählte Gameplay-Assertion |

Import-/Renderprotokolle enthalten Umgebungswarnungen: nicht erreichbarer Android-ADB-Daemon (`tcp:5037`) und nicht verstellbares V-Sync des Softwaretreibers. Kein `SCRIPT ERROR`, `ERROR:` oder `FAIL:` im erfolgreichen Godot-Suitenlauf. Der ADB-Hinweis belegt keinen Android-Gerätetest.

### Reproduktion

Voraussetzungen: Node.js, Python 3, Godot 4.6.3; für vollständige Render-Suite ein funktionierendes X11-Display (hier Xvfb `:99`). Beide Repositories auf die oben genannten SHAs auschecken. Aus dem Godot-Repo:

```bash
node docs/migration/evidence/export_legacy.cjs /path/to/duel-deck /tmp/legacy_export.json
# Export muss mit dem eingecheckten evidence/legacy_export.json identisch sein.
cmp /tmp/legacy_export.json docs/migration/evidence/legacy_export.json
mkdir -p work/migration work/xdg/data work/xdg/config work/xdg/cache
export XDG_DATA_HOME="$PWD/work/xdg/data"
export XDG_CONFIG_HOME="$PWD/work/xdg/config"
export XDG_CACHE_HOME="$PWD/work/xdg/cache"
godot --headless --path . --script docs/migration/evidence/compare_attack.gd
DISPLAY=:99 bash tools/test.sh
```

Im auf den Referenzcommit gesetzten JS-Repo getrennt ausführen und Exitcodes einzeln erfassen:

```bash
node test.js
node tests.js
node ui-smoke.test.js
node check.js
node simulate.js 1000 0 /tmp/legacy-simulation.json
```

Export und Sonden sind **Auditwerkzeuge unter docs**, kein neuer Produktionspfad. Sie verändern keine Spielquellen oder Nutzerstände; Godot-Ausgabedateien entstehen ausschließlich unter ignoriertem `work/migration/`. Der Auditexport enthält bewusst öffentlich vorhandene Kartendaten und künstliche Testzustände, keine Nutzerdateien.

### Grenzen des Nachweises

- Kein vollständiger engineübergreifender Command-/Snapshot-Differentialtest existiert. Die acht Auditvektoren prüfen nur kontrollierte Angriffe; sämtliche Kartenfähigkeiten sind statisch verglichen, nicht semantisch in beiden Engines ausgeführt worden, da Godot sie nicht implementiert.
- `test.js` belegt 250 JS-interne vollständige Partien mit Replay-Endhash, nicht die Abdeckung jedes Effektrandes und nicht Godot-Parität. Die Simulation hat zwei Timeouts am 145-Schritte-Limit; diese sind weder Siege noch vollständige Partien.
- Das veraltete `tests.js` meldet im Erfolgsfall „19 checks“, erreicht diesen Punkt aber aktuell nicht. Erwartet 20 Startkarten, tatsächlicher START hat 25. Nachfolgende Erwartungen sind außerdem verdächtig: drei Beschwörungen im selben Zug widersprechen dem heutigen Limit 2. Nicht durch Testreparaturen kaschiert und nicht als erfolgreiche Checks gezählt.
- `ui-smoke.test.js` ist ein Node-VM-/DOM-Mocktest, kein echter Browsertest; `document.body.classList` fehlt schon im Mock. Seine weitere 20-Karten-Erwartung wäre ebenfalls veraltet. `check.js` verlangt `/mnt/data/nachtsiegel-kampf-2162621497.json`, die in main nicht versioniert ist; nicht durch eine erfundene Originaldatei ersetzt.
- Bestehende Dokumente und JSON-Balanceberichte sind historische Artefakte, keine in dieser Prüfung neu ausgeführten Tests. Die aktuelle Testsuite ist separat protokolliert.
- Keine neuen Android-/iOS-Builds, physischen Gerätetests oder Webexport-/Browser-QA-Läufe für diesen Dokumentationsauftrag. Native Godot-Render-/Eingabetests laufen, soweit im Resultat aufgeführt, auf Linux/Xvfb; das ist kein iPhone-/Android-Nachweis. Keine Veröffentlichung oder Änderung der Live-Seite.

## 8. Prioritäten, Abhängigkeiten und Entscheidungspunkte

**P0:** Referenzcommit/Oracle sichern (P01), echte IDs/Karten/Decks (P02), Phasen/Start/Ressourcen (P03), Schaden/Bereitschaft/Tod (P04). Ohne diese Grundlage können Effekte oder KI keinen belastbaren Paritätsnachweis liefern.

**P1:** Ziehen/Ablage/Kreislauf (P05), 16 Fähigkeiten mit Ziel-/Queue-Verträgen (P06), Resonanz/Reaktionen/Entfesselungen/Manöver (P07), symmetrische Ergebnisse (P08), vollständige bedienbare Zielauswahl (P09), echte Legacy-KI (P10), Logs/Replay (P11). Nicht als kosmetische UI-Aufgabe behandelbar.

**P2:** Sammlung/Deckwerkstatt/Altstände/lokale Ökonomie (P12), sobald Kernregeln/IDs stabil sind. Diese Funktionen gehören zur vollständigen funktionalen Parität des alten `game.js`, auch wenn eine bewusste spätere Produktentscheidung sie ausklammern kann. Sie dürfen bis dahin nicht als portiert gelten.

Detaillierte kleine Pakete, Abhängigkeiten, Prüfungen und Gate zum späteren Paritätsclaim: [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md). Jeder spätere Gameplay-PR muss die neuen Legacy-Verträge von den bisherigen Godot-Regressionsverträgen unterscheiden; den eingefrorenen Godot-Oracle stillschweigend als JS-Oracle zu ersetzen würde die Historie verfälschen.

**Vor Umsetzung ausdrücklich festzuhalten:** Sollen die Legacy-Regeln zum verbindlichen Ziel werden, oder bleiben die derzeitigen Godot-Regeln ein eigenständiger Modus? Welche Anzeige-/Konzeptnamen werden nur gemappt? Wie wird der zusätzliche Godot-Zauber behandelt? Werden Deckwerkstatt und lokale Booster übernommen? Dieser Audit trifft diese Produktentscheidungen nicht und ändert weder Kartenwerte noch Regelmodus.

## 9. Dateiverweise

Die Referenzen pinnen den geprüften Quellstand. Auditdateien selbst liegen relativ unter `docs/migration/`; die hier enthaltenen zukünftigen Pakete sind keine Implementierungsbehauptung.

[J]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js
[U]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/game.js
[Index]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/index.html
[G]: https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/scripts/battle_model.gd
[C]: https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/data/card_definitions.gd
[Fixture]: https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/tests/fixtures/legacy_card_pool.json
[R2]: https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/tests/reference_rules.gd#L2
[N]: https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/data/narrative/content.json
[Campaign]: https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/data/campaign/chapters.json
[J4]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L4
[J8]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L8
[J12]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L12
[J13]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L13
[J14]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L14
[J15]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L15
[J16]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L16
[J18]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L18
[J19]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L19
[J21]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L21
[J25]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L25
[J28]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L28
[J33]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L33
[J35]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L35
[J37]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L37
[J38]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L38
[J40]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L40
[J41]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L41
[J42]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L42
[J43]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L43
[J44]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L44
[J45]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L45
[J46]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L46
[J47]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L47
[J48]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L48
[J49]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L49
[J50]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L50
[J51]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L51
[J52]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L52
[J54]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L54
[J55]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L55
[J56]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L56
[J57]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L57
[J58]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L58
[J59]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L59
[J60]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L60
[J65]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L65
[J68]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L68
[J69]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L69
[J70]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L70
[J71]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L71
[J72]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L72
[J73]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L73
[J74]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L74
[J75]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L75
[J76]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L76
[J77]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L77
[J78]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L78
[J79]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L79
[J80]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L80
[J81]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L81
[J82]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L82
[J83]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L83
[J96]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L96
[J97]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L97
[J99]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L99
[J100]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L100
[J102]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L102
[J103]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L103
[J105]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L105
[G3]: https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/scripts/battle_model.gd#L3
[G22]: https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/scripts/battle_model.gd#L22
[G25]: https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/scripts/battle_model.gd#L25
[G26]: https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/scripts/battle_model.gd#L26
[G28]: https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/scripts/battle_model.gd#L28
[G32]: https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/scripts/battle_model.gd#L32
[G33]: https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/scripts/battle_model.gd#L33
[G34]: https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/scripts/battle_model.gd#L34
[G35]: https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/scripts/battle_model.gd#L35
[G41]: https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/scripts/battle_model.gd#L41
[G44]: https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/scripts/battle_model.gd#L44
[G47]: https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/scripts/battle_model.gd#L47
[G53]: https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/scripts/battle_model.gd#L53
[G71]: https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/scripts/battle_model.gd#L71
[G72]: https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/scripts/battle_model.gd#L72
[G77]: https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/scripts/battle_model.gd#L77
[G79]: https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/scripts/battle_model.gd#L79
[G87]: https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/scripts/battle_model.gd#L87
[G90]: https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/scripts/battle_model.gd#L90
[G92]: https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/scripts/battle_model.gd#L92
[G101]: https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/scripts/battle_model.gd#L101
[G106]: https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/scripts/battle_model.gd#L106
[G107]: https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/scripts/battle_model.gd#L107
[G110]: https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/scripts/battle_model.gd#L110
[G118]: https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/scripts/battle_model.gd#L118
[G129]: https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/scripts/battle_model.gd#L129
[G132]: https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/scripts/battle_model.gd#L132
[G133]: https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/scripts/battle_model.gd#L133
[G136]: https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/scripts/battle_model.gd#L136
[G137]: https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/scripts/battle_model.gd#L137
[U3]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/game.js#L3
[U6]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/game.js#L6
[U7]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/game.js#L7
[U8]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/game.js#L8
[U22]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/game.js#L22
[U23]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/game.js#L23
[U24]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/game.js#L24
[U26]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/game.js#L26
[U27]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/game.js#L27
[U28]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/game.js#L28
[U29]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/game.js#L29
[U30]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/game.js#L30
[U37]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/game.js#L37
[U44]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/game.js#L44
[U45]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/game.js#L45
[U61]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/game.js#L61
[A573]: https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/scripts/arena.gd#L573
[A642]: https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/scripts/arena.gd#L642
[A861]: https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/scripts/arena.gd#L861
[A910]: https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/scripts/arena.gd#L910
[A935]: https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/scripts/arena.gd#L935
[A941]: https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/scripts/arena.gd#L941
[F202]: https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/scripts/front_end.gd#L202
[S12]: https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/scripts/progress_store.gd#L12
[S27]: https://github.com/Jagarex-lab/nachtsiegel-app/blob/b1f5ea59a4754bac19df31e279bff8a295cb6ea8/scripts/progress_store.gd#L27

[J106]: https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js#L106
