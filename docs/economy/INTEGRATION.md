# Integration des isolierten Wirtschaftspakets

Ergänzung zu PR #16: Die [Monetarisierungsanalyse](MONETIZATION-REPORT.md) verwendet ausschließlich `data/economy/analysis/monetization.json` und neue Python-Werkzeuge. Ihre alternativen Goldbudgets, Zielkartenpfade und hypothetischen Geldbeträge sind nicht in den Godot-Managern aktiviert. Reproduktion: `python3 tools/economy/simulate_monetization.py`. Die vorhandene Testsuite nimmt die neuen `economy_monetization*_test.py` automatisch auf. Eine spätere Freigabe eines Modells benötigt gesondertes Produktbalancing, Server-/Zahlungsintegration und reale Nachfrage-/Decktests.

Stand:2026-11-10. **Nicht in das Hauptspiel integriert. Alle Zahlen vorläufig.** Der Ausgangsstand ist `develop@17121e40a49838f479d1655d88d354ed836ad20e`; Arbeitsbranch `feature/orafold-economy`. Dieses Paket darf separat geprüft werden. Es erteilt keine Merge-/Releasefreigabe und enthält keine Echtgeldkäufe oder produktiven Handelsfunktionen.

## Grenzen und wiederverwendete Systeme

Das Hauptspiel startet unverändert mit `scenes/alpha_shell.tscn`. Keine Economy-Autoloads, keine Besitzsperre im bestehenden Deckbuilder, keine Goldvergaben aus `Session.command()`, keine Änderungen an Kampf-/Effekt-/Trigger-/Ressourcenlogik oder Kartenwerten. Der isolierte Prototyp wird ausdrücklich über seine eigene Szene gestartet; er setzt keinen vollständigen550er-Kampf voraus.

Bestehende Persistenzquellen bleiben getrennt:

| Quelle | Bestehender Vertrag | Integration |
|---|---|---|
| `scripts/alpha/session.gd` | `profile`, `save_profile()`, `save_deck(key,ids,rule_mode)`; `user://orafold_alpha_profile_v1.json` | Deck-/Einstellungsquelle erhalten. Kein Übertragen lokaler Siege in echtes Vermögen. |
| `scripts/progress_store.gd` | `data`, `load_progress()`, `save()`, `.path`, `.last_error`; Standard `user://progress_v1.json` | Vorhandenen temporären Dateischreib-/Backuptransport durch Sandboxadapter wiederverwenden. Economy-Schema fachlich separat validieren/migrieren. Den aktiven Fortschrittspfad niemals als Economy-Datei benutzen. |
| `scripts/alpha/catalog.gd` | `all_cards()`, `card(id)`, `deck_ids()`, `deck(power)`, `validate(deck)` | Adapter liefert Besitzmetadaten/Starterauflösung. Karten-IDs erst aus gültigem, versioniertem Katalog übernehmen; Kampfwerte unverändert. |
| `scripts/game_audio.gd` | Autoload `GameAudio`, `.cue(name)` | Semantische Economy-Events an vorhandene Cues/kommende Audioarbeit mappen. Keine zweite Managerinstanz. |

Ein zusätzlicher fachlicher Zustands-/Katalogadapter ist keine zweite produktive Sammlung: die bisherige Alpha-Bibliothek ist ein frei sichtbarer Katalog und besitzt noch kein Eigentumsmodell. Die Sandbox bleibt bis zu einer ausdrücklich geplanten Integration eine eigene Testdomäne.

## Ausführen und Schnittstellen

Aus dem Repositoryverzeichnis:

```sh
godot --headless --editor --import --path . --quit
godot --path . res://scenes/economy/prototype.tscn
bash tools/economy/test.sh
node --test tests/economy_web_storage.test.cjs
python3 tools/economy/simulate_progression.py
```

Der Browsertest benötigt Node, Playwright und Chromium (`CHROMIUM_BIN` kann dessen Pfad überschreiben). Der CI-Workflow `economy-qa.yml` installiert die Voraussetzungen und besitzt keinen Deploymentpfad. Testartefakte liegen in `work/economy/`, eingecheckte Simulationen und native Ansichten unter `docs/economy/results/`. Für gerenderte Tests `godot --path . --audio-driver Dummy --script tests/economy_ui.gd` auf einem verfügbaren Display starten. Headless prüft dieselben Controls und synthetisch zugestellte Touchereignisse ohne Screenshot.

`preload("res://scripts/economy/economy_manager.gd").new(save_path, catalog_mode)` erstellt den Dienst. Standard ist `user://orafold_economy_sandbox_v2.json` mit Modus `fixture`. `ready`/`last_error` melden die Lade-/Validierungsentscheidung. `state`, `catalog`, `config` dienen in der Sandbox als Abfragen; produktive Adapter dürfen den Zustand nicht direkt verändern.

| Operation | Vertrag |
|---|---|
| `grant_starters(tx_id)` | Alle vier Vorlagen einmalig, gemeinsame Kopien als Maximum |
| `claim_reward(tx_id, reward_id, source_id)` | Einmaliges Onboarding; Kapitelquelle separat dedupliziert; Aufgaben werden über Ereignisse vergeben |
| `buy_booster(tx_id, pool)` | Gold abbuchen, ungeöffneten Boosterbestand erhöhen |
| `open_booster(tx_id, pool)` | Booster, RNG, Pity, Besitz und Ergebnis gemeinsam buchen; gespeicherte `cards` für Reveal |
| `craft(tx_id, card_id)` | Essenz abbuchen und eine gebundene Kopie unterhalb des Limits erzeugen |
| `salvage(tx_id, card_id, confirm)` | Nur bestätigte, ungebundene, ungesperrte und nicht reservierte Kopien |
| `set_deck_reservations(tx_id, copies)` | Adapter übergibt maximale pro ID benötigte Kopien aller gespeicherten Decks |
| `lock_card(tx_id, card_id, locked)` | Schutzstatus persistieren |
| `record_activity(tx_id, event)` | `type`, UTC-`day`, eindeutige `source_id`, optional `amount`; Quelle unabhängig von Request-ID deduplizieren |

Der Webadapter nutzt für seinen eigenen Pfad einen synchronen LocalStorage-Eintrag mit Primär-/Backup-Umschlag; Desktop nutzt den bestehenden Dateitransport. Beide benötigen weitere Plattform-/Mehrfensterprüfung. Es gibt keine Mehrgeräte-Synchronisation und keinen sicheren Mehrschreibervertrag. Browserquota und deaktivierter Speicher verhindern einen Commit. Der Browsertest führt die tatsächlich vom Adapter erzeugten JavaScript-Ausdrücke aus; er ersetzt keinen vollständigen Godot-Webexport-Test.

## Integrationsreihenfolge nach Stabilisierung paralleler Aufträge

1. **Katalogvertrag pinnen.** Eindeutige, dauerhafte `id`, vier technische Seltenheiten (`common/rare/epic/legendary`), Macht (`houses/stillwatch/morph/ninth/neutral`), Set-/Revision sowie Publikationsstatus vereinbaren. Konzeptdaten nicht automatisch freigeben. Unbekannte IDs/Seltenheiten und leere positive Boosterunterpools vor Aktivierung ablehnen. Wirtschaftliche Einträge müssen nicht auf Kampfskripte zeigen.
2. **Starter auflösen und prüfen.** Vier benannte Starter vom stabilen Katalogresolver beziehen; je30 Karten, zulässige Macht, max3 je normale Karte/max1 legendär gemäß aktuellem Alpha-Vertrag. Die erste Vergabe ist eine atomare einmalige Quelle. Gemeinsame Karten über maximale benötigte Kopien pro ID berücksichtigen; keine mehrfachen neutralen Grants allein durch vier Deckvorlagen. Gebundene Starter werden nicht verwertet/gehandelt. Bis dahin bleiben Simulationseinträge als vorläufige Definitionen markiert.
3. **Speicherhoheit bestimmen.** Eine spätere Profilintegration hat eine explizite, getestete Versionsmigration und eine einzige fachliche Schreibgrenze. Alpha- und Kampagnenprofil weder still überschreiben noch per Last-write-wins mit wirtschaftlichen Daten mischen. Lokal ausgeführte Economy-Buchungen niemals zu serverbestätigtem Guthaben aufwerten. Web benötigt vor Freigabe vollständige Godot-Reload-/Tabcloseprüfung; der Sandboxadapter implementiert dafür einen eigenen synchronen Eintrag, statt den nur am ursprünglichen Standardpfad aktiven ProgressStore-Mirror vorauszusetzen.
4. **Ergebnisadapter anbinden.** Nach Stabilisierung von Session-/Effekt-/Kampagnenverträgen authentische Abschlussereignisse mit stabiler `source_id`/Perioden-ID an den Aufgaben-/Rewardport senden. Quelle,Art,Menge und Tagesbudgets aus Konfiguration/autoritativer Quelle bestimmen. Vom Client kommende Sieg-,Resonanz- oder Pfadmeldungen bleiben im lokalen Prototyp untrusted. Der Eventadapter beobachtet; er verändert keine Kampfregeln.
5. **Besitzprüfung ergänzen.** Vorhandene `AlphaCatalog.validate(deck)` weiterverwenden; eine separate Inventarprüfung danach prüft tatsächlich nutzbare Kopien und Bindungen. Freie Test-/Übungsmodi können ihren expliziten Katalogzugang behalten. Sammlungskatalog, Besitz und spielbare Rechte sind verschiedene Abfragen.
6. **Präsentation einhängen.** Nach UI-Abstimmung Prototypsignale/Ergebnismodelle in die Hauptnavigation übernehmen. Kein Reward auf Animation-Ende buchen. Nach Speichern darf ein gespeichertes Öffnungsergebnis beliebig erneut angezeigt werden. Skip, Szenenwechsel, Resize und reduzierte Bewegung sind reine Präsentationspfade. Bestehende Kartenrahmen/-rückseiten und Machtfarben wiederverwenden.
7. **Exports gezielt erweitern.** Neues `data/economy/*.json` in den später freigegebenen Export aufnehmen; die vorhandenen zentralen include_filter nennen diesen Ordner noch nicht. Prüfen, dass alle zur Laufzeit benötigten JSONs im Paket enthalten sind und tools/tests/docs/work ausgeschlossen bleiben. Testexport und Produktivveröffentlichung getrennt behandeln. Physische Android-/iOS-Speicher-,Touch- und Resumeprüfung zusätzlich durchführen.
8. **Produktwerte freigeben.** Mit finalen Karten, realen Decklisten und beobachteten Spielzeiten erneut simulieren. Preise,Ertragsbudgets,Schutzregeln,Crafting und Erweiterungsrhythmus versionieren. Die derzeitigen Simulationsparameter sind keine endgültigen Echtgeldpreise.

## Zukünftiger Serveradapter

Der lokale Wirtschaftskern bereitet Commands/Antworten und idempotente Transaktionen vor; er ist kein sicherer Server. Vor handelbarem Vermögen benötigt die Live-Implementierung mindestens:

- Authentisierung, Konten-/Realm-Bindung und serverseitige Autorisierung jeder Quelle/Menge; Client sendet Absichten.
- Unveränderliche Policy-/Katalogrevisionen; Serverzeit und geeignete serverseitige Zufallsquelle; keine Clientseeds für wertvolle Ziehungen.
- Eine atomare DB-Transaktion für Wallet,Packverbrauch,Pity,Inventar,Crafting,Quellendeduplizierung,Operationsergebnis und Audit/Outbox; Datenbankconstraints und Versionskonflikte statt lokaler Mehrgeräte-Merges.
- Dauerhafte fachliche Quellen- und Packeinheits-IDs zusätzlich zu Request-IDs. Derselbe Request mit geändertem Inhalt wird abgelehnt; dieselbe Quelle mit neuem Request erzeugt keine zweite Vergabe.
- Serverseitige Ownership-Instanzen, Bindungs-/Reservationzustände,Herkunftsnachweis und Transferereignisse. Lokale aggregierte Kopien und Hashes sind keine sicheren Eigentumsbelege.
- Recovery-/Restoreproben, persistente Deduplizierung, Reconciliation und kontrollierte Kompensationstransaktionen. Bei Wiederholung nach Antwortverlust gespeichertes Ergebnis liefern.

`docs/economy/architecture.md`, `inventory-transactions.md`, `data-model.md` und `security-threat-model.md` enthalten den vorhandenen ausführlicheren Serverentwurf. Dessen zukünftige Markt-/Kaufports sind **nicht implementiert**. Eine echte Marktfreigabe braucht zusätzliche Regeln für gebundene/übertragbare Instanzen,Betrug,Accountfarmen,Escrow,Chargebacks und mögliche indirekte Echtgeld-zu-Gold-Wege. Dieses Paket erzeugt keine Echtgeldauszahlung und keinen Marktplatz.

## Abnahme vor Hauptspielintegration

| Prüfung | Erforderlicher Nachweis |
|---|---|
| Neue Karten-/Setrevision | Pools/Starter/IDs validiert; keine alte ID still neu vergeben; unbekannte Revision verweigert |
| Reward-/Eventadapter | Doppelte/umgeordnete Ereignisse, neue Request-ID für alte Quelle, Periodenwechsel und Limitüberschreitung geprüft |
| Persistenz | Abbruch vor/nach Commit, Speicherschreibfehler, korrupter Primärstand/Backup, unbekannte Version, fehlgeschlagene Migration und Wiederanlauf geprüft |
| Öffnungsoberfläche | Szene verlassen/Skip/Reload nach Commit, mehrfaches Reveal, Touchziele und reduzierte Bewegung ohne zweite wirtschaftliche Wirkung |
| Besitz im Deckbuilder | Vier Starter bleiben vollständig nutzbar; fehlende Kopien eindeutig angezeigt; Kampfregeln unverändert |
| Plattform | Web-Reload/Tabclose, Android-Pause/Resume/Touch, PC-Dateirechte; iOS gesondert sobald Toolchain vorhanden |
| Fairness | Finalkarten-Decktests/Matchups und neue Progressionssimulation; Sammlungsmetrik ersetzt keinen Gewinnratenbeweis |
| Parallelentwicklung | Diff ausschließlich genehmigter Integrationsstellen, aktuelle Basis getestet; keine fremden Branches automatisch gemergt |
| Auslieferung | Separater PR-Review und aktuelle explizite Freigabe für Merge/Produktionsrelease gemäß `AGENTS.md` |

Die isolierten Prüfbefehle, tatsächlich ausgeführten Ergebnisse und Plattformgrenzen sind in den Test-/Simulationsberichten dieses Pakets festgehalten. Nicht ausgeführte Prüfungen werden dadurch nicht als bestanden erklärt.
