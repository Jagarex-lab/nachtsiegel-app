# Unabhängige Integrationsprüfung des ersten 550er-Meilensteins

Stand: 10.11.2026. Geprüft wurden der Arbeitsstand auf Basis `782a41cf9ec4fba270923fd8c63cdfc35c9f7494`, die neuen `scripts/card_system`-Module, Daten-/Testverträge, Exportfilter sowie CI-/Releasepfade. Nachfolgende Korrekturen benötigen die erneute CI auf ihrem tatsächlichen Integrationscommit. Dies ist **keine pauschale Freigabe des 550-Karten-Auftrags**.

## Konkrete Befunde und Maßnahmen

| Priorität | Befund | Maßnahme / Nachweis |
|---|---|---|
| P1, vor Verteilung wiederholt lokal erstellter Builds | `tools/build_alpha.sh` exportierte erneut direkt in dasselbe Verzeichnis. Tatsächlich lagen dort sieben historische Commitpräfixe und rund 314 MB statt eines einzelnen Kandidaten. Das ZIP-Programm filterte bereits korrekt auf den aktuellen Präfix, das Kopieren/Hochladen des vollständigen Verzeichnisses tat dies jedoch nicht. | Behoben durch ein frisches Stagingverzeichnis. Erst erfolgreicher Export, nichtleere PCK/WASM/JS-Dateien, native Paketinventur und Metadaten erlauben den Austausch. Der bisherige Kandidat bleibt bei Export-/Paketfehlern vollständig erhalten. Der letzte lokale Verzeichnistausch besitzt einen Wiederherstellungspfad. Fünf isolierte Dateisystem-/Fehlerpfadtests bestehen; sie simulieren den Exporter ausdrücklich und sind kein Godot-Buildnachweis. Ein anschließender echter Export bleibt erforderlich. |
| P1, vor einer Behauptung vollständiger Release-QA | Die Ressourcensimulation lief zunächst nur im separaten Alpha-QA-Workflow. Der bestehende Pages-Guard akzeptiert ausschließlich einen erfolgreichen `web-preview.yml`-Lauf. Dessen Erfolg belegte daher zunächst keinen Ressourcenversuch auf dem später veröffentlichten Commit. | Im aktuellen Arbeitsstand ruft nun auch `web-preview.yml` den gemeinsamen `tools/test_master550_resources.sh` auf. Der Prüfer verlangt reale Erfolgsassertions, 192 Matrixpartien, sieben zusätzliche Verifikationspartien und 192 vollständige Datensätze. Die tatsächliche CI dieses Arbeitsstands steht bei dieser Prüfung noch aus. |
| P2, CI-Stabilität | Der neue native Wrapper hatte zunächst weder eine individuelle Laufzeitgrenze noch eine begrenzte Software-Renderer-Threadzahl. Ein hängender Szenentest konnte den gesamten Job bis zum Workflowlimit blockieren. | `tools/test_master550.sh` setzt nun standardmäßig `LP_NUM_THREADS=2` und `GODOT_TEST_TIMEOUT=600s` pro Suite. Der echte GUI-Lauf benötigt unter Last etwa vier Minuten; die Grenze lässt dafür Reserve. Ein während eines lokalen Laufs parallel geänderter Wrapper endete nach drei erfolgreichen nativen Tests mit Shell-Exit 2; dies war kein erfolgreicher Gesamtlauf. Nach Abschluss der Änderungen muss der unveränderte Wrapper erneut laufen. |
| P2, Browser-Gate | `tools/master550_browser_qa.cjs` entstand parallel. Die ersten CI-Stände riefen nur die bisherigen Alpha-/Alpha02-Browsertests auf. Damit war neue spezifische Drag-/Mulligan-Browserprüfung noch kein Release-Gate. | Vor einer entsprechenden Erfolgsbehauptung muss der neue Browserlauf auf dem tatsächlichen Export in den releasebestimmenden Workflow aufgenommen werden und bestehen. Frühere Browsererfolge sind kein Ersatz für diesen Nachweis. |

## Geprüfte Verpackung und Berechtigungsgrenzen

Die Erweiterung von `export_presets.cfg` nimmt `data/card_system/*.json` in alle vorhandenen Exportprofile auf. Das ist notwendig: Der Adapter liest die Registry zur Laufzeit über `FileAccess`, und solche JSON-Dateien sind keine automatisch importierten Texturen oder Szenen.

Die tatsächlich bereits erzeugte Paketinventur `work/alpha/package-inspection.log` enthält alle sechs neuen JSON-Dateien, die drei neuen Skripte als Bytecode und deren Remaps. Sie meldet **null verbotene Ressourcen** aus `work/`, `tests/`, `tools/`, `docs/` oder `node_modules/`. Das belegt den untersuchten lokalen Export; Änderungen an Filter oder Dateien benötigen eine neue Inventur. Die Stagingkorrektur baut dieselben Ressourcen in ein frisches Verzeichnis und verändert keine Exportinhalte absichtlich.

Beide geprüften Testworkflows besitzen nur `contents: read`. Es wurde kein automatisches Pages-Deployment hinzugefügt. Die Veröffentlichung bleibt ein separates `workflow_dispatch` mit vollständigem develop-SHA, erfolgreichem exakt passendem develop-QA-Lauf, SHA-Bestätigung und den tatsächlich aktiven GitHub-Environment-Regeln. Der Guard prüft den gesamten Erfolg von `web-preview.yml`, nicht nur einen einzelnen nativen Test. Direkte Pushes oder PR-Ereignisse allein veröffentlichen weiterhin nichts. Diese Quelltextprüfung beweist nicht, welche Repository-/Environment-Einstellungen GitHub aktuell aktiviert hat; dafür bleibt die tatsächliche Releasevorprüfung verbindlich.

## Capability- und Inhaltsprüfung

Es wurde keine Behauptung gefunden, dass 550 neue Karten bereits implementiert oder ausbalanciert seien. Der aktive Pool bleibt bei 55 Alpha-Karten. Acht zusätzliche V2-Datensätze sind Ansichten bestehender stabiler Identitäten, keine acht neuen Karten. Der Legacy-Pool bleibt eine getrennte Referenz. Der strikte Datenprüfer meldet für den isolierten V2-Piloten weiterhin `runtime_playable: 0`.

Der neue Runtime-Adapter meldet korrekt 25 explizit ausführbare Effektadapter, eine zusätzliche quellengebundene Beschwörungsprimitive, 16 **erkannte** Auslöser-IDs und `production_wired=false`. Die 16 IDs sind kein Beleg für 16 automatische Kampf-Hooks. `pierce`, `shift`, `retaliate`, `haste` und der noch quellenlose deklarative Effekt `summon(count)` bleiben in dieser generischen Schnittstelle ausdrücklich unsupported. Ihre bestehenden Alpha-/Legacy-Implementierungen werden dadurch nicht entfernt.

Die 1.000er-Schranke gilt für Einträge der Adapterqueue. Delegierte native Unterqueues haben weiterhin ihren eigenen ursprünglichen Schutz; ein Echo-Bündel zählt nicht fälschlich als vollständig in diesem 1.000er-Budget enthalten. Das Dokument `EFFECT_FOUNDATION.md` benennt diese Grenze und die Verantwortung des internen Aufrufers für echte Auslöser und stabile Ereignis-IDs.

Der Kartenrenderer erzeugt eine gemeinsame 63:88-Außenkontur und verwendet die bestehenden Bildressourcen. Fehlende Einzelbilder werden sichtbar als geteilte Konzepte bezeichnet. Eine vorhandene Datei mit `final`-Metadaten wird technisch geladen, erhält dadurch aber weder künstlerische noch rechtliche Freigabe. Die Dokumentation unterscheidet das ausdrücklich. Die bestehende Atlasauflösung bleibt eine Bildgrenze; die Vollkarte wird nicht als neu erzeugte hochauflösende Illustration ausgegeben.

## Tatsächlich vorliegende Testnachweise

Im Review eigenständig ausgeführt:

- **37/37 Node-Tests** für Alpha-Kartentexte und den V2-Vertrag.
- **8/8 bestehende Release-Sicherheitstests**.
- **5/5 neue isolierte Stagingtests**: fehlgeschlagener Export, fehlgeschlagene Paketprüfung, fehlende Exportdatei, fehlgeschlagener letzter Verzeichnistausch mit Wiederherstellung, erfolgreicher Austausch ohne historische Präfixdateien. Keine dieser Prüfungen startet einen echten Exporter.
- `bash -n tools/build_alpha.sh`; keine Shell-Syntaxfehler.

Die gelesenen nativen Artefakte des aktuellen Gesamtlaufs belegen **314 Adapter-, 374 Kartenrender- und 852 Opening-/Touch-Assertions**, jeweils null Fehler. Der Adapterlauf wurde außerdem während seiner Entwicklung selbst mehrfach real mit Godot 4.6.3 headless ausgeführt. Die drei aktuellen Ergebnisdateien allein heben den dokumentierten fehlerhaften Wrapper-Abschluss nicht auf; für die Integrationsfreigabe zählt dessen Wiederholung nach eingefrorenen Änderungen.

## Noch offene Risiken und Abnahmebedingungen

1. Der abschließende Commit benötigt vollständige Legacy-/Alpha-Regression, den unverändert gestarteten neuen Wrapper, die Ressourcensimulation, den echten Export und beide Browserengines. Diese Prüfung autorisiert keinen Merge aufgrund älterer grüner Commits.
2. Der neue Browserlauf muss das exportierte Spiel über tatsächliche UI-Eingaben prüfen. Ein direkter Aufruf des internen Effektadapters oder eine künstliche Modellfixture ist kein iPhone-Interaktionstest.
3. Physische iPhone-/Android-Tests liegen für diesen Review nicht vor. Linux-Rendering und Playwright-WebKit dürfen nicht als solche ausgegeben werden.
4. Vollständige automatische Triggerintegration, neue Kartenquellen/-kosten, passive und reaktive Fähigkeiten, 550 individuelle Karten, neue Arten-Testdecks und belastbare Gesamtbalance bleiben offen. Dieser Meilenstein bewahrt die vorhandene Spielbarkeit und liefert getestete Grundlagen/UI, nicht die Gesamtabnahme.
5. Ein Stagingaustausch ist ein kontrollierter lokaler Verzeichnistausch, keine Freigabe oder Aktivierung eines produktiven Releases. Die tatsächliche Pages-Veröffentlichung und anschließende Live-Browserprüfung bleiben gesondert nachzuweisen.
