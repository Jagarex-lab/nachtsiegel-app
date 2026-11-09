# Task C – Einstieg, Kampagne und lokaler Fortschritt

Umsetzung zusammen mit [Task B: neue Arena und vier Designzyklen](../design/premium/README.md) auf `feature/premium-experience`, Basis `develop` bei `2bce5c3`. Der Produktname bleibt NACHTSIEGEL und kommt aus der zentralen Markenidentität. Die fünf Pfade und der bestehende Standardregelsatz bleiben erhalten.

## Tatsächlich spielbare Wege

- Startbildschirm → Einführung (überspringbar) → Auswahl von zwei vorhandenen Heldenporträts → geführtes Tutorial-Duell → Ergebnis → Hauptmenü.
- Nach dem Tutorial startet **Spielen** ein normales lokales Duell. Ergebnisse bieten Rückkehr ins Hauptmenü und erneutes Spielen. Ein noch laufendes Duell verlangt beim Verlassen eine Bestätigung.
- **Kampagne** zeigt fünf Begegnungen. Das Tutorial öffnet Kapitel 1, ein Kapitelsieg die nächste Begegnung. Bereits geöffnete Kapitel bleiben auch nach Niederlagen verfügbar. Jede Begegnung besitzt Geschichte, Gegner, KI-Profil, festen Startwert, Sieg-/Niederlagenrückmeldung und Wiederholungsweg.
- **Kartensammlung** zeigt zunächst exakt die sieben tatsächlich implementierten Karten. Suche, Fraktionsfilter, Detailansicht und separat zuschaltbare 13 Konzeptkarten funktionieren. Entwürfe besitzen keine erfundenen spielbaren Werte oder Fähigkeiten.
- **Einstellungen** speichert reduzierte Bewegung. Vollbild ist nur bei vorhandener Plattformunterstützung aktiv; native Builds bieten Beenden, Browser eine Rückkehr zum Startbildschirm. Keine funktionslosen Audio-, Account-, Kauf- oder Online-Schaltflächen.

Die Plattform-Zurück-Taste wird abgefangen und folgt dem Menürouting; in einem Duell öffnet sie das Duellmenü.

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
3. **Mobile und Wiederladen:** Touch-Ziele, kurze Browserfenster, Tastaturhöhe und alle Texte geprüft. Eine fokussierte Suche übersteht das Einblenden der Bildschirmtastatur. Die Labelgröße wird vor dem Einfügen gesetzt, um eine anfänglich auf Nullbreite umbrochene, zu hohe Mindestgröße zu vermeiden. Unmittelbarer Browser-Speicherspiegel behebt einen durch Neuladen nachgewiesenen Persistenzfehler. Der Debug-Webexport prüfte zusätzlich die JavaScript-Brücke: ihre numerische Rückgabe wird explizit in einen Wahrheitswert umgewandelt.

4. **Vollständige Kampagnenübergänge:** alle fünf Kapitel nacheinander legal gewonnen, echte Niederlage durch Passen und anschließende Wiederholung geprüft. Ein Godot-Laufzeitfehler bei bedingten Signalaufrufen im Ergebnisdialog wurde mit expliziten Zweigen behoben. Kapitel fünf kehrt zur Übersicht zurück; normale Duelle bieten einen direkten Neustart.

## Screenshots

[Start](screenshots/start-844x390.png) · [Hauptmenü](screenshots/home-844x390.png) · [Heldenwahl](screenshots/heroes-844x390.png) · [Sammlung](screenshots/collection-844x390.png) · [Kartenansicht](screenshots/implemented-inspection.png) · [Kapitel 1](screenshots/chapter-1.png) · [Niederlage](screenshots/campaign-defeat.png)

## Prüfung und Grenzen

Native automatisierte Prüfungen senden echte Touch-Ereignisse für die Menüwege, schließen Tutorial und normales Duell mit legalen Modellaktionen ab, starten eine freigeschaltete Begegnung, prüfen Abbruch/Abbrechen, Suche/Filter, Neustart und Fehlerfälle. Browserprüfungen führen das Tutorial vollständig mit tatsächlichen Touch-Kommandos aus; die nur unter `?qa=1` aktive Brücke liefert Geometrie und Zustand, keine Sieg- oder Gesundheitsmanipulation.

**Lokale Abnahme: 8.111 Assertions, keine Fehler.** Davon 627 neue Prüfungen der Spielerfahrung, 684 Regelprüfungen mit 30 Differential-Duellen, 2.253 Datenprüfungen, 97 Katalogprüfungen, 380 Eingabeprüfungen, 1.720 Premium-Geometrieprüfungen und 2.350 UX-Prüfungen. Die erweiterten Kampagnenprüfungen ergänzen den zunächst mit 609 Experience-Assertions abgeschlossenen Gesamtlauf; sie wurden anschließend für den endgültigen Quellstand erneut ausgeführt. [Zusammengeführtes Prüfprotokoll](qa/native-final.log).

**78 gepaarte Renderzustände, 2.835 Kontrastmessflächen, keine Unterschreitung** der Ziele 4,5:1 für Text und 3:1 für wesentliche Grenzen/Symbole. [Messdaten](qa/contrast-report.json). Die vier geforderten Querformate und zusätzliche kurze Fenster/Safe Areas sind abgedeckt. Die sechs Konzeptbilder wurden mit dem abschließenden Quellstand erneut in Godot gerendert.

Web-, Linux- und Android-Debug-Export erstellt. [Prüfung der eingebetteten Kampagnenressourcen im Linux-Paket](qa/packaged-experience.log); die CI prüft dieselben Ressourcen auch im exportierten Web-Paket. Android: Version 0.5.0-experience, ARM64/x86_64, Debug-Signatur mit APK Signature Scheme v2/v3 [erfolgreich geprüft](qa/android-signature.log). Der fehlende ADB-Gerätedienst verhindert keinen Export; mangels angeschlossenem Gerät wurde keine Installation behauptet. Eine Meldung zur Wahl von Build Tools 35 ist protokolliert. Linux/Xvfb meldet fehlende V-Sync-Unterstützung des virtuellen Displays.

Zusätzlich lokal bestanden: Chromium-Desktop im Release-Export und WebKit im endgültigen Debug-Export bei 844×320, reduzierter Bewegung und simulierten iPhone-Safe-Areas. Beide absolvieren das Tutorial ausschließlich mit echten Touch-Kommandos und prüfen den danach erneut geladenen Spielstand. [WebKit-Protokoll](qa/local-webkit-debug.log), [Metadaten](qa/local-webkit-debug-results.json), [Menü nach erneutem Laden](screenshots/home-progress-webkit.png). Der explizite Host-Prerequisite-Check wurde lokal übersprungen, nachdem die fehlenden WebKit-Bibliotheken im Arbeitsverzeichnis installiert waren; Browserstart und tatsächliche Tests bestanden. Die CI installiert die offiziellen Host-Abhängigkeiten vollständig.

Ein zusätzlicher mobiler Eingabetest besteht in Chromium und WebKit: vertrauenswürdiger Touch aktiviert das echte HTML-Eingabefeld, Eingabetext wird an Godot weitergereicht, die Sammlung filtert und der Fokus bleibt bei 844×200 bestehen. Die Web-Exportoption `html/experimental_virtual_keyboard=true` aktiviert Godots offizielle Brücke; die kanonische Sieben-Profil-Prüfung verlangt nun ebenfalls diesen DOM-Fokus und die eingegebenen Zeichen. [Prüfprotokoll](qa/keyboard-browser.log), [Chromium](screenshots/keyboard-chromium.png), [WebKit](screenshots/keyboard-webkit.png). Eine tatsächlich angezeigte Betriebssystemtastatur auf Hardware wurde damit nicht behauptet.

**Finaler Feature-CI erfolgreich:** [Lauf 42598581483](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/42598581483), Quellstand `5c28c97e1aa2056affad1b285700ad4e25f04647`, vollständige native Suite und sieben Browserprofile ohne Fehler. Vier Chromium-Profile (1280×720, 1600×900, 915×412, 844×320 mit DPR 2/Safe Areas), drei WebKit-Profile (844×390 mit DPR 3, 915×412, 844×320 mit reduzierter Bewegung/Safe Areas). Jede Partie erreicht einen echten Tutorialsieg und prüft anschließend persistente Heldenwahl/Fortschritt, Kapitelzugang, Sammlung und native HTML-Texteingabe. In der CI wurden 2.836 Kontrastmessflächen geprüft; die lokale Momentaufnahme enthält 2.835. [CI-Auszug](qa/feature-ci.log).

Manuelle Sichtprüfung der tatsächlich gerenderten Arena, des Hauptmenüs, der Einführung, Heldenwahl, Sammlung, Kartenansicht, Kapitelgeschichte und Niederlage. Keine Behauptung eines manuell auf Hardware absolvierten Duells.

## Veröffentlichte Fassung und öffentliche Abnahme

[Direkt spielen](https://jagarex-lab.github.io/nachtsiegel-app/?v=5c28c97e1aa2): **Beginnen** öffnet bei neuen Spielern Einführung, Heldenwahl und Tutorial. Nach dem Tutorial stehen normales Duell und Kapitel 1 bereit.

Am 9. November 2026 über `develop` veröffentlicht: Quellstand **`5c28c97e1aa2056affad1b285700ad4e25f04647`**. [Veröffentlichungslauf 42599448842](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/42599448842) erfolgreich: gesamte Suite nochmals bestanden, anschließend **sieben vollständige Browserprofile direkt auf der öffentlichen Spieladresse, keine Fehler**. [Veröffentlichungs-/Live-Protokoll](qa/published-ci.log), [öffentlich ausgelieferte Build-Metadaten](qa/public-build-info.json).

Zusätzliche öffentliche WebKit-Prüfung: Einstieg → Hauptmenü → überspringbare Einführung → Heldenbildschirm → Tutorialarena → tatsächliche Kartenauswahl. Commit stimmt, keine Browser- oder Godot-Fehler. [Prüfdaten](qa/public-spot-check.json), [Start](screenshots/public-start.png), [Menü](screenshots/public-menu.png), [Arena](screenshots/public-arena.png). Für diese zusätzliche Cloud-Prüfung wurde der geerbte Proxy verwendet. Chromium lehnte dessen Zertifikat trotz lokal eingerichtetem NSS-Speicher ab; WebKit mit bestehender System-CA-Vertrauensbasis bestand ohne TLS-Ausnahme. Die vollständigen öffentlichen Chromium-/WebKit-Tests laufen unabhängig davon erfolgreich auf den GitHub-Runnern.

Die Webdateien heißen `nachtsiegel-5c28c97e1aa2.*`, damit alte Safari-Caches keine Ressourcen der vorigen Fassung wiederverwenden. `main` blieb unverändert. Der anschließende Dokumentationscommit verändert den veröffentlichten Spielcode nicht.

## Verbleibende Plattformgrenzen

Browseremulation ist kein physischer iPhone-/Android-Test. Native iOS-Builds und App-Store-Auslieferung benötigen macOS/Xcode und Signierung. Sie sind nicht Bestandteil dieser Web-Veröffentlichung.
