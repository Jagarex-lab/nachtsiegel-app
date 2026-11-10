# ORAFOLD – sichere Bereinigung und Kartenmigration

Stand: 10. November 2026, Ausgangspunkt `795be306470073276f53d1bcf8f85e5ad1278fe0`. **In diesem Audit wurden keine Karten, Assets, Referenzdaten oder alten Codepfade gelöscht.** Ein historischer Name ist kein Beleg für Nutzlosigkeit. Die neue Nutzeranweisung erlaubt die kontrollierte Ablösung aktiver Karten, verlangt davor Referenz- und Speichermigration.

## Referenzprüfung und Entscheidungen

| Kandidat | Tatsächliche Referenzen | Sichere Entscheidung jetzt | Bedingung für spätere Ablösung |
|---|---|---|---|
| 55 Alpha-Karten `data/alpha/cards.json` | AlphaCatalog, aktuelle Session/UI/KI, vier Starter, zehn Testdecks, gespeicherte Nutzerdecks, Replay-Setup, Text-/Regel-/Browserprüfungen. | **Aktiv beibehalten**, bis Nachfolgeprogramm spielbar und Migration definiert ist. | Pro ID `keep`/`replace`/`archive` mit neuer ID oder begründetem Wegfall; alle Starter/Testdecks/Savekontexte prüfen. |
| Umleitung `oa-ninth-e01` | Alpha-Starterdaten, Alpha-Regeltests, native Impulsmatcher, Textgenerator; aus zehn neuen Testdecks ausdrücklich ausgeschlossen. | Bekannten Inhaltsblocker dokumentieren; kein stilles Löschen/Verändern. | Legale verzögerte Quelle innerhalb Neunte Stunde/Neutral hinzufügen und über Session testen, oder Karte ausdrücklich neu definieren und versionieren. |
| 100 Legacy-Karten `data/legacy/` | LegacyCatalog, separate Session/QA, Legacy-Deckvalidator, Referenzgeneratoren/Differentialtests, Alpha-Erbschaft/Displaydaten. | **Historische Regression behalten**, außerhalb normaler Alpha-Sammlung. | Auslieferungsgröße separat optimieren; Quellpfade erst mit allen Tests/Exporten ändern. Der fixierte Originalpool bleibt reproduzierbar erhalten. |
| Sieben Prototypkarten `data/card_definitions.gd` | `arena.gd`, `battle_model.gd`, Archiv-Front-End/Kampagne, Creative-/Legacyfoundations-/Darstellungs-/Kampagnentests und exportierte Archivprüfung. | **Historischer Prototyp behalten**. | Erst Archivpaket aus öffentlichem Build lösen und Tests auf separatem Preset weiterhin bestehen lassen; keine normale Produktionskarte. |
| Arvess-Kampagne/Narrative | `front_end.gd`, `campaign_catalog.gd`, `narrative_catalog.gd`, `tests/experience.gd`, Kampagnenseeds/Balance/Creativevalidierung, Archiv-Export. | **Als Altentwurf getrennt erhalten**, keine ORAFOLD-Kanonbehauptung. | Neue Kampagnengeschichte braucht Freigabe. Technische Funktionen können weiterverwendet werden, Texte werden nicht blind ersetzt. |
| Acht V2-Pilotansichten `data/card_system/pilot.json` | Vertrags-/Runtime-/PR11-Bindertests und Illustrationsmanifest. | **Test-/Migrationsreferenz behalten**, nicht zusätzlich aktiv zählen. | Nach generischer Produktionsmigration als historische Bindungsfixtures behalten oder klar migrieren. |
| 550 Konzepte `data/lore/card-concepts.json` | Lore-Dokumentation, Familien/Orte/Figuren, kreative Autorenquellen. | **Vorschläge erhalten**, nicht direkt als aktive Karten laden. | Produktionsdatensatz verweist per `concept_id`; ersetzte Namen/Mechanik dokumentieren. Kanonstatus bleibt unabhängig. |
| Geteilter Konzeptatlas | Kompakte Hand-/Feldkarten, Vollinspektor und ältere Arena/Heldenporträts, Assetprüfer und Vorschaubilder. | **Behalten**, solange tatsächliche Fallback-/Archivverwendung besteht. | Jede aktive Karte und jeder Held erhält gültige Nachfolgezuordnung; Artfallback muss sichtbar bleiben. |
| Alte Arenabilder/Rahmen/Materialien | Alpha-Menühintergrund sowie Archiv-/Premiumdarstellung und Screenshottests. | **Kein verwaistes Asset bestätigt**. | `rg`-Referenz plus tatsächliche ResourceLoader-/Exportinventur und dynamische Pfade prüfen. Ein nicht mehr öffentlich sichtbares Bild kann noch QAreferenziert sein. |
| Alte Effekt-IDs/Matcher | Bestehende Alpha-/Legacykarten und direkte Tests. | **Behalten**; generische Engine führt Defaultpfade nicht doppelt aus. | Nachfolger besitzt explizite Ownership, originale Replays/Legacy bleiben kompatibel; kein ungültiger Fallback nach teilweise ausgeführtem Programm. |
| `work/`, alte lokale Exportdateien | Ignorierte Build-/QAartefakte, nicht Quellkarten. | Nicht versionieren; frisches Staging verhindert Anhäufung. | Alte lokale Dateien dürfen bei Platzbedarf gezielt entsorgt werden, aber Belege für laufende QA/Release nicht überschreiben. |

Es wurden Referenzen mit `rg` über `scripts/`, `scenes/`, `tests/`, `tools/`, `project.godot` und `export_presets.cfg` geprüft. Entscheidende Beispiele: `scripts/alpha/session.gd` lädt Legacyanzeigen, `tests/legacy_foundations.gd` verlangt den Originalpool, `tests/exported_experience.gd` lädt die Prototypen/Kampagne, und `project.godot` besitzt einen besonderen `archive_qa`-Einstieg. Eine Löschung allein anhand der aktiven Startszene wäre fehlerhaft.

## Migrationsvertrag für den neuen aktiven Katalog

1. Bestehende stabile Alpha-ID behalten, wenn Identität und Vertrag weiterbestehen. Regeländerung trotzdem im Regeln-/Katalogprofil versionieren.
2. Für jede entfernte/ersetzte ID einen expliziten Datensatz führen: `old_id`, `decision`, `new_id`, `reason`, `effective_catalog_version`, `lore_status`, betroffene Decks und Replays.
3. Deckmigration erhält Reihenfolge und Kopien, soweit legal. Nicht mehr gültige Listen werden unter ursprünglichem Namen/Originaldaten in eine Quarantäne übernommen; verständliche Reparaturhinweise statt Verlust oder unkontrollierter Zufallsersatz.
4. Deckvalidierung nach Migration: genau 30, eine Macht plus Neutral, maximal drei normale/eine legendäre Kopie, nur aktive IDs. Historische neutral-only-Decks als eigener Kompatibilitätsfall erhalten/kennzeichnen.
5. Profil atomar ersetzen und last-good-Backup behalten. Fehlerhafte/unbekannte Versionsdaten nicht still mit leerem Profil überschreiben. Alte Profile und echte Neustarts separat testen.
6. Replays binden ursprünglichen Regeln-/Kataloghash. Alte Replaydaten niemals unter veränderten Fähigkeiten als „identisch“ ausführen. Unterstützte historische Profile behalten oder sauber als nicht mehr abspielbar melden.
7. Legacy und Sieben-Karten-Prototyp bleiben deutlich getrennte Archive; normale Sammlung lädt ausschließlich den aktiven Produktionskatalog. Archivkarten nicht über eine bequeme Poolvereinigung einblenden.
8. Für entfernte Illustrationen Referenzen über aktive Daten, Archivfixtures, Menüs/Helden, Manifest und dynamische Resolver prüfen. Nur echte Referenzfreiheit berechtigt zur Quelllöschung.

## Bereinigungsbilanz dieses Audits

| Maßnahme | Anzahl / Ergebnis |
|---|---|
| Gelöschte aktive Alpha-Karten | **0** |
| Gelöschte Legacy-Karten/Referenzen | **0** |
| Automatisch umbenannte/ersetzte Karten | **0** |
| Gelöschte Illustrationen/Assets | **0** |
| Bestätigte Referenzfreiheit für Quelllöschung | **Keine** |
| Bereits getrennte historische Bestände | 100 Legacykarten und sieben Prototypkarten; keine zusätzlichen Alpha-Karten. |

Diese Nullbilanz ist eine Sicherheitsentscheidung vor dem Nachfolgekatalog, keine Behauptung einer bereits vollständig bereinigten Produktion. Das folgende Implementierungspaket aktualisiert die Bilanz anhand tatsächlich migrierter IDs und erfolgreich geprüfter Abhängigkeiten.
