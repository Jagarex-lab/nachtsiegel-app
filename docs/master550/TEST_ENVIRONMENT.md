# Lokale Browser-QA: gemessene Grenzen

Messung vom 10.11.2026; kein Test auf einem physischen iPhone oder Android-Gerät. Godot 4.6.3, Playwright 1.65.0, Chromium 158 und WebKit 27.2 liefen in einem Container mit zwei CPU-Kernen Quota, drei sichtbaren CPUs und 8 GiB Speicherlimit. Browser verwenden hier Software-Rendering.

| Beobachtung | Einzelner Chromium-Lauf | Browserfreie Kontrolle |
|---|---:|---:|
| Zeitfenster UTC | 16:37:21–16:38:20 | 16:42:00–16:42:10 |
| Mittlere gesamte CPU-Auslastung | 1,912 Kerne | 0,0876 Kerne |
| Gedrosselte CPU-Perioden | 540/592 | 0/76 |
| Zusätzliche kumulierte Kernel-Drosselzeit | 47,80 s | 0 |
| Speicher | 1,55–1,69 GiB | etwa 847 MiB |
| OOM-/Speichergrenzen-Ereignisse | alle Zähler null | alle Zähler null |

Chromium verbrauchte mindestens 100,91 CPU-Sekunden in 59,23 Sekunden; drei beobachtete GPU-Softwareworker davon zusammen mindestens 65,35 Sekunden. Insgesamt gab es bis zu 127 Chromium-Threads, darunter auch I/O- und Servicethreads. WebKit zeigte drei llvmpipe-Worker. Eine massive Workerexplosion aufgrund einer großen Host-CPU-Zahl ist damit **nicht** belegt.

Der korrigierte Sampler benötigte ungefähr 0,09 CPU-Kern. Eine erste, zu breite Abtastung zahlreicher alter Browser-Zombies hatte selbst etwa 0,26 Kern verbraucht und wird als belastete Erstbeobachtung geführt. Zombies wurden im korrigierten Lauf nicht als aktive Renderer gezählt. Die Rohdaten liegen lokal in `work/master550/runner-performance/`, einschließlich Sampler, Zeitreihen, Auswertung und browserfreier Kontrolle.

Die Quota-Drosselung belegt eine reale Einschränkung dieser Testmaschine. Sie beweist weder schlechte iPhone-Performance noch die konkrete Ursache eines früheren Drag-Timeouts. Der betreffende Lauf scheiterte beim zweiten Maus-Drag nach einer ungültigen Ablage mit 418 Assertions; er zählt nicht als bestanden. Eine fokussierte Wiederholung derselben Folge bestand anschließend 422 Assertions: Render-Version 43→44 nach der ersten Rückkehr, zweiter Down erst bei Version 44, danach Version 45. Die ursprüngliche Ursache wurde dabei nicht reproduziert.

Der vollständige Browser-Harness synchronisiert zurückkehrende Karten deshalb mit dem tatsächlichen UI-Rebuild: nach explizitem Abbruch Render-Versionswechsel, zwei Browserframes und passende neue Hand-Controls abwarten. Die frühere feste 180-ms-Pause allein garantierte keinen abgeschlossenen Rebuild. Es wurden weder der produktive Acht-Sekunden-Gestenabbruch noch Testtimeouts erhöht und keine stillen Wiederholungen eingebaut. Absichtlich wirkungslose abgebrochene Taps verlangen keinen Rebuild.

Native Renderprüfungen und lokale Softwarebrowser laufen nacheinander. Chromium und WebKit dürfen in CI auf getrennten Maschinen parallel prüfen. Vollständige erfolgreiche Browserläufe müssen durch ihre eigenen Ergebnisdateien belegt werden; eine Maschinenmessung ersetzt keine fehlgeschlagene Funktionalitätsprüfung. Physische Touchlatenz, reale Geräte-Framerate und Akkunutzung bleiben ungemessen.
