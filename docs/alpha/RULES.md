# Regelprofile

## Trennung

`legacy-34b3062` folgt ausschließlich duel-deck Commit `34b3062c3f22c0950d9323ad9b97b17c41d1d14f`. Original-IDs/Werte, Deckgrößen20–25, Beschwörungslimit2, alte Energie-, Kontrollserien-, Ressourcen- und Effektregeln bleiben erhalten. Originalquelle unter `tests/reference/duel_deck/`; unveränderte Pin-/Hashprüfung durch `tools/test_legacy.sh`.

`orafold-alpha-0.1` verwendet ausschließlich `data/alpha/cards.json`. Alpha-Anpassungen sind keine Änderungen der Legacy-Referenz.

## Alpha-Eröffnung

30 Karten mit einer gewählten Macht; alle nichtneutralen Karten müssen zu dieser Macht gehören. Neutrale Karten sind zusätzlich erlaubt; höchstens3 identische Karten, Legendäre höchstens1. Beide Helden30 LP; beide ziehen fünf Karten. Einmaliger Mulligan ausgewählter verschiedener Handindizes: Ersatz aus verbleibendem Deck ziehen, danach zurückgelegte Karten einmischen. Leere Auswahl verbraucht kein zusätzliches RNG. KI tauscht teure Karten. Erst danach entscheidet der gemeinsame deterministische Seed den Startspieler.

Beide wählen verdeckt einen Ursprungspfad, anschließend gemeinsame Aufdeckung. Die erste dort eigene beschworene/zurückgeholte Kreatur erhält einmal einen Punkt Kreaturenschutz; die Nutzung wird pro Spieler vermerkt. Der zweite Spieler kann einmal seinen Ursprung ändern und einmal genau eine Handkarte tauschen; beides optional. Erster Spieler zieht in seinem ersten Zug nicht, zweiter zieht eine Karte.

## Züge und Ressourcen

Ziehen → Hauptphase → links-nach-rechts Angriff → Gegnerbeginn. Energie steigt pro eigenem Zug1→8 und verfällt am Zugende. Resonanz ist unabhängig, cap15; Heldenschild cap25. Handlimit6; notwendiges Verbrennen ist vor regulärem Ziehen verpflichtend. Die bestehenden geordneten Ablage-, Erschöpfungs-, Kreislauf- und Rückholregeln werden explizit aus dem Kernel wiederverwendet; Effektziehen löst keinen kostenlosen Erschöpfungs-/Recyclingweg aus. Aktive Resonanzaktionen behalten ihre dokumentierten Kosten (Manöver3, Pfadwacht2, Rückholung und Entfesselung gemäß Kernel).

Fünf eigene und gegnerische Pfade. Ohne direkt gegenüberliegende Kreatur trifft ein Angriff den gegnerischen Helden: Block, dann Schild, dann LP gemäß Schadensart; Kreaturenschutz absorbiert Kreaturentreffer. Frisch beschworene Kreaturen warten, außer haste; Betäubung und Schwächung bleiben relevant. Keine zusätzliche Alpha-Beschwörungsanzahlgrenze neben Energie und freien Plätzen. Die16 Kreaturenfähigkeiten werden mit Alpha-Kartenparametern auf dem gemeinsamen Effektkernel ausgeführt.

Die vier Mächte sind Häuser/Stillwacht/Vielgestalt/Neunte Stunde. Zur Wiederverwendung der expliziten Reaktionseffekte gilt Häuser→thorn, Stillwacht→tide, Vielgestalt→veil, Neunte Stunde→ash. Neutrale Wechsel geben die regulären2 Resonanz, besitzen keine erfundene gerichtete Ordensreaktion. Mehrmachtdecks bleiben illegal.

## Ereignisse, Relikte und Reihenfolge

Ereignis: vor Zahlung vollständig Ziel/Parameter prüfen, zahlen, aus Hand entfernen, Effekt auflösen, ablegen. Zurückholung erzeugt eine neue Instanz-ID und löst Ankunft aus. Verzögerung bindet den Zielpfad und wird nach zwei Halbzuggrenzen ausgeführt; Umleitung ändert den ältesten eigenen verzögerten Eintrag. Zeitstillstand verhindert zwei relevante Angriffsgelegenheiten. Verdrängung nimmt den ersten freien angrenzenden Pfad. Zusätzliche Angriffe setzen eine kampffähige Einheit voraus, inklusive frischer haste.

Ein aktives Relikt pro Spieler. Neues Relikt ersetzt das alte in die Ablage. Aktivierung kostet1 Energie, einmal pro eigenem Zug; Ersetzen setzt die Nutzung nicht zurück. Ressourcen nur durch ausdrücklich aktivierte Effekte.

Logische Effekte laufen iterativ FIFO. Todes-/Ankunfts-/Formationsfolgen werden fertig abgearbeitet. Getestete Ketten10/25/50/100. Wiederholter vollständiger Zustand samt verbleibender Queue wird als Zyklusfehler explizit angehalten; technischer Guard10000 meldet ebenfalls Fehler statt Erfolg. Die maximal24 visuellen Jobs verändern keine Regeln.

## Konvergenz und Sieg

LP≤0 entscheidet vor Konvergenz; beide≤0 ergeben draw. Danach keine regulären weiteren Commands.

Nach fünf **vollständig abgeschlossenen** Runden (frühestens Runde6) kann der aktive Spieler in seiner Hauptphase Konvergenz erklären: genau drei verschiedene eigene kampffähige, unbestrittene Pfade. Dies beendet den Zug. Nach eigenen Angriffen werden dieselben drei Kreatureninstanzen gebunden. Der Gegner erhält einen vollständigen Zug. Erst beim nächsten Beginn des Erklärenden werden nach fälligen Ereignissen und LP-Prüfung dieselben Instanz-IDs, ihre Kampffähigkeit und freie Gegenpfade geprüft.

Tod, Ersetzung, Bewegung oder zwischenzeitlicher Verlust eigener Kampffähigkeit lösen die Bindung dauerhaft. Wiederbelebung erzeugt eine andere Instanz. Zwischenzeitliche gegnerische Besetzung allein ist kein dauerhafter Bruch: ist sie vor der abschließenden Prüfung verschwunden, kann die ursprüngliche Formation bestehen. Misslungene Konvergenz kann später neu erklärt werden. Die KI erklärt und verteidigt Konvergenz; Collapse-only-Simulationen deaktivieren ausschließlich diese Siegbedingung.
