# Marken- und Lore-Bibel – Master Task A

**Stand: 9. November 2026. Basis: `develop`, Commit `927ae10`.** Umsetzung: `feature/brand-world-bible`.

**NACHTSIEGEL bleibt der angezeigte Produktname.** Der interne Entwurf heißt **GEGENMASS / COUNTERMEASURE – ARBEITSTITEL**. Weder dieser Arbeitstitel noch ein Favorit der Namensliste ist als endgültige Marke freigegeben. Sämtliche neue Weltinhalte sind Vorschläge; Bestandsbefunde stehen getrennt davon.

## Lesen und entscheiden

1. [Bestandsanalyse](01-existing-audit.md): Was im Repository tatsächlich existiert, was fehlt und wie stark die bisherige Identität trägt.
2. [Namens- und Markenentscheidung](02-brand-decision.md): 20 Kandidaten, Recherchebefunde, Aussprache, Bewertung und drei Favoriten. **Empfehlung zur weiteren Prüfung: KERUVANT; keine Namensänderung ausgeführt.**
3. [Worldbuilding-Bibel](03-world-bible.md): Ursprung, Nullwinter, Magie, fünf Pfade, Religion, Politik, acht Orte, zehn Figuren, Geheimnisse und Folgehandlungen.
4. [Vier Fraktionen](04-factions.md): Schmelzkonvent, Pegelbund, Pfropfkammern, Namenkolleg; Kultur, Motive, Ambivalenz und visuelle Grammatik.
5. [Erzählerische Inhalte, DE/EN](05-narrative.md): Monolog, 40-Sekunden-Intro, fünf Kapitel, 20 Kartentexte, vier Fraktionsvorstellungen, sechs Heldenbiografien und erster Bosskampf.
6. [Datenintegration und Tests](06-integration-and-qa.md): Freigabegrenzen, technische Verwendung, Datenformat, Prüfungen und verbleibende Grenzen.

## Leitidee

**DE:** Magie verschiebt die Kosten des Überlebens. Wer fünf Versorgungswege kontrolliert, entscheidet, wer die Rechnung trägt.

**EN:** Magic defers the cost of survival. Whoever controls five supply paths decides who bears the bill.

Das Spiel verspricht taktische Entscheidungen zwischen Schutz, Druck und dauerhafter Präsenz in einer Welt mit nachvollziehbaren politischen Interessen. Keine der vier Fraktionen besitzt alle richtigen Antworten. Institutionen, Reparaturen und Alltagsversorgung prägen die Bilder stärker als beliebige dunkle Könige und uralte Prophezeiungen.

## Kanon und Implementierung

| Ebene | Verbindlichkeit |
|---|---|
| Vorhandenes Duell und Kartenwerte | Bestehende implementierte Regeln, unverändert |
| Bestandsnamen und Porträts | Im Audit belegt; keine hinzuerfundene alte Biografie |
| Neue Lore und englische Texte | Neuer Kreativentwurf, als strukturierte Grundlage erstellt |
| Kampagne, Intro und Boss | Narrative Designs; keine Behauptung, dass diese bereits spielbar sind |
| Endgültiger Produktname | Entscheidung des Auftraggebers, weiterhin offen |

Lokalisierungsquelle: `data/narrative/content.json` und `data/narrative/locales/{de,en}.json`. Die drei erzählerischen Bibeldateien werden daraus erzeugt; Dokumentation und Übersetzungen können dadurch nicht unbemerkt auseinanderlaufen. IDs bleiben unabhängig von späteren Namen.

## Abnahme

[Lokale Tests, GitHub-Prüfung und Live-Nachweis](06-integration-and-qa.md#github-abnahme-und-veröffentlichter-technischer-stand): 5.314 Assertions, 2.042 Kontrastmessungen, Paketprüfungen und sechs Browserprofile vor sowie nach Veröffentlichung erfolgreich. Die aktuelle Lieferung ändert keinen endgültigen Produktnamen und implementiert keine spielbare Kampagne.
