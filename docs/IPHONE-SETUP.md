# iPhone- und Android-Prüfung

Die getestete Webversion wird nach ausdrücklicher Freigabe des Nutzers automatisch auf https://jagarex-lab.github.io/nachtsiegel-app/ veröffentlicht. Der Workflow **NACHTSIEGEL Test and Publish** veröffentlicht ausschließlich nach erfolgreichen Tests auf `develop` und prüft anschließend die öffentliche Seite. Das ist keine native Store-Veröffentlichung.

## Web auf dem Telefon

Die Spielseite in Safari bzw. Chrome öffnen. Für lokale Entwicklung den Inhalt von `work/build/web/` über HTTPS oder einen erreichbaren Entwicklungsserver ausliefern; die HTML-Datei nicht über `file://` öffnen. Auf Safari bzw. Chrome im Querformat testen. Der Webexport verwendet keine Threads und benötigt deshalb keinen SharedArrayBuffer. Der lokale QA-Bericht deckt Chromium mit simuliertem Touch ab, keinen echten Mobile-Safari-Test.

## Native Android-Version

Godot 4.6.3 mit passenden Exportvorlagen, Java und Android-SDK konfigurieren. Das Preset **Android QA** erzeugt eine Debug-APK für arm64 und x86_64. Einen lokalen Debug-Schlüssel in Godots Editor-Einstellungen konfigurieren; keine Schlüssel einchecken. Die lokal erzeugte APK wurde paket- und signaturgeprüft, aber nicht auf einem Android-Gerät gestartet. Erst nach Installation auf echten Geräten Akku-/GPU-Verhalten, Safe Areas, Unterbrechungen und Touch-Ergonomie freigeben.

## Native iOS-Version

Auf einem Mac Godot 4.6.3 und die iOS-Exportvorlagen installieren, ein iOS-Preset mit eigener Bundle-ID und Team-ID erstellen, Xcode-Projekt exportieren, signieren und auf einem iPhone prüfen. Team-ID und Signierschlüssel gehören nicht ins Repository. Der Linux-Entwicklungsrechner hat weder Xcode noch ein iPhone; ein iOS-Build und die native iOS-Laufzeit sind hier nicht verifiziert.

Die Arena hält äußere Abstände frei und zentriert das vollständige Spielfeld im Querformat. Die native Notch-/Display-Safe-Area muss auf den Zielgeräten kontrolliert werden. Kleiner Kartentext wird in der Großansicht lesbar; Mindest-Touch-Flächen wurden in simulierten Viewports geprüft, nicht physisch vermessen.
