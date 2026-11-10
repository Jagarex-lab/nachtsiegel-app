# Tatsächlich veröffentlichte Alpha 0.2

Am 10.11.2026 wurde PR #9 nach erfolgreicher CI regulär integriert und über den vorhandenen manuellen Pages-Prozess veröffentlicht. Die aktuelle Nutzeranweisung genehmigt diesen Merge und das Ersetzen des bisherigen Testbuilds.

* Live-URL: <https://jagarex-lab.github.io/nachtsiegel-app/>
* Verifizierter Commit: `5d37cd937d7fcc50912a565e96f3cc4aa87f506d`.
* Erfolgreiche Integrations-CI: `42832143806`.
* Erfolgreicher manueller Release: `42836632754`, einschließlich Preflight und Pages-Publish.

Die erwartete Build-ID wurde auf der öffentlichen HTTPS-URL in beiden Browsern tatsächlich aus `build-info.json` geprüft. Anschließend wurden jeweils Hauptmenü, Sammlung und Karteninspektion, Einstellungen, Einstieg, sichtbare Fünf-Pfade-Arena, 44-CSS-Pixel-Touchflächen, Kartenausspielen, gespeichertes Deck nach Neuladen, eine vollständige KI-Partie, identisches Replay und ein Neustart ohne Spielende geprüft.

| Browser | Profil | Ergebnis |
|---|---|---|
| Chromium 158.0.8127.18 | Desktop 1280×720, DPR 1 | Vollständiger Ablauf bestanden; null Konsolenfehler |
| WebKit 27.2 | iPhone-Viewport 844×390, DPR 3 | Vollständiger Ablauf bestanden; null Konsolenfehler |

[Maschinenlesbares Ergebnis mit Bildhashes](qa/live-alpha02-results.json), [tatsächlicher iPhone-Profil-Screenshot der Live-Version](qa/live-alpha02-iphone-battle.png). Zwölf native PNGs wurden lokal aufbewahrt. Die Profilprüfung ist **kein physischer iPhone- oder Safari-Gerätetest**.

Die Testumgebung benötigt ihren verwalteten HTTPS-Proxy. Chromium musste dafür den bereits vorhandenen, zur Umgebung gehörenden CA-Eintrag über eine beschreibbare NSS-Datenbank lesen können. Es wurde keine TLS-Prüfung deaktiviert. Frühere Versuche mit falschem Netzwerkzugang beziehungsweise einem hängenden Browser-Screenshot zählen nicht als bestandene Tests. Nach Behebung der Testumgebung und tatsächlicher Viewport-Aufnahme bestanden beide vollständigen Läufe.

Dieser Nachweis gilt für den oben genannten veröffentlichten Commit. Die neuen Karten-/Bedienungsarbeiten in PR #10 sind ein anderer Stand und benötigen ihre eigene abschließende CI, Browserprüfung und manuelle Veröffentlichung. Der 550-Karten-Auftrag ist dadurch nicht als abgeschlossen behauptet.
