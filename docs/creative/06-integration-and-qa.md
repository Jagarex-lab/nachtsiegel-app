# A6 – Integration, Freigabegrenzen und Qualitätssicherung

## Implementierter Umfang

Die Lieferung bereitet Rebranding und lokalisierte Storytexte technisch vor. Sie implementiert **keine Kampagne, keine Boss-KI, keine Intro-Wiedergabe und keinen vollständigen englischen UI-Modus**. Diese Grenzen sind im Datenmodell und in den Dokumenten markiert. Die bestehende Spieloberfläche bleibt deutsch und zeigt NACHTSIEGEL an.

### Zentrale Markenidentität

`data/brand/identity.json` ist die zentrale Quelle für den Anzeigenamen und die Build-Metadaten. `scripts/brand_identity.gd` liest sie in Godot. Der Arenatitel, die Querformatmeldung, der Fenstertitel sowie Browser-Titel und Canvas-Beschriftung verwenden diese Quelle. Die HTML-Schablone nutzt zusätzlich Godots Projektplatzhalter beim Export.

- `legacy_product_name`: NACHTSIEGEL, weiterhin aktiv.
- `approved_product_name`: `null`.
- `approval_reference`: `null`; keine Freigabe erfunden.
- `preview`: markierte DE-/EN-Arbeitstitel, getrennt vom Auslieferungsnamen.
- `application_id`: bestehende Android-ID, unverändert.

`python3 tools/sync_brand.py --check` prüft Projektname, Projektbeschreibung, Android-Anzeigename und Paketkennung. Ohne `--check` synchronisiert das Werkzeug diese generierten Metadaten aus der zentralen Quelle. Es wählt niemals selbst einen Kandidaten aus. Ein neuer Produktname ohne nichtleeren Freigabeverweis wird abgewiesen. Der Verweis ist eine dokumentarische Sicherung, keine automatische Echtheitsprüfung einer Auftraggeberfreigabe.

Godot-Verwendung:

```gdscript
const Brand = preload("res://scripts/brand_identity.gd")
var release_title = Brand.display_name()  # NACHTSIEGEL
var draft_title = Brand.preview_name("en")  # explicitly WORKING TITLE
```

Die Vorschau ist eine technische API für spätere Entwurfswerkzeuge, kein neuer öffentlicher Produktmodus. Aktuell wird kein neuer Markenname in Menü, Kartentitel, App-Paket oder URL übernommen.

### Strukturierte, lokalisierbare Lore

`data/narrative/content.json` enthält Version, Entwurfsstatus und stabile IDs. Texte stehen ausschließlich unter `data/narrative/locales/de.json` und `en.json`; Metadaten wie bisherige Bindungsnamen dienen dem Abgleich und sind keine Lokalisierungsquelle.

- **74 Entitäten**, gegliedert in Welt, Zeitlinie, Pfade, Fraktionen, Orte, Figuren, Karten, Intro, Kapitel, Kampagne, Boss, Geheimnisse und Folgehandlungen.
- **275 Schlüssel pro Sprache**, identische Schlüsselmenge, keine leeren Übersetzungen.
- Die Daten nennen `status: creative_draft` und `runtime_enabled: false`.
- Die ersten sieben Karten referenzieren unveränderte Pool-Indizes. Die übrigen 13 haben `concept_only` und keine Kosten, Angriffe, Lebenswerte oder Effekte.
- Fraktions-, Orts-, Figuren- und Kapitelverweise verwenden IDs, keine übersetzten Namen.
- Die fünf Pfade behalten ihre bestehenden Indizes 0–4. Namen sind vorerst redaktionelle Bedeutung, keine neuen Pfadfähigkeiten.
- Bossdaten benennen das bestehende Duell und den bisherigen Gegnerpool 0–5; keine neue Fraktionsdeckregel.
- Geheimnisse haben explizite Enthüllungskapitel und `writers_only_spoiler`. Ein künftiger Codex darf diese Autorenebene nicht ungefiltert anzeigen.

Beispiel:

```json
{
  "id": "ash_watch",
  "status": "existing_presentation_binding",
  "legacy_pool_index": 0,
  "flavor_only": true,
  "texts": {
    "name": "cards.ash_watch.name",
    "flavor": "cards.ash_watch.flavor"
  }
}
```

`narrative_catalog.gd` bietet `text(key, locale, values)`, `entity(collection, id)` und `manifest()`. Daten werden kopiert zurückgegeben, damit Vorschauwerkzeuge weder Identität noch Katalog verändern. Regionale englische Tags wie `en-GB` und `en_US` verwenden Englisch; unbekannte Sprachen fallen dokumentiert auf Deutsch zurück. Fehlende Schlüssel ergeben einen sichtbaren `[missing:key]`-Wert. Benannte Platzhalter stimmen zwischen den Sprachen überein.

```gdscript
const Lore = preload("res://scripts/narrative_catalog.gd")
var card = Lore.entity("cards", "ash_watch")
var en_flavor = Lore.text(card.texts.flavor, "en")
var greeting = Lore.text("preview.greeting", "de", {"hero":"Mara"})
```

Die narrative API wird nicht in den laufenden Kampfpool hineingemischt. `CARD_POOL`, Kartenreihenfolge, Zahlen, KI-Auswahl, Siegbedingungen, Energie und Zugauflösung bleiben unverändert. Die bestehenden Differenztests verwenden weiterhin dieselbe unabhängige Regelreferenz.

### Synchronisierte Bibel

`python3 tools/render_narrative.py` erzeugt die Worldbuilding-, Fraktions- und Narrative-Dokumente aus Manifest und Sprachdateien. `--check` erkennt veraltete Ansichten. Neue redaktionelle Inhalte zuerst in den Sprachkatalogen und strukturierten Entitäten ändern, dann die Dokumente neu erzeugen. Audit und Namensentscheidung bleiben eigenständige, quellenbezogene Dokumente.

## Prüfungen

`DISPLAY=:99 tools/test.sh` führt zusätzlich zum vorhandenen Testsystem zwei neue Prüfebenen aus:

1. `tools/validate_creative.py`: Entitätszahlen und eindeutige IDs; alle Referenzen; DE-/EN-Schlüssel und Platzhalter; Monologlänge; kurze Kartentexte; zusammenhängendes 40-Sekunden-Intro; Trennung von Entwurf und aktivem Inhalt; unveränderte Originalkarten gegen eingefrorene Daten aus `927ae10`; konsistente Markenmetadaten und erzeugte Bibeldateien.
2. `tests/narrative.gd`: tatsächliches Godot-Laden der JSON-Ressourcen, deutsche/englische und regionale Textabfragen, Platzhalter, Fallback, fehlende Schlüssel, nicht mutierbare Rückgaben sowie unveränderter Produktname und ausdrücklich deaktivierte Entwurfsinhalte.

Die abschließenden lokalen und GitHub-Ergebnisse werden im folgenden Nachweisabschnitt erfasst. Die vorhandenen Regel-, Touch-, Layout-, Render- und Kontrastprüfungen bleiben verpflichtend. JSON-Dateien sind explizit in den Exportfiltern enthalten; ein zusätzlicher Test gegen das exportierte PCK prüft, dass das Paket die Daten tatsächlich enthält.

## Redaktionelle Prüfung und Grenzen

- Monolog: 158 Wörter pro Sprache, unabhängig vom wesentlich kürzeren Intro-Sprechertext. Das Intro ist ein 40-Sekunden-Schnittplan mit Raum für Geräusche; Vertonung und tatsächliches Sprechtempo wurden nicht produziert.
- Zeitlinie und Figurenalter sind abgestimmt: Gegenwart 83, Listenbereinigung 62, Nemi heute 23 und damals zwei; Mara heute 32, Rettung mit acht im Jahr 59. Acht wurde im Jahr des Nullwinters nach dessen Eintritt gebaut.
- Die vier Motive behalten die vorhandenen Zahlenprofile. Neue visuelle Farbfamilien sind Materialangaben, keine Ersetzung der getesteten semantischen UX-Palette.
- Storyvarianten in den Kapitelbeschreibungen sind Dialogentwürfe mit wieder zusammenführenden Verläufen, kein implementierter Verzweigungs- oder Belohnungsmechanismus.
- Der erste Boss verfügt weder über Immunitäten noch manipulierte Zufallszüge. Der vorhandene KI-Mischpool bleibt die technische Grenze; eine exklusive Gezeitenaufstellung wird nicht behauptet.
- Es fand eine redaktionelle DE-/EN-Prüfung statt, keine professionelle Übersetzungslokalisierung durch Muttersprachler, kein aufgenommener Sprecherlauf und keine internationale Publikumsstudie.
- Die Textbasis ist neu geschrieben. Externe Recherche diente der Namensprüfung; aus gefundenen Spielen wurden keine Geschichten oder Figuren übernommen. Absolute Originalität oder markenrechtliche Freiheit wird nicht behauptet.
- Vor einer echten Namensumstellung bleiben Store-/Titelprüfung, finale Logoentwicklung und gegebenenfalls Migration von Godot-`user://`-Daten notwendig. App-ID, Repository, Pages-Pfad und QA-Diagnosekennung bleiben stabil. In dieser Lieferung werden keine Nutzerdateien verschoben.

## Nächste Freigaben, ohne die aktuelle Lieferung zu blockieren

1. Auftraggeber wählt einen Namenskandidaten zur weiteren Prüfung bzw. genehmigt später die endgültige Schreibweise ausdrücklich.
2. Marken-/Domain-/Titelsituation und Zielländer vervollständigen; Favoriten sind bisher nur vorgeprüft.
3. Lore, Fraktionsnamen und Porträtzuordnungen redaktionell abnehmen.
4. Erst in einem Folgeauftrag Kampagnen-UI, Sprecherproduktion, Encounter-Anbindung und vollständig englische Produktoberfläche implementieren.

## Lokaler Abnahmelauf

Godot 4.6.3; Xvfb/Mesa; Python/Pillow. Vollständiger Lauf `DISPLAY=:99 tools/test.sh`:

| Prüfung | Ergebnis |
|---|---|
| Godot-Import | Keine Skriptfehler |
| Bestehende Regeln | 684 Assertions, 0 Fehler; 30 Differential-Duelle |
| Narrative Daten / Lokalisierung / Markenmetadaten | 2.253 Assertions, 0 Fehler |
| Tatsächliche Godot-Katalogabfragen | 97 Assertions, 0 Fehler |
| Bestehende Maus-/Touch- und Layouttests | 380 Assertions, 0 Fehler |
| Bestehendes UX-Audit | 1.900 Assertions, 0 Fehler; 49 gepaarte Renderzustände |
| Gerenderter Kontrast | 2.042 Messflächen, 0 Fehler |
| Webexport | Erfolgreich |
| Katalogtest gegen exportiertes PCK | Weitere 97 Assertions, 0 Fehler; Daten tatsächlich enthalten |

Die vollständige Suite umfasst **5.314 Assertions**, zusätzlich Kontrastmessungen und den wiederholten Pakettest. Neue Datenprüfungen fanden im Entwicklungszyklus eine doppelte Entitäts-ID; der erste Godot-Test fand einen falschen Lookup-Pfad. Beide wurden korrigiert und die komplette Suite danach erfolgreich ausgeführt.

Die neuen Prüfungen sind in `tools/test.sh` und die Paketprüfung in GitHub Actions integriert. Browserprüfungen kontrollieren zusätzlich, dass Browser-Titel und Canvas-Beschriftung die unveränderte zentrale Produktidentität verwenden. Ergebnisse und Logauszüge liegen unter [qa/](qa/).

Zusätzliche Exportprüfung: Linux-Debugexport erfolgreich; der Katalogtest gegen dessen eingebettetes Paket besteht ebenfalls mit 97 Assertions. Der Android-Debugexport ist erfolgreich, APK-Signaturen v2/v3 sind verifiziert. Keine Installation auf physischem Android-Gerät; kein neuer nativer iOS-Build auf dieser Linux-Umgebung.

Browserlauf: sechs Profile in Chromium und WebKit bestehen mit Touch-Auswahl, Inspector, Beschwörung, Zugende, Safe-Area-/Viewportänderung und reduziertem Bewegungsmodus. Die zentrale Produktidentität ist in Browser-Titel und Canvas-Beschriftung geprüft. Godots Kennzeichnung „(DEBUG)“ darf beim Debugexport als Zusatz erscheinen; sie ist kein anderer Produktname.

## GitHub-Abnahme und veröffentlichter technischer Stand

- [Finaler Feature-Lauf](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/42570426109): erfolgreich, vollständige Suite mit 5.314 Assertions, bildbasiertem Kontrast, exportiertem Pakettest und sechs Browserprofilen.
- [Veröffentlichung und Live-Prüfung](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/42570773767): beide Jobs erfolgreich. Dieselbe vollständige Prüfung vor Veröffentlichung; danach weitere sechs Profile auf der öffentlichen HTTPS-Spielseite, einschließlich zentralem Produktnamen und Touch-Bedienung. Keine JavaScript- oder Konsolenfehler.
- Spielbuild: `22e80a20b559469529e5336ae624b9a597f16f44`; Kanal `develop`. `build-info.json` und die versionierten JS-/PCK-Dateien wurden zusätzlich per HTTPS abgeglichen.
- [Bestehendes Spiel mit der neuen technischen Grundlage öffnen](https://jagarex-lab.github.io/nachtsiegel-app/?v=22e80a20b559). Der sichtbare Produktname ist weiterhin NACHTSIEGEL; hier wird keine neue Kampagne oder Markenwahl vorgetäuscht.
- Metadaten und Testausgaben: [github-feature.json](qa/github-feature.json), [github-feature-summary.log](qa/github-feature-summary.log), [github-publish.json](qa/github-publish.json), [github-publish-summary.log](qa/github-publish-summary.log), [live-build.json](qa/live-build.json). Die Browserbilder stehen außerdem in den Actions-Artefakten `nachtsiegel-arena-qa` und `nachtsiegel-live-qa`.
- Branch `feature/brand-world-bible`, nach grüner Feature-QA per Fast-Forward nach `develop` integriert. `main` blieb bei `caaa00169a7c43eb6eabe919746a0f33131a0664`.

Der abschließende Nachweiscommit enthält ausschließlich Dokumentation und Belege. Der veröffentlichte Spielbuild bleibt der oben angegebene getestete Codecommit. Physische Gerätetests, ein nativer iOS-Build, eine endgültige Namensfreigabe und vollständige amtliche Marken-/Ähnlichkeitsprüfungen bleiben ausdrücklich offen.
