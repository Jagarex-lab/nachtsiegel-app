# M3 – Reproduzierbare Energie- und Resonanzversuche

Stand: 10.11.2026. Dieses Paket untersucht den tatsächlichen Alpha-Pool mit **55 Karten und vier vorhandenen 30-Karten-Startern**. Es verändert weder Produktionsregeln noch Legacy-Referenz, Starter, Kartenwerte oder Benutzeroberfläche. Ein Ergebnis für diesen kleinen Pool ist kein Nachweis der Balance des geplanten 550-Karten-Spiels.

## Versuch und unveränderte Regeln

[Testprogramm](../../tests/master550_resources.gd) erbt für den Versuch von [AlphaModel](../../scripts/alpha/model.gd), das seinerseits den [gemeinsamen Kernel](../../scripts/legacy/battle_engine.gd) verwendet. Es gibt keine kopierte Angriffs-, KI-, Konvergenz- oder Effektengine. Drei isolierte Modelle unterscheiden ausschließlich die gewöhnliche Energieauffüllung und die Resonanzobergrenze:

| Modell | Energie je eigenem Zug | Resonanzmaximum | Entfesselung |
|---|---|---:|---|
| `energy8_res15` | `min(eigene Züge, 8)` | 15 | Schwelle 15, Zahlung 8, höchstens einmal je eigenem Zug |
| `energy10_res15` | `min(eigene Züge, 10)` | 15 | unverändert |
| `energy10_res20` | `min(eigene Züge, 10)` | 20 | unverändert |

Die Erhöhung auf 10/20 ist ausschließlich ein Testprofil. `AlphaModel` bleibt bei 8/15. Unverändert bleiben 30 Helden-LP, 30 Karten, fünf Starthandkarten, Handlimit sechs, Ursprung, Zweite Möglichkeit, Mulligan, Nachziehen, Ablage, Kosten sämtlicher Karten und Sonderaktionen, Reaktionen, Relikte und beide Siegbedingungen. Ein Angriff auf ein leeres direkt gegenüberliegendes Feld trifft weiterhin den Helden; gewöhnlicher Schaden verbraucht Block vor Schild.

Der Adapter setzt die Versuchsenergie am vorhandenen `begin`-Protokollpunkt, bevor die geerbte KI handelt. `add_res` verwendet die jeweilige Obergrenze. **Harvest** ist ein wichtiger Sonderfall: Der Legacy-Kernel schreibt dafür direkt `min(15, ...)`, ohne `add_res`. Der Adapter berücksichtigt auch diesen Pfad am vorhandenen `harvest`-Protokollpunkt. Die geerbte Todesqueue bleibt erhalten. Der 8/15-Adapter wird gegen die unveränderte Produktionsklasse mit vollständigen Ereignisfolgen und Endzuständen geprüft; bloß gleiche Sieger würden hierfür nicht ausreichen.

## Versuchsmatrix und Reproduzierbarkeit

16 geordnete Starterpaarungen × vier fest ausgewählte Seeds × drei Modelle ergeben **192 Matrixpartien**. Pro Paarung sind genau zwei Seeds mit Startspieler `hero` und zwei mit `enemy` enthalten. Die kleinsten passenden Seeds werden deterministisch aus 0…2047 ausgewählt. Jeder Seed wird mit derselben Deckreihenfolge und Eröffnung in allen drei Bedingungen verwendet. Der Seed wird nach dem vorhandenen Mulligan anhand der tatsächlichen Münze klassifiziert; der Startspieler wird nicht nachträglich überschrieben.

Die Politik entspricht [alpha02_balance.gd](../../tests/alpha02_balance.gd): Karten über Kosten drei im Mulligan austauschen, eigener Ursprung zunächst Pfad zwei, zweiter Spieler tauscht gegebenenfalls eine teure Karte und verschiebt den Ursprung um einen Pfad. Danach spielt die vorhandene KI auf beiden Seiten. Die Hero-KI überspringt eine ausstehende Verschiebung; die vorhandene Gegnerlogik löst diese teilweise automatisch. Diese bestehende Asymmetrie wird nicht als symmetrisch optimale Spielweise ausgegeben.

Die Variante 20 Resonanz benutzt absichtlich dieselbe KI wie die anderen Varianten, einschließlich der vorhandenen Reliktentscheidung `Resonanz < 15` und der Entfesselung ab 15. Die KI wurde nicht für eine 20er-Reserve optimiert. Pro Partie gilt die technische Grenze von 400 Hero-KI-Aufrufen; ein noch offenes Spiel wird als `censored` gespeichert und lässt den Test fehlschlagen. Nicht unterstützte oder fehlerhafte Abläufe zählen nicht als bestanden.

Zusätzlich zu den Matrixpartien laufen vier Vergleichspartien: zweimal Adapter gegen Produktionsmodell, einmal je Startseite. Drei weitere Partien wiederholen je einen Matrixlauf pro Bedingung mit exakt demselben Ereignishash. Diese **sieben zusätzlichen Verifikationspartien** fließen nicht in die Siegraten ein.

Das ignorierte Artefakt `work/master550/resource_experiments.json` enthält alle Seeds, Paarungen, Startspieler, Sieger, Modellparameter, vollständige aggregierte Messwerte, Karten-Nutzungen und SHA-256-Werte der Ereignisfolgen/Endzustände. Dazu kommen Godot-Version, mechanischer Kartenpool, Starterlisten und Quellhashes des verwendeten Modells, Katalogs, Kernels und RNG. Der mechanische Poolhash verwendet die regelrelevanten Felder; reine Textkorrekturen werden nicht mit Balanceänderungen verwechselt. Karten und Starter werden am Testende erneut auf unveränderte Definitionen geprüft.

## Messgrößen

* `round` zählt globale Halbzüge, keine Sekunden und keine vollständigen Zugpaare. Laufzeit von KI-Simulationen beweist kein menschliches Spieltempo.
* Energieangebot ist die Summe der tatsächlichen Zugauffüllungen plus Energie aus der gerichteten Reaktion `tide>veil`. Verbrauch erfasst Kartenkosten und erfolgreiche Reliktaktivierungen. Restenergie wird unmittelbar vor Angriffen beziehungsweise bei einem vorherigen Spielende gemessen. **Angebot = Verbrauch + Rest** wird für jede Seite jeder Matrixpartie geprüft.
* Resonanzgewinn, über der Obergrenze verlorene Resonanz, Verbrauch, Spitzenwert und Reserve bei eigenem Zugbeginn werden getrennt erfasst. **Gewinn − Verbrauch = Schlussreserve** wird für jede Seite jeder Matrixpartie geprüft. Kartengeneration und Entfesselung sind keine zusätzliche, unbegrenzt ausgebbare Energie.
* Kartennutzung zählt erfolgreiche Ausspielvorgänge pro Original-ID. Das ist keine Nutzungsquote unter allen möglichen Karten oder verfügbaren Handkarten; die bestehenden Starter enthalten nur einen Teil des Pools.
* Konvergenzgewinn, Erklärungen, gescheiterte Erklärungen, Reliktaktivierungen, Entfesselungen und die längste geerbte Effektqueue werden erfasst. Ein beobachtetes Maximum ist keine obere Enginegrenze.
* Macht-Siegraten verwenden nur Nichtspiegelpaarungen. Die unabhängige Einheit ist eine konkrete Seed-/Deckpaarung; die drei Varianten desselben Seeds sind gepaart und keine drei unabhängigen Beobachtungen.

## Grenzen der aktuellen Daten und gesonderte Grenztests

Alle 55 bestehenden Karten kosten höchstens sechs Energie. Die vorhandenen vier Starter werden direkt aus [cards.json](../../data/alpha/cards.json) geladen; keine experimentelle Deckkopie wird produktiv gespeichert. Ein höheres Auffüllmaximum kann im aktuellen Pool mehrere Aktionen ermöglichen, prüft aber nicht die Stärke neuer Kosten-9/10-Karten.

Der Test ergänzt daher **ausschließlich im Speicher** zwei ausdrücklich synthetische Wesen für Kosten neun und zehn. Sie sind weder neue kommerzielle Karten noch Teil der 55 oder der geplanten 550. Auf beiden Spielerseiten wird geprüft, dass die gewöhnliche Zugauffüllung im 8er-Modell nicht reicht, das 10er-Modell am entsprechenden eigenen Zug zahlen kann und eine abgelehnte Ausspielaktion den Zustand unverändert lässt. Das ist ein Erreichbarkeitsnachweis der Auffüllkurve, kein Balanceurteil und kein allgemeiner Beweis gegen künftige zusätzliche Energiequellen.

Weitere Grenztests prüfen auf beiden Seiten für alle drei Modelle:

* direkte Resonanzgewinne an der Obergrenze;
* Speicherung über den eigenen Zugbeginn;
* Harvest mit echter Alpha-Karte an der Obergrenze;
* Entfesselung bei 14 Resonanz abgelehnt und unveränderlicher Zustand;
* Entfesselung bei 15 Resonanz erlaubt und danach genau sieben Resonanz.

Die zwölf Legacy-Ordensreaktionen sind vorhanden, benötigen jedoch jeweils zwei verschiedene nichtneutrale Ordnungen. Die aktuellen Alpha-Karten tragen ihre eigene Macht als `order`, und legale Decks enthalten nur eine Macht plus Neutral. Deshalb löst der aktuelle Starterpool diese zwölf Paar-Effekte durch normales Ausspielen nicht aus. Wechsel zwischen Macht und Neutral erzeugen weiterhin zwei Resonanz, aber keine der zwölf gerichteten Reaktionen. Die Simulation darf keine Reaktionsbalance des zukünftigen Pools behaupten. Der Test erfasst zusätzliche Reaktionsenergie trotzdem, damit die Bilanz einen später tatsächlich auftretenden Fall nicht verschweigt.

## Tatsächlicher Messlauf

Godot **4.6.3-stable (official)**, Headless-Linux. Ergebnis: **1.125 Assertions bestanden, null fehlgeschlagen; 192 beendete Matrixpartien und sieben zusätzliche Verifikationspartien; null Enginefehler, null abgebrochene oder zensierte Partien.** Die exakten Baseline- und Wiederholungsvergleiche bestanden. Synthetische Grenztests zählen nicht zu diesen 199 vollständigen Partien.

| Messgröße | Energie 8 / Resonanz 15 | Energie 10 / Resonanz 15 | Energie 10 / Resonanz 20 |
|---|---:|---:|---:|
| Matrixpartien | 64 | 64 | 64 |
| Startspielersiege | 29/64 (45,31 %) | 29/64 (45,31 %) | 29/64 (45,31 %) |
| Hero-/Enemy-Siege | 33/31 | 33/31 | 33/31 |
| Konvergenzsiege | 12 (18,75 %) | 11 (17,19 %) | 12 (18,75 %) |
| Halbzüge, Mittel / Median | 28,42 / 24 | 28,30 / 24 | 28,20 / 24 |
| Frühester beobachteter Konvergenzsieg | 16 | 16 | 16 |
| Energieangebot gesamt | 10.856 | 12.263 | 12.193 |
| Ausgegebene / unverbrauchte Energie | 6.090 / 4.766 | 6.076 / 6.187 | 6.076 / 6.117 |
| Energienutzung | 56,10 % | 49,55 % | 49,83 % |
| Resonanzgewinn / -verbrauch | 1.227 / 320 | 1.229 / 328 | 1.254 / 344 |
| Durch Obergrenze verlorene Resonanz | 28 | 28 | 0 |
| Höchste beobachtete Resonanz | 15 | 15 | 19 |
| Mittlere Reserve bei eigenem Beginn | 4,47 | 4,43 | 4,46 |
| Entfesselungen / Reliktaktivierungen | 40 / 827 | 41 / 831 | 43 / 825 |
| Erfolgreiche Kartenausspiele | 2.342 | 2.335 | 2.338 |
| Unterschiedliche ausgespielte IDs | 40 | 40 | 40 |
| Längste beobachtete Effektqueue | 10 | 10 | 10 |

Gegen die Baseline änderte Energie 10 / Resonanz 15 bei **0 von 64 Paaren den Sieger** und bei zwei Paaren die Halbzugzahl. Energie 10 / Resonanz 20 änderte bei **0 von 64 Paaren den Sieger**, bei vier Paaren die Halbzugzahl. Keine Siegeränderung in dieser Stichprobe beweist weder Äquivalenz noch allgemeine Balance. Zusätzliche Energie blieb bei den vorhandenen günstigen Karten überwiegend ungenutzt. Die drei Bedingungen hatten jeweils 0 Energiegewinn aus gerichteten Ordensreaktionen, entsprechend der oben beschriebenen Ein-Macht-Grenze.

Die Nichtspiegel-Siege betrugen in **jeder** Bedingung: Zwölf Häuser 7/24, Stillwacht 10/24, Vielgestalt 7/24 und Neunte Stunde **24/24**. Das ist eine deutliche Warnung zur bestehenden Starter-/KI-Konstellation. Die kleine, fest ausgewählte Seedmenge erklärt keine Ursache und liefert keine belastbare Schätzung einer menschlichen Metagame-Siegrate. Weder die Energieerhöhung noch der höhere Resonanzspeicher beseitigte diese beobachtete Dominanz.

Die vier Starter enthalten zusammen **41 verschiedene IDs**. Nur 40 wurden ausgespielt; die übrigen 14 Karten des gesamten 55er-Pools stehen gar nicht in diesen Startern. Besonders relevant ist die einzige ungenutzte Starterkarte: **`oa-ninth-e01` – Umleitung**. `redirect` verlangt ein eigenes ausstehendes `delayed`-Ereignis. Die einzige aktuelle `delay`-Karte ist jedoch **`oa-stillwatch-e01` – Aufgeschobenes Urteil**, einer anderen Macht zugehörig. Damit kann Umleitung in einem gegenwärtig legalen Neunte-Stunde-Deck keine eigene Zielvoraussetzung herstellen. Das ist eine nach Quellcode und Daten nachvollziehbare bestehende Inhaltslücke, kein Zufall der 192 Partien. Dieses Versuchspaket korrigiert sie nicht heimlich. Ein künftiges Kartenpaket muss innerhalb der Macht oder neutral eine regelkonforme passende Quelle anbieten oder die betreffende Definition ausdrücklich neu bewerten; eine Quermacht-Beimischung wäre ein Deckregelverstoß.

Mechanischer Pool-SHA-256: `863d645d68da979c2f5658af2c8058dfbb017016a5017f85f034a4f3c54888c4`. Starter-SHA-256: `7749e8004d411dc4c1165854c743863a629b36ff005a2d0e5396f918e30222c4`. Modell-SHA-256: `576f12ecf5432533f82a089bd80959958e3ded970c4e6dc94efba21b7a530fc4`. Das JSON-Artefakt des Laufs umfasst rund 363 KB. Eine spätere Änderung von Karten, Startern oder Kernel erfordert einen neuen Lauf; dieser Bericht ist kein Prüfnachweis für danach veränderte Mechaniken.

## Empfehlung und nächste Entscheidung

Für die Erweiterung auf echte Kosten neun und zehn ist **Energiemaximum zehn mit getrennter, vorerst auf 15 begrenzter Resonanz** die nachvollziehbare nächste Versuchsgrundlage. Der Zweck der Energieerhöhung ist eine verständliche reguläre Erreichbarkeit der neuen Kostenskala. Resonanz bleibt eine zugübergreifende Sonderressource für Eingriffe; Energie bezahlt Karten und Reliktaktivierung. Eine Zusammenlegung würde Rückholung, Positionswechsel, Schutz und die vier Entfesselungen gleichzeitig ändern und wird hier nicht eingeführt.

Das 20er-Modell ist eine Reservevariante, keine automatisch bessere Lösung. Es verändert Überlauf und Restresonanz nach einer Entfesselung, ohne im aktuellen Auftrag allein durch den höheren Zahlenwert einen erkennbaren zusätzlichen Spielzweck zu beweisen. Erst neue, tatsächlich implementierte Resonanzpreise und geeignete Antworten erlauben eine tragfähige Entscheidung darüber.

Vor einer Produktionsumstellung sind Kostenkurven, Typ-/Arten-Archetypen, Gegenstrategien und die neuen Resonanzverbraucher als echte Karten zu implementieren und auf derselben gepaarten Matrix sowie einer deutlich größeren Seedstichprobe erneut zu testen. Die im bestehenden Alpha-Pool erkennbare Machtasymmetrie darf nicht durch eine pauschale Ressourcenerhöhung als behoben dargestellt werden. Menschliche Spieltests und echte iPhone-/Android-Tests bleiben zusätzlich erforderlich. Dieses Paket führt keine physischen Gerätetests durch.

## Ausführen

```bash
mkdir -p work/xdg/data work/xdg/config work/xdg/cache
LP_NUM_THREADS=2 \
XDG_DATA_HOME="$PWD/work/xdg/data" \
XDG_CONFIG_HOME="$PWD/work/xdg/config" \
XDG_CACHE_HOME="$PWD/work/xdg/cache" \
godot --headless --path . --script tests/master550_resources.gd
```

Der Test benötigt die vorhandenen Projektimporte und Godot 4.6.3; er lädt keine externe Referenz nach und führt keinen Build, Merge oder Release aus. Das JSON liegt absichtlich im ignorierten `work/`-Verzeichnis. Der dokumentierte Lauf endete mit Exitcode 0; sein Protokoll liegt lokal in `work/master550_resources.log`.
