# Task D – Combat Presentation und Production Polish

Basis: geprüfter B/C-Stand `f3d3c7b`, Umsetzung auf `feature/combat-presentation`.
Produktname, sieben Karten und fünf Pfade bleiben erhalten. Der eingefrorene
unabhängige Regelvergleich bleibt die Referenz für das Standardduell.

## Befund und Entscheidung

Vorher bewegten sich zunächst beide Seiten, danach wurde der gesamte Zug auf
einmal ausgewertet. Gegnerspawn, einzelne Treffer, direkte Heldentreffer und
Todesfälle hatten keinen gemeinsamen zeitlichen Ablauf. Alle Fraktionen nutzten
dasselbe umgefärbte Ringmuster; nach dem Ausspielen war die Auswahl schon gelöscht,
bevor deren Fraktionsfarbe gelesen wurde. Eine Audioarchitektur fehlte.

Das Kampfmodell wertet weiterhin synchron nach denselben Regeln aus. Zusätzlich
liefert es ein begrenztes Ereignisprotokoll mit tief kopierten Vorher-/Nachher-
Zuständen: eigene Angriffe → gegebenenfalls sofortiges Ergebnis → gegnerische
Beschwörung → Gegenangriffe → neuer Zug beziehungsweise Ergebnis. Ein tödlicher
eigener Angriff erzeugt keine nachträgliche gegnerische Aktion.

Die Arena spielt diese Zustände ab, ohne das autoritative Modell zurückzusetzen.
Währenddessen bleiben kampfverändernde Eingaben gesperrt; Menü und Hilfe bleiben
zugänglich. Speichern, Freischalten und Ergebnisdialog folgen erst nach der
Präsentation. Die QA-Brücke meldet einen abgeschlossenen Kampf entsprechend erst
nach der Eingabefreigabe. Direkte synchrone Regeltests bleiben möglich.

## Tatsächliche Animationen

| Aktion | Präsentation |
|---|---|
| Ziehen | Ziehstapelsignal; neue Handkarten erscheinen kurz versetzt mit Einblendung und kleiner Bewegung in der reservierten Handzone |
| Auswahl | zentrale, abbrechbare Vergrößerung und Anhebung; ein Transform-Tween je Control |
| Ausspielen | aus der gewählten Karte abgeleitete Illustration fliegt als nicht interaktives Dekorelement zum Pfad |
| Beschwörung | ortsgebundene Fraktionsform und kurzes Wachstum des Kreaturenmedaillons |
| Angriff | Rücknahme, Vorstoß und Rückkehr; gerichtete Spur vom tatsächlichen Angreifer zum tatsächlichen Ziel |
| Schaden | Wertewechsel im passenden Phasenstand, Trefferform und kontraststarke Minuszahl am Ziel |
| Tod | vorherige Kreaturenillustration blendet aus, ohne alte Kampfwerte stehen zu lassen |
| Heldenangriff | Spur direkt zum Helden; mehrere Treffer derselben Phase ergeben eine zusammengefasste Schadenszahl |
| Zugwechsel | erst nach abgeschlossenen Gegenangriffen neue Handkarte, Energie und eindeutige Zugmeldung |
| Sieg/Niederlage | tatsächliches Ergebnis, eigener Klang, kurzer Dialogaufbau; erst dann weitere Spielwege |

Normale Angriffsphasen dauern jeweils etwa 0,50 Sekunden, die gegnerische
Beschwörung etwa 0,28 Sekunden. Bewegungsreduktion verwendet kurze feste
Markierungen und eine kurze Lese-/Eingabesperre statt Flugbewegungen. Es gibt
keine globale Kameraverwacklung. Ein Größenwechsel beendet alte Transform-Tweens
und dekorative Flugspuren; die Kampfauswertung läuft korrekt zu Ende.

## Vier Effektfamilien

- **Aschensturm / ASH:** aufsteigende Glutstriche und warme Funken. Funkenstoß gehört ebenfalls zu dieser Familie.
- **Gezeitenwall / TIDE:** versetzte elliptische Wellenfronten und helle Brechungskanten.
- **Dornenwacht / THORN:** wachsende, gekrümmte Ranken mit Blattspitzen.
- **Nachtgewebe / VEIL:** gebrochene, einziehende Mondsicheln und versetzte Schattenenergie.

Diese mechanischen Familien bleiben mit den bisherigen Karten kompatibel;
sie erzwingen keine Umbenennung des Kreativentwurfs aus Task A. Effekte liegen
unter Kreaturenwerten, Heldenwerten, Hand und Bedienaktionen. Bewegte Karten-/Todes-
Dekorationen wiederholen keine wichtigen Kampfwerte. Neue Treffer auf dasselbe
Ziel ersetzen dessen alte Schadensmarkierung, statt Zahlen übereinanderzulegen.

## Audio und Herkunft

`GameAudio` ist ein Autoload mit den unabhängigen Bussen **Music**, **SFX** und
**UI**. Der Menüweg **Einstellungen → Audio und Effekte** bietet drei echte
Lautstärkeregler, individuelle Stummschaltung bei 0 Prozent, kurze Hörproben für
Effekt-/UI-Lautstärke und den sparsamen Effektmodus. Werte werden mit dem
bestehenden lokalen Schema 1 gespeichert; ältere Spielstände erhalten sichere
Standardwerte. Der Vollbildwechsel bleibt eine sitzungsbezogene Browseraktion.

Elf kurze WAV-Cues und ein zwölfsekündiges atmosphärisches Vorbis-Klangbett
wurden ausschließlich aus mathematischer Synthese und fest gesetztem Rauschen
hergestellt. Keine Fremdsamples, Downloads oder musikalischen Vorlagen.
[Herkunft und kommerzielle Projektnutzung](../../assets/audio/README.md),
[reproduzierbarer Generator](../../tools/generate_audio.py). Das Klangbett ist
keine behauptete orchestrale Titelmusik. Projektinhaber nutzen die eigenen
Assets unter dem bestehenden Rechtevorbehalt; Exklusivität an mathematischen
Tönen wird nicht behauptet.

Maximal acht Effektstimmen, zwei UI-Stimmen und ein Musikplayer; keine
Knotenerzeugung je Ton. Audio beginnt nach der ersten Interaktion. Pegelreserve
je Stimme begrenzt auch einen kohärenten Vollaussteuerungsfall konservativ auf
weniger als 1,0. Samples wurden auf Format, Spitzen, RMS und klickfreie Ränder
geprüft. Beenden stoppt die Mixerquellen vor der Engine-Freigabe; neue Cues werden
währenddessen verworfen.

## Ressourcen und schwächere Geräte

Ein einzelnes FX-Control, höchstens 16 aktive Einträge; auch 500 gleichzeitige
Anforderungen wachsen nicht darüber hinaus. Keine neuen Partikelsysteme,
Vollbildshader, Refraction-Renderziele oder zusätzlichen großen Texturen.
Handkarten werden bei unverändertem Hand-/Interaktionszustand nicht je Phase
neu erzeugt. Transform-Tweens besitzen einen zentralen Besitzer und werden beim
Entfernen des Controls freigegeben.

**Sparsam:** sechs statt 16 Detailsegmente, zwölf statt 42 Staubpunkte und zwei
statt sieben Kerzenpartikel. Das zusätzliche Fragmentlicht wird übersprungen;
die bereits gemalte Beleuchtung bleibt erhalten. **Reduzierte Bewegung:** keine Kartenflüge, keine
Vorstöße, keine bewegten Spuren; Ursache, Treffer, Zahlen und Ergebnis bleiben
sichtbar. Beide Optionen wirken unabhängig voneinander. Eine automatische
Einschätzung unbekannter Telefonhardware wird nicht vorgetäuscht.

## Reproduzierbare Aufnahme

[Gameplay mit Ton, MP4](gameplay.mp4): 1280×720, H.264/AAC, 17,4 Sekunden,
522 Bilder. Einstieg → Heldenwahl → tatsächliche Touch-Kommandos → vier Runden →
regulärer Drei-Pfade-Sieg → Hauptmenü mit gespeichertem Fortschritt. Keine
Gesundheits-, Energie- oder Siegmanipulation im Aufnahmetreiber.

```bash
# Nach Projektimport bzw. erfolgreichem tools/test.sh:
DISPLAY=:99 tools/record_gameplay.sh
```

Godot MovieMaker schreibt offline mit festen 30 Bildern pro Ausgabesekunde.
Dies ist **kein** Nachweis von 30 FPS auf einem Telefon oder auf dem Testhost.
Die AVI-Zwischendatei bleibt unter `work/`; die komprimierte MP4 ist eingecheckt.
Zusätzlich erzeugt `tests/combat_sequence.gd` eine nachvollziehbare Phasenfolge
und vier aufeinanderfolgende Familienbeispiele. Diese Bildfolge verwendet eine ausdrücklich
angelegte Belastungsfixture und behauptet keine natürlich gezogene Kartenhand.

## Prüfzyklen und Abnahme

1. Ereignisprotokoll und Zwischenstände eingeführt; weiterhin 684 Regelassertions
   und 30 Differential-Duelle ohne Änderung der Standardmechanik.
2. Fraktionsformen, direkter Heldenangriff, zentrale Transformbesitzer und
   begrenzter Mixer. Ein anfängliches Audio-Importproblem wurde durch Laden
   nach dem Ressourcenimport behoben. Beenden räumt Quellen vor Engine-Teardown auf.
3. Komplette Duelle, schnelle Mehrfacheingaben, Fensterwechsel, sparsamer Modus,
   Bewegungsreduktion, persistente Lautstärken und tatsächliche Videoaufnahme.
   Parallele Software-Videoaufnahme beeinflusste Zeitprüfungen; finale Performance-
   und Abnahmeläufe werden deshalb seriell ausgeführt und die Messumgebung genannt.

4. Abschließende Bewegungsreduktion: Untereigenschaften wie `modulate:a` und
   `position:y` werden über Godots indizierten Setter abgeschlossen. Ein laufender
   Kartenaufbau bleibt beim Umschalten dadurch weder halbtransparent noch verschoben.
   [Gezielte Prüfung](qa/indexed-motion.log), zusätzlich im kompletten Kampf-Test
   und der abschließenden CI enthalten.

### Bestandene Abnahme des Spielcodes

[Feature-CI 42620064084](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/42620064084)
prüft Quellstand `1d248153e27f87786b3219c69bf827825756ed84` erfolgreich:
**9.547 Assertions, 89 Renderzustände, 3.838 Kontrastmessflächen, keine Fehler**.
Zusätzlich bestehen 97 Katalogabfragen im Webexport und die Kontrolle der
exportierten Kampagnenressourcen. Alle sieben Chromium-/WebKit-Profile spielen
bis zu einem echten Tutorialsieg und prüfen danach Neustart, Audio-Stummschaltung,
gespeicherten sparsamen Modus, Sammlung und virtuelle Tastatur.
[CI-Protokoll](qa/feature-ci.log).

Die lokale Suite beziehungsweise ihre abschließenden Nachprüfungen bestehen mit
9.537 Assertions und 3.837 Kontrastmessflächen ebenfalls ohne Fehler.
Zeitlich begrenzte Feedback-Elemente können die Zahl der erfassten Einzelprüfungen
zwischen Momentaufnahmen verändern; die Ziele 4,5:1 für Text und 3:1 für wesentliche
Grenzen bleiben unverändert. [Native Prüfungen](qa/native-final.log),
[Messdaten](qa/contrast-report.json). Die abschließende Layerprüfung hielt die
Pfadsiegel über dekorativen Effekten; keine Kontrastgrenze wurde abgesenkt.

### Bildfolge und Sichtprüfung

| Zustand | Tatsächliches Godot-Rendering |
|---|---|
| Vor der Aktion | [Bild 00](sequence/d-sequence-00-before.png) |
| Eigener Angriffsauftakt | [Bild 01](sequence/d-sequence-01-windup.png) |
| Treffer, Tod und direkter Heldenschaden | [Bild 02](sequence/d-sequence-02-impact.png) |
| Gegner beschwört | [Bild 03](sequence/d-sequence-03-enemy-summon.png) |
| Gegenangriff | [Bild 04](sequence/d-sequence-04-counterattack.png) |
| Neuer Zug | [Bild 05](sequence/d-sequence-05-next-turn.png) |

Die Familienbeispiele lassen Nachläufe vorheriger Effekte bewusst überlappen;
die Auswahl zeigt jeweils die nächste Familie. Familien: [Glut](sequence/d-family-0.png), [Wasser](sequence/d-family-1.png),
[Ranken](sequence/d-family-2.png), [Mondschatten](sequence/d-family-3.png).
[Mischpult im Smartphone-Querformat](sequence/mixer-844x390.png).
Die Bildfolge wurde visuell kontrolliert; die Aufnahme zeigt einen vollständigen
regulären Spielverlauf mit Ton. Das Gameplay-Video entstand während des dritten
Zyklus; die anschließende Pfadsiegel-/Layerkorrektur ist in der finalen Bildfolge
und im geprüften Spielcode enthalten.

### Performance: ehrliche Messgrenzen

[Sechs vollständige Linux-Duelle](qa/performance.json) umfassen 844×390,
915×412, 1280×720 und 1600×900, normalen/sparsamen Modus, reduzierte Bewegung
sowie einen legal erspielten Verlust durch Passen. Gemessen wurden 78–84
Spitzenknoten pro Lauf, maximal zehn aktive FX-Einträge im normalen Ablauf
und etwa 36–39 MiB in Godots **MEMORY_STATIC**-Monitor. Der separate 500er-Burst
bestätigt die harte Obergrenze 16. Audiostimmen bleiben bei 8 + 2 + 1.

Der isolierte Prozesslauf für Quellstand `f843596` (vor der abschließenden
Setterkorrektur, gleicher Ressourcenaufbau) auf Xvfb/Mesa llvmpipe benötigt rund 69 Sekunden für
die gesamte Testmatrix und erreicht **250,3 MiB Spitzen-RSS**, einschließlich
Engine und Software-Renderer. [Prozessmessung](qa/process-resources.json),
[reproduzierbarer Python-Wrapper](qa/profile_command.py):

```bash
DISPLAY=:99 python3 docs/combat/qa/profile_command.py
```

Die Software-Rendering-Messungen erreichen kein 60-FPS-Ziel. Die gemessenen
Framezeiten und kalten Caches erlauben keinen belastbaren Beschleunigungsfaktor
für den sparsamen Modus; reduziert werden nachweisbar dessen Operationsbudgets.
**Dies ist keine Leistungsfreigabe für echte Telefone.** Die MovieMaker-Framerate
ist davon unabhängig. Es wurden keine physischen iPhone-/Android-Tests durchgeführt.

Linux- und Android-Debugexport erstellt. Das Linux-Paket enthält weiterhin
Kampagne, Karten, Lore und Einstieg ([Prüfung](qa/exported-resources.log));
Android 0.6.0-combat ist mit APK-Signatur v2/v3 gültig
([Prüfung](qa/android-signature.log)). Keine Geräteinstallation oder native iOS-
Auslieferung behauptet; dafür fehlen physische Tests sowie macOS/Xcode/Signierung.

## Veröffentlichte Fassung

**[Spiel öffnen](https://jagarex-lab.github.io/nachtsiegel-app/?v=1d248153e27f)** ·
**[Gameplay-Video mit Ton öffnen](https://jagarex-lab.github.io/nachtsiegel-app/media/gameplay.mp4?v=1d248153e27f)**

Am 9. November 2026 über `develop` veröffentlicht: Spielcode
`1d248153e27f87786b3219c69bf827825756ed84`.
[Veröffentlichungslauf 42621761568](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/42621761568)
erfolgreich: gesamte Suite vor Veröffentlichung erneut bestanden; anschließend
**sieben vollständige Browserprofile auf der öffentlichen Adresse, keine Fehler**.
[Prüfprotokoll](qa/published-ci.log), [öffentliche Build-ID](qa/public-build-info.json).

Zusätzliche öffentliche WebKit-Prüfung: Menü, Mischpult, Tutorialstart, reale
Kartenauswahl und Beschwörung, kompletter präsentierter Zug und anschließende
Eingabefreigabe. Keine Browser-/Godot-Fehler, Build-ID stimmt.
[Prüfdaten](qa/public-spot.json), [Mischpult](sequence/public-mixer.png),
[Kampf](sequence/public-combat.png), [neuer Zug](sequence/public-next-turn.png).
Die MP4 wird mit `video/mp4`, HTTP 200 und 3.040.281 Byte ausgeliefert.

Dateinamen `nachtsiegel-1d248153e27f.*` verhindern veraltete Safari-Spielressourcen.
`main` bleibt unverändert. Der anschließende Dokumentationscommit ändert weder
Spielcode noch den veröffentlichten Build. Physische Gerätetests und eine
native iOS-/Store-Freigabe bleiben ausdrücklich offen.
