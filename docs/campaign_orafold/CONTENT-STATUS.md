# Inhaltsstatus und Quellenregister

Stand: 10.11.2026. Zentralquelle: [LORE-BIBLE.md](../LORE-BIBLE.md), Version 1.0. Dieses Register hält technische Nutzbarkeit, narrative Freigabe und historische Inhalte auseinander. Der finale technische Prüfstatus steht in [QA.md](QA.md), die konkreten APIs in [ARCHITECTURE.md](ARCHITECTURE.md).

## Quellenhierarchie

Es gilt die Hierarchie aus Bibel §0: ausdrückliche spätere Nutzerentscheidung vor früherer Nutzerentscheidung, belegtem Gesprächsarbeitsstand und unverbindlichen Altentwürfen. Implementierung beweist ausführbares Verhalten und keine Weltgeschichte. Der Produktionsauftrag autorisiert neue kleinere Figuren und technische Beispieltexte, aber keine selbständige Lösung zentraler Lorefragen.

| Quelle | Datum / Status | Verwendung |
|---|---|---|
| `docs/LORE-BIBLE.md` | 10.11.2026; enthält KANON, ARBEITSSTAND, VORSCHLAG, ALTENTWURF, VERWORFEN/ABGELÖST, OFFEN | Maßgebliche Referenz je konkreter Aussage. Nicht die ganze Datei pauschal als KANON behandeln. |
| Aktueller Produktionsauftrag | 10.11.2026; technischer Arbeitsauftrag | Isolierte Kampagne, Beispieltexte, freigabefähiger Plan, keine zentrale Storyauflösung. |
| `docs/creative/`, `data/narrative/` | Historischer Arvess-/Gegenmaß-ALTENTWURF | Audit/Archiv; keine ORAFOLD-Figurenquelle. |
| `docs/experience/`, `data/campaign/` | Implementierter historischer Prototyp | Technische Muster und historische Regression. Kein neuer Kanon. |
| `docs/campaign_orafold/CAMPAIGN-PLAN.md` | 10.11.2026; VORSCHLAG | Neuer möglicher Bogen mit offenen Freigaben; kein implementierter Hauptplot. |
| Neue isolierte Kampagnendaten | Technischer Prototyp / explizite Statusfelder | Bedienung, Zustände und Adapter demonstrieren. Keine behauptete narrative Hauptgeschichtenfreigabe. |

## Zulässige bestätigte Verweise

| Inhalt | Status und Quelle | Grenze |
|---|---|---|
| ORAFOLD | KANON, Bibel §1 und §10.3 | Aktuelle Projektkommunikation; keine technische Store-/Paketumbenennung durch diesen Auftrag. |
| Zwölf Häuser, Stillwacht, Vielgestalt, Neunte Stunde | KANON Namen/Spielidentität, §5 | Keine erfundenen Hauptquartiere, Herrscher, Ursprungsgeschichten oder Bündnisse. |
| Kupfer, Eisblau, Jadegrün, Amethyst | KANON Design, §5 | Verwendete UI-Farbtöne sind Präsentationsauswahl, keine neu freigegebenen exakten Markenfarbwerte. |
| Neutral | KANON Karten-Zugehörigkeit, §5 | Keine fünfte Macht. |
| Fünf Kampfpfade | KANON Spiel, §8.1 | Kein Nachweis von fünf Welten/Fragmenten/Versorgungswegen. |
| Wesen, Impuls, Relikt | KANON, §8.5 | Keine zusätzliche Hauptkartengattung. |
| Energie / Resonanz | KANON Design bzw. Designziel, §8.4 | Keine erfundene physikalische Bedeutung, keine neuen Balancingwerte. |
| Ursprungspfad / Zweite Möglichkeit | KANON Alpha-Design, §8.2 | Konkrete Ausführung bleibt Aufgabe des geprüften Regelprofils; Lorebedeutung offen. |
| Konvergenz | KANON Spielziel, §8.3 | Keine bestätigte metaphysische Stabilisierung/Auslöschung. |
| Echo keine offizielle Wesensart | KANON Kartenklassifikation, §4 | Echo nicht als dreizehnte Art einführen. |

## Geschützte offene Inhalte

| Inhalt | Quellenstatus | Handhabung |
|---|---|---|
| Eira als zentrale Figur; beschriebene Löschung | ARBEITSSTAND, §2 | Kein endgültiger Weltfakt allein durch UI-Darstellung. |
| Eiras Herkunft, Aussehen, Beziehungen, Schuld, Rolle und Rückkehr | OFFEN, §2 | Keine ausgefüllte Biografie, kein erfundenes Porträt. Technische Freischaltungsplätze enthalten keine vorweggenommenen Antworten. |
| Archiv bewahrt Erinnerung an Verlorenes | ARBEITSSTAND, §3 | Konkrete institutionelle oder räumliche Form bleibt offen. |
| Ursprung, Zuverlässigkeit, Zugang und Manipulierbarkeit des Archivs | OFFEN, §3 | Kein fester Ort mit selbst erfundenen Hütern/Regeln als Kanon. |
| Echos als Spuren/Nachwirkungen | ARBEITSSTAND, §4 | Bewusstsein, Körperlichkeit und Eigenhandeln nicht festlegen. |
| Zeitkorrektur und konkurrierende Wirklichkeiten | ARBEITSSTAND, §§1/6 | Keine vollständige Chronologie oder Kausaltheorie. |
| Ursache/Akteure der Zeitkorrektur und Weltfinale | OFFEN, §§1/7 | Kein verborgener Mastermind oder endgültiger Ausgang geschrieben. |
| Führung der vier Mächte | OFFEN, §5 | Neue lokale Nebenrollen sind keine geheimen Herrscher. |

## Neue Inhalte dieser Lieferung

**Technische Beispielrollen, Testdialoge und abstrakte Testbilder:** Prototyp/VORSCHLAG. Sie existieren zur Darstellung von Dialog, Wahl, Information und Kampfrückkehr. Eine Testrolle wird nicht durch Benutzung als Erzähler zur allwissenden Weltinstanz. Ein abstraktes Bild ist keine Abbildung eines bestätigten ORAFOLD-Ortes.

Der konkrete Prototyp trägt den Beispielnamen **„Die unbeschriebene Zeile“**. Seine zwei Kapitel **„Zwei Stimmen“** und **„Eine leere Zeile“**, die Beispielbegleitung **Sena**, eine geschlossene Seite und zwei widersprüchliche Berichte sind **VORSCHLAG**, Quelle: neue Kampagnendaten dieser Lieferung, 10.11.2026. Sena erhält keine bestätigte ORAFOLD-Biografie. Die Szene beantwortet nicht, welcher Bericht die Wahrheit enthält. Die Wahl zwischen dem Bewahren einer Zusage und dem Vergleichen der Berichte verändert den Rückblick; sie legt keine Natur des Archivs oder der Zeitlinien fest.

Ein Begegnungsanschluss benutzt vorhandene Häuser-/Stillwacht-Deckrollen als technische Übung; er behauptet weder einen kanonischen Krieg noch eine bestätigte Gegnerschaft der Mächte. Sieg öffnet das zweite Kapitel, Niederlage bietet Wiederholung. Die abschließenden Varianten einer dokumentierten oder bewusst leeren Zeile sind lokale Testendzustände. Sie lösen keinen zentralen Weltkonflikt. Die Eira-Freischaltung zeigt ausschließlich bereits vorhandene offene Fragen und keine enthüllte Biografie. Die tatsächlich geprüften Szenen-/Textzahlen werden in [QA.md](QA.md) erfasst.

**Planungstitel „Eine kleine Bitte“, „Was bewahrt wird“, „Eine andere Möglichkeit“, „Die Reihenfolge“, „Die Lücke“, „Eine offene Zusage“:** VORSCHLAG, Quelle `CAMPAIGN-PLAN.md`, 10.11.2026; zeitliche Einordnung offen; Kartenbezüge nicht festgelegt. Es handelt sich um mögliche Produktionskapitel, nicht um zugesagte spielbare Prototypkapitel.

**Begleitrolle, Gegenposition und Perspektivrolle im Plan:** VORSCHLAG, Quelle `CAMPAIGN-PLAN.md`, 10.11.2026; Namen, Aussehen, Macht und Zeitstellung offen. Sie sind dramaturgische Rollenentwürfe und keine bestätigten Weltfiguren. Der Plan erfindet keine Eira-Beziehung.

**Belohnungen:** Konfigurierbare technische Definitionen und narrative Informationsfreischaltungen. Wirtschaftliche Werte, neue Karten-IDs, Echtgeldfunktionen und produktive Ökonomie sind nicht freigegeben oder hier festgelegt. Ein Adapter-Erfolg im Prototyp ist kein Nachweis einer externen Kartensammlungsgutschrift.

**DE/EN:** Stabile IDs und zweite Sprachstruktur dienen technischer Lokalisierung. Beispieltexte und technische Übersetzungen übernehmen denselben vorläufigen Status. Sprachvollständigkeit und Fallback werden separat geprüft; sie ersetzen keine professionelle literarische Übersetzungsabnahme.

## Bewusst erhaltene historische Inhalte

Die Arvess-Welt, zehn alte Figuren, acht Orte, fünf Versorgungspfade, fünf alte Kapitel und alte Kreativgeheimnisse bleiben an ihren bisherigen Pfaden. Keine ID wird gleichgesetzt, kein Save umgeschrieben, kein Prototypsieg auf einen ORAFOLD-Kapitelsieg übertragen. [MIGRATION.md](MIGRATION.md) benennt die aktiven Abhängigkeiten und späteren Schritte.

## Redaktioneller Freigabestand

Für diese Lieferung liegt eine technische Umsetzungsbeauftragung vor. Sie enthält **keine neue narrative Freigabe** der vorgeschlagenen Hauptkapitel, Rollen oder offenen Geheimnisantworten. Bestätigte Begriffe werden mit Quellen verwendet; neue Beispielinhalte bleiben gekennzeichnet. Die Lore-Bibel wurde nicht durch einen Kampagnenentwurf überschrieben.

Bei späterer Freigabe ist zuerst die Entscheidung mit Datum und Quelle in der Lore-Bibel einzutragen. Erst danach werden Szene, Charakterinformation, Übersetzung und Quellenregister angepasst. Ein automatisch grüner Validator kann dies nicht selbst autorisieren.
