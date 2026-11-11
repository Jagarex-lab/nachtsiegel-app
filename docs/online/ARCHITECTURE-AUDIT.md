# ORAFOLD: Online-Bestandsaudit

Prüfung am 10.11.2026, Ausgangsstand `develop` bei
`17121e40a49838f479d1655d88d354ed836ad20e`. Featurebranch:
`feature/orafold-online`. Aussagen über den Bestand beziehen sich auf diesen
Commit, nicht auf später eintreffende Paralleländerungen.

## Parallelentwicklung und Schutzgrenzen

Beim Start waren folgende PRs offen: [#11](https://github.com/Jagarex-lab/nachtsiegel-app/pull/11)
(`feature/generic-trigger-hooks`, Basis `develop`),
[#7](https://github.com/Jagarex-lab/nachtsiegel-app/pull/7)
(`feature/legacy-engine-p07`, gestapelt auf #5),
[#5](https://github.com/Jagarex-lab/nachtsiegel-app/pull/5)
(`feature/legacy-engine-p05-p06`, gestapelt auf #4) und
[#4](https://github.com/Jagarex-lab/nachtsiegel-app/pull/4)
(`feature/legacy-engine-p01-p04`, Basis `feature/legacy-foundations`).
Ein offener historischer PR beweist keine fehlende Funktion im aktuellen
`develop`; dieser enthält inzwischen weitere Integrationscommits.

Sichtbare Remote-Branches zusätzlich zu diesen Ketten: `alpha/playable-0.1`,
`architecture/f2p-economy-design`, `audit/legacy-functional-parity`,
`feature/alpha-0.2-mobile-ux`, `feature/arena-quality`,
`feature/brand-world-bible`, `feature/card-system-550`,
`feature/combat-presentation`, `feature/premium-experience`,
`feature/ux-contrast`, `lore/orafold-worldbuilding-550-draft`,
`production/audit-cleanup`, `security/pages-release-gate`, `main`, `develop`.
Das sind beobachtete Branches, keine verlässliche Liste laufender Agenten.

Online-Dateien werden ausschließlich in neuen Modulen ergänzt. Keine Änderung
an bestehenden Kampfmodellen, Effekt-/Trigger-Runtime, Kartendaten,
Ressourcenwerten, Szenen, Autoloads oder Releaseworkflows. Kein Merge nach
`develop`, keine Veröffentlichung. `AGENTS.md` verlangt für Merge/Release
ausdrückliche aktuelle Freigabe und schützt Gameplay sowie Produktionsassets.

## Bestandsaufnahme

| Bereich | Gefundener Bestand | Konsequenz für Online |
|---|---|---|
| Godot | `project.godot`: Format 5, Featureminimum 4.3, GL Compatibility. CI und lokale Laufzeit: **4.6.3**. Hauptszene `scenes/alpha_shell.tscn`; nur GameAudio als Autoload. | Headless-Worker exakt auf getestete Godot-Version pinnen. Minimum im Projekt ist kein Versionsnachweis. |
| Netzwerk | Keine API, WebSocket-/ENet-Anbindung oder Multiplayerverwaltung in den bestehenden GDScript-Dateien gefunden. | Neue Transportmodule bleiben opt-in und benötigen keine Offline-Netzverbindung. |
| Aktive Regeln | `scripts/alpha/model.gd` erweitert `scripts/legacy/battle_engine.gd`; kein unabhängiger Alpha-Kampfkern. Archiv `scripts/battle_model.gd` bleibt für alte QA relevant. | Aktuelles Alpha-/Kernelmodell später wiederverwenden; Archivmodell nicht als neuen Onlinekern wählen. |
| Effekte | `scripts/card_system/runtime.gd` ist ein expliziter Adapter auf Alpha-Primitiven; `registry.gd` beschreibt Fähigkeiten. Automatische Bridge wird parallel in PR #11 entwickelt. | Nicht zusätzlich an native Effekte hängen: Doppelauflösung wäre möglich. Integration erst nach stabilen Hooks und Quellen-/Pendingverträgen. |
| Determinismus | `scripts/legacy/rng.gd`: eigener unsigned-32-LCG, Fisher–Yates, RNG-Aufrufzähler; Kernel-/Alpha-Replay- und JS-Differentialtests. | Regel-/Katalog-/Engineversion und RNG-Zustand inklusive Aufrufposition speichern; LCG ist kein Sicherheitsgenerator. |
| Zustände | Kernel `state`/`snapshot()`, Ereignisse mit vollständigen Snapshots; Alpha ergänzt Eröffnungs-/Relikt-/Konvergenzfelder. | Snapshots enthalten Hand, Deck und Seed beider Seiten und dürfen niemals direkt an Clients gehen. |
| Start/Ende/KI | Alpha `start_alpha`, `mulligan`, `choose_origin`, `finish_opening`, `end_turn` enthalten Gegnerentscheidungen; Legacy-Komfortmethoden starten KI. `check_winner` bleibt Regelquelle. | Zwei Menschen benötigen seitenneutrale Befehle und ausgeschaltete Komfort-KI, keine neue KI oder neue Siegprüfung. |
| Lokale Session | `scripts/alpha/session.gd`: Startparameter, erfolgreiche Befehle, Vor-/Nachhash, lokaler Replayexport und Profilzugriff. | Session nicht unverändert auf dem Server verwenden: Profil-I/O, hero/enemy-Annahmen und vollständige Auditdaten sind lokal. |
| Speicherstände | `user://orafold_alpha_profile_v1.json`: Decks, Siege, Optionen; temporäre Datei + Rename. `progress_store.gd`: Archivfortschritt, Backup, Web-localStorage-Spiegel. | Offline-Daten bleiben lokal. Sie sind kein Nachweis für Kartenbesitz, Rang oder Belohnungen. |
| Sammlung/Deckbuilder | Alpha-Katalog `data/alpha/cards.json`, feste IDs, vier Starter; genau 30 Karten/eine Macht + Neutral/Kopiengrenzen. Legacy validiert 20–25 Kreaturen, optional caller-supplied Besitz. | Spielmodus exakt versionieren; kein Mischen der Deckregeln. Besitz künftig über autoritative Economy-Schnittstelle beziehen. |
| Wirtschaft | `docs/economy/` beschreibt zukünftige ACID-Inventar-/Ledger-/Escrowarchitektur; kein produktiver Economy-Server im Ausgangsstand. | Nur Adapter vorbereiten. Keine Währung, Booster, Belohnung oder Handel implementieren. |
| Tests | Godot Alpha-Regeln/Replays, Legacy-Differentialtests gegen fixierte JS-Referenz, Card-System-/UI-/Kampagnen-/Audio-/Exporttests. | Bestehende Referenzen unverändert; neue Online-Suiten ohne aktive Kampfengine ausführbar. |
| CI/CD | `.github/workflows/alpha-qa.yml`, `legacy-foundations.yml`, Web-QA für Chromium/WebKit, `release-safety.yml`. Pages-Release ist manuell und geschützt. | Eigene Online-CI ohne Deploypfad ergänzen. Bestehende Workflows nicht zur Online-Veröffentlichung umnutzen. |
| Plattformen | Web und Linux-QA-Exporte, Android-QA; kein iOS-Exportpreset. | WebSocket über HTTPS/WSS kompatibel planen; keine physische Mobile-/iOS-Abnahme behaupten. |
| Hosting | Bisher statische Pages-Auslieferung; kein langlebiger Matchprozess/DB-Dienst. | Pages kann Client hosten, keinen autoritativen WebSocket-Server. Lokaler Nodeprozess/VPS/Container nötig. |
| Lizenzen | `LICENSE-NOTICE.md`: Godot MIT; originale Quellen/Assets ohne allgemeine Open-Source-Lizenz. Font-/Assetnachweise im Bestand. | Open-Source-Infrastruktur gibt keine Rechte an ORAFOLD frei. Dependencylizenzen und Container-/Godotnotices vor Distribution prüfen. |

## Eignung von Godot Headless

Der Legacy-Kernel ist `RefCounted` und ausdrücklich ohne Scene-/UI-/Netzwerk- oder
Economyabhängigkeiten. Bestehende `godot --headless --script`-Tests zeigen bereits,
dass Regeln außerhalb einer UI ausgeführt werden können. Alpha erweitert denselben
Kernel. **Godot Headless ist deshalb der bevorzugte Integrationskandidat.**

Das ist noch keine geprüfte autoritative Laufzeit: Vollständiges Restore von RNG,
Queue/Pending/UID/Runtimehistorie, seitenneutrale Eingaben, Fehleratomarität,
Prozessisolation, Speicherbudget und Workerleistung fehlen als Onlinevertrag.
Der neue TypeScript-Prototyp prüft ausschließlich Nachrichtenabläufe mit einer
klar bezeichneten Simulation. Er portiert keine ORAFOLD-Kampfregel.

## Offene Abhängigkeiten

1. Stabile Effekt-/Triggerengine mit eindeutigem Regelprofil und Herkunft jedes Ereignisses.
2. Zwei-Spieler-Commandvertrag ohne automatische Gegnerzüge; feste Spieler-ID↔Seitenbindung.
3. Vollständige versionierte Serialisierung/Restore samt RNG und Adapterhistorie.
4. Ausschließlich erlaubte Spieleransichten und gefilterte öffentliche Ereignisse.
5. Serverseitiger Besitz-/Decksnapshot aus dem separaten Economy-Auftrag.
6. Native/Web-Authintegration und explizite Paketfilter für `server/`, `shared/`, Testdaten und lokale DB-Dateien, bevor ein Gameexport Online integriert.
7. Reale Workerbenchmarks und Geräte-/Browserprüfungen; aktuelle Infrastrukturtests belegen keine spielbare Onlinepartie.

Aktuelle Testergebnisse gehören in [QA.md](QA.md). Historische QA-Zahlen anderer
Branches werden nicht als neue Onlineprüfung gezählt.
