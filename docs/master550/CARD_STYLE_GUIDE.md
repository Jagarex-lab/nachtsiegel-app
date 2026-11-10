# ORAFOLD – kanonische Vollkarte und Bildpipeline

Stand: 10.11.2026. M5 ist eine geprüfte Darstellungsgrundlage; dieser Stand enthält weder550 fertige Einzelillustrationen noch einen neuen550-Karten-Katalog. Die kompakte Spielfeld-/Handdarstellung und die Kampflogik werden durch diesen Renderer nicht verändert.

## Verbindliche Geometrie

Implementierung: [card_face.gd](../../scripts/card_system/card_face.gd). Digitales Koordinatensystem756×1056, Verhältnis63:88. `face_rect()` passt dieses Format gleichmäßig in den verfügbaren Control ein und zentriert es; es wird nicht verzerrt. Gleiche Außenkontur für sämtliche Mächte, Typen, Seltenheiten und Rückseiten: Rechteck(8,8,740,1040), Eckradius34. Bevel, Kristalle, Falzlinien und Seltenheitszeichen bleiben innerhalb dieser Kontur. Kein Außenleuchten und keine überstehenden legendären Aufbauten.

Die obere linke Lichtquelle gilt für alle Materialkanten. Der dunkle, leicht kühle Grundkörper trägt die Machtfarbe; helle obere/linke Kanten und dunkle untere/rechte Kanten erzeugen Materialtiefe ohne zusätzliche Shader oder Partikel. Die asymmetrische Raumfalte trennt Bild und Informationsbereich mit einer Diagonale von(42,647) nach(714,561). Diese Geometrie ist die gemeinsame Formensprache, kein kopiertes Kartenspiel-Layout.

| Information | Masterposition / Verhalten |
|---|---|
| Energie | Kreis oben links, Mittelpunkt(82,87), Radius36 |
| Name | (126,49),478×87; adaptive25–34px, Wortumbruch; kein Ellipsis |
| Machtzeichen | Raute oben rechts um(663,87), zusätzlich ausgeschriebener Machtname unter der Illustration |
| Illustration | (42,152),672×500; proportional beschnitten, nicht verzerrt |
| Typ | unter der Diagonale; ausschließlich Wesen, Impuls oder Relikt |
| Wesensarten | unter der Typzeile; beide Arten gleichwertig und nebeneinander |
| Fähigkeiten | opake Informationsfläche; adaptive24–30px; vollständiger Text aus den Daten |
| Angriff / Leben | ausschließlich Wesen, symmetrische Rauten unten links/rechts |
| Seltenheit | unten mittig als eigenes Zeichen plus ausgeschriebener Name |

Bei den alten55 Alpha-Karten fehlen Arten. Die Vollkarte lässt die Artenzeile dann leer; sie zeigt weder eine technische Warnung im Produkt noch weist sie einer alten Karte nachträglich eine erfundene Art zu. Diese Datenlücke bleibt im Audit dokumentiert und wird vom neuen Datenvertrag geprüft. Der V2-Pilot kann vorhandene Artenfelder darstellen, ohne den aktiven Katalog zu ändern. Unbekannte Arten werden nicht als angeblich gültige Art erfunden; die vorgeschaltete Datenvalidierung muss sie zurückweisen.

## Macht und Seltenheit

| Macht | Rahmenpigment | Zeichen |
|---|---|---|
| Zwölf Häuser | Kupfer `#c58c64` | Ⅻ |
| Stillwacht | Eisblau `#9bd2e8` | ◇ |
| Vielgestalt | Jade `#65c49e` | ❧ |
| Neunte Stunde | Amethyst `#b99ce2` | Ⅸ |
| Neutral | Graphit/Stahl `#a9bac9` | ○ |

Die Macht bleibt durch Farbe, Symbol und Text erkennbar. Seltenheit ändert die Machtfarbe nicht: gewöhnlich hat eine schlichte Innenkante; selten zusätzliche Falzkanten; episch mehrere Innenebenen und zwei schmale Kristallfacetten; legendär zusätzlich eine innenliegende gebrochene Raumfalte. Eigene Zeichen und Texte unterscheiden alle vier Stufen auch ohne Farbe. Es existieren derzeit keine aktiven epischen Alpha-Karten; die epische Gestaltung wird mit einem ausdrücklich synthetischen Renderfall geprüft.

Die Rückseite verwendet ausschließlich neutrales Stahlblau/Graphit, gespiegelte Falzgeometrie, ein eigenes gebrochenes Raumzeichen, fünf Pfadlinien und ORAFOLD-Schrift. `draw_back()` liest keinerlei Kartenfelder. Alle Karten haben dieselbe Rückseite; weder Macht noch Kosten, Typ, Seltenheit oder Identität fließen in die Zeichnung ein. Sie hat dieselbe gerundete Außenkontur wie die Vorderseite.

## Schrift, Schärfe und Bedienung

Der Renderer verwendet die bestehende lizenzierte DejaVu-Schrift über `scripts/alpha/style.gd`: MSDF an, Ausgangsgröße64. Texte und Rahmen werden als Godot-Zeichnung in der tatsächlichen Viewport-Auflösung erzeugt; es wird kein756px-Gesamtbild zur Laufzeit als UI hochskaliert. MSDF verhindert keine zu kleine Anzeige: bei350px Kartenbreite beträgt der Faktor0,463;24–30 Masterpixel entsprechen etwa11,1–13,9 CSS-Pixeln. Deshalb bleibt eine lesbare externe Inspektion mit zusätzlichem Volltext und gegebenenfalls Scrollen erforderlich. Eine auf195px verkleinerte Vollkarte ist eine Vorschau, kein Ersatz für diese Inspektion.

Informationsflächen sind opak: `#161d29`, Text `#f3ede2`, Sekundärtext `#c5ccd7`. Die Renderprüfung verlangt für beide mindestens4,5:1 Kontrast. Artwork trägt keinen regelrelevanten Text. Textfelder passen die Schrift innerhalb eines begrenzten Bereichs an; `layout_report()` meldet zu lange Inhalte ausdrücklich über `title_fits` und `rules_fit`. Es werden keine langen zukünftigen Texte stillschweigend als geprüft ausgegeben.

`card_face.gd` ist ein nicht interaktives Control (`MOUSE_FILTER_IGNORE`); der umgebende Inspektor steuert Schließen, Scrollen und Eingaben. API: `Face.new()`, `view.card = dictionary`, `view.face_down = bool`, `view.size = …`. Damit kann das Design ohne zweite Eingabelogik in bestehende Dialoge eingebettet werden. Die Normalisierung akzeptiert Alpha-V1(`faction`, `cost`, `atk`, `hp`, `description`) und V2(`power`, `energy_cost`, `attack`, `health`, `species`, `text_de`). Numerisches V1-`power` wird ausdrücklich nicht als Machtname interpretiert. Technische Typ-ID `event` wird als **Impuls** dargestellt; kein vierter Haupttyp wird eingeführt.

## Illustration und Rechte: tatsächlicher Stand

Vorhanden ist ein1245×1263px-Konzeptatlas mit neun415×421px-Zellen. Die aktive Alpha-Darstellung teilt sieben Motive. Beim Vollkarten-Bildfenster wird ein ungefähr415×309px-Ausschnitt auf672×500 Masterpixel vergrößert. Diese begrenzte Quellauflösung ist eine eigenständige Bildgrenze; MSDF oder eine höhere Canvas-Auflösung erzeugen daraus keine zusätzlichen Bilddetails. Der Renderer verwendet lineare Filterung mit Mipmaps gegen Flimmern beim Verkleinern und kennzeichnet den Fallback direkt als **GETEILTES KONZEPTBILD**. Das ist kein fertiges individuelles Motiv.

Herkunft und vorhandene Schriftlizenzen: [ASSET_MANIFEST.md](../../assets/ASSET_MANIFEST.md), [DejaVu-Lizenz](../../assets/fonts/LICENSE), [Cinzel OFL](../../assets/fonts/Cinzel-OFL.txt), zusätzlich bestehende Projektlizenz und LICENSE-NOTICE. Der Atlas wurde laut Manifest projektbezogen mit OpenAI Image Generation erzeugt; es werden weder exklusive Bildrechte noch abgeschlossene juristische Prüfung behauptet. In diesem Paket wurden **keine** neuen KI-Illustrationen erzeugt. Für den geplanten550er-Katalog fehlen weiterhin550 individuelle, geprüfte Bildzuordnungen; die vorhandenen geteilten Konzepte werden nicht als550 fertige Assets gezählt.

Die nächste Produktionsstufe verwendet stabile `art.asset_id`, Status `missing/shared_concept/concept/final`, Herkunft und Rechtenachweis. Der validierte V2-Vertrag kann bereits eine überprüfte `res://assets/…`-Bildressource über `art.asset_id` auflösen; Namen werden nicht automatisch in Dateipfade umgewandelt. `shared:orafold-atlas` bleibt ausdrücklich ein geteiltes Konzept. Die Datenvalidierung prüft Pfad, Bilddatei und Herkunft; der Renderer prüft zusätzlich tatsächliche Ressourcenverfügbarkeit und den Typ `Texture2D`. Ohne geladene Textur wird auch ein irrtümlich als`final` deklariertes Bild wieder als geteiltes Konzept dargestellt und beschriftet. Die Quelldaten bleiben unverändert. Das ältere optionale Darstellungsfeld `art.path` ist ausschließlich ein V1-Adapter und kein Bestandteil des V2-Datenvertrags; V2 kann damit die`asset_id`-Auflösung nicht umgehen.

Für jedes endgültige Motiv erforderlich:

1. Eigener Bildbrief aus bestätigter Macht-/Kartenidentität, keine fremden Figuren, Logos oder widersprüchliche neue Lore.
2. Unbeschriftetes Artwork mindestens1344×1000px für das672×500-Fenster bei2× Darstellung; zentrale Silhouette auch bei kleinem Handkarten-Crop erkennbar. Kein Upscaling als neues Original deklarieren.
3. Komposition mit sicherer Bildmitte und reservierter Diagonalkante; keine eingebrannten Zahlen, Kartennamen oder UI-Rahmen.
4. Rohquelle und Nachweis der kommerziellen Verwendbarkeit archivieren; Status erst nach visueller und rechtlicher Sichtung auf`final` setzen.
5. Ressourcengröße, Import, Mipmaps, Speicher und Ladezeit auf Web/Mobile messen. Atlas/Slicing oder bedarfsgeladenes Artwork verwenden; keine550 hochaufgelösten Texturen gleichzeitig laden.

## Reproduzierbare Prüfung

```sh
export DISPLAY=:99 LP_NUM_THREADS=2
export XDG_DATA_HOME="$PWD/work/xdg/data"
export XDG_CONFIG_HOME="$PWD/work/xdg/config"
export XDG_CACHE_HOME="$PWD/work/xdg/cache"
godot --path . --audio-driver Dummy --script tests/master550_card_visual.gd > work/master550-card-visual.log 2>&1
```

Der Test rendert20 Kombinationen(5 Mächte×4 Seltenheiten) tatsächlich im756×1056-SubViewport, prüft die gemeinsame Alpha-Außenkontur pixelweise, transparente Außenränder und passende Informationsgeometrie. Weitere Prüfungen:55 reale Alpha-Namen/-Texte, V1/V2-Normalisierung,3 Typen, optionaler Resonanztext ohne Überlagerung,20 identische Rückseiten unabhängig von geheimen Kartendaten und3 proportionale Einpassungen(350×489,390×844,844×390). PNG-Nachweise werden reproduzierbar unter`work/master550/cards/` abgelegt: Raritäts-/Machtmatrix, vier Master-Raritäten, drei Typen, Rückseite und Einpassungen.

Ergebnis am10.11.2026 mit Godot4.6.3: **374 Assertions,0 Fehler**. Jede der20 Vorderseiten besitzt einen eigenen Bildhash; alle20 Rückseiten sind bytegleich. Zusätzliche echte Renderfälle prüfen eine vorhandene V2-`asset_id`-Textur als Konzept, den synthetischen Finalstatus desselben Testbilds und den identischen, ausdrücklich beschrifteten Konzept-Fallback bei fehlendem Finalasset. Ein bestehendes Nicht-Bild darf nicht als Finalillustration erscheinen; V2 kann nicht auf das alte`art.path` ausweichen. Diese Loader-Testfälle sind keine Freigabe des verwendeten Konzeptbilds als fertige Kartenillustration. Der abschließende Lauf mit Dummy-Audio enthält keine`SCRIPT ERROR`, `ERROR:` oder `FAIL`-Zeilen. Ein erster Lauf ohne expliziten Audio-Treiber meldete vor dem erfolgreichen Dummy-Fallback die fehlende ALSA-Hardware; der reproduzierbare Befehl oben vermeidet diesen Umgebungsfehler. Master-Vorderseite,350×489-Einpassung und Rückseite wurden zusätzlich visuell gesichtet.

Dies sind echte native Godot-Renderprüfungen auf Linux/llvmpipe. Sie sind keine iPhone-Gerätetests und keine Aussage über die vollständige550-Karten-Balance oder deren noch fehlende Illustrationen. Browser-/Inspektorregressionen gehören zur anschließenden UI-Integration.
