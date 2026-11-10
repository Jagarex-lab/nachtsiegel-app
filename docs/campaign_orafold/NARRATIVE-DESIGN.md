# Narrative Gestaltung und Lorekontrolle

Stand: 10.11.2026. Quelle und Vorrang: [LORE-BIBLE.md](../LORE-BIBLE.md). Dieses Dokument ist eine Produktionsregel und ein **VORSCHLAG** zur Gestaltung; es kanonisiert keine neue Weltgeschichte. Der langfristige Entwurf steht in [CAMPAIGN-PLAN.md](CAMPAIGN-PLAN.md), der Inhaltsstatus in [CONTENT-STATUS.md](CONTENT-STATUS.md).

## Erzählvertrag

Spieler sollen zuerst eine verständliche lokale Aufgabe erleben, eine Person mit nachvollziehbarem Interesse treffen und eine überschaubare Entscheidung treffen können. Größere Weltfragen wachsen aus beobachteten Folgen. Jede Szene verändert eine Beziehung, einen Wissensstand oder die unmittelbar nächste Handlung. Ein Text, der ausschließlich Hintergrund erklärt, gehört eher in einen freiwilligen Rückblick.

Mystery entsteht durch eine erkennbare Lücke und überprüfbare Beobachtungen. Es entsteht nicht dadurch, dass alle Figuren in Rätseln sprechen. Politischer Konflikt zeigt zwei verständliche Bedürfnisse, beispielsweise Bewahren und Anpassen; er erklärt keine Macht pauschal zum Guten oder Bösen. Verlust muss an einer konkret verstandenen Beziehung hängen. Hoffnung erhält eine sichtbare Handlungsmöglichkeit, ohne den Weltkonflikt aufzulösen.

Der technische Prototyp beweist Bedienung und Zustandswechsel. Er ist keine erste Folge der freigegebenen Hauptgeschichte. Neutrale Testrollen dürfen Entscheidungen kommentieren; solche Texte müssen als Beispiel gekennzeichnet bleiben. Die aktuelle Lore erlaubt noch keine verbindliche Inszenierung von Eiras Biografie, Aussehen oder Rückkehr.

## Quellen und Status

Jeder narrative Datensatz führt stabile ID, Status und Quelle; bei abgeleiteten oder vorgeschlagenen Inhalten zusätzlich die offene Entscheidung. Der Status gilt auch für Übersetzungen. Eine englische Fassung macht einen Vorschlag nicht verbindlicher.

| Status | Im Spielerlebnis |
|---|---|
| KANON | Darf als bestätigte Festlegung erscheinen; Quelle muss die konkrete Aussage tragen. |
| ARBEITSSTAND | Nur mit sichtbarer Arbeitsstandkennzeichnung; nicht als erwiesene historische Wahrheit behandeln. |
| VORSCHLAG | Entwurf oder Beispiel sichtbar kennzeichnen. Keine automatische Veröffentlichung als Hauptgeschichte. |
| ALTENTWURF | Getrennt archivieren/anzeigen; keine Figuren oder Ereignisse in ORAFOLD umbenennen. |
| VERWORFEN/ABGELÖST | Nur als historische Redaktionsevidenz, nicht als aktive Weltregel. |
| OFFEN | Leerstelle erhalten. Kein Dialog darf ihre Antwort als Tatsache erfinden. |

Technische Status wie `prototype` sagen, wie etwas benutzt wird. Sie ersetzen keinen Lorestatus. Für kanonische Namen und mechanische Hinweise gelten die genauen Quellenabschnitte: vier Mächte §5; Kartentypen, Energie/Resonanz, Pfade und Konvergenz §8; Eira §2; Archiv §3; Echos §4. Die letzten drei enthalten hauptsächlich ARBEITSSTAND/OFFEN.

## Dialogregie

Eine Zeile enthält gewöhnlich einen Gedanken und höchstens wenige kurze Sätze. Ein emotionaler Wechsel bekommt einen eigenen Beat. Aufeinanderfolgende Aussagen derselben Figur müssen nicht erneut mit einem langen Namensblock eingeführt werden. Ein kurzer Erzählertext beschreibt Beobachtbares; er bestätigt keine unentschiedene Metaphysik.

Jede sprechende Rolle benötigt ein unmittelbares Ziel, einen Anlass, gerade jetzt zu sprechen, und eine Grenze ihres Wissens. Emotionen sind Darstellungshinweise, keine Behauptung, dass der Spieler die Wahrheit der Figur kennt. Schweigen und eine praktische Bitte können mehr tragen als eine Erklärung der gesamten Welt.

Beispiel einer technischen Testzeile, **VORSCHLAG / kein Weltkanon**: „Soll die Notiz sichtbar bleiben?“ Eine Wahl kann „Aufbewahren“ und „Zunächst zurückstellen“ anbieten. Die Folge zeigt sofort, welche Notiz im Rückblick erscheint. Diese Testentscheidung sagt nichts über Regeln des Archivs aus.

Entscheidungen benennen die beabsichtigte Handlung klar. Unvorhersehbare Überraschungen dürfen aus späterem Kontext entstehen; die UI darf keine versteckte Ablehnung der gewählten Absicht vortäuschen. Wo eine Konsequenz unmittelbar bekannt ist, wird sie knapp angekündigt. Beziehungseffekte bleiben lokal und begrenzt. Zwei Varianten dürfen nach einer kurzen Zusatzszene zusammenlaufen; ihre Flags und Rückblicktexte bewahren die unterschiedliche Erfahrung.

## Wissensmodell und Eira-Schutz

Vier Ebenen bleiben getrennt:

| Ebene | Inhalt | Darf direkt im Codex erscheinen? |
|---|---|---|
| Loregesichert | Eine ausdrücklich bestätigte Aussage samt Quelle | Ja, sofern die Spielerfreischaltung erfüllt ist. |
| Tatsächliches Figurenwissen | Was eine Figur innerhalb eines freigegebenen Szenarios erfahren hat | Nur, wenn sie es glaubwürdig mitteilt oder ein freigegebenes Ereignis es offenlegt. |
| Figurenglaube | Annahme, Gerücht oder Interpretation | Nur als Aussage dieser Figur, mit erhaltener Unsicherheit. |
| Spielerwissen | Tatsächlich erlebte oder freigeschaltete Information | Grundlage des sichtbaren Rückblicks und der Charakteransicht. |

Autorenwissen ist keine fünfte sichtbare Kategorie. Verborgene Daten werden nie allein deshalb angezeigt, weil ein Charakterdatensatz geladen wurde. Ein Flag `information_unlocked` autorisiert nur die jeweilige freigegebene Information; es bestätigt keine Theorie.

Eira erhält einen geschützten Eintrag mit stabiler ID. Offene Felder bleiben offen: kein erfundenes Alter, Porträt, Macht, Angehörige, Motivation, Schuld oder metaphysischer Sonderstatus. Enthüllungsplätze dürfen technisch vorbereitet werden, ohne fertige Texte zu enthalten. Freischaltung eines leeren Platzes darf kein geratenes Standardprofil erzeugen. Ein abstrahiertes Platzhaltersymbol ist ausdrücklich kein Eira-Porträt. Auch ein Autorenvermerk „aus allen Zeitlinien gelöscht“ bleibt nach Bibel §2 ARBEITSSTAND und wird nicht heimlich zum KANON.

## Welt und Mechanik

Die vier bestätigten Namen und Farbidentitäten sind Zwölf Häuser/Kupfer, Stillwacht/Eisblau, Vielgestalt/Jadegrün, Neunte Stunde/Amethyst. Neutral ist eine Karten-Zugehörigkeit, keine fünfte Macht. Gemeinsame Farbverwendung ist kein Beleg einer Figurenzugehörigkeit.

Tutorials können bestätigte Spielbegriffe erklären: Wesen, Impuls, Relikt, fünf Kampfpfade, Energie, Resonanz als strategische Ressource, Ursprungspfad und Konvergenz als Spielziel. Konkrete Zahlen und legal ausführbare Aktionen kommen aus dem aktiven Regelprofil. Ein Dialog erfindet keine neue Pfadphysik, Sonderressource oder zusätzliche Siegbedingung. Eine Veranschaulichung darf ausdrücklich eine Spielübung sein; sie muss kein historisches Weltduell behaupten.

## Präsentation und Zugänglichkeit

Der neue Bereich verwendet dunkle Flächen, ruhige Raumfalten und klaren Kontrast. Schmuck darf die Textbreite und Touchflächen nicht reduzieren. Porträts dienen der Orientierung; Eira bleibt ohne erfundenes Aussehen. Kapitelkarten zeigen kurze Einführung, verfügbaren Zustand und Wiederholbarkeit. Der Rückblick wird aus erlebten Ereignissen aufgebaut, nicht aus einer ungefilterten Volltext-Lorebibliothek.

Auf Hochformat bleibt der Dialog im normalen vertikalen Lesefluss. Lange Übersetzungen und vergrößerte Schrift müssen umbrechen und scrollen können. Entscheidungen besitzen große Trefferflächen und eindeutigen Fokus. Tastaturfortschritt und sichtbare Bedienelemente bieten denselben Weg. Bereits gelesene Szenen dürfen übersprungen werden; ungelesene Inhalte und offene Entscheidungen benötigen einen klaren Fortsetzungspunkt. Verlauf bleibt nachlesbar. Textgeschwindigkeit und reduzierte Bewegung sind Präferenzen, keine Spielfortschrittsbedingungen.

Animationen dürfen Zustandsmutation nicht auslösen: ohne Tween, bei reduzierter Bewegung oder nach Fokuswechsel bleibt dieselbe Szene erreichbar. Audio ist optional. Storyereignisse können Atmosphäre oder Sprachproduktion später auslösen; ein fehlender Audioempfänger führt keinen anderen Manager ein und verhindert keinen Szenenwechsel.

## Redaktionelle Abnahme

Vor narrativer Freigabe jeden neuen Satz gegen die konkrete Bibelstelle prüfen. Fragen: Ist dies bestätigt, eine Figurenaussage, eine Ableitung oder neu vorgeschlagen? Verrät die Zeile Wissen, das weder Sprecher noch Spieler haben? Löst ein Satz versehentlich Eiras Geheimnis oder die Natur der Echos? Werden alte Arvess-Inhalte gleichgesetzt? Bleibt eine verständliche Handlung übrig, wenn der Spieler keinen Codex liest?

Nach Kanonentscheidung zuerst die Lore-Bibel mit Entscheidungsquelle aktualisieren, danach Daten und Übersetzungen angleichen. Ein Retcon bewahrt alte Aussage und Ablösungsgrund. Automatische Validatoren können Status, Quellen, Referenzen und Bedingungen prüfen; sie ersetzen diese semantische Prüfung nicht. Die technische Abnahme und narrative Freigabe werden getrennt berichtet.
