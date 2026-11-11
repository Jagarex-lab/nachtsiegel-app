# Story-Präsentation – isolierter Prototyp

Status: technisch implementierter Entwurf. Keine narrative Freigabe. Die neue Szene ist kein Ersatz für den produktiven Alpha-Einstieg.

Start im Editor über `scenes/campaign_orafold/campaign_overview.tscn` (F6) oder:

```sh
godot --path . scenes/campaign_orafold/campaign_overview.tscn
```

`presentation.gd` rendert Kapitelübersicht, Dialog, Rückblick, Charakterwissen, Einstellungen und die durch den Kampfadapter gestartete Begegnung. Eigene Unteransichten werden in einer gemeinsamen scrollbaren Szene aufgebaut; dadurch ist kein Eingriff in zentrale UI-Szenen nötig. Die Ansichten greifen ausschließlich auf den Kampagnenmanager zu.

## Gestaltung

Ruhige dunkle Flächen, abstrakte Raumfalten, Kupfer- und Amethyst-Akzente sowie die vorhandenen lizenzierten Schriften Body und Cinzel ergänzen die Kartenoptik. Der Prototyp verwendet ausdrücklich vorläufige Illustrationen aus `assets/campaign_orafold/`. Eira erhält kein erfundenes Aussehen. Statuskennzeichnungen erscheinen sowohl am Einstieg als auch bei Charakteren.

## Bedienung und Zugänglichkeit

- Unter 720 Pixeln wechseln Kapitelkarten in eine senkrechte Anordnung; Inhalte fließen ohne feste Dialoghöhe und ohne horizontales Scrollen.
- Schaltflächen sind mindestens 52 Pixel hoch; die gesamte Inhaltsfläche lässt sich auf kleinen Bildschirmen scrollen.
- Dialoge bestehen aus kurzen Einzelabschnitten. Weiter zeigt zunächst den vollständigen Text und wechselt erst bei erneutem Auslösen zur nächsten Zeile. Entscheidungen werden nicht automatisch getroffen.
- Bereits abgeschlossene Szenen können bis zur nächsten Entscheidung oder Begegnung übersprungen werden. Ungelesene Szenen erhalten diese Abkürzung nicht.
- Textgeschwindigkeit, sofortige Darstellung, reduzierte Bewegung und Textgröße werden im separaten Kampagnenzustand gespeichert.
- Deutsch/Englisch verwenden stabile Text-IDs; ein Sprachwechsel ändert die Ansicht sofort.
- Tab und Enter bedienen native Godot-Schaltflächen. Leertaste setzt Dialoge fort, Escape öffnet die Übersicht. Die Auswahl einer Option bleibt explizit.
- Der Rückblick ist scrollbar und verwendet weiterhin Text-IDs, damit gespeicherte Dialoge in der aktuell gewählten Sprache erscheinen.
- Ein laufender Kampf bleibt beim Öffnen anderer Ansichten im selben Prozess erhalten. Nach einem Neustart wird eine ausstehende Begegnung mit demselben Ergebnis-Token sicher neu gestartet; es wird kein ungeprüfter Kampfzustand rekonstruiert.

## Prüfbarkeit und Grenzen

Öffentliche UI-Testzugänge: `manager`, `screen`, `body`, `main`, `line_index`, `open_overview()`, `open_dialogue()`, `open_history()`, `open_characters()`, `open_settings()` und `advance_dialogue()`.

Viewportprüfungen und tatsächliche Prüfergebnisse stehen in [QA.md](QA.md). Ein simuliertes Viewport-Ergebnis ersetzt keine Prüfung auf physischen Android-/iOS-Geräten. Globale Projektausrichtung, Exportprofile und Produktnavigation werden in diesem Auftrag nicht verändert; eine spätere mobile Hostintegration muss Hochformat zulassen. Audio wird ausschließlich über narrative Ereignisse vorbereitet, ohne eigenen AudioManager.

Der UI-Neuaufbau wird pro Frame zusammengefasst und erst nach der aktuellen Eingabeweiterleitung ausgeführt. Integratoren sollten über die vorhandenen Öffnen-/Manager-Methoden gehen und nicht während eines Touch-Callbacks Widgets unmittelbar aus dem Baum entfernen. Dekorative Panels lassen Wischgesten zur Scrollfläche durch. Die Web-Ansicht skaliert hochauflösende Canvas-Pixel auf logische CSS-Pixel.
