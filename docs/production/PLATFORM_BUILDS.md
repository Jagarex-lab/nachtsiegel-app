# Native Plattformprüfungen

Der lokale Wrapper `tools/build_platform_qa.sh` erzeugt ausschließlich Debug-Exporte. Er veröffentlicht nichts und besitzt keine Store- oder Apple-Signaturberechtigung.

## Tatsächliche Korrektur am Exporttest

Das offizielle Godot-4.6.3-Linux-Debugtemplate unterstützt weder `--path` noch `--script`. Der erste Versuch wurde wegen `--path` ausdrücklich abgewiesen. Nach Entfernen dieses Arguments ignorierte das Template `--script` und blieb tatsächlich im Hauptmenü, bis der strikte 300-Sekunden-Timeout ablief. Dieser Versuch ist **kein bestandener Kampftest**.

Der reguläre `Linux QA`-Export behält daher das normale Hauptmenü. Sein tatsächlicher Start wird aus einem leeren Verzeichnis geprüft. Ein zweiter, ausdrücklich `Linux Runtime QA` genannter Export verwendet allein über das Custom-Feature `native_smoke_qa` eine kleine QA-Einstiegsszene. Sie lädt dieselben tatsächlich gepackten 550 Definitionen, vier Starter, Produktionsengine und KI; sie spielt eine vollständige Partie bis zum echten Endzustand. Der normale Web-, Android- und Linux-Start wird nicht umgeschaltet. Der Test ist im Paket enthalten und benötigt keine losen Skripte oder Ressourcen aus dem Checkout.

## Lokaler Entwicklungsnachweis

Am 10.11.2026 bestanden auf dem Entwicklungsstand nach `ae8478f` mit damals noch uncommitted QA-Einstiegsszene:

- Regulärer exportierter Linux-Spielstart ohne Script-/Ressourcenfehler.
- Eigenständiges natives QA-Programm: **12 Assertions, 0 Fehler**, eine tatsächlich beendete Partie Vielgestalt gegen Stillwacht, Seed 777, Sieg des Spielers nach 25 Halbzügen. Kein erzwungener Sieger oder verkürzter Schadenssimulator.
- Android-Debug-APK tatsächlich gebaut, mit `apksigner verify` geprüft; Manifest/Badging bestätigt ORAFOLD und die erhaltene Paketidentität `com.jagarex.nachtsiegel`.

Diese frühe Probe ist kein Nachweis eines späteren unveränderten Integrationscommits. Der Wrapper erfasst deshalb jetzt vor dem Export die SHA-256 der tatsächlichen Projekt-, Skript-, Szenen-, Daten- und Assetdateien, prüft sie nach dem gesamten Lauf erneut und speichert Commit, Dirty-Status sowie die Hashes beider Linux-Programme und der APK unter `work/production/platforms/results.json`. Vor Release wird der tatsächliche integrierte Stand erneut gebaut und geprüft.

```sh
DISPLAY=:99 tools/build_platform_qa.sh
```

Die aktuellen Ergebnisse sind Debug-/Paketprüfungen. Kein Android-Gerät oder physisches iPhone wurde getestet. Native iOS-Builds, Xcode, Provisioning, Store-Signaturen, Touch-/GPU-/Thermaltests auf Geräten und kommerzielle Auslieferung bleiben offen. Die WebKit-Browserprüfungen sind gesonderte automatisierte Browsernachweise und ersetzen diese Gerätetests nicht.
