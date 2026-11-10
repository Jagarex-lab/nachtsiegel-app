# Tatsächlich gefundene defensive Blockade und geprüfte Korrektur

## Fehlgeschlagener Ausgangslauf

Der erste vollständige lokale Shard 0 enthielt 212 tatsächliche Matrixpartien und vier Wiederholungen. Ergebnis: **671 Prüfungen, ein Fehler, 211 beendete Partien, eine zensierte Partie, keine Enginefehler**. Dies ist kein bestandener 848-Partien-Lauf. Der reproduzierbare Fehler war `prod-shield` gegen `prod-control`, Seed 2, Gegner beginnt: nach 500 eigenen KI-Aufrufen beziehungsweise Halbzug 1002 war kein Sieger bestimmt. Der Fehler blieb ausdrücklich im Bericht enthalten.

Die Quellen blieben in diesem Lauf tatsächlich unverändert. Der Bericht wurde am 10.11.2026 um 21:30:22 UTC abgeschlossen; die nachfolgenden KI-/Deckkorrekturen begannen erst danach. `FAILED_BASELINE.json` enthält den vollständigen fehlgeschlagenen Fall und seine Quellenbindung. Die Rohdateien bleiben unter `work/production/baseline-before-finishers/` erhalten.

## Diagnose statt erzwungenem Ergebnis

Eine unabhängige, auf 100 KI-Aufrufe begrenzte Untersuchung verwendete denselben echten Produktionskernel, dieselben tatsächlichen Decks und denselben Seed. Sie erreichte Halbzug 202 ohne Sieger oder Enginefehler. Beide Spieler hatten fünfmal recycelt; die Helden standen bei 27 und 30 LP. Vier der fünf eigenen Wesen hatten 0 Angriff. Die gegnerische Seite hielt unter anderem mehrere Konstrukte mit 25 Schild. Regelmäßige Heilung konnte den auf 3 begrenzten Recyclingschaden ausgleichen. Die Referenzlisten enthielten fast ausschließlich schützende Relikte und keinen verlässlichen wiederkehrenden Angriffsaufbau.

Dies war ein tatsächliches Problem der gewählten Referenzzusammensetzungen und ihrer KI-Bewertung. Es wurde kein Sieger erzwungen, kein Zeitlimit als neue Regel eingeführt und kein zensierter Fall nachträglich als bestanden gewertet.

## Kontrollierter Versuch mit bestehenden Karten

Zunächst wurden ausschließlich die drei Reliktplätze des Schilddecks im Speicher durch drei regelkonforme Exemplare der bereits vorhandenen epischen **Ungebrochenen Scheibe** (`of-stillwatch-097`) ersetzt. Alle 550 Kartenwerte, Ressourcen, Siegbedingungen und die damalige KI blieben unverändert. Das Relikt gewährt dem eigenen Wesen mit dem wenigsten Leben zu Zugbeginn +2 Angriff und schafft damit einen langfristigen Gewinnplan gegen volle, geschwächte Spielfelder.

Dieser tatsächliche Versuch endete im Halbzug 65 durch gegnerische Konvergenz, bei 18/21 Helden-LP. Er belegt eine aufgebrochene Blockade, keine automatische Überlegenheit des geänderten Schilddecks. Artefakt: `work/production/finisher-treatment-final.json`.

## Implementierte Korrektur

- Die vier defensiven Referenzdecks **Kontrolle, Schild, Block und Konvergenz** verwenden in ihren vorhandenen zwei beziehungsweise drei Reliktplätzen die Ungebrochene Scheibe. Alle Listen bleiben echte 30-Karten-Decks mit derselben Macht- und Kopienregel.
- Die Produktions-KI erkennt ein beidseitig volles Spielfeld mit weitgehend kraftlosen Wesen oder hoher gegnerischer Schutzsättigung. Sie bewertet dort wiederkehrende Angriffsverstärkung als Gewinnplan, kann ein rein schützendes Relikt ersetzen und tauscht ein bereits hilfreiches Wachstumsrelikt nicht wieder grundlos gegen Schutz aus.
- Beim eigenen Pflichtverbrennen schützt die Policy das beste noch nicht aktive Wachstumsrelikt. Sie schützt einen Gewinnplan, nicht sämtliche doppelten Exemplare.
- Die Auswertung bleibt zustandslos und verwendet ausschließlich öffentliche Spielfeldwerte sowie eigene Karten. Es gibt keine Bonusressourcen, verborgenen gegnerischen Karteninformationen oder Eingriffe in die Zufallsfolge.
- Die drei entsprechenden Reliktplätze der sichtbaren Stillwacht-Startervorlage wurden ebenfalls aktualisiert. Bereits gespeicherte eigene Decks werden weiterhin nicht ungefragt überschrieben.

Beim Einbetten der neuen Starter wurde die Gleichheit **aller 550 vollständigen Kartendatensätze** vor und nach der Generierung geprüft. Es änderten sich keine Kartenwerte oder Fähigkeiten, sondern nur die Starterliste. Der Mindestunterschied zwischen zwei der vierzehn Referenzdecks bleibt acht ausgetauschte Kopien.

## Regression und Grenzen

`tools/test_production_finishers.sh` prüft beide Rollen, Seeds 0, 1, 2 und 4 sowie eine vollständige Wiederholung des früher zensierten Falls. Der aktuelle Lauf bestand **91 Prüfungen und neun tatsächliche Produktionspartien**. Alle endeten regulär; die Wiederholung verglich vollständigen Endzustand und alle Ereignisse. Auf dem zusätzlich korrigierten Konvergenzstand endete der zuvor zensierte Seed-2-Fall bereits im Halbzug 25.

Die separate archivierte 55-Karten-Policy-Prüfung bestand **187 Prüfungen und 20 tatsächliche Partien**. Die anschließende vollständige 848-Partien-Matrix muss mit den final eingefrorenen Quellen erneut bestehen. Frühere fehlgeschlagene Resultate werden nicht zu diesem Erfolg addiert.

Die Korrektur liefert nachvollziehbare Gewinnpläne für die Referenzdecks. Sie beweist keine vollständige Balance aller möglichen selbst gebauten Decks. Es wurde keine allgemeine Pattsituationserkennung oder automatische Remisregel eingeführt. Die erhaltenen nativen Gegnerpfade wählen beim automatischen Verbrennen und bei bestimmten ursprünglichen Ankunftseffekten weiterhin nach ihren früheren Heuristiken; diese Sitzasymmetrie ist bei der Interpretation von Selbstspielresultaten zu berücksichtigen.
