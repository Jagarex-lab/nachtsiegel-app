# Matchmaking, private Duelle und Ranglisten

Alle beschriebenen aktiven Modi sind **lokale Protokollsimulationen**. Öffentliche
Produktionssuche und gewertete ORAFOLD-Duelle bleiben deaktiviert.

## Warteschlange und Zuweisung

`matchmaking.join` akzeptiert nur `casual` und eine unterstützte Region.
Regionen sind Suchpartitionen; ein Client kann keine gemessene Netzlatenz oder
Serverkapazität verbindlich behaupten. Der aktuelle Testwert beträgt für jeden
Teilnehmer serverseitig 1.000. Die Matchmakingfunktion ist von diesem festen
Profilwert getrennt und für eine spätere Ratingquelle erweiterbar.

Die Kompatibilität prüft verschiedene Spieler, gleiche Region und Ratingabstand.
Das vorläufige Fenster startet bei 100 Punkten, wächst je zehn Sekunden
Wartezeit um 50 und endet bei 600. Die ältere Wartezeit der beiden Einträge
bestimmt die Erweiterung. Das sind technische Suchparameter, keine beschlossene
Rangbalance. Latenzmessung, Deckgültigkeit und globale Regionsausweichung sind
noch nicht integriert.

Die Queue ist persistent; pro Spieler existiert höchstens ein Eintrag.
Bestehende aktive Matches werden wiedergegeben statt doppelt erzeugt. Die
Zuweisung prüft beide Spieler erneut und entfernt beide Queueeinträge in derselben
Transaktion wie das neue Match. Blockierte Paare werden in beiden Richtungen
ausgeschlossen. Gleiche Request-ID mit anderer Nutzlast wird verworfen.

`matchmaking.leave` entfernt den eigenen Eintrag. Socketverlust entfernt eine
unbeaufsichtigte Suche. Queueeinträge laufen nach vorläufig 120 Sekunden ab;
erneute Suche verwendet einen neuen Request-Key. Ein abgelaufener Request-Key
wird nicht als verlässliches Verfahren zum Starten einer neuen Suche verwendet.

## Bestätigung und simulierte Zustände

Nach Zuweisung ist das Match `waiting_ready`. Beide Teilnehmer müssen
`match.ready` senden. Erst danach folgt `active`; ohne vollständige Bestätigung
wird nach vorläufig 30 Sekunden ohne Gewinner abgebrochen. Ein Match kann nur
seine beiden authentifizierten Teilnehmer lesen oder verändern.

Der Adapter erlaubt nur `advance` und `concede`. `advance` wechselt die
Simulationsseite; sechs angenommene Schritte schließen die Fixture als
`simulation_complete` ab. Das sind keine Kartenaktionen oder ORAFOLD-Siegregeln.
`concede` beendet die Fixture zugunsten des anderen Teilnehmers. Clientresultate
werden nicht angenommen. Simulationsergebnisse vergeben weder Rating noch Rewards.

## Private Duelle und Soziales

`private.create` erstellt einen kryptografisch zufälligen Einladungscode. Die
Einladungstabelle speichert den Hash; der private Requestbeleg enthält die
ursprüngliche Antwort einschließlich Code für idempotente Wiederholung bis zur
Belegbereinigung nach 24 Stunden. Die Einladung selbst verfällt nach 120 Sekunden.
Der Code ist ein begrenztes Geheimnis und gehört nicht in
öffentliche Logs. `private.join` prüft Gültigkeit, Ablauf, verschiedenen Spieler,
Blockierung und fehlende aktive Matches. Erfolgreiche Zuweisung konsumiert die
Einladung; vorläufige Gültigkeit 120 Sekunden. Ein Code ist für lokale Tests
manuell übertragbar. Ein öffentlicher Such-/Chat-/Nachrichtendienst existiert nicht.

Das soziale Grundmodell bietet `social.request`, `social.accept`,
`social.remove`, `social.block` und `social.list`. Eine umgekehrte Anfrage wird
nicht automatisch zur Annahme. Nur der Empfänger kann eine offene Anfrage
annehmen. Entfernen kann eine Anfrage ablehnen oder eine Freundschaft beenden.
Blockieren entfernt bestehende Beziehungen und verhindert Matching/Einladungen.
Vorläufige Grenzen: 100 Beziehungen/Anfragen pro Nutzer und 1.000 eigene Blocks.

Noch offen: adressierte Freundesduelle mit eigenem Einladungsannahme-/Ablehnungs-
Workflow, Entblockieren, Benachrichtigungen, Meldesystem, Moderation und
produktive Missbrauchsprüfung. Das aktuelle private Codeverfahren benötigt keine
Freundschaft und ersetzt diese spätere Produktfunktion nicht.

## Reconnect und Zeitverwaltung

`session.resume` findet das eigene laufende Match. `match.reconnect` liefert
eine gefilterte aktuelle Ansicht, nächsten eigenen Aktionszähler und öffentliche
Ereignisse nach einem Cursor. Der Server führt beim Reconnect keine Regelaktion
aus. Reihenfolge und Idempotenz werden aus der DB wiederverwendet.

Vorläufige Infrastrukturwerte: 90 Sekunden Reconnectfrist, 30 Sekunden aktive
Schrittfrist, 30 Sekunden Readyfrist. Die Durchsetzung der Schrittfrist wird bei
getrennten Teilnehmern bis zur begrenzten Reconnectfrist ausgesetzt; ihre Deadline
wird dabei nicht verschoben. Eine bereits überfällige Deadline kann unmittelbar
nach Reconnect greifen. Wiederverbinden gewährt keine zusätzliche Aktion oder
Zeitgutschrift. Nach Fristablauf entscheidet ausschließlich der Server über
den Simulationsabschluss. Bei Prozessneustart werden alte Socketpräsenzen
ungültig, Matchdaten bleiben bestehen und benötigen erneuten Reconnect.

`GET /matches/history` liefert nur eigene Matchmetadaten.
`GET /matches/:id/replay` ist ausschließlich für Teilnehmer abgeschlossener oder
abgebrochener Simulationsmatches freigegeben. Er enthält Regel-/Katalogversion,
Startseed, akzeptierte Aktionen, öffentliche Ereignisse und Zeitstempel.
Während laufender Matches wird dieser vollständige Replayzugang verweigert.

Mulligan- und Reaktionsfenster der echten Engine sind noch nicht integriert.
Keiner dieser Testwerte darf ohne Regel-/Balancingprüfung zum endgültigen
ORAFOLD-Spielzuglimit werden. Mobile Hintergrundphasen halten WebSockets nicht
zuverlässig aktiv; nach `visibilitychange`/Appwechsel stets Zustand abgleichen.

## Ranglistenentscheidung

| Modell | Vorteile | Nachteile | Stand |
|---|---|---|---|
| Elo | Kleine deterministische Formel, verständlich, reproduzierbar | Keine Unsicherheit/Inaktivität, K-Faktor und Matchmissbrauch separat behandeln | Isolierter `EloSandbox`-Testkandidat |
| Glicko-2 | Modelliert Unsicherheit und Volatilität, gut für schwankende Aktivität | Ratingperioden/Parameter/Implementierung komplexer | Dokumentierte spätere Alternative |
| TrueSkill-artig | Gut für Teams/mehrere Teilnehmer | Für 1v1 unnötige Komplexität, Lizenz/Implementierung prüfen | Nicht ausgewählt |

Die Elo-Sandbox startet bei 1.500, verwendet vorläufig K=32 und separate
Testtabellen. `applyResultOnce` dedupliziert über Match-ID und Hash der gesamten
Resultatnutzlast in einer Transaktion; widersprüchliche Wiederverarbeitung wird
abgelehnt. Saison ist im Modell vorgesehen. Sie liest keine Clientresultate aus
dem Transport und wird von Simulationsmatches nicht produktiv aufgerufen.

Vor Rankingaktivierung: ausschließlich Engine-signierte/autoritative Resultate,
atomare Ergebnisverarbeitung, Saisonregeln, Aufgabe-/Abbruch-/Voidpolitik,
Mindestspielzeit/Repeated-opponent-Signale und faire Einspruchsmöglichkeiten
festlegen. Die Sandbox verhindert keine abgesprochenen Niederlagen oder Smurfs.
