# ORAFOLD – Verbindlicher Kartentext und Auswahlregeln

Diese Begriffe beschreiben das Produktions-Regelprofil. Sie behaupten keine bereits beschlossene Physik der Welt und keine vollständige Balance. Historische Legacy- und Alpha-Profile behalten ihre eigenen Regeltexte.

## Drei Kartentypen

**Wesen** besetzen einen der fünf Pfade. Sie besitzen Angriff, Leben und eine oder zwei gleichwertige Wesensarten. **Impulse** werden einmal ausgespielt; ihre Wirkung kann unmittelbar eintreten, verzögert gespeichert oder als ausdrücklich markierte Reaktion vorbereitet werden. **Relikte** verbleiben außerhalb der fünf Pfade. Pro Spieler ist höchstens ein Relikt aktiv. Die Installation eines neuen Relikts legt das bisherige Relikt ab; sie ist keine kostenlose Aktivierung.

Die technischen Datenbezeichnungen `creature`, `event` und `relic` sind diese drei Typen. `event` ist kein vierter Kartentyp.

## Ressourcen und Werte

**Energie** bezahlt das Ausspielen. Die zunächst erhaltene Kurve reicht von 1 bis 8 Energie; eine Erhöhung auf 10 wird hier nicht stillschweigend übernommen. Zusätzliche Energie gilt für den laufenden Zug und umgeht keine Obergrenze.

**Resonanz** ist eine gespeicherte strategische Ressource für Reaktionen, Entfesselungen und ausdrücklich bepreiste Fähigkeiten. Sie ist keine zweite Bezeichnung für Energie. Ein Karteneffekt mit „Erzeuge“ ist durch Ressourcengrenzen und die vermerkten Auslöselimits beschränkt.

**Schild** absorbiert Schaden vor Leben und verbleibt, bis es verbraucht oder entfernt wird. **Block** ist davon getrennt und endet nach seiner Regel, bei den hier verwendeten Helden-Blockeffekten spätestens zum nächsten eigenen Zugbeginn. Ein Kartentext „bis zu deinem Zugbeginn“ meint diesen nächsten eigenen Zugbeginn. Der direkte Heldenangriff durch einen leeren gegenüberliegenden Pfad bleibt erhalten; Schild und Block absorbieren nach dem vorhandenen Schadensverfahren. Effekte, die ausdrücklich Schutz umgehen, bleiben gesondert bezeichnet.

**Angriff** bezeichnet den aktuellen Angriffswert. **Leben** bezeichnet die aktuellen Lebenspunkte. Heilung überschreitet die maximalen Lebenspunkte nicht. Dauerhafte Angriffsänderungen sind an das betroffene Wesen gebunden und gehen beim Verlassen des Spielfelds verloren, sofern der Effekt nichts anderes bestimmt.

**Karte ziehen** verwendet die vorhandenen Stapel-, Hand- und Erschöpfungsregeln. Ein Kartentext muss nicht bei jedem Auftreten alle globalen Grenzen wiederholen. Eine volle Hand und ein leerer Stapel erzeugen keine erfundene zusätzliche Karte.

**Betäuben für N Angriffsphasen** setzt den Stasiszähler des betroffenen Wesens mindestens auf N. Eine übersprungene eigene Angriffsphase verbraucht einen Zählerpunkt. Eine vor dem Angriff ausgelöste Verteidigungsreaktion kann die gerade beginnende Angriffsphase verhindern; sie verbraucht dabei genau einen Punkt und erzeugt keinen unbezeichneten zusätzlichen Zug ohne Angriff.

## Wesensarten

Es existieren genau zwölf Arten: Menschen, Bestien, Geister, Konstrukte, Pflanzen, Amalgame, Morphiden, Paradoxe, Wiedergänger, Elementare, Zehrer und Mechanoide. Ein Wesen besitzt eine oder zwei verschiedene Arten. Beide gelten bei einer Auswahl wie „eigene Pflanzen“ vollständig und gleichwertig. Das erste Arrayelement ist keine Hauptart; zwei passende Arten bewirken nicht automatisch zwei Anwendungen desselben Effekts. Echo bleibt ein Lorebegriff und ist keine dreizehnte Art.

## Eindeutige Zielauswahl

| Kartentext | Auswahl |
|---|---|
| Dieses Wesen | Die konkrete auslösende Instanz; eine später auf denselben Pfad gelegte Karte erbt ihre Effekte nicht |
| Direkt gegenüberliegendes gegnerisches Wesen | Der gegnerische Platz auf demselben Pfad; fehlt das Wesen, erzeugt dieser reine Wesen-Effekt keinen ungekennzeichneten Heldenersatz |
| Gegnerischer Pfad | Der beim Ausspielen gewählte Pfad; bei Wesen ein von ihrer auslösenden Instanz gebundener Pfad. Ein ausdrücklich so formulierter leerer Pfad trifft den gegnerischen Helden |
| Wesen mit dem wenigsten Leben | Niedrigste aktuelle Lebenspunkte unter gültigen Wesen der angegebenen Seite; Gleichstand wird von links nach rechts entschieden |
| Eigene Nachbarwesen | Die unmittelbar benachbarten eigenen Pfade; keine Umwicklung von Pfad 5 zu Pfad 1 |
| Alle eigenen Wesen einer Art | Jedes gültige eigene Wesen, das diese Art als eine seiner höchstens zwei Arten besitzt; jedes höchstens einmal |
| Erster freier eigener Pfad | Von Pfad 1 nach Pfad 5; bei vollem Feld wird kein Wesen überschrieben |
| Zuletzt abgelegtes eigenes Wesen | Rückwärts durch den Ablagestapel suchen, Impulse und Relikte überspringen; die Karte wird auf die Hand genommen, nicht direkt beschworen |
| Einen Pfad nach links/rechts | Genau ein benachbartes Feld; nur wenn es innerhalb der fünf Pfade liegt und frei ist |

Eine Instanzkennung und ihre Seite gehören zur Zielbindung. Ein ungültig gewordenes Ziel wird bei der Auflösung erneut geprüft; sein Ersatz auf demselben Feld ist nicht dasselbe Ziel. Automatische Mehrfachziele werden deterministisch von links nach rechts bearbeitet.

## Auslöser und Limits

Das Muster lautet **Auslöser: Effekt.** „Beim Ausspielen“ ist nicht dasselbe wie „Beim Beschwören“: Ein durch einen Effekt beschworenes Wesen wurde nicht aus der Hand ausgespielt.

Unterstützte Auslöser im Datenvertrag sind Ausspielen, Beschwören, Angreifen, Verteidigen, Schaden verursachen, Schaden erleiden, ein Wesen besiegen, selbst besiegt werden, eigener Zugbeginn, eigenes Zugende, Pfadwechsel, Kartenziehen, Abwerfen, Resonanz ausgeben, Relikt aktivieren und das Erreichen einer definierten Bedingung. Der Nachweis eines Eintrags im Datenvertrag ersetzt keinen automatisierten Ausführungstest dieses Auslösers.

Wesen beobachten bei Angriff, Verteidigung, Schaden, Besiegen und Pfadwechsel ihre eigene Instanz. Ein aktives Relikt beobachtet entsprechend eigene Wesen. Bei Ziehen, Abwerfen, Resonanzausgabe und Reliktaktivierung wird die ausdrücklich eigene Seite beobachtet. „Wenn ein eigenes Wesen …“ bezeichnet diese Beobachtung und keine zusätzliche manuelle Reaktion.

**1× pro Zug** begrenzt die jeweilige Fähigkeit einer konkreten Quelle innerhalb des laufenden Spielzugs. „Jede Fähigkeit 1× pro Zug“ am Ende einer Karte gilt getrennt für alle dort abgedruckten Fähigkeiten; die erste Auslösung verbraucht nicht automatisch die anderen Fähigkeiten. Der Wechsel in eine neue Runde beseitigt keine Zielbindung.

**Sobald eine Bedingung erfüllt ist** bezeichnet eine Schwellenüberschreitung, keinen dauerhaften Tick: Beim ersten gültigen Prüfen einer neu gebundenen Quelle kann eine bereits erfüllte Bedingung auslösen. Danach muss sie erst falsch und wieder wahr werden. Sie löst nicht erneut aus, nur weil ein neuer Zug beginnt und die Bedingung unverändert wahr bleibt. Zusätzlich gilt das auf der Karte angegebene Limit von höchstens einer Anwendung pro Zug. Beispiele sind mindestens fünf Resonanz oder die Kontrolle von mindestens drei Pfaden.

## Reaktionen, Relikte und Verzögerung

**Aktivieren (Energie, Resonanz)** nennt die tatsächlichen Kosten. Ein installierter Reliktplatz allein reicht nicht aus. Energie, Resonanz, eigener Zug, Phase und Nutzungsgrenze werden geprüft. Ein Relikt besitzt höchstens eine manuell nutzbare Aktivierung pro eigenem Zug; weitere ausgelöste Fähigkeiten sind davon getrennt und besitzen ihre eigenen Limits.

**Vorbereitete Reaktion**: Ein ausdrücklich reaktiver Impuls wird zunächst mit seinen Ausspielkosten vorbereitet. Er wartet bis zum angegebenen Ereignis oder bis zum nächsten eigenen Zugbeginn. Die zusätzliche abgedruckte Reaktionskost wird erst beim tatsächlichen Auslösen geprüft und bezahlt. Die geordnete Reaktion ist keine unimplementierte Mehrspieler-Priorität und kein unbegrenztes verborgenes Unterbrechungsrecht. Abgelaufene beziehungsweise verbrauchte Impulse werden nach ihrer tatsächlichen Engine-Regel abgelegt. Die Oberfläche muss vorbereitete Reaktionen sichtbar anzeigen.

**Nach N Zugwechseln** verwendet die im Zustand gespeicherte Verzögerung. Ein Zugwechsel ist ein Übergang zum anderen Spieler, kein Animationsschritt und keine einzelne gespielte Karte. Der markierte Pfad bleibt gespeichert. Der Text beschreibt ausdrücklich, ob ein dann leeres Feld den Helden trifft. Umleitung benötigt ein tatsächlich vorhandenes eigenes verzögertes Ereignis; die vier neuen Produktionsstarter, insbesondere Neunte Stunde, berücksichtigen diese Voraussetzung.

## Validierung und Grenzen

`tools/production/validate_catalog.py` prüft die 550 Datensätze, bekannten Operationen, Parameter, Ziele, Arten, drei Haupttypen, Kopienlimits und vier Starter. `tools/production/test_catalog.py` prüft auch negative Eingaben und ausgewählte unabhängige deutsche Textbeispiele. Die generierten Texte werden gegen die strukturierten Fähigkeiten verglichen. Die Laufzeit- und Browserprüfungen bleiben zusätzliche, eigenständige Nachweise.

Ein gültiger Text ist kein Beleg für endgültige Stärke, individuelle Illustration oder echte Gerätetests. Diese Nachweise werden getrennt dokumentiert.
