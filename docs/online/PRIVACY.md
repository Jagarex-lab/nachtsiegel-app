# Datenschutz und rechtliche Vorbereitung

Technische Vorbereitung, **keine Feststellung vollständiger DSGVO-Konformität**
und keine Rechtsberatung. Vor öffentlichem Betrieb sind Verantwortlichkeiten,
Zwecke, Rechtsgrundlagen und tatsächlich verarbeitete Daten juristisch zu prüfen.

## Datenminimierung und Trennung

Lokale Registrierung verwendet einen Loginhandle und Anzeigenamen. Der Prototyp
benötigt weder Anschrift, Zahlungsdaten, Geburtsdatum noch eine E-Mail-Adresse.
Passworthash und Sessiondigests gehören ausschließlich in private Accounttabellen.
Öffentliche Profile sollen nur ID, Anzeigename und bewusst freigegebene
Spielfelder zeigen. Eine zufällige ID ist pseudonym, nicht automatisch anonym.

Matchteilnahme, Freundschaft/Blockierung, Zeitstempel und Gegnerzuordnung können
personenbezogen sein. Replayveröffentlichung ist ein eigener Zweck; ein beendetes
Match erlaubt nicht automatisch die Veröffentlichung vollständiger Decks und
verdeckter Entscheidungen. Zunächst bleiben vollständige Replays intern.

## Aufbewahrung: vorgeschlagene Produktentscheidungen

| Daten | Vorgeschlagene Frist / Zweck | Noch zu entscheiden |
|---|---|---|
| Session-/Recoverydigests | Bis Ablauf/Widerruf, danach zeitnahe Bereinigung | Konkrete Sessionlänge, Cleanupjob, Sicherheitsnachweis |
| Matchlogs | Etwa 30 Tage heiß für Replay/Fehlerprüfung; minimale Resultate ggf. saisonal länger | Widerspruch, Rangnachweise, tatsächliche Fristen |
| Sicherheitsereignisse | Kurze begrenzte Frist, etwa 7–30 Tage je Vorfallzweck | Rechtsgrundlage, Zugriff, Pseudonymisierung |
| Freundschaften/Blocks | Während Accountnutzung und berechtigtem Sicherheitszweck | Umgang mit Löschung und Rückkehr |
| Backups | Rollierende begrenzte Frist, beispielsweise 30 Tage | Löschmarker nach Restore erneut anwenden |

Diese Vorschläge sind keine bereits aktivierten produktiven Löschjobs. Der
Prototyp darf nicht jahrelang unbeaufsichtigt Daten ansammeln. `GET /account/export`
und `POST /account/delete` sind implementierte authentifizierte APIgrundlagen.
Löschen verlangt erneut das Passwort; Cookieaufrufe benötigen CSRF-Schutz. Vor
öffentlichem Betrieb sind Nutzerführung, Vollständigkeit und die tatsächlichen
Aufbewahrungs-/Backupfristen zu prüfen. DB-Direktzugriff ist kein
benutzerfertiges Auskunfts-/Löschverfahren.

## Anforderungen an Export und Löschung

Der lokale Export liefert Profil, eigene Deck-/Sammlungstabellen, soziale
Beziehungen, eigene Matchmetadaten und Account-Auditdaten als JSON. Er enthält
keine Passworthashes oder Tokens. Zukünftige Entitlements/Wirtschaftsdaten müssen
vom separaten Economyauftrag ergänzt werden. Private Daten anderer Spieler
dürfen nicht in einen Accountauskunftsexport gelangen.
Bei vollständigen Replays Rechte aller Beteiligten und Anti-Cheat-Zweck prüfen.

Die lokale Accountlöschung widerruft Sessions/Recoveryberechtigungen, entfernt
Deck-/Sammlungseinträge und soziale Beziehungen und pseudonymisiert Login/Profil.
Die interne Spieler-ID bleibt zur Matchintegrität erhalten. Ein erneuter
Löschanwendungspfad nach Backuprestore ist noch zu implementieren. Gesetzliche Aufbewahrungspflichten
zukünftiger wirtschaftlicher Transaktionen bleiben separat zu prüfen; es gibt
in diesem Prototyp keine Zahlungen oder Handel.

## Vor öffentlichem Betrieb rechtlich zu prüfen

- Verantwortlicher, Datenschutzhinweise, Kontakt und Betroffenenrechte.
- Rechtsgrundlagen für Account, Matchbetrieb, Sicherheit und optionale Telemetrie.
- Minderjährige, Alters-/Elternmodelle und anwendbare Schutzvorgaben je Land.
- Auftragsverarbeitung, Datenregionen und mögliche Drittlandtransfers der Anbieter.
- Cookie-/Speichereinsatz: notwendige Sessions vs. optionale Analyse/Einwilligung.
- Melde-/Auskunfts-/Löschfristen, Sicherheitsvorfallprozess und interne Rollen.
- Fairness und Transparenz von Sperren/Anomalieauswertung, Einspruch und Moderation.
- Nutzungsbedingungen, offene Infrastruktur-/Godot-/Fontlizenzen und Assetrechte.
- Jede zukünftige Echtgeld-/Booster-/Handelsfunktion separat; dieser Auftrag aktiviert keine.

Keine öffentliche Chatfunktion. Auch Freundschaftsanfragen und Einladungen
benötigen Blockieren, Limits und Missbrauchsmeldung vor einer öffentlichen
Freischaltung. Technische Anti-Cheat-Ereignisse rechtfertigen keine pauschale
Sammlung von IP-/Gerätefingerprints oder privaten Clientdateien.
