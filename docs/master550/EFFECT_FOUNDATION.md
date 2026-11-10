# M2: Isolierte Effekt-Grundlage

Stand: 2026-11-10. Diese Grundlage ist **keine** Integration von 550 Karten und ersetzt keine Kampfengine. Die produktive Arena und das bestehende Legacy-/Alpha-Regelwerk werden durch diese Dateien nicht verändert.

## Architektur und Nachweisgrenze

- [registry.gd](../../scripts/card_system/registry.gd) liest den gemeinsamen [V2-Vertrag](../../data/card_system/registry.json), prüft Fähigkeiten und benennt die tatsächlich ausführbare Teilmenge.
- [runtime.gd](../../scripts/card_system/runtime.gd) adaptiert eine bereits gestartete `scripts/alpha/model.gd`-Instanz. Schaden, Wesen-Schild, Todesqueue, Ziehen, Resonanz, UID-Vergabe, Ursprungsschutz, Reliktaktivierung und Beschwörungsfähigkeiten verwenden die vorhandenen Methoden beziehungsweise dieselben vorhandenen Zustandsfelder.
- [card_system_runtime.gd](../../tests/card_system_runtime.gd) ist ein tatsächlich ausgeführter Godot-Test. Er prüft ausdrücklich die neue Adaptergrenze und bestehende Primitiven.

Es gibt keine zweite Kampfsimulation, keine eigene KI, keine neue RNG-Quelle und keine Kopie des Kartendatenkatalogs. Wesen werden weiterhin aus dem bestehenden Alpha-Katalog erzeugt. Die ergänzenden Wesensarten werden nur als separates Metadaten-Mapping gebunden; sie verändern keine bestehende Karte.

**Wichtig:** `production_wired=false` und `automatic_hooks=[]` sind Teil der maschinenlesbaren Fähigkeitenmeldung. Der Adapter erkennt keinen Angriff, Zugwechsel oder Todesfall selbst. Er darf nicht zusätzlich zum bestehenden Effektpfad an denselben Vorgang angeschlossen werden: Das würde Wirkungen doppelt ausführen. Eine spätere Integration muss den jeweiligen bestehenden Effektpfad kontrolliert ersetzen und Differentialtests behalten.

## API

```gdscript
var adapter = preload("res://scripts/card_system/runtime.gd").new(alpha_model)
adapter.bind_species(pilot_cards)
var result = adapter.publish("on_summon", "hero", card.abilities, {
    "event_id": "summon:17",
    "source_lane": 2,
    "source_uid": alpha_model.state.hero.lanes[2].uid
})
```

`publish(trigger, side, abilities, context)` prüft eine gesamte Liste, bevor sie die Kampfzustände verändert. Nur Fähigkeiten mit genau passendem Auslöser gelangen in die Queue. Ein `on_play`-Ereignis führt keine `on_summon`-Fähigkeit aus. Eine bekannte, aber nicht passende Liste meldet `queued=0` und `reason=no_matching_abilities`; das ist kein Funktionsnachweis für diesen Auslöser.

`activate(side, ability, context)` delegiert die vier ursprünglichen Reliktaktivierungen einschließlich Energiezahlung, Phasenprüfung, aktivem Relikt und Einmal-pro-Zug-Flag an `AlphaModel.activate_relic`. Die Kosten bleiben 1 Energie und 0 Resonanz. Beliebige andere Aktivierungskosten werden ausdrücklich als `unsupported_activation_cost` zurückgewiesen. `validate_costs` bietet bereits eine reine, mutationsfreie Prüfung auf ganzzahlige Energie-/Resonanzkosten und ausreichende Ressourcen; das ist noch keine Einführung neuer Resonanzkosten.

`summon(side, known_card_id, free_lane, event_id)` ist eine zusätzliche **quellengebundene interne Primitive**. Sie verwendet `make_unit` und `enqueue(type=summon)`. Ursprungsschild, Beschwörungsverzögerung und vorhandene Ankunftsfähigkeiten funktionieren. Sie entfernt keine Handkarte, bezahlt keine Ausspielkosten, zählt nicht als regulär ausgespielte Karte und verändert keine Ordensabstimmung. Sie erzeugt insbesondere kein `on_play`-Ereignis. Nur bekannte Wesen des bestehenden Katalogs sind zulässig. Der noch unvollständige deklarative Effekt `summon(count)` bleibt unsupported, weil der Vertrag dessen Kartenquelle noch nicht festlegt.

Die API ist eine interne Engine-Schnittstelle, keine öffentliche Befehlsvalidierung für Spieler. Ihr Aufrufer muss tatsächliche Auslöser feststellen und pro realem Ereignis eine stabile ID vergeben. Insbesondere beweist ein manuell veröffentlichtes `on_death` nicht, dass die Engine den Todesfall bereits automatisch an diese Schnittstelle weiterleitet.

## Ausführbare Teilmenge

Alle Parameter `amount` bezeichnen den **tatsächlichen** Effektwert. Ursprüngliche `power + 1`-/`power + 2`-Umrechnungen verbleiben im `source_binding` der Daten und werden nicht erneut addiert.

| Kategorie | Explizit ausführbare Effekte/Primitiven | Grenze |
|---|---|---|
| Schaden | `strike`, `drain`, `bolt`, `cascade` | `strike` braucht bei vorhandenen Gegnerwesen ein gültiges gewähltes Wesen; keine neue Zielwahl-UI |
| Schutz | `guard`, `ward`, `relic_ward` | Vorhandener Block; Heldenschild höchstens 25 |
| Heilung | `mend`, `heal`, `relic_heal` | Höchstens bestehendes `maxHp` |
| Verstärkung | `rally`, `pulse` | Vorhandene Nachbarregeln und Angriffswerte |
| Schwächung | `weaken` | Vorhandene gegnerische Angriffsphasen-Schwächung |
| Bewegung | `displace` | Vorhandene Auswahl: zuerst freier linker, sonst rechter Nachbar |
| Beschwörung | `summon(known_card_id, lane, event_id)`-Primitive | Nur bekannte Katalogwesen; deklaratives `summon(count)` fehlt weiterhin |
| Wiederkehr | `recall` | Letztes Wesen im eigenen Ablagestapel; Reihenfolge der übrigen Karten bleibt erhalten |
| Ressourcen | `weave`, `harvest`, `relic_res` | Bestehendes Resonanzmaximum 15; keine Änderung der Ressourcenregeln |
| Kartenmanipulation | `draw`, `relic_draw` | Ursprüngliche Effekt-Ziehregel: maximal 6 Handkarten; kein neuer Kreislauf/Erschöpfungseffekt |
| Zeitmanipulation | `surge`, `delay` | Vorhandener zusätzlicher Angriff bzw. originaler Zwei-Zugwechsel-Termin |
| Kontrolle | `silence`, `stasis`, `redirect` | Vorhandene Aussetzen-/Umleitungsregeln |

Damit bestehen 25 ausführbare deklarative Effektadapter und eine separate Beschwörungsprimitive. Dies belegt **nicht** vollständige parametrisierbare Abdeckung jeder der zwölf Kategorien, aller Kombinationen oder aller 16 automatischen Auslöser.

Der deklarative Adapter weist `pierce`, `shift`, `retaliate`, `haste` und `summon` ausdrücklich zurück. Ihre vorhandenen Produktionsimplementierungen bleiben erhalten. Insbesondere werden passive Eile und reaktive Vergeltung nicht als fertig integrierte allgemeine Fähigkeiten ausgegeben.

## Timing, Ziele und Schutzgrenzen

1. Die Reihenfolge innerhalb einer veröffentlichten Liste entspricht ihrer Datenreihenfolge.
2. Während eines Effekts erneut veröffentlichte Arbeit wird hinten angehängt. Bereits wartende Effekte werden zuerst abgewickelt; keine rekursive unmittelbare Auflösung.
3. Ausgewählte Wesen werden durch Seite, Pfad und Instanz-UID gebunden. Vor Ausführung wird die Bindung erneut geprüft. Verlässt das Wesen den Pfad oder wird durch eine neue Instanz ersetzt, protokolliert der Adapter `fizzled`; die Ersatzinstanz wird nicht getroffen. Pfadgebundene Effekte wie verzögerter Schaden behalten dagegen ihre vorhandene Pfadsemantik.
4. Vollständig ungültige Anfragen werden vor jeder Kampfmutation abgewiesen. Tests vergleichen Zustand, Modellereignisse, native Queue und RNG-Zustand/-Aufrufzahl. Innerhalb einer bereits begonnenen gültigen Kette werden spätere ungültig gewordene Ziele nicht nachträglich zu einer neuen Auswahl umgedeutet.
5. Das Metadaten-Mapping behandelt beide Wesensarten gleichwertig. Unbekannte oder doppelte Wesensarten werden zurückgewiesen. Ein gewünschter Artenfilter benötigt ein tatsächlich bekanntes Ziel.
6. Doppelte Ereignisse derselben Seite mit gleichem Auslöser und gleicher Ereignis-ID werden nicht erneut ausgeführt. Der interne Aufrufer darf einen realen Auslöser nicht unter neuen IDs wiederholen.
7. Eine Adapterkette ist auf 1.000 Queue-Einträge begrenzt, auch bei erneuter Veröffentlichung mit ständig neuen IDs. Ein zu großes Eingangsbatch wird vollständig zurückgewiesen. Eine während der Auflösung wachsende Schleife meldet `chain_limit`; bereits korrekt ausgeführte Effekte werden nicht zurückgerollt. Es gibt keinen stillschweigenden Erfolg dieser technischen Abbruchfälle.
8. Delegierte Original-Unterqueues behalten ihren bestehenden eigenen Schutz (Alpha: maximal 10.000 Einträge plus Zyklenerkennung). Beispielsweise zählt ein `cascade` im Adapter als ein Eintrag und erzeugt höchstens 100 originale Echo-Einträge. Der Adapter behauptet keine globale 1.000er-Grenze über beide Queues zusammen.
9. Die Ereignis-ID-Historie ist auf 10.000 Einträge pro Adapterinstanz begrenzt. Bei Erreichen folgt ein ausdrücklicher Fehler statt unbeschränktem Wachstum. Eine neue Partie benötigt eine neue Adapterinstanz.
10. Nach Spielende wird verbleibende Arbeit als `cancelled` protokolliert. Fehler einer delegierten nativen Queue werden ausdrücklich als `native_effect_failed` gemeldet. Bestehende Gewinnbedingungen und ihre Reihenfolge werden nicht ersetzt.

`log` enthält Reihenfolge, Kette, Ereignis-ID, Seite, Auslöser, Fähigkeitsindex, vollständige Fähigkeit, Zielkontext, Ergebnis und Fehler/Fizzle-Grund. Angewendete Einträge werden zusätzlich im vorhandenen Modellprotokoll mit vollständigem Zustand erfasst. Tests prüfen identische Zustände und Ereignisreihenfolge bei Wiederholung.

## Tatsächlich ausgeführte Tests

```sh
LP_NUM_THREADS=2 \
XDG_DATA_HOME=$PWD/work/xdg/data \
XDG_CONFIG_HOME=$PWD/work/xdg/config \
XDG_CACHE_HOME=$PWD/work/xdg/cache \
godot --headless --path . --script tests/card_system_runtime.gd
```

Godot 4.6.3, Linux headless: **314 Assertions, 0 Fehler** (Stand dieses Meilensteins). Nachweise:

- Alle acht tatsächlich gespeicherten Pilotfähigkeiten werden auf beiden Seiten durch die explizite API ausgeführt.
- Elf ursprüngliche Kreatur-Effektpfade werden auf beiden Seiten mit vollständigem Zustand gegen denselben Original-Effektpfad verglichen; es handelt sich um Adapter-/Regressionsvergleiche, nicht um neue JavaScript-Differentialfälle.
- Jeder der 25 als ausführbar gemeldeten Effekte wird tatsächlich ausgeführt; Unsupported-Fälle werden ausdrücklich zurückgewiesen und nicht zur Effektabdeckung gezählt.
- Zwölf aufeinanderfolgende Adaptereffekte; zusätzlich zwölf über die originale Queue abgewickelte Echo-Treffer; deterministische Wiederholung und reentrante FIFO-Reihenfolge.
- Abbruch einer absichtlich endlosen erneuten Veröffentlichung bei exakt 1.000 Einträgen; Resonanz bleibt höchstens 15.
- Identitätswechsel eines Ziels zwischen zwei Effekten; der zweite Eintrag fizzelt und trifft das neue Wesen nicht.
- Ungültige Batchbestandteile, IDs, Parameter, Kosten, Artenfilter und Ziele verändern weder Kampfzustand noch RNG.
- Direkter Heldentreffer auf leerem Gegenpfad, Verbrauch von Block vor Schild, Wesen-Schild vor Lebenspunkten und originale Todesablage.
- Quellengebundene Beschwörung auf beiden Seiten mit vollständigem Vergleich zum vorhandenen `make_unit`-/Summon-Queue-Pfad; Ursprungsschild und Ankunftseffekt; kein Ausspielen-/Hand-/Energienebeneffekt.

## Offen vor produktiver Integration

- Zustandsgebundene automatische Erkennung und genau einmalige Veröffentlichung aller 16 Auslöser; Reihenfolge gleichzeitiger Auslöser zwischen mehreren Quellen.
- Vollständige reaktive Fenster, passive Fähigkeiten sowie aktivierbare nicht bestehende Reliktfähigkeiten.
- Eine ausdrückliche Kartenquelle und Mengensemantik für deklarative Beschwörung; neue Karten außerhalb des aktiven Katalogs benötigen zuerst dessen kontrollierten Datenadapter.
- Einheitliche Kostenzahlung beim tatsächlichen Ausspielen neuer V2-Karten; der Effektadapter selbst ist kein Karten-Ausspielbefehl.
- Vollständige 550-Karten-Daten, globale Kombinationstests, belastbare Balancesimulationen und UI-Anbindung. Ein Test des internen Adapters macht keine neue Karte automatisch regulär spielbar.
- Echte iOS-/Safari-Gerätetests. Dieses Paket enthält keine UI und führt keinen Browser-/Gerätetest vor.

Keiner dieser Punkte darf allein durch Umbenennen der Capability-Flags als erledigt ausgegeben werden.
