# ORAFOLD Alpha 0.3 – geprüfter Release vorbereitet

Stand: 11. November 2026. Der vollständige Produktionsstand ist über PR #23 und PR #19 nach `develop` integriert: `345edb6e683d4359b8141ef228683c0855773ac2`. Der Dateibaum entspricht dem zuvor vollständig geprüften Kandidaten ba09e105. Der anschließende tatsächliche Develop-Push besteht ebenfalls alle 16 Hauptjobs und Release Safety. Dieser Nachweis behauptet keine Veröffentlichung.

## Implementierung und nachgewiesene Grenzen

550 aktive spielbare Karten: 357 Wesen, 133 Impulse, 60 Relikte; je 110 pro Macht/Neutral. Alle 550 wurden für beide Seiten regulär ausgespielt. 550 tatsächliche individuelle Originalillustrationen und passende mobile Derivate sind bereits auf develop enthalten. Karten, UI, Bilder, Audio, Deckbuilder, Speicherung, Replay und KI sind integriert. Historische 55 Alpha-, 100 Legacy- und sieben Prototypkarten bleiben getrennte Referenzprofile; elf Produktionsfassungen sind überarbeitet, Quelllöschungen null.

Vier Starter, 14 Strategievorlagen, Spielfeldmulligan, Ursprung/Zweite Möglichkeit, fünf Pfade, direkte Heldenangriffe, Block/Schild, Relikte und Konvergenz sind implementiert. Zwölf Effektkategorien und 16 Trigger verwenden den bestehenden gemeinsamen Kernel. Unterstützte passive Fähigkeiten, automatische Reaktionsfenster und technische Kettengrenzen sind in docs/production/EFFECT_ENGINE.md ausdrücklich abgegrenzt.

Die vollständige Develop-CI prüft Regeln/Legacy/Alpha, GUI/Touch/Drag/Rotation, Speicherung/Migration, Chromium/WebKit, Audio, echte Windows-/Linux-QA-Duelle, Android-Debugpaket, Art-Pakete und Bildtransport. Getrennte Simulationsstichproben: 848+18, 192+10 und 256+12 vollständige Partien/Kontrollen. Im Full-Pool-Sampler wurden 546 verschiedene IDs tatsächlich ausgespielt; alle 550 besitzen zusätzlich beide-seitige Ausspieltests. Die Stichproben sind keine unabhängige Gesamtsumme oder vollständige Balancefreigabe.

Bekannte Grenzen: deutliche Balanceausreißer (Referenzmatrix 63,4% Startspielersiege); keine abschließende menschliche Balance. Kommerzielle Bildfreigaben bleiben 0/550 trotz dokumentierter Herkunft und visueller Sichtung. Physische iPhone-/Android-Tests, native iOS-Signierung, abschließende menschliche Hör-/Kunst-/Rechteabnahme und Match-Resume nach OS-Abbruch bleiben offen. Keine Echtgeldfunktionen oder ungeprüfte Kampagnenkanonisierung.

## Genau geprüfter Build

- Main-CI: https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/42978378329 — alle 16 Jobs SUCCESS.
- Release Safety: https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/42978378260 — SUCCESS.
- Getestetes Artefakt: [nachtsiegel-arena-qa](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/42978378329/artifacts/13837861450), ID `13837861450`, 511275323 Bytes.
- SHA-256 des tatsächlichen Artefakt-ZIP: `103dd77c173387652f1b9002c08718c36a132003cc026fdca71ecef56c638b6e`.
- Maschinenlesbare Prüfung: [ALPHA_03_CI_345.json](evidence/ALPHA_03_CI_345.json).

## Noch erforderlicher manueller Schritt

Der verbundene GitHub-Connector bietet keinen Workflow-Dispatch. Die separate Shell-Anmeldung ist ungültig und wird gemäß Nutzeranweisung nicht verwendet oder ersetzt. Es fehlen keine erneut angefragten Merge-/Releasegenehmigungen. Repository-/Environment-Schutzregeln werden nicht umgangen.

[Manual production Pages release öffnen](https://github.com/Jagarex-lab/nachtsiegel-app/actions/workflows/pages-release.yml) → **Run workflow** → Branch **develop** wählen und exakt eintragen:

| Eingabe | Wert |
| --- | --- |
| commit | `345edb6e683d4359b8141ef228683c0855773ac2` |
| qa_run_id | `42978378329` |
| confirmation | `PUBLISH 345edb6e683d4359b8141ef228683c0855773ac2` |

Dann den Workflow starten. Er prüft zweimal den aktuellen Develop-HEAD, den vollständigen erfolgreichen exakten QA-Lauf, das noch gültige Artefakt und aktuelle Pages-/Environment-Regeln. Wenn develop inzwischen geändert wurde, diesen Stand nicht erzwingen: neuen vollständigen QA-Nachweis verwenden. Den Dokumentations-PR daher vor diesem Release nicht zusätzlich mergen.

Erst ein erfolgreicher Deploymentlauf und anschließende tatsächliche öffentliche Browserprüfung bestätigen die Veröffentlichung. Ziel-URL bleibt https://jagarex-lab.github.io/nachtsiegel-app/ . Die letzte tatsächliche HTTP-Prüfung vor diesem Nachweis liefert weiterhin Alpha 0.2, Commit fde508e85a2866e24653ef25d920a59832d2d653.

## Vergleichsbilder und tatsächlicher Spielablauf

Zusätzlich sind 25 unveränderte Original-PNGs mit Raw-QA, Replay und Offlinevalidator im Arbeitsbereich vollständig erhalten und geprüft: acht Vorher-, acht Nachher-, acht chronologische Gameplaybilder und eine geklärte transiente Bildladeprobe. Originale Aufnahmecommits bleiben 2b8ea627 beziehungsweise 0f346b0; ältere Bilder werden nicht als neue Audio-/Releaseprüfung umetikettiert.

Das vollständige lokale Paket `ORAFOLD-visual-evidence-30814a5.zip` enthält 57 Dateien, 25 PNGs, 24.970.580 Bytes; SHA-256 `458ef46a018cb98908b157e7f18132b006b6da7dadae4e9e611dbd78a0657dd1`. Der tatsächliche Offlinevalidator bestätigt PNG-Hashes/CRC/Scanlines/native DPR, acht Geometriepaare und die erhaltene 45-Befehl-/412-Ereignis-Replaykette. Das ist kein Web-Spielbuild.

Die zusätzliche Übertragung dieser Screenshotdateien per Connector wurde nach langen Aufrufen ohne API-Antwort unterbrochen; unbestätigte Blobwrites zählen nicht als hochgeladen, und kein unvollständiger Galeriebaum wurde veröffentlicht. Die originalen Dateien und das geprüfte ZIP bleiben unverändert verfügbar. Diese Einschränkung betrifft zusätzliche Screenshotbelege, nicht die bereits vollständig integrierten 550 Kartenillustrationen oder das grün geprüfte Webartefakt.
