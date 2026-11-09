# NACHTSIEGEL

Eigenständiges Dark-Fantasy-Kartenduell in Godot 4.6.3, für Querformat auf iPhone und Android gestaltet. Fünf Pfade, illustrierte Reliquienkarten, Obsidianarena und lokaler KI-Gegner.

![Neue Arena](docs/design/premium/screenshots/full-board-six-hand-844x390.png)

**Direkt spielen:** https://jagarex-lab.github.io/nachtsiegel-app/?v=5c28c97e1aa2

[Premium-Designbericht mit drei gerenderten Konzepten](docs/design/premium/README.md) · [Spielerfahrung, Kampagne und Tests](docs/experience/README.md)

## Marken- und Lore-Entwurf

[Master Task A: vollständige Marken- und Lore-Bibel](docs/creative/README.md), mit 20 Namenskandidaten, Entscheidungsvorlage und strukturierten DE-/EN-Texten. NACHTSIEGEL bleibt der Produktname. Ein kuratierter Teil der Lore ist jetzt als lokale Fünf-Kapitel-Kampagne spielbar; weitere Entwürfe bleiben gekennzeichnet.

## Spielen

`project.godot` in Godot 4.6.3 öffnen und F5 starten. Startbildschirm → überspringbare Einführung → Held wählen → Tutorial. Danach stehen normales Duell, freigeschaltete Kampagnenkapitel, Sammlung und Einstellungen im Hauptmenü bereit. Fortschritt bleibt lokal gespeichert. Handkarte antippen, anschließend Zielpfad wählen. Zauber können auch direkt auf die gegnerische Kreaturenkarte gespielt werden. **Details** öffnet die Großansicht; **Menü → Spielhilfe** erklärt Kampf und Siegbedingungen. Nach Sieg/Niederlage führen die Ergebnisaktionen ins Hauptmenü, zur Wiederholung oder zur nächsten freigeschalteten Begegnung.

Getestete Änderungen auf `develop` werden automatisch auf der Spielseite veröffentlicht und dort erneut im Browser geprüft. Der Entwicklungsstand baut auf `develop` auf. Die vorhandenen lokalen Spielregeln bleiben erhalten; dieser Stand ist kein nachgewiesener vollständiger Port des älteren [Webspiels](https://jagarex-lab.github.io/duel-deck/).

## Prüfen und exportieren

```bash
# Godot 4.6.3 und ein X11-Display, z. B. Xvfb :99, erforderlich
DISPLAY=:99 tools/test.sh

# Passende offizielle Godot-Exportvorlagen installieren
mkdir -p work/build/web
godot --headless --path . --export-debug 'Linux QA' work/build/nachtsiegel.x86_64
godot --headless --path . --export-debug 'Web QA' work/build/web/index.html
# Android SDK und Java unter Editor Settings → Export → Android konfigurieren
godot --headless --path . --export-debug 'Android QA' work/build/nachtsiegel-debug.apk
```

`tools/test.sh` legt Godot-Benutzerdaten ausschließlich unter `work/` ab. Exportvorlagen müssen daher unter diesem XDG-Datenverzeichnis verfügbar sein, wenn dieselben Umgebungsvariablen für den Export verwendet werden. Binärdateien, SDK, Debug-Schlüssel und temporäre Dateien werden nicht eingecheckt.

[UX/UI, Kontrast und Tests](docs/QA-UX-2026-11-09.md) · [Grafikstufe Mondheiligtum](docs/QA-SANCTUM-2026-11-08.md) · [Erste Überarbeitung](docs/QA-2026-11-08.md) · [Asset-Herkunft](assets/ASSET_MANIFEST.md)

Godot: MIT. Projektcode und Spielinhalte: bestehender Rechtevorbehalt laut `LICENSE-NOTICE.md`. Illustrationen sind ausdrücklich als KI-Konzept-Platzhalter gekennzeichnet.
