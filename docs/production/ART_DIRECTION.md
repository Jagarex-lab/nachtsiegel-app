# ORAFOLD – Art Direction für individuelle Illustrationen

Stand: 10.11.2026. **Produktionsvorschlag**, keine Kanonisierung und keine Bildabnahme. Diese Ergänzung baut auf dem bestehenden [Card Style Guide](../master550/CARD_STYLE_GUIDE.md) und der [Lore-Bibel](../LORE-BIBLE.md) auf. Die Dateien unter `data/production/art-briefs/` sind Aufträge für Bilder, keine erzeugten Bilder, aktiven Karten oder geprüften Effektdefinitionen.

## Bild und Karte getrennt produzieren

Die KI oder eine Illustratorin erzeugt ausschließlich die Illustration. Namen, Kosten, Werte, Arten, Typen, Seltenheiten und Rahmen zeichnet Godot aus validierten Kartendaten. Auch eine legendäre Illustration enthält weder Typografie noch Ziffern, Rahmen, Seltenheitszeichen oder Rückseitenbestandteile.

Das Kartenmaster bleibt **756 × 1056 Pixel**, 63:88. Außenkontur, Ecken, Informationspositionen, gemeinsame Rückseite und asymmetrische Raumfalte bleiben beim bestehenden Renderer. Das sichtbare Bildfenster liegt dort bei **672 × 500 Masterpixeln**. Das individuelle Ausgangsbild muss mindestens **1344 × 1000 Pixel** echte Quelldetails für dieses Fenster liefern. Ein größerer Export oder Upscaling erzeugt keine neue Originalauflösung. Andere Bildverhältnisse benötigen einen dokumentierten, visuell geprüften Zuschnitt.

Wichtige Gesichter, Hände, Objektkonturen und Wirkungszentren liegen in den mittleren etwa 70 Prozent der Bildbreite. Die untere Bildkante trägt keine für das Verständnis unverzichtbaren Details; die vorhandene Diagonale kann sie beschneiden. Auch links oben und rechts oben bleiben Randdetails verzichtbar. Ein Preview im vollständigen Kartenrenderer entscheidet über die Abnahme, nicht das alleinstehende große Artwork.

## Gemeinsame Bildsprache

Science Fantasy mit gemalten Materialien, klaren großen Formen und glaubwürdiger Beleuchtung. Gebrauchsspuren erzählen von Arbeit, Reisen, Bewahrung und Anpassung. Ungewöhnliche Physik bleibt räumlich lesbar: eine klar begrenzte Falte, Stasisfläche oder Verschiebung wirkt stärker als beliebige leuchtende Partikel überall.

Ein Hauptmotiv, eine konkrete Tätigkeit und ein sichtbares Unterscheidungsmerkmal tragen das Bild. Große Hintergrundarchitektur wird vereinfacht. Kleidung, Werkzeuge, Bewuchs und Schmutz folgen dem konkreten Ort. Gesicht und Anatomie dürfen individuell sein; jede Figur als gerüstete, frontal posierende Heldengestalt darzustellen schwächt die Sammlung. Die Briefings benennen eigenständige Situationen, statt ein Motiv nur mit einer anderen Farbe oder Zahl erneut zu bestellen.

Oberes Seitenlicht und ruhige Schatten unterstützen die Materiallesbarkeit. Kein pauschales Gegenlicht, das sämtliche Figuren zu dunklen Umrissen macht. Farbige Wirkungskanten bleiben schmal genug, dass Hände, Gelenke und Objektverbindungen erkennbar sind. Illustrierte Raumfalten dürfen sich innerhalb des Artworkfensters bewegen; der Kartenrenderer beschneidet sie an seiner unveränderten Kontur.

## Machtidentität

| Zugehörigkeit | Dominante Akzente | Materialien und Formensprache | Zu vermeiden |
|---|---|---|---|
| Zwölf Häuser | Kupfer, warme dunkle Brauntöne | Geerbte Reparaturen, geschichtete Hüllen, sorgfältig bewahrte Spuren | Neue verbindliche Hauswappen oder unbelegte Herrscherdarstellungen |
| Stillwacht | Eisblau, kalte helle Flächen | Belastbare Schutzflächen, präzise Stützen, ruhige horizontale Rhythmen | Jede Karte als dieselbe Eisritterfigur |
| Vielgestalt | Jadegrün, gedämpfte organische Töne | Flexible Körperachsen, sichtbare Anpassung, asymmetrische natürliche Formen | Beliebige zusätzliche Gliedmaßen ohne funktionale Verbindung |
| Neunte Stunde | Amethyst, entsättigte tiefe Schatten | Instrumente, unterbrochene Bewegung, klare lokale Verschiebungen | Eine weltweite kosmische Katastrophe als Standardhintergrund |
| Neutral | Graphit und Stahl; lokale Naturfarben bleiben erhalten | Alltagsgeräte, Transport, Arbeit, Reisende, eigenständige Ökologie | Neutral als fünfte einheitliche Kultur oder nur graue Farblosigkeit |

Die Machtfarbe dominiert den Rahmen und bleibt ein wiederkehrender Bildakzent. Sie muss nicht jedes natürliche Material umfärben. Seltenheit wird überwiegend durch die bestehende deterministische Rahmenmaterialität vermittelt. Seltene Bilder dürfen konzentrierter und einzigartiger werden; eine höhere Seltenheit verlangt weder ein größeres Wesen noch stärkere Sättigung oder automatisch Führungsrang.

## Arten und Typen sichtbar erklären

Die zwölf offiziellen Arten bleiben die Klassifikation aus der Lore-Bibel. Eine visuelle Umsetzung erklärt die tatsächlich angegebenen ein oder zwei Arten, statt eine menschliche Berufsbezeichnung ungeprüft als Anatomie zu übernehmen. Beide Arten einer Doppelklassifikation müssen gleichwertig erkennbar sein.

Menschen benötigen glaubwürdige Gelenke und eine zur Tätigkeit passende Handhaltung. Bestien brauchen eine zusammenhängende Bewegungsanatomie. Pflanzen zeigen funktionale Wurzeln, Stängel und Blätter; sie erhalten nicht automatisch ein menschliches Gesicht. Konstrukte und Mechanoide benötigen nachvollziehbare Verbindungen und Materialübergänge. Amalgame und Morphiden besitzen trotz ungewöhnlicher Formen eine im Bild erkennbare Körperorganisation. Geister, Paradoxe, Wiedergänger, Elementare und Zehrer bekommen pro Karte eine begrenzte konkrete Erscheinung. Diese visuellen Entscheidungen definieren keine universelle Metaphysik der Art. Echo wird nicht als zusätzliche Art eingeführt.

Bei **Wesen** bestimmen Silhouette und Tätigkeit das Hauptmotiv. Bei **Impulsen** ist ein klarer Ereignismoment sichtbar: Auslöser, Eingriff oder unmittelbare Folge. Ein beliebiges Porträt mit Lichtstrahlen genügt dafür nicht. Bei **Relikten** trägt ein eigenständiges Objekt die Komposition; Befestigung, Maßstab und eine erkennbare Gebrauchsspur machen es materiell lesbar. Keine zusätzlichen Hauptkartentypen erfinden.

## Briefings und Lorestatus

Jedes Briefing bindet seine stabile `card_id` an den unveränderten `source_name`. `proposed_name` ist ein redaktioneller Namensvorschlag und ändert keine aktive Karte. `subject`, `action`, `setting`, `composition` und `distinctive_detail` bilden zusammen den individuellen Bildauftrag; `avoid` schränkt bekannte Fehlrichtungen ein.

Alle neuen Briefings tragen **`lore_status: VORSCHLAG`**. Die aus den Konzepten übernommenen Regionen und kleineren örtlichen Situationen bleiben Vorschläge. Sie bestätigen weder den in `docs/lore/` vorgeschlagenen Kontinent noch dessen Ursprungsgeschichte. Keine Illustration beantwortet Eiras Geheimnis, bestimmt Ursachen der Zeitkorrektur, legt das Archiv ontologisch fest oder ernennt neue Fraktionsführer. Historische Figuren aus dem Arvess-/Gegenmaß-Altentwurf werden nicht übernommen.

## Visuelle Abnahme pro Bild

1. Motiv gegen seine stabile Karten-ID, Briefing, Typ und Arten prüfen. Eine vorhandene Datei ist kein Beleg für passende Identität.
2. Anatomie und Objekte bei Originalgröße prüfen: Fingerzahl, Gelenke, Werkzeugkontakt, Zugrichtungen von Seilen, Symmetrie dort, wo sie funktional nötig ist, Schatten und Spiegelungen. Absichtliche Anomalien müssen sich vom Generierungsfehler unterscheiden lassen.
3. Bildfenster zuschneiden und in der bestehenden Vollkarte betrachten. Keine entscheidenden Details unter der Diagonale oder an den Randmasken verlieren.
4. Auf etwa 168 × 125 Pixel verkleinert sowie in einer Handkartenvorschau prüfen. Hauptsilhouette, Tätigkeit und mindestens ein unterscheidbares Merkmal sollen noch erkennbar sein. Diese Sichtprüfung ist keine bestätigte Mobile-Geräteprüfung.
5. Mit benachbarten Karten derselben Macht und desselben Typs vergleichen. Wiederholte Pose, identischer Kopf, gleicher Hintergrund oder nahezu derselbe Gegenstand verlangen Überarbeitung; ein neuer Dateihash genügt nicht als Individualitätsbeleg.
6. Transparenz, sichtbare Artefakte, Bildgröße, tatsächliches Dekodieren und zulässige Dateiformate technisch prüfen. Import mit Mipmaps und Speicherverbrauch auf den späteren Zielgeräten messen. Nicht alle 550 Originaltexturen gleichzeitig laden.
7. Visuelle Entscheidung mit Datum, prüfender Person und etwaigen verbleibenden Punkten dokumentieren. Automatische Checks ersetzen diese Entscheidung nicht.

Ein Bild mit `concept` kann für interne Sichtung brauchbar sein. **`final`** setzt bestandene technische, visuelle und Herkunftsprüfung voraus. Fehlt eine dieser Prüfungen, bleibt der entsprechende Status offen. Geteilte Atlaszellen und ihre Vergrößerungen zählen nicht als neue individuelle Originalillustrationen.

## Herkunft und Nutzungsgrundlage

Je Asset sind mindestens Karten-ID, Asset-ID, tatsächlicher Urheber oder Generator, Erstellungsdatum, Quelle beziehungsweise vollständiger Prompt, verwendete Referenzen, Änderungen, Originalauflösung, SHA-256, Alternativtext und Prüfstatus festzuhalten. Bei generierten Bildern gehören tatsächlich verwendete Werkzeuge und Referenzdateien ins Protokoll; erfundene Modellversionen oder nicht belegte Entstehungsdaten sind unzulässig.

Die dokumentierte Grundlage zur kommerziellen Nutzung muss zum konkreten Asset passen. Ein Quellenlink, technische Validität oder eine interne Notiz allein bestätigen weder Exklusivität noch eine abgeschlossene juristische Prüfung. Fremde Logos, erkennbare geschützte Figuren und unbelegte Referenzübernahmen verhindern eine finale Freigabe. Vorhandene Schriftlizenzen aus dem Repository bleiben erhalten; sie übertragen keine Rechte an Illustrationen.

Dieses Paket liefert Briefings und Produktionsregeln. Eine Illustration wird erst dann als vorhanden gezählt, wenn die zugeordnete Bilddatei tatsächlich vorliegt; als fertig zählt sie erst nach den dokumentierten Abnahmen.
