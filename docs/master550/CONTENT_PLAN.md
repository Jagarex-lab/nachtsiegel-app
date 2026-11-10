# ORAFOLD – Karteninhalt und Datenvertrag für den 550-Karten-Auftrag

Stand: 10. November 2026. Dies ist ein überprüfbarer Ausbauplan mit einer implementierten, isolierten Datengrundlage. **Es sind noch keine 550 Karten fertiggestellt.** Die produktive Alpha-Bibliothek wird durch diese Dateien nicht ersetzt.

## Tatsächlicher Inhalt und Widersprüche

`data/alpha/cards.json` enthält 55 Karten: 37 `creature`, 12 `event`, 6 `relic`; 15 neutrale und je 10 Karten der vier Mächte. Seltenheiten: 20 gewöhnliche, 31 seltene, 4 legendäre, **keine epische Karte**. Vier vorhandene Starterlisten enthalten jeweils 30 Einträge. Die 100 Originalkreaturen in `data/legacy/` und sieben Prototypkarten bleiben getrennte Referenz- beziehungsweise Archivpools; sie ergeben nicht zusammen 162 unterschiedliche ORAFOLD-Karten.

Die 55 Alpha-Karten besitzen nur 43 unterschiedliche Signaturen aus Typ, Energiekosten, Angriff, Leben, Effekt und Effektstärke. Alle vier bisherigen legendären Wesen sind `pulse`, 6 Energie, 5 Angriff und 8 Leben. Weitere Gleichheiten bestehen etwa bei Pfadkundigem/Kausaljäger und Festem Bild/Konservierung. Das ist ein Befund der aktuellen Bibliothek, keine ausreichende Grundlage, ihre Schablonen lediglich auf 550 Namen zu verlängern. Der neue Vertrag erkennt innerhalb derselben Macht auch rein umbenannte mechanische Kopien; Vergleiche zwischen Mächten müssen zusätzlich redaktionell erfolgen.

Wesensarten, gedruckte Resonanzkosten, generische Fähigkeitenlisten und ein vollständiger 16-Auslöser-Dispatcher fehlen im bisherigen aktiven Katalog. Der vorhandene Alpha-Kernel unterstützt spezifische Kreaturenfähigkeiten, Impulse und aktivierte Relikte. Ein Registryeintrag belegt keine beliebige neue Kombination dieser Effekte.

Die umfangreiche Bibel unter `docs/creative/` ist der historische GEGENMASS-/Arvess-Entwurf mit Schmelzkonvent, Pegelbund, Pfropfkammern und Namenkolleg. Sie untersagt echte Wiederbelebung und Änderung der Vergangenheit. Sie ist **keine bereits existierende vollständige ORAFOLD-Bibel**. Konkrete ORAFOLD-Identitäten liegen gegenwärtig in `data/alpha/cards.json`, Feld `identities`, sowie `docs/alpha/RULES.md` vor. Neue Karten verwenden diese vier Machtachsen. Neue Lore-Metadaten erhalten ausdrücklich den Geltungsbereich ORAFOLD; historische Kreativentwürfe werden weder umgeschrieben noch unbemerkt als Kanon übernommen. Insbesondere bedeutet regeltechnische Rückholung nicht automatisch Wiederbelebung einer erzählerisch toten Person.

## Zielverteilung für die beauftragte Autorenarbeit

Die folgende Arbeitsverteilung verbindet die Mehrheit der Wesen mit unterscheidbaren Machtprofilen. Sie ist ein Entwurfsbudget für die ausdrücklich beauftragte Erweiterung, kein bereits existierender Katalog.

| Macht | Wesen | Impulse | Relikte | Gesamt |
|---|---:|---:|---:|---:|
| Zwölf Häuser | 74 | 27 | 9 | 110 |
| Stillwacht | 70 | 28 | 12 | 110 |
| Vielgestalt | 80 | 23 | 7 | 110 |
| Neunte Stunde | 66 | 34 | 10 | 110 |
| Neutral | 76 | 28 | 6 | 110 |
| Gesamt | **366** | **140** | **44** | **550** |

66,5 Prozent Wesen erhalten die Bedeutung der fünf Pfade. Stillwacht erhält mehr dauerhafte Aufbauwerkzeuge; Neunte Stunde mehr kombinierbare Impulse; Vielgestalt mehr Wesen als bewegliche Synergieträger. Nur 8 Prozent Relikte vermeiden, dass die Ein-Relikt-Regel viele unspielbare Handkarten erzeugt. Abweichungen werden vor der betreffenden Autorencharge begründet, statt nachträglich stillschweigend summiert.

Je Macht sind zunächst 48 gewöhnliche, 36 seltene, 18 epische und 8 legendäre Karten vorgesehen: insgesamt 240/180/90/40. Seltenheit ist kein Ersatz für eine mechanische Rolle. Gewöhnliche Karten tragen günstige, zuverlässige Basisaktionen und mindestens eine strategisch relevante Rolle; sie werden nicht pauschal durch seltene Karten desselben Kostenpunkts verdrängt.

Vorgeschlagene Wesen-Energiekurve für insgesamt 366 Wesen: Kosten 1–10 mit 38/62/66/60/45/34/25/18/12/6 Karten. **Konflikt:** Das aktuelle Alpha-Energielimit beträgt 8. Kosten 9 und 10 dürfen nicht als spielbar freigegeben werden, bevor ein dokumentierter Ressourcenvergleich und eine getestete Entscheidung vorliegen. Das Kostenschema ist keine heimliche Erhöhung der produktiven Energie. Der Legacy-Pin bleibt unberührt.

28 bewusste Budgetausnahmen wären 5,09 Prozent des Pools. Ihre erhöhte Stärke benötigt einzeln eine überprüfbare Bedingung, einen Nachteil und eine praktisch verfügbare Gegenstrategie. Die Ausnahmen werden in Balance-Metadaten aufgelistet; nicht alle legendären Karten gelten automatisch als Ausnahme. Angriff und Leben werden wegen direkter leerer Gegenpfad-Angriffe getrennt simuliert, bevor Gewichte festgelegt werden.

## Archetypen und Unterscheidbarkeit

Jede Karte erhält bei der eigentlichen Autorenarbeit einen primären Archetyp, eine taktische Rolle, eine konkrete Synergie und eine Gegenstrategie. Die vier vorhandenen Archetypnamen je Macht sind bisher Identitätsachsen, keine 16 fertig entwickelten Decks.

| Macht | Ausbauachsen | Erforderliche Gegenmittel |
|---|---|---|
| Zwölf Häuser | Geordnete Wiederkehr; Erinnerung an abgelegte Karten; Wiederaufbau beschädigter Pfade; Schutz durch begrenzten Verzicht | Rückholung besitzt Quelle, neue Instanz und klares Timing; keine kostenlose Endlosschleife aus Tod und Rückkehr |
| Stillwacht | Block zeitlich planen; dauerhaften Schild aufbauen; einzelne Pfade stilllegen; Konvergenz vorbereiten | Angriffsgelegenheiten und Dauer müssen sichtbar sein; Kontrolle ist begrenzt und ersetzt keinen gesamten gegnerischen Zug |
| Vielgestalt | Eigene Positionen wechseln; gleichwertige Doppelarten kombinieren; Nachbarschaften aufbauen; auf konkrete Bedrohungen reagieren | Bewegung bindet gültige freie Ziele; Werte können nicht durch unbegrenztes Hin-und-her-Wandern wachsen |
| Neunte Stunde | Schaden verzögern und umleiten; Impulse verketten; Resonanzfenster nutzen; Vorhersage mit begrenzter Information | Geplante Wirkung bleibt sichtbar und beantwortbar; Reaktionen erhalten geprüfte Auslöser und Kosten, keine unendliche Kette |
| Neutral | Verlässliche Kurvenkarten; verschiedene Arten verbinden; gezielte Ressourcenhilfe; einfache Antworten auf Relikte und einzelne Pfade | Darf Machtidentität unterstützen, aber nicht sämtliche exklusiven Kombinationen günstiger ersetzen |

Zusammen müssen tatsächlich baubare Testdecks mindestens Aggro, Kontrolle, Resonanz, Schild, Wiederkehr, Positionswechsel, Impulskombinationen, Relikte, Konvergenz und Artensynergien abdecken. Die vorhandenen vier Starterlisten werden referenziert und fortentwickelt; es entsteht keine zweite unsynchronisierte Starterquelle.

Ein neuer Name oder andere Zahlen allein rechtfertigen keine neue Karte. Pro Autorencharge von zehn bis zwanzig Karten werden insbesondere Kombinationen aus Auslöser, Zielbindung, Bedingung, Kosten, Zeitpunkt und Gegenmittel geprüft. Mechanische Fingerprints erkennen exakte Kopien; eine zweite, zahlenunabhängige Effektgraph-Prüfung und redaktionelle Prüfung sind vor einem großen Katalog noch zu ergänzen. Es gibt keinen Zufallsgenerator, der einen verfügbaren Effekt mit 550 austauschbaren Namen als abgeschlossene Entwicklung ausgibt.

`tools/card_system/diagnose.cjs` meldet die zehn vorhandenen Duplikatgruppen mit insgesamt 43 unterschiedlichen Kosten-/Werte-/Effektsignaturen bei 55 Alpha-Karten als **Warnung**, ohne vorhandene Karten oder Werte zu ändern. Unterschiedliche Werte gelten bei dieser exakten Prüfung nicht fälschlich als Duplikat. Machtzugehörigkeit ist für diesen Vergleich bewusst ausgenommen; die Ausgabe behauptet deshalb keine vollständige Gleichheit aller Reaktions- und Synergieinteraktionen. Die normale Katalogprüfung und die Diagnose erzwingen eindeutige Anzeigenamen auch über Machtpools hinweg. Dieselbe stabile ID in Alpha und ihrer V2-Ansicht bleibt eine legale Mehrfachreferenz, keine zweite Karte.

## Implementierter V2-Vertrag

Dateien:

- `data/card_system/registry.json`: genau drei stabile Haupttyp-IDs `creature`/`event`/`relic`, angezeigt als Wesen/Impuls/Relikt; zwölf Arten, zwölf Kategorien und sechzehn Auslöser. 29 vorhandene spezifische Effektpfade werden als Referenzen erfasst; `summon` ist ausdrücklich noch nicht implementiert.
- `data/card_system/schema.json`: portables JSON Schema, aus derselben Registry erzeugt.
- `data/card_system/pilot.json`: acht bewusst ausgewählte bestehende Karten mit unveränderten IDs, Kosten und Werten, als neue strukturierte Ansicht. Keine Einbindung in den produktiven Katalog. Artenzuordnungen dieser Ansicht sind ausdrücklich neue redaktionelle Vorschläge.
- `data/card_system/glossary.de.json`: zentrale Terminologie und Grenzen der bestehenden Mechanik.
- `data/card_system/illustration_manifest.json`: reproduzierbares Inventar der acht tatsächlich vorhandenen Pilotzuordnungen. Es enthält acht geteilte Konzeptverweise und acht fehlende individuelle Originale; die geplanten 550 Karten werden nur als Zielzahl geführt, ohne leere zukünftige Kartenzeilen.
- `tools/card_system/contract.cjs`: strikte Prüfung, deutscher Textgenerator, Originaldaten-Abgleich, gleichwertige Artenabfrage und Kopienprüfung. Keine Kampfengine.

Ein V2-Wesen enthält `species` mit ein oder zwei unterschiedlichen IDs sowie `attack` und `health`. Impulse und Relikte dürfen diese drei Felder **auch nicht mit Nullwerten** enthalten. Anzeigename und stabile ID sind unabhängig. Ein Effekt besitzt `mode`, gegebenenfalls `trigger`, `effect`, `target`, streng geprüfte `params` und `limit`; aktivierte Fähigkeiten besitzen zusätzlich explizite Aktivierungskosten. Unbekannte Felder, Fähigkeiten, Parameter, Ziele und nicht zum Effekt passende Auslöser werden abgewiesen.

Die zwölf Arten heißen `human` Menschen, `beast` Bestien, `spirit` Geister, `construct` Konstrukte, `plant` Pflanzen, `amalgam` Amalgame, `morphid` Morphiden, `paradox` Paradoxe, `revenant` Wiedergänger, `elemental` Elementare, `devourer` Zehrer und `mechanoid` Mechanoide. Die verbindlichen Definitionen stehen in der Registry. Konstrukte und Mechanoide unterscheiden sich nach dem vorherrschenden mechanischen Antrieb; eine sinnvolle Doppelzuordnung bleibt möglich. Eine Art ist keine Berufsbezeichnung. Eine Abfrage auf Menschen und Konstrukte trifft einen Menschen/Konstrukt-Doppeltyp **einmal**, sofern der Effekt nicht ausdrücklich je passender Art zählt.

Deutscher Regeltext entsteht aus Registryvorlage und geprüften Parametern. Beispiel: `Beim Beschwören: Dein Held erhält 3 Block bis zu deinem nächsten Zugbeginn.` Manuell veränderte Zahlen oder nicht generierter Text scheitern an der Validierung. Ausspielen und Beschwören bleiben getrennte Auslöser; Aktivierung und Dauerhaftigkeit sind eigene Modi. Lore steht getrennt vom Regeltext.

`reference_implemented=true` bezeichnet einen bereits existierenden spezifischen Effekt im angegebenen Quelldateipfad. **`implemented=false`, `runtime_status=adapter_required` und `runtime_playable=false` bleiben für diese isolierte Datengrundlage ausdrücklich gesetzt.** Daraus folgt keine automatische Unterstützung beliebiger neuer Auslöser. Die separate native Adapterarbeit muss Ausführung und genaue Zustandsübergänge zusätzlich testen. Nicht implementierte Registryeinträge bestehen die normale Freigabeprüfung nicht; ein ausdrücklich gewählter Entwurfsmodus macht sie weiterhin nicht spielbar.

Die veraltete Tooltipbehauptung über `pierce` wird im neuen Glossar nicht übernommen: Der tatsächliche Beschwörungsschaden umgeht **Block und Schild**; tödlicher Angriffsüberschuss durchläuft dagegen die normale Schutzpipeline. Dies ist eine Textkorrektur nach `scripts/legacy/battle_engine.gd`, keine Regeländerung.

Grenzen dieses ersten Vertrags: maximal 16 Fähigkeitsdefinitionen je Karte, Angriff 0–30, Leben 1–40 und Effektparameter mit jeweils dokumentierten sicheren Bereichen. Diese technischen Eingabegrenzen sind kein bewiesenes Balancingmodell. Eine spätere Erweiterung braucht zusätzliche Ausführungstests; Datenannahme allein ist keine Spielbarkeitsfreigabe. Langkettenschutz bleibt Aufgabe des Kernels.

## Illustrations- und Kartenpipeline

Der vorhandene Atlas `assets/art/atlas.png` enthält neun Konzeptmotive; die Alpha-Karten nutzen sieben davon über einen ID-Hash wieder. Eine Zelle hat etwa 415 × 421 Pixel. Die 55 Alpha-Karten besitzen deshalb weder 55 noch 550 eigene fertige Illustrationen. `assets/ASSET_MANIFEST.md` dokumentiert OpenAI-erzeugte Konzeptbilder, prozedurale Eigenformen und Schriftlizenzen. Daraus werden weder exklusive Bildrechte noch abgeschlossene kommerzielle Prüfung behauptet.

Für jede neue Illustration wird vor Integration ein Manifestdatensatz geführt: stabile Asset-ID, Karten-ID, Urheber oder Generator/Modell und Datum, Prompt beziehungsweise Herkunftsnachweis, Referenzquellen und Nutzungsrecht, Originalabmessungen, Hash, Bearbeitungen, Freigabestatus und Alternativtext. Status `missing`, `shared_concept`, `concept` und `final` bleiben unterscheidbar. Fehlende Einzelbilder verhindern technische Kartenpartien nicht; der sichtbare Konzeptstatus verhindert eine falsche Fertigmeldung.

`node tools/card_system/assets.cjs` erzeugt das aktuelle Manifest ausschließlich aus den acht wirklichen Pilotkarten und der vorhandenen PNG-Datei. Es liest Abmessungen und SHA256 aus dem echten Atlas, prüft die 3×3-Aufteilung, referenziert die Herkunftsdatei und erfasst fehlende individuelle Originale ausdrücklich. Es erzeugt keine Bilder, keine 550 leeren Karten und keine behaupteten Nutzungsfreigaben. Eine künftig vorhandene Originaldatei gilt zunächst als `unreviewed`; erst eine gesonderte Provenienz- und Sichtprüfung kann sie freigeben. `--check` erkennt einen veralteten Atlas-Hash oder geänderte Pilotzuordnungen.

Neue Illustration und UI bleiben getrennt: keine eingebrannten Namen, Kosten, Angriffswerte oder Fähigkeiten. Das digitale Kartenmaster beträgt 756 × 1056 Pixel mit identischer Außenkontur. Illustrationsmaster werden mindestens für das tatsächliche Bildfenster in dieser Größe erstellt; Retina-Kosten und Texturkompression werden auf Mobilgeräten gemessen. Ein hochskalierter Altatlas gilt nicht als neu erzeugtes hochauflösendes Original. Produktionsderivate verwenden explizite Import-/Mipmapeinstellungen und bleiben aus dem ursprünglichen Master reproduzierbar.

Der aktuelle Alpha-Kartenrenderer ist eine kompakte Rechteckkomponente mit Textleisten und Konzeptatlas. Ein vorhandener vollständiger asymmetrischer 756×1056-Diagonalrahmen ist im aktiven Renderer nicht belegt. Die neue isolierte Kartenkomponente setzt die nun verbindliche Raumfalten-/Diagonalrichtung um. Machtfarbe und Symbol bleiben unabhängig von Seltenheitsmaterialien; alle legendären Details bleiben innerhalb derselben Kontur. Die einheitliche Rückseite erhält weder Macht- noch Seltenheitsinformation. Vollständige Einzelillustrationen sind ein gesonderter Produktionsschritt, keine Voraussetzung, diesen technischen Rahmen korrekt zu testen.

## Prüfschritte und nächster Inhaltsschritt

Reproduzierbar ohne zusätzliche Node-Abhängigkeit:

```sh
node tools/card_system/schema.cjs --check
node tools/card_system/assets.cjs --check
node tools/card_system/validate.cjs
node tools/card_system/diagnose.cjs
node --test tests/card_system/contract.test.cjs
```

Der ergänzte Lauf besteht mit **24 Node-Tests**, acht valide und gegen die Originalwerte geprüften Pilotdatensätzen, null unbekannten Effekten und ausdrücklich **null als V2-Laufzeitspielbarkeit gezählten Karten**. Alle ursprünglichen 20 Vertragsprüfungen bleiben enthalten. Hinzu kommen reale Assetinventur, Reproduzierbarkeit, Signaturdiagnose und poolübergreifende Namensprüfung. Das heißt nicht, dass die zugehörigen acht bisherigen Alpha-Karten unspielbar wären; sie sind vorhandene Source-Bindings und bleiben in der alten aktiven Bibliothek spielbar. Datenprüfungen ersetzen keine Effekt-Differentialtests oder Geräteprüfungen. `node tools/card_system/validate.cjs --complete` verlangt tatsächlich 110 Karten je Macht und schlägt beim Pilotdatensatz erwartungsgemäß fehl.

Nächste unabhängige Pakete: (1) native Ausführung dieser acht konkreten Bindings mit vollständigen Zustandsvergleichen; (2) Dispatcher und Ereignisvertrag für die tatsächlich implementierten Auslöser, einschließlich Ausspielen versus Effektbeschwörung; (3) Ressourcenkandidaten und Energie-9/10-Konflikt prüfen; (4) kuratierte zehn- bis zwanzigteilige Autorenchargen mit Karten-, Interaktions-, Deck- und Simulationsabnahme. Erst danach wird die aktive Sammlung schrittweise erweitert. Ein Abschlussbericht muss Datenvalidität, native Spielbarkeit, automatische Spielabdeckung und endgültige Illustration getrennt zählen.
