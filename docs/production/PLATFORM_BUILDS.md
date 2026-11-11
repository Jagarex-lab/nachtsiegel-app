# Native Plattformprüfungen

Der lokale Wrapper `tools/build_platform_qa.sh` erzeugt ausschließlich Debug-Exporte. Er veröffentlicht nichts und besitzt keine Store- oder Apple-Signaturberechtigung.

## Tatsächliche Korrektur am Exporttest

Das offizielle Godot-4.6.3-Linux-Debugtemplate unterstützt weder `--path` noch `--script`. Der erste Versuch wurde wegen `--path` ausdrücklich abgewiesen. Nach Entfernen dieses Arguments ignorierte das Template `--script` und blieb tatsächlich im Hauptmenü, bis der strikte 300-Sekunden-Timeout ablief. Dieser Versuch ist **kein bestandener Kampftest**.

Der reguläre `Linux QA`-Export behält daher das normale Hauptmenü. Sein tatsächlicher Start wird aus einem leeren Verzeichnis geprüft. Ein zweiter, ausdrücklich `Linux Runtime QA` genannter Export verwendet allein über das Custom-Feature `native_smoke_qa` eine kleine QA-Einstiegsszene. Sie lädt dieselben tatsächlich gepackten 550 Definitionen, vier Starter, Produktionsengine und KI; sie spielt eine vollständige Partie bis zum echten Endzustand. Der normale Web-, Android- und Linux-Start wird nicht umgeschaltet. Der Test ist im Paket enthalten und benötigt keine losen Skripte oder Ressourcen aus dem Checkout.

## Lokaler Entwicklungsnachweis

Am 10.11.2026 bestanden auf dem Entwicklungsstand nach `ae8478f` mit damals noch uncommitted QA-Einstiegsszene:

- Regulärer exportierter Linux-Spielstart ohne Script-/Ressourcenfehler.
- Eigenständiges natives QA-Programm: **12 Assertions, 0 Fehler**, eine tatsächlich beendete Partie Vielgestalt gegen Stillwacht, Seed 777, Sieg des Spielers nach 25 Halbzügen. Kein erzwungener Sieger oder verkürzter Schadenssimulator.
- Android-Debug-APK tatsächlich gebaut, mit `apksigner verify` geprüft; Manifest/Badging bestätigt ORAFOLD und die erhaltene Paketidentität `com.jagarex.nachtsiegel`.

Diese frühe Probe ist kein Nachweis eines späteren unveränderten Integrationscommits. Der Wrapper erfasst deshalb jetzt vor dem Export die SHA-256 der tatsächlichen Projekt-, Skript-, Szenen-, Daten- und Assetdateien, prüft sie nach dem gesamten Lauf erneut und speichert Commit, Dirty-Status sowie die Hashes beider Linux-Programme und der APK unter `work/production/platforms/results.json`. Vor Release wird der tatsächliche integrierte Stand erneut gebaut und geprüft.

```sh
DISPLAY=:99 tools/build_platform_qa.sh
```

Die aktuellen Ergebnisse sind Debug-/Paketprüfungen. Kein Android-Gerät oder physisches iPhone wurde getestet. Native iOS-Builds, Xcode, Provisioning, Store-Signaturen, Touch-/GPU-/Thermaltests auf Geräten und kommerzielle Auslieferung bleiben offen. Die WebKit-Browserprüfungen sind gesonderte automatisierte Browsernachweise und ersetzen diese Gerätetests nicht.

## Reproduzierbare native Plattform-CI

Der separate Plattformbaustein ergänzt zwei Windows-x86_64-Debugpresets. `Windows QA` behält den normalen Spieleinstieg, `Windows Runtime QA` verwendet dieselbe bereits vorhandene QA-Szene wie Linux. Es gibt keine zweite Testkampfengine. Der offizielle Debug-Konsolenwrapper reicht Parameter/Logs an das tatsächlich exportierte Windows-Programm weiter. Windows-Pakete werden auf einem Windows-Runner ausgeführt; ein PE-Header auf Linux wird ausdrücklich nicht als Windows-Laufzeitprüfung gezählt.

`tools/platform_qa.py` ist die gemeinsame Orchestrierung für Linux/Android und Windows. Sie prüft ELF64 beziehungsweise PE32+, das tatsächlich eingebettete Godot-V2/V3-PCK, die byteidentischen 550 Kartendefinitionen, Starter, Artmanifest und Schriftlizenzen. Versehentlich gepackte Checkout-/Test-/Buildpfade werden abgewiesen. Android erhält zusätzlich eine ZIP-/ABI-Prüfung beider tatsächlich enthaltenen nativen Bibliotheken sowie echte `apksigner verify`-/`aapt badging`-Aufrufe. Ein bewusst für diesen Lauf erzeugter Debugschlüssel ist keine Store-Signatur; Schlüssel und lokale Einstellungen werden nicht als CI-Artefakte hochgeladen.

Die reguläre Binärdatei wird strukturell geprüft und ausdrücklich mit `runtime_executed=false` ausgewiesen. Die zweite native QA-Ausführung instanziiert denselben tatsächlichen Shell-Menücode, prüft Lobby und vier Hauptaktionen und muss eine erfolgreiche echte Duellzusammenfassung einschließlich `main_menu_verified=true` liefern. Sie beendet sich über den vorhandenen Audioowner. Ein erzwungenes `--quit-after` würde diesen geordneten Shutdown umgehen und ist deshalb keine Ersatzprobe. Exitcode null allein reicht nicht. Scriptfehler, Ressourcenlecks, fehlende Ausgabe, falsche Engineversion, unvollständige Partien, Source-/HEAD-Wechsel und Timeouts verhindern einen bestandenen Bericht. Das bleibt eine native Headless-Prüfung und keine gerenderte Geräteabnahme.

```sh
tools/build_platform_qa.sh --platform linux-android
# Platzsparend für kleine Entwicklungscontainer: nach jeder tatsächlichen
# Prüfung Hash/Größe/Log erhalten und nur die erzeugten Binärdateien entfernen.
PLATFORMS_KEEP_BINARIES=0 tools/build_platform_qa.sh --platform linux-android

# Auf Windows, mit Godot4.6.3 und passenden Templates:
python tools/platform_qa.py --platform windows
```

Jeder Lauf erhält ein frisches Verzeichnis unter `work/production/platforms/run-*`. `results.json` benennt Status, tatsächlichen Commit, Quellhashes, Befehle, Laufzeiten, Binärhashes und den Aufbewahrungszustand der Dateien. In platzsparendem Modus bedeutet `retained=false`, dass kein lokaler Download dieser Datei behauptet wird. Generierte `.uid`-/`.import`-Metadaten sind von der Rohquellbindung getrennt; tatsächliche Skripte, Szenen, Definitionen, Illustrationen, Fonts und Exportkonfiguration werden vor und nach dem Lauf verglichen. Editor-Konfiguration/Cache sind pro Lauf getrennt, die installierte Template-Datensuche bleibt erhalten. Ausschließlich das bestehende QA-Custom-Feature verwendet den getrennten Benutzerordner `ORAFOLD_NATIVE_QA`; die regulären Spiel-/Webprofile behalten ihren bisherigen Namen und Pfad.

Der wiederverwendbare Workflow `.github/workflows/native-platform-qa.yml` ist Teil der Gesamtkonklusion von `web-preview.yml`. Ein fehlgeschlagener nativer Lauf kann deshalb nicht hinter einem grünen freizugebenden Haupt-QA-Lauf verborgen werden. Zusätzlich ist ein rein manueller Debugtest möglich. Beide Wege haben ausschließlich `contents: read`, keine Pages-/Deploymentberechtigungen und keine Store-Geheimnisse.

## Nachweisgrenzen dieses Bausteins

Die lokalen 14 Python-Testgruppen prüfen Paketparser, falsche Architektur, kaputte Offsets, fehlende Lizenzen, Source-/HEAD-Drift, fehlende/fehlerhafte Duellzusammenfassungen, Fehler-/Leakzeilen, Timeouts, erhaltene Template-Suche und die sequentielle Artefaktaufbewahrung. Ihre kleinen synthetischen ELF-/PE-/APK-Container sind ausdrücklich Metadatenfixtures und keine zusätzlichen nativen Partien. Separat wurde ein vorhandener echter Linux-Audioexport mit 551 PCK-Einträgen strukturell gelesen; seine 550 Kartendefinitionen, Starter und Lizenzdateien stimmten byteidentisch mit der zugehörigen Quelle überein. Dieser reine Lesetest ist keine erneute Programmausführung und belegt keinen Windows- oder Android-Lauf.

Erfolgreiche neue native CI-Läufe werden erst nach tatsächlichem Abschluss mit Run/Commit/Artefaktbindung als bestanden berichtet. Physische Android-/iPhone-Geräte, Xcode-/iOS-Signing, gerenderte Windows-GUI-/Touchtests, GPU-/Batterie-/Thermalmessungen und kommerzielle Store-Abnahme bleiben davon unabhängig offen.

Format-/Optionsgrundlage: offizieller Godot-4.6.3-Quellstand [PCK-Leser](https://github.com/godotengine/godot/blob/4.6.3-stable/core/io/file_access_pack.cpp), [Desktop-Export/Konsolenwrapper](https://github.com/godotengine/godot/blob/4.6.3-stable/editor/export/editor_export_platform_pc.cpp) und [Android-Assetexport](https://github.com/godotengine/godot/blob/4.6.3-stable/platform/android/export/export_plugin.cpp).

Der erste echte Plattform-CI-Versuch (Run `42935786627`, Merge-Prüfcommit `6d54fc90efb802b66aec6c21f222258882e7ed8f`) scheiterte vor einem erfolgreichen nativen Lauf: `setup-android@v3` forderte das nicht mehr verfügbare Standardpaket `tools` an; Windows konnte den extensionlosen `setup-godot`-Alias nicht per Python/CreateProcess auflösen. Die Konfiguration installiert jetzt explizit `platform-tools` und verwendet auf Windows die tatsächlich installierte offizielle `Godot_v4.6.3-stable_win64_console.exe` für Import und Export. Die 14 Parser-/Reportingtests liefen bereits auf Windows erfolgreich; das ist weiterhin kein bestandener nativer Spieltest. Ein neuer realer CI-Lauf muss diese Infrastrukturkorrektur bestätigen.

Der Folgeversuch `42936408997` bestätigte einen weiteren Windows-Infrastrukturfehler: Der Windows-Cache von `setup-godot@v2` sichert nur die Haupt-EXE und lässt deren offizielle Konsolenbegleitdatei aus. Dieser Cache wird im Windows-Job deaktiviert; `Get-Command` und eine tatsächliche EXE-Inventur dokumentieren die Installation vor dem Import. Der Linux-/Android-Job desselben Runs war erfolgreich (Details im nachfolgenden Nachweis); ein Windows-Pass ist damit noch nicht belegt.

## Tatsächlich bestandene CI-Plattformjobs

[Run 42937319265](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/42937319265) prüfte PR-Head `f5b5ab8eb6b5f1104cf457bbcb56a90130a6713c` über den tatsächlich ausgecheckten PR-Merge-Prüfcommit `02aafce6fe5554fdd70fc5e1af539e412cf32228`. Die beiden Plattformjobs waren erfolgreich:

| Prüfung | Tatsächlicher Nachweis |
| --- | --- |
| Windows Server 2025 | Regulärer PE32+-x86_64-Export und separater QA-Export mit eingebettetem PCK; tatsächliche Ausführung über den offiziellen Debug-Konsolenwrapper aus leerem Arbeitsverzeichnis |
| Linux Ubuntu 24.04 | Regulärer ELF64-x86_64-Export und separater QA-Export mit eingebettetem PCK; tatsächliche QA-Ausführung aus leerem Arbeitsverzeichnis |
| Beide native QA-Programme | Je **17 Assertions, 0 Fehler**, echte Partie Seed 777 bis Sieg `hero` nach 25 Halbzügen; tatsächliche Shell-Lobby und vier verbundene Hauptaktionen; geordneter Shutdown ohne Scriptfehler oder Ressourcenlecks |
| Android | Debug-APK tatsächlich exportiert; beide nativen ABI-Bibliotheken, ZIP-CRC, byteidentische Daten/Lizenzen, echte Debug-Signatur und Paketname/Label geprüft |
| Quellbindung | Rohquellen und HEAD während des gesamten jeweiligen Laufs unverändert; Windows protokolliert neu generierte `.import`-Metadaten gesondert |

[Maschinenlesbare Nachweise mit Binärgrößen, SHA-256, Job-/Artefakt-IDs und Grenzen](evidence/NATIVE_PLATFORM_QA_2026_11_11.json) halten die tatsächlichen Berichte fest. Die hochgeladenen `results.json` enthalten zusätzlich die vollständige Rohquellhashliste. Windows-Artefakt: [13818792220](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/42937319265/artifacts/13818792220); Linux-/Android-Artefakt: [13818558711](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/42937319265/artifacts/13818558711). Diese Debugdateien wurden nicht auf Pages oder in Stores veröffentlicht.

Dieser Plattformnachweis betrifft weiterhin den Kern mit **550 Kartendefinitionen und damals fünf individuellen Illustrationen**. Er bestätigt weder eine spätere Integration aller Illustrationen noch den damaligen Gesamtworkflow, dessen übrige Tests zum Nachweiszeitpunkt noch liefen. Nach Zusammenführung von Karten-, Audio-, Art- und UI-Änderungen ist der tatsächliche Integrationscommit erneut zu bauen und zu prüfen. Native Gerätetests und die oben genannten iOS-/GUI-Grenzen bleiben offen.
