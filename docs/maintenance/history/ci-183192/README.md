# Historischer CI-Provisionierungsfehler auf 183192

Der unveränderte, SHA256-geprüfte ZIP enthält den fehlgeschlagenen Browser-Installationslauf. Offizielle Ubuntu-Indizes waren erfolgreich; eine unabhängige Microsoft-Quelle antwortete zweimal mit HTTP 429. Die integrierten Tests liefen nicht. Der Fehler bleibt als Fehler erhalten und hat die Veröffentlichung korrekt blockiert.

Nachverfolgung: https://github.com/Jagarex-lab/nachtsiegel-app/issues/33 . Eine spätere grüne QA gilt nur für ihren exakten neuen Commit und ersetzt diesen Fehlversuch nicht. Kein Workflow aus diesem Archiv wird aktiviert.

Der erste Reparatur-Head5364 wurde nicht gemergt: Seine Rechteprüfung passte nicht zum offiziellen Runner-Image, das /usr/share auf777 setzt. first-repair.json und zwei Originalarchive erhalten diesen Fehlversuch. ubuntu-keyring-provenance.json dokumentiert die unabhängig geprüfte Noble-Paket-/Signaturkette für die korrigierte Snapshot-Variante; es handelt sich ausschließlich um öffentliches Ubuntu-Schlüsselmaterial, nicht um einen privaten Schlüssel oder neue Zugangsberechtigungen. TLS, GPG und sämtliche Test-/Releasegates bleiben aktiv.

Der zweite nicht gemergte Head 2b65 bestand die korrigierte Browserinstallation,
scheiterte danach aber am unveränderten strikten Ressourcen-Guard des
Kampagnen-Präsentationstests. presentation-failure.json und das dazugehörige
Originalarchiv pr34-2b65-integration-failure.zip erhalten diesen unabhängigen
Fehler, seine Grenzen sowie den deterministischen Test-Ownership-Nachweis
vor und nach der eng begrenzten Testkorrektur. Die konkrete ursprüngliche
CI-Allokationsspur ist mangels verbose Ausgabe nicht bekannt.

Die native Präsentation und integrierten Module bestanden auf af6 nach dem
Test-Fix vollständig. Dessen zusätzlicher eigenständiger Kampagnenlauf wurde
jedoch vom URI-Guard vor APT zurückgewiesen. campaign-source-variant.json und
pr34-af6-campaign-failure-log.zip erhalten den ganzen dekodierten Job-Log,
Artefaktmetadaten, die belegten offiziellen Quellenvarianten und die Grenze,
dass der konkrete historische URI nicht ausgegeben wurde.

Das zusätzliche Audio-Originalartefakt pr34-af6-audio-failure.zip ist vollständig
und SHA256-geprüft erhalten. audio-probe-failure.json unterscheidet den echten
WebKit-Absturz, die belegte SDK-Abweichung, die begrenzte Pin-/Vertragstest-
Korrektur und die weiterhin nötige frische reale Browserabnahme.

Der isolierte WebKit-Polling-Fehler ist in polling-probe-failure.json mit
exaktem stdout-Auszug und kontrolliertem Vorher-/Nachherbeleg dokumentiert.
pr34-af6-polling-failure.zip erhält unverändert das kleine GitHub-Artefakt
(Installationslog, keine irreführende Zuordnung des eigentlichen Timeout-Logs).
Die Korrektur behält500ms und alle negativen/Produkt-Kontrollen bei.
