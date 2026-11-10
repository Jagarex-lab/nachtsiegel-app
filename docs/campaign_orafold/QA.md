# Kampagnen-QA und Abnahmegrenzen

Stand: 10.11.2026. Godot 4.6.3, Linux, bestehende Projektbasis `develop` bei `17121e40a49838f479d1655d88d354ed836ad20e`. Technischer Prototyp, keine narrative Freigabe und keine Veröffentlichung.

## Reproduzierbare automatisierte Abnahme

```sh
bash tools/test_campaign_orafold.sh
```

Der Runner verwendet eigene XDG-Testverzeichnisse unter `work/campaign_orafold/xdg`, feste Seeds, Zeitlimits und einen Scanner für Script-/Assertionfehler. Die fünf Suiten nicht gleichzeitig im selben Arbeitsbaum starten: ihre isolierten Testprofile besitzen absichtlich feste Dateinamen.

| Suite | Assertions | Ergebnis |
|---|---:|---|
| Validator | 150 | Bestanden |
| Runtime / Entscheidungen / Speicher | 468 | Bestanden |
| Tatsächlicher Alpha-Kampfadapter und Kampfbedienung | 270 | Bestanden |
| Responsive Geometrie | 2.754 | Bestanden |
| Präsentationsintegration | 31 | Bestanden |
| **Gesamt** | **3.673** | **0 Fehler** |

Die Suiten prüfen gültige und gezielt fehlerhafte Inhalte: Kampagnen-/Kapitel-/Szenenreferenzen, fehlende Assets, Figuren, Status/Quellen, DE/EN-Textschlüssel, widersprüchliche lokale Flagbedingungen, unerreichbare Szenen, deterministische Endlosschleifen, zyklische Kapitelabhängigkeiten, fehlende Abschlusswege und unzulässige Kapitelübergänge. Beliebige bedingte Graphen sind kein allgemein gelöstes Erfüllbarkeitsproblem; neue verzweigte Kampagnen benötigen zusätzlich konkrete Durchlauftests.

Laufzeitnachweise umfassen vier Entscheidungsverläufe, persistierte Konsequenzen, alternative Abschlüsse, Sieg-/Niederlagenrückkehr, Wiederholungen, keine erneuten Belohnungen, verzögerte und doppelte Kampfergebnisse, private Wissenseinträge, Eira-Schutz, Sprachwechsel, unveränderlichen Originalrückblick und Rücksetzung temporärer Wiederholungsentscheidungen. Fehlerhafte Saves, Backupwiederherstellung, additive eigene v1-Migration, unbekannte zukünftige Versionen, ungültige verschachtelte Zustände sowie fehlgeschlagene Schreibtransaktionen werden geprüft. Fremde Arvess-/Alpha-Saves werden nicht migriert.

Der Kampfadapter gewinnt und verliert vollständige Partien über reguläre Befehle des unveränderten Alpha-Modells. Drei aktive Strategiedurchläufe liefern Niederlage/Niederlage/Sieg; ein passiver Durchlauf verliert ebenfalls. Kein Test setzt Lebenspunkte, Kartenwerte oder Gewinner künstlich. Aufgeben ist eine eigene bestätigte Nutzeraktion und liefert eine narrative Niederlage, ohne einen Enginegewinner zu fälschen.

## Mobile Darstellung

80 automatisch gemessene Kombinationen: 360×800, 390×844, 844×390 und 1280×720; Deutsch/Englisch; 100/130 Prozent Textgröße; Übersicht, Dialog, Rückblick, Charaktere und Einstellungen. Dazu kommen vergrößerte Entscheidungen und scrollbare Historie. Mindestgrößen, Containerbreite, Textumbruch und Scrollzugang werden an tatsächlichen Godot-Controls geprüft.

Native Screenshots wurden zusätzlich mit Mesa/llvmpipe auf einem virtuellen X11-Bildschirm gerendert und visuell geprüft. Die finale mobile Navigation verwendet zwei Spalten, damit lange deutsche Wörter lesbar bleiben. Kleine Querformatfenster verwenden geringere Ränder und kleinere Seitentitel; längere Inhalte bleiben scrollbar. Die Illustrationen sind eigene ausdrücklich vorläufige Vektoren. Keine physische Android-/iOS-Geräteabnahme.

## Regressionen bestehender Funktionen

| Bestehende Suite | Assertions | Ergebnis |
|---|---:|---|
| `tests/alpha_rules.gd` | 1.704 | 0 Fehler; 64 vollständige KI-Partien |
| `tests/alpha_replay.gd` | 173 | 0 Fehler; vier Legacy-/Alpha-Replays |
| `tests/narrative.gd` | 97 | 0 Fehler; alte Identität und Texte |
| `tests/experience.gd` | 707 | 0 Fehler; alter Einstieg, Tutorial, Kampagne, Sammlung, gespeicherter Neustart |

Die letzte Suite wurde gerendert mit `DISPLAY=:99 LP_NUM_THREADS=2`, die anderen kopflos ausgeführt. Logs liegen in `qa/`. Eine Mesa-VSync-Warnung betrifft den virtuellen Testbildschirm. Lokale Editor-Importe innerhalb der Sandbox melden gelegentlich verweigerte Editor-TCP-Sockets; die eigentlichen Tests enthalten keine Script-/Runtimefehler. Das ist kein Nachweis einer Geräte- oder vollständigen plattformübergreifenden Produktionsabnahme.

## Web-Export und CI

```sh
tools/build_campaign_orafold.sh
# Optional: CAMPAIGN_WEB_TEMPLATE=/absolut/web_debug.zip
# Testserver auf work/campaign_orafold/web starten, dann:
GAME_URL=http://127.0.0.1:8791/ node tools/campaign_orafold_browser_qa.cjs
```

Das Buildskript erstellt ausschließlich ein generiertes Stagingprojekt und einen lokalen QA-Export. Es ändert weder `project.godot` noch bestehende Exportprofile. Alle Kampagnen-JSONs einschließlich dynamisch geladener Übersetzungen werden explizit eingeschlossen. Die zusätzliche Workflowdatei `.github/workflows/campaign-orafold-qa.yml` hat ausschließlich Leserechte, Tests und Artefakte; keinen Deploymentpfad.

Lokaler Chromium-Lauf bestanden: **Desktop 1280×900/DPR 1 und Hochformat 390×844/DPR 2, 0 Fehler**. Ausschließlich echte Maus-/Touch-Eingaben starten Kapitel, scrollen Panels und treffen eine Entscheidung. Danach werden der lokale Spiegel, Neuladen, persistiertes Flag, sicherer Szenenpunkt und Fortsetzen geprüft. Die nur mit `?qa=1` angebotene Telemetrie liefert ausschließlich Messdaten; sie enthält keine Steuer- oder Ergebnisinjektion. Die Hochformatdarstellung verwendet CSS-Pixel statt unskalierten Geräte-Pixeln. Beleg: [browser-results.json](qa/browser-results.json).

Gemessener lokaler Start einschließlich QA-Metadaten: 3.806 ms Desktop, 2.884 ms Hochformat. Das ist ein Test auf diesem Rechner, kein Mobilfunk-/Gerätebenchmark. Der nicht optimierte Debugexport umfasst ungefähr 35 MiB WASM und 12 MiB PCK; das finale Download- und Speicherbudget muss bei Produktintegration geprüft werden.

Die Browserprüfung fand und korrigierte fünf Probleme, die im reinen Geometrietest unsichtbar waren: falsche benutzerdefinierte Thread-Vorlage, Prüfung importierter Bildressourcen über deren nicht mehr vorhandene Quelldatei, boolesche Rückgaben der Web-Speicherbrücke als numerische Varianten, abgefangene Touch-Wischgesten dekorativer Panels und synchrone Widgetentfernung während der Touch-Ereignisweiterleitung. Finale Gegenmaßnahmen: `web_nothreads_debug.zip`, `ResourceLoader.exists`, explizite bool-Konvertierung, durchlässige Panels und zusammengefasster verzögerter UI-Neuaufbau. Die anfänglichen Fehlbelege sind unter `qa/*-error.json` erhalten; sie beschreiben korrigierte Befunde. Der abschließende Lauf hat keine Konsole-/Scriptfehler.

Getestete Quellkorrekturen sind in `206ae9d` enthalten; die folgenden Dokumentationsänderungen verändern diese Quellbytes nicht. Der lokale Export entstand vor dem abschließenden Quellcommit und nennt daher in seinen Buildmetadaten den damaligen HEAD. GitHub CI baut aus dem finalen PR-Commit neu. Lokale grüne Läufe werden nicht als bereits grüne GitHub-Läufe ausgegeben.

## Was die Abnahme nicht behauptet

Keine Freigabe der ORAFOLD-Hauptgeschichte, endgültiger Figurenbilder, wirtschaftlicher Belohnungen oder offener Weltgeheimnisse. Keine Integration in die produktive Navigation, das vorhandene Inventar oder die Audiozuordnung. Kein Cloudsync und kein Fortsetzen mitten im Kampf: nach Neustart beginnt die ausstehende Begegnung reproduzierbar am gespeicherten Vorkampfpunkt. Für iOS, physische Mobilgeräte, Screenreader, professionelle Textredaktion und finales Performancebudget bleiben gesonderte Abnahmen erforderlich.
