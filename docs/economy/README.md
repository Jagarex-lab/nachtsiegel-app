# F2P-Wirtschaftssystem: technischer Architekturentwurf

Stand: 2026-11-09. **Vorschlag, ausschließlich Dokumentation. Kein wirtschaftliches Feature ist dadurch implementiert oder freigegeben.** Arbeitsbranch `architecture/f2p-economy-design`, Ausgangspunkt `develop` bei `b1f5ea59a4754bac19df31e279bff8a295cb6ea8`. PC und Mobile; Godot 4 bleibt Client.

Dieser Entwurf ändert ausschließlich `docs/economy/`. Keine Regeln, Kartenwerte, Namen, Spielstände, Live-Version, Zahlungsintegration oder anderen Branches werden geändert. PR #1 und PR #2 bleiben getrennt und ungemergt. Zahlen in Beispielen sind technische Testparameter, keine beschlossene Produktbalance oder Verkaufspreise.

## Verbindliche Anforderungen und vorgeschlagene Entscheidungen

| Kategorie | Vertrag |
|---|---|
| Vom Auftrag vorgegeben | Vollständiges kostenloses Tutorial-Starterdeck; Sammlung überwiegend aus kostenlosen/bezahlten Boostern; reguläre Boosterkarten grundsätzlich handelbar, jede Ausnahme explizit konfiguriert; Handelsgold nicht auszahlbar; Server alleinige wirtschaftliche Autorität |
| Technischer Vorschlag | Modularer Server mit PostgreSQL als einer ACID-Schreibgrenze, atomaren Besitz-/Ledger-/Escrow-Operationen, persistenten Idempotenznachweisen und Outbox |
| Technischer Vorschlag | Unveränderliche versionierte Kartendefinitionen, einzelne Besitzinstanzen, separate Anzeige, Modusregeln und temporäre Nutzungsrechte |
| Technischer Vorschlag | Gemeinsame Command-/Query-Verträge für lokale Simulation und spätere Serveradapter; Sandboxdaten nie als echtes Inventar/Guthaben importieren |
| Offene Produktfreigabe | Konkrete Raten, Preise, Pity, Starterbindung, Handelsgebühren/-zugang, Alters-/Länderverfügbarkeit und Umgang mit bezahlten handelbaren Karten |

Bezahlte Booster → handelbare Karten → Handelsgold ist eine **indirekte Echtgeld-zu-Gold-Konvertierung**, auch ohne Goldverkauf oder Auszahlung durch den Betreiber. Das Architekturdesign kann Duplikation verhindern, aber diesen wirtschaftlichen Zusammenhang nicht beseitigen. Vor einer Freigabe bezahlter handelbarer Karten sind Betrugs-, Chargeback-, Produkt- und Rechtsentscheidungen erforderlich.

## Dokumente

1. [Bestand und Quellen](current-architecture.md): develop, offene PRs, Legacy und Migrationslücken.
2. [Datenmodell](data-model.md): zehn versionierbare Modelle mit Typen, Regeln, Lebenszyklen und JSON.
3. [Systemarchitektur](architecture.md): Vertrauensgrenzen, API, Austauschbarkeit der Offlineadapter.
4. [Boosterregeln](booster-rules.md): konfigurierbarer Ziehvertrag, Garantien, Pity und Handelbarkeit.
5. [Inventartransaktionen](inventory-transactions.md): atomare Vorgänge, Ledger, Idempotenz und Wiederanlauf.
6. [Spielmodi](game-modes.md): Pools, Deckvalidierung, Rechte und Belohnungsnachweise.
7. [Marktplatz und Gilden](marketplace-guilds.md): Escrow, Kauf-/Verkaufsangebote, Rollen und Kassen.
8. [Bedrohungsmodell](security-threat-model.md): konkrete Angriffe und Kontrollen.
9. [Wirtschaftliche und rechtliche Risiken](economic-risks.md): Modellgrößen, Manipulation, Prüfbedarfe.
10. [MVP-Roadmap](mvp-roadmap.md): Phasen A–F mit Voraussetzungen, Tests, Abnahme und Komplexität.
11. [Offene Entscheidungen](open-decisions.md): Verantwortlichkeiten und blockierende Gates.
12. [Dokumentationsprüfung](validation.md): tatsächlich ausgeführte statische Prüfungen und Grenzen.

## Übergreifende Invarianten

- Ein Kartenexemplar hat genau einen wirtschaftlichen Eigentümer. Verkauf, Sperre, Verwertung und Leihe sind kein zweiter Besitzdatensatz.
- Der Client darf nur Absichten senden; keine verbindlichen Karten-, Kauf-, Sieg- oder Goldwerte bestimmen.
- Ein versiegeltes Boosterexemplar wird höchstens einmal konsumiert. Eine Belohnungsquelle erzeugt höchstens eine logische Vergabe, unabhängig von Request-Keys.
- Ein Ledgertransfer hat pro Währung Summe null. Erzeugung/Entzug erfolgt über begrenzte Systemkonten; Benutzerkonten werden nicht negativ.
- Gebühren, Besitzwechsel und Escrowauflösung werden gemeinsam committed oder gemeinsam verworfen.
- Leihrechte erlauben Spielen, niemals automatisch Verkaufen, Verwerten oder dauerhaftes Besitzen.
- Raum-/Zeitmechaniken dürfen Kampfzustände verändern, nicht Inventar-, Kauf- oder Ledgerhistorien zurückdrehen.
- Gleiche Regelkarte hat im selben Modus gleiche Werte unabhängig von Kaufherkunft, Edition und Besitzer.

Noch nicht gegeben: Backend, Login, Datenbank, sichere Ergebnisherkunft, Storeverifikation, Markt, Gilden oder wirtschaftlich vertrauenswürdige Offline-Spielstände. Der vorliegende Entwurf ersetzt keinen Implementierungs- oder Rechtsnachweis.
