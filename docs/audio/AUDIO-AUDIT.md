# ORAFOLD – Audioaudit

Stand: 10. November 2026. Unveränderte Ausgangsbasis: `develop` bei
`17121e40a49838f479d1655d88d354ed836ad20e`. Umsetzung separat auf
`feature/orafold-audio`; kein Merge, Release oder Deployment gehört zu diesem Auftrag.

## Parallelentwicklung und Schutzbereich

Beim Start wurden offene PRs #4 (Legacy P01–P04), #5 (P05/P06), #7 (P07)
und #11 (Trigger-Brücke) sowie die Remote-Branchliste geprüft. Relevante weitere
Branches betreffen Kartenproduktion (`feature/card-system-550`),
Kampfpräsentation (`feature/combat-presentation`), Trigger
(`feature/generic-trigger-hooks`), UI (`feature/alpha-0.2-mobile-ux`,
`feature/ux-contrast`) und Release-Schutz (`security/pages-release-gate`).
Diese Branches wurden nicht übernommen oder verändert.

Die neue Produktion ergänzt nur `assets/audio/`-Unterverzeichnisse,
`scripts/audio/`, `data/audio/`, `docs/audio/` und isolierte Audiotests.
Bestehende Wurzel-Audioassets, Autoload, UI-Szenen, Karten, Ressourcen-,
Effekt-, Trigger- und Kampfcode bleiben unverändert. `AGENTS.md` verlangt
separate aktuelle Freigabe für Merge und Veröffentlichung; ein Feature-PR ist
keine Veröffentlichung.

## Vorhandener Bestand

| Bereich | Befund an der Ausgangsbasis |
| --- | --- |
| Einstieg | `project.godot` startet `scenes/alpha_shell.tscn` → `scripts/alpha/shell.gd`. |
| Autoload | `GameAudio` → `scripts/game_audio.gd` ist global aktiv. |
| Audiodateien | Elf kurze PCM-WAV-Cues und `atmosphere.ogg`, zusammen rund 380 KiB inklusive Importmetadaten/README. |
| Cues | `ui`, `draw`, `attack`, `hit`, `ASH`, `TIDE`, `THORN`, `VEIL`, `turn`, `win`, `lose`. |
| Produktion | `tools/generate_audio.py`: originale deterministische Synthese mit Standardbibliothek und ffmpeg. Keine Downloads/Samples. |
| Formate | Cues: 24 kHz, Mono, 16 Bit; WAV-Imports mit Kompression. Atmosphäre: 12 Sekunden Vorbis, Laufzeit setzt Loop. |
| Busse | `Music`, `SFX`, `UI` werden zur Laufzeit erzeugt, keine eigene Buslayout-Datei. |
| Stimmen | Zehn wiederverwendete Player: acht SFX, zwei UI; ein Musikplayer. Wiederbelegung stoppt erste Stimme der Gruppe. |
| Varianten | Keine Varianten, Pitchvariation, Fraktionsschichten oder prioritätsgesteuerte Auswahl. |
| Start | Musik startet nach erster gedrückter Taste, Maustaste oder Touch; `cue()` selbst prüft `unlocked` nicht. |
| Regelung | Drei lineare Gains, getrennte Bus-Mutes bei praktisch null. Kein eigener Gesamt-/Umgebungsregler, globaler Mute oder reduzierte Audiointensität. |
| Persistenz | `scripts/progress_store.gd`: Schema 1, `user://progress_v1.json`, `settings.audio.{Music,SFX,UI}`, Web-Mirror `nachtsiegel.progress.v1` in localStorage. |
| UI | Archiv-Frontend `scripts/front_end.gd` bietet drei Mixer-Slider und Vorschautöne. Die produktive Alpha-Shell hat keine Audioanbindung. |
| Präsentationshaken | Archiv `scripts/arena.gd::_audio()` ruft `GameAudio.cue()` bei Ziehen, Spielen, Auswahl, Angriff/Treffer, Zugwechsel und Ergebnis. |
| Alpha-Präsentation | `scripts/alpha/shell.gd::_feedback_events()` verarbeitet bereits aufgelöste Ereignisse für visuelles Feedback; `scripts/alpha/feedback.gd` erzeugt ausschließlich visuelle Jobs. Keine Audiobrücke. |
| Qualitätstests | `tools/validate_audio.py` kontrolliert elf Wurzel-Cues auf Format, RMS, Spitzen, Endpunkte und konservative Mischsumme. `tests/combat_presentation.gd` prüft alten Mixer/Persistenz/Nodebudget. Dummy-Audio ist keine Hörprüfung. |
| Lizenz | `assets/audio/README.md` benennt Ursprung und `LICENSE-NOTICE.md`; ursprüngliche Projektassets besitzen keine allgemeine Open-Source-Freigabe. |

Die alten Sigillen `ASH/TIDE/THORN/VEIL` sind kein belastbarer Ersatz für die vier
ORAFOLD-Machtidentitäten. Der neue Katalog verwendet deren eigene Schichten.
Bestehende Kartendaten benutzen `houses`, `stillwatch`, `morph`, `ninth`,
`neutral`; die Audio-API kann diese IDs an der Adaptergrenze übersetzen.
`epic` ist als Audiovariante vorbereitet, obwohl der geprüfte Alpha-Kartenbestand
nur `common`, `rare`, `legendary` enthält. Es werden keine Seltenheiten ergänzt.

## Lücken und technische Risiken

1. **Doppelter Musikstart:** `GameAudio` bleibt beim normalen Projektstart aktiv.
   Das neue System darf erst nach dem dokumentierten Austausch/Stilllegen des
   alten Autoloads produktiv eingeschaltet werden. Ein zweiter Manager neben
   `GameAudio` würde zwei Musiksysteme starten und alte Einstellungen umgehen.
2. **Exportfilter:** Alle vorhandenen Exportpresets schließen Daten über
   explizite JSON-Globs ein. `data/audio/*.json` fehlt dort. Audioimport allein
   reicht deshalb für exportierte Kataloge nicht. Der kleine Integrationsschritt
   muss diesen Glob ergänzen; die isolierte QA verwendet eigene Exportdaten.
3. **Musik/Atmosphäre:** Vorhanden ist ein kurzer harmonischer Soundbed;
   keine szenenspezifischen Kompositionen, keine Crossfades oder dynamischen
   Musikzustände. Das neue Paket liefert eigene Assets und einen Controller.
4. **Audioereignisse:** Hardcodierte Cue-Namen ohne Fraktions-, Seltenheits-,
   Relikt- oder Resonanzparameter. Die neue Brücke muss aus bereits bestätigten
   Präsentationsereignissen gespeist werden, nicht Spielregeln selbst auswerten.
5. **Fehlerbehandlung:** Bestehende unbekannte Cues werden ignoriert, aber
   fehlende Dateien/kaputte Kataloge sind nicht umfassend abgesichert.
6. **Mischpegel:** Die alte Begrenzung gilt nur für ihre elf Cues und Playergains.
   Sie beweist nichts über zusätzliche Schichten oder beide Systeme zusammen.
   Neuer Pool und eigene Pegelgrenzen sind separat zu testen.
7. **Speicherung:** Altes Profil nicht umschreiben. Neues versioniertes
   Audioschema separat halten; alte Musik/SFX/UI-Werte nur explizit importieren.
   Browserpersistenz bei verweigertem Speicher muss folgenlos fehlschlagen.
8. **Plattformen:** Webexports sind ohne Threads konfiguriert. Gerätefokus,
   AudioContext-Suspend/Resume, Safari-Autoplay, Telefonunterbrechungen,
   Gerätewechsel und echte Latenz sind durch den alten Dummy-Test nicht belegt.
   `web/shell.html` behandelt Sichtbarkeit für Pointer/Viewport, nicht umfassend
   für Audio.
9. **Mobil-Performance:** Fixe Spielerzahl existiert, aber keine belastbare
   physische Android-/iOS-Audiomessung. CPU-/Speicherzahlen einer Cloudmaschine
   müssen als solche ausgewiesen werden.

## Abgrenzung und Nachweise

Die neue Architektur, Assets und isolierten Prüfungen stehen in den
Audio-Unterverzeichnissen. Tatsächliche Testergebnisse und Plattformgrenzen
werden in [AUDIO-QA.md](AUDIO-QA.md) geführt. Stil und Herkunft stehen in
[AUDIO-STYLE-GUIDE.md](AUDIO-STYLE-GUIDE.md) und
[AUDIO-LICENSES.md](AUDIO-LICENSES.md). Die spätere produktive Aktivierung
ist ein kleiner separater Schritt gemäß [AUDIO-INTEGRATION.md](AUDIO-INTEGRATION.md).
Ein vorhandener Codepfad, eine echte Audiodatei, ein bestandener automatischer
Test und eine manuelle Hör-/Geräteprüfung sind verschiedene Nachweise.
