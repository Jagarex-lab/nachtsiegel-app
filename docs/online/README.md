# ORAFOLD Online-Grundlage

Lokaler Infrastrukturprototyp für Accounts, sichere Sessions, Matchmaking,
private Codes, Nachrichtenvalidierung, Reconnect und Matchhistorie. Der Server
führt ausschließlich ausdrücklich markierte Simulationszustände aus.
**Dies ist noch kein spielbarer ORAFOLD-Online-Multiplayer.**

## Lokal ausprobieren

```sh
cd server
npm ci
npm run typecheck
npm test
npm run demo
```

Die Demo startet selbstständig einen lokalen Server mit temporärer Datenbank
und zwei Testaccounts. Dauerhafter lokaler Server: `npm start`.
Docker/Compose, Umgebungsvariablen und Healthcheck: [Deployment](DEPLOYMENT.md).
Offline-Spiel, Hauptszene, Kampfengine, Kartenwerte und bestehende UI bleiben
unverändert; die optionalen `scripts/online/`-Module sind nicht automatisch aktiv.

## Status und Grenzen

| Kategorie | Stand |
|---|---|
| Implementiert | Registrierung/Login/Logout/Rotation, widerrufbare Sessions, private Profile, Export/Löschung, versioniertes HTTP-/WebSocketprotokoll, casual/private Simulation, soziale Basis, persistente Matchaktionen/-history, Reconnect und Teilnehmerreplay nach Abschluss |
| Lokal getestet | Tatsächliche Befehle, Ergebnisse, Laststufen und Einschränkungen stehen in [QA](QA.md); keine historischen Fremdbranchzahlen übernommen |
| Sicherheitstechnisch geprüft | Automatisierte Negativtests, Codeprüfung und Dependencyaudit im dokumentierten Umfang; keine externe Penetrationsprüfung oder pauschale Sicherheitsgarantie |
| Produktionsbereit | **Nein.** Produktionsstart wird verweigert; kein öffentlicher Dienst und keine Zahlungsfunktion angelegt |
| Noch nicht integriert | Echte Godot-Regelengine, serververifizierte Sammlung/Decks/Rewards, produktive Rangliste, externe Login-/Recoveryanbieter, PostgreSQL-/Clusterbetrieb und vollständiges Betriebsmonitoring |
| Blockiert vor Freischaltung | Stabile Effekt-/Triggerverträge, Zwei-Menschen-Regeladapter, echte Worker-/Geräte-/TLSabnahme, Recoveryidentitätsprüfung, Datenschutz-/Betriebs-/Sicherheitsfreigabe |

## Dokumentation

- [Bestandsaudit und Parallelentwicklung](ARCHITECTURE-AUDIT.md)
- [Architektur und Technologieentscheidung](SYSTEM-DESIGN.md)
- [Netzwerkprotokoll](PROTOCOL.md)
- [Sicherheitsmodell](SECURITY-MODEL.md)
- [Matchmaking, private Duelle, Reconnect und Eloexperiment](MATCHMAKING.md)
- [Integrationsvertrag zur tatsächlichen Godot-Regellogik](INTEGRATION.md)
- [Lokaler Start und späteres Deployment](DEPLOYMENT.md)
- [Betrieb, Monitoring und Backup/Restore](OPERATIONS.md)
- [Hostingannahmen und Kostenmodell](HOSTING.md)
- [Datenschutz und rechtliche Prüfpunkte](PRIVACY.md)
- [Ausgeführte Tests und Lastmessungen](QA.md)

Keine zweite Kampfengine und kein konkurrierendes Wirtschaftssystem.
Der separate Feature-PR wird weder automatisch gemergt noch veröffentlicht.
