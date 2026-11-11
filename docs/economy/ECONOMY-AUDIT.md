# ORAFOLD Wirtschaftsaudit

Stand: 2026-11-10. Ausgangspunkt `develop` bei `17121e40a49838f479d1655d88d354ed836ad20e`; eigener Branch `feature/orafold-economy`. Alle Wirtschaftswerte dieses Umsetzungspakets sind **vorläufige Testparameter**, keine Preis- oder Produktfreigabe. Dieses Audit beschreibt den Bestand **vor** der neuen Implementierung; den erreichten Umsetzungsstand dokumentieren ECONOMY-DESIGN, SIMULATION-REPORT und INTEGRATION.

## Parallelentwicklung und Quellen

Der Arbeitsbaum war nach dem Klonen sauber. Die Remote-Branches wurden inventarisiert; keine Fremdbranches übernommen und keine Merges durchgeführt. Der vorhandene Architekturbranch `architecture/f2p-economy-design` bei `d3634b462444760665ba169dcd2be7df86baddfe` ist bereits Vorfahr des Ausgangsstands. Seine Dateien in `docs/economy/` sind unverändert vorhanden: ein wertvoller **Dokumentationsentwurf**, kein ausführbares Wirtschaftssystem.

Die GitHub-Abfrage zu Beginn ergab folgende offenen Pull Requests. Offen bedeutet keine Freigabe oder Integration; der Status kann sich unabhängig von diesem Branch ändern.

| PR | Branch / Basis | Berührung vermeiden |
|---|---|---|
| [#11](https://github.com/Jagarex-lab/nachtsiegel-app/pull/11) | `feature/generic-trigger-hooks` → `develop`, Entwurf | Trigger-/Effektadapter, Kampfmodelle, Kartentests |
| [#7](https://github.com/Jagarex-lab/nachtsiegel-app/pull/7) | `feature/legacy-engine-p07` → `feature/legacy-engine-p05-p06`, Entwurf | Legacy-Reaktionen, Ressourcen, Referenzfixtures |
| [#5](https://github.com/Jagarex-lab/nachtsiegel-app/pull/5) | `feature/legacy-engine-p05-p06` → `feature/legacy-engine-p01-p04`, Entwurf | Kartenkreislauf und Legacy-Fähigkeiten |
| [#4](https://github.com/Jagarex-lab/nachtsiegel-app/pull/4) | `feature/legacy-engine-p01-p04` → `feature/legacy-foundations` | Legacy-Kernel/Regeln |

Weitere vorhandene Branches: `feature/card-system-550`, `feature/alpha-0.2-mobile-ux`, `feature/arena-quality`, `feature/combat-presentation`, `feature/premium-experience`, `feature/ux-contrast`, `feature/brand-world-bible`, `lore/orafold-worldbuilding-550-draft`, `production/audit-cleanup`, `security/pages-release-gate` und ältere Audit-/Grundlagenbranches. Ein vorhandener Branch beweist keine aktive Bearbeitung. Der konkrete Konfliktschutz dieses Auftrags besteht deshalb aus eigenen Verzeichnissen und unveränderten zentralen Dateien.

## Vorhanden, fehlend, veraltet

| Bereich | Nachweisbarer Bestand | Lücke / Integrationsgrenze |
|---|---|---|
| Aktiver Alpha-Katalog | `data/alpha/cards.json`, `scripts/alpha/catalog.gd`: **55** Karten, davon 20 gewöhnlich,31 selten,0 episch,4 legendär;15 neutral und10 je Macht | Keine vollständige550er-Sammlung. Ein Pool mit positiven Episch-Chancen darf mit diesem Katalog allein nicht aktiviert werden. |
| Legacy-Katalog | `data/legacy/cards.json`:100 Karten,44/32/20/4 Seltenheiten; eigener `ruleset_id`, ursprüngliche Ordens-IDs | Nicht mit Alpha-/Lore-IDs verschmelzen. Keine Namensheuristik oder automatische Portierung von Werten. |
| V2-Kartenbasis | `data/card_system/schema.json`, `registry.json`, `pilot.json`; acht isolierte Pilotdefinitionen (4 gewöhnlich,4 selten) | Registry/Explizitdispatch sind keine produktive550er-Freigabe. Automatische Hooks sind am Ausgangsstand nicht generisch verdrahtet. |
| Geplante550 | `data/lore/card-concepts.json`:550 **Konzeptplätze**, je110 für vier Mächte und neutral;250 gewöhnlich,160 selten,100 episch,40 legendär | Lore-/Mechanikabsichten sind keine ausführbaren, balancierten Karten. IDs bleiben unter fremder redaktioneller Hoheit. Die Wirtschaft darf eine isolierte550er-Simulationsmenge verwenden, keine finale Karte behaupten. |
| Deckbuilder | `scripts/alpha/shell.gd`, `AlphaCatalog.validate(deck)`:30 Karten, eine Macht plus neutral, max3 Kopien bzw.1 legendär; vorhandene Suche/Filter/Kartendarstellung | Validator prüft Karten-/Deckregeln, keinen Besitz. Die Bibliothek zeigt den Katalog frei. Künftige Besitzprüfung als zusätzlicher Adapter, keine Änderung der Kampfregeln. |
| Vier Starter | `AlphaCatalog.deck_ids()` und `.deck(power)`:houses/stillwatch/morph/ninth, je30 vollständige spielbare Alpha-Karten | Jeder Starter enthält15 gewöhnliche+14 seltene+1 legendäre Kopie. Gemeinsame neutrale Kopien können zwischen Decks wiederverwendet werden: max-Kopienvereinigung41 IDs/111 physische Kopien (17 gewöhnliche IDs/51 Kopien,20 seltene IDs/56 Kopien,4 legendäre IDs/4 Kopien), keine120 unabhängigen Inventarkopien. Ein neutrales gewöhnliches3er-Playset wird in allen vier Decks gemeinsam verwendet. Endgültige550er-Starter benötigen ein geprüftes Mapping. |
| Alpha-Speicher | `scripts/alpha/session.gd`: `profile` Version1, Decks/Siege/Motion/Macht/Schwierigkeit/Seed; `save_profile()` schreibt temporär und benennt um; `user://orafold_alpha_profile_v1.json` | Keine Währungen, Inventare, Rewardquellen oder dauerhafte Wirtschafts-Idempotenz. Nicht umdeuten oder ersetzen. |
| Kampagnen-/Komfortspeicher | `scripts/progress_store.gd`: schema1, `progress_v1.json`, temporär+Backup+Rename; Web zusätzlich localStorage-Mirror; Tutorial,Kapitel,Siege,Niederlagen,Held,Audio/Motion | `recorded_runs` auf32 begrenzt: kein dauerhafter Vergabenachweis. Lokale Resultate nicht vertrauenswürdig. Transport kann durch isolierten Adapter wiederverwendet werden; aktiven Spielstand nicht ändern. |
| Kampagne | `scripts/campaign_catalog.gd`, `data/campaign/chapters.json`:fünf Kapitel, Vorlagen/Helden; `ProgressStore.record_result()` schaltet Kapitel frei | Kein zentraler wirtschaftlicher Chapter-Rewardvertrag. Kampagnenbelohnungen erst an stabile eindeutige Begegnungs-/Abschluss-IDs anbinden. |
| Wirtschaft | `docs/economy/` beschreibt Serverports, ACID/Inventory/Ledger, offene Produktentscheidungen | Vor diesem Auftrag keine ausführbaren Gold-,Booster-,Crafting-,Aufgaben- oder Levelmanager. Resonanz und Energie sind bestehende Kampfressourcen und bleiben außerhalb der Wirtschaft. |
| Audio | einziger Autoload `GameAudio`, `scripts/game_audio.gd`, `.cue(name)` mit11 vorhandenen Cue-IDs | Semantische `booster.*`/`reward.claim`-Events vorbereiten; vorhandenen Manager später per Adapter bedienen. Keine neuen Audiobusse/-manager. |
| UI | aktive `alpha_shell.tscn`/`scripts/alpha/shell.gd`, bestehende `card_back`, `card_view`/`card_system/card_face`, Layout-/Motionkonventionen | Booster-/Crafting-/Goldprototyp in eigenem Szenenordner. Vorhandenen Rahmen wiederverwenden; keine Kaufoberfläche. |
| Tests/Tooling | Godot SceneTree-Tests, Node-Datenprüfungen, Python-Berichte, `tools/test_alpha.sh`, `test_master550*.sh`, Legacy-Differentialtests; Browser-QA-Skripte | Keine Wirtschafts-Monte-Carlo-Werkzeuge am Ausgangspunkt. Neues Paket benötigt eigene Seed-/Konfigversionsnachweise und Fehler-/Persistenztests. Vorhandene Testberichte sind keine neu ausgeführten Prüfungen. |
| Plattformexport | `export_presets.cfg` hat explizite JSON-include_filter für benannte vorhandene Datenordner;tools/docs/tests/work ausgeschlossen | Economy-JSON beim späteren Export explizit einschließen und Paketinhalt prüfen. Keine zentrale Export-/Produktionsdatei in diesem Paket ändern. |

## Veraltete Aussagen im erhaltenen Architekturentwurf

`current-architecture.md` und `README.md` sind korrekt als historischer Dokumentationsstand2026-11-09 bei `b1f5ea5` markiert. Aussagen über sieben Prototypkarten, fehlenden Deckbuilder und noch nicht übernommene Legacygrundlagen gelten **nicht** für den heutigen Ausgangsstand. Die alten Texte bleiben aus Nachvollziehbarkeit erhalten; dieses Audit hat für Bestandszahlen Vorrang. Die dortigen25er-Starterbeispiele sind Legacybeispiele, keine30er-Alpha-Starterverträge. Zukünftige Markt-/Servermodelle bleiben Entwürfe; der neue lokale Prototyp implementiert keinen produktiven Marktplatz.

## Architekturentscheidung dieses Auftrags

- Eigene Wirtschaftsdaten/-manager/-simulationen/-tests/-prototypszenen; keine Autoloads oder Menüpunkte im Hauptspiel registrieren.
- Eine fachliche Transaktionsgrenze für Gold,Sammlung,Booster,Pity,Crafting,XP,Aufgaben und Rewardquellen. Erst nach dauerhafter Speicherung Ergebnis präsentieren. Ein abgebrochener Reveal darf keine zweite Vergabe erzeugen.
- Bereits vorhandenen Dateitransport über Adapter verwenden. Neue Sandboxdaten erhalten einen eigenen Dateipfad/Namespace; keine parallele Ersatzimplementierung der Alpha-Profile oder Kampagnensammlung.
- Katalogadapter trennt wirtschaftliche `id/rarity/power`-Metadaten von Kampfwerten. Starterresolver liest bestehende Definitionen bei Integration, keine festgeschriebenen zukünftigen IDs.
- Lokale Bestände bleiben **nicht vertrauenswürdige Testdaten**. Hashes/Validierung entdecken Beschädigungen, authentisieren aber keinen Gerätebesitzer. Echtgeld/Handel benötigen später einen autoritativen Server, eigene Konten, atomare DB-Transaktionen und sichere Herkunftsnachweise.

Die Details und offenen Integrationsschritte stehen in [INTEGRATION.md](INTEGRATION.md). Keine Aussage dieses Audits erteilt Merge-,Release- oder Preisfreigabe.
