# Verbleibende Grenzen nach dem grünen Alpha-Kandidaten

Stand:2026-11-09. Kandidat8c1d342 hat zwei vollständig grüne CI-Läufe einschließlich Native/Chromium/WebKit und wiederholten Kaltstarts. Kein produktiver Release. [Nachweise](QA_REPORT.md).

## Historischer Auditumfang über das spielbare Alpha-Minimum hinaus

- **P11c/d:** Originales JS audit-v4/replayVersion2 mit JS-JSON-/FNV1a-Semantik und Import echter Legacy-Exports fehlt. ORAFOLD-LOCAL-REPLAY v1 ist ausdrücklich ein eigener vollständiger nativer Replayvertrag. Nächster unabhängiger Schritt:Unicode/Zahlen/Feldreihenfolge-Goldens, Originalauditimport, dann exakter Event-/Exportvertrag.
- **P12c:** v09/v06/v05-Altstandadapter fehlt. Eigenes Alpha-Profil verhindert Überschreiben des Archivs, ersetzt aber keine Besitz-/Deck-/Ergebnis-/Settingskonvertierung. Separat atomar testen.
- Historische Angriffsvorschau und alle game.js-Nebenwege sind nicht vollständig migriert. Audit-Gate250 vollständige Oraclepartien/1000 Simulationen ist nicht erreicht; vorhanden24 vollständige Differentialpartien und64 Alpha-Simulationen.
- Raw-helper `block.retained_during_other_begin` bleibt `guarded_begin_wrong_side` unsupported:der reguläre Vertrag verbietet falsche aktive Seite. Nicht als bestanden gezählt. Alle regulären implementierten Spielaktionen laufen über geprüfte Commands.

Der Alpha-Master verlangt für P08–P12 die zur vollständigen Partie nötigen Funktionen, ein nachvollziehbares Protokoll und mindestens einen speichernden lokalen Deckbuilder. Dieser funktionale Umfang ist vorhanden; daraus folgt **keine vollständige historische game.js-/Audit-Parität**.

## Geräte, Gestaltung und Balance

- Keine physischen iPhone-/Android-Tests; WebKit/Chromiumprofile sind Desktop-Browser-Simulationen. Keine native Store-/FPS-/Batterie-/Thermalabnahme. Vor Geräte-/Releasefreigabe tatsächliche Zielgeräte und Safari-Versionen testen.
- Vorhandene Atlasillustrationen sind ausdrücklich Platzhalter, nicht55 einzigartige finale Bilder. Keine abgeschlossene Premium-Art-Produktion behauptet. Eine eigenständige vollständige Alpha-WCAG-Messreihe steht noch aus; die bestehende Archivreihe bleibt grün.
- Unter296 logischen Höhenpixeln erscheint ein Platz-/Tastaturhinweis statt abgeschnittener Kampfcontrols. Partie bleibt erhalten.
- Balance unbewiesen. Lange Collapse-Partien und geringe Stichprobe siehe BALANCE_REPORT; keine47–53%-Aussage. Vier Archetypnamen je Macht sind Identitätsachsen, nicht16 fertige Decks.
- Sammlung ist für lokale Tests vollständig freigeschaltet. Kein Shop, Booster, Währungssystem, Konto, Handel, Gilde oder Echtgeld. PR3 ist ausschließlich Architekturreferenz.

## Behobene beziehungsweise eingegrenzte Prüfprobleme

Alte Playwright1.56.1/WebKit26-Läufe hatten sporadische WASM-Boottraps vor Spielbeginn, auch im Archiv. Prozessisolation allein reichte nicht. Mit fixiertem aktuellem Stack1.65.0/27.2 bestehen zwei aktuelle CI-Läufe und Kaltstartregression; die genaue frühere Engineursache wird nicht als bewiesen ausgegeben. Alte reale Safari-Versionen sind dadurch nicht abgenommen. Sämtliche Fehlerchronik einschließlich HTTP-Server-Race, frühzeitigem UI-Renderfehler und lokalem Archiv-Timingbefund steht in QA_REPORT. Keine Timeouts/Assertions zur Schönung entfernt.

## Lieferung und spätere Freigabe

Develop blieb unverändert. Publisher-ID406254158 ist deaktiviert. Adminschutz/Reviewer/Branchschutz sind nicht vollständig verifiziert; dies blockiert ausschließlich PhaseB, nicht weitere Entwicklung. Kein Auto-Merge oder Release-Dispatch. [Freigabeablauf](RELEASE_REPORT.md).

Geteilter Desktop:Environment `ccarenv_b64_Y2NhcmVudl9mYTkyN2VhMzYwZjA4MTkxYTgwYTIyNzY4MDZkZGQ4Mg` meldete remote_desktop enabled/state unknown, bot aber weder Desktop-NodeREPL noch open_in_codex an. Ein gemeinsamer Browsertab konnte deshalb nicht geöffnet werden. Automatisierte reale Browserprozesse, lokale Testserver und herunterladbare ZIP-Artefakte funktionieren unabhängig davon.
