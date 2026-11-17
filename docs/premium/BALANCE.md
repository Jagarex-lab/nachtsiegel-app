# Gemessene Korrektur des Block-Referenzdecks

## Entscheidung und tatsächlicher Umfang

Das bestehende `prod-block`-Referenzdeck erhält **acht ausgetauschte Kopien vorhandener Karten**. Es behält 22 seiner 30 Kopien, 24 Karten mit Blockerzeugung, beide bisherigen Block-/Angriffswachstumsrelikte und seine Stillwacht-Identität. Der automatische Generator und die generierte Liste stimmen überein. Die anderen 13 Referenzdecks und alle vier sichtbaren Starter bleiben unverändert.

Es wurden **keine Kartenwerte, Kosten, Fähigkeiten, Ressourcenregeln, Siegbedingungen, Kampfpfade oder KI-Bewertungen verändert**. Insbesondere gelten weiterhin direkte Heldenangriffe bei leerem Gegenfeld und die vorhandene Reihenfolge Block → Schild → Leben. Es gibt keinen pauschalen Neunte-Stunde-Nerf. Der Befund betrifft eine schwache konkrete Referenzliste und beweist keine vollständige Balance des 550-Karten-Pools.

## Vorab festgelegter Test

Der historische Acht-Kopien-Vorschlag aus der Alpha-0.3-Diagnose wurde anhand seiner tatsächlichen Datei geprüft. Seine alte Ausgangsliste stimmt bytegenau mit `data/production/test_decks.json` des öffentlichen Commits `10782185cf41f2013607ba47da0bbfcb737e89e2` überein. Die alte 12-Fälle-Beobachtung 0/12 → 4/12 war nur der Anlass für den neuen Test und wird nicht als frischer Nachweis gezählt.

Die neuen Kandidatenkarten wurden vor dem ersten Spiel in die kanonische Sortierung des bestehenden Generators gebracht. Die historischen angehängten Kartenpositionen wurden deshalb nicht als identische Ziehreihenfolge ausgegeben.

Der vor Spielbeginn gespeicherte Plan umfasst:

- Alle 14 ursprünglichen Referenzgegner, einschließlich eines unveränderten Blockdecks als Kontrollgegner.
- Beide Spielfeldseiten, beide Startmünzen und zwei getrennte Seedblöcke pro Kombination: 112 A/B-Paare.
- Für jedes Paar exakt denselben Seed und dieselbe tatsächliche Startseite in beiden Varianten. Seeds wurden ausschließlich anhand der Eröffnungsmünze gesucht, ohne abgeschlossene Partieergebnisse anzusehen. Die Suchbereiche überschneiden sich nicht.
- 224 vollständige Matrixpartien plus acht weitere vollständige Wiederholungen mit frischem Modellkonstruktor. Endzustand, vollständige geordnete Ereignisse und RNG-Zustand/-Aufrufzahl müssen exakt übereinstimmen.
- Auf beiden Seiten dieselbe unveränderte öffentliche Production-KI auf Stufe 2. Der Test verwendet direkt den vorhandenen Produktionskernel und dessen normale legalen Aktionen, keine zusätzliche Kampfengine und keinen historischen Beobachter mit verborgenen Handdaten.

Vorab galt eine Übernahme nur bei mindestens 12 zusätzlichen Siegen, einem diagnostischen gepaarten Vorzeichentest ≤ 0,05, keiner Verschlechterung in einer der beiden Spielfeldrollen und vollständig erfolgreichen, unzensierten Partien ohne Enginefehler oder erreichtes KI-Aktionslimit. Diese Kriterien wurden nach Betrachtung des Ergebnisses nicht abgesenkt.

## Ergebnis

| Beobachtung | Bisherige Liste | Kandidat |
| --- | ---: | ---: |
| Siege / 112 Partien | 29 / 112 (25,9 %) | 43 / 112 (38,4 %) |
| Siege auf der Hero-Seite / 56 |12 |20 |
| Siege auf der Enemy-Seite / 56 |17 |23 |
| Siege als Startspieler / 56 |16 |23 |
| Siege als Zweitspieler / 56 |13 |20 |
| Vorab gewählte Pilotgruppe / 12 |0 |5 |
| Mittlere Halbzüge |31,05 |31,12 |
| Reliktaktivierungen |104 |200 |
| Beobachteter Netto-Resonanzabgang erfolgreicher Aktionen |214 |594 |
| Bekannte Kartenkosten / beobachtete Energie zu Aktionsbeginn |70,1 % | 55,4 % |

**+14 Siege beziehungsweise +12,5 Prozentpunkte.** 27 Paare wechseln zugunsten des Kandidaten, 13 zugunsten der alten Liste. Der einseitige gepaarte Vorzeichentest ergibt 0,01924. Beide Spielfeldrollen verbessern sich. Die vorab festgelegten Kriterien sind erfüllt.

Die Energiekennzahl verschlechtert sich ausdrücklich. Der günstigere frühe Aufbau lässt später mehr Energie ungenutzt; der Sieggewinn entsteht zusammen mit häufiger nutzbarer Resonanz und Reliktaktivierung. Die Kennzahl ist keine vollständige Bilanz aller Energiequellen oder ausgegebenen Ressourcen. Es werden keine Ressourcenregeln geändert, um diese Zahl nachträglich schöner aussehen zu lassen.

| Gegner | Bisherige Siege / 8 | Kandidatensiege / 8 |
| --- | ---: | ---: |
| Aggro |1 |4 |
| Midrange |2 |3 |
| Kontrolle |1 |1 |
| Schild |7 |5 |
| Ursprüngliches Blockdeck |5 |6 |
| Wiederkehr |1 |1 |
| Resonanz |1 |1 |
| Positionswechsel |3 |6 |
| Wesensarten |2 |1 |
| Relikt |0 |4 |
| Impulse |1 |5 |
| Konvergenz |4 |3 |
| Zeit |0 |1 |
| Ressourcen |1 |2 |

Das Deck bleibt unter anderem gegen Zeit, Resonanz und Kontrolle schwach. Schild-, Arten- und Konvergenzpaarungen verschlechtern sich teilweise. Acht Spiele je Gegner sind zu wenig für eine sichere einzelne Matchup-Aussage; diese Grenzen werden nicht durch eine globale Erfolgszahl verdeckt.

## Konkreter Listentausch

| Entfernt | Kopien | Hinzugefügt | Kopien |
| --- | ---: | --- | ---: |
| Schneewurzel (`of-stillwatch-016`) |2 | Pfadkundiger (`oa-neutral-c01`) |2 |
| Panzerhüter (`of-stillwatch-026`) |2 | Wanderfeuer (`of-neutral-049`) |2 |
| Stiller Doppelgänger (`of-stillwatch-017`) |1 | Resonanzträger (`oa-neutral-c09`) |2 |
| Grenzbewahrer (`of-stillwatch-021`) |1 | Gläserner Grenzstein (`of-stillwatch-049`) |2 |
| Aufgefangener Schlag (`of-stillwatch-075`) |1 | — |— |
| Eiserne Pause (`of-stillwatch-078`) |1 | — |— |

Die mittleren Energiekosten sinken von 3,57 auf 2,97. Karten bis einschließlich 2 Energie steigen von 9 auf 17. Die Mischung verändert sich von 21 Wesen / 7 Impulsen / 2 Relikten auf 23 / 5 / 2. Beide vorhandenen `of-stillwatch-097` bleiben erhalten. Es entsteht weder ein neues Deckformat noch ein zweiter Reliktplatz.

## Quellen, Wiederholung und Abgrenzung

Die ursprünglichen Gegnerlisten liegen als ausdrücklich benanntes Testfixture in `tools/premium/block_reference_baseline.json`. Es enthält Referenzdecks, keine neuen Kartendefinitionen und keinen zusätzlichen aktiven Pool. Der Driver prüft dessen ursprünglichen SHA. Auch nach Übernahme des neuen Blockdecks bleibt der A/B-Vergleich ausführbar; alle anderen aktiven Referenzobjekte müssen weiter exakt der Kontrolle entsprechen.

Der erste vollständige 224+8-Lauf fand vor der Übernahme statt. Nach der Änderung von Generator und generierter Liste wurde der vollständige Vergleich erneut auf den neuen Quellen ausgeführt. Die zweite Serie ist der maßgebliche gebundene Nachweis. Die erste Serie bleibt separat erhalten; beide Serien werden ausdrücklich nicht als 464 unabhängige Strategiepartien addiert. Die zusätzlichen Kontrollen prüfen vollständige deterministische Simulationsdurchläufe; Session-/Replaydateien haben weiterhin eigene Regressionstests.

- [Gebundene Zusammenfassung](balance/block-summary.json) mit exakten Quellenhashes und Rohbericht-SHA.
- [Vor Spielbeginn gespeicherter Plan](balance/block-plan.json).
- [Alle 224 tatsächlichen Matrixergebnisse](balance/block-games.jsonl) mit Ereignis-, Zustands- und RNG-Nachweisen.
- [Acht frische vollständige Wiederholungen](balance/block-verification.jsonl).
- Vollständiger Rohbericht, Journal und Logs: `work/premium-balance/`; der erste Lauf bleibt unter `work/premium-balance-before-promotion/` erhalten.

```sh
# Godot 4.6.3; vollständiger Checkout mit öffentlicher Baselinehistorie.
godot --headless --editor --import --path . --audio-driver Dummy --quit
bash tools/test_premium_block_balance.sh

# Optional die kompakten öffentlichen Nachweise aus dem tatsächlichen Lauf erzeugen:
python3 tools/premium/report_block_balance.py --check-sources --verify-rejections \
  --output docs/premium/balance/block-summary.json \
  --evidence-dir docs/premium/balance
```

Zusätzliche Datenregressionen prüfen die Originaldatei aus 10782185, den exakten Acht-Kopien-Tausch, Blockidentität, alle Kopien-/Machtregeln, die unveränderten anderen 13 Listen und die Generatorreproduktion. Die 550 Kartendaten und vier Starter sowie Regeln und KI werden bytegenau mit derselben Baseline verglichen. Der Reporter weist 16 gezielt beschädigte Kopien der tatsächlich erzeugten Nachweise zurück; diese Gegenproben sind keine zusätzlichen gespielten Partien.

Die vorhandene vollständige 848er-Matrix und die breiteren Ressourcen-, Kartenfähigkeits-, Legacy-, Replay- und Full-Pool-Tests werden dadurch nicht ersetzt. Nach Integration muss die vollständige CI auf dem exakten neuen Commit erneut laufen. Die frische vorherige Referenzmatrix meldete insbesondere 538 / 848 Startspielersiege, 59,4 % beim Neunte-Stunde-Starter und 68,8 % beim Zeit-Referenzdeck. Das sind andere Listen-/Seedbedingungen als dieses gepaarte Experiment; die absoluten Block-Siegquoten sind deshalb nicht unmittelbar gegeneinander austauschbar.

Weiter offen bleiben menschliche Balancepartien, größere unabhängige Seedmengen, andere KI-Policies und die kausale Isolierung des Startspielervorteils. Der feste zentrale Hero-Ursprung und die bestehende autonome Enemy-Eröffnung unterscheiden sich weiterhin. Die Ausgangsmünzen-Auswahl konditioniert die Stichprobe. Der Vorzeichentest ist ein Diagnosemaß, keine Bescheinigung kommerzieller Gesamtbalance und keine physische Geräteprüfung.
