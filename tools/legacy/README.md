# P01-Referenzadapter und Fixturegenerator

```bash
node tools/legacy/generate.cjs                 # deterministisch regenerieren
node tools/legacy/generate.cjs --check         # nur bytegenau prüfen
node tools/legacy/generate.cjs --check --verify-checkout /path/to/duel-deck
tools/test_legacy.sh                          # Node + Godot, ohne Display
```

Keine externen npm-Abhängigkeiten; Node24 und Godot4.6.3. Der Referenzadapter prüft die fest codierte Commit-/Blob-/SHA-Zuordnung und Lockdatei, bevor er die unveränderte Engine in einer frischen Node-VM lädt. Die VM dient der Isolation von Testdatenmutationen, nicht als Sicherheits-Sandbox für beliebige Skripte. Normale Tests sind offline ausführbar; der optionale Checkout-Nachweis prüft lokalen Git-HEAD und Dateibytes, lädt nichts aus dem Netz.

Ausgaben (alle mit Herkunft im Envelope):

1. `tests/fixtures/legacy/cards.json`: sämtliche tatsächlichen JS-Kartendefinitionen inklusive Originalbeschreibungen/Orden.
2. `tests/fixtures/legacy/decks.json`: START/Presets und24 JS-validierte Positiv-/Negativfälle.
3. `tests/fixtures/legacy/transitions.json`: sechs natürliche Eröffnungen aus Seed/Level und 124 klar gekennzeichnete synthetische Kontrollfälle mit 152 Schritten. Jeder Schritt enthält Befehl/Argumente, tatsächlichen Rückgabewert, Vor-/Nachzustand und sämtliche entstandenen Ereignisse einschließlich Boundary-Zuständen. Alle elf aufgezeichneten Legacy-Kommandos haben angenommene und abgelehnte Fälle. Zusätzlich werden einzelne exportierte Enginehelfer aufgerufen.
4. `data/legacy/cards.json`, `display_de.json`, `decks.json`: separater Datenkatalog für P02, kein neues Kampfmodell.

`scenarios.cjs` definiert Eingabezustände und ruft die tatsächliche Referenz auf; es berechnet **keine** erwarteten Kampfregeln nach. Die kontrollierten Hände/Einheiten/Ressourcen sind künstliche Testeingaben und keine behaupteten natürlich gezogenen Karten oder vollständigen Replayexporte. Die Goldens sind erst Referenzmaterial für spätere Godot-Implementierung. Bestehende Godot-Regressionen und deren alter Oracle bleiben unberührt.

`compare.cjs` und `tests/legacy_fixture_compare.gd` vergleichen vollständige JSON-Strukturen: Objektschlüsselreihenfolge bedeutungslos, Arrayreihenfolge bedeutsam, null ungleich fehlend, Typen erhalten. JSON-Zahlen1/1.0 sind numerisch gleich; boolean/string werden nicht in Zahlen umgewandelt. Keine Felder werden weggelassen. Nichtendliche Zahlen/unsichere Werte außerhalb±(2^53−1) und Nicht-JSON-Typen werden nicht als gleich akzeptiert. Der Node-Helfer wirft bei nicht darstellbaren Werten; der Godot-Helfer liefert einen Diagnoseunterschied. Das ist **kein** JS-kompatibler JSON/FNV-Replayhash; P11 bleibt offen.

Abdeckung: alle 16 Ankunftsfähigkeiten, Ziele/Skip, Ressourcenlimits, alle 12 gerichteten Ordenswechsel, Kosten/Handverbrauch, Wartezeit/Eile/Stun, beide Angriffsrichtungen, Block/Schild, Überlauf/Vergeltung/Tod, Nachziehen/Verbrennen/Erschöpfung/Kreislauf/Rückholung, aktive Manöver/Wacht/Entfesselungen sowie HP-/Pfadsieg und Stopreihenfolge. Die Eigenheiten `burn`/`skipShift` ohne eigenen Gewinnercheck und `recover` trotz Pendingziel werden festgehalten, nicht verbessert. Kein Anspruch auf sämtliche Kombinationen oder vollständige Kampfreplay-Parität.

Im Fixture bedeutet `accepted` exakt `result !== false` der alten Commandwrapper. Bei direkt exportierten Hilfsfunktionen (z.B. `draw` mit Rückgabewert0 oder `begin` mit undefined) bedeutet das nicht, dass eine Spieleraktion freigeschaltet oder eine Karte gezogen wurde. Der tatsächliche Rückgabewert ist separat typisiert gespeichert; undefined wird ausdrücklich als `{type:"undefined"}` statt als fehlendes JSON-Feld kodiert.
