# Alpha 0.3: Balancing-Prüfung und frischer Neunte-Stunde-Pilot

## Ergebnis und Entscheidung

**Kein pauschaler Neunte-Stunde-Nerf und keine Ressourcenänderung.** Die alte
24/24-Aussage aus dem frühen Pipeline-PR beschreibt nicht den aktuellen
550-Karten-Pool. Im neuen gepaarten Test gewinnt der Neunte-Stunde-Starter
13/24 Partien und das Zeit-Referenzdeck 18/32. Beide gewinnen häufiger mit der
komplexeren bestehenden KI-Policy. Ein klarer Startspieler- und Deckeffekt
bleibt sichtbar. Das ist ein Befund für weitere gezielte Tests, kein Beweis,
dass alle 550 Karten ausbalanciert wären.

Es wurden keine Karten, Werte, Decklisten, Regeln, Ressourcen oder
Produktions-KI verändert. Die kleine, korrelierte Stichprobe rechtfertigt keine
willkürliche Schwächung einer ganzen Macht. Der vorhandene 8/15-Default bleibt.

## Tatsächlich neu ausgeführt

Quellen: lokaler Integrationsstand `9c23578188650ac1969d7d373783e2b4f2b98eb4`
vor den neuen Safari-, Kampagnen-, Economy- und Online-Anpassungen. Vollständige
SHA-256 aller 18 ausgeführten Quell-/Datendateien sind im Rohbericht gebunden.
Diese Nachweise dürfen nicht als frische Abnahme später geänderter Quellen
umetikettiert werden; auf dem endgültigen Integrationscommit ist die
vollständige CI erneut erforderlich.

- **314 Engineprüfungen, 0 Fehler.** 56 neue vollständige Matrixpartien plus 4
  Wiederholungen mit frischem Modellkonstruktor:60 tatsächlich beendete Spiele.
- Keine Zensierung, kein Enginefehler und kein erreichtes KI-Aktionslimit.
- Beide Kartenlisten-, Sitz- und Startpositionen sind kontrolliert. Neunte-Stunde-
  Starter und Zeitdeck spielen gegen die drei anderen Starter; das Zeitdeck
  zusätzlich gegen das starke Häuser-Reliktdeck. Beide Richtungen und beide
  Startmünzen werden unter den bestehenden Schwierigkeitsstufen 1 und 5 gespielt.
- Die Seeds 930017 und 930018 wurden ausschließlich nach der Startmünze gewählt,
  bevor die erste Partie lief. Die gleichen Seeds zwischen Paarungen erzeugen
  bewusst gepaarte, korrelierte Fälle; es sind keine 56 unabhängigen Zufallsseeds.
- Vier erneute Partien bestätigen vollständige Endzustands- und geordnete
  Ereignisdigests bytegenau. Eröffnungsproben zählen nicht als Partien.
- **Sieben Python-Integritätstests** prüfen beschädigte Nachweiskopien, darunter
  fehlende/zensierte Partien, falsche Startseite und manipulierte Replaydigests.
  Diese strukturellen Unit-Tests sind keine gespielten Partien.

| Deck | Partien | Siege | Stufe1 | Stufe5 | Siege als Startspieler / Startteilnahmen |
|---|---:|---:|---:|---:|---:|
| Neunte-Stunde-Starter |24|13 (54,2%)|4/12|9/12|8/12|
| Zeit-Referenzdeck |32|18 (56,3%)|7/16|11/16|12/16|
| Zwölf-Häuser-Starter |16|6|5/8|1/8|5/8|
| Vielgestalt-Starter |16|8|5/8|3/8|5/8|
| Stillwacht-Starter |16|8|5/8|3/8|6/8|
| Häuser-Reliktdeck |8|3|2/4|1/4|1/4|

56 Partien erzeugen 112 Deckteilnahmen; die Zeilen sind keine zusätzlichen
Spiele. Gegen das Häuser-Reliktdeck gewinnt das Zeitdeck 5/8. Ein universell
überlegenes Relikt- oder Zeitdeck folgt daraus gerade nicht.

Startspieler gewinnen 37/56 (66,1%); fünf Partien enden durch Konvergenz.
Der Mittelwert liegt bei 21,64 Halbzügen; eine menschliche Spielzeit wurde nicht gemessen. Beide
Siegbedingungen bleiben aktiv. Die unterschiedliche Eröffnungsheuristik
(fester zentraler menschlicher Ursprung gegenüber autonomem Gegnerursprung)
verhindert eine saubere kausale Isolation des Startspielerbonus. Die beiden
Policy-Stufen sind Varianten derselben heuristischen KI, keine menschlichen
Experten oder unabhängig entwickelten Suchagenten.

Die tatsächlich längste generische Kette enthält fünf Einträge, die längste native
zwei. Dieser Pilot beweist daher keine natürliche Zehnerkette; dafür bleiben
die separaten Effektketten-Regressionen erforderlich. 87 unterschiedliche IDs
wurden tatsächlich gespielt; die Resonanz an beobachteten Aktionsgrenzen
erreichte höchstens 15.

## Bestehende Nachweise richtig einordnen

Die vollständige semantisch korrigierte 848er-Matrix ist historisch erhalten:
Roh-SHA-256 `5315796e48eb14c9428a0efb8f9a89f1ce2f4b9a928a8e396ea6241eba0da6d8`.
Sie ist nicht mit einem älteren lokalen 848er-Lauf mit 528 statt 538
Startspieler-Siegen zu verwechseln. Sie meldet:

| Referenz | Siege / Teilnahmen |
|---|---:|
| Neunte-Stunde-Starter |19/32 (59,4%)|
| Zeitdeck |77/112 (68,8%)|
| Resonanzdeck |77/112 (68,8%)|
| Ressourcendeck |72/112 (64,3%)|
| Häuser-Reliktdeck |82/112 (73,2%)|
| Blockdeck |16/112 (14,3%)|
| Schilddeck |37/112 (33,0%)|

Dort gewinnt der Startspieler 538/848 (63,4%). Die Tabelle betrifft konkrete
Listen und die dortige Policy, keine isolierte Bewertung aller Karten einer
Macht. [Der volle bestehende Bericht](../production/BALANCE_REPORT.md) enthält
Messgrenzen und Quellenbindung.

Der vorhandene [Ressourcenvergleich](../production/RESOURCE_MODEL_EXPERIMENT.md)
prüfte 192 echte Matrix- und 10 Kontrollpartien:8/15,10/15 und 10/20. Er empfiehlt
weiterhin 8 Energie/15 Resonanz. Höhere Limits erzeugen andere Verläufe, aber
keinen hinreichenden Vorteil für eine Regeländerung. Diese202 historischen
Spiele werden nicht zu den 60 neuen addiert.

Der [Full-Pool-Sampler](../production/FULL_POOL_COVERAGE_METHOD.md) deckte 256
Matrix- und 12 Kontrollpartien mit 32 legalen Decks ab, 546/550 tatsächlich
beobachtete Ausspiel-IDs und 8.914 Ausspielkommandos. Listenabdeckung aller 550
ist von tatsächlich ausgespielten IDs zu unterscheiden. Auch diese 268 Spiele
sind separat und kein neuer Nachweis dieses Piloten.

## Konkrete nächste Balancing-Arbeit

1. Die vorhandene Block-/Schild-Schwäche ist real in den gebundenen
   Referenzlisten. Die lokale historische Deckdiagnose fand einen legalen
   Acht-Kopien-Blockkandidaten: weniger teure reine Verteidigung, mehr frühe
   Wesen, nutzbare Resonanz und Angriffswachstum. Zwölf gepaarte Pilotfälle
   verbesserten sich von 0/12 auf 4/12. Das ist ein Kandidat für eine neue volle
   Matrix, keine ausreichend validierte Produktionsübernahme.
2. Eine heuristische Wachstumsvorziehung installierte Wachstumsrelikte früher,
   korrigierte aber nur 2/24 selektierte Niederlagen. Die willkürliche +8-
   Bewertungszugabe wird deshalb nicht ausgeliefert. Sie könnte gerade das
   ohnehin starke Reliktdeck weiter verbessern.
3. Den klaren Zusammenhang zwischen Neunte-Stunde-Ergebnissen und Policy-
   Stufe durch gezielte Entscheidungsreplays prüfen: Resonanzverwendung,
   verzögerte Treffer, Zieh-/Reliktkombinationen und Konvergenzabwehr. Aus den
   vorliegenden Siegen lässt sich keine einzelne überstarke Karte ableiten.
4. Den Startspielereffekt mit symmetrischen Ursprung-, Mulligan- und
   Zweite-Möglichkeit-Policies, mehr unabhängigen Seedblöcken und echten
   Testpartien untersuchen. Kein eigenmächtiger Eingriff in Ursprungsschild,
   zweite Chance oder Konvergenz.
5. Erst einen vorab definierten Deckkandidaten gegen alle 14 Referenzen prüfen,
   anschließend die vollständige 848er-Matrix auf exakt neuen Quellen. Die
   jetzigen Warnwerte müssen bis dahin sichtbar bleiben.

Der historische Diagnoseordner ist lokal unter
`/workspace/tmp/balance-policy-review` erhalten. Dessen Helfer-Review und
unterbrochene Nachverifikation sind ausdrücklich dokumentiert. Er ist kein
zusätzlicher veröffentlichter oder vollständig neu verifizierter Alpha 0.3-
Balancebeweis.

## Reproduktion und Artefakte

```sh
bash tools/test_alpha03_balance.sh
```

Rohbericht: `work/alpha03/balance-fresh.json`, SHA-256
`22dd1bb129ff3204cb6862bcc360fc34e25b221cb3b8b9f54770a0123066ca7b`.
Der eingecheckte [Rohbericht](balance-fresh-results.json),
[Plan](balance-fresh-plan.json) und
[kompakte Bericht](balance-fresh-summary.json) erhalten alle tatsächlich
beobachteten Fälle. Der vorhandene Legacy-Differentialtest, vollständige
Kartenfähigkeitstests, UI-Prüfungen und Release-Safety werden dadurch nicht
ersetzt oder abgeschaltet.
