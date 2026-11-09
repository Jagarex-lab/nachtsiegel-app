# ORAFOLD Alpha 0.1 – spielbarer Entwicklungsstand

Stand: 2026-11-09. Phase A ist ausdrücklich autorisiert; dies ersetzt den historischen administrativen Implementierungsstopp. Branch `alpha/playable-0.1`, Draft-PR [#8](https://github.com/Jagarex-lab/nachtsiegel-app/pull/8). Keine Integration in develop, kein produktiver Release.

## Tatsächlicher Umfang

- Getrennt auswählbare Profile: fixiertes Legacy mit 100 Originalkreaturen/fünf Originaldecks sowie ORAFOLD Alpha mit 55 eigenständigen IDs/vier 30-Karten-Startern. Keine automatische Vermischung mit den sieben Archiv-Prototypkarten.
- Vollständige lokale Partien gegen deterministische KI, drei Schwierigkeitsstufen, sichtbare Ressourcen, fünf Pfade, Hand, Ablage, freie Pfade → geschützter Heldentreffer, Ergebnis und Neustart.
- Alpha: 30 LP, fünf Starthandkarten, Mulligan, Ursprung, Zweite Möglichkeit, Energie bis8, ein aktives Relikt, Ereignisse und erklärte Konvergenz. Siehe [Regeln](RULES.md).
- Sammlung/Deckbuilder: Suche, Macht/Typ/Kosten/Seltenheit, Kopienlimits, hinzufügen/entfernen, ungültige Decks ablehnen, lokale Speicherung/Neustart. Alle Testkarten sind freigeschaltet; keine Besitzökonomie simuliert.
- Native versionierte Replays mit vollständigen Zustandshashes, JSON-Export/Verifikation und schrittweiser Ansicht; keine behauptete Kompatibilität mit dem alten JS-Auditformat.
- Neuer Desktop-/Mobile-Einstieg und Arena, echte Touch-Kommandos, Safe-Area-/DPR-Behandlung, Karten-Großansicht, Ereignisfeedback und reduzierte Bewegung. Vorhandene Atlasbilder sind ausdrücklich Platzhalter.

## Architektur

`data/alpha/cards.json` ist der Alpha-Katalog. `scripts/alpha/catalog.gd` validiert Decks. `model.gd` erweitert den bestehenden Legacy-Kernel über eng begrenzte Hooks; der unveränderte Standardvertrag bleibt durch Oracle-Vergleiche abgesichert. `scripts/legacy/opponent.gd` ist die Original-KI; die Alpha-KI bleibt im eigenen Modell. `session.gd` verwaltet Commands, Replay und eine eigene lokale Profildatei. `shell.gd`, `card_view.gd` und `feedback.gd` projizieren nur angenommene Modellaktionen. Präsentationsjobs sind begrenzt; die logische Effektqueue wird nicht visuell abgeschnitten.

Der Archivmodus bleibt erreichbar; `alpha_build` startet den neuen Einstieg. `Alpha Web QA` ist ein separates Exportpreset. Keine zweite Legacy-Kampfengine, keine UI-seitige Schadensberechnung, keine Accounts, Käufe oder Server.

## Meilensteine und verbleibende Arbeit

| Paket | Stand / Nachweis |
|---|---|
| P01–P07 | Übernommene PR-Kette, fixierter Oracle; bestehende Differentialfälle erneut geprüft |
| P08 | Ergebnis-/Kontrollserien im Legacy-Kernel; vollständige Referenzpartien und bestehende Winner-Goldens |
| P09 | Funktionale neue UI für beide Profile; vollständige historische Audit-Vorschau noch nicht umgesetzt |
| P10 | Original-KI und automatische Eröffnung/Züge; 24 vollständige JS/Godot-Vergleiche, noch nicht Audit-Gate250/1000 |
| P11 | Vollständiger nativer Replayvertrag implementiert/getestet; JS audit-v4/FNV1a-Import/Export fehlt |
| P12 | Sammlung, Detail, lokaler Deckbau/Speicherung implementiert; v09/v06/v05-Altstandadapter und alte Ökonomie nicht implementiert |
| Alpha M2–M4 | Regelprofil, 55 Karten, vier Starter, KI und lokale Oberfläche implementiert |
| M5 | Lokaler Web-Build vorhanden; QA-Status und Einschränkungen in QA_REPORT; Veröffentlichung gesperrt |

Dies ist ein spielbarer Alpha-Meilenstein, **keine Behauptung vollständiger historischer game.js-Parität**. [Offene Punkte](KNOWN_ISSUES.md), [Tests](QA_REPORT.md), [Releasegrenze](RELEASE_REPORT.md).
