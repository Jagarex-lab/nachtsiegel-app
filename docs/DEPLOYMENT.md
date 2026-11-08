# Getestete Webversion automatisch veröffentlichen

Am 08.11.2026 hat der Nutzer ausdrücklich freigegeben, die getestete Webversion künftig direkt auf der bestehenden Spielseite bereitzustellen. Die bisherige Beschränkung auf QA-Artefakte ist damit für die Webversion aufgehoben.

Spieladresse: https://jagarex-lab.github.io/nachtsiegel-app/

1. Auf einem Entwicklungsbranch implementieren und prüfen.
2. Workflow `NACHTSIEGEL Test and Publish`: Godot-Import, Regelprüfung, echte GUI-/Touch-Ereignisse, Querformat-Screenshots und Webexport ausführen.
3. Den exportierten Build in zwei Browsergrößen testen. Der Build enthält `build-info.json` mit Commit und Run-ID; die Browserprüfung vergleicht den erwarteten Commit.
4. Den geprüften Feature-Stand nach `develop` integrieren. Auf `develop` laufen dieselben Prüfungen nochmals, danach wird genau das geprüfte Build-Verzeichnis als Pages-Artefakt veröffentlicht.
5. Die öffentliche Spielseite wird anschließend in zwei Browsergrößen samt Touch-Zugende und erwartetem Commit geprüft. Screenshots und Ergebnisse liegen im Workflow-Artefakt `nachtsiegel-live-qa`.

Ein fehlgeschlagener Test verhindert die Bereitstellung. Die bestehende Pages-Umgebung erlaubt `develop`; ihre Schutzregeln bleiben erhalten. Pull Requests und der Featurebranch veröffentlichen nichts. `main` bleibt unverändert.

Die Spieldateien tragen den Commit im Dateinamen. Der ausgelieferte Einstieg heißt weiterhin `index.html`. Dadurch lädt Safari für eine neue Version neue JS-, WASM- und PCK-Dateien. Ein Versionsparameter am direkten Spiel-Link umgeht zusätzlich einen eventuell zwischengespeicherten HTML-Einstieg.

Native iOS-/Android-Gerätetests und Store-Veröffentlichungen sind davon unabhängig. Die ursprünglichen Einschränkungen stehen im [QA-Bericht](QA-2026-11-08.md).
