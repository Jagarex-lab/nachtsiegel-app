# Implementation Plan — Legacy-Parität

Stand 2026-11-09; Grundlage: [LEGACY_PARITY_AUDIT.md](LEGACY_PARITY_AUDIT.md), JS `34b3062c3f22c0950d9323ad9b97b17c41d1d14f`, Godot `b1f5ea59a4754bac19df31e279bff8a295cb6ea8`.

**Dies ist ein vorgeschlagener Folgeplan, keine ausgeführte Gameplay-Änderung und keine Freigabe zum Ersetzen der heutigen Godot-Regeln.** Dieser PR ergänzt ausschließlich Bestandsaufnahme und reproduzierbare Auditnachweise. Namen, Lore, Kartenwerte, Assets und produktive Regeln bleiben unverändert. Kein Merge und keine Veröffentlichung gehören zu diesem Auftrag.

## 1. Zielvertrag vor Beginn festhalten

Vor einem späteren Implementierungs-PR ausdrücklich entscheiden und in dessen Beschreibung festhalten:

1. Wird die fixierte JavaScript-Engine der verbindliche Regelvertrag, oder erhält Godot einen gesonderten Legacy-Modus? Bestehende Godot-Regressionen und den gefrorenen Oracle nicht stillschweigend umdefinieren.
2. IDs `ash-0` usw. sind Regelidentität; Anzeige-/Narrativnamen sind unabhängig davon zu mappen. Namensähnlichkeit ist kein Identitätsnachweis. Insbesondere Nebelqualle/Schattenwolf erst bewusst zuordnen.
3. Den zusätzlichen Godot-Zauber Funkenstoß separat behandeln; er ist keine der 100 alten Karten. Konzepte bleiben nicht spielbar. Kein ungeprüftes Zusammenmischen beider Pools.
4. Vollständige Parität schließt Deckwerkstatt, Altstände, Sammlung und lokale Ökonomie aus `game.js` ein. Falls einzelne Funktionen bewusst entfallen, diese als Ausnahmen ausweisen und keinen uneingeschränkten Paritätsclaim verwenden.
5. Produktionsfehler der alten Engine nicht nebenbei „verbessern“. Abweichungen zwischen Beschreibung, veralteten Tests und aktuellem Code dokumentieren; verbindliche Semantik aus dem fixierten ausführbaren Stand ableiten. Gewollte Regelkorrekturen erhalten eigene Freigabe und Tests.

Diese Entscheidungen blockieren **keine** weitere Bestandsaufnahme oder Testdatenextraktion, aber verhindern ein versehentliches Umschalten der bestehenden spielbaren Anwendung.

## 2. Paket- und Prioritätsübersicht

Jede Tabellenzeile ist ein einzeln reviewbarer, unabhängig prüfbarer PR-Kandidat. „Unabhängig prüfbar“ bedeutet: mit expliziten Zuständen und erfüllten Abhängigkeiten testbar, ohne sämtliche Folgeteile fertigzustellen. Keine Zeile verlangt einen ungetesteten Zwischenstand auf der Live-Seite.

| Paketgruppe | Priorität | Audit-Verträge | Ergebnis |
|---|---|---|---|
| P01 Referenz und Differentialnachweis | P0 | M12, M55–M60 | Richtiger Oracle und goldene Zustandsübergänge |
| P02 Kartenidentität / Decks | P0 | M08–M12, M69–M70 | Unveränderte Legacy-Daten, klar von Godot-Zusätzen getrennt |
| P03 Zug- und Ressourcenmodell | P0 | M01, M04–M07, M13–M18 | Symmetrischer Start und Phasenscheduler |
| P04 Schaden / Bereitschaft / Todesqueue | P0 | M02–M03, M20–M21, M23, M26–M27, M49, M52 | Korrekte Kernangriffe einschließlich Block/Schild |
| P05 Ziehen / Ablage / Kreislauf | P1 | M07, M18–M19, M22–M25 | Vollständiger Kartenlebenszyklus |
| P06 Sechzehn Fähigkeiten | P1 | M28–M43, M61 | Ein Effekt pro prüfbarem Paket |
| P07 Resonanz / Reaktionen / Aktionen | P1 | M17, M25, M44–M48, M70 | Vier regelmechanisch identifizierbare Orden |
| P08 Ergebnisse / Kontrollserien | P1 | M49–M52 | Symmetrische, sofortige Kampfentscheidung |
| P09 Bedienbare Regelaktionen | P1 | M61–M62, M68–M69 | Neue Legacy-Kommandos ohne zweite UI-Regelengine |
| P10 Legacy-KI | P1 | M53–M55 | Gegner nutzt echte Ressourcen und Referenzentscheidungen |
| P11 Logs / Replay | P1 | M55–M60, M68 | Reproduzierbare Befehle und vollständiger Auditexport |
| P12 Sammlung / Deckbau / Speicherung | P2 | M63–M67 | Funktionale Nebenwege aus `game.js` |

## 3. Kleine Implementierungspakete mit Abhängigkeiten und Abnahme

### P01 — Beweisgrundlage

| Teil | Abhängigkeiten | Konkrete Änderung im späteren PR | Unabhängige Akzeptanzprüfung |
|---|---|---|---|
| P01a Referenz pinnen | keine | JS-Testadapter lädt exakt den untersuchten Commit; Herkunft/SHA in jedem Fixture. Bestehenden Godot-Oracle als Godot-Regression erhalten. | Abweichenden Quell-SHA ablehnen. 100 Karten exportieren und deren Identität/Typ/Werte/Effekte vollständig prüfen. Keine „legacy“-Benennung ohne Herkunft. |
| P01b Übergänge exportieren | P01a | Kleine JS-Szenarien für jeden öffentlichen Befehl und jede relevante Grenzbedingung; erwartete Zustände, Ressourcen, Ereignisse und Ablehnungen. | Fixtures durch tatsächliche Engine neu erzeugen; byte-/semantisch identisch. Ein absichtlich veränderter erwarteter Wert muss den Vergleich rot machen. |
| P01c Kanonischer Vergleich | P01b | Zustand normalisieren, ohne Spiellogik nachzubauen; array-Reihenfolgen erhalten, JSON-Zahlen/Strings explizit behandeln. | Ein fehlendes Feld, andere Deckreihenfolge oder abweichende Ziel-ID schlägt fehl. Reine JSON-Objektschlüsselreihenfolge separat vom JS-kompatiblen Hash behandeln. |

**Testschuld getrennt:** Das alte `tests.js` und `ui-smoke.test.js` später nur in einem separaten Testwartungs-PR aktualisieren; aktuelles Fehlverhalten im Audit nicht überschreiben. `check.js` benötigt eine echte, versionierte Beispielaufzeichnung oder einen expliziten Eingabepfad. Die fehlende Originaldatei nicht rekonstruieren und als Original ausgeben.

### P02 — Daten und Regelidentität

| Teil | Abhängigkeiten | Konkrete Änderung | Akzeptanzprüfung |
|---|---|---|---|
| P02a Legacy-Katalog separat | P01a, Zielvertragsentscheidung | 100 stabile IDs mit kind/order/rarity/power/effect und unveränderten Originalwerten als separater Regelkatalog; kein Überschreiben des heutigen Pools. | Für jede ID alle Felder gegen JS-Export vergleichen; genau vier Legendäre / 100 Kreaturen / keine Legacy-Zauber; unbekannte ID ablehnen. |
| P02b Deckvalidator | P02a | 20–25 Karten, Kopien- und Besitzgrenzen als reine Funktion. | 19/20/25/26, unbekannte ID, normale 3/4, legendäre 1/2, fehlender Besitz; keine Mutation bei Fehler. |
| P02c START und Presets | P02b | Fünf originale Decklisten (START + vier Presets); narratives Mapping nur Anzeige. | Alle Listen exakt 25; Originalmultimengen und Reihenfolgen stimmen, valide unter passendem Besitz. |
| P02d JS-RNG und Deckreihenfolge | P01c, P02c | 32-bit-LCG und Fisher–Yates mit exakt gleicher Konsumfolge; Deckanfang statt Deckende ziehen. | Bekannte Seedfolgen inkl. 0 und unsigned-Maximum; Münzwurf und beide vollständigen Decks identisch. Godot-RNG nicht als gleichwertigen Ersatz behaupten. |

### P03 — Symmetrischer Grundzustand und Phasen

| Teil | Abhängigkeiten | Konkrete Änderung | Akzeptanzprüfung |
|---|---|---|---|
| P03a Zwei Spielerzustände | P02a | Beide Seiten mit HP/maxHP, Hand/Deck/Ablage, fünf Pfaden, Ressourcen und Flags; reine Befehlsvalidatoren. | Unbekannte Seite/Karte, falsche Phase, besetzter/ungültiger Slot und unzureichende Kosten ohne Mutation ablehnen. |
| P03b Eröffnung | P03a, P02d | Seed-Münze, Gegnerdeck nach Level, GegnermaxHP, Zweitspielerschutz und erste 3er-Hand. | Beide Münzseiten, Level 1/2/5 und maxHP-Deckel; Snapshot vor begin und nach Eröffnung gegen JS. Gegnerische Eröffnungsautomatik erst mit P10 aktivieren. |
| P03c Phasenscheduler | P03b | begin/draw/main/attack/end, aktive Seite und Round pro Halbzug; Flags pro eigenem begin zurücksetzen. | Ungültige Kommandos in jeder Phase ablehnen; zwei beschworene Kreaturen pro Seite, nächste eigene Phase setzt genau einmal zurück. |
| P03d Energieformel | P03c, P07a | Basis 2, Hard-Gegnerbonus, einmaliger Zweitspielerbonus, Resonanzschwellen 5/10/15. | Werte 4/5/9/10/14/15 und beide Startpositionen; keine künstliche rundenbasierte Steigerung oder 10er-Obergrenze aus dem Godot-Prototyp übernehmen. |

### P04 — Schaden und Angriffsauflösung

| Teil | Abhängigkeiten | Konkrete Änderung | Akzeptanzprüfung |
|---|---|---|---|
| P04a Reine Schadenspipeline | P03a | Schaden floor/max0; erst Block, dann Schild, dann HP; explizites Pierce-Flag; Rückgabewert tatsächlicher HP-Verlust. | Auditvektoren 2/5/10 mit Block 3/Schild 4, Schutzignorierung, 0/negativ, tödlicher Treffer und HP-Clamp. Beide Seiten. |
| P04b Bereitschaft | P03c | summoned/stun-Zustand, Reihenfolge stun vor Warteprüfung, haste-Ausnahme. | Neu beschworen ohne Eile wartet genau eine eigene Phase; Eile greift sofort; Betäubung sperrt auch Eile; Flags nach Überspringen exakt. |
| P04c Gewöhnlicher Pfadangriff | P04a–b | Pfade 0–4 sequentiell: Gegenkreatur, sonst Held durch Schadenspipeline; keine generelle Gegenwehr. | Leerer Gegenpfad trifft Gegnerhelden für beide Seiten; Block/Schild absorbieren; besetzter Pfad schützt Held ohne allgemeinen Überlauf; andere Pfade bleiben unberührt. |
| P04d Todes- und Effektqueue | P04c | Entfernen → FIFO-Todesevent → Ablage/Trigger; verschachtelte Ereignisse, max.100, Gewinnerabbruch. | Doppelentfernung ausgeschlossen; Angreifer-/Verteidigertod-Reihenfolge; Ereignis-100-Grenze; nach entscheidendem Treffer kein weiterer Pfad. Fähigkeitstests ergänzen spezifische Trigger später. |

Block verfallen lassen nur bei **eigenem** begin, Schild cap 25 und persistent. Kreaturen sind keine Helden: Heldenblock/-schild schützt Kreaturen nicht. Durchdringungs-Ankunft und Angriffsüberlauf dürfen nie dieselbe Schutzignorierungsfunktion ohne expliziten Modus verwenden.

### P05 — Kartenlebenszyklus

| Teil | Abhängigkeiten | Konkrete Änderung | Akzeptanzprüfung |
|---|---|---|---|
| P05a Basisziehen | P03c | Handcap 6, vom Deckanfang, Effektziehen ohne eigene Erschöpfungs-/Recyclelogik. | Hand 5/6, Deck 0/1, angeforderte Menge > Deck; keine verschwundene Deckkarte bei voller Hand. |
| P05b Pflichtverbrennen / Bestätigung | P05a, P04d | pendingDraw, burn ausschließlich bei echtem Überlauf in draw; ID in Ablage; finishDraw nur bei ausreichendem Platz. | 6+1 verlangt eine Verbrennung; 5+1 keine; wiederholtes/illegales burn ohne Mutation; nach Bestätigung genau main. |
| P05c Leerer Stapel und Erschöpfung | P05b, P04a | Fehlende Karten zählen; einmalige Stufe 1/2/3 je eigener Nachziehphase, direkter HP-Verlust, Serienreset. | Mehrere fehlende Karten kosten nicht mehrfach; Schutz unverändert; voller Nachzug setzt zurück; tödlicher Fall beendet Kampf. |
| P05d Deterministischer Kreislauf | P05c, P02d | Bei leerem Deck Ablage shuffle mit Seiten-/Zyklus-Seed; Ablage leeren und direkter Lebenspreis 1/2/3. | Beide Seiten, mehrere Zyklen, Teilstapel und leerer Ablagestapel; Reihenfolge/Preis sowie Todesabbruch exakt. |
| P05e Erinnerungsruf | P05d, P07a | main, einmal, 5 Resonanz, zufällige deterministische Ablagekarte auf Hand. | Gleicher Seed/round/Ablagelänge ergibt gleiche ID; Kosten/Flags, Handcap und leere Ablage; keine zweite Verwendung. |

### P06 — Ein Fähigkeitspaket pro Effekt

Jede Zeile erhält eigene JS-Golden-Übergänge und Godot-Tests; erst danach Einbindung in die Arena. Die Formeln sind keine neuen Balanceentscheidungen: `p` stammt unverändert aus dem Legacy-Katalog. Gemeinsam vorausgesetzt: P02a, P04d, P01c. Zusätzliche Abhängigkeiten stehen in der Tabelle.

| Teil / Effekt | Zusätzlich abhängig von | Abnahme einschließlich Negativfall |
|---|---|---|
| P06a strike | P04a | p+1 gegen beliebige gewählte Gegnerkreatur; Pending sperrt play/endTurn; ungültiges Ziel bleibt offen; ohne Gegnerkreaturen geschützter Helden-Fallback; KI niedrigste HP. |
| P06b guard | P04a, P03c | +p+2 Block; mehrere Quellen addieren, nächster eigener begin löscht Rest. |
| P06c ward | P04a | +p+1 Schild, cap25; bleibt über Zugwechsel. |
| P06d mend | P03a | +p+2 eigene Helden-HP bis maxHP; bei voller HP keine Überheilung. |
| P06e weave | P07a | +p+1 Resonanz, cap15. |
| P06f drain | P04a | p+1 geschützter Heldenschaden, Heilung nur tatsächlicher HP-Verlust; komplett absorbierter Treffer heilt nicht. |
| P06g rally | P03a | Linken vor rechtem Nachbarn um p ATK erhöhen; ohne Nachbarn kein Buff; Quelle selbst nicht buffen. |
| P06h silence | P04b | Gegenüberliegendes Ziel stun=max(1,stun); kein Offlaneziel; Fähigkeiten nicht entfernen. |
| P06i pierce | P04a–d | Ankunft p+2 ignoriert Schutz; Angriff nur tödlichen Überschuss durch Schutz; exakter Kill ohne Überschuss. |
| P06j shift | P07a | Nur Nachbarn der Quelle als bewegte Kreatur, Ziel irgendein freier eigener Pfad; Skip; falscher Ursprung/Ziel abgelehnt; Formation bei beliebigem eigenen Nachbarn +1 Resonanz. |
| P06k harvest | P07a | Eigener Tod nach Entfernung/Ablage erzeugt +p+1 Resonanz; kein Ankunftseffekt, kein doppelter Trigger. |
| P06l retaliate | P04a–d | Nur positiver Angriff bei überlebendem Verteidiger; p Gegenschaden, ggf. Angreifertod; toter Verteidiger vergilt nicht. |
| P06m draw | P05a | Ein Effektzug bei Ankunft, volle Hand/leeres Deck ohne Erschöpfung oder Kreislauf. |
| P06n haste | P04b | Normalen Wartezug umgehen; stun weiterhin wirksam; kein zweiter Angriff. |
| P06o weaken | P04b–c | max(weak,p), alle Kreaturen derselben nächsten eigenen Phase reduziert, mindestens0; dann Reset, keine permanente ATK-Änderung. |
| P06p pulse | P07a, P04a | +p Resonanz/+p Schild gedeckelt, beide eigenen Nachbarn +1 ATK; Quelle nicht; fehlender Randnachbar sicher. |

### P07 — Resonanz, Reaktionen und aktive Aktionen

| Teil | Abhängigkeiten | Konkrete Änderung | Akzeptanzprüfung |
|---|---|---|---|
| P07a Ressourcenbasis | P03a | Resonanz cap15, Schildcap25; Erweiterung der begin-Wirkung bei Resonanz15; kein Effekt-Dispatch nötig. | Ressourcen 14→15, 15→15; bei begin15 +2 Schild; Effekte können isoliert in Folgetests aufrufen. |
| P07b attune / Reaktion | P07a, P03c, P04a | Nach anderem Folgeorden +2 Resonanz und eine der 12 gerichteten Reaktionen; vor Beschwörungseffekt. | Alle12 Paare mit Ressourcen/Schaden, gleicher Orden/erster Ruf ohne Reaktion; Reset nach eigenem Zug; tödliche Reaktion unterdrückt folgenden summon-Effekt. |
| P07c Entfesselungen | P07a, P04a | Vier reine ordensspezifische Aktionen, Gate15, Kosten8, einmal pro Zug, passende Einheit. | n=0/1/mehrere, 14/15 Resonanz, zweite Nutzung; Thorn heilt alle eigenen Kreaturen; Veil setzt weak genau2; Ash durch Schutz. Keine automatische KI-Nutzung hinzufügen. |
| P07d Pfadmanöver | P07a, P03c | −3, einmal, benachbartes freies Ziel; kein shift-Formationstrigger. | Fernziel/besetztes Ziel/falsche Phase abgelehnt; einmal legal, zweites abgelehnt; Summoned/Stun der bewegten Einheit erhalten. |
| P07e Pfadwacht | P07a, P03c | −2, einmal, +2 Schild und +1 HP bis Basis einer eigenen Einheit. | Voll geheilte Kreatur weiterhin legal; keine Überheilung; Schildcap; ungültige Ziele ohne Verbrauch. |

### P08 — Ergebnisvertrag

| Teil | Abhängigkeiten | Konkrete Änderung | Akzeptanzprüfung |
|---|---|---|---|
| P08a Sofortige HP-Entscheidung | P04d | Sieg/Verlust/draw nach jedem relevanten Effekt/Pfad; zentrale Ergebnisfunktion. | Beide HP0 → draw; tödlicher erster Pfad verhindert weitere Treffer/Tode; reguläres play/endTurn nach Ende ohne Mutation. Ausnahmen der Legacy-Hilfs-API separat nachweisen, nicht unbemerkt härten. |
| P08b Kontrollserien beider Seiten | P08a, P03c | Eigene seals pro Seite, mindestens3 unbestrittene Pfade am Ende der eigenen Angriffsphase, zwei eigene Phasen. | Beide Seiten können gewinnen; Unterbrechung reset; Randfälle2/3 und frische/betäubte lebende Einheiten zählen entsprechend JS. |

### P09 — UI-Integration ohne zweite Regelengine

| Teil | Abhängigkeiten | Konkrete Änderung | Akzeptanzprüfung |
|---|---|---|---|
| P09a Zustandsprojektion | P03c, P05b | Arena zeigt aktive Seite, Phase, beide Ressourcen, Deck/Hand/Ablage; Commands statt direkter Feldmutation. | Kommandos im falschen Zustand deaktiviert und im Modell ebenfalls abgelehnt; schnelle Touchdoppelung bucht nicht doppelt. |
| P09b Effektauswahl | P06a, P06j, P09a | Strike-Ziele, Shift-Quelle/-Ziel und Skip; offene Wahl sperrt weitere betroffene Aktionen. | Jeder gültige/ungültige Pfad, Abbruch wo erlaubt, Wiederaufnahme; kein visueller Effekt ohne angenommenes Kommando. |
| P09c Aktive Aktionen und Vorschau | P07c–e, P05e, P09b | Manöver/Wacht/Recover/Burst und regelbasierte Angriffsvorschau. | Kosten/Schwellen/Flags sichtbar; Vorschau stimmt mit tatsächlichem Ziel/Schutz/Schaden überein, inklusive readiness/retaliate/pierce. |
| P09d Ereignispräsentation | P11b, P09c | Frames aus übernommenen Regelergebnissen; Skip/Tempo und reduzierte Bewegung ohne Einfluss auf Regeln. | Derselbe Befehlslauf mit jeder Präsentationseinstellung identische Endzustände/Hashes; Inputs während gesperrter Folge sicher. Querformat844×390/915×412/1280×720/1600×900. |

Der heutige Godot-Zauber erhält keine erfundene JS-Identität. Ein bewusst erhaltener zusätzlicher Modus benötigt eigene Regeln/Tests und darf den Legacy-Oracle nicht beeinflussen.

### P10 — Gegner statt kostenloser Erzeugung

| Teil | Abhängigkeiten | Konkrete Änderung | Akzeptanzprüfung |
|---|---|---|---|
| P10a Gleiche Ressourcenregeln | P03–P05, P08 | Gegnerhand/-deck/-energie, Draw/Überlauf wie Referenz; Aufrufe über denselben Validator. | Gegner kann nicht kostenlos/mit leerer Hand/mehr als2 Kreaturen spielen; Nachziehen/Verbrennen und Startschutz korrekt. |
| P10b Kandidaten und Auswahl | P10a, P06, P07 | Scoring easy/normal/hard inklusive Sortierung/Tie-Breaks und Zielwahl. | Gleiche Zustände → gleiche Karte/Handindex/Pfad; alle Fähigkeitsboni und Levelgrenzen1/2/5 in isolierten Fällen. |
| P10c Taktische Folge / Eröffnung | P10b | Manöver vor Summons, Schleifenlimit8, Wacht/Recover/Skip und endTurn in Originalreihenfolge; automatische gegnerische Eröffnung. | Goldene komplette Gegnerzüge für beide Münzseiten; keine Rekursion ohne Ende; nach Rückkehr Spieler aktiv oder Kampf beendet. Burst nicht als vermeintlich vorhandene KI-Funktion hinzufügen. |

### P11 — Vollständiges Kampfprotokoll

| Teil | Abhängigkeiten | Konkrete Änderung | Akzeptanzprüfung |
|---|---|---|---|
| P11a Vollständiger Snapshot | P03a, P01c | Alle JS-Felder beider Seiten, Basis-/aktuelle Werte, Pendingzustände, Deckreihenfolge, Ablage und Flags. | Kopie bleibt nach Folgemutation unverändert; kein fehlendes Feld; Hashdarstellung explizit festgelegt. |
| P11b Ereignisse und Befehle | P11a, P04d | side/type/message/seq/source/target/actionId/pendingDeath/state sowie 11 Commandwrapper und Grenzen. | Angenommene Aktion genau einmal, abgelehnte nicht; interne KI-Folgen korrekt unter äußerer Aktion; Todeszwischenzustand nachvollziehbar. |
| P11c JS-kompatibler Hash / Export | P11b, P10c | JS-JSON/FNV1a-Semantik, audit v4/replayVersion2, Seed/Level/Deck/initial/final/actions/events. | Bekannte JS-Hashes exakt; Umlaut-/Unicode-/Zahlenfälle; reine Schlüsselumsortierung nicht fälschlich als kompatibler Hash deklarieren. |
| P11d Import und Replayverifikation | P11c, P06–P08 | Neuberechnung aus initialen Eingaben und Kommandos, Vor-/Nach-/Endhashprüfungen. | Echte JS-Golden-Replays erfolgreich; unbekannte Aktion, manipulierte Hashes, illegale Wahl und unvollständiger Export nachvollziehbar abgelehnt. |

### P12 — Vollständigkeit von `game.js` außerhalb des Kampfes

| Teil | Abhängigkeiten | Konkrete Änderung | Akzeptanzprüfung |
|---|---|---|---|
| P12a Sammlung und Detailansicht | P02a | Alle100 Karten, Effekte/Seltenheit/Besitz und Filter; Konzepte separat. | Such-/Filterkombinationen, kein Konzept im Kampfpool; Werte/Erklärungen stimmen zum Regelkatalog. |
| P12b Deckwerkstatt / Presets | P12a, P02b–c | Hinzufügen/Entfernen, Besitz-/Kopienlimits und gültiges Startdeck. | 20/25 Grenzen, Legendäre, vollständiges Preset, Speichern/Neustart und ungültiger Kampfstart. |
| P12c Altstandadapter | P12b | v09 und v06/v05 Import/Export mit explizitem Mapping zu Godot-Fortschritt; vorhandene Kapitel/Helden/Settings erhalten. | Originalähnliche versionierte Beispiele, ungültige IDs/Decks/JSON atomar ablehnen; Roundtrip für Besitz/Deck/Wins/Losses/Settings; Battle bleibt nicht persistiert. |
| P12d Lokale Ökonomie / Abschluss | P12c, Zielvertragsentscheidung | Startwährung/Booster/Belohnungen/Level/Aufgabe nach altem Verhalten, soweit als Ziel bestätigt. | 240 Kosten, 3 Karten, erste mindestens selten, deterministischer Seedtest; Sieg genau einmal buchen, Niederlage/Aufgabe ohne Siegprämie; Adminlabor und sichtbare Navigation unterscheiden. Keine Echtgeld- oder Serverfunktion. |

## 4. Abhängigkeitsreihenfolge und Integrationsgates

1. P01a–c schafft Nachweiswerkzeuge, P02a–d Daten/RNG, P03a–c Grundzustand/Phasen. P07a kann danach früh unabhängig umgesetzt werden und schließt P03d ab.
2. P04a–d etabliert Angriffe/Tode. P05a–e und die jeweils abhängigen P06-Einzeleffekte werden daran schrittweise geprüft. P07b–e benötigt keine fertige KI und ist isoliert mit Zuständen prüfbar.
3. P08 und P11a–b sind Kernintegration; P09 integriert erst getestete Kommandos. P10 folgt auf die verwendbaren Regelverträge. P11c–d vervollständigt den engineübergreifenden Nachweis.
4. P12 kann nach stabilen Daten/Validierung unabhängig von visuellen Effekten entstehen. Altstandadapter benötigt ein bewusstes Mapping, keinen Austausch des heutigen Speicherformats.

**Gate A — Daten:** 100/100 IDs und sämtliche Werte unverändert nachgewiesen; ursprüngliche Decks und RNG-Golden bestehen. Keine Ersatzzuordnung nur durch Namen.

**Gate B — Kernregeln:** Alle70 Auditzeilen mit neuen konkreten Nachweisen neu bewerten. Jede der16 Fähigkeiten einschließlich Zielregeln und Triggerreihenfolge durch kleine JS-gegen-Godot-Fälle belegen. Bekannte verbleibende Abweichungen offen als solche führen.

**Gate C — Partien / Replay:** Mindestens dieselben250 Seed/Level-Partien wie `test.js` engineübergreifend mit identischen Kommandos und vollständigen Zuständen/Ereignissen vergleichen; anschließend1000 Simulationen über die11 Archetypen und3 Levelstufen. Timeouts separat melden, nicht als abgeschlossene Partie zählen. Abweichungen/fehlende Pfade zuerst als minimales reproduzierbares Szenario reduzieren.

**Gate D — Bedienung / Regression:** Bestehende Godot-UI-/Eingabe-/Präsentationstests weiter ausführen; neue Nachzieh-, Auswahl-, Resonanz-, Deck- und Replaypfade automatisieren und manuell prüfen. Mehrfache Touchaktionen, Sieg/Niederlage/Draw, volle Hand/Felder, alle vier Querformate, Bewegungsreduktion und Speicherneustart. Physische iOS-/Android-Tests ausdrücklich getrennt von Desktop/Browser-Simulationen protokollieren.

**Gate E — Liefersicherheit:** Erst grüne relevante Tests und reviewbare Belege, dann separate Integration/Veröffentlichung nach dem jeweiligen Auftrag. Dieser Audit-PR wird nicht automatisch gemergt oder deployt.

Ein uneingeschränkter Paritätsclaim ist erst vertretbar, wenn Daten, alle Regelverträge, KI, Aufzeichnungen und die übernommenen Nebenwege belegt sind. Ausgenommene Produktfunktionen oder bewusst abweichende Regeln müssen im Ergebnis benannt bleiben; die bloße Zahl erfolgreicher Godot-Regressionstests genügt nicht.
