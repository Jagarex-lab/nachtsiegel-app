# Balance-Smoke – kein Turniernachweis

`tests/alpha_rules.gd` erzeugt `work/alpha/simulations.json`:4×4 Machtpaarungen, je zwei deterministisch ermittelte Seeds mit unterschiedlichen Startspielern, jeweils mit/ohne Konvergenz. 64 vollständige Partien;32 Starts pro Seite. Dieselben Paarungsseeds für beide Varianten. Keine Timeouts als Siege gezählt. Seeds/Startspieler/Verbrauch/Karten/Schaden/Queue-Länge/Fehler und Ergebnis je Partie im JSON.

| Profil | Partien | Hero-Siege | Startspieler-Siege | Halbzüge min/Median/max | Konvergenzsiege | Fehler |
|---|---:|---:|---:|---|---:|---:|
| alpha_collapse | 32 | 18 | 18 | 15/27.0/152 | 0 | 0 |
| alpha_convergence | 32 | 20 | 16 | 15/24.5/76 | 9 | 0 |

Konvergenz:49 Erklärungen,9 Erfolge,40 gescheiterte Bindungen. Die Hauptphase-Zählung ist der Halbzugindex, keine Behauptung ebenso vieler vollständiger Runden. Getrennte Legacy-Referenzserie:24 Partien,705 Spielerkommandos inklusive deterministischer KI-Folgen; keine direkte Balance-A/B-Aussage zwischen unterschiedlichen Regeln/Decks.

Erkannt: einzelne Collapse-Partien dauern bis152 Halbzüge; Häuser-Spiegel kann Ressourcen lange wiederverwenden. Konvergenz verkürzt den Median dieser kleinen Stichprobe. Hero gewinnt38/64, aber diese Zahl ist durch deterministische Steuerung, Deckpaarungen und nur zwei Seeds je Paarung beeinflusst. Keine47–53%-Balancebehauptung, kein Beleg gleicher Machtstärke und keine nachträgliche Kartenwertänderung zur Schönung. Nächster Schritt: mindestens250 gegen den Oracle und1000 breit gestreute Alpha-Partien, getrennte Schwierigkeits-/Macht-/Startspieler-Auswertung und menschliche Tests. Lange synthetische Effektketten separat bis100 geprüft; das ist kein Nachweis, dass normale Starter im Spiel hundert Effekte erzeugen.
