# ORAFOLD – Bestandsaudit vor dem 550-Karten-Ausbau

Stand: 10.11.2026. Untersucht wurde der tatsächlich integrierte Alpha0.2-Code aus PR9, develop `5d37cd9`, vor den neuen Karten-/Engine-Paketen. Der neue Featurebranch beginnt auf diesem Stand. Dieses Dokument beschreibt **den Ausgangszustand**, keine bereits erreichte Abnahme des 550-Karten-Auftrags. Spätere Implementierungsnachweise gehören in die jeweiligen Paketberichte.

Die aktuelle Benutzerfreigabe erlaubt getestete Integration und manuell ausgelöste Web-Veröffentlichung. Sie ersetzt weder die technische Releaseprüfung noch aktive GitHub-Schutzregeln. Der Release wird getrennt vom Ausbau geprüft; ein bereits spielbarer Alpha0.2-Meilenstein ist nicht gleichbedeutend mit 550 fertigen Karten.

## Quellen und Bewertungsmaßstab

Primärquellen sind [Alpha-Modell](../../scripts/alpha/model.gd), [gemeinsamer Legacy-Kernel](../../scripts/legacy/battle_engine.gd), [Alpha-Katalog](../../scripts/alpha/catalog.gd), [55 Kartendefinitionen und Starter](../../data/alpha/cards.json), [Sitzung und Speicherung](../../scripts/alpha/session.gd), [Alpha-Oberfläche](../../scripts/alpha/shell.gd) und die tatsächlichen Tests. Die fixierte Legacy-Referenz bleibt Commit `34b3062c3f22c0950d9323ad9b97b17c41d1d14f`; [Lockdatei](../../tests/reference/duel_deck/source.lock.json) und [Originalengine](../../tests/reference/duel_deck/engine.js) bleiben erhalten.

**Funktionsfähig** bedeutet eine konkret vorhandene Implementierung mit passenden bisherigen Testnachweisen. **Teilweise** bedeutet einen vorhandenen Teilumfang gegenüber dem neuen Auftrag. **Fehlend** bedeutet keinen entsprechenden Runtime-/Datenvertrag. **Widersprüchlich** bezeichnet unterschiedliche Aussagen oder Verträge, die vor einer Erweiterung geklärt werden müssen. Eine JSON-Zeile, eine Methode mit anderem Zweck oder eine geplante Dokumentationsposition ist kein Nachweis der geforderten Funktion.

Dieser Audit hat Quelldateien und Daten gelesen und Verteilungen nachgezählt. Er behauptet keinen erneuten vollständigen Testlauf. Die vollständigen bisherigen CI-/Browsernachweise stehen im [Alpha0.2-Prüfbericht](../alpha02/QA_REPORT.md); die Prüfung des tatsächlichen Integrations-/Release-SHA wird separat durchgeführt.

## Tatsächliche Architektur und Kartenbestand

`project.godot` startet `scenes/alpha_shell.tscn`. Die Alpha erbt vom bestehenden Legacy-Kernel; es existiert keine eigenständige zweite Alpha-Kampfengine. Alpha überschreibt Start, Energiekurve, Ursprung, Konvergenz, Impulse, Relikte und KI. Der alte Sieben-Karten-Prototyp und seine Arena bleiben getrennte Archivregressionen. Die 100 Legacy-Karten sind ein separater Katalog, keine zusätzlichen Alpha-Karten.

| Bestand | Nachgezählter Ausgangswert | Einordnung |
|---|---:|---|
| Alpha-Karten | 55 | 37 `creature`, 12 `event`, 6 `relic` |
| Zugehörigkeit | 15 neutral; je 10 Häuser/Stillwacht/Vielgestalt/Neunte Stunde | Gegenüber 110 je Zugehörigkeit fehlen insgesamt 495 Alpha-Einträge |
| Seltenheiten | 20 gewöhnlich, 31 selten, 0 episch, 4 legendär | Renderer kennt episch, der Alpha-Pool verwendet es noch nicht |
| Energiekosten | 7×1, 28×2, 15×3, 1×5, 4×6 | Keine Karten mit Kosten 4, 7, 8, 9 oder 10 |
| Fähigkeiten | 16 Wesen-IDs, 9 Impuls-IDs, 4 Relikt-IDs | Einzelne konkrete Handler, kein allgemeines Effektprogramm |
| Wesenarten | 0 Felder / 0 Synergien | Alle zwölf neuen Arten fehlen |
| Explizite Illustrationsreferenzen | 0 | Renderer wählt einen von sieben Atlasmotiven über den Karten-ID-Hash |
| Starter | 4×30, jeweils 11 unterschiedliche IDs | Je 22 Wesen-, 6 Impuls-, 2 Reliktkopien; bestehende Daten wiederverwenden |
| Legacy | 100 Wesen, fünf alte Decklisten | Referenzpool getrennt; kein Ersatz für die fehlenden 495 Alpha-Karten |

Alle 55 Alpha-Einträge besitzen stabile IDs, Namen, Macht, Typ, Seltenheit, Kosten, einen Effekt und eine deutsche Beschreibung. `event` und `relic` enthalten historisch `atk: 0`/`hp: 0`; die Werte haben keine eigene Kampfrolle. Die Felder `trigger`, `target`, `duration`, `limit` sind derzeit beschreibende Metadaten. Die Engine wertet stattdessen `kind`, `effect`, `power` und ihren fest codierten Kontext aus. Eine neue beliebige Triggerbezeichnung in JSON würde noch keine Fähigkeit auslösen.

## Statusmatrix Spielregeln und Systeme

| Bereich | Status am Ausgangspunkt | Tatsächlicher Vertrag / nächste Lücke |
|---|---|---|
| Fünf Pfade / direkter Heldenangriff | Funktionsfähig | Alpha `attack_phase`, Modell:254–278; leerer direkt gegenüberliegender Pfad trifft den Helden |
| Block / Heldenschild | Funktionsfähig | Kernel `damage`:74–85: gewöhnlicher Schaden verbraucht Block, dann Schild, dann LP; Block löscht sich am nächsten eigenen Beginn, Schild bleibt bis 25 |
| Wesenschild | Funktionsfähig, begrenzt | Alpha `hit_unit`:112–115; Ursprung gibt einmal 1 Schild. Allgemeine mehrfache Schutzfähigkeiten fehlen |
| Heilung / Stasis / Schwächung | Funktionsfähig, begrenzt | Bestehende festen Effekte; kein beliebiges Dauer-/Statusschema |
| Phasen | Funktionsfähig | Eröffnung → Nachziehen → Hauptaktion → automatische Angriffe → Ende; Nachziehen ist regelrelevant und darf durch UI-Zusammenlegung nicht verschwinden |
| 30 Karten / 30 LP / fünf Starthandkarten | Funktionsfähig | `start_alpha`:10–18; Katalogvalidierung verlangt exakt 30 |
| Energie | Funktionsfähig, Konflikt mit neuem Umfang | Eigener Zug 1…8, Rest verfällt; Planungskosten 9/10 sind bei normalen Alpha-Regeln unerreichbar |
| Resonanz | Funktionsfähig | Reserve bis 15, zugübergreifend; Quellen und Sonderaktionen unten; kein gedruckter Resonanzpreis im bisherigen Pool |
| Ursprung / Zweite Möglichkeit | Funktionsfähig | Verdeckte Ursprünge, ein Ursprungsschild; zweiter Spieler darf einmal Ursprung und einmal eine Handkarte tauschen |
| Mulliganregel | Funktionsfähig | Einmalige Auswahl; Ersatz ziehen, dann alte Karten zurückmischen; beide Seiten und ungültige Indizes getestet |
| Mulligan auf dem Spielfeld | Fehlend | `shell.battle`:234–236 ruft frühe separate `opening`-Liste auf; keine ausgeteilten Vollkarten auf dem sichtbaren Fünf-Pfade-Feld |
| Held auf 0 / Unentschieden | Funktionsfähig | Gemeinsame Ergebnisprüfung; bei gleichzeitig 0 beide Seiten Unentschieden |
| Konvergenz | Funktionsfähig | Drei bereite unbestrittene konkrete Instanzen, frühestens globaler Halbzug 11/12; Erklärung endet eigenen Zug, Gewinn erst nächsten eigenen Beginn, sofern Bindung hält |
| Nachziehen / Handlimit / Pflichtverbrennen | Funktionsfähig | Limit 6; bei Nachziehüberlauf vorher Handkarte verbrennen; kein generischer Zieh-/Abwurftrigger |
| Recycling / Erschöpfung / Rückholung | Funktionsfähig | Deterministischer Ablagekreislauf mit ungeschütztem 1/2/3-LP-Preis; fehlender Nachzug steigert Erschöpfung bis 3; Rückholung kostet 5 Resonanz |
| Reaktionen | Teilweise gegenüber neuem Auftrag | Alle zwölf gerichteten Legacy-Machtreaktionen implementiert; automatische Effekte ohne Spieler-Reaktionsfenster. In legalen Ein-Macht-plus-neutral-Alpha-Decks sind die gemischten Machtpaare nicht erreichbar |
| Entfesselungen | Funktionsfähig | Vier Varianten, Schwelle 15, Kosten 8, einmal je eigenem Zug, passende eigene Wesen erforderlich |
| Relikte | Funktionsfähig, Teilumfang | Ein aktiver Slot außerhalb der fünf Pfade; Ersetzen legt altes Relikt ab; Aktivierung 1 Energie einmal je Spielerzug; vier feste Effekte |
| Dauerhafte / ausgelöste / verbrauchbare Relikte | Fehlend | Bestehende Relikte sind ausschließlich die vier Aktivierungshandler; keine allgemeine Aura-/Trigger-/Ladungsarchitektur |
| Lange Ketten | Funktionsfähig für bestehenden Umfang | FIFO death/summon/formation/echo; Tests für 10/25/50/100 Echos und expliziten Zyklusfehler. Dies beweist keine Kombination aller neuen 16 Trigger |
| KI | Funktionsfähig, begrenzt | Komplette Partien, legal-target-Aufzählung und feste Bewertungen. Keine umfassende Strategie-, Ketten-, Ressourcen-/Reaktionsplanung für 550 Karten |
| Sammlung / Deckbuilder | Funktionsfähig, Teilumfang | Suche Name/Text, Macht/Typ/Kosten/Seltenheit, Großansicht, Kurve, Kopienlimits, Speichern/Laden, vier bearbeitbare Starter. Kein Artenfilter oder ausdrückliche Kostensortierung |
| Zehn Strategietestdecks | Fehlend | Vier Starter sind vorhanden, keine zehn gesondert validierten neuen Strategiedecks |
| Replay / Kampfprotokoll | Funktionsfähig, eigene Schnittstelle | ORAFOLD-LOCAL-REPLAY v1 mit Zustandsdigests. Kein historischer JS-Audit-v4/FNV1a-Importvertrag |
| Lokales Profil | Funktionsfähig, Teilumfang | Atomar geschriebenes version1-Profil mit gültigen Decks, Einstellungen, Siegen. Laufende Partie nur RAM; OS-Prozessabbruch verliert den Kampf |
| Historische Speichermigration | Fehlend | v09/v06/v05-Legacy-Adapter ausdrücklich offen; keine Besitz-/Ökonomiemigration vortäuschen |
| Mobile / Desktop | Funktionsfähig in vorhandenen Simulationen | Querformatkampf, Hochformatmenüs/-Werkstatt, native DPR/MSDF, Safe Areas, Touch und Rotation; keine physischen iPhone-/Android-Nachweise |
| Drag-and-drop | Fehlend | Button-`pressed`/Tap-Auswahl; keine Alpha-`get_drag_data`/`can_drop_data`/`drop_data` oder gleichwertige Touch-Drag-Zustandsmaschine |
| Animationen | Teilweise | Kurze Linien/Ringe/Kreise, Schadens-/Heilzahlen, reduzierte Bewegung. Keine vollständige getrennte Zieh-, Manifestations-, Block-, Schild-, Relikt-, Ablage- und Kartenbewegungschoreografie |
| Kartenformat / Rückseite | Teilweise bzw. fehlend in Alpha | Vektorrahmen, Machtzeichen und Seltenheit vorhanden. Alpha-Karten folgen Containergrößen; kein einheitlicher 756×1056-/63:88-Splitrahmenvertrag und keine gemeinsame Alpha-Rückseitenkomponente |
| 550 vollständige spielbare Karten | Fehlend | 55 konkret vorhandene Alpha-Karten sind Ausgangsmaterial; 495 zusätzliche Einträge plus neuer Engineumfang erforderlich |

## Effektkategorien: vorhandene Primitive sind noch kein allgemeiner Vertrag

| Neue Kategorie | Konkreter vorhandener Teil | Fehlender allgemeiner Umfang |
|---|---|---|
| Schaden | strike, drain, pierce, bolt, delay, echo, Angriffe | Typisierte Quellen/Ziele, frei kombinierbare Schritte/Trigger |
| Schutz | guard, ward, pulse, Ursprung, fortify, Relikt | Wesens-/Heldenziele, Dauer, Auf-/Abbau, Auren |
| Heilung | mend, heal, drain, burst, Relikt | Freie Wesensziele und einheitliche Grenzen/Protokolle |
| Verstärkung | rally, pulse, Vielgestalt-Entfesselung | Generische Angriff-/Leben-/Dauer-/Artensynergien |
| Schwächung | weak, silence/stasis | Frei kombinierbare Zustände und Aufhebungsregeln |
| Bewegung | shift, tactical_move, displace | Ziel-/Instanzvertrag und generische Pfadwechseltrigger |
| Beschwörung | Hand ausspielen; recall erstellt Wesen | Frei definierter Effekt-Summon, Kopien-/Tokenregeln und Unterscheidung play/summon |
| Wiederkehr | recall aus letzter Wesenablage; recover auf Hand | Auswahl, Bedingungen und Wiederkehrtrigger |
| Ressourcen | Energiezahlung, add_res, feste Sonderkosten | Gedruckte Resonanzpreise, parametrische Zahlungen/Erzeugung und Pro-Ketten-Limits |
| Kartenmanipulation | draw, burn, exchange, recover, recycle | Parametrische Auswahl-/Abwurf-/Deckoperationen und vollständige Trigger |
| Zeitmanipulation | delayed damage, stasis, redirect | Allgemeiner verzögerter Effekt, überprüfbare Zeitpunkte/Abbruchregeln |
| Kontrolle | Feste Betäubung, Schwächung, Verdrängung | Generische Kontrollbedingungen/-effekte, eindeutige Dauer und Gegenmaßnahmen |

Alle zwölf Kategorien haben entweder verwandte Primitive oder vorhandene Teilregeln. **Keine** wird bereits als frei parametrisierbare Kategorie mit geschlossenem validiertem Operationsschema angeboten. Derzeit trägt jede Karte genau eine primäre `effect`-ID; `pulse` ist ein im Handler fest codierter Mehrfacheffekt. Für neue Karten darf nicht jede Kombination einen neuen Spezialhandler erhalten.

## Trigger: 16 verlangte Auslöser gegenüber Runtime

| Auslöser | Ausgangsabdeckung |
|---|---|
| 1 Beim Ausspielen | Impulse/Relikte besitzen eigenen `play`-Zweig; Wesen-Ausspielen und Summon-Effekt nicht generell getrennt |
| 2 Beim Beschwören | `summon`-Queue plus 16 feste Wesenfähigkeiten; recall verwendet denselben Einstieg |
| 3 Beim Angreifen | Angriffe vorhanden, kein freies Auslösen von Kartenprogrammen |
| 4 Beim Verteidigen | Nur Sonderhandler retaliate; nur nach positivem Treffer und bei überlebendem Verteidiger |
| 5 Beim Schaden verursachen | Keine allgemeine Triggerregistrierung |
| 6 Beim Schaden erleiden | Keine allgemeine Triggerregistrierung |
| 7 Beim Besiegen | Keine allgemeine Triggerregistrierung |
| 8 Beim eigenen Besiegtwerden | death/harvest vorhanden; kein freies Programm |
| 9 Zu Zugbeginn | Feste Regelabläufe und verzögerte Treffer; keine Kartentriggerliste |
| 10 Zu Zugende | Feste Angriffe/Ergebnisprüfung; keine Kartentriggerliste |
| 11 Beim Pfadwechsel | formation nach shift; tactical_move hat eigene Mutation, kein einheitlicher Kartenhook |
| 12 Beim Kartenziehen | Ziehprimitive vorhanden; kein freies Kartenprogramm |
| 13 Beim Abwerfen | burn/verschiedene Ablagewege vorhanden; kein einheitlicher Abwurfhook; Ablegen und Abwerfen nicht gleichsetzen |
| 14 Beim Ausgeben von Resonanz | Vier Sonderaktionen ziehen Resonanz ab; kein Hook |
| 15 Beim Aktivieren eines Relikts | Vier feste Handler plus trace; kein freier Folgetrigger |
| 16 Beim Erreichen einer Bedingung | Konvergenz ist feste Siegprüfung, kein generischer Bedingungs-/Einmaligkeitsvertrag |

Aktivierte Fähigkeiten existieren nur für Relikte/Sonderaktionen; haste/retaliate/harvest sind feste passive Sonderregeln. Spielerwahlbare reaktive Impulse und dauerhafte beliebige Auren fehlen. Die 16 Legacy-Fähigkeiten sind **nicht** mit den 16 neuen Auslösern gleichzusetzen.

## Queue, Timing und Schutzgrenzen

Alpha `enqueue_many`:220–245 validiert einen Batch vor dem Einfügen, verarbeitet FIFO, erzeugt einen Fingerprint aus Zustand+Queue und stoppt bei wiederholtem Zustand oder 10.000 Einträgen mit einem sichtbaren Fehlerzustand. Der Legacy-Standard bleibt bei 100 Einträgen; Alpha überschreibt ihn. Ereignisse werden mit Reihenfolge und vollständigem Zustand protokolliert. Bei Sieg werden weitere Queue-Effekte verworfen. Am Zugbeginn lösen fällige verzögerte Effekte vor Konvergenz aus, sodass tödlicher Heldenschaden Vorrang hat.

Für den bisherigen Kartenumfang ist das getestet. Für den Ausbau fehlen ein geschlossenes parametrisches Effekt- und Zielmodell, stabile Quellen-/Ziel-UIDs in allen Queuenachrichten, erneute Zielgültigkeitsprüfung am Auflösungspunkt, ein ausdrücklich festgelegter Zeitpunkt gleichzeitiger neuer Auslöser, Besitzer-/Pfadreihenfolge und Reaktionsfenster mit Pass-/Auflösungsregel. Ein gültiger `summon`-Queueeintrag garantiert bisher beispielsweise lediglich bekannte Karte und gültigen Pfad, keinen allgemeinen UID-/Quellidentitätsvertrag.

Die Endlosschleifenbremse ist eine technische Notabschaltung, kein vollständiges Balancinglimit: Eine endliche Kette kann innerhalb der 10.000 Schritte viel Block/Angriff erzeugen. `add_res` deckelt Resonanz auf 15, aber es gibt noch keine pro Quelle/pro Trigger/pro Zug beschriebene Kontrolle der neuen Ressourcenkombinationen. Wiederholtes Bezahlen und Erzeugen bis 15 benötigt gesonderte Tests. Vollständige Snapshots pro Ereignis und erneute JSON-Fingerprints sind ein messbarer Performanceprüfpunkt bei umfangreichen Ketten, kein bereits gemessener Gerätefehler.

## Ressourcen und Regelkonflikte

1. **Energie 1–10 gegenüber Cap 8.** Alpha Modell:96 und `tests/alpha_rules.gd`:65–67/194 erwarten 8. Kosten 9/10 hätten ohne gezielte neue Erzeugung keine reguläre Spielbarkeit. Kostenfilter endet momentan bei 6 (`shell`:688), Kurve zählt 0…8 (`shell`:501–507). Vor Karten 9/10 sind Modell, Hilfetext, UI und Tests gemeinsam zu versionieren; Legacy unverändert lassen. Eine neue Kurve ist eine dokumentiert zu begründende Alpha-Regelentscheidung, kein bloßer Datenimport.
2. **Gedruckte Resonanzkosten fehlen.** Resonanz bleibt bis 15 bestehen. Unterschiedliche aufeinanderfolgende Beschwörungsordnungen erzeugen +2, auch Macht↔neutral; formation +1, weave/pulse/harvest und Resonanzrelikte liefern weitere. Rückholung kostet 5, Bewegung 3, Wacht 2; Entfesselung verlangt 15 und verbraucht 8. Die vier bisherigen Relikthandler zahlen 1 Energie, keine Resonanz. Neues optionales Resonanzkostenfeld darf nicht nur UI-Metadatum sein.
3. **Zwölf Reaktionen in Ein-Macht-Decks.** Der Alpha-Adapter mappt Mächte auf vier Legacy-Ordnungen. Reaktionen verlangen zwei unterschiedliche nicht neutrale Ordnungen; reguläre Alpha-Decks haben nur eine. Neutralwechsel erzeugt Resonanz, aber keinen der zwölf Paareffekte. Das ist eine Erreichbarkeitslücke für den neuen reaktiven Kartenauftrag, keine fehlende Legacy-Implementierung. Nicht eigenmächtig Mehrmachtdecks als Lösung erlauben.
4. **Dokumentationsfehler Durchdringung.** `docs/alpha02/AUDIT.md`:62 behauptet, Durchdringungs-Ankunft ignoriere Schild, aber nicht Block. Tatsächlich rufen Alpha/Legacy `damage(..., true)` auf; Kernel:74–85 und Original-JS:48/71 umgehen **beides**. Gewöhnliche direkte Angriffe und Durchbruch-Überlauf verbrauchen weiter Block vor Schild. Den Satz in Folgedokumentation korrigieren; nicht die nachgewiesene Runtime an den falschen Satz anpassen.
5. **Genau eine Macht gegenüber Neutraldecks.** Kernkatalog erlaubt vollständig neutrale 30er-Decks; neue Alpha0.2-Werkstatt verlangt mindestens eine Karte der ausgewählten Macht (`shell.deck_check`:522–525). Persistenzvalidierung und Replay akzeptieren den älteren Vertrag weiterhin. Vor allgemeinem Schemawechsel beide Zwecke explizit trennen; gespeicherte gültige Decks nicht still verlieren.
6. **Wesen/Impuls gegenüber Kreatur/Ereignis.** Drei technische IDs sind bereits vorhanden: `creature`, `event`, `relic`. Der neue Auftrag verlangt drei Haupttypen, keinen vierten. Die stabile technische ID `event` kann als **Impuls** lokalisiert werden. Stil/UI zeigt bisher Kreatur/Ereignis (`style`:9). ID-/Replay-/Deckkompatibilität ist bei Migration zu berücksichtigen.
7. **Reliktersatz.** Belegte Regel: neues Relikt ersetzt altes, altes geht auf Ablage, kein Pfad wird belegt. Aktivierungsverbrauch ist pro Spielerzug und wird durch Ersetzen nicht erneuert (`tests/alpha_rules.gd`:boundary_checks). Empfohlener konsistenter Bestandsschutz: diese Regel beibehalten; neue Dauer-/Ladungseffekte müssen beim Entfernen deterministisch beendet werden. Reliktentfernung ohne Ersatz ist noch kein generischer Effekt.
8. **Text stimmt nicht automatisch mit Effekten überein.** Beschreibungen sind handgeschriebene freie Strings, teilweise „Ankunft:“ statt verbindlichem Auslösermuster. Es gibt keine zentrale Textgenerierung oder Grammatik-/Parameterprüfung. Das aktuelle Schema verlangt sogar genau einen festen Effekt pro Karte; optionale effektlose Wesen und mehrere Fähigkeiten brauchen einen neuen validierten Vertrag.
9. **Replay-/Profilversionen.** Session speichert mode, Deck, Seed, Schwierigkeit, Konvergenzoption, Befehle und Hashes, aber kein je Balancingversion fest eingefrorenes Kartenmanifest. Regel-/Werteänderungen würden alte Replays mit Zustandsabweichung ablehnen. Vor umfangreichem Ausbau Replay-Rulesetversion/Manifest und kontrollierte Profilmigration ergänzen; stabile vorhandene IDs erhalten.
10. **Raritätsbudget versus gesicherte Balance.** Der Bestand hat keine epischen Alpha-Karten und verwendet keine zentralen Fähigkeitsbudgets. Die neue Formel ist ein Startmodell; frühere KI-Simulationen beweisen keine Austauschbarkeit von Angriff und Leben im Fünf-Pfade-Kampf. Kosten-/Ressourcenmodelle zuerst gepaart vergleichen und bewusste Ausnahmen separat führen.

## Balance- und KI-Ausgangsevidenz

Der [vorhandene Bericht](../alpha02/QA_REPORT.md) beschreibt 768 deterministische Partien: jeweils 256 offizielle Regeln, ohne Konvergenz und ohne Ursprungsschild. Offizielle Stichprobe: Erstspieler 114/256 Siege (44,53%; Wilson95% 38,57–50,66), 55/256 Konvergenzsiege (21,48%), keine Enginefehler oder unvollendeten Läufe. Das ist eine Screeningstichprobe mit fester KI, keine menschliche Balanceabnahme.

Neunte Stunde gewann 90/96 nicht gespiegelte Partien. Das ist ein dringender Untersuchungsbefund. Zugleich sind Testpolitik/Implementierung asymmetrisch: Spielerursprung wird fest auf Pfad 3 gewählt, Gegnerursprung zufällig; gegnerseitiges shift wählt schon im Summonhandler eine Bewegung, `ai_turn("hero")` überspringt seinen Pending-Shift. Neunte-Stunde-Kosten/Schaden, Burst, Reaktionen und diese Policy-Unterschiede müssen getrennt untersucht werden. Kein pauschaler Nerf und keine Aussage „alle 550 ausbalanciert“ aus dem alten Screening ableiten.

Die KI bewertet legal spielbare Karten mit festen Score-Zuschlägen, priorisiert gegnerische Konvergenz, aktiviert brauchbare Relikte/Entfesselungen und erklärt eigene Konvergenz. Es gibt keine allgemeine Bewertung neuer Arten-/Resonanz-/Reaktions-/Reliktketten. Zehn Strategiedecks und Instrumentierung für Nutzungsraten, Energieeffizienz, Resonanzverlauf, Extremketten und Seitenwechsel sind noch zu bauen.

## Darstellung, Eingabe, Illustration und Stabilität

Alpha0.2 hat bereits die wesentliche Mobilebasis: Kampf bevorzugt Querformat, Portrait zeigt Drehhinweis mit sicherem Menüausstieg; keine erzwungene Safari-Orientierung oder 90°-Canvasrotation. Rotation erhält Modell, RNG, Befehle und Auswahl. Menüs/Starter/Deckbau funktionieren in Portrait, Desktop bei ausreichender Breite zweispaltig. Primäraktionen haben 44er Touchmindestflächen, Auswahl per Tap plus explizitem Abbruch, 180-ms-Doppeltap-/Rotationsschutz. Der neue Ausbau muss diese geprüften Verhaltensweisen bewahren.

Rendering: Stretch disabled, native Canvas-Pixelmaße, UI skaliert aus tatsächlichem DPR, Alpha-MSDF-Schrift, Vektorrahmen und Atlas-Mipmaps. Der vorige CSS-Inlinebreiten-/Rückrotationsfehler und unbeabsichtigte Einpackung von Node-Testassets sind gezielt behoben. Einzelillustrationen bleiben aus einem ca. 415×421-Pixel-Motivvorrat; fehlende Auflösung lässt sich nicht durch Schriften/Canvas-Einstellungen reparieren. Aktuell keine 55, erst recht keine 550 individuellen finalen Illustrationen. Eine neue Assetpipeline muss pro Karte Quelle/Lizenz/Status angeben und vorhandene Motive ehrlich als Ersatzdarstellung führen.

`card_view.gd` zeichnet adaptive kompakte Karten und Wesen. Identische Masterabmessungen und diagonale Informationszonen sind noch kein Alpha-Vertrag. Das im Archiv vorhandene Kartenrückseiten-/Premiumsystem ist keine automatisch integrierte Alpha-Rückseite. Seltenheitssymbole existieren, aber die neuen Anforderungen an zusätzliche innere Materialtiefe und Animation innerhalb einer einheitlichen Kontur sind offen.

Animationen werden getrennt von Regeln als höchstens 24 Jobs von je 0,45 s gezeichnet (`feedback.gd`); reduzierte Bewegung unterdrückt sie. Das schützt die Spiellogik vor Animationswartezeiten, ersetzt aber keine nachvollziehbaren individuellen Karten-/Schild-/Blockabläufe. Beim neuen Drag müssen Fingertracking, Schwellwert, ungültige Drops, Pointerverlust, Mehrfachberührung und Rotation getrennt vom bestätigten Command behandelt werden.

Keine physischen iOS-/Android-Tests. Desktop-WebKit/Chromium emulieren Bildschirm/Touch/DPR, nicht Safari-Tastatur, tatsächlichen Appwechsel, OS-Kill, thermische Drosselung, Fingerlatenz oder Gerätespeicher. Profil/Deck speichern lokal; aktive Partie überlebt nur Resize/Rotation im laufenden Prozess. Der frühere Geräteprüfbedarf bleibt auch nach einem erfolgreichen Webrelease bestehen.

## Bestehende Tests und ihre Grenzen

Vorhandene Gates: `tools/test_legacy.sh`, `tools/test_alpha.sh`, `tools/test.sh`, Release-Sicherheitstests, Alpha-/Archiv-Browser-QA und Alpha0.2-Layout-/Upgrade-/Balanceprüfungen. Die vorherige CI meldet 1.305 Legacy-Differentialfälle einschließlich 24 ganzer Referenzduelle, Alpha-Regeln 1.704 Assertions/64 vollständige KI-Partien, Replay 173, Alpha-UI 348 und Alpha0.2-UI 769; siehe [Bericht und Rohdaten](../alpha02/QA_REPORT.md). Diese Summen gehören zu den dokumentierten bisherigen Läufen, nicht zu einer neuen 550er-Suite.

`tests/alpha_data.test.cjs` enthält ausdrücklich den 55er-/15+10er-Vertrag, bekannte feste Effektlisten und Kosten 1…8. `tests/alpha_rules.gd` beschwört/spielt jede vorhandene Karte auf beiden Seiten und prüft konkrete Interaktionen, jedoch teilweise mit absichtlich künstlicher Energie 20. Das beweist Effekt-Ausführbarkeit unter Testvoraussetzungen, nicht jedes künftige 10-Energie-Wesen in einer regulären Partie. Neue Tests müssen echte Ressourcen-/Deckzustände und ausschließlich verfügbare Effekte verwenden.

Offen sind insbesondere 550-Datenvalidierung, zwölf Arten einschließlich gleichwertiger Doppelzuordnung, alle 16 allgemeinen Trigger, neue reaktive Fenster, generische Zielinvalidierung, per-Quelle-Limits, Drag-Eingabe, Spielfeld-Mulligan, 63:88-/Rückseiten-Konturtests, zehn Strategiedecks und hinreichend breite neue Kartenkombinationssimulationen. Unbekannte Effekt-IDs müssen weiter hart abgewiesen werden; fehlende Implementierung darf nicht als No-op-Erfolg zählen.

## Kleine, überprüfbare Umsetzungspakete aus dem Audit

Diese Empfehlungen konkretisieren den [Hauptplan](IMPLEMENTATION_PLAN.md), ohne ihn durch eine zweite konkurrierende Reihenfolge zu ersetzen:

1. **Geschlossener Datenvertrag:** drei stabile Typ-IDs, zwölf Arten 1–2 gleichwertig nur bei Wesen, vier Seltenheiten, optionale separate Resonanzkosten, explizite Illustration mit Produktionsstatus, versionierte Fähigkeiten-/Ziel-/Triggerdefinitionen. Bestehende 55 IDs über Adapter beibehalten. Negativtests für jedes Feld; noch keine 495 Füllkarten.
2. **Gemeinsame Effektprimitive:** parametrisierte Kategorien registrieren; zuerst Schaden/Schutz/Heilung und vorhandene 16 Fähigkeiten auf Alpha-Vertrag adaptieren. Legacy-Profil und Goldens unverändert. Gleiche Kosten und Reihenfolge der alten Alpha-Karten regressiv vergleichen.
3. **Einheitliche Auslöser/Queue:** zuerst play/summon/death, dann Angriff/Schaden, Zug-/Pfad-/Karten-/Ressourcen-/Relikthooks. Besitzer-/Pfad-/Registrierungsreihenfolge, Ziel-UID/Verfall und Schleifen-/Erzeugungsgrenzen definieren; jeden Hook einzeln, auf beiden Seiten und in Zehnerketten testen.
4. **Regelentscheidungen versionieren:** Ressourcenmodelle mit vorhandenen Startern und Seiten-/Policyausgleich vergleichen; danach Energie 9/10 ermöglichen und Kurve, Hilfe, Filter, Replayversion und Tests gemeinsam umstellen. Getestete Spielbarkeit bleibt als Zwischenmeilenstein erhalten.
5. **Kuratierte Inhalte:** je Macht erkennbare Archetypen, Synergien, Gegenkarten und klare Reaktions-/Reliktrollen entwickeln. Pro Paket echte strukturelle/semantische/textliche Prüfung, reguläres Spielen, Kombinationsfixtures und Simulationen. Erst bei tatsächlich 110 je Zugehörigkeit den 550er-Abschluss ausweisen.
6. **Eingabe/Präsentation parallel:** bestehendes Commandmodell für Drag und Tap gemeinsam verwenden; echter Spielfeld-Mulligan; neuer Splitrahmen und gemeinsame Rückseite mit identischer Kontur. Keine neue UI-Spielregel-Engine.
7. **Persistenz/KI/Gesamtabnahme:** Profile und Replays migrieren, Artenfilter/Kostensortierung und zehn Testdecks; Strategie-KI mit dokumentierten Metriken. Exakten Integrations-SHA vollständig testen, manuelles Release und anschließend Live-Browserpartie prüfen. Keine Test-/Releasebehauptung aus einem anderen Commit übernehmen.

Priorität P0: vorhandene Partie/Leerpfadregel erhalten, Daten-/Queueverträge und unspielbare Kosten vermeiden. P1: neue Fähigkeiten real implementieren, Karteninhalte kuratieren, Mobile-Mulligan/Drag und Deckbau. P2: Einzelillustrationen und zusätzliche Veredelung. Die grafischen Produktionslücken bleiben ausdrücklich sichtbar, bis echte Assets vorliegen.
