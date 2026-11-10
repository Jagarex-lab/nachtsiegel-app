# ORAFOLD – Produktionsaudit

Stand: 10. November 2026. **Unveränderter Ausgangspunkt dieser Prüfung ist `develop` `795be306470073276f53d1bcf8f85e5ad1278fe0`.** Später in diesem Produktionszweig entstehende Implementierungen sind keine rückwirkenden Eigenschaften dieses Ausgangspunkts. Ziel ist die tatsächliche Fertigstellung; dieses Dokument allein erfüllt sie nicht.

Die Bestandsaufnahme beruht auf dem Startprojekt, den Datenkatalogen, Alpha-/Legacy-Modellen, Session, UI, Rendering, Audio, Speicherverwaltung, Kampagnenkatalog, Quell-/Exportprüfern, Workflows und PR-Metadaten. Historische Prüfberichte werden als historische Nachweise bezeichnet. Eine Datenzeile, eine Registry-ID oder ein Konzept zählt weder als ausgeführte Fähigkeit noch als fertige Illustration.

## Branches, Integration und Veröffentlichung

| Gegenstand | Festgestellter Stand |
|---|---|
| PR #10 | [Gemergt](https://github.com/Jagarex-lab/nachtsiegel-app/pull/10), Head `0835f7c0b0588a146165e9b5e2cebce0164f5263`, Merge `fde508e85a2866e24653ef25d920a59832d2d653`; alle abgefragten Checks erfolgreich. |
| Bekannte veröffentlichte Basis | `fde508e85a2866e24653ef25d920a59832d2d653`, manueller Pages-Lauf [42866035677](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/42866035677). Die nach Veröffentlichung geprüften Desktop-/WebKit-Partien gehören zu diesem Commit, nicht automatisch zu neuen Änderungen. |
| PR #11 | [Offener Draft](https://github.com/Jagarex-lab/nachtsiegel-app/pull/11), Head `70cc08e482e17ac1bcec53a02ba95c78583df8bf`, Basis `develop`; abgefragte historische CI-Checks erfolgreich. Opt-in-Profil, kein aktiver Sessionwechsel. Vor Übernahme aktuellen Integrationsstand erneut prüfen. |
| PR #12 | [Gemergte vorläufige Arbeitsgrundlage](https://github.com/Jagarex-lab/nachtsiegel-app/pull/12), integrierter Stand `795be30`; Lore und 550 Konzepte, keine Kampfruntimeänderung und keine automatische Kanonisierung. |
| Aktuelles develop-CI bei Abfrage | [42885455505](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/42885455505) noch laufend; Release-Sicherheit [42885455473](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/42885455473) erfolgreich. Dies ist eine zeitgebundene Beobachtung, keine spätere Freigabe. |
| Ältere offene Legacy-PRs #4/#5/#7 | Historisch gestapelt; benötigte Implementierungen gelangten bereits mit Alpha #8 in die integrierte Historie. Nicht erneut pauschal mergen. |

Die aktuelle Nutzerfreigabe erlaubt getestete Merges und manuelle Veröffentlichung. Sie erlaubt weder das Umgehen aktiver GitHub-Regeln noch eine Wiederherstellung automatischer Publisher. `AGENTS.md` und [Releaseverfahren](../release/PAGES_RELEASE_SAFETY.md) bleiben technisch maßgeblich.

## Nachgezählter Kartenbestand

| Quelle | Tatsächliche Daten | Status |
|---|---|---|
| `data/alpha/cards.json` | **55 aktive IDs**: 37 Wesen, zwölf Impulse, sechs Relikte; neutral 15, je Macht zehn. Seltenheiten 20 gewöhnlich / 31 selten / null episch / vier legendär. | Vorhandener aktiver Pool; eine bekannte Voraussetzungslücke verhindert die pauschale Aussage „alle 55 in legalen Decks vollständig nutzbar“. |
| `data/card_system/alpha_species.json` | Eine oder zwei gleichwertige Arten für alle 37 Alpha-Wesen. | Aktive Metadaten/Filter, noch keine allgemeine automatische Artensynergie. |
| `data/card_system/pilot.json` | Acht strukturierte Ansichten bestehender Alpha-IDs. | Keine zusätzlichen Karten; keine allgemeine Produktionsfreigabe. |
| `data/legacy/cards.json` | **100 ursprüngliche Wesen**, stabile IDs/Werte; fünf alte Decklisten. | Getrennter Referenz-/Regressionpool; kein Bestandteil der normalen Alpha-Sammlung. |
| `data/card_definitions.gd` | Sieben ältere Prototypkarten. | Historischer Spiel-/Kampagnenprototyp; eigener Renderer und Tests. Nicht als weitere Alpha-Karten zählen. |
| `data/lore/card-concepts.json` | **550 Konzeptplätze**, je Zugehörigkeit 110; 350 Wesen / 125 Impulse / 75 Relikte; 250 gewöhnlich / 160 selten / 100 episch / 40 legendär. Alle `status: VORSCHLAG`, `prototype_only: true`, alle 550 Namen eindeutig. | **Noch nicht implementierte Karten**: keine Energiepreise, Kampfwerte, validierten ausführbaren Fähigkeitsprogramme oder individuellen Bilddateien. Die neue Produktionsentscheidung darf Entwürfe gezielt ersetzen. |

SHA-256 des unveränderten Ausgangspools: Alpha `0e5fcc20589961c5bdca662642870bc9abfc483b0ef2aebfbbf88be2876355ef`, Legacy `0e70a27c6c70e8bc5e8d527b4fbbb76201ae0d004c7b1cb29202b219cf229ffe`, Konzepte `b7e6bfd396bf899df8ca00d46c138fefd18f23923313c68e86ff8caf9dc5668b`.

## Funktions- und Qualitätsmatrix

„Fertig und getestet“ gilt hier für den bestehenden begrenzten Alpha-Vertrag und seine genannten bisherigen Tests. Es bedeutet keine Abnahme desselben Systems für 550 neue Karten.

| Bereich | Kategorie | Befund und primäre Quelle |
|---|---|---|
| Fünf Kampfpfade, leerer Gegenpfad trifft Held | **Fertig und getestet** | `scripts/alpha/model.gd::attack_phase`, geerbter Kernel; direkte Angriffe bleiben verbindlich. Gewöhnlicher Heldenschaden verbraucht Block, dann Schild, dann LP. |
| Block, Schild, Heilung, Stasis, Schwächung | **Fertig und getestet**, begrenzter Umfang | Konkrete native Handler; Kreaturenschutz in `hit_unit`. Durchdringen-Ankunft umgeht **Block und Schild**, gewöhnlicher Angriff/Überlauf nicht. |
| 30 Karten / 30 LP / fünf Starthandkarten | **Fertig und getestet** | `scripts/alpha/model.gd::start_alpha`, Katalog und Alpha-Regeltests. |
| Mulligan auf dem Spielfeld | **Fertig und getestet** | Tatsächliche fünf Pfade bleiben sichtbar; Austauschmarkierung, Inspektion, Bestätigung, Ursprünge/Zweite Möglichkeit in `scripts/alpha/shell.gd`. Keine separate alte Menülösung wiederherstellen. |
| Ursprung / Zweite Möglichkeit | **Fertig und getestet** | Einmaliger Ursprungsschild; zweiter Spieler optional Ursprung ändern und Handkarte tauschen, tatsächliche Regeltests. |
| Konvergenz / LP-Sieg / Gleichstand | **Fertig und getestet** | Drei konkrete kampffähige unbestrittene Instanzen nach fünf vollständigen Runden; Gegner erhält Antwortzug; LP-Prüfung vor Konvergenz. Umfangreiche Timing-/Instanzgrenzfälle vorhanden. |
| Nachziehen / Handlimit / Verbrennen / Recycling | **Fertig und getestet** | Gemeinsamer Kernel; Handlimit sechs, geordnete Ablagen, Erschöpfung, Wiederholungskosten und Rückholung. Noch keine generischen Draw-/Discard-Trigger. |
| Energie und Resonanz | **Teilweise implementiert** gegenüber Produktion | Produktiv Energie 1→8 und Resonanzreserve bis 15. Karten neun/zehn regulär nicht erreichbar. Getrennte Ressourcen und bestehende Sonderaktionen funktionieren. Noch kein allgemeiner gedruckter Resonanzkostenvertrag. |
| Zwölf gerichtete Legacy-Reaktionen | **Fertig und getestet** als Legacy-Regeln; **blockiert** für legale Alpha-Konstruktion | Verlangen zwei verschiedene nichtneutrale Ordnungen; Ein-Macht-plus-neutral-Alpha kann sie nicht erzeugen. Nicht heimlich Mehrmachtdecks zulassen. |
| Vier Entfesselungen | **Fertig und getestet** | Bestehende vier Effekte/Schwelle/Kosten im Kernel; neue Kartenkombinationen benötigen neue Tests. |
| Relikte | **Teilweise implementiert** | Maximal ein Slot, kein Pfad, Ersetzen legt altes ab. Aktivierung 1 Energie einmal je eigenem Zug; Ersetzen erneuert Nutzung nicht. Vier konkrete Handler, keine allgemeine Aura-/Ladungs-/Reaktionsarchitektur. |
| Bestehende lange Effektketten | **Fertig und getestet**, begrenzt | FIFO und Zyklus-/Schrittgrenzen im Alpha-Kernel; bestehende Echo-/Todesketten getestet. Keine vollständige 16-Trigger-Garantie. |
| Deklarative Effekt-Engine | **Teilweise implementiert** | `scripts/card_system/runtime.gd`: expliziter Adapter für vorhandene Effekte, stabile Ziel-UIDs/Fizzle, Kostenvalidierung, Log. Registry beschreibt Kategorien und Trigger; Beschreibung ist kein Hook. |
| Automatische Trigger in PR #11 | **Teilweise implementiert**, außerhalb aktiver Session | Nur source-bound `on_play`, `on_summon`, `on_death`, je gebundener Originalkarte genau eine passende Fähigkeit; Reliktaktivierung nur beobachtet. 13 ausführbare Triggerfamilien bleiben offen. |
| Allgemeine Passiv-/Reaktions-/Bedingungsprogramme | **Noch nicht umgesetzt** | Kein geschlossener Produktionsvertrag mit Reaktionsfenstern und freien Kombinationen. |
| „Umleitung“ `oa-ninth-e01` | **Fehlerhaft / Inhaltsblocker** | Eigenes verzögertes Ereignis erforderlich; einzige aktuelle Quelle `oa-stillwatch-e01` liegt außerhalb legaler Neunte-Stunde-Decks. Handler selbst getestet, normale Voraussetzung nicht erreichbar. Neue passende Quelle oder ausdrücklich dokumentierte Überarbeitung erforderlich. |
| KI | **Teilweise implementiert** | Spielt ganze legale Partien und bewertet vorhandene Karten/Relikte/Konvergenz. Schwierigkeitsparameter existieren; keine nachgewiesene Strategie-/Kombinationskompetenz für 550 Karten. |
| Bestehende Balance | **Fehlerhaft / Warnbefund** | Ressourcenversuch: Neunte Stunde 24/24 Nichtspiegelsiege je Bedingung. Kleine gepaarte KI-Stichprobe, kein Beweis menschlicher Siegrate; dennoch kein „weitgehend ausbalanciert“-Nachweis. |
| Sammlung/Deckbuilder | **Fertig und getestet** für 55; **teilweise** für 550 | Tatsächliche Suche/Filter/Sortierung/Inspektion, Kopienlimits, vier Starter, zehn unterschiedliche Testvorlagen, ausdrückliches Speichern. Große Liste/virtuelle Darstellung und neue Synergien noch prüfen. |
| Deckregeln | **Fertig und getestet** mit dokumentiertem Randkonflikt | Exakt 30, eine Macht plus Neutral, normale Karten max. drei, legendäre max. eins. Katalog/alte Profile akzeptieren auch rein neutral, aktuelle Werkstatt fordert gewählte Macht. Migration darf alte gültige Decks nicht still löschen. |
| Profil/Deckspeicherung | **Teilweise implementiert** | `scripts/alpha/session.gd`: Version 1, validiert geladene Decks, `.tmp`+Rename. Keine laufende Partie nach Prozessabbruch, kein Alpha-Backup-/Quarantäne-/Katalogmigrationsvertrag. |
| Replay | **Fertig und getestet** für native Alpha/Legacy; **teilweise** für neue Engine | Setup/Befehle/Zustandshashes Version 1. PR11-Profil/Binder nicht enthalten; angenommene technische Fehler aktuell nicht als erfolgreicher Befehl aufgezeichnet. |
| Mobile Touch/Drag/Rotation | **Fertig und getestet** in Browserprofilen | Drag plus Tap; Cancel-/Blur-/Rotationstoken verhindert ungewolltes Spielen. WebKit/Chromium, keine physischen Gerätetests. |
| Rendering/Schärfe | **Fertig und getestet**, Assetgrenze bleibt | Adaptiver nativer Canvas/DPR, deaktiviertes starres Stretch, MSDF-Schriften, Safe Areas. Geteilter Atlas liefert keine hochaufgelösten Einzelillustrationen. |
| Kartenmaster/Rückseite | **Fertig und getestet** als Komponente | Einheitliche 756×1056-Außenkontur, Diagonalrahmen, Machtfarbe und Seltenheitsstruktur; Vollinspektor integriert. Kleine Feld-/Handkarten kompakt. Kein vollständiger globaler Premium-Neubau abgeschlossen. |
| Animation/Feedback | **Teilweise implementiert** | Begrenzte kurze Linien/Ringe/Zahlen, Eröffnungsausteilen und reduzierte Bewegung. Vollständige choreografierte Schild-/Block-/Tod-/Relikt-/Ablagefamilien offen. |
| Ton | **Fertig und getestet** als Infrastruktur, **teilweise** als Produktion | Getrennte Music/SFX/UI-Busse, begrenzte Stimmen, erste Interaktion entsperrt Audio. Elf eigene synthetische Cues und zwölfsekündige Atmosphäre; kein aufwendiger vollständiger Soundtrack. |
| ORAFOLD-Kampagne/Tutorial | **Noch nicht umgesetzt** als neue Lore-Erfahrung | Aktive Alpha startet Duelle; vorhandene fünf Kampagnenkapitel/Mara/Varo stammen aus Arvess-Altentwurf und sind getrennte Archivprototypen. Keine stillschweigende Kanonübernahme. |
| Lore | **Teilweise implementiert** als Arbeitsgrundlage | `docs/LORE-BIBLE.md` ist Referenz; `docs/lore/` und `data/lore/` aus #12 ausdrücklich Vorschläge. Eira/Archiv/Zeitkorrekturdetails bleiben offen. |
| Produktmetadaten | **Veraltet** | `project.godot` nennt weiterhin NACHTSIEGEL in `config/name`/Beschreibung; aktive öffentliche UI heißt ORAFOLD. Kontrollierte Metadatenanpassung möglich, Speicher-/URL-Namen nicht blind umbenennen. |
| Legacy- und Sieben-Karten-Architektur | **Veraltet für reguläre UI**, als Regression notwendig | Nicht Bestandteil normaler Sammlung; `archive_qa`/`legacy_ui_qa`, Tests und Referenzdaten weiterhin benutzt. Nicht allein wegen alten Namens löschen. |
| Nachweislich überflüssige Daten | **Kein sicher löschbarer Kandidat bestätigt** | Gesonderte [Bereinigungsprüfung](CLEANUP.md); die Abwesenheit aus öffentlicher Navigation beweist keine Referenzfreiheit. |
| Builds/CI | **Fertig und getestet** für bestehende Web-Alpha | Node/native/export plus Chromium/WebKit-Matrix, getrennte Legacy-/Releaseprüfungen, frisches Buildstaging und Paketinventur. Neues Datenverzeichnis muss explizit exportiert/getestet werden. |
| Native Plattformen | **Teilweise implementiert / blockiert** | Linux-/Android-QA-Exportprofile vorhanden; Android-SDK/Signierung/echte Geräte gesondert prüfen. Kein iOS-Preset, Xcode-/Signatur-/Geräteabnahme nicht vorhanden. |
| Veröffentlichungsprozess | **Fertig und getestet** im letzten Live-Release | Nur manuelles Dispatch mit vollständigem develop-SHA, genau passendem erfolgreichem Gesamtrun, SHA-Bestätigung und aktiven Environment-Regeln. Neue Quelländerung allein publiziert nichts. |
| Echtgeld/Online/Handel | **Noch nicht umgesetzt**, bewusst | Architekturpapier vorhanden; keine zahlenden Konten, Serverbesitz oder Onlinefunktionen vortäuschen. |

## PR-#11-Übernahmeprüfung

Der Quellreview bestätigt eine sorgfältig begrenzte Brücke statt einer zweiten Kampfengine. Die Standard-Extensionpoints sind leer/defaultgleich, Todesablage und Nativequeue bleiben erhalten. Schwacher Model-Rückbezug verhindert den RefCount-Zyklus; synchrone Drains halten das Modell lokal, UID-Deduplizierung verhindert doppelte Ankunft/Tod, Fehler stoppen Folgeeinträge. Die historische Suite meldet 506 Bridge-Assertions und bestehende Alpha-/Legacy-Regressionsnachweise; im Audit wurden diese nativen Suiten **nicht erneut ausgeführt**.

Vor allgemeiner Integration zwingend:

1. Echte automatische Hooksemantik für die fehlenden 13 Familien; Angriff/Schaden/Tötung brauchen Quellenprovenienz statt Nettodelta-Heuristik.
2. Session-/Replayprofil mit Version und vollständiger Karten-/Fähigkeitskonfiguration; atomare ungültige Aktionen von angenommenen terminalen Kettenfehlern unterscheiden.
3. Generalisierte neue Karten und mehr als eine Fähigkeit benötigen einen neuen validierten Vertrag; bestehendes `source_binding` akzeptiert absichtlich ausschließlich Originalwerte.
4. `strike` mit neuer Zielwahl ist als Binding abgewiesen; Pending-/Command-/UID-Vertrag muss bestehen, bevor neue Zielkarten freigeschaltet werden.
5. PR11 lässt einen ausgelösten Ankunftseffekt bei verschwundener/verschobener Quelle fizzeln. Legacy kennt diese zusätzliche UID-Bindung nicht. Für neue Karten explizit Timing entscheiden und testen; keine unbeabsichtigte Legacy-Änderung.
6. Limits von Runtime und delegierter Nativequeue sind getrennt. Ein 1.000er-Adapterbudget ist kein gemeinsames Budget für beliebig viele native Untereffekte.

## Ressourcen und messbare Balancegrenzen

Die [bestehenden Experimente](../master550/RESOURCE_EXPERIMENTS.md) umfassen drei Profile × 16 geordnete Starterpaarungen × vier ausgewählte Seeds = 192 Matrixpartien, dazu sieben Verifikationen. Alle Modelle hatten 29/64 Startspielersiege. E10/R15 änderte gegenüber E8/R15 keinen der 64 gepaarten Sieger; viel Zusatzenergie blieb ungenutzt, da alle bestehenden Karten höchstens sechs kosten. Neunte Stunde dominierte in allen Bedingungen. Diese Daten rechtfertigen weder eine endgültige Balanceaussage noch eine automatische Produktionsumstellung. Neue Kartenkosten, Zielbedingungen und Gegenstrategien benötigen eigene Simulationen.

Energie bezahlt Karten; Resonanz bleibt zugübergreifend für Eingriffe. Neutral↔Macht-Wechsel liefert +2 Resonanz; konkrete Fähigkeiten/Formation/Relikte weitere Quellen. Pfadmanöver kostet drei, Wacht zwei, Rückholung fünf; Entfesselung verlangt 15 und bezahlt acht. Reliktaktivierung aktuell eine Energie. Resonanz-, Schild- und Handobergrenzen müssen auch bei neuen Reaktionen gelten.

## Grafik, Herkunft und kommerzielle Grenzen

Die Alpha teilt sieben Motive aus `assets/art/atlas.png`, etwa 415×421 Pixel pro Zelle; neun Motive sind im Atlas vorhanden. **Null endgültig einzeln abgenommene Alpha-Kartenillustrationen** sind durch diese Pipeline belegt. Kartenrenderer und Illustrationen sind getrennt. `assets/ASSET_MANIFEST.md`, `assets/audio/README.md`, `assets/fonts/LICENSE`, `assets/fonts/Cinzel-OFL.txt` und `LICENSE-NOTICE.md` dokumentieren Quelle bzw. Lizenz.

Vorhandene Bilder sind projektbezogene KI-Konzeptassets; es gibt keine belastbare Einzelabnahme für 550 Karten und keine behauptete Exklusivität oder vollständige Rechtsprüfung. Audio ist eigener mathematischer Synthese entnommen, Schriften DejaVu/Cinzel besitzen mitgelieferte Lizenzen. Neue Bilder benötigen Originaldatei, Prompt/Quelle, Generator/Datum, Hash, Abmessungen, Zuordnung, sichtbare Motivprüfung und getrennten kommerziellen Freigabestatus. Bildgenerierung ist als Werkzeug verfügbar; fehlende Bilder dürfen daher nicht pauschal mit „kein Werkzeug“ begründet oder als fertig ausgegeben werden.

## Im Audit tatsächlich erneut ausgeführte Tests

Auf dem unveränderten Ausgangsstand `795be30`:

```sh
node --test tests/alpha_card_texts.test.cjs tests/build_alpha_staging.test.cjs tests/card_system/*.test.cjs
python3 -m unittest discover -s tests/release -v
```

Ergebnis: **44 Node-Testgruppen bestanden, null Fehler/übersprungen; acht Release-Sicherheitstests bestanden.** Rohlogs: `work/production-audit/node.log`, `work/production-audit/release.log` (ignorierte lokale Artefakte). Dies sind gezielte Vertrags-/Sicherheitsprüfungen, kein neuer Gameplay-, Export-, Browser- oder Gerätetest. Historische vollständige Nachweise bleiben in [MILESTONE_REPORT](../master550/MILESTONE_REPORT.md) und PR10. Ein späteres Produktionspaket muss seine tatsächlichen Änderungen erneut testen.

## Abnahmeblocker in Prioritätsfolge

P0: generische Runtime/Session-/Replayintegrität; erreichbare Kartenbedingungen; endliche Queue/Resonanzketten; keine verlorenen gespeicherten Decks; unveränderte Fünf-Pfade-/Heldenregel.

P1: 550 echte semantisch verschiedene Datensätze mit einzeln belegten Fähigkeiten, 110 je Zugehörigkeit; KI/Testdecks und größere reproduzierbare Simulation; belastbare Sammlungsskalierung; eindeutige deutsche Texte; neue aktive Kartenmigration.

P2: 550 individuelle Motivillustrationen mit technischer, visueller und Provenienzabnahme; vollständige Animation/Ton/Tutorial-Erfahrung; physische Mobilgeräte, Android/iOS-Builds und kommerzielle Schlussprüfung.

Die Priorität Gameplay vor Veredelung verschiebt keine finale Abnahmebedingung: Ein 550er-Katalog ohne fertige Einzelillustrationen bleibt unvollständig.
