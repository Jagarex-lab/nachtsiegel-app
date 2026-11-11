# Begrenzte Wiederholung der CI-Abhängigkeitsinstallation

## Beobachteter Fehler

Die erste Prüfung von PR #28 auf Head `567add86ce2955b826043de1b5a2276d42db76fb` scheiterte unter anderem vor den Anwendungstests. Drei voneinander getrennte Integrationsjobs meldeten bei Playwrights Betriebssystem-Abhängigkeiten wiederholt `Temporary failure resolving 'azure.archive.ubuntu.com'`, fehlgeschlagene Ubuntu-Paketdownloads und APT-Exit 100. Die strenge Artefaktübertragung fand anschließend erwartungsgemäß noch keine Anwendungs-Testlogs. Die Audio-Installation verwendete zusätzlich schon vor Playwright ein ungeschütztes `apt-get update` für FFmpeg.

Dieser Infrastrukturfehler ist von den separat gefundenen UI-Kontrast-/Überlaufproblemen zu unterscheiden. Ein fehlgeschlagener Installationsschritt ist keine bestandene Browserprüfung. Die ursprünglichen GitHub-Läufe bleiben fehlgeschlagene Nachweise; eine neue Source benötigt neue vollständige CI.

## Tatsächliche Änderung

`tools/ci/install_dependencies.py` vereinheitlicht die vorhandenen Installationsschritte, ohne eine Prüfung zu entfernen:

1. Zuerst werden die normalen Ubuntu-Mirrors verwendet. Playwright erhält weiterhin `install --with-deps` und dieselben verlangten Browser. FFmpeg wird weiterhin über ein tatsächliches `apt-get update` und `apt-get install -y ffmpeg` installiert.
2. Eine ausschließlich für diesen Aufruf angelegte Datei in `/etc/apt/apt.conf.d/` begrenzt Acquire-Wiederholungen auf 2 und HTTP-/HTTPS-Zeitgrenzen auf 20 Sekunden. Fehlgeschlagene Indexaktualisierungen bleiben Fehler. Die benannte Datei wirkt auch auf Playwrights interne `sudo sh -c apt-get`-Prozesse; ein möglicherweise von sudo verworfenes `APT_CONFIG`-Environment wird nicht vorausgesetzt.
3. Nur nach einer tatsächlichen Ubuntu-Abhängigkeits-/Paketdownload-Fehlermeldung folgt höchstens ein weiterer Versuch. Eine reguläre vorhandene Ubuntu-Mirrorlist wird dafür vorübergehend auf die offiziellen HTTPS-Adressen `archive.ubuntu.com` und `security.ubuntu.com` gesetzt. Originalbytes, Eigentümer, Rechte und Zeitstempel werden mitgesichert und anschließend wiederhergestellt. Nicht-Ubuntu-Systeme sowie fehlende oder verlinkte Mirrorlists werden nicht umgeschrieben.
4. Die Installationsbefehle jedes Versuchs erhalten zusammen höchstens 300 Sekunden; danach folgt ein gesondert begrenzter Prozessabschluss. Beim Timeout wird ausschließlich die eigene beim Start erzeugte Prozessgruppe mit autorisiertem TERM und nötigenfalls KILL beendet, einschließlich sudo-/APT-Kindern. Es gibt weder ein globales pkill noch gelöschte Paketmanager-Sperren.
5. Die temporäre APT-Konfiguration wird im Abschlussblock entfernt. Ein Wiederherstellungsfehler lässt den Schritt ebenfalls fehlschlagen. Erfolgloser Fallback, reine Browser-CDN-Fehler oder nicht unterstützte Konfigurationen werden nicht als Erfolg behandelt.

GPG-Prüfung, HTTPS-/Zertifikatsprüfung, Playwright-Abhängigkeiten und dessen normale Hostvalidierung bleiben aktiv. Es gibt keine feste IP-Zuordnung, keinen Hosts-/Resolver-Hack, keine fremden Zugangsdaten und keine Änderung von Repository-, Branch-, Environment- oder Pages-Sicherheitseinstellungen. Der aktive Publisher und sein Guard bleiben byteidentisch.

Die bisherigen Jobnamen und Matrixeinträge bleiben erhalten. Für den Main-Job `test-and-export` steigt das Gesamtbudget von 45 auf 65 Minuten: Die zusätzliche vollständige Bildkettenprüfung und neun realen räumlichen Renderings benötigen auf dem lokalen Software-Renderer rund 20 Minuten. Das bisherige Budget der bestehenden Regressionen bleibt damit verfügbar. Die einzelnen 600-Sekunden-Fehlergrenzen und sämtliche Assertions bleiben unverändert; andere Jobbudgets werden nicht erhöht. Der Installer wird in Main-, Alpha-, Audio-, Economy- und Kampagnen-Workflows verwendet; die Online-Prüfung nutzt denselben Integrationsworkflow. Die eigenen Installer-Vertragstests laufen innerhalb vorhandener Main- und Release-Safety-Schritte. Ein zusätzlicher veröffentlichungsberechtigter oder verpflichtender 21. Job wird nicht eingeführt.

## Diagnostik und Nachweise

Das angeforderte Log wird bereits vor dem npm-Bootstrap angelegt und erfasst dessen Ausgabe mit aktivem Shell-Pipefail; der Installer hängt seine Diagnostik anschließend an. Es liegt jeweils innerhalb der bereits erfassten Evidence-Verzeichnisse, etwa `work/alpha03/browser-install.log` oder `work/audio/system-install.log`. Die Main-Browserübertragung nimmt zusätzlich ihren Installationslog auf. Die Regel `if-no-files-found: error` des Integrationsworkflows wird nicht abgeschwächt.

```sh
python3 -W error::ResourceWarning -m unittest discover -s tests/ci -v
python3 -m unittest discover -s tests/release -v
```

Fünfzehn lokale Tests mit kleinen Fake-Installer-Prozessen und gezielten Prozessgegenproben prüfen normalen Erstversuch, unverändertes `--with-deps`, genau einen offiziellen Fallback, anhaltenden Fehler, CDN-Abgrenzung, ungeeignete Mirrorlists, Originaldaten/-rechte, Konfigurationskonflikt, Wiederherstellungsfehler und die tatsächliche Beendigung eines gestarteten Kindprozesses bei Zeitüberschreitung. Auch ein unerwartet nach TERM/KILL offener Ausgabekanal führt nach begrenzter Wartezeit ausdrücklich zu einem Fehler. Die Tests schreiben ausschließlich in temporäre Verzeichnisse; sie ändern keine lokalen Systemquellen und installieren keine echten Pakete. Der FFmpeg-Vertrag prüft die wirklichen auszuführenden APT-Kommandos ohne einen Paketdownload.

Die lokalen Verträge sind kein Nachweis, dass ein externer DNS-Ausfall behoben ist. Wenn auch die offiziellen Ubuntu-Archive nicht erreichbar sind, bleibt die neue CI ausdrücklich fehlgeschlagen. Erst der tatsächliche frische GitHub-Lauf kann die komplette Installation und anschließend alle Browser-/Anwendungstests bestätigen. Die Änderung verspricht keine unbegrenzte Wiederholung und keine künstlich grüne CI.
