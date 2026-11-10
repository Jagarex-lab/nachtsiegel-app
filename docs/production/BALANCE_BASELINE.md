# ORAFOLD – bestätigter Alpha-Ressourcenlauf

Stand: 10. November 2026, Basis `develop` `17121e40a49838f479d1655d88d354ed836ad20e`. Der unveränderte Ressourcenwrapper wurde tatsächlich erneut ausgeführt: **1.125 Assertions bestanden, 0 Fehler; 192 Matrixpartien und 7 zusätzliche Verifikationspartien**. Dies bestätigt den vorhandenen Alpha-Versuch auf dieser Basis. Es ist keine Balanceabnahme für die 550 Konzepte und keine Änderung der produktiven Ressourcenregeln.

Der übernommene [Rohbeleg](evidence/alpha-resource-experiments.json) enthält alle 192 Partien mit Seeds, Paarungen, Startseite, Sieger, Ereignis-/Zustandshashes, Ressourcennutzung und Quellfingerabdrücken. Dateihash SHA-256: `7623294cda6f8f588aafd30cae2953edbb0d6c5069b79ed810953733667b57d9`. Godot-Version: `4.6.3-stable (official)`. Regeln, Versuchsmethode und bestehende Grenzen sind ausführlich in [RESOURCE_EXPERIMENTS.md](../master550/RESOURCE_EXPERIMENTS.md) beschrieben.

## Versuchsbedingungen und Ergebnisse

Vier vorhandene 30-Karten-Starter ergeben 16 geordnete Paarungen. Vier ausgewählte Seeds je Paarung enthalten zwei Starts pro Seite; dieselben Seeds werden unter drei Ressourcenprofilen verglichen. Das ergibt 64 Partien je Profil. Die sieben zusätzlichen vollständigen Verifikationspartien prüfen Baseline-/Wiederholungsparität und zählen nicht zu den Siegraten. Die Profile sind gepaart; 192 Partien sind daher keine 192 unabhängigen Stichproben.

**Energie 8 / Resonanz 15 bleibt produktiv.** Energie 10 und Resonanz 20 existieren ausschließlich im Versuch. Die vorhandene KI spielt beide Seiten mit ihren bestehenden Entscheidungen; sie wurde für diese Auswertung nicht optimiert. Die Simulation nutzt den bestehenden Alpha-/Legacy-Kernel, keine zweite Kampfengine.

| Messgröße | E8 / R15, produktive Baseline | E10 / R15, Versuch | E10 / R20, Versuch |
|---|---:|---:|---:|
| Matrixpartien | 64 | 64 | 64 |
| Hero-/Enemy-Siege | 33 / 31 | 33 / 31 | 33 / 31 |
| Startspielersiege | 29/64 (45,31 %) | 29/64 (45,31 %) | 29/64 (45,31 %) |
| Konvergenzsiege | 12 (18,75 %) | 11 (17,19 %) | 12 (18,75 %) |
| Siege ohne Konvergenz | 52 | 53 | 52 |
| Halbzüge, Mittel / Median | 28,42 / 24 | 28,30 / 24 | 28,20 / 24 |
| Energieangebot | 10.856 | 12.263 | 12.193 |
| Energieverbrauch / Restenergie | 6.090 / 4.766 | 6.076 / 6.187 | 6.076 / 6.117 |
| Energienutzung | 56,10 % | 49,55 % | 49,83 % |
| Energie aus gerichteten Reaktionen | 0 | 0 | 0 |
| Resonanzgewinn / Verbrauch | 1.227 / 320 | 1.229 / 328 | 1.254 / 344 |
| Über der Obergrenze verlorene Resonanz | 28 | 28 | 0 |
| Resonanzmaximum, tatsächlich beobachtet | 15 | 15 | 19 |
| Mittlere Resonanz bei eigenem Zugbeginn | 4,47 | 4,43 | 4,46 |
| Entfesselungen / Reliktaktivierungen | 40 / 827 | 41 / 831 | 43 / 825 |
| Erfolgreiche Kartenausspiele | 2.342 | 2.335 | 2.338 |
| Unterschiedliche ausgespielte IDs | 40 | 40 | 40 |
| Konvergenzerklärungen / gescheiterte Erklärungen | 94 / 79 | 92 / 78 | 89 / 74 |
| Längste beobachtete Effektqueue | 10 | 10 | 10 |
| Enginefehler / zensierte Partien / Unentschieden | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 0 / 0 |

`round` zählt globale Halbzüge, keine vollständigen Zugpaare und keine reale Spielzeit. Hero und Enemy sind Simulationsseiten; Hero bedeutet nicht automatisch Startspieler. Die Kategorie „ohne Konvergenz“ ist aus der Siegerzahl minus Konvergenzsiegen abgeleitet. Die JSON-Zusammenfassung unterscheidet hierbei nicht zwischen direktem Heldenangriff, Effekt und Erschöpfung; eine genaue Quote direkter Angriffs-Siege lässt sich daraus nicht behaupten.

Die gepaarte Auswertung findet bei E10/R15 **0 von 64 geänderte Sieger und 2 geänderte Halbzugzahlen**, bei E10/R20 **0 von 64 geänderte Sieger und 4 geänderte Halbzugzahlen**. Mehr Energie blieb im vorliegenden günstigen Pool überwiegend ungenutzt. Diese Stichprobe beweist weder Gleichwertigkeit der Profile noch die Balance neuer Karten mit Kosten 9 oder 10. Die gesonderten synthetischen Kosten-9/10-Fixtures prüfen ausschließlich die Erreichbarkeit der Auffüllkurve; sie sind keine Sammelkarten.

## Auffälligkeiten und Abdeckungsgrenzen

| Macht | Nichtspiegel-Siege je Profil | Anteil |
|---|---:|---:|
| Zwölf Häuser | 7 / 24 | 29,17 % |
| Stillwacht | 10 / 24 | 41,67 % |
| Vielgestalt | 7 / 24 | 29,17 % |
| Neunte Stunde | 24 / 24 | 100 % |

Die Neunte Stunde gewinnt in jeder Bedingung alle 24 Nichtspiegelpartien. Das verlangt eine Untersuchung von Starterzusammensetzung, KI und Karteninteraktionen. Die kleine, fest ausgewählte Seedmenge erklärt die Ursache nicht und schätzt keine menschliche Metagame-Siegrate zuverlässig. Die drei Profile wiederholen dieselben Paarungen; die 24 Siege dürfen nicht zu 72 unabhängigen Erfolgen zusammengezählt werden. Auch die beobachteten 29/64 Startspielersiege belegen keine allgemeine Startspielerbalance.

**40 von 55 Alpha-IDs wurden tatsächlich ausgespielt.** Die Starter enthalten zusammen nur 41 unterschiedliche IDs. 14 Alpha-Karten kommen in diesen Decks gar nicht vor; die verbleibende ungenutzte Starterkarte ist `oa-ninth-e01` – Umleitung. Der schon dokumentierte Voraussetzungskonflikt bleibt offen: Umleitung benötigt ein eigenes verzögertes Ereignis, dessen einzige vorhandene Quelle einer anderen Macht angehört. Eine illegale Quermacht-Beimischung wird nicht als Lösung ausgegeben. Es wurden weder Umleitung noch Engine- oder Deckregeln geändert.

Die einmächtigen Starter lösen die zwölf gerichteten Legacy-Ordensreaktionen beim normalen Ausspielen nicht aus; deren Ressourcenbalance ist durch diese Matrix nicht geprüft. Die längste beobachtete Queue von zehn ist kein allgemeiner Beweis gegen unbegrenzte künftige Effektketten. Weitere Archetypen, die zehn Referenzdecks, neue Trigger und die 550 Vorschläge sind nicht Gegenstand dieses Laufs.

## Reproduktion und Laufhistorie

Aus dem Repository-Verzeichnis, mit Godot 4.6.3:

```sh
mkdir -p work/production work/xdg/data work/xdg/config work/xdg/cache
export XDG_DATA_HOME="$PWD/work/xdg/data"
export XDG_CONFIG_HOME="$PWD/work/xdg/config"
export XDG_CACHE_HOME="$PWD/work/xdg/cache"
export LP_NUM_THREADS=2
godot --headless --editor --path . --import > work/production/resource-reproduce-import.log 2>&1
bash tools/test_master550_resources.sh > work/production/resource-reproduce.log 2>&1
```

Der Wrapper schreibt `work/master550/resources.log` und `work/master550/resource_experiments.json` und prüft Fehler, Assertions sowie die vollständige Partienzahl. Die Reproduktionsbefehle verwenden neue äußere Lognamen, damit die vorhandene Laufhistorie erhalten bleibt.

Der erste Versuch vor dem Godot-Import war wegen fehlender importierter Audioressourcen nicht erfolgreich und wurde beendet. Das erhaltene äußere Log `work/production/resource-run.log` enthält nur `Terminated`; es bewahrt keine vollständige Audiofehlerdiagnose. Nach dem Import bestand der erneute Lauf vollständig; `work/production/resource-retry.log` enthält die Erfolgsmeldung und die vollständige Zusammenfassung. Beide vorhandenen Logs bleiben unverändert im ignorierten Arbeitsbereich. Die Importprotokolle enthalten zusätzlich Sandbox-TCP-Listenfehler; diese werden nicht als bestandene Importfehlerprüfung ausgegeben. Der erfolgreich geprüfte Ressourcenlauf selbst enthält keine Enginefehler.

**Getestet:** vorhandene Alpha-Ressourcenmatrix und ihre Regressionen. **Veröffentlicht:** durch dieses Paket nichts. **Offen:** belastbare Balance weiterer Decks, Ursachenanalyse der Neunte-Stunde-Dominanz, Umleitung und der vollständige Produktionskartenpool. Eine Ressourcen- oder Kartenänderung erfordert einen neuen passenden Lauf.
