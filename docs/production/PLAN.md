# ORAFOLD – Umsetzungs- und Integrationsplan

Stand: 10. November 2026. Basis des Produktionsauftrags: `develop` `795be306470073276f53d1bcf8f85e5ad1278fe0`, veröffentlichte Vorgängerversion `fde508e85a2866e24653ef25d920a59832d2d653`. Der [Audit](AUDIT.md) beschreibt den Ausgangspunkt. Dieser Plan ist ein Arbeitsinstrument und ersetzt keine Implementierung oder Abnahme.

## Lieferbare, unabhängig prüfbare Pakete

| Paket | Konkretes Ergebnis | Abhängigkeiten | Mindestnachweis vor Integration |
|---|---|---|---|
| A1 Bestandsaudit/Bereinigung | Tatsächliche Poolzahlen, PR-Abhängigkeiten, Regelkonflikte, sichere Archiv-/Migrationsentscheidungen. | Aktueller develop, #10/#11/#12. | Datennachzählung und Quellenverweise; keinerlei ungeprüfte Löschung. |
| B1 PR11 konsolidieren | Vorhandene Source-bound-Brücke kontrolliert übernehmen, Default-Legacy erhalten. | Review von #11; keine Parallelengine. | Opt-out-Vollzustände/Ereignisse identisch; Bridge, Legacy, Alpha, Replay, Export und CI auf aktuellem Integrationsstand. |
| B2 Generische Programme/Trigger | Validierte frei kombinierbare Effektprogramme, alle zwölf Kategorien und 16 tatsächlichen automatischen Hooks, stabile Quellen/Ziele, passive/aktivierte/reaktive/verzögerte Fähigkeiten. | B1, geschlossener Daten-/Textvertrag. | Alle Hookfamilien mit realem Zustandsübergang, beide Seiten, Reaktionsfenster/Pass, zehnteilige Kette, ungültige Ziele und unendliche Zyklen begrenzen; Registry-ID allein zählt nicht. |
| B3 Session/Replay/Persistenz | Versionsgebundenes Produktionsprofil, Kataloghash, replaybarer Setupvertrag, Migration alter Alpha-Decks und Quarantäne beschädigter Daten. | B2. | Vollständige Partien reproduzieren Zustand und Ereignisse; ungültige Befehle unverändert; angenommene Kettenfehler korrekt protokolliert; Neustart/fehlerhafte Profile getestet. |
| C1 Kuratierte erste Kartenchargen | Autorenquellen und Datenübersetzung; tatsächliche Effekte, Kosten, Arten, Archetypen, Gegenmittel und deutsche Texte. | B2/B3-Vertrag. | Kleine Chargen zuerst nativ/Session spielbar; keine bloßen Namens-/Zahlenklone. Umleitungslücke regelkonform schließen oder sperren. |
| C2 Aktiver 550er-Katalog | Genau 110 Karten je vier Mächten und Neutral; genau drei Haupttypen; Wesenmehrheit; alle IDs/Referenzen/Parameter gültig. | C1; aktive Migrationsentscheidung. | Struktur-/Text-/semantische Signaturprüfung, jede Karte regulär ausspielen und alle Fähigkeiten auslösen, vollständige Fähigkeitsabdeckung separat zählen. Nicht nur automatisch eine Testfunktion pro ID aufrufen. |
| D1 Ressourcen/Balance/KI | Gegenübergestellte Ressourcenprofile, Kostenbudget, archetypische legale Decks, Strategie-KI ohne Regelvorteile. | B2/C1, danach C2 erneut. | Reproduzierbare gepaarte Seeds/Startpositionen; ganze Partien; Siege, Konvergenz, Ressourcenbilanz, Nutzung und Kombinationsausreißer; Zensur/Fehler nicht als Erfolg. |
| D2 Iterative Kartenkorrektur | Dokumentierte datenbasierte Änderungen an Kosten/Werten/Fähigkeiten, starke Ausnahmen mit Risiko/Gegenmittel. | D1 und praktische Partien. | Vorher-/Nachherdatensätze und ausreichend große neue Matrix; keine vollständige Balance aus einer kleinen KI-Stichprobe behaupten. |
| E1 Einheitliche Kartenpräsentation | Bestehenden Diagonalmaster konsolidieren, Macht/Material/Seltenheit lesbar; eine einzige Rückseite. | B2/C1-Datenfelder. | Identische Außenkontur 756×1056, alle Typen/Mächte/Seltenheiten; keine Ausläufer/Textüberläufe, tatsächliche Screenshots. |
| F1 Illustration/Provenienz | Pro Karte eigenes Motiv, Quelle/Prompt/Hash/Status und passender Art-Brief; Rahmen/Text separat. | Kanonprüfung der konkreten Karte, E1-Bildfenster. | Echte Dateien und Einzelmotivprüfung; fehlend/concept/final und juristische Prüfung getrennt; keine Upscaling-Fertigmeldung. |
| F2 Alle 550 Einzelbilder | Tatsächliche 550 unterschiedliche, passende Originale und mobile Derivate. | F1/C2. | Vollständige Zuordnung, Hash-/Format-/Motiv- und Artefaktprüfung; Lizenzen/Herkunft dokumentiert. Ohne diese Arbeit keine Endabnahme. |
| G1 Sammlung/Deckbuilder | Schnelle Filter/Sortierung für 550, große Sammlung ohne Hunderte teure Controls, valide 30er-Decks, sichere Bearbeitung. | C2/B3. | Gleichwertige Doppelarten, mehrere Filter gleichzeitig, Kopienlimits, Speichern/Laden/Migration, Touch/Scroll/Inspektion bei Desktop und realistischen Mobilgrößen. |
| G2 Kampf/Animation/Tutorial | Bestehender Spielfeldmulligan, Drag und Tap erhalten; klare Werte/Ziele/Konvergenz, kurze Ereignisanimationen, reduzierte Bewegung und Einsteigerhilfen. | B2/B3, E1; kein neues Lore-Kampagnenfinale. | Abbruch/Rotation/Hintergrundwechsel, unterbrochene Animationen, Mehrfachtouch, komplette Duelle; Animation entscheidet keine Regel. |
| H1 Plattform-/Releaseintegration | Web-/Linux-/Android-Prüfung, iOS-Voraussetzungen dokumentieren; finale CI und kontrollierter manueller Release. | Alle für jeweiligen Zwischenstand benötigten Pakete. | Exakter Integrations-SHA grün, vorhandener Releaseguard, bestätigtes Deployment und öffentliche Browserpartie; echte Geräte nicht mit Emulation gleichsetzen. |

## Architekturgrenzen

Der bestehende Alpha-/Legacy-Kernel bleibt die einzige Kampfengine. Neue Datenprogramme delegieren primitive Zustandsänderungen und besitzen deterministische Hooks statt Karten-ID-Spezialcode. Kartennamen/Lore bleiben von Identität und Regelprogrammen getrennt; Sammlung/Besitz/Monetarisierung entscheiden keine Kampfregeln.

Vor PR11-Übernahme dessen aktuellen Head prüfen und auf dem aktuellen develop aufbauen. Keine älteren offenen gestapelten PRs erneut mergen. Neue Produktionskarten erhalten einen expliziten Regeln-/Katalogstand; alte Replays und gespeicherte Decks dürfen nicht unter anderer Mechanik unbemerkt neu interpretiert werden.

## Verbindliche Invarianten und Regelentscheidungen

Erhalten bleiben fünf Pfade, leerer direkter Gegenpfad → Heldenangriff, ursprüngliche Schadensabsorption, zwei Siegbedingungen, maximal ein Relikt und Tap-Alternative zum Drag. Änderung nur als konkrete begründete Version mit Tests.

Vor neuer Kostenkurve 9/10 muss Energieerreichbarkeit produktiv entschieden sein. Der abgeschlossene [Ressourcenvergleich](RESOURCE_MODEL_EXPERIMENT.md) bestätigt den Produktionsdefault E8/R15; E10/R15 und E10/R20 bleiben ausschließlich Testprofile. Resonanz bleibt eigenständig. Aktivierbare und reaktive Fähigkeiten bezahlen reale Bruttokosten und benutzen per Quelle/Zug/Kette geprüfte Grenzen.

Die vier Machtidentitäten und zwölf Arten sind Kanon. Namen/Orte aus #12 bleiben Vorschlag. Neue Hauptereignisse, Führungsfiguren und Eira-Enthüllungen bleiben ausdrücklich Vorschläge; keine neue Kampagne ungefragt kanonisieren.

## Entwicklungs- und Prüfablauf

1. Baseline erfassen, Paket in kleinem Featurebranch implementieren, gezielte Tests zuerst.
2. Quell-/Datenänderungen in nachvollziehbare Commits aufteilen; Pakete mit Reviewbeschreibung und exakten Grenzen als PR bereitstellen.
3. Nach Abschluss paralleler Änderungen einen unveränderten Gesamtstand prüfen. Während eines Wrappers seine Datei nicht ändern.
4. Node-/Godot-Regeln, Legacy-Differentialtests, Replay, Exportinventur und Browsermatrix passend zum Paket ausführen. Neue Fähigkeiten dürfen nicht nur in direktem Testadapter bestehen, sondern müssen über die produktive Session erreichbar sein.
5. Vor Merge sämtliche für den tatsächlichen Integrations-SHA relevanten Checks bestehen lassen. Ein grüner Vorläufercommit genügt nicht.
6. Nur einen geprüften Zwischenstand über den bestehenden manuellen Pagesworkflow veröffentlichen. Nach Release Commitmetadaten, Menü, komplette Partie, Replay/Neustart und Speichern auf öffentlicher HTTPS-URL prüfen.
7. Tatsächliche Karten-/Fähigkeits-/Bild-/Simulationszahlen berichten; offene Arbeit nicht hinter Gesamtsummen verstecken.

Reproduzierbare vorhandene Einstiegspunkte: `tools/test_legacy.sh`, `tools/test_alpha.sh`, `tools/test_master550.sh`, `tools/test_master550_resources.sh`, `python3 -m unittest discover -s tests/release -v`, `tools/build_alpha.sh`. GUI-Suiten benötigen Xvfb/Display; Browserprüfungen Playwright mit tatsächlichem Export. Für neue Produktionspakete werden passende zusätzliche Gate-Wrapper eingeführt, ohne alte Tests still zu entfernen.

## Fortschrittsbuchführung

Jeder Paketbericht nennt mindestens: Quell-SHA/Branch/PR, implementierte Mechaniken, tatsächliche aktive Karten und gebundene Legacy-/Archivbestände, Anzahl einzeln nutzbarer Effekte, fertige Einzelbilder, testweise vs. produktive Regeln, Tests/Fehler/übersprungene Fälle, Simulationen und ihre Grenzen, publizierter SHA oder „nicht veröffentlicht“.

Dieser Plan beginnt auf einer spielbaren Alpha. **550 Konzepte sind kein technisch vollständiger Katalog; ein technisch vollständiger Katalog ohne 550 passende Einzelbilder ist keine vollständige Produktion.**
