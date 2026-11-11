# ORAFOLD – Produktionsstand und Abnahmegrenzen

Quellengebundener Vorbereitungsbericht. Der spätere veröffentlichte Stand ist ausschließlich über das öffentliche `build-info.json` und den erfolgreichen manuellen Deploymentlauf feststellbar; dieser Bericht behauptet keinen zukünftigen Release.

Stand: 11. November 2026. Geprüfter Dokumentations-/Integrationsstand: `945f57070a0b6756bea865c283df8727887ba726`, [PR23](https://github.com/Jagarex-lab/nachtsiegel-app/pull/23), weiterhin Draft. Die Runtime-Dateien unter `scripts`, `data`, `scenes`, `assets` sowie Projekt-/Exportkonfiguration sind gegenüber `0f346b0df29ad1098e92088c65e2e8c5fc1e6297` unverändert. Ein vollständig grüner gemeinsamer Abnahmelauf dieses Integrationsstands ist hier noch nicht belegt; Browser-QA-Korrekturen und abschließende CI stehen aus.

**Bei der Bestandsaufnahme lief öffentlich Alpha 0.2 auf `fde508e85a2866e24653ef25d920a59832d2d653`.** Das öffentliche [build-info.json](https://jagarex-lab.github.io/nachtsiegel-app/build-info.json) lieferte diesen Commit am 11.11.2026 um 03:45 UTC mit HTTP 200. Der neue Produktionsstand war zum genannten Messzeitpunkt nicht veröffentlicht.

## Tatsächlich implementiert

- **550 aktive Karten**, genau 110 je Macht und Neutral: 357 Wesen, 133 Impulse, 60 Relikte; 500 generische Definitionen und 50 ausdrücklich native Handler. Sammlung, Filter, Inspektion, vier Starter und validierte 30-Karten-Decks benutzen diesen aktiven Pool.
- **550 individuelle Originalillustrationen und 550 mobile Vorschauen**, 550 visuell freigegebene Zuordnungen, keine fehlenden oder verwaisten Bilder laut eingechecktem Manifest. Unveränderte Originale, tatsächliche native Abmessungen, Prompts, Hashes, Referenzen und Bearbeitungsspuren sind dokumentiert. Quellenmanifest: `6eafb4bdf0852dd0ecc0e3f7211e915e718955607e31babab54e3d52c891f6ef`.
- **Ein Produktionskernel auf dem bestehenden Alpha-/Legacy-Kernel:** zwölf Effektkategorien, 16 automatische Triggerfamilien, stabile Quellen-/Zielinstanzen, FIFO, Kosten, Reliktwechsel, verzögerte Effekte und atomare Ablehnung illegaler Befehle. Reaktive Impulse haben automatische erklärte Auslösefenster. Der unterstützte passive Effekt ist Eile; aktivierte Fähigkeiten sind derzeit Reliktfähigkeiten.
- **Standardressourcen bleiben 8 Energie / 15 Resonanz.** Fünf Pfade, Angriff auf den Helden bei leerem Gegenpfad, Block vor Schild vor Leben sowie LP- und Konvergenzsieg bleiben erhalten. Die verglichenen 10er-Energieprofile sind Testbedingungen.
- **Bereinigung durch Trennung und Migration:** Die reguläre Sammlung lädt ausschließlich den Produktionspool. Alle 55 alten Alpha-IDs bleiben erhalten; elf Produktionsfassungen wurden ausdrücklich geändert. Original-Alpha, 100 Legacykarten und sieben Prototypkarten bleiben für historische Regeln, Replays und Regressionen erhalten. Physische Quelllöschungen: null. Ungültige Altdecks werden mit Originaldaten quarantänisiert.
- **Einsteigerhilfe und Bedienung:** In Einstellungen existiert der sechsteilige Dialog „ORAFOLD · ERSTE PARTIE“ mit Regel-/Touchhinweisen und Ressourcenhilfe. Spielfeldmulligan, Ursprung, zweite Möglichkeit, Tap/Drag, Abbruchschutz und kurze Rückmeldungen sind implementiert. Das belegt keinen neuen geführten Tutorialkampf oder freigegebene ORAFOLD-Kampagne. Lokale Profile und Replays sind vorhanden; Fortsetzen eines laufenden Kampfes nach OS-Prozessabbruch bleibt offen.

## Tatsächlich ausgeführte, jeweils quellengebundene Teilnachweise

| Bereich | Vorliegender Nachweis und Grenze |
|---|---|
| Regeln und Trigger | Engine: 4.425 Assertions, 940 Fähigkeitsfixtures, 1.100 arrangierte Ausspielbefehle für alle Karten/beide Seiten. Ergänzend 44 Printed-Semantics-, 456 Kill-Watcher- und 799 Delayed-Assertions ohne Fehler. Arrangierte Grenzen sind keine vollständigen Partien. Historische Vorherfehler bleiben erhalten. |
| Referenz-Selbstspiel | 848 vollständig beendete Partien, 18 Wiederholungen, 2.688 Prüfungen, null Fehler/Zensierung; Anker `5cd7d8a`, Rohdaten-SHA `5315796e48eb14c9428a0efb8f9a89f1ce2f4b9a928a8e396ea6241eba0da6d8`. Tatsächlich 176 verschiedene IDs ausgespielt. |
| Breitere Pool-Stichprobe | Separat 256 vollständige Partien, acht Wiederholungen und vier frische Konstruktoren, 1.666 Prüfungen ohne Fehler/Zensierung, Quellencommit `96c5028`. Die 32 legalen Decks enthalten alle 550 IDs; tatsächlich ausgespielt wurden **546/550**. Nicht ausgespielt: `oa-houses-r01`, `of-houses-068`, `of-houses-100`, `of-morph-095`. Keine Behauptung vollständiger Interaktionsabdeckung. |
| Ressourcenvergleich | 192 gepaarte Partien plus zehn Kontrollen, 1.435 Prüfungen ohne Fehler. Alle 64 Standardpartien bestätigen vollständige Zustands-/Ereignisdigests der korrigierten Pre-Getter-Baseline. Empfehlung: 8/15 behalten. |
| Aktuelle Web-Komponenten | Export `0f346b0`: PCK 17.160.176 Bytes, SHA-256 `bbeeb2dd6602bfc740e76de466a582622170552366775485ba3d4c97f41dc4fd`; isolierte PCK-Inventur 5.535/0, genau fünf gepackte Vorschauen und keine Full-Texturen. Zehn tatsächliche Art-Transportkontexte Chromium/WebKit bestehen 294/0 einschließlich eigener Abbrüche. Ein Desktop-Duell besteht mit 45 Befehlen, acht chronologischen Bildern, tatsächlichem Replay/Neustart und null Browserfehlern. Der heruntergeladene Replay bestätigt zusätzlich 11/0 mit 412 geordneten Ereignissen. Lokale Komponentenbelege ersetzen die finale gemeinsame CI nicht. |
| Bildauslieferung | Der ausdrücklich ältere Art-Stand `e6ba759` bestand 284 Browser-Assertions in zehn Chromium-/WebKit-Kontexten sowie 3.878 isolierte Web-PCK- und 5.513 native Art-Paket-Assertions. Erfolgs-, Offline-, Korruptions-, Größen-, Redirect- und Abbruchpfade wurden tatsächlich geprüft. Das ersetzt die neue gemeinsame Integrations-CI nicht. |
| Native Plattformen und Audio | CI `42949575160`, Prüfcommit `2db3b5e` über Head `0f346b0`, enthält bereits alle 550 Bilder und Audio: Windows und Linux führen je einen tatsächlichen exportierten QA-Durchlauf mit Shell und vollständiger Partie aus, je 29/0. Android-Debug-APK besteht Signatur-/ABI-/CRC-/Datenprüfung. Der native Art-PCK besteht 7.715/0 und dekodiert 550 Full-/550 Vorschautexturen. Der vollständige Audiojob besteht ebenfalls einschließlich echter Produktmenüs und -partie. [Job-/Artefakt-/Hashbelege](evidence/INTEGRATION_COMPONENTS_0F.json). Der Gesamtworkflow dieses Vorlaufs bleibt wegen der separaten Browserfehler ausdrücklich fehlgeschlagen. |

Die genauen Quellen und Reproduktionswege stehen in `EFFECT_ENGINE.md`, `KERNEL_SEMANTICS_REVIEW.md`, `BALANCE_REPORT.md`, `full-pool/FULL_POOL_COVERAGE.md`, `RESOURCE_MODEL_EXPERIMENT.md`, `ART_550_DELIVERY.md` und `PLATFORM_BUILDS.md`. Historische Teilnachweise werden nicht als neue gemeinsame Tests gezählt.

## Grenzen vor einer endgültigen Freigabe

Die Referenzmatrix zeigt **63,4 % Startspielersiege**, Block **14,3 %**, Schild **33,0 %** und Relikt **73,2 %**. Eine vollständige oder menschlich geprüfte Balance ist damit nicht nachgewiesen. Die längste natürliche generische Queue dieser Matrix beträgt fünf; die separate Zehn-Effekt-FIFO-Probe belegt Enginefähigkeit. Eine kleine lokale Deck-/KI-Folgestudie ist kein übernommener Produktionsfix.

Alle 550 Bilder besitzen eine dokumentierte visuelle Erstprüfung. Der zusätzliche Kontaktbogenpass sah alle 550 Vorschauen und öffnete 22 ausgewählte Originale; Root prüfte zusätzlich 275 Vorschauen. Das ist keine unabhängige zweite Vollprüfung aller Originalpixel. **Kommerzielle Bildfreigaben: 0/550**; Anbieterbedingungen, einzelne Motive und Produktname bleiben Gegenstand der Auftraggeberprüfung. Szenen/Lorevorschläge werden durch Bildfreigabe nicht kanonisch.

Physische Android-/iPhone-Tests, native iOS-Erstellung/Signierung, gerenderte Windows-Geräteabnahme und Geräte-Memory-/Thermalmessungen bleiben offen. Browserprofile sind Emulation. Vollbilder werden bedarfsgesteuert nachgeladen; Dateisummen sind keine Messung des initialen Transfers oder gesamten Gerätespeichers.

Vor Veröffentlichung fehlen der vollständige grüne Lauf des endgültigen gemeinsamen Commits einschließlich der noch korrigierten Browser-QA, dessen belegte Artefakte und die tatsächliche öffentliche Nachprüfung nach dem bewachten manuellen Release. Ein grüner Vorläufer, PR-Merge oder Branch-Push veröffentlicht nichts. Die ausdrückliche Nutzerfreigabe für getestete Integration und den manuellen Testrelease liegt vor. Der vorhandene Releaseprozess bleibt verbindlich; eine zweite Reviewer-Identität wird nicht verlangt und aktive GitHub-Schutzregeln werden nicht umgangen.


## Nachweis der Web-Testkorrekturen

Der tatsächliche CI-Lauf [42949575160](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/42949575160) auf PR-Head `0f346b0` (ausgecheckter Merge-Prüfcommit `2db3b5ec8fef286a492fa6a32ab71b772c86cd42`) bestand Native-Export, Windows-/Linux-/Android-, Audio-, Art-Paket-/Transport-, Ressourcen- und vier Balance-Shardprüfungen. Chromium bestand alle vier regulären Alpha-Profile, Rotation und 177 echte Upgrade-/Stale-Tab-/Quotaprüfungen. Der Gesamtworkflow war trotzdem **fehlgeschlagen**: WebKit prüfte einen noch veralteten Lobby-Snapshot vor dem abgeschlossenen Builderwechsel; Master550 verglich die alphabetisch serialisierten Action-Dictionary-Schlüssel mit der abweichenden Anzeige-Reihenfolge derselben zwölf IDs. Beide Fehler bleiben als fehlgeschlagene Vorläufe dokumentiert. Die neuen Tests warten auf die tatsächliche Zielseite und gemessene Canvas-Geometrie; die Deckgröße-30-Prüfung bleibt bestehen. Die Kartenprüfung vergleicht exakte eindeutige Mitgliedschaft, ohne die Anzeige-Reihenfolge zu verändern; fehlende, zusätzliche und doppelte IDs werden weiterhin abgewiesen. Eine weitere echte Scroll-Timing-Grenze wird separat korrigiert und muss erneut geprüft werden.

## Getrennte Simulationsstichproben


Die vorhandenen Nachweise sind getrennte, quellgebundene Läufe:

| Nachweis | Matrixpartien | Kontrollpartien | Ausführungen dieses Laufs |
|---|---:|---:|---:|
| Strategie-/Startermatrix | 848 = 784 Strategie + 64 Starter | 18, darin 8 frische Konstruktoren | 866 |
| Ressourcenvergleich | 192 = drei Profile mit je 64 Fällen | 10 = 6 Wiederholungen + 4 frische Konstruktoren | 202 |
| Full-Pool-Sampler | 256 | 12 = 8 Wiederholungen + 4 frische Konstruktoren | 268 |

Alle drei dokumentierten Läufe melden null Fehler und keine zensierten Matrixpartien. Die gepaarten beziehungsweise überlappenden Fälle werden nicht als unabhängige Gesamtstichprobe addiert. Historische Pre-Semantik-Läufe und der separate identische 848er-Wiederholungslauf zählen ebenfalls nicht zusätzlich.

Die Referenzmatrix spielte 176 verschiedene IDs aus. Im Full-Pool-Sampler enthielten 32 legale Decklisten gemeinsam alle 550 IDs; tatsächlich erfolgreich ausgespielt wurden **546/550 IDs in 8.914 Matrix-Ausspielkommandos**. Die 343 Ausspielkommandos der Kontrollen bleiben aus dieser Coverage-Zählung ausgeschlossen. Nicht ausgespielt wurden `oa-houses-r01` (Ahnenregister), `of-houses-068` (Zurück ins Licht), `of-houses-100` (Die offene Chronik) und `of-morph-095` (Häutungsklinge). Listenmitgliedschaft oder Beschwörung gelten nicht als Ausspielnachweis. 19 negative Nachweiswächter und fünf separat gekennzeichnete Health-Kopienprüfungen bestätigen Integrität und ehrliche FAILED-Berichte; sie sind keine weiteren Partien oder beobachteten Enginefehler.

**Quellenbindung des Integrationsstands:** Im geprüften Baum `445686d86d787619611620a6ed1faedfe38a0e17` stimmen alle **20** eingefrorenen Full-Pool-Quelldateien byteidentisch mit dem ausgeführten Commit `96c5028a91fd86f5b0e875bf1a7fab31c5f4f4f4` überein. Insbesondere:

- Produktionsmodell: `11b384202d75ab490df16bda95d93cd611be62241afce9d626e3883b8ab25ca5`
- Produktionskarten: `161384024ba4ba4ad78994adfb203eaa49c6fd222916285e6d9338f5f19f53b7`

Die späteren Unterschiede betreffen Präsentation, UI, Audio, Artwork, QA-Beobachtung und Auslieferung; keine der 20 gebundenen Dateien ist verändert. Die geprüften Audio-Beobachter lesen bereits aufgelöste Ereignisse; die ergänzten QA-/Artwork-Seams ändern keine Modellregeln. Damit bleibt der Modell-Selbstspielnachweis auf diesen Runtime-Bytes gültig. Dies ist ein lesender Quellenvergleich, kein neuer Gesamtintegrationslauf; GUI-, Audio-, Bildtransport-, Export- und Browsernachweise bleiben separat erforderlich.

Die archivierte 848er-Matrix bindet noch Pre-Getter-Bytes. Der Ressourcenlauf bestätigt die **64** Standard-Starterfälle mit vollständigen Zustands-/Ereignisdigests gegen diese Baseline; daraus wird keine erneute Ausführung aller 848 Fälle mit den finalen Getter-Bytes abgeleitet. Energie/Resonanz bleiben im normalen Spiel bei **8/15**; höhere Limits existieren nur in der Test-Subclass.

Diese deterministischen KI-/Deck-/Seed-Stichproben belegen weder menschliche Balance noch alle Fähigkeiten oder Interaktionen sämtlicher 550 Karten. Ressourcenwerte sind qualifizierte Aktionsgrenzen-/Nettobeobachtungen, keine vollständige Bruttoflussbilanz; Headless-Wandzeiten sind kein Nachweis für Browser-FPS oder Renderleistung.

Nachweise: `docs/production/simulation-results.json`, `RESOURCE_MODEL_EXPERIMENT.json` und `full-pool/FULL_POOL_COVERAGE.json`. Zugehörige Rohdaten-SHA-256:

- 848er-Matrix: `5315796e48eb14c9428a0efb8f9a89f1ce2f4b9a928a8e396ea6241eba0da6d8`
- Ressourcenlauf: `d64fcb5368b1412ed6ca05b3370557fe7586b6f441e8f7b92678f94e49e9f676`
- Full-Pool: `ced1294a2eb14b008bfb13ed5ae6a274e1d226c6776a25b42a241f6b3743c112`
