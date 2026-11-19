# ORAFOLD – Fractal-Fold-Vergleichsstudie

**Status: Vorschlag / Freigabe des Projektinhabers ausstehend.**
Keine Variante ist als neues Produktionsdesign ausgewählt. Dieser separate
Entwurfs-PR darf die aktiven Kartenrahmen nicht global umstellen. Seine Szene ist
eine Entwickleransicht und kein neuer Eintrag im regulären Hauptmenü.

## Anlass und verbindliche Vergleichsbedingungen

Die vorhandene Produktion verwendet `folded` aus
[`card_frames.gd`](../../scripts/premium/card_frames.gd). Die ältere
[Materialstudie](PREMIUM_CARD_MATERIALS.md) vergleicht drei Varianten mit denselben
zwanzig Karten zwischen den Varianten; innerhalb einer Seltenheitsreihe verwendet
sie jedoch unterschiedliche Kartenillustrationen. Ihre zusätzliche kontrollierte
Nahaufnahme behandelt nur eine Macht. Das beantwortet die neue Frage nach allen
Mächten und Seltenheiten bei identischem Motiv nicht vollständig.

Diese neue Studie verwendet deshalb je Macht **dieselbe tatsächliche Karte,
Originalillustration, denselben Namen, dieselben Kosten, Werte, Arten und Effekte**
für alle vier Seltenheitsstufen. Nur `rarity` wird in einer privaten Renderkopie
variiert. Die Kopie wird weder im Katalog registriert noch einem Deck, Spielstand,
Inventar oder Kampf übergeben. Die globalen Quelldaten und ihr mechanischer
Fingerprint müssen vor/nach der Aufnahme identisch bleiben.

| Reihe | Tatsächliche Quellkarte | Kontrolle |
| --- | --- | --- |
| Zwölf Häuser | `of-houses-001`, Kupferhüterin | Vier visuelle Seltenheiten, dasselbe Originalbild |
| Stillwacht | `of-stillwatch-001`, Eislichtwache | Vier visuelle Seltenheiten, dasselbe Originalbild |
| Vielgestalt | `of-morph-001`, Jadekundschafterin | Vier visuelle Seltenheiten, dasselbe Originalbild |
| Neunte Stunde | `of-ninth-001`, Zeigerläuferin | Vier visuelle Seltenheiten, dasselbe Originalbild |
| Neutral, zusätzliche Referenz | `of-neutral-001`, Wegmarkiererin | Vier visuelle Seltenheiten, dasselbe Originalbild |

Die Gegenüberstellung enthält die unveränderte Produktionsarchitektur sowie drei
isolierte Vorschläge. Es entstehen keine neuen spielbaren Versionen dieser Karten.

## Drei Vorschläge, keine Designfreigabe

| Kennung | Vorgeschlagene Rahmenarchitektur | Bei der Sichtung besonders prüfen |
| --- | --- | --- |
| A – Gebrochene Scharniere | Breite asymmetrische Faltflächen, dunkle Unterseiten und wenige klare Gelenke | Ruhe um das Motiv; Erkennbarkeit der legendären Doppelgelenke bei 84px |
| B – Verschachtelte Archive | Begrenzte selbstähnliche Verzweigungen, versetzte Ebenen und tiefe Innenkanten | Strukturelle Seltenheit und Gefahr zu vieler kleiner Linien |
| C – Kristalline Raumfalten | Lange plane Facetten, geteilte Reflexkanten und kristalline Verbindungen | Materialtiefe und Konkurrenz zu kontrastreichen Illustrationskanten |

Alle Vorschläge verwenden dieselbe eckige Außenkontur mit kleinen geraden
Eckschnitten, das digitale Masterformat **756×1056 / 63:88**, eine asymmetrische
Diagonale und eine gemeinsame Lichtquelle oben links. Keine Faltung, kein Kristall
und keine Linie darf über die Außenkontur ragen. Titel, Kosten, Typ/Arten,
vollständiger Effekt, Seltenheit und gegebenenfalls Angriff/Leben werden nach der
Dekoration gezeichnet. Informationen liegen auf opaken Flächen. Schlüsselwort-
Definitionen werden nicht in die Karte kopiert.

Die bisherigen Dokumente
[CARD_STYLE_GUIDE](../master550/CARD_STYLE_GUIDE.md) und
[ART_STYLE_GUIDE](../production/ART_STYLE_GUIDE.md) erklären Masterformat,
Informationspositionen, sichere Bildmitte und Trennung zwischen Illustration und
Godot-Rahmen. Ihre gerundete Produktionskontur bleibt die gekennzeichnete
Referenz. Die neue eckige Kontur ist hier ausschließlich der aktuelle
freigabepflichtige Entwurf, keine stillschweigende Änderung der aktiven Sammlung.

## Macht und Seltenheit

Die Machtpigmente bleiben Kupfer `#B9824A`, Eisblau `#58A9CF`, Jade `#5B9E68`,
Amethyst `#9867BE` und neutrales Stahlgrau `#8B98A5`. Zusätzlich zur Farbe zeigen
die seitlichen Elemente Archivklammern, vermessene Kristalle, facettierte Blätter,
versetzte Kausalitätslinien beziehungsweise zurückhaltende Stahlmarken.

Gewöhnlich besitzt eine einzelne innere Faltlage. Selten ergänzt eine weitere
Lage und Schulterverbindungen. Episch erhält mehrere Ebenen und sichtbare
Kristallknoten. Legendär ergänzt große innenliegende Doppelgelenke und eine
verschachtelte untere Faltarchitektur. Die Machtfarbe bleibt erkennbar; ein
winziger Seltenheitspunkt ist nicht das einzige Unterscheidungsmerkmal.
Die über der Illustration gezeichneten Seitenformen unterscheiden außerdem
A mit zusammenhängenden Scharnierflächen, B mit offenen rechteckigen
Verzweigungen und C mit langen geteilten Kristallprismen. Sie sitzen nicht
ausschließlich unsichtbar unter der Illustration.

Innerhalb der vorgeschlagenen Reihen bleibt das Bildfenster `(74,152,608,500)`
bei allen Seltenheiten gleich. Der Mittelpunkt der Illustration bleibt frei;
zusätzliche Struktur sitzt überwiegend in den seitlichen Materialbändern.
Die Produktionsreferenz verwendet ihre tatsächlichen bestehenden Abstände.
Das neue Grunddesign und die Rückseite werden durch diese Studie nicht aktiviert.
Die produktive, identitätsunabhängige Rückseite bleibt bytegleich erhalten.

## Tatsächliche Godot-Vorschau und Reproduktion

Neu und isoliert:

- `scripts/design_study/fractal_fold_frames.gd`: begrenzte Vektorgeometrie, keine Shader oder permanenten Effekte.
- `fractal_fold_card.gd`: Vorschau-Unterklasse der echten kanonischen Karte mit demselben Bildresolver und Textsatz.
- `fractal_fold_compact.gd`: Vorschau-Unterklasse der echten kompakten Karte mit ihren Kosten, Namen und Kampfwerten.
- `fractal_fold_study.gd` und `scenes/design_study/fractal_fold_study.tscn`: lokale Entwickleransicht; vier funktionierende Variantenschalter, kein Spielmenüeintrag.
- `tools/design_study/render_fractal_fold.gd`: echte SubViewport-Aufnahmen, kontrollierte Kartenreihen und maschinenlesbarer Nachweis.

Im Projektverzeichnis mit vorhandenen importierten Assets und sichtbarem
OpenGL-Kompatibilitätsrenderer:

```sh
godot --headless --path . --script tests/design_study/fractal_fold_geometry.gd
godot --path . --rendering-method gl_compatibility --audio-driver Dummy --script tools/design_study/render_fractal_fold.gd -- --output=res://work/fractal-fold-study
godot --path . --rendering-method gl_compatibility --audio-driver Dummy res://scenes/design_study/fractal_fold_study.tscn
```

Der Aufnahmebefehl erzeugt für `reference`, `hinge`, `lattice`, `crystalline`
jeweils eine vollständige 5×4-Matrix, dieselbe Matrix als echte 84px-Handkarten,
eine 844×390-Ansicht und drei echte Kartentypen. `--architecture=hinge` und
`--mode=mini` erlauben einen einzelnen schnellen, reproduzierbaren Prüffall.
Die 1200×1940-/980×1000-/1040×680-/844×390-Aufnahmen stammen aus echten
SubViewports; ein kleiner Desktopbildschirm schneidet die Matrix nicht ab.
`comparison.json` bindet Bilder an Quellhashes, mechanischen Fingerprint,
Godot-Version, gebundene Originaltexturen, Karten-IDs und den Status
`pending_owner`. Eine fehlende oder nur behauptete Illustration führt zu einem
Fehler; Fallbacks zählen nicht als fertige Studie.
Vollkarten verlangen ausdrücklich `preview_only=false`, den tatsächlich
gebundenen Originalpfad und dessen native Manifestabmessungen. Die kompakten
Karten melden den tatsächlich gezeichneten Vorschaupfad und dessen Abmessungen;
auch dort muss je Reihe dieselbe Originalzuordnung nachgewiesen sein.
`status=final` allein gilt ausdrücklich nicht als Bildnachweis.

Optional prüft `--mode=contour` die drei neuen Architekturen mit je zwanzig
tatsächlich transparent gerenderten Masterkarten. Die Pixelprüfung vergleicht
alle vier Eckschnitte mit der gemeinsamen Winkelkontur, verlangt transparente
Außenränder und vergleicht Hashes ausschließlich eines seitlichen Rahmenbands.
Damit dürfen die vier Seltenheiten nicht allein wegen anderer Seltenheitswörter
oder Punkte als verschieden gelten. Das ist eine native Rasterprüfung und
keine bloße Wiederholung ausgegebener Geometrieparameter.
Die analytische Innen-/Außenprüfung überspringt ausschließlich Pixelzentren
innerhalb von 0,76 Masterpixeln einer mathematischen Polygonkante, deren
Rasterdeckung backendabhängig ist. Der tatsächliche Alpha-Eckhash muss dennoch
für alle Mächte/Seltenheiten exakt übereinstimmen; ein Pixel außerhalb des
äußeren Kartenrechtecks ist ohne Toleranz ein Fehler.

Die native Framegröße ist kein iPhone-Gerätetest. Eine verkleinerte vollständige
Karte ist außerdem kein Ersatz für den neuen Inspektionsablauf aus dem getrennten
UI-PR. Der Smartphone-Ausschnitt beurteilt Rahmenwirkung und die echte kompakte
Darstellung; seine Informationen werden nicht als physische Lesbarkeitsabnahme
ausgegeben.

## Leistung, Rechte und Abnahme

Die Falten sind begrenzte Vektorelemente, keine rekursiven Shader. Es gibt keine
permanente Animation. Zwanzig Karten pro Matrix teilen fünf vorhandene Motive;
der bestehende Resolver behält seine 32MiB-Grenze. Diese Cachegrenze ist keine
Messung der gesamten sichtbaren Szene oder des GPU-Speichers. Die fünf
1448×1086-Originale (Neunte Stunde 1447×1087) können zusammen einschließlich
Mipmaps ungefähr 42 MiB Texturdaten darstellen. Physische Framerate,
Speicherverbrauch, Akku und thermische Stabilität bleiben Geräteprüfungen.

Es werden keine KI-Bilder erzeugt oder vorhandene Bilder als neue Originale
ausgegeben. Die vorhandenen Bild-/Lizenz-/Herkunftsverweise bleiben erhalten;
diese Designstudie erteilt keine neue kommerzielle Rechtefreigabe.

## Tatsächliche Prüfschritte und Grenzen

Der erste Godot-4.6.3-Lauf erkannte eine fehlerhafte Typinferenz bei einer
Pixelkoordinate in der Rasterprüfung. Die Koordinaten und booleschen
Zwischenwerte wurden ausdrücklich typisiert; der folgende Lauf kompilierte.
Die anschließende Sichtung auf `4133a15` zeigte zwei konkrete Schwächen:
Die Erklärung der Smartphonevorschau konnte rechts hinausreichen, und die drei
Architekturformen waren bei 84 px zu ähnlich, weil Bild und gemeinsame Dekoration
die Unterschiede verdeckten. `d64d110` korrigiert die Beschriftungsanordnung und
zeichnet größere, verschieden geformte Seitenfalten über die Bildränder.

Die vollständige Wiederholungsprüfung verwendete diesen Studiencode zusammen
mit der aktuellen mobilen Arena-/Namenskorrektur. **Tatsächlich geprüfter
Integrationscommit: `037acb29382b7056259388d79187009ec25397fe`,
Git-Tree `38d05734592cab977a0798a025be529bc3f7b826`.** Das ist ein lokaler
Prüfstand der Studie und keine Behauptung eines veröffentlichten Designs.

| Prüfung, Godot 4.6.3 / OpenGL-Kompatibilität | Ergebnis | Tatsächlicher Umfang |
| --- | --- | --- |
| Geometrie und unveränderte Quelldaten | **1.474 Assertions, 0 Fehler** | 60 kontrollierte Vorschlagskarten; reine Datenprüfungen ausdrücklich kein Bildnachweis |
| Native Vergleichsaufnahmen | **1.033 Assertions, 0 Fehler** | **16 PNGs**, vier Architekturen × Matrix/Handkarten/Smartphone/Kartentypen |
| Transparente Masterraster | **226.784 Assertions, 0 Fehler** | **60 tatsächlich gerenderte Raster**, drei Vorschläge × fünf Mächte × vier Seltenheiten |

Die Rasterprüfung speichert 60 maschinenlesbare Einträge, aber keine zusätzlichen
PNGs (`captures.length=60`, `capture_count=0`). Das ist kein leerer Prüflauf.
Die 16 aktuellen Vergleichs-PNGs werden nicht mit Aufnahmen des früheren,
inzwischen korrigierten Zwischenstands zu einer größeren Zahl vermischt.
Es wurden keine Skript-, Laufzeit- oder Leakfehler gemeldet. Katalog-, Mechanik-,
Produktionsrenderer- und Manifesthashes blieben während der Aufnahmen unverändert.
Vollbilder und kompakte Vorschauen bestanden jeweils ihre eigene Prüfung der
tatsächlich gebundenen Pfade und Bildabmessungen.

Die Integrations-QA hat die aktuellen A-/B-/C-Smartphonebilder und vollständigen
Matrizen angesehen: Scharniere, rechteckige Verzweigungen und Kristallprismen
sind unterscheidbar; die Erklärung passt in das Bild. Die aktuelle Namenssetzung
vermeidet den zuvor sichtbaren einzelnen Endbuchstaben bei „Kupferhüterin“.
Diese Namenskorrektur stammt aus der getrennten Arena-Änderung; die Studie
ändert den globalen Namenssatz nicht.

### Vergleich für die Freigabe

| Vorschlag | Sichtbare Stärke | Abwägung bei der Freigabe |
| --- | --- | --- |
| A / Scharniere | Ruhige, zusammenhängende Materialflächen und klare asymmetrische Gelenke; die Illustration bleibt dominant | Die zurückhaltende Grundstruktur wirkt weniger ornamental als B/C |
| B / Archive | Offene rechteckige Verzweigungen zeigen zunehmende strukturelle Komplexität | Die feineren Linien benötigen auf kleinen Displays besonders sorgfältige Sichtung |
| C / Kristall | Große geteilte Facetten und ausgeprägte Reflexflächen sind schon in der kompakten Ansicht auffällig | Die kräftigeren Seitenprismen beanspruchen mehr Bildrand und können mit kontrastreichen Motiven konkurrieren |

Die Bilder dienen einer Designentscheidung, nicht einer behaupteten objektiven
Premium-Bewertung. Für keinen Vorschlag ist eine endgültige Auswahl getroffen.
Der nominelle kompakte Wert `art_fraction` ist nach Dekorationsüberlagerungen
keine pixelgenaue Messung der sichtbaren Illustration und wird hier nicht als
solche verwendet.

Galerie und Nachweise:
[Vergleichsbilder und Prüfmanifest](fractal-fold-qa/README.md),
[Aufnahmeprotokoll](fractal-fold-qa/comparison.json),
[Masterrasterprotokoll](fractal-fold-qa/raster-comparison.json).
Die eingebetteten WebP-Dateien sind Vorschauen der nativen Godot-PNGs;
die Original-PNG-Hashes stehen im Aufnahmeprotokoll.

Physische iPhone-/Android-Abnahme, GPU-Speichermessung und Designfreigabe sind
weiterhin offen. Der Projektinhaber entscheidet anhand der tatsächlichen Bilder
über die weitere Designrichtung. **Keine globale Umstellung und kein Merge
dieses Entwurfs-PRs ohne seine ausdrückliche Freigabe.**
