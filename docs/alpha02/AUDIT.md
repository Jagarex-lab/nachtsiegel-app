# ORAFOLD Alpha 0.2 – technischer und spielmechanischer Audit

Basis: `f1d24ba9a15ae7bc74a21cfb674f61899ac4ac7a` (veröffentlichte Alpha 0.1), 10.11.2026. Dieser Branch ist ein **unveröffentlichter UI-Kandidat**. Kein Merge, keine Pages-Auslösung. Kampfkernel, Kartendaten, RNG und Siegbedingungen werden nicht verändert.

## Orientierung und Architektur

Die Alpha ist `scenes/alpha_shell.tscn` mit `scripts/alpha/shell.gd`; `card_view.gd` zeichnet Karten direkt. Legacy-Kernel liegt in `scripts/legacy/battle_engine.gd`, Alpha erbt davon in `scripts/alpha/model.gd`. Das ist eine gemeinsame Engine mit getrennten Profilen, keine neue Engine. `catalog.gd` liest die vorhandenen 55 Karten und vier Starter aus `data/alpha/cards.json`; alle vier Starter haben 30 Karten und bestehen die vorhandene Validierung.100 Legacy-Karten und deren fünf Listen bleiben separat.

Alt: freie Control-Fläche, skalierter logischer Layout-Container, mehrfach pro Aktion neu aufgebaute HBox/VBox-Zeilen; dieselbe Komposition in Hochformat. Sechs Karten und fünf Pfade werden dort nebeneinander auf schmale Spalten gedrückt. Deckfilter waren sechs nebeneinanderliegende Controls, teilweise außerhalb des sichtbaren Bereichs. Starterwahl war hinter Einstellungen versteckt. Nachziehen ist tatsächlich eine regelrelevante Phase; „Aktionen“ und „Karte“ sind dagegen UI-Funktionen, keine weiteren Phasen.

`screen.orientation.lock()` ist kein belastbarer Safari-Wechsel: [MDN Browser Compatibility Data](https://github.com/mdn/browser-compat-data/blob/main/api/ScreenOrientation.json), am 10.11.2026 abgerufen, meldet Safari `version_added:false`; iOS spiegelt Safari. Ein vorhandenes API auf anderen Browsern garantiert ohne passende Fullscreen-/Berechtigungsbedingungen ebenfalls keinen Erfolg. Der Kandidat ruft deshalb keine Orientierungs-Sperre auf. Native Sensororientierung erlaubt beide Richtungen. Der Kampf wird bei sichtbarem Hochformat durch eine Drehaufforderung ersetzt; keine 90°-Canvas-Transformation. Auf Desktop kann das Fenster verbreitert werden. Menüs, Auswahl, Sammlung und Deckwerkstatt werden nach verfügbarer Breite/Höhe komponiert.

Drehung baut nur Ansichten neu auf: Modell, RNG, Befehlsliste, Hand, Auswahl und offene Pflichtentscheidungen bleiben erhalten. Touchereignisse unmittelbar im Drehübergang werden kurz abgefangen. Eine vorhandene Detailansicht wird im Hochformat-Kampf ausgeblendet und danach wieder einpassbar. Ein expliziter Menüausstieg benötigt weiterhin Bestätigung; keine vorgetäuschte dauerhafte Speicherung laufender Partien.

## Getrennte Ursachen der Unschärfe

| Bereich | Beleg/Reproduktion | Erklärung und Dateien | Korrektur / erwartete Wirkung | Messung |
|---|---|---|---|---|
| A Schrift | Alpha bei DPR2/3 oder stark skalierter Control-Fläche; lange Namen schon bei844×390 | `Body.ttf.import`: Bitmap-Rasterisierung (`multichannel_signed_distance_field=false`), während Alpha `layout.scale=density` verwendet. Alte Namen wurden mit begrenzter Breite einzeilig gezeichnet; das ist zusätzlich Abschneiden, keine Bildunschärfe. | Alpha-eigene duplizierte MSDF-Font64 in `style.gd`, keine Änderung der Originalschrift/Archiv-Themes. Namen mit adaptiver zweizeiliger TextParagraph-Formung; große Detailtexte. Suche16CSS. | Alle55 Namen bei schmalen Breiten vollständig geformt; Zeilenbreite/-zahl geprüft. Browser-CSS/Canvas/DPR und Screenshots getrennt protokollieren. |
| B Illustration | Atlas-Ausschnitt in großen Ansichten / Retina | `assets/art/atlas.png`1245×1263 enthält3×3 Felder: **415×421 pro Bild**. Kein individuelles hochauflösendes Original für55 Alpha-Karten. Hash-Verteilung verwendet sieben Platzhalter. | Mipmaps + mipmapfähiger linearer Texturfilter verbessern Verkleinerung. Größere Quellillustrationen bleiben ein eigener Art-Auftrag. Kein erfundenes Upscaling und keine Behauptung, Mipmaps erzeugten Details. | Quelldimensionen mit Pillow; Source-/Display-Pixel-Verhältnis.240CSS beiDPR3 kann die Quelle überschreiten und bleibt begrenzt. |
| C Rahmen/UI | Rechteckiges Debug-Gefühl, kleine gleiche Buttons, skalierte Rasterglyphen | Alpha zeichnete bereits überwiegend Vektorrechtecke; es gibt keinen Beleg für global niedrig aufgelöste Rasterrahmen. | Vektor-Rahmen, unterschiedliche Seltenheitsmarken, Machtsymbol plus Name, konsistente MSDF-Werte. Primäre Zugaktion deutlich, sekundäre Aktionen im Menü. | Bounds,44CSS-Touchziele, Farbpaare≥4.5:1; manuelle Sichtung gerenderter Zustände. |
| D Hintergrund | Breites Hintergrundbild deckt einen hohen Smartphone-Viewport ab | `arena_painted.png`1672×941, KEEP_ASPECT_COVERED: Hochformat erfordert Vergrößerung und starken Zuschnitt. | Dekorative, gedämpfte Kulisse bleibt. Informationsflächen tragen eigene dunkle Untergründe. Kein Hintergrundtext und keine Schärfezusage über die Quellauflösung hinaus. | Bildmaße / Cover-Skalierung getrennt von Schrift und Canvas messen. |
| E gesamter Canvas | DPR, Zoom, Safari-Browserleisten oder Drehung ändern sich | Projekt1280×720 ist Startgröße, Stretch disabled. Web-Policy2 passt die Zeichnungsauflösung an Canvas/DPR an. CSS setzt100vw und visualViewport-Höhe. Es gibt **keinen Beleg**, dass grundsätzlich immer nur1280×720 hochskaliert wurde. Aber Alpha las Hardware-DPR nur beim Start. | Verhältnis tatsächliche Canvas-Pixel zu CSS-Breite bei Layoutänderungen neu bestimmen; Safe Areas weiter in CSS-Pixeln anwenden. Resize/pageshow/visibility aktualisieren die Höhe. Kein pauschales Anheben der Projektauflösung. | `orafoldDisplayMetrics`: Canvas-Pixel, CSS-Größe, DPR, Zoom und verfügbare Lock-API; Godot-Layoutdichte und Screenshotgröße dagegen prüfen. |

Retina bleibt im vorhandenen nativen DPR-Pfad; keine globale `devicePixelRatio`-Manipulation, keine Pixelated-CSS-Schrift, kein blindes Abschalten linearer Bildfilter. Mipmaps kosten beim Atlas ungefähr ein Drittel zusätzlichen Texturspeicher; die Basisebene benötigt unkomprimiert ca.6.3MB. Ein1170×2532-Framebuffer hat allein ca.11.85MB Farbdaten; tatsächlicher Gesamtverbrauch umfasst weitere Puffer/WASM und ist damit nicht gemessen. MSDF64 benötigt Glyphenatlas-Speicher; keine spekulative iPhone-Peak-RAM-Angabe.

Fonts: DejaVu Sans/Serif mit vorhandener Lizenz, Cinzel OFL, siehe `assets/ASSET_MANIFEST.md`. Die verwendeten Bilder sind dort als projektgenerierte KI-Konzeptassets ohne behauptete Exklusivität dokumentiert. Das ist Herkunftsdokumentation, keine neue juristische Freigabe oder exklusive Rechtegarantie. Keine fremden oder neu hochskalierten Illustrationen eingeführt. Platzhalterhinweis bleibt sichtbar.

## Energie, Resonanz, Aktionen – tatsächliche Regeln

Quellen: `scripts/legacy/battle_engine.gd` begin_turn/play/_resolve_summon/_resolve_death/_reaction/burst/recover/tactical_move/fortify und Alpha-Overrides in `scripts/alpha/model.gd`.

**Legacy-Energie:** pro eigenem Beginn neu berechnet:2 Basis, +1 pro erreichtem Resonanzschwellenwert5/10/15, ggf. Startbonus für den Zweitspieler und KI-Bonus auf taktischer Stufe. Die Reaktion tide→veil erzeugt zusätzlich1. Kein genereller harter Energie-Clamp im Legacy-Kernel. Rest wird am Zugende auf0 gesetzt. Beschwörung zahlt den gedruckten Preis; maximal zwei Beschwörungen im Legacy-Zug.

**Alpha-Energie:** eigener Zugzähler1…8, auf8 begrenzt. Kein Resonanzschwellen-Bonus. Die erste Hand enthält5 Karten; der Erstspieler zieht im ersten eigenen Zug keine zusätzliche Karte, der Zweitspieler1. Weitere eigene Züge ziehen1. Kreaturen, Ereignisse und Installationen zahlen Kartenkosten; aktive Relikte1 Energie, einmal pro eigenem Zug. Alpha hat kein Legacy-Zwei-Beschwörungen-Limit. Die geerbte energieerzeugende Machtpaar-Reaktion ist mit normalen Ein-Macht-Decks nicht erreichbar. Die Energiekurve im Builder zeigt echte Kartenkosten.

**Resonanz beider Profile:** entsteht bei unterschiedlichen aufeinanderfolgenden Beschwörungs-Ordenskennungen +2 (auch Wechsel mit neutral), einer Nachbarformation +1, Weben(power+1), Puls(power), Ernte beim Tod(power+1), zwei Reaktionspaaren zusätzlich+1 und in Alpha durch das Resonanzrelikt+1. Maximal15. Bleibt zwischen Zügen erhalten, kein passiver Verfall; die Zugbegleitung `attune` wird zurückgesetzt. Ereignisse/Reliktinstallation sind kein normaler Beschwörungs-Ordenswechsel. Rückholung verbraucht5 und mischt den Ablagestapel deterministisch vor der einzelnen Rücknahme; Pfadmanöver3, Pfadwacht2. Entfesselung benötigt15, verbraucht8, einmal pro eigenem Zug und mindestens eine passende Kreatur. Keine Karte hat einen gedruckten Resonanzpreis.

### Zwölf gerichtete Legacy-Reaktionen

Alle kosten **0 Resonanz** und laufen automatisch nach dem +2-Wechselgewinn vor der Beschwörungsfähigkeit ab. Alpha-Mapping: Häuser→thorn, Stillwacht→tide, Vielgestalt→veil, NeunteStunde→ash. Die zwölf gemischten Machtpaare sind regulär bei genau einer Macht + neutral nicht zusammensetzbar; vorhandener Enginecode ist nicht gleichbedeutend mit normaler Alpha-Erreichbarkeit.

| Paar | Effekt |
|---|---|
| ash→tide |2 geschützter Heldenschaden|
| ash→thorn |+3 Block|
| ash→veil |2 geschützter Heldenschaden|
| tide→ash |+1 Resonanz|
| tide→thorn |+3 Schild, maximal25|
| tide→veil |+1 Energie|
| thorn→ash |+2 Schild|
| thorn→tide |+1 Resonanz|
| thorn→veil |+2 Heilung, maximal Helden-Maximum|
| veil→ash |gegnerische Schwäche mindestens1|
| veil→tide |+2 Block|
| veil→thorn |+2 Schild|

### Vier Entfesselungen

n = eigene passende Kreaturen; zuerst8 Resonanz abziehen, dann Effekt und Siegprüfung. ash/NeunteStunde:4+3n geschützter Heldenschaden. tide/Stillwacht:6+2n Schild bis25. thorn/Häuser:alle eigenen Kreaturen bis3 zur originalen Karten-HP heilen, Held um3+n bisMaximum. veil/Vielgestalt:gegnerische Schwäche2, passende Kreaturen erhalten+2 Angriff. Kein zusätzlicher Energiepreis; offene Strike-/Shift-Auswahl sperrt die Entfesselung in der Originalregel ausdrücklich nicht. UI bildet diese Ausnahme ab.

Block wird vor Schild verbraucht und am nächsten eigenen Beginn gelöscht. Schild bleibt bestehen, maximal25. Ein leerer Gegenpfad bedeutet direkten Heldenangriff. Durchdringender Ankunftsschaden umgeht Heldenschild, nicht Block; Alphakampf-Überlauf ist eigener, weiterhin geschützter Schaden. Diese Unterscheidungen dürfen nicht zur allgemeinen „ignoriert allen Schutz“-Behauptung vereinfacht werden.

## Ressourcenvarianten – Empfehlung

| Variante | Tiefe/Tempo/Verständlichkeit | Einfluss und Aufwand | Mobile / Exploits |
|---|---|---|---|
| A nur Energie |Einfachste Erklärung, direkteres Tempo; verliert langfristige Rücklagenentscheidung|Weben/Puls/Ernte, Relikte, Sonderaktionen und alle Entfesselungskosten müssten neu balanciert werden. Mächte mit Aufbau verlieren Werkzeug.|Weniger UI, aber ungetestete Ersatzkosten können frühe Burst-/Recycle-Schleifen öffnen. Keine Legacy-Parität mehr.|
| B Energie + Resonanz |Kosten pro Zug und gespeicherte Sonderaktionsreserve bleiben eigenständig. Erklärkost höher, strategische Zeitachse bleibt.|Geringster Regel-/Migrationsaufwand. Die unerreichbaren Machtpaar-Reaktionen müssen ehrlich erklärt werden, nicht als Alpha-Kombo verkauft werden.|Ein Wertpaar mit Informationsansicht und kontextuellen Kosten ist handhabbar. Cap15 und Verbrauch8 begrenzen Reserve, Kettengewinn trotzdem testen.|
| C Energie + vereinfachte Kette |Könnte kurzfristige Kombinationen intuitiver machen; verwirft ggf. Reserve über Züge|Erfordert neue Definition von Kettenende, Neutralwechsel, Echo und Entfesselung. Betroffen sind alle vier Mächte, besonders Aufbau/Ernte.|Potentiell gute mobile Anzeigen, aber Farming/Unterbrechungen/Mehrfachtriggers benötigen neue Regeln und Tests.|

**Für Alpha0.2 B beibehalten.** Es ist der einzige sofort risikoarme Weg ohne unbeauftragte Kosten-/Fähigkeitsänderungen. Kein Claim eines fertigen Alleinstellungsmerkmals: Ressourcentrennung ist aus anderen Kartenspielen bekannt; die fünf Pfade und konkret implementierten Zustandsketten sind hier relevant. C kann nach eigener Designfreigabe als kontrolliertes Experiment untersucht werden. A/C wurden hier nicht als angeblich bereits implementierte Spielmodi simuliert.

## Startsystem und Balance – reproduzierbares Screening

`tests/alpha02_balance.gd` + `tools/alpha02_balance_report.py`; Rohdaten und Zusammenfassung in `data/`.16 geordnete Deckpaarungen, je8 Seeds pro Startseite,256 Partien je Bedingung. Bedingungen:offiziell, vorhandene Testoption Konvergenz aus, Gegenprobe Ursprungsschild aus. Gegenproben existieren ausschließlich im Auditskript und ändern keine Produktionsregeln. Mulligan und Zweitspieleroptionen spiegeln die vorhandene KI-Heuristik. Hero-Ursprung startet fest auf2, Gegner zufällig; Hero-KI überspringt Shift während die gegnerische Legacy-Effektregel automatisch verschiebt. Diese Asymmetrien und die feste KI begrenzen Balanceaussagen.

768/768 abgeschlossen,0 Enginefehler,0 zensierte Partien. Offiziell:Erstspieler114/256 Siege=44.53%, Wilson95%-Intervall ca.38.6–50.7%; damit kein nachgewiesener Erstspielervorteil in dieser Stichprobe, **kein Beweis** für ausreichenden menschlichen Ausgleich. ZweiteMöglichkeit umfasst optional einen Pfad- und einen Handkartentausch; die zusätzliche erste Ziehkarte ist separat wirksam.

Konvergenz55/256=21.48%. Median26 Halbzüge gegenüber27 ohne Konvergenz; sechs gepaarte Gewinnerwechsel. Theoretisch erklären ab Halbzug11/12 (sechste Runde), Auflösung frühestens eigener Folgebeginn13/14. Beobachteter frühester Konvergenzsieg:Halbzug16. Gegner hat einen vollständigen Zug; Contest, Tod, Stasis oder Instanzwechsel können den Bindungszustand brechen. Verzögerter tödlicher Heldenschaden wird vor der Konvergenz geprüft. Kein beobachteter illegal früher Sieg.

**Prioritärer Balancebefund:** nicht gespiegelte Machtpaarungen unter dieser KI: Häuser24/96, Stillwacht47/96, Vielgestalt31/96, NeunteStunde90/96 Siege. Das ist ein starkes Prüf-Signal für direkten Schaden/Entfesselungen und KI-Nutzung, kein belastbarer menschlicher Ranglistenwert. Stillwacht erzielt28 seiner63 Siege per Konvergenz, Häuser14/40, Vielgestalt12/47, NeunteStunde1/106. Defensive Kontrolle nutzt diese Siegbedingung sichtbar, dominiert aber nicht insgesamt. Maximale beobachtete Kette10; die separaten Regeltests prüfen zusätzlich10/25/50/100-Ereignisketten. Keine Behauptung, damit seien alle Ketten-Exploits ausgeschlossen.

Ursprungsschild-Gegenprobe:Erstspieler117/256 statt114/256; Konvergenz59 statt55. Kein Beleg, den einmaligen1-Schild-Schutz zu entfernen. Weitere Schritte:mehr AI-Strategien/Seeds, symmetrische Shift-/Ursprungswahl als Testpolitik, echte Spielertests; Kosten/Siegbedingungen nur nach gesonderter Freigabe ändern.

## Prioritäten und Umsetzung

P0:Kampf nicht mehr im Hochformat quetschen; Rotation ohne Zustandsänderung; fixe primäre Touchaktion; echte Auswahl aller vier Starter; vollständige Namensformung. P1:portraitfähige Werkstatt mit Bibliothek/Deckliste, Desktop-Zweispalten, echte Kopien-/Machtvalidierung und gespeicherter Änderung; MSDF-Schrift und tatsächliches DPR-Verhältnis; Ressourcenhilfe und gültige Ziele. P1-Designentscheidung offen:NeunteStunde-Balance sowie künftige Erreichbarkeit der zwölf Legacy-Machtreaktionen. P2:eigene höher aufgelöste Einzelillustrationen, reale iPhone-Safari-/Android-Geräteprüfung, dauerhafte Fortsetzung laufender Partien nach OS-Prozessabbruch.

Die UI verlangt beim Speichern mindestens eine Karte der ausgewählten Macht entsprechend dem Auftrag. Der unveränderte Kernvalidator erlaubt historisch auch reine Neutraldecks; diese Einschränkung wurde nicht heimlich in den Kampfkernel übertragen. Builderregel und Altprofil-Kompatibilität sind damit ausdrücklich getrennt.

## Testnachweis und Grenzen

Endgültiger SHA, CI-Status, Testbuild und Vergleichsbilder stehen im zugehörigen Draft-PR / QA-Bericht. Vorherbilder sind gerenderte Alpha0.1-Zustände, keine Zeichnungen. Nachher-Kampf mit vollem Feld ist ein ausdrücklich beschrifteter Layoutfixture; vollständige Partien werden separat durch reale UI-Eingaben geprüft. Keine Screenshotfixture wird als gewonnene Partie gezählt.

Keine physischen iOS-/Android-Tests durchgeführt. WebKit-Emulation ersetzt nicht iPhone-Safari mit nativer Tastatur, Appwechsel, thermischer Drosselung oder OS-Speicherdruck. Browser-Resize/Pageshow-/Visibility-Tests belegen keinen Schutz gegen Prozessbeendigung. Deck/Profile werden lokal gespeichert; laufende Kämpfe sind weiterhin speicherresident. Keine Serverkonten, Währung, Booster oder Echtgeldfunktionen.
