# Legacy-Kartenkreislauf und Fähigkeiten P05/P06

Stand 2026-11-09. Branch `feature/legacy-engine-p05-p06`, direkt aus PR #4 bei `e36c9262b3854518afe6ced02f74ae130c1adbde`. **Keine UI-/Arena-Integration, keine KI-Zugsteuerung, keine Veröffentlichung und kein Merge.** Der [Integrationsbericht](INTEGRATION_REVIEW.md) ist ein eigener erster Dokumentationscommit dieses Branches; es wurde kein zusätzlicher Prüf-PR eröffnet.

## Ausgangsbasis und Schutzgrenzen

PR #1 Audit, #2 Grundlagen und #4 Kernel sind offen, unverändert und gemäß ihren jeweiligen CI-Nachweisen grün. #4 basiert auf #2; der neue PR wird deshalb gegen **`feature/legacy-engine-p01-p04`** gestapelt. PR #3 ist unabhängig und wird weder übernommen noch verändert. Fixierte JS-Referenz: `Jagarex-lab/duel-deck` bei `34b3062c3f22c0950d9323ad9b97b17c41d1d14f`, SHA-256 `abf880e049080a7ec39a43fefa805ba9e8de18f7638633bef6d7096dc5a78dd1`.

Weiterbenutzt: Katalog, 100 Original-IDs/Regelwerte, fünf Decklisten, RNG, Spielerzustand, Schadenspipeline, Angriffsbereitschaft, Kampf und Todesqueue aus P01–P04. Keine zweite Kampfengine. Änderungen ausschließlich am vorhandenen Legacy-Kernel, seiner Testinstrumentierung/-suite und Migrationsdokumentation. Bereits eingecheckte Goldens/Referenzbytes werden nicht überschrieben. Produktive Arena, sieben Prototypkarten, Lore/Fraktionen/Assets, Markenidentität, F2P und Pages-/Exportkonfiguration bleiben unverändert. Die im Auftrag genannte Bezeichnung ORAFOLD wird hier weder umbenannt noch neu aktiviert.

## Ergebnis

- **P05a–e vollständig für den regulären Legacy-Regelvertrag:** Nachziehen/Handlimit, Pflichtverbrennen, Ablage, Erschöpfung/Reset, deterministischer Lebenspreis-Kreislauf und Rückholung.
- **P06a–p: alle 16 Originalfähigkeiten unterstützt und gegen die unveränderte Originalengine getestet**, einschließlich aller 100 Karten auf beiden Seiten.
- **100/100 Karten sind einzeln im Kernel regelkonform beschwörbar**, mit Originalkosten und tatsächlichem Effekt; 200 Karten-/Seitenfälle weisen dies nach. Das bedeutet nicht 100 neue Karten in der produktiven Arena. Bei einem weiteren Ruf eines anderen Ordens sperrt weiterhin die explizite P07-Abhängigkeit vor jeglicher Mutation.
- Bisheriger Kernelvergleich wächst von 370 auf 415 vollständig ausgeführte Fälle (45 bisher unsupported jetzt aktiviert). Die 370 ursprünglichen Fälle bleiben enthalten; kein zuvor unterstützter Fall wird jetzt übersprungen. Dazu 366 neue P05/P06-Szenarien: **781 bestandene Differentialfälle insgesamt**, nicht 781 vollständige Duelle.
- 27 alte Szenarien weiterhin ausdrücklich unsupported: 25 P07-Fälle, 1 automatischer KI-Zug (P10), 1 Raw-begin-Aufruf für die falsche aktive Seite (bekannte Schutzgrenze aus #4). **Keine P05-/P06-Skips** in der neuen Suite.

## P05: exakte Regeln und Reihenfolgen

| Teil | Implementierter Originalvertrag | Nachweise / Grenzfälle |
|---|---|---|
| Nachziehen | Deckanfang `shift`/`pop_front`, maximal 6 Handkarten; erstes eigenes begin fordert 3, später 1 | Voll/leer/teilweise, Effektziehen versus Phasenziehen, beide Seiten |
| Pflichtverbrennen | Ausschließlich draw, aktive Seite, gültiger ganzzahliger Index, nur wenn `hand + min(pendingDraw, deck.size) > 6`; Hand → Ablage in gewählter Reihenfolge | Ungültige Indizes, unnötiges/zu häufiges Verbrennen abgelehnt; nach erforderlicher Verbrennung erneut finishDraw |
| Ablage | Tod nach Feldentfernung, danach Ablage und harvest; burn legt direkt ab | Feldentfernungs-/Tod-/Ablagezustände und wiederholtes Sterben derselben Karten-ID nach Rückholung/Recycling |
| Phasenermüdung | Einmal pro eigener Nachziehphase mit fehlenden Karten Stufe 1/2/3, cap 3, direkter HP-Verlust ohne Block/Schild | 3 fehlende Karten kosten nicht 3 separate Treffer; erfolgreiche Teilziehung mit Restfehler erhöht Stufe, vollständiger Nachzug setzt Serie zurück |
| Recycling | Nur leeres Deck und nichtleere Ablage; cycles++, deterministischer Shuffle der gesamten Ablage, Ablage leeren, Lebenspreis min(3,cycles), checkWinner | Beide Seiten/Seeds, mehrere Zyklen bis unsigned32-Grenze, Schutz unverändert, tödlicher Preis stoppt vor Ziehen |
| Recycleseed | `(seed XOR imul(cycles,2654435761) XOR sideConstant) >>> 0`, `hero=0x1234abcd` / `enemy=0x5678dcba` | Kein zusätzlicher Verbrauch des Match-RNG; ergänztes low32-Produkt per 16-Bit-Teilen vermeidet int64-Überlauf |
| Rückholung | Aktive main-Phase, einmal/Zug, mindestens 5 Resonanz, Hand<6, Ablage nichtleer; −5, cycled=true, deterministisch mischen/pop_back in Hand | Kosten, Handlimit, Phase, Ablage und Finished-Zustand, Repeat, begin-Reset und neue Nutzung |
| Rückholseed | `(seed + imul(round,7919) + discard.size*17) >>> 0` | Separate RNG-Instanz; negative Seeds, unterschiedliche Runden und hohe 32-Bit-Rundenwerte geprüft |

Originalreihenfolge `begin`: Block/Aktionsflags/Energie/Resonanzbonus → attune/turns/phase/pendingDraw → gegebenenfalls Recycling/Lebenspreis → Gewinnerprüfung → begin-Beobachtung → automatischer Erstnachzug bzw. gegnerische Pflichtverbrennung/Nachzug. Bei einem normalen späteren Spielerzug wird finishDraw weiterhin separat bestätigt.

Originalreihenfolge `finishDraw`: Recycling → gegebenenfalls Ende → Überlaufprüfung → verfügbare/fehlende Karten feststellen → Ziehen → pendingDraw=0/main/drawDone → Beobachtung → Erschöpfungsschaden und Ergebnis oder Serienreset. Bei einem tödlichen Recyclingpreis bleibt der noch nicht abgeschlossene draw-Zustand wie in JS erhalten; kein erfundenes Nachziehen danach.

Gegnerische automatische Pflichtverbrennung wählt wie die Referenz den ersten minimalen Wert `atk + hp*.25 + power − cost`. Das gehört zur Nachziehphase. Es ist **keine** Implementierung von `enemyTurn`, Kartenauswahl-/Beschwörungs-KI oder vollständiger Partieautomation.

### Unvermeidlicher Quellkonflikt: Raw-Helper und öffentliche Aktion

Die Originalfunktion kann bei leerem Deck zuerst die Ablage recyceln und Leben abziehen und danach wegen voller Hand **false** liefern. Eine API kann für denselben Aufruf nicht gleichzeitig diesen Zwischenzustand erhalten und „Ablehnung ohne Mutation“ garantieren.

Deshalb explizite Schichten **im selben Kernel, keine zweite Regelimplementierung**:

- `_finish_draw_reference`, `_burn_reference`, `_skip_shift_reference`: vertrauenswürdige interne Referenzprimitive mit ursprünglicher Reihenfolge/Raw-API-Eigenheiten. Sie ermöglichen den exakten Differentialnachweis, einschließlich zweier dokumentierter mutierender finishDraw-Ablehnungen.
- `execute` und die öffentlichen `finish_draw`/`burn`/`skip_shift`: befugte Spieleraktionen. Finished-Zustand blockiert; `finish_draw` prüft auf einer Zustandskopie mit derselben Implementierung vorab. False führt außen zu keiner Zustands-/Ereignisänderung. Alle illegalen öffentlichen Tests prüfen das ausdrücklich.

Kein UI-/Netzwerkcaller darf interne `_...reference`-Methoden als Spielercommand benutzen. Ein gewöhnliches begin recycelt bereits vor dem späteren Nachziehprompt, daher kann danach regulär die erforderliche Verbrennung gewählt werden. Die defensive Facade ist eine ausdrücklich benannte ABI-Abweichung, keine stillschweigende Änderung des getesteten Raw-Regelablaufs.

## P06: vollständige Effektabdeckung

`p` bezeichnet die unveränderte Effektstärke der CardDefinition. Bei allen Effekten wird zunächst genau der ursprüngliche Kartenpreis bezahlt und genau eine Handkarte verbraucht. Keine zusätzliche Beschwörungsgebühr. automatische/fehlende Ziele sind keine frei erfundenen Wahlrechte.

| Effekt | Trigger, Ziel und Ausführung | Relevante Grenzen und Tests |
|---|---|---|
| strike | Ankunft p+1 auf beliebige Gegnerkreatur; Spieler-Pendingwahl, ohne Gegnerkreatur geschützter Gegnerheld | Offlane-Wahl, negative/fraktionale/leere Ziele, Wiederholung, Tod/harvest; Gegnerseite niedrigste HP, erster Pfad bei Gleichstand |
| guard | Ankunft +p+2 eigener Block | Additiv; verfällt bei eigenem begin, kein erfundener Blockcap |
| ward | Ankunft +p+1 eigener Schild | Cap 25, kein Ablauf bei Zugwechsel |
| mend | Ankunft eigener Held +p+2 HP | Cap maxHP; keine Kreaturenheilung, auch bei voller HP gültiger Ruf |
| weave | Ankunft +p+1 eigene Resonanz | Cap 15; kein zusätzlicher automatischer Burst |
| drain | Ankunft p+1 geschützter Heldenschaden, Heilung nur tatsächlicher HP-Verlust | Vollabsorption heilt 0, Teilabsorption/Overkill/maxHP |
| rally | Ankunft eigener linker, sonst rechter Nachbar +p ATK | Links vor rechts; Randpfade, fehlender Nachbar erlaubt und wirkungslos; nie Selbstbuff |
| silence | Ankunft nur gegenüberliegende Kreatur stun=max(stun,1) | Kein Fähigkeitsentzug/Offlaneziel; fehlendes Gegenüber zulässig, höhere Betäubung bleibt; Eile übergeht Stun nicht |
| pierce | Ankunft p+2 Heldenschaden ohne Schutzverbrauch | Getrennt vom bestehenden **geschützten** Angriffsüberlauf; geschütztes/tödliches Ziel, exakter Kill/Überschuss weiterhin P04 |
| shift | Ankunft Nachbarkreatur der Quelle auf irgendeinen freien eigenen Pfad | Quelle selbst nicht bewegbar, Ziel muss nicht angrenzen; Gegner-Effektziel nach Originalregel, Spielerwahl/Skip/Repeat/ungültige Felder |
| harvest | Eigener Tod nach Entfernung/Ablage +p+1 Resonanz | Cap 15; keine Ankunftswirkung; erneuter Tod nach Recycle/Recover zählt als neuer Einheitenkörper |
| retaliate | Positiver Kreaturentreffer gegen überlebenden Verteidiger: p Gegenschaden | Keine Vergeltung bei tödlichem oder 0 Treffer, gegebenenfalls Angreifertod; bestehende P04-Fälle bleiben aktiv |
| draw | Ankunft zieht 1 innerhalb Handcap vom Deckanfang | Kein Recycling/Ermüdung bei Effektziehen; volle/leere Hand-/Deckkombinationen |
| haste | Greift im Beschwörungszug an | Stun weiterhin zuerst, kein zweiter Angriff; vorhandene P04-Phasentests |
| weaken | Ankunft Gegner weak=max(weak,p) | Alle Kreaturenangriffe nächster eigener Phase reduziert, cap unten 0, danach Reset, keine permanente ATK-Änderung |
| pulse | Ankunft +p Resonanz/+p Schild und beide eigenen Nachbarn +1 ATK | Ressourcen caps 15/25, Randpfade/fehlende Nachbarn; nur originale vier Legendäre, kein neuer Effekt |

Shift-Folge: Bewegung löscht pendingShift, dann FIFO-formation; existiert am Ziel irgendein eigener Nachbar, +1 Resonanz. Keine Ordensgleichheit erforderlich. Dies ist der Originaleffekt, nicht P07-Pfadmanöver mit3 Resonanz. Alle aktiven Ziele werden vor Kosten-/Positionsänderung validiert.

Die gegnerseitige Auswahl innerhalb strike/shift ist Bestandteil der ursprünglichen Fähigkeit. Es wird **kein** Gegnercontroller, keine Hand-/Deckheuristik des P10-`enemyTurn`, kein neues Online-/Serververhalten eingeführt.

## Differentialnachweise und Ereignisse

| Prüfung | Nachgewiesenes Ergebnis |
|---|---|
| Node Grundlagen / Kernel / neue P05-P06-Goldens | 8 + 7 + 6 = **21 Gruppen**, alle bestanden |
| Godot Grundlagen | **2171 Assertions, 0 Fehler** |
| Godot bestehender Kernelvergleich | **2221 Assertions, 0 Fehler; 415 Fälle**, davon die bisherigen 370 unverändert enthalten |
| Godot neue P05/P06-Suite | **2348 Assertions, 0 Fehler; 366 Szenarien / 521 Übergänge**, alle 16 Effekte und 200 Karten-/Seitenpaare |
| Gesamter Differentialvergleich | **781 bestandene Fälle**, 27 getrennt ausgewiesene alte unsupported-Szenarien |
| Original-JS `node test.js` | 250 vollständige Läufe und 250 Replays, Exit 0 |
| Original-JS `node tests.js` | Exit 1: bestehende START-Erwartung 20 versus Quellwert 25 |
| Original-JS UI-Smoke | Exit 1: bestehender Mock besitzt kein `document.body.classList` |
| Original-JS `check.js` | Exit 1: externe `/mnt/data/nachtsiegel-kampf-2162621497.json` fehlt |

[Legacy-Testlog](p05-p06-evidence/legacy-suite.log), [Kernelresultat und unsupported-Liste](p05-p06-evidence/core-results.json), [P05/P06-Resultat](p05-p06-evidence/p05-p06-results.json), [unveränderte Upstream-Testresultate](p05-p06-evidence/upstream-results.json).

Die [Kartenabdeckung](p05-p06-evidence/card-coverage.csv) führt alle 100 stabilen Original-IDs mit beiden Seiten auf; gemischte Ordensketten sind ausdrücklich P07-gesperrt. [Geschützte Dateien](p05-p06-evidence/protected-files.json) dokumentieren die unveränderten Quell-/Datenbytes. Das [Quellmanifest](p05-p06-evidence/source-manifest.json) fixiert die geprüften Kernel-, Test- und neuen Fixturebytes mit SHA-256.

Die neue Suite vergleicht pro Schritt vollständige Vor-/Nachzustände und eine kanonische **Ereigniszustandsfolge** mit pendingDeath. Unmittelbar identische aufeinanderfolgende Beobachtungen werden zusammengefasst; keine Ressourcen, Deckreihenfolgen, Flags oder Zwischenzustände gelöscht. Nichtaufeinanderfolgende Wiederholungen bleiben erhalten. Vertauschte unterschiedliche Ereigniszustände und manipulierte Felder werden erkannt.

Das ist noch kein P11-kompatibles Rohlog: Nachrichtentexte, source/target-Metadaten, Befehls-/Hashgrenzen und jedes doppelte identische Textlog werden nicht als ABI identisch behauptet. FIFO-Todeszustände werden zusätzlich weiter separat gegen Originalereignisse geprüft. Der neue strengere Vergleich fand einen fehlenden Beobachtungspunkt im vorhandenen Angriffsablauf: Feldentfernung vor Ablage. Diese Tracepunkte sind ergänzt; Schadens-/Endzustandsregeln wurden dafür nicht verändert.

Alle drei neuen Golden-Dateien werden ausschließlich aus der fixierten Referenz erzeugt, unabhängig von der Godot-Implementierung. Normaler Generatoraufruf prüft Bytes; `--write-new` darf bestehende Goldens nicht überschreiben. Vorhandene P01–P04-Referenzen und Daten bleiben unverändert. Erweiterte alte Tests aktivieren neue Fälle, statt deren bisherige „unsupported“-Markierungen für immer festzuschreiben.

## Bekannte Unterschiede, Risiken und offene Abhängigkeiten

1. Raw-finishDraw-Mutation vor false und strengere öffentliche Facade wie oben. Raw-burn/skipShift ohne eigenen JS-Gewinnercheck bleiben nur intern quellkonform, öffentlich blockiert. Recover trotz Pendingtarget ist laut Quelle erlaubt und wird nicht pauschal gesperrt.
2. Bereits dokumentierte Schutzunterschiede aus #4 bleiben: physisch doppelt injiziertes Todesevent nur einmal, falsche aktive begin-Seite abgelehnt, Eventlimit als Diagnose statt JS-Exception. Kein vollständiger untypisierter JS-ABI-Claim.
3. P07-Ordenswechselreaktionen blockieren einen weiteren andersartigen Ruf **vor** Kosten, Karte und Feld. Gleichordentliche Kombinationen und erster Ruf aller 100 Karten funktionieren. Manöver/Wacht/Burst bleiben unsupported. Es wird nichts stillschweigend ignoriert.
4. P08-Ergebnisprüfungen erfolgen an den ursprünglichen vorhandenen Punkten, einschließlich tödlichem Recycling/Ermüdung/pierce und Abbruch von Folgeereignissen. Bei späteren P07-Effekten müssen alle zusätzlichen Gewinner-/Queuegrenzen noch erweitert geprüft werden.
5. Keine automatische KI, kein vollständiger JS-createBattle/endTurn-Komfortwrapper, kein P11-Replay-/Hash-/Save-/Netzwerkvertrag. Interne Dictionary-Identität schützt Tode nur innerhalb eines Kernel-Laufs, kein persistenter Instanz- oder Rewindvertrag.
6. Neue lokalen Regeln/Referenztests sind keine Smartphone-/Store-/Produktionspackungsabnahme. Keine neuen Plattformexports, keine physischen Geräte, keine produktive Aktivierung. RefCounted-Kernel verwendet bestehende Datenkomponenten, keine F2P-Karteninstanzen oder Währungen.
7. Unveränderte Upstream-Testschuld wird separat aufgeführt; ein bestandener JS-Replaylauf beweist keine Godot-Ganzpartieparität.

### Gefundene Fehler und Wiederholungen

Die erste Lifecycle-Prüfung meldete **12 fehlgeschlagene Assertions** bei korrekten Endzuständen: Die neue Ereignisfolge verlangte den Zwischenzustand „Einheit entfernt, noch nicht abgelegt“. Der entsprechende Tracepunkt fehlte im übernommenen P04-Code. Nach Ergänzung der Beobachtung bestanden alle 2348 Assertions; die ursprüngliche [Fehlerausgabe](p05-p06-evidence/fixed-trace-failure.log) bleibt erhalten.

Ein vollständiger Desktop-Regressionslauf bestand sämtliche Assertions, scheiterte jedoch beim abschließenden Fehlercheck an `ObjectDB instances leaked at exit` / `1 resources still in use at exit` im unveränderten Regeltest. [Suitefehler](p05-p06-evidence/shutdown-failure.log), [Regellog](p05-p06-evidence/shutdown-rules-failure.log). Eine isolierte Wiederholung von `tests/rules.gd` bestand 684 Assertions ohne diese Meldungen ([Log](p05-p06-evidence/isolated-rules-recheck.log)). Die Ursache ist nicht bewiesen; insbesondere ist ein Zusammenhang mit parallelen Godot-Prozessen nur eine Hypothese. Keine Produktions-/Audiocodes wurden zur Unterdrückung des Fehlers geändert.

Der anschließend serialisierte Gesamtlauf scheiterte im unveränderten Kampfpräsentationstest an **2 Assertions** (`Animated turn finishes`, `No stale visual snapshot after phase sequence`) bei 1600×900, gemeldeten 2 FPS und unveränderter 12-Sekunden-Frist. Die bis dahin abgeschlossenen Regel-, Daten-, Narrative-, Menü-, Touch-/Layout-, Premium- und UX-Tests waren fehlerfrei. Das ist ein tatsächlicher fehlgeschlagener Lauf; Software-Renderer-Last ist eine plausible, aber nicht bewiesene Ursache. [Fehlerlog](p05-p06-evidence/render-timeout.log), [Messwerte](p05-p06-evidence/render-timeout-performance.json). Die Umgebung hat CPU-Quota 2 bei 3 sichtbaren CPUs. Fristen, Tests und Produktionsanimationen wurden nicht verändert.

Eine isolierte Wiederholung mit `DISPLAY=:99 LP_NUM_THREADS=2 godot --path . --audio-driver Dummy --resolution 1280x720 --script tests/combat_presentation.gd` bestand **725 Assertions, 0 Fehler** einschließlich aller vier intern gewechselten Auflösungen und vollständiger Sieg-/Niederlagenpartien ([Log](p05-p06-evidence/combat-lp2.log), [Messwerte](p05-p06-evidence/combat-lp2-performance.json)). Die begrenzte Mesa-Threadzahl ist eine reine Testumgebungseinstellung, keine Produktions-/Testcodeänderung.

Der vollständige Desktop-Regressionslauf mit `DISPLAY=:99 LP_NUM_THREADS=2 tools/test.sh` läuft zum Zeitpunkt dieses Quellcommits noch. Bis zum dokumentierten Abschluss bleibt der Folge-PR Entwurf; der Ausgang wird mit eigenen Logs nachgetragen. Keine vollständig grüne Endabnahme dieses Laufs behauptet.

## Fortschrittsmatrix P01–P12

| Paket | Stand nach diesem PR | Nächste Grenze |
|---|---|---|
| P01 | Pins/Goldenreproduktion, Vergleich und neue Zustandsfolgen geprüft | Für jeden neuen Command fortschreiben, kein Vollreplayclaim |
| P02 | 100 Originalkarten/fünf Decks/RNG unverändert weiterbenutzt | Keine produktive Aktivierung |
| P03 | Beide Spieler, Ressourcen, Phasen und nun alle P05-Nachziehgrenzen | Automatischer Gegnerzug weiterhin P10; before-AI-Schnittstelle bleibt |
| P04 | Schutz, Bereitschaft, Pfadkampf, FIFO/Tod; Beobachtung um Entfernung vor Ablage ergänzt | Keine neue Kampfregel, defensive Raw-API-Differenzen beibehalten |
| P05 | a–e vollständig im regulären Vertrag und über Raw-/Facade-Grenze getestet | Keine offenen P05-unsupported-Fälle |
| P06 | a–p: 16 Effekte,100 Karten auf beiden Seiten, Ziele, Queue und Interaktionen geprüft | Keine offenen P06-unsupported-Fälle; gemischte Ordensketten noch P07 |
| P07 | Ressourcenbasis/Formationsfolge vorhanden | 12 Reaktionen, Entfesselungen, Manöver und Wacht |
| P08 | Bestehende Ergebnisregeln plus P05/P06-Prüfpunkte quellkonform | P07-Ketten: tödliche Reaktion vor Ankunft, weitere Grenztests |
| P09 | Nicht begonnen | UI-/Touch-/Zielwahl-/Ressourcenprojektion erst nach Regelabnahme |
| P10 | Nicht begonnen | Originale ressourcenbasierte KI und automatische Wrapper |
| P11 | Noch kein kompatibles Audit/Replay | Quelle/Ziel, Commands, Hashes, Import/Export |
| P12 | Nicht begonnen | Sammlung/Deckwerkstatt/Spielstand-/Altstand-/Produktintegration separat |

## Nächster sicherer Schritt

P07 zunächst die zwölf gerichteten Reaktionen als ein separat getestetes Paket ergänzen und erst dann den derzeitigen Ordenswechselguard entfernen. Nach jeder Reaktion exakt wie JS vor Ankunft checkWinner prüfen; ein tödlicher Wechsel darf den folgenden Beschwörungseffekt unterdrücken. Anschließend Originalentfesselungen (Freigabe 15/Kosten 8), Manöver (3) und Wacht (2) jeweils mit Bedingungen/Negativtests. Parallel P08 an allen neuen Mutationspunkten prüfen. Bestehende 781 Fälle müssen weiterbestehen, neue Ordensfolgen erst nach vollständigem Vertrag aktivieren. KI und UI folgen gesondert.

## Reproduktion, PR-Basis und Mergegrenze

```bash
# Node 24, Godot 4.6.3, Linux/Coreutils; alle Legacy-Pakete:
tools/test_legacy.sh
# Neue Goldens ausschließlich prüfen, nichts überschreiben:
node tools/legacy/generate_p05_p06.cjs
node tools/legacy/generate_p05_p06_edges.cjs
node tools/legacy/generate_p05_p06_lifecycle.cjs
# Bestehende produktive Desktop-Regressionssuite, z.B. Xvfb:
DISPLAY=:99 LP_NUM_THREADS=2 tools/test.sh
```

Der Legacy-CI-Workflow wird nur um den neuen gestapelten Basisbranch erweitert; er besitzt keinen Deploymentpfad. Pages-Publish bleibt unverändert und ist gerade deshalb ein Integrationsblocker unter „kein Deployment“. Mergefolge erst nach Absicherung und ausdrücklicher Freigabe: #1 → #2 → #4 → dieser Folge-PR; #3 separat. Nach tatsächlicher Elternintegration retargeten und bei Squash nur die eigenen Folgecommits neu auf develop aufsetzen. Keine Elternbranches aus diesem Auftrag verändern, kein Auto-Merge.
