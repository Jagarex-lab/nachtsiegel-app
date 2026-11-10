# Asset-Herkunft

- `art/atlas.png`: für diese NACHTSIEGEL-Überarbeitung am 08.11.2026 mit OpenAI Image Generation erzeugte Fantasy-Konzeptillustrationen. Ein 3×3-Atlas enthält Aschenwache, Dornenwolf, Nebelqualle, Schattenwolf, Glutritter, Gezeitenhüter, Funkenstoß, Siegelhüterin und Aschenkönig (Reihenfolge zeilenweise). Kein Referenzbild oder bestehendes Franchise-Artwork wurde verwendet. Die Kennzeichnung **KONZEPT** auf den Karten und der ausdrückliche Hinweis in der Großansicht gehören zum Platzhalterstatus. Keine Behauptung exklusiver Rechte an KI-Ausgaben.
- `art/arena.svg`: eigens programmierte Vektorgrafik für Steintisch, Kathedralrippen, Steinmaserung und fünf Siegelpfade. Keine fremden Texturen.
- `icon.svg`: eigens gezeichnetes NACHTSIEGEL-Siegel.
- Kartenmetall, Beschläge, Juwelen, Schatten und atmosphärische Partikel: prozedurale Originalgrafik in `scripts/card_face.gd` und `scripts/atmosphere.gd`.
- `fonts/Body.ttf`: DejaVu Sans; `fonts/Display.ttf`: DejaVu Serif. Unveränderte Schriften, zugehörige Lizenz in `fonts/LICENSE`.
- Ältere prozedurale Illustrationsskripte bleiben als historische Projektressourcen erhalten, werden aber von der neuen Arena nicht geladen.

Die bestehende Projektlizenz und `LICENSE-NOTICE.md` bleiben maßgeblich für Spielcode und Spielinhalte. Der technische Prototyp ist keine Store-Veröffentlichung.

## Erweiterung „Mondheiligtum“ (08.11.2026)

- `art/arena_painted.png`: eigens mit OpenAI Image Generation erzeugte 16:9-Kathedralen-Arena mit freier Spielfläche, fünf Siegeln, Steinschnitzerei, Kerzen und Mondlicht. Kein Referenzbild eines bestehenden Spiels.
- `art/reliquary_frame.png`: eigens generierter transparenter Kartenrahmen mit Metallrelief, Beschwörungssockel, Namensschild und Wertesockeln. Illustrationen und alle Werte werden separat in Godot eingesetzt; kein eingebrannter Spieltext.
- `art/hero_medallion.png`: eigens generierte transparente Metallfassung mit Porträtfenster, Namensschild und Lebenspunkt-Edelstein. Bestehende eigene Konzeptporträts und dynamische Lebenspunkte werden in Godot zusammengesetzt.
- Diese drei Bilder sind KI-generierte Original-Konzeptassets für dieses Projekt und ersetzen noch keine abschließende manuelle Art-Produktion. Keine Behauptung exklusiver Rechte an KI-Ausgaben.
- `fonts/Cinzel.ttf`: Cinzel, Copyright 2020 The Cinzel Project Authors, SIL Open Font License 1.1. Unveränderte Quelle: https://github.com/google/fonts/tree/main/ofl/cinzel. Lizenz: `fonts/Cinzel-OFL.txt`.
- Shader-Licht, Gravuren, Zielfeldringe, Energie-Orb, HUD-Kristalle, gezeichnete UI-Schaltflächen und zeitlich begrenzte Zauber-/Beschwörungseffekte sind prozedurale Projektgrafik. Regeln, Bildfenster, Texte und Werte bleiben vom generierten Rahmen getrennt.

## Premium-Arena (09.11.2026)

- `art/premium_slate.png`: eigens mit OpenAI Image Generation erzeugte dunkle Schiefer-Materialtextur mit zurückhaltenden Metallnähten. Kein Referenzbild, kein fremdes UI. Wird als Textur auf die in Godot gezeichnete perspektivische Bühne und Plinthen gelegt; keine eingebrannten Karten, Werte oder Bedienelemente. KI-Konzeptmaterial, keine behauptete Exklusivität. Die bestehende eigene Arena- und Reliquiengrafik wird unabhängig weiterverwendet.

## Original audio (Task D)

`assets/audio/`: project-generated mathematical synthesis, no sampled external source. See [audio provenance](audio/README.md) and `tools/generate_audio.py`. Eleven PCM cues plus a short Vorbis atmosphere bed; commercial project use follows existing project rights.

## ORAFOLD-Produktionsillustrationen (10.11.2026)

Fünf individuelle, ausschließlich für dieses Projekt mit OpenAI Image Generation
erzeugte individuelle Illustrationen liegen in `assets/cards/originals/`: Torwache
(`oa-neutral-c02`), Namenhüter (`oa-houses-c01`), Glaskonservator
(`oa-stillwatch-c01`), Sprunglarve (`oa-morph-c01`) und Kausaljäger (`oa-ninth-c01`).
Jedes PNG besitzt native 1448 × 1086 Pixel; es wurde kein Atlas hochskaliert und
kein Referenzbild verwendet. Die Dateien enthalten ausschließlich das Bildmotiv;
Kartenrahmen und sämtliche Informationen zeichnet Godot separat.

Vollständige Prompts, Erzeugungsdatum, ursprüngliche Quelldateinamen,
SHA-256-Prüfsummen, unveränderte Originalabmessungen, alternative Bildtexte und
Reviewstatus stehen in `data/production/art_sources.json`. Technische Pipeline
und Grenzen: `docs/production/ART_PIPELINE.md`. Die tatsächlichen Originalbilder
und Godot-Kartenansichten wurden von implementierendem Agent und Hauptagent auf
Motiv, Arten, Palette, Beschneidung und sichtbare Fehler geprüft und für die
aktuelle visuelle Produktionsrichtung freigegeben (`final` / `approved`). Das
ist keine juristische Freigabe. Prüfung der maßgeblichen Nutzungsbedingungen
und abschließende kommerzielle Rechteprüfung stehen aus; keine Exklusivität oder
juristische Unbedenklichkeit wird behauptet. Nach dem ersten Paket fehlten 545 Einzelillustrationen
des Produktionskandidaten fehlen weiterhin.

## ORAFOLD-Produktionsillustrationen – Paket 2 (10.11.2026)

Zehn weitere individuelle Originale mit nativen 1448 × 1086 Pixeln liegen unter
`assets/cards/originals/`: Kupferspinne, Restaurationslampe, Gepanzerter Keim, Wand
aus Erinnerung, Zweithautechse, Reißende Blüte, Taktfalter, Verzögerungsspule,
Wanderfeuer und Gemeinsame Deckung. Sie gehören zu bestehenden Starterdeckkarten.
Neun Bilder wurden ohne Referenzen erzeugt; Zweithautechse erhielt eine dokumentierte
Image-Generation-Korrektur auf Grundlage des eigenen ersten Projektbilds.
Provenienz, Original-/Referenzhashes und Bearbeitungsauftrag stehen vollständig in
`data/production/art_sources.json`. Native Originale und tatsächliche Godot-Karten-
ansichten wurden visuell geprüft; die kommerzielle Rechteprüfung bleibt offen.

15 technische 512 × 384 Vorschaubilder unter `assets/cards/previews/` entstehen
ausschließlich durch deterministische Godot-Verkleinerung derselben 15 Originale.
Sie sind keine weiteren individuellen Illustrationen. Quell- und Vorschauhashes
sind in `data/production/art_previews.json` gebunden. Es wurde kein fehlendes
Bild durch Hochskalieren erfunden. Aktueller Bestand: 15 individuelle visuell
freigegebene Originale, 535 fehlende Originale, keine behauptete juristische
Unbedenklichkeit oder Exklusivität. Einzelheiten: `docs/production/ART_BATCH2.md`.
