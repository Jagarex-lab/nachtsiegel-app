# Kampagnenaudit und Migration

Stand: 10.11.2026. Geprüfte Basis: `develop` bei `17121e40a49838f479d1655d88d354ed836ad20e`. Verbindliche Weltquelle: [LORE-BIBLE.md](../LORE-BIBLE.md), vollständig gelesen. Dieser Bericht beschreibt den Quellstand, keine nachträgliche Kanonfreigabe. Ausführungsnachweise der neuen Kampagne stehen in [QA.md](QA.md).

## Tatsächlicher Bestand

| Bestand | Implementierung | Einordnung und Vorgehen |
|---|---|---|
| Produktiver Einstieg | `project.godot` startet `scenes/alpha_shell.tscn`, gesteuert von `scripts/alpha/shell.gd` | Alpha-Duelle, Deckbau und Profile; im geprüften Shell-Skript kein Kampagnenrouting. Unverändert lassen. |
| Älterer Einstieg | `scenes/front_end.tscn`, `scripts/front_end.gd`; `run/main_scene.archive_qa` verweist darauf | Weiter ausführbarer historischer Einstieg mit Intro, Heldenwahl, Tutorial, Kampagne, Sammlung und Einstellungen. Nicht löschen oder als ORAFOLD-Hauptgeschichte ausgeben. |
| Kampagnenkatalog | `data/campaign/chapters.json`, `scripts/campaign_catalog.gd` | Fünf tatsächlich an Duelle angebundene Begegnungen; feste Seeds und KI-Profile. Format `implemented_local_prototype`. Kein allgemeiner Szenen-/Entscheidungsgraph. |
| Storybibliothek | `data/narrative/content.json`, `data/narrative/locales/{de,en}.json`, `scripts/narrative_catalog.gd` | 74 Entitäten und 275 Textschlüssel je Sprache; Manifest `creative_draft`, `runtime_enabled: false`. Trotzdem lädt der alte Einstieg ausgewählte Texte ausdrücklich. Dieses Feld allein beweist daher keine Unerreichbarkeit. |
| Narrative Entwürfe | `docs/creative/`, besonders `03-world-bible.md`, `04-factions.md`, `05-narrative.md` | Arvess/Gegenmaß. Generierte Kapitelentwürfe sind als `narrative_design_only` markiert, obwohl ein kuratierter Teil später spielbar wurde. Historische Kennzeichnungen erhalten, nicht automatisch aufwerten. |
| Historischer Erlebnisnachweis | `docs/experience/README.md`, Screenshots und QA | Dokumentiert fünf lokale Begegnungen samt Sieg, Niederlage und Wiederholung. Nachweis des damaligen Spielstands, keine Lorefreigabe und kein Testnachweis der neuen Lieferung. |
| Alter Duellanschluss | `scripts/arena.gd` und `scripts/battle_model.gd` | Arena bietet `completed(victory, reason)`, Rückkehr-, Retry- und Fortsetzungssignale. Andere Regelgeneration als die aktuelle Alpha. Keine neue Kampagne über Umbenennen dieser Figuren anbinden. |
| Alpha-Anschluss | `scripts/alpha/model.gd`, `catalog.gd`, `session.gd` | Aktuell ausführbare Kartenspielregeln. `Session.start_match(...)` startet Alpha/Legacy, `command(...)` kann Profilsiege schreiben. Für isolierte Kampagne Modell direkt über einen eigenen Adapter verwenden; keine Nebenwirkung auf den Alpha-Profilzähler. |
| Charakterwissen | Alte `characters`-Sammlung sowie `secrets` mit `writers_only_spoiler` | Kein vollständiges Trennmodell zwischen Wissen, Glauben, Spielerwissen und bestätigter Lore. Autorenfelder keinesfalls ungefiltert als Codex anzeigen. |
| Belohnungen | Historischer Fortschritt zählt Siege und Kapitel | Keine vorhandene generische Karten-/Goldvergabe für die neue Kampagne übernehmen. Konfigurierbarer Vertrag mit externem Ledger erforderlich. |

Die fünf alten Gegner heißen Tovin Marr, Ofenaufsicht, Kammerdelegation, Archivaufsicht und Orren Daal. Ihre Seeds sind 8802043 bis 8802111 in Schritten von 17; ihre KI-Profile `easy`, `standard`, `defensive`, `tactical`, `challenging`. Dies sind Auditbefunde, keine neuen ORAFOLD-Encounter-Vorgaben.

## Wiederverwendbare Technik und Oberfläche

Wiederverwendbar sind die allgemeinen Muster: stabile Text-IDs, Sprachfallback, kopierte Katalogrückgaben, Szenenreferenzen, Seed-basierte Reproduktion, resultatorientierte Rückkehrsignale, explizite Wiederholungswege, Flush/Temporärdatei/Backup und touchfähige Container. Bestehende Body-/Display-Schriften unterstützen deutsche Sonderzeichen; Lizenzen liegen unter `assets/fonts/`.

Die konkrete alte Kapitelansicht ist in den zentralen Front-End-Code eingebettet. Eine direkte Extraktion würde parallele Arbeit und Regressionen riskieren. Die neue UI bleibt unter `scenes/campaign_orafold/` und `scripts/campaign_orafold/`; zentrale UI-Szenen bleiben unangetastet. Alte Konzeptporträts sind keine Belege für Eiras Aussehen. Die neue Kampagne darf diese Bilder nicht als Eira, Fraktionsführer oder bestätigte ORAFOLD-Figuren neu etikettieren.

Die alte Arena hat echte Sieg-/Niederlagenanschlüsse, aber ihre Übernahme wäre keine Integration mit dem heutigen Alpha-Regelsatz. Der neue Adapter verwendet bestehende Regeln und bestehende Deckkataloge nur lesend. Weder feste Kartenlisten aus dem 550er-Auftrag noch Sonderregeln werden hier festgeschrieben.

## Inhaltliche Konflikte

| Altinhalt | Konflikt | Migrationsentscheidung dieser Lieferung |
|---|---|---|
| Arvess, Halt, Gegenmaß, Nullwinter, Fünferrat | Andere Weltprämisse als Zeitkorrektur und konkurrierende Wirklichkeiten | Als getrennten ALTENTWURF erhalten. |
| Schmelzkonvent, Pegelbund, Pfropfkammern, Namenkolleg | Keine alternativen Namen von Zwölf Häusern, Stillwacht, Vielgestalt, Neunter Stunde | Keine ID- oder Textumbenennung. |
| Mara, Varo, Ivara, Rian, Nemi, Eda, Sera, Acht, Tovin, Orren | Keine bestätigten Figuren der Eira-Handlung | Nicht in die ORAFOLD-Charakterdatenbank migrieren. |
| Versetztes Archiv | Identität mit ORAFOLD-Archiv ungeklärt | Kein Alias, keine gemeinsame Historie. |
| Fünf Versorgungswege | ORAFOLD-Pfade haben keine bestätigte metaphysische Bedeutung | Nur die mechanische Fünfzahl ist übertragbar. |
| Gegenmaß kann Vergangenheit nicht ändern / Tote nicht zurückbringen | Nicht ohne neue Entscheidung mit Zeitkorrektur und Wiederkehr kompatibel | Weltregeln getrennt halten. |
| Arvess-Datierung −40 bis 83 | Keine beschlossene ORAFOLD-Chronologie | Nicht als Weltzeitachse importieren. |
| Himmelsfragmente | Unbestätigter früherer Vorschlag | Keine Erklärung für fünf Pfade oder Konvergenz. |

## Speicher und aktive Abhängigkeiten

`scripts/progress_store.gd` verwaltet `user://progress_v1.json`, Schema 1. Enthalten sind Tutorialstatus, ein maximal freigeschaltetes Kapitel, Kapitelsiege, Siege/Niederlagen, Held, Einstellungen, Laufnummer, aktiver Lauf und bis zu 32 verbuchte Lauf-IDs. Backup: `.bak`, temporäre Datei: `.tmp`. Im Web existiert ein synchroner Spiegel unter `nachtsiegel.progress.v1` in `localStorage`. Alte `user://ux.cfg` übernimmt ausschließlich reduzierte Bewegung. Diese Daten bleiben unverändert.

`scripts/alpha/session.gd` verwaltet zusätzlich `user://orafold_alpha_profile_v1.json`, Version 1: Decks, Siege, Bewegungseinstellung, Seed, Macht und Schwierigkeit. Das Profil ist unabhängig vom alten Kampagnenspeicher. Alpha-Replays verwenden `user://orafold_last_replay.json`. Auch diese Dateien und deren Schreibwege bleiben unberührt.

Aktiv lesend abhängig vom alten Storybestand sind `front_end.gd`, `campaign_catalog.gd`, `narrative_catalog.gd` und historische QA. `tests/experience.gd` prüft alten Fortschritt, Kapitelübergänge und echte Kampfergebnisse; `tests/narrative.gd` prüft den alten Katalog. Ein späteres Verschieben nach `archive/` benötigt vorher eine vollständige Referenzmigration und diese Regressionstests. **Diese Lieferung verschiebt oder löscht nichts.**

Die neue Kampagne besitzt einen eigenen Speichervertrag; Details zu Namespace, Migration und Fehlerbehandlung stehen in [ARCHITECTURE.md](ARCHITECTURE.md). Alte Kapitelnummern werden niemals stillschweigend in neue Story-IDs übersetzt. Ein Sieg gegen Tovin ist kein Sieg in einer ORAFOLD-Erzählung. Isolierte Persistenz vermeidet zugleich das Risiko, dass ein parallel veränderter zentraler Speicher überschrieben wird.

## Spätere Integration und Archivierung

1. Eigener Menüeintrag im aktuellen Einstieg nach Abstimmung mit Mobile-UX-Auftrag. Ziel ist die eigenständige Kampagnenszene, nicht der historische Einstieg.
2. Regelprofil, Deckslots und KI-Schwierigkeit gemeinsam mit Kampf-/Katalogauftrag bestätigen. Adaptervertrag anbinden, keine Regeln aus Dialogdaten ausführen.
3. Gemeinsames Profil nur durch additive namespacierte Einbindung migrieren. Originaldateien und lokalen Browser-Spiegel vor der Migration sichern; Fallback, kaputte Dateien, unbekannte zukünftige Version und unmittelbares Browser-Neuladen prüfen.
4. Optionale Übernahme von Accessibility-Präferenzen separat anbieten. Decks, Siege und alte Storyentscheidungen nicht konvertieren, solange es keine explizite Zuordnung gibt.
5. Belohnungsadapter erst mit bestätigten externen IDs und dauerhafter Idempotenz verbinden. Ein mehrfach gemeldetes Kampfergebnis oder Kapitel-Replay darf keine zweite Vergabe erzeugen.
6. Arvess-Auswahl sichtbar als historischer Prototyp kennzeichnen, falls sie später wieder im Produktmenü erscheint. Eine Archivierung des Quellbestands ist ein eigener, überprüfbarer Folgepatch.
7. Narratives Audio durch vorhandenen Audioauftrag an Storyereignisse anschließen. Fehlender Empfänger blockiert keinen Dialog.
8. Kein Merge und keine Veröffentlichung durch diese Migration. Branch/PR und QA-Artefakte sind gemäß `AGENTS.md` keine Releases.

## Auditgrenzen

Der Bericht hat Implementierung, Daten und vorhandene Testquellen untersucht. Historische Logs werden als historische Evidenz zitiert. Er behauptet weder physische Mobile-Tests noch eine erneute Ausführung sämtlicher damaliger Export-/Live-Prüfungen. Die neue Lieferung dokumentiert ihre eigenen tatsächlichen Läufe in [QA.md](QA.md).
