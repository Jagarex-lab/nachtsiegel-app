# Task C – Einstieg, Kampagne und lokaler Fortschritt

Umsetzung zusammen mit [Task B: neue Arena und vier Designzyklen](../design/premium/README.md) auf `feature/premium-experience`, Basis `develop` bei `2bce5c3`. Der Produktname bleibt NACHTSIEGEL und kommt aus der zentralen Markenidentität. Die fünf Pfade und der bestehende Standardregelsatz bleiben erhalten.

## Tatsächlich spielbare Wege

- Startbildschirm → Einführung (überspringbar) → Auswahl von zwei vorhandenen Heldenporträts → geführtes Tutorial-Duell → Ergebnis → Hauptmenü.
- Nach dem Tutorial startet **Spielen** ein normales lokales Duell. Ergebnisse bieten Rückkehr ins Hauptmenü und erneutes Spielen. Ein noch laufendes Duell verlangt beim Verlassen eine Bestätigung.
- **Kampagne** zeigt fünf Begegnungen. Das Tutorial öffnet Kapitel 1, ein Kapitelsieg die nächste Begegnung. Bereits geöffnete Kapitel bleiben auch nach Niederlagen verfügbar. Jede Begegnung besitzt Geschichte, Gegner, KI-Profil, festen Startwert, Sieg-/Niederlagenrückmeldung und Wiederholungsweg.
- **Kartensammlung** zeigt zunächst exakt die sieben tatsächlich implementierten Karten. Suche, Fraktionsfilter, Detailansicht und separat zuschaltbare 13 Konzeptkarten funktionieren. Entwürfe besitzen keine erfundenen spielbaren Werte oder Fähigkeiten.
- **Einstellungen** speichert reduzierte Bewegung. Vollbild ist nur bei vorhandener Plattformunterstützung aktiv; native Builds bieten Beenden, Browser eine Rückkehr zum Startbildschirm. Keine funktionslosen Audio-, Account-, Kauf- oder Online-Schaltflächen.

Die beiden Helden haben je 35 Leben, dasselbe Deck und keine Sonderfähigkeit. Die Auswahl ändert Porträt und Identität, keine Kampfwerte. Gegnerporträts sind wiederverwendete, ausdrücklich vorläufige Konzeptbilder.

## Kampagne

Die fünf Kapitel übernehmen einen kuratierten Teil des vorhandenen DE-/EN-Lore-Katalogs. Dadurch wird nicht die gesamte Kreativbibel automatisch zum endgültigen Kanon. `data/campaign/chapters.json` kennzeichnet die Umsetzung als lokalen spielbaren Prototyp.

| Kapitel | Gegner | KI | Fester Startwert |
|---|---|---|---:|
| 1 | Tovin Marr, Schleusenverwalter | leicht: kleinerer vorhandener Kreaturenpool | 8802043 |
| 2 | Ofenaufsicht, Werkstattwache | bisherige Standard-KI | 8802060 |
| 3 | Kammerdelegation, Pfropfhof-Wache | bevorzugt widerstandsfähige Kreaturen | 8802077 |
| 4 | Archivaufsicht, Zeugniswache | berücksichtigt bedrohte Pfade | 8802094 |
| 5 | Orren Daal, Wintermandat | stärkere taktische Auswahl | 8802111 |

Alle Gegner verwenden vorhandene Karten und dieselben Schadens-, Beschwörungs- und Siegbedingungen. KI-Profile verändern lediglich Karten-/Pfadauswahl, keine Lebenspunkte, Energie, Fähigkeiten oder zusätzlichen Beschwörungen. Die festen Startwerte machen den Einstieg reproduzierbar; sie ersetzen keine ausgewogene Schwierigkeitsstudie. Ein legaler automatischer Spieler kann jede Begegnung gewinnen. Es gibt keine automatische Siegvergabe.

## Architektur

| Verantwortlichkeit | Implementierung |
|---|---|
| Kampfzustand, Ziehen, Ausspielen, Phasenauswertung | `scripts/battle_model.gd` |
| Arena, Eingaben, Animationen, Kampfdialoge | `scripts/arena.gd` und visuelle Komponenten |
| Unveränderte sieben Karten | `data/card_definitions.gd` |
| Einstieg, Menürouting, Sammlung, Sitzungswechsel | `scripts/front_end.gd`, `scenes/front_end.tscn` |
| Begegnungen und Heldenzuordnung | `data/campaign/chapters.json`, `scripts/campaign_catalog.gd` |
| Versionierter lokaler Speicher | `scripts/progress_store.gd` |
| Lokalisierbare erzählerische Texte | `data/narrative/content.json`, `data/narrative/locales/` |

Das Kampfmodell kennt weder Menüs noch Dateisystem oder Netzwerk. Die Arena meldet Abschluss/Rückkehr an den Einstieg. Kein unfertiger Multiplayer-Modus; diese Trennung schafft lediglich Erweiterungsmöglichkeiten.

## Speichervertrag

`user://progress_v1.json`, Schema 1: Tutorialstatus, freigeschaltete Kapitel, Kapitelsiege, Siege/Niederlagen, ausgewählter Held, reduzierte Bewegung, Laufnummer und zuletzt verbuchte Ergebnisse. Temporärdatei mit Flush/Close, letzte gültige Sicherung und atomarer Dateiersatz. Wiederholte Abschlussmeldungen desselben Laufs erhöhen Siege nicht nochmals. Beschädigte Daten laden die Sicherung beziehungsweise sichere Startwerte. Alte `ux.cfg` übernimmt nur die Bewegungseinstellung; ein alter erster Zug gilt nicht als abgeschlossenes Tutorial.

Im Browser schließt eine unmittelbar geschriebene, versionierte `localStorage`-Kopie die Zeitlücke der asynchronen Godot-IndexedDB-Synchronisation. Beim erneuten Laden erhält diese neuere Kopie Vorrang. Gesperrter Speicher wird als Fehler gemeldet. Browserdaten löschen oder ein anderes Gerät verwenden bedeutet keinen wiederherstellbaren Spielstand; es gibt keinen Serveraccount. Laufende Duelle werden nicht gespeichert, was Menü und Verlassensdialog ausdrücklich erklären.

## Überarbeitungen und Fehlerbehebung

1. **Sitzungen und Regeln:** Kampfmodell herausgelöst, Karten zentralisiert, Navigation und Speicher eingeführt. Differentialtests fanden ein nach Fixture-Reset fortlebendes Ergebnisfeld; vor jeder neuen Phasenauswertung bereinigt. Standardduelle stimmen wieder mit dem eingefrorenen unabhängigen Regelmodell überein.
2. **Vollständige Wege:** echte Tutorial-/Kampagnenabschlüsse, Sammlung und Speicherkorruption geprüft. Kapitel-IDs aus JSON-Zahlen explizit in Ganzzahlen umgewandelt; GUI-Wechsel aus Eingabe-Callbacks werden verzögert ausgeführt, damit freigegebene Controls keine Ereignisse mehr verarbeiten.
3. **Mobile und Wiederladen:** Touch-Ziele, kurze Browserfenster, Tastaturhöhe und alle Texte geprüft. Eine fokussierte Suche übersteht das Einblenden der Bildschirmtastatur. Die Labelgröße wird vor dem Einfügen gesetzt, um eine anfänglich auf Nullbreite umbrochene, zu hohe Mindestgröße zu vermeiden. Unmittelbarer Browser-Speicherspiegel behebt einen durch Neuladen nachgewiesenen Persistenzfehler.

## Prüfung und Grenzen

Native automatisierte Prüfungen senden echte Touch-Ereignisse für die Menüwege, schließen Tutorial und normales Duell mit legalen Modellaktionen ab, starten eine freigeschaltete Begegnung, prüfen Abbruch/Abbrechen, Suche/Filter, Neustart und Fehlerfälle. Browserprüfungen führen das Tutorial vollständig mit tatsächlichen Touch-Kommandos aus; die nur unter `?qa=1` aktive Brücke liefert Geometrie und Zustand, keine Sieg- oder Gesundheitsmanipulation.

Prüfprotokolle, endgültige Messzahlen und Screenshots werden nach dem vollständigen Testlauf hier ergänzt. Browseremulation ist kein physischer iPhone-/Android-Test. Native iOS-Builds und App-Store-Auslieferung benötigen macOS/Xcode und Signierung. Sie sind nicht Bestandteil dieser Web-Veröffentlichung.
