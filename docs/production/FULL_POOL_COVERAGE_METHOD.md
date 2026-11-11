# Full-Pool-Selbstspiel: vorab festgelegte Methode

Dieser zusätzliche Sampler untersucht breitere tatsächliche Interaktionen und
eine kleine Laufzeitstichprobe. Er verändert weder Produktionsengine noch KI,
Kartendaten, Regeln oder Ressourcenlimits. Er behauptet keine vollständige
550-Karten-Balance und ersetzt nicht die bestehende 848-Partien-Matrix.

## Decks und Umfang

`tools/production/build_full_pool_decks.py` erzeugt deterministisch 32 legale
30-Karten-Listen, acht je Macht mit neutralen Ergänzungen. Normale Karten kommen
höchstens dreimal, legendäre höchstens einmal vor. Jede Liste behält einen
Starter-Wesenkern und zwei Exemplare eines tatsächlich vorhandenen Relikts mit
wiederkehrender Angriffserhöhung. Diese regulären Siegpläne verhindern keine
Abbrüche per Definition: Jeder auftretende Stalemate bleibt ein Befund.

Die Listen enthalten zusammen alle 550 IDs. Das ist ausschließlich eine
Eigenschaft der Listen. Für Ausspielabdeckung zählen später nur erfolgreich
beobachtete `play`-Kommandos. Beschworene Quellen und tatsächlich abgearbeitete
generische Effekte werden separat ausgewiesen. Alle nicht ausgespielten IDs
bleiben ausdrücklich aufgelistet.

Jede Liste spielt als Hero gegen zwei vorab definierte Listen: denselben lokalen
Index der nächsten Macht sowie den um drei versetzten Index der übernächsten
Macht. Dies ergibt 64 gerichtete Paarungen. Je Paar werden durch echte
Eröffnungen die ersten zwei Seeds mit Hero beziehungsweise Enemy als erster
Sitzposition gewählt. Die vollständigen 256 Fälle werden samt Decklistenbindung
in eine eigene Plandatei geschrieben und gehasht, bevor die erste vollständige
Partie beginnt. Jede Liste hat dadurch 16 Sitzteilnahmen und begegnet insgesamt
allen drei anderen Mächten. Eröffnungsproben sind keine gespielten Partien.

256 Partien sind ein begrenzter Zusatz zu den 848 Referenzpartien: genügend
Wiederholungen je Expositionsdeck für häufigere Ausspielgelegenheiten, aber keine
erschöpfende Paarungsmatrix und keine unabhängigen menschlichen Beobachtungen.

## Engine, Kontrollen und Nachweise

`tests/production_full_pool_coverage.gd` erbt den vorhandenen realen Aufbau,
Zugablauf und die Beobachtungen aus `production_simulations.gd`. Es gibt keine
zweite Kampfengine und keine vereinfachte Siegerberechnung. Die unveränderten
Runtime-, KI-, Daten- und geerbten Harness-Dateien werden zusätzlich gegen den
Core-Commit `d3c7c7bf1e2d714aef896d39538bfd343d2365c2` geprüft.

Acht vorab bestimmte Fälle werden erneut gespielt; vier weitere Kontrollen
verwenden den gewöhnlichen frischen Modellkonstruktor statt eines übergebenen
Konfigurationstemplates. Diese Kontrollen zählen getrennt von den 256
Matrixpartien. Sie vergleichen vollständige Endzustands-/Ereignisdigests sowie
sämtliche deterministischen Beobachtungen; nur gemessene Wandzeit ist aus dem
Vergleich ausgenommen. Unveränderliche Katalog-Caches dürfen weiterhin bestehen.

Jede Partie protokolliert Listenidentitäten, Seed, tatsächliche Startseite,
Sieger, Halbzüge, Fehler/Zensierung, erfolgreiche Kartenausspielzahlen,
generische Effekt-/Statuszahlen, native Ereignisarten, Ressourcenbeobachtungen
und vollständige Zustands-/Ereignisdigests. Energiezahlungen umfassen bekannte
gedruckte Kartenkosten; Resonanz ist eine Nettobeobachtung je KI-Aktion. Beides
ist keine vollständige Bruttoflussbilanz. Wandzeit umfasst Aufbau, Eröffnung und
tatsächliche Partie bis zum Ende des geerbten Ablaufs, keine garantierte Leistung
auf anderer Hardware oder unter anderer Systemlast.

Die 500 Hero-KI-Aufrufe sind ausschließlich eine technische Grenze. Eine dort
nicht beendete Partie bleibt zensiert und erhält keinen erfundenen Sieger. Fehler
und zensierte Fälle werden erhalten und machen den Lauf nicht bestanden.
Abgeschlossene Versuche werden einzeln in ein geflushtes JSONL-Journal
geschrieben. Nach externem Abbruch bleiben Plan und tatsächliche fertige
Versuche erhalten; fehlende Fälle heißen nicht abgeschlossen oder nicht
ausgeführt. Eine teilweise begonnene Partie ist damit kein behauptetes Ergebnis.

Alle 20 gebundenen Quellen werden vor und nach dem Lauf gehasht. Der Wrapper
bindet zusätzlich den tatsächlich ausgeführten Git-Commit. Beschädigte Kopien
echter Nachweise prüfen, dass fehlende/doppelte Fälle, falsche Startseiten,
gemischte Quellen, manipulierte Kontrollen und vorgetäuschte Abdeckung abgewiesen
werden. Diese Integritätsprüfungen erzeugen keine weiteren gespielten Partien.

## Reproduktion und begrenzte Ausführung

```sh
python3 tools/production/build_full_pool_decks.py --check
LP_NUM_THREADS=1 bash tools/test_production_full_pool_coverage.sh
```

Der Wrapper verwendet eine einzelne Headless-Instanz mit `nice -n 10`, schreibt
in `work/production/full-pool-coverage*` und bewahrt frühere Versuche vor einem
Neustart. Ein fehlgeschlagener oder unterbrochener Lauf darf nicht als bestanden
bezeichnet werden. Der vollständige Bericht nennt tatsächlich ausgespielte und
nicht ausgespielte IDs, getrennt von den 550 Listenmitgliedern.

Eine erste reine Planungsprobe beendete sich wegen fehlendem schreibbarem
XDG-Daten-/Fontcache vor dem Engine-Test. Das Infrastrukturprotokoll blieb
erhalten; der Wrapper verwendet nun eigene schreibbare XDG-Verzeichnisse. Dieser
Versuch und die anschließende reine Planungsprüfung zählen keine vollen Partien.
