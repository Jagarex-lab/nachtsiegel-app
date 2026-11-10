# Offline-Illustrationspipeline

Dieses Paket erweitert die Autorenwerkzeuge, nicht die aktive Godot-Kartenbibliothek. Die 550 Einträge unter `data/lore/card-concepts.json` bleiben Vorschläge ohne dadurch bestätigte Spielbarkeit. Separate Bild-/Namensvorschläge liegen in `data/production/art-briefs/`. Der bestehende Laufzeitvalidator `tools/card_system/art.cjs` bleibt unverändert; ein späterer Adapter muss beide Verträge bewusst verbinden.

## Reproduzieren

Python 3.10 oder neuer genügt für Briefs und Promptexport. Inventarprüfung und die Tests benötigen Pillow; die hier getestete Version ist **13.0.0**. Es gibt keinen Netzwerkaufruf, KI-Aufruf, kostenpflichtigen Dienst, Build oder Deployment in diesem Werkzeug.

```sh
python3 -m unittest discover -s tests/production -p 'test_art_pipeline.py' -v
python3 tools/production/art_pipeline.py validate
python3 tools/production/art_pipeline.py prompts --out work/production/prompts.json
python3 tools/production/art_pipeline.py report --out work/production/art-report.json
python3 tools/production/art_pipeline.py validate --release-ready
```

Der letzte Befehl schlägt erwartungsgemäß fehl, solange nicht alle 550 **individuellen** Illustrationen als `final` geprüft sind. Diese technische Illustrationsabnahme ersetzt weder Gameplay-Abnahme noch Veröffentlichung. Zum Wiederholen eines Exports auf demselben Pfad ist `--overwrite` ausdrücklich erforderlich. Ohne `--out` erscheint JSON auf stdout. Pfade können für isolierte Tests über `--root`, `--source`, `--briefs` und `--manifest` gesetzt werden. Ein explizit angegebenes fehlendes Manifest ist ein Fehler; ein standardmäßig noch nicht vorhandenes Manifest bedeutet 550 fehlende Bilder.

## Briefvertrag

Die fünf Dateien `houses.json`, `stillwatch.json`, `morph.json`, `ninth.json`, `neutral.json` enthalten zusammen exakt 550 Objekte:

```json
{
  "card_id": "ZH-001",
  "source_name": "Kupfer-Hüter",
  "proposed_name": "Ein eigenständiger Namensvorschlag",
  "lore_status": "VORSCHLAG",
  "subject": "Konkrete Figur, Anatomie oder Gegenstand.",
  "action": "Eine klar sichtbare Handlung im Bild.",
  "setting": "Ein konkreter Hintergrund ohne neue Weltenthüllung.",
  "composition": "Eine im kleinen Bildfenster lesbare Anordnung.",
  "distinctive_detail": "Ein für dieses Motiv spezifisches visuelles Detail.",
  "avoid": ["Motivspezifische Fehler vermeiden."]
}
```

Die Prüfung verlangt vollständige bijektive Konzept-ID-Zuordnung, unveränderte Quellnamen, einzigartige Namensvorschläge, mindestens 20 Zeichen je Szenenfeld, keine exakten Szenenkopien trotz umbenannter Karte und unverändert `VORSCHLAG`. Das sind maschinelle Mindestprüfungen, keine Behauptung redaktioneller Endabnahme. Nahezu identische Bildideen müssen weiterhin visuell/redaktionell erkannt werden. Der Promptexport übernimmt Typ, Arten und Machtpalette aus der Quelle, ergänzt gemeinsame Stil-/Negativvorgaben und bindet den **SHA-256 der vollständigen Quelldatei** ein. Ändert sich der Katalog, muss die Zuordnung neu geprüft werden.

Jeder exportierte Prompt und jedes vorhandene Bild bindet zusätzlich den **vollständigen Einzelbrief** über `brief_sha256`. Die exakte Formel lautet `hashlib.sha256(json.dumps(brief, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode('utf-8')).hexdigest()`, ohne abschließenden Zeilenumbruch. JSON-Schlüsselreihenfolge und Dateiformatierung ändern diesen Digest nicht; Änderungen an vorgeschlagenem Namen, Szene, Negativvorgaben oder weiteren Brieffeldern schon. Ein veralteter oder fehlender Digest macht die bestehende Zuordnung bei `generated`, `reviewed` und `final` ungültig. Nach Briefänderungen muss das Bild erneut gegen den neuen Brief geprüft und gegebenenfalls ersetzt werden; den Hash bloß neu einzutragen ist keine neue Bildprüfung.

## Assetinventar und Herkunft

`data/production/art-assets.json` kann ein Teilinventar enthalten; nicht eingetragene Konzepte werden als `missing` gezählt. Jede existierende Illustration benötigt tatsächlich vorhandene Datei, übereinstimmenden SHA-256, vollständig dekodierbare Pixel, korrekte Maße sowie dokumentierte Herkunft. Minimalbeispiel für ein **generiertes, noch nicht fertig abgenommenes** Einzelbild:

```json
{
  "schema_version": 1,
  "source_sha256": "SHA256 von data/lore/card-concepts.json",
  "entries": [
    {
      "card_id": "ZH-001",
      "status": "generated",
      "asset_id": "orafold-zh-001",
      "alternative_text": "Konkrete deutsche Beschreibung der tatsächlich sichtbaren Illustration.",
      "edits": [],
      "asset_path": "assets/production/illustrations/ZH-001.png",
      "sha256": "SHA256 der tatsächlichen Bilddatei",
      "brief_sha256": "SHA256 des kanonisch serialisierten Einzelbriefs",
      "width": 1344,
      "height": 1000,
      "provenance": {
        "creator_or_generator": "Tatsächlicher Urheber oder Generator",
        "created_on": "2026-11-10",
        "source_or_prompt": "Vollständiger Prompt oder konkret nachvollziehbare Quelldatei",
        "reference_sources": [],
        "commercial_usage_basis": "Tatsächlich belegte Grundlage; ungeprüft ausdrücklich benennen"
      },
      "review": {
        "visual": "pending",
        "lore": "pending",
        "rights": "pending"
      }
    }
  ]
}
```

Die vier Status haben unterschiedliche Bedeutung:

| Status | Beleg |
|---|---|
| `missing` | Kein individuelles Bild. Eintrag enthält ausschließlich `card_id` und `status`. |
| `generated` | Datei vorhanden und technisch geprüft; Bild/Lore/Rechte können noch offen sein. |
| `reviewed` | Bild und Lore jeweils `passed`, mit `reviewer` und `note`; Rechte können offen bleiben. |
| `final` | Mindestens 1344 × 1000 echte dekodierte Pixel; Bild, Lore und Rechte jeweils `passed`, Prüfer und begründende Notiz vorhanden. |

Ein eingetragener Prüfer ist eine dokumentierte Erklärung, kein automatisch bewiesener Rechteerwerb. Das Tool erfindet keine kommerzielle Freigabe. Dasselbe gilt für eine belegte Generierung: Sie ist von fertiger Illustration und Nutzungsfreigabe zu unterscheiden.

Jeder Eintrag außer `missing` benötigt die stabile `asset_id` nach dem Muster `orafold-` plus kleingeschriebene Konzept-ID, einen nichtleeren `alternative_text` zum tatsächlich sichtbaren Motiv und `edits` als Bearbeitungsliste. Ein leeres Array kennzeichnet ein unverändertes Original. Bei Beschnitt, Retusche, Skalierung oder Farbänderung sind die tatsächlich ausgeführten Schritte zu dokumentieren; die ursprüngliche Datei und ihre Herkunft sollen nachvollziehbar bleiben.

Akzeptiert werden PNG, JPEG und WebP unter `assets/`, mindestens 672 × 500 Pixel und maximal 32 MiB. Die kleinere Mindestauflösung gilt für `generated` und `reviewed`; **`final` verlangt mindestens 1344 × 1000 echte dekodierte Pixel** entsprechend dem Art-Guide. Ein Metadateneintrag höherer Maße genügt nicht. Vor dem vollständigen Dekodieren gilt zusätzlich ein Limit von 8192 Pixeln pro Achse beziehungsweise 32 Megapixeln. Ein klarer Fokus innerhalb der mittleren 70 Prozent und ausreichender Beschnittspielraum für das 672 × 500-Bildfenster bleiben erforderlich. Der **Kartenmaster 756 × 1056** bleibt eine getrennte Godot-Komposition. Keine Kartenrahmen, Texte, Kosten oder Spielwerte in das Bild einbacken.

Pfadtraversal, absolute Pfade, Symlinks, unbekannte IDs, doppelte Karten, identische Dateihashes auf mehreren Karten, als Original kopierter Konzeptatlas, veralteter Quell-/Briefhash, unpassende Maße, falsche Dateiendungen, beschädigte Bilder und unvollständige Herkunft führen zu Fehlercode 2. Unterschiedlich kodierte Kopien oder sehr ähnliche Motive werden dadurch nicht zuverlässig erkannt: Ein späterer Kontaktbogen-/Ähnlichkeitsreview bleibt erforderlich. Vorhandene Alpha-/Legacy-/Atlasassets werden weder umgebunden noch entfernt.

## Grenzen und Integration

Dieses Werkzeug installiert keine Bilder, verändert keine Karten-IDs und kennt keine Engine-Trigger. Die Dateiablage unter `assets/production/illustrations/` ist ein Produktionsbestand, keine automatische Laufzeitaktivierung. `assets/production/.gdignore` und `data/production/.gdignore` halten die Autorenbestände aus Godots `all_resources`-Exporten heraus. Diese Marker bei Erweiterungen erhalten; eine spätere aktive Bildübernahme benötigt bewusst gewählte Laufzeitdateien und Importoptionen. Ein zukünftiger Integrations-PR muss nach Engine-Integration die endgültigen IDs, Kartenfähigkeit, Bildzuordnung, Ladestrategie, Beschnitte, Speicherverbrauch und Mobilqualität prüfen. Vor der ersten öffentlichen Veröffentlichung sind sämtliche Abnahmekriterien des Masterauftrags separat nachzuweisen.

## Native Autorenansicht

```sh
mkdir -p work/xdg/data work/xdg/config work/xdg/cache
export XDG_DATA_HOME="$PWD/work/xdg/data"
export XDG_CONFIG_HOME="$PWD/work/xdg/config"
export XDG_CACHE_HOME="$PWD/work/xdg/cache"
export LP_NUM_THREADS=2
python3 tools/production/art_pipeline.py validate
# Grafische Sitzung oder Xvfb erforderlich; kein Dummy-/Headless-Renderer.
godot --path . --audio-driver Dummy --rendering-method gl_compatibility --script tools/production/preview_art.gd
```

Das Werkzeug liest die ignorierten Original-PNGs direkt über `Image.load_from_file` und verwendet eine isolierte Unterklasse des vorhandenen Kartenrenderers. Die normale Kartenbibliothek bleibt unverändert. Es erzeugt Einzelansichten, Rückseite, Kontaktbogen und `report.json` unter `work/production/previews/`. Jede Vorderseite zeigt deutlich **„BILDVORSCHLAG – keine Spieldefinition. Werte sind Platzhalter.“** Die angezeigten Nullkosten und Kampfwerte sind ausschließlich temporäre Renderer-Eingaben. Sie dürfen nicht in Spielkarten übersetzt oder als Balancewerte verstanden werden.

Geprüft werden tatsächliche Pixel statt Atlasfallback, Namens-/Textpassung, 756×1056-Abmessungen, gemeinsame Außenkontur und identische Rückseite. Diese Ansicht ist kein Kampftest und keine mobile Geräteabnahme. Die Produktions-CI prüft Daten und Pixeldateien; der grafische Autorenlauf wird gesondert ausgeführt und protokolliert.
