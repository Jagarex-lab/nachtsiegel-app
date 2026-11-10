# M2b – Opt-in-Triggerbrücke: Architektur und Abnahmeplan

Arbeitsbasis: `67f89fd`, eigener Labor-Worktree/Branch. Kein Bestandteil von PR10 und keine Freigabe einer produktiven Kartenmigration.

## Gewählte Grenze

Die vorhandene Alpha-Engine bleibt der einzige Kampfkernel. Ein neues explizit instanziiertes `scripts/card_system/trigger_model.gd` erbt von ihr. Die produktive Session verwendet weiterhin das unveränderte Alpha-Profil. Nur mechanisch validierte V2-Ansichten bestehender Karten mit passendem `source_binding` dürfen ihre bisherigen spezifischen Effekte ersetzen. Es gibt keinen automatischen Poolimport, keine neuen Kartenwerte und keine neuen Kostenregeln.

Erste ausführbare Auslöser: `on_play`, `on_summon`, `on_death`. Bestehende aktivierte Relikte werden weiterhin genau einmal über die native Aktivierung ausgeführt; `on_relic_activate` kann zunächst als tatsächlicher Beobachtungspunkt protokolliert werden, ohne allgemeine neue reaktive Fähigkeiten zu behaupten.

Die notwendigen Standard-Extensionpoints ändern keine Standardwirkung:

1. Ein leerer Ausspielen-Hook nach Zahlung/Platzierung/Ordensreaktion und vor dem Einreihen der Ankunft. Er meldet kein Ausspielen bei reiner Effektbeschwörung.
2. Die ursprüngliche Todesablage, Instanz-Deduplizierung und `pending_death` bleiben gemeinsam. Nur der bisher fest eingebaute Harvest-Effekt wird in eine überschreibbare Methode ausgelagert.
3. Nur der bestehende Alpha-Impuls-Effektmatcher wird in eine überschreibbare Methode ausgelagert. Zahlung, Handentfernung, Ablage und Protokoll bleiben im ursprünglichen `play`.
4. Die bisherigen Transaktionsproben erhalten eine Factory-Methode. Das Opt-in-Profil kopiert Konfiguration, Seriennummern und relevante Adaptergrenzen in eine getrennte Instanz. Keine veränderlichen Bridge-/Queueobjekte werden mit der echten Partie geteilt.

Nach Übergabe eines Effekts an V2 erfolgt bei Fehlern **kein V1-Fallback**: Er würde unbekannte oder doppelte Wirkungen erzeugen. Vor der Aktion ungültige Anfragen bleiben unverändert; ein technischer Fehler während einer bereits gültigen Effektkette wird ausdrücklich protokolliert und sperrt das Opt-in-Spiel.

## Identität und Reihenfolge

Ein nativer Summon-Queueeintrag wird beim Einreihen an die damalige Wesen-UID gebunden. Ein später auf demselben Pfad stehendes Exemplar derselben Karten-ID darf dessen Ankunft nicht erben. Die zusätzliche Identität gilt nur für Opt-in-Einträge; unveränderte V1-Partien behalten ihre Originalereignisse.

Die Bridge erzeugt monotone Ereignisnummern und quellenbezogene IDs. Der Runtime-FIFO bleibt die Ausführungsqueue. Während eines laufenden Runtimeeffekts entstehende native Beschwörungs-/Todesereignisse veröffentlichen neue V2-Arbeit hinten in diese Queue. Bestehende noch wartende Fähigkeiten werden zuerst abgewickelt. Die native Queue bleibt für ihre ursprünglichen Aufgaben verantwortlich. Die beiden bestehenden technischen Limits werden nicht als eine gemeinsame Gesamtgrenze ausgegeben.

Kampfprotokoll und Bridgejournal enthalten Auslöser, echte Quelle, UID, Pfad, Anlass und gegebenenfalls Fizzle-/Fehlergrund. Kosten bleiben Sache des ursprünglichen Ausspiel-/Aktivierungsbefehls; eine Wirkung darf sie nicht erneut bezahlen. Zwei identische Impulse am selben Handindex erhalten verschiedene monotone Ereignis-IDs. Extern gewählte Runtime-IDs dürfen Beobachtungs-/Leereinträge nicht nachträglich als ausgeführte Bridgefähigkeiten erscheinen lassen.

Ankunftsereignisse sind in diesem Opt-in-Profil an eine lebende, noch am ursprünglichen Ort vorhandene Instanz gebunden. Eine entfernte/ersetzte Quelle wird als `fizzled` protokolliert. Das ist eine ausdrücklich gewählte zusätzliche Quellenvalidierung des experimentellen Profils, keine behauptete vollständige Legacy-Semantik für zukünftige Ketten: Der alte Resolver prüft diese UID nicht. Sobald neue Ketten Quellen vor ihrer Ankunft entfernen oder verschieben können, muss die Frage, ob ein bereits ausgelöster Effekt ohne Quelle weiterläuft, anhand eines verbindlichen Timingvertrags geprüft werden. Standard-V1-Partien bleiben unverändert.

Die Runtime hält ihren Kernel bei expliziter Verwendung weiterhin stark. Nur das neue Modell-owned-Profil verwendet den optionalen schwachen Rückbezug, damit `Modell → Runtime → Modell` keinen RefCount-Zyklus bildet. Während eines synchronen Drains hält eine lokale Referenz das Modell am Leben. Die kleine beobachtende Runtime-Unterklasse aktualisiert auch Outcomes von Kindereffekten, die erst nach Rückkehr aus einem nativen Queue-Stack ausgeführt werden.

## Auslösermatrix und Nachweisauftrag

| ID | Ziel dieses Teilpakets | Noch notwendige Semantik/Abhängigkeit |
|---|---|---|
| `on_play` | Automatisch bei regulär ausgespielten Opt-in-Karten; Kosten/Ablage nativ | Kein zusätzlicher Ausspielvorgang bei Recall/Effektbeschwörung |
| `on_summon` | Automatisch an nativer Summonqueue; V1-Ankunft ersetzt | UID-Revalidierung vor Ausführung |
| `on_attack` | Offen | Pro einzelnen Angriff vor Zielkontakt; Reaktionsfenster und erneute Zielprüfung |
| `on_defend` | Offen | Tatsächlicher Verteidiger und Überleben/Schadensbedingung |
| `on_deal_damage` | Offen | Instanzbezogener Schadenswrapper statt statischer, quellenloser `damage()`-Funktion |
| `on_take_damage` | Offen | Gewünschter Schaden gegenüber Block/Schild/HP-Verlust; Quellen-/Zielprovenienz |
| `on_kill` | Offen | Eindeutige Zuordnung zum tödlichen Schadensereignis, auch Vergeltung |
| `on_death` | Automatisch innerhalb ursprünglicher Todesqueue; V1-Harvest ersetzt | Ursprüngliche Ablage/Deduplizierung nicht überspringen |
| `on_turn_start` | Offen | Nach verzögertem Schaden/Konvergenz/Ressourcenreset, vor automatischem Nachziehen; Probe äquivalent |
| `on_turn_end` | Offen | Verhältnis zu Angriff/Konvergenzdeklaration und Gewinnerprüfung festlegen |
| `on_lane_change` | Offen | Gemeinsamer Bewegungshook in Shift/Taktik/Displace; Ursache sowie alte/neue Position |
| `on_draw` | Offen | Einzelner tatsächlicher Deck→Hand-Übergang; Eröffnung und Rückholung ausdrücklich unterscheiden |
| `on_discard` | Offen | Abwerfen aus der Hand gegenüber Todesablage/Impulsverbrauch/Reliktersatz unterscheiden |
| `on_spend_resonance` | Offen | Tatsächliche Bruttokosten aus Recover/Burst/Taktik/Fortify; keine Nettodelta-Heuristik |
| `on_relic_activate` | Beobachtung der nativen erfolgreichen Aktivierung | Noch kein allgemeiner aktivierungsabhängiger Trigger-/Kostenvertrag |
| `on_condition` | Offen | Datenvertrag für Prädikate, Quellenbereich, Kanten-/Dauerbedingung und Wiederholgrenzen |

Die aktuelle Registry erlaubt für konkrete Fähigkeiten weiterhin nur ihre tatsächlich bekannten Kombinationen. Die bloße Erzeugung eines zusätzlichen Ereignisnamens wird nicht als spielbare Triggerfähigkeit gezählt. Neue Triggerkombinationen benötigen einen gemeinsamen Daten-/Text-/Runtimevertrag.

## Vorgesehene Tests

- Opt-out-Profil gegen Alpha: vollständige Zustände und Originalereignisse identisch, beide Startseiten und vollständige Partien.
- Alle acht tatsächlichen Pilotbindungen auf beiden Seiten; genau einmalige Wirkung einschließlich Harvest und Recall→V2-Ankunft.
- Reguläres Ausspielen gegenüber Effektbeschwörung, ursprüngliche Energie-/Hand-/Ablagereihenfolge und Reliktaktivierung.
- Ganze Konfiguration atomar zurückweisen bei falschen Originalwerten, unbekannten IDs, nicht unterstützten Fähigkeiten/Triggern oder neuen Resonanzkosten.
- Summon an alte UID binden; Ersatzinstanz bleibt unbeeinflusst. Bereits gestorbene Instanz nicht zweimal ablegen/auslösen.
- Native Probe besitzt eigene Bridge und entspricht der realen Konfiguration; Probeeindrücke/Sicherheitszähler gelangen nicht doppelt in die Partie.
- Deterministische Wiederholung, lange FIFO-Ketten, klare Fehlersperre, Hand-/Resonanz-/Schildgrenzen und direkte Heldentreffer erhalten.

## Tatsächlich ausgeführte Ergebnisse

Godot 4.6.3, Linux, ausschließlich headless mit `LP_NUM_THREADS=2` und eigenen XDG-Verzeichnissen im Labor-Worktree:

| Suite | Ergebnis | Aussage |
|---|---|---|
| `card_system_trigger_bridge.gd` | **506 Assertions, 0 Fehler** | Acht tatsächliche Pilotbindungen, beide Spielerseiten, echte Befehls-/Queuehooks und Fehler-/Ownershipfälle |
| Bestehende `card_system_runtime.gd` | **314 Assertions, 0 Fehler** | Bestehende explizite Adapter-API nach dem optionalen Ownership-/Callbackschutz unverändert funktionsfähig |
| Bestehende `alpha_rules.gd` | **1.704 Assertions, 0 Fehler**, 64 vollständige KI-Simulationen | Produktions-Alpha-Regeln, 55 Karten und vier Starter |
| Bestehende `alpha_replay.gd` | **173 Assertions, 0 Fehler** | Vier vorhandene native Legacy-/Alpha-Replays; kein behaupteter neuer V2-Session-Replay |
| Vollständiges `tools/test_legacy.sh` | **30 Node-Tests bestanden**, alle fünf Godot-Suiten fehlerfrei | Fixierte JavaScript-Referenz und Defaultkernel unverändert |

Die fünf Legacy-Godot-Suiten meldeten: Foundations 2.171 Assertions; Engine 2.235 Assertions mit 441 Differentialfällen; P05/P06 2.340 mit 366 Differentialfällen; P07 7.562 mit 474 Differentialfällen; Matches 2.235 mit 24 vollständigen Duellen und 705 Befehlsübergängen. Alle jeweils null Fehler. Diese alten Fälle sind keine neu erfundenen V2-Differentialfälle.

Die neue Bridge-Suite enthält unter anderem:

- Alle acht gespeicherten Pilotfähigkeiten werden auf beiden Seiten über reguläre `execute`-Befehle oder ihre echte native Todesqueue erreicht. Vergleichbare V1-/V2-Fixtures besitzen nach Ausführung identische vollständige Gameplayzustände.
- Wiederkehr entfernt die letzte passende Ablagekarte, erzeugt den ursprünglichen Ursprungsschild und führt den V2-Guard genau einmal aus. Der zurückgerufene Guard wird nicht als ausgespielte Karte gemeldet, bezahlt, gezählt oder abgestimmt. Die Runtimefolge lautet `recall`, danach `guard`.
- Sowohl ein ursprünglicher Strike mit echter Zielwahl als auch die ursprüngliche Angriffsphase lösen den optierten Harvest über die Todesqueue einmal aus. Ablage, Overkill-Kontext, `pending_death` und Deduplizierung bleiben erhalten.
- Zehn unterschiedliche Instanzen aus beiden Seiten erreichen die native Summonqueue in bestimmter Reihenfolge und wenden tatsächlich zehn Guard-Effekte an. Erneutes Einreihen derselben Instanz erzeugt keinen zusätzlichen Block.
- Acht vollständige KI-Partien in vier Profilvarianten und zwei Seeds: Original-Alpha, Bridge ohne Opt-in, Bridge mit acht Bindings und deren unabhängige Wiederholung. Opt-out bleibt einschließlich Originalereignissen identisch; Opt-in erhält den Gameplayzustand und reproduziert seine eigenen Ereignisse/Journalfolge deterministisch. Dies ist eine unabhängige Modellwiederholung, kein neues veröffentlichtes Session-Replayformat.
- Proben besitzen unabhängige Konfiguration, UID-Historien und Runtime-Reservierungen. Ihre Effekte und Logs werden nicht doppelt auf die echte Partie angewandt.
- Ungültige Befehle/Binder verändern weder Partiezustand noch Seriennummern, Protokoll oder RNG. Ein späterer technischer Auflösungsfehler ist davon getrennt: `execute` meldet `ok=false`, `accepted=true`, `reason=effect_resolution_error`, weil die ursprünglich gültige Aktion bereits bezahlt/angenommen war.
- Technische Fehler stoppen nachfolgende native Echo-/V1-Einträge. Ein Fehler während eines synchronen Runtime-Callbacks kann nicht nachträglich als erfolgreiche äußere Kette erscheinen. Explizite Fehler-Injektionsfixtures werden als solche benannt; sie sind keine neuen Gameplayfähigkeiten.
- Ein extern gehaltener schwacher Adapter bleibt nach Modellfreigabe sicher; Freigabe während eines Callbacks erfolgt erst nach beendetem Drain. Der saubere Lauf enthält keine Objekt-/Ressourcen-Leakmeldungen.

Ein erster Lauf im frischen Worktree meldete fehlende Audioimportdateien und zählt trotz erfolgreicher Regelassertions nicht als sauberer Test. Nach eigenem headless Import bestand der Lauf fehlerfrei. Ein späterer Fehler-Injektions-Test erzeugte selbst einen starken Callback-Zyklus; der Wrapper wies seine Leakmeldungen korrekt zurück. Die Testverbindung wird nun ausdrücklich getrennt, der abschließende Lauf ist sauber.

```sh
mkdir -p work/xdg/data work/xdg/config work/xdg/cache
export LP_NUM_THREADS=2
export XDG_DATA_HOME="$PWD/work/xdg/data"
export XDG_CONFIG_HOME="$PWD/work/xdg/config"
export XDG_CACHE_HOME="$PWD/work/xdg/cache"
godot --headless --editor --import --path . --quit
tools/test_legacy.sh
tools/test_trigger_bridge.sh
```

Die Logs liegen reproduzierbar unter `work/trigger-bridge/`, `work/legacy/` und `work/alpha/`; der Gesamtlauf unter `work/trigger-aggregate-final.log`. Es wurden keine Browser, GUI-Tests, Geräteprüfungen, Builds, Pushes, Merges oder Deployments für dieses Paket gestartet.

## Noch nicht freigegeben / nächste Pakete

1. Die mechanische Opt-in-Prüfung ersetzt nicht `tools/card_system/validate.cjs` für vollständigen Daten-/Text-/Artworkvertrag. Das Profil akzeptiert ausschließlich eine einzelne, parametergleiche ursprüngliche Fähigkeit je `source_binding`. Es ist keine allgemeine Freigabe beliebiger V2-Karten oder neuer Kombinationen.
2. Quellen mit erforderlicher neuer Zielwahl wie der bisherige `strike` werden bei Konfiguration ausdrücklich abgewiesen. Der ungebundene ursprüngliche Strike bleibt spielbar und ist als Todesqueue-Ursache getestet. Neue Ziele benötigen einen eigenen Command-/Pending-Vertrag und stabile UID-Prüfung.
3. Die 13 übrigen ausführbaren Triggerfamilien bleiben offen, einschließlich der nur beobachteten Reliktaktivierung. Für Schaden/Angriff/Tötung fehlt die Quellenprovenienz; für Bedingungen fehlen Prädikate und Kanten-/Wiederholsemantik; für Draw/Discard/Bewegung fehlen abgestimmte Ereignisursachen.
4. `effect_processed` dient Beobachtung/Präsentation. Beliebige regeländernde Befehle aus externen Callbacks sind keine unterstützte Reaktionsmechanik und werden nicht in Proben kopiert. Reaktionen müssen künftig als validierte Queueeinträge mit Zeitfenster/Kosten modelliert werden. Der neue Fehler-/Ownershipschutz macht solche externen Befehle nicht zu einem fertigen Regelsystem.
5. Die produktive `Session` und ihr Replayformat instanziieren dieses Profil nicht. Vor einer Integration müssen Binding-Konfiguration und Profilversion im Setup gespeichert sowie bereits angenommene terminal fehlgeschlagene Befehle korrekt aufgezeichnet werden. Die bestehenden nativen Replays sind dadurch unverändert.
6. Kosten 9/10, neue Resonanzkosten, neue Kartenidentitäten, allgemeine passive/reaktive Fähigkeiten, 550 Autorenkarten und UI-Anbindung sind nachfolgende Pakete. Dieses Paket erhöht weder Energie noch Resonanzmaximum und verändert keinen aktiven Kartenpool.
