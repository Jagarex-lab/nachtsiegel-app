# ORAFOLD – konfliktfreies Produktionspaket

Stand: 10.11.2026. **Zwischenlieferung, Gesamtauftrag nicht abgeschlossen.** Branch `production/content-art-pipeline`, Basis `develop` `17121e40a49838f479d1655d88d354ed836ad20e`. Der aktuelle Liefercommit ist am PR-Head beziehungsweise mit `git rev-parse HEAD` feststellbar. Es wurden keine Merges oder Veröffentlichungen ausgelöst.

## Implementiert

- Reproduzierbare Prüfung aller 550 Konzepte: [CONTENT_REVIEW](CONTENT_REVIEW.md), mit Struktur, Klassifikation, Referenzen, Textwiederholungen und fehlenden Spieldefinitionen. 350 Wesen, 125 Impulse, 75 Relikte; exakt 110 pro Zugehörigkeit. Die Quelle bleibt Vorschlag.
- 550 individuell autorierte [Bildbriefings](../../data/production/art-briefs/), jeweils mit Motiv, Handlung, Ort, Komposition, erkennbarem Detail und eigenständigem Namensvorschlag. Ein bei der Integration erkannter doppelter Namensvorschlag wurde in `NE-082` zu „Wurzelspreizer“ geändert. Keine aktiven Karten wurden dadurch umbenannt.
- [Art Direction](ART_DIRECTION.md), [Assetpipeline](ART_PIPELINE.md), Promptexport und ein eigener CI-Check ohne Deploymentrecht. Brief-/Konzept-/Bildhashes, echte Bilddekodierung, Maße, Herkunft, Alternativtexte, Änderungen und Status werden geprüft. Veränderte Briefs invalidieren ihre Bildzuordnung.
- Fünf tatsächlich erzeugte Einzelillustrationen: ZH-001, SW-001, VG-001, NS-071 und NE-101. Je eine pro Zugehörigkeit, zusammen drei Kartentypen. [Inventar mit vollständigen Prompts](../../data/production/art-assets.json), unveränderte Originale unter `assets/production/illustrations/`, jeweils 1448×1086 Pixel. Keine fremden Bildreferenzen verwendet; Generatorversion wurde vom Werkzeug nicht offengelegt und daher nicht erfunden.
- Native Autorenansicht im bestehenden Godot-Diagonalrahmen. Nur temporäre, sichtbar als Bildentwurf bezeichnete Renderer-Eingaben; keine ausführbaren Kartenprogramme.
- Neuer tatsächlicher Lauf der vorhandenen Regelsimulation: [Auswertung](BALANCE_BASELINE.md) und [192 Partien als Rohbeleg](evidence/alpha-resource-experiments.json). Die vorhandene Engine wurde hierfür nicht verändert oder dupliziert.

## Getestet

| Prüfung | Ergebnis und Grenze |
|---|---|
| Neuer Katalogprüfer | 12 Tests bestanden, 0 Fehler/Skips; inklusive ungültiger Referenzen, Klassifikation und Read-only-CLI. |
| Neue Assetpipeline | 21 Python-Tests bestanden, 0 Fehler/Skips; inklusive Briefdrift, Quellenhash, Dateityp, beschädigter Pixel, Doppelbildern, Pfadgrenzen, Herkunft und Finalgate. |
| Echte Autorenbestände | 550 bijektiv zugeordnete Briefs und eindeutige Namensvorschläge; fünf dekodierbare Einzelbilder. Alle weiteren 545 Bilder fehlen ausdrücklich. |
| Bestehende Regression | 44 Node-Testgruppen und acht Release-Sicherheitstests bestanden. Der erste Sandbox-Lauf scheiterte an `spawnSync EPERM`; die unveränderten Tests bestanden außerhalb dieser Einschränkung. |
| Ressourcenmatrix | 1.125 Assertions, 0 Fehler; 192 vollständige Matrixpartien plus sieben Verifikationspartien. 40 von 55 aktiven IDs tatsächlich ausgespielt. Kein Nachweis für 550 Karten. |
| Native Bildansicht | Kontaktbogen und Prüfbericht unter `evidence/`; tatsächlicher Godot-4.6.3-/Mesa-Renderlauf. Platzhalterwerte sind auf jeder Karte beschriftet. |
| Exportisolation | Tatsächlicher Alpha-PCK-Export und Inventur: Autorenbilder/-daten dürfen nicht in den Spielbuild gelangen. `.gdignore` trennt beide Autorenverzeichnisse vom Export. |
| Negatives Abnahmegate | `art_pipeline.py validate --release-ready` weist den Bestand erwartungsgemäß zurück: null finale Illustrationen. |

Die erste Simulation vor dem Ressourcenimport scheiterte an fehlenden importierten Audioressourcen; der erneute Lauf nach Import bestand. Einzelheiten und erhaltene Lognamen stehen in der Balanceauswertung. Es wurden keine Tests oder Fristen aufgeweicht. Die grafische Sitzung wurde mit einem lokal im ignorierten Arbeitsbereich entpackten offiziellen Debian-Xvfb ermöglicht; keine zusätzliche Laufzeitabhängigkeit im Spiel.

## Parallelität und technische Abhängigkeiten

Vor Beginn wurden sämtliche 20 vorhandenen Remote-Branches, deren Heads, offene PRs und die letzten develop-Commits geprüft. Der [Branch-Snapshot](evidence/branch-snapshot.json) ist eine zeitgebundene Beobachtung. PR #13 wurde während der Einrichtung von anderer Seite integriert; die Arbeitsbasis enthält ihn bereits. Sein Audit wird weiterverwendet, nicht überschrieben. Dessen frühere Freigabeaussagen werden für diesen Auftrag nicht übernommen: Es gilt das aktuelle Mergeverbot.

| Parallele Arbeit | Beobachteter Stand und Grenze |
|---|---|
| [PR #11](https://github.com/Jagarex-lab/nachtsiegel-app/pull/11) | Offen, Draft, Head `70cc08e482e17ac1bcec53a02ba95c78583df8bf`. Keine seiner zehn geänderten Dateien oder zentralen Engine-/Phasendateien angefasst. Quelle-/Ziel-/Pending-/Session-/Replayvertrag bleibt Voraussetzung für die Produktionskarten. |
| [PR #14](https://github.com/Jagarex-lab/nachtsiegel-app/pull/14) | Während der Arbeit neu eröffnet, Audio-Draft, bei Prüfung Head `4a975e0ec76d9185399a934b1d90fa4fe57785af`. Dateiübersicht geprüft; keine seiner Audioassets, Daten, Skripte, Tests oder Dokumente verändert. |
| PRs #4/#5/#7 | Historische Legacy-Stapel; relevante Implementierungen sind bereits in der integrierten Alpha-Historie. Keine erneute Übernahme. |
| Eigener Bereich | Neue `tools/production`, `tests/production`, `data/production`, `assets/production` und eindeutig benannte Produktionsdokumente; zusätzlich nur ein ausdrücklich als Vorschlag markierter Registereintrag in der Lore-Bibel und ein eigener CI-Workflow. |

Nach tatsächlicher Integration der parallelen Engine-Arbeit muss dieser Branch erst auf den neuen develop-Stand aktualisiert und erneut geprüft werden. PR #11 ist bisher keine allgemeine 16-Trigger-Integration; sein Merge allein würde die Produktionsabnahme nicht schließen. Bis dahin bleiben Engine, Ressourcen, Kampfphasen und davon abhängige Kartenaktivierung zurückgestellt. Es wurde keine zweite Effektengine gebaut.

## Veröffentlicht

**Durch dieses Paket nichts.** Die bestehende spielbare Alpha liegt unter <https://jagarex-lab.github.io/nachtsiegel-app/>; bekannte veröffentlichte Basis ist `fde508e85a2866e24653ef25d920a59832d2d653`. Diese URL enthält die neuen Briefs und Piloten nicht. Der Live-Build wurde in diesem Paket nicht neu veröffentlicht oder als neuer Release abgenommen.

## Noch offen und blockiert

Aktiv bleiben **55 Alpha-Karten**, hinzugekommen sind **null aktive Karten**. Alle 550 Konzepte benötigen weiterhin Kosten, Werte, ausführbare Effekte, deutsche Regeltexte und Einzelinteraktionstests. Die 100 Legacy-Karten bleiben getrennte Referenzen. Keine Karte, kein Save und kein referenziertes Asset wurde gelöscht; es gab keine aktive ID-Migration. Die vorgeschlagenen Namen sind im separaten Briefbestand nachvollziehbar.

**Fünf Bilder sind erzeugt und visuell geprüft, null final abgenommen.** Alle fünf bleiben `reviewed`, kommerzielle Schlussprüfung und endgültige Kartenintegration offen. Die beiden menschlichen Pilotfiguren ähneln sich sichtbar; breite Figurenvarianz ist damit nicht nachgewiesen. Die übrigen 545 Bilder fehlen. Kanon, Spieldefinitionen und Rechte werden nicht durch ein technisches Dateigate bewiesen.

Die Simulation bestätigt den bekannten Warnbefund Neunte Stunde 24/24 Nichtspiegel-Siege je Profil. Keine Balanceänderung wird aus dieser kleinen, gepaarten KI-Stichprobe abgeleitet. Umleitung bleibt ein ausdrücklich dokumentierter Inhaltsblocker: Die notwendige eigene Verzögerung ist in legalen Neunte-Stunde-Decks nicht erzeugbar. Dieser Auftrag erlaubt derzeit keinen Eingriff in die dafür nötigen Engine-/Zeitverträge.

Die vollständige 550-Karten-Runtime, Trigger-/Session-/Replayintegration, Migration, neue KI-/Archetypendecks, breite Balancierung, aktive Illustrationseinbindung, Mobile-/Browser-Gesamtabnahme, native Android-/iOS-Abnahme und geprüfter Release bleiben offen. Der vorhandene zentrale Glossarvertrag `data/card_system/glossary.de.json` wird weiterverwendet. **Release-Reife: Alpha mit Produktionsvorbereitung, keine vollständige kommerzielle Spielversion.**
