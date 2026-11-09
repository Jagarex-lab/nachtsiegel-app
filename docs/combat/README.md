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
DISPLAY=:99 tools/record_gameplay.sh
```

Godot MovieMaker schreibt offline mit festen 30 Bildern pro Ausgabesekunde.
Dies ist **kein** Nachweis von 30 FPS auf einem Telefon oder auf dem Testhost.
Die AVI-Zwischendatei bleibt unter `work/`; die komprimierte MP4 ist eingecheckt.
Zusätzlich erzeugt `tests/combat_sequence.gd` eine nachvollziehbare Phasenfolge
und vier getrennte Familienrenderings. Diese Bildfolge verwendet eine ausdrücklich
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

Die endgültigen Protokolle, Messwerte, Bildfolge und Veröffentlichung werden nach
Abschluss der Gesamtsuite ergänzt. Keine physischen iPhone-/Android-Tests wurden
durchgeführt. Xvfb/llvmpipe, Dummy-Audio und Browseremulation ersetzen diese nicht.
Native iOS-Ausgabe und Store-Signierung stehen weiterhin aus.
