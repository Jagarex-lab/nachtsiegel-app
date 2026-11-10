# ORAFOLD – Illustrationsbestand und Produktionsrückstand

Bestandsaufnahme vom10.11.2026 auf Basis des55-Karten-Alpha-Katalogs. Geprüfter Quellstand: `3920b073e50f118d02173e2259a8e0448b7e98f5`. Dieses Dokument inventarisiert tatsächlich vorhandene Karten und tatsächlich verwendete Bildquellen. Es erzeugt keine Karten, Bilder oder kommerziellen Freigaben.

## Tatsächlicher Umfang

- **55 vorhandene Alpha-Karten:**37 Wesen,12 Impulse,6 Relikte;15 neutral und je10 pro Macht.
- **55 fehlende individuelle Originalillustrationen:** Keine der55 Karten bindet im aktiven Katalog eine eigene`art`-Ressource. Alle verwenden denselben Konzeptatlas über die ID-Hashauswahl. Auch die vorgesehenen individuellen Dateien unter`assets/cards/originals/<card-id>.png` sind für alle55 IDs nicht vorhanden.
- **Sieben wiederverwendete Atlaszellen**, keine55 eigenständigen Motive. Der Atlas enthält insgesamt neun Zellen; die aktuelle Auswahl modulo7 verwendet nur die ersten sieben.
- **Weitere495 Karten sind noch nicht autoriert.**550 bleibt das Entwicklungsziel. Für diese495 werden weder erfundene Kartenzeilen noch angeblich vorhandene Illustrationen angelegt. Die100 getrennten Legacy-Karten/Referenzdaten sind kein zusätzlicher fertiger ORAFOLD-Katalog.

Primärquellen: [aktive Kartendaten](../../data/alpha/cards.json), [kompakter Kartenrenderer](../../scripts/alpha/card_view.gd), [Vollkartenrenderer](../../scripts/card_system/card_face.gd), [Asset-Herkunft](../../assets/ASSET_MANIFEST.md). Das bestehende [Illustrationsmanifest](../../data/card_system/illustration_manifest.json) inventarisiert bewusst nur die acht V2-Pilotkarten und ersetzt keine vollständige55er-Liste. Die Stildatei`alpha/style.gd` enthält derzeit keine eigene`S.art`-Auswahlfunktion; die tatsächliche Bildauswahl steht in den beiden genannten Renderern.

## Gemeinsame Quelle und tatsächlich verwendete Regionen

Für jede unten genannte Karte lautet die Bildquelle **`res://assets/art/atlas.png`**, im V2-Pilot als`shared:orafold-atlas` bezeichnet. Dateigröße im Bildraum:1245×1263px,3×3-Zellen zu415×421px. Geprüfte SHA-256:

`3655610a243d792b90115ba752805a28d3e1f3491e1f70e3fba1c17660ad1db3`

Die Renderer berechnen`absi(str(card.id).hash()) % 7`. Die nachfolgenden Zuordnungen wurden aus dieser tatsächlich vorhandenen Formel ermittelt. Die32-Bit-DJB2-Implementierung von`String::hash()` wurde gegen den [Godot4.6.3-Quelltext](https://github.com/godotengine/godot/blob/4.6.3-stable/core/string/ustring.cpp) geprüft: Startwert5381, pro Zeichen`hash = (hash * 33 + codepoint) mod 2^32`. Das ist eine nachvollziehbare statische Auflösung der Rendererformel, kein neuer Geräte- oder GUI-Test.

| Region | Nullbasierter Index | Atlasrechteck(x,y,Breite,Höhe) | Motiv laut bestehendem Herkunftsmanifest | Verwendungen |
|---|---:|---|---|---:|
| A0 |0| (0,0,415,421) | Aschenwache |10|
| A1 |1| (415,0,415,421) | Dornenwolf |7|
| A2 |2| (830,0,415,421) | Nebelqualle |8|
| A3 |3| (0,421,415,421) | Schattenwolf |9|
| A4 |4| (415,421,415,421) | Glutritter |7|
| A5 |5| (830,421,415,421) | Gezeitenhüter |7|
| A6 |6| (0,842,415,421) | Funkenstoß |7|

Die Namen der Motive sind Aussagen des vorhandenen Manifests, keine neu bestätigte ORAFOLD-Lore. Zellen7(Siegelhüterin) und8(Aschenkönig) sind im Atlas verfügbar, werden durch die aktuelle Alpha-Auswahl aber nicht verwendet.

Die Tabelle bezeichnet die Ausgangszelle. Tatsächlich sichtbare Ausschnitte hängen vom Renderer ab: Die Vollkarte verwendet innerhalb der jeweiligen Zelle einen415×308,78px-Ausschnitt mit39,28px vertikalem Versatz und zeichnet ihn in672×500 Masterpixel. Kompakte Karten beschneiden abhängig vom Seitenverhältnis des Bildfensters horizontal oder vertikal; die genaue Formel steht in`card_view.gd:illustration()`. Diese Zuschnitte erzeugen keine neuen Originalmotive. Die gemeinsame Quelle ist für mehrere Karten semantisch unpassend, beispielsweise zeigt nicht jeder beruflich benannte Mensch ein eigenes menschliches Porträt.

## Vollständiger55er-Rückstand

**„Fehlt“ bedeutet in jeder Zeile: individuelles, geprüft zugeordnetes Original fehlt; lediglich das angegebene gemeinsame Konzept wird angezeigt.** Es ist keine Aussage, dass die Karte technisch unspielbar wäre. Es werden keine zusätzlichen Karten oder Bilder angedeutet.

| Karten-ID | Vorhandener Kartenname | Typ | Aktuelle Quelle | Individuelles Original |
|---|---|---|---|---|
| oa-neutral-c01 | Pfadkundiger | Wesen | Atlas A6 | Fehlt |
| oa-neutral-c02 | Torwache | Wesen | Atlas A0 | Fehlt |
| oa-neutral-c03 | Prismaträger | Wesen | Atlas A1 | Fehlt |
| oa-neutral-c04 | Feldärztin | Wesen | Atlas A2 | Fehlt |
| oa-neutral-c05 | Bündnisträger | Wesen | Atlas A3 | Fehlt |
| oa-neutral-c06 | Chronist | Wesen | Atlas A4 | Fehlt |
| oa-neutral-c07 | Eilbote | Wesen | Atlas A5 | Fehlt |
| oa-neutral-c08 | Wegweber | Wesen | Atlas A6 | Fehlt |
| oa-neutral-c09 | Resonanzträger | Wesen | Atlas A0 | Fehlt |
| oa-houses-c01 | Namenhüter | Wesen | Atlas A3 | Fehlt |
| oa-houses-c02 | Eidärztin | Wesen | Atlas A4 | Fehlt |
| oa-houses-c03 | Blutarchivar | Wesen | Atlas A5 | Fehlt |
| oa-houses-c04 | Erinnerungsleserin | Wesen | Atlas A6 | Fehlt |
| oa-houses-c05 | Erbenwall | Wesen | Atlas A0 | Fehlt |
| oa-houses-c06 | Ahnenrufer | Wesen | Atlas A1 | Fehlt |
| oa-houses-c07 | Die letzte Erbin | Wesen | Atlas A2 | Fehlt |
| oa-stillwatch-c01 | Glaskonservator | Wesen | Atlas A6 | Fehlt |
| oa-stillwatch-c02 | Ewigwächter | Wesen | Atlas A0 | Fehlt |
| oa-stillwatch-c03 | Nullsekunde | Wesen | Atlas A1 | Fehlt |
| oa-stillwatch-c04 | Siegelrichter | Wesen | Atlas A2 | Fehlt |
| oa-stillwatch-c05 | Bewahrerin | Wesen | Atlas A3 | Fehlt |
| oa-stillwatch-c06 | Winterherold | Wesen | Atlas A4 | Fehlt |
| oa-stillwatch-c07 | Die unbewegte Königin | Wesen | Atlas A5 | Fehlt |
| oa-morph-c01 | Sprunglarve | Wesen | Atlas A5 | Fehlt |
| oa-morph-c02 | Schwarmrufer | Wesen | Atlas A6 | Fehlt |
| oa-morph-c03 | Pfadwanderin | Wesen | Atlas A0 | Fehlt |
| oa-morph-c04 | Sporenträger | Wesen | Atlas A1 | Fehlt |
| oa-morph-c05 | Häutungsweiser | Wesen | Atlas A2 | Fehlt |
| oa-morph-c06 | Gegendorn | Wesen | Atlas A3 | Fehlt |
| oa-morph-c07 | Die Vielstimmige | Wesen | Atlas A4 | Fehlt |
| oa-ninth-c01 | Kausaljäger | Wesen | Atlas A1 | Fehlt |
| oa-ninth-c02 | Spaltenspeer | Wesen | Atlas A2 | Fehlt |
| oa-ninth-c03 | Vorzeichner | Wesen | Atlas A3 | Fehlt |
| oa-ninth-c04 | Uhrlose | Wesen | Atlas A4 | Fehlt |
| oa-ninth-c05 | Schuldzehrer | Wesen | Atlas A5 | Fehlt |
| oa-ninth-c06 | Möglichkeitsweber | Wesen | Atlas A6 | Fehlt |
| oa-ninth-c07 | Der neunte Zeuge | Wesen | Atlas A0 | Fehlt |
| oa-neutral-e01 | Prismenblitz | Impuls | Atlas A0 | Fehlt |
| oa-neutral-e02 | Atempause | Impuls | Atlas A1 | Fehlt |
| oa-neutral-e03 | Festes Bild | Impuls | Atlas A2 | Fehlt |
| oa-neutral-e04 | Doppelter Schritt | Impuls | Atlas A3 | Fehlt |
| oa-houses-e01 | Wiederkehr | Impuls | Atlas A4 | Fehlt |
| oa-houses-e02 | Letzter Eid | Impuls | Atlas A5 | Fehlt |
| oa-stillwatch-e01 | Aufgeschobenes Urteil | Impuls | Atlas A0 | Fehlt |
| oa-stillwatch-e02 | Konservierung | Impuls | Atlas A1 | Fehlt |
| oa-morph-e01 | Seitenwechsel | Impuls | Atlas A6 | Fehlt |
| oa-morph-e02 | Rascher Wandel | Impuls | Atlas A0 | Fehlt |
| oa-ninth-e01 | Umleitung | Impuls | Atlas A2 | Fehlt |
| oa-ninth-e02 | Echosalve | Impuls | Atlas A3 | Fehlt |
| oa-neutral-r01 | Wanderkompass | Relikt | Atlas A3 | Fehlt |
| oa-neutral-r02 | Feldspiegel | Relikt | Atlas A4 | Fehlt |
| oa-houses-r01 | Ahnenregister | Relikt | Atlas A0 | Fehlt |
| oa-stillwatch-r01 | Bewahrungsuhr | Relikt | Atlas A3 | Fehlt |
| oa-morph-r01 | Schwarmknoten | Relikt | Atlas A2 | Fehlt |
| oa-ninth-r01 | Vorhersagelinse | Relikt | Atlas A5 | Fehlt |

## Herkunft, Lizenzbelege und offene Nachweise

| Gegenstand | Tatsächlich vorhandener Beleg | Grenze des Belegs |
|---|---|---|
| Konzeptatlas |`assets/ASSET_MANIFEST.md` nennt OpenAI Image Generation,08.11.2026, neun Motive und keine verwendete Franchisevorlage; PNG und Hash liegen vor. | Das ist eine projektinterne Herkunftserklärung. Ein vollständiges Prompt-/Generierungsprotokoll, die konkrete Kontolizenz und eine individuelle kommerzielle Freigabe pro Karte wurden in den geprüften Repository-Dateien nicht gefunden. Keine Exklusivität wird behauptet. |
| Weitere KI-Konzeptassets | Dasselbe Manifest nennt Arena, Reliquienrahmen, Heldenmedaillon und Schiefertextur mit Entstehungsangaben. | Sie sind keine individuellen55-Karten-Illustrationen und schließen den Rückstand nicht. |
| Projektcode/-assets |`LICENSE-NOTICE.md` erklärt, dass Originalcode und Originalassets durch dieses Repository keine Open-Source-Lizenz erhalten; fremde Assets benötigen kompatible kommerzielle Nutzungsrechte. | Diese Notiz ist keine separate Rechteübertragung oder pauschale kommerzielle Bildfreigabe. |
| DejaVu-Schriften |`assets/fonts/LICENSE` enthält Bitstream-Vera-Nutzungs-/Weitergabebedingungen und Hinweise auf gemeinfreie DejaVu-Änderungen. | Schriftrechte gelten nicht automatisch für Illustrationen; vorgeschriebene Hinweise müssen erhalten bleiben. |
| Cinzel |`assets/fonts/Cinzel-OFL.txt` enthält SIL Open Font License1.1 und Urheberangaben. | Diese Lizenz betrifft die Schrift und ihre Einbettung, keine Kartenbilder. |

Es werden keine erfundenen Freigaben, abgeschlossene juristische Prüfung oder außerhalb des Repositories vorhandene Rohdateien behauptet. Die vorhandene Spielbarkeit mit markierten Konzepten ist von der Produktion individueller, nachweisbar nutzbarer Illustrationen getrennt.

Die PNG-Datei enthält bei der Prüfung mit Pillow keine auslesbaren Metadatenfelder; ein eingebettetes Generierungsprotokoll wurde damit ebenfalls nicht nachgewiesen. Der Dokumentabgleich bestätigte55/55 eindeutige IDs, Namen, Typen und berechnete Atlasregionen gegen die aktuellen Daten sowie55 fehlende erwartete Originaldateien. Es wurde keine GUI und kein neuer Spieltest ausgeführt.

## Nächster Produktionsschritt

Für die55 realen Karten werden zuerst individuelle Bildbriefings aus bestätigten Namen, Mächten, Arten und Effekten erstellt. Jede spätere Bilddatei benötigt stabile Karten-/Asset-ID, tatsächliche Quelle oder Generierungsprotokoll, Urheber-/Generatorangaben, Datum, Referenzquellen, dokumentierte Nutzungsgrundlage, Originalauflösung, Hash und Prüfstatus. Erst nach Bild- und Rechteprüfung wird`art.status=final` zulässig; bloßes Hochskalieren der Atlaszelle zählt nicht als neues Original.

Format, Machtfarben,756×1056-Master, Raumfalten-Komposition und Auflösungs-/Speicherziele stehen im [CARD_STYLE_GUIDE](CARD_STYLE_GUIDE.md). Für das Ziel550 gilt der [Implementierungsplan](IMPLEMENTATION_PLAN.md); die übrigen495 Einträge beginnen mit tatsächlicher Kartenautorenschaft und werden erst danach in diesen Rückstand aufgenommen. In diesem Dokumentationspaket wurden keine Illustrationen erzeugt und keine Laufzeitdateien verändert.
