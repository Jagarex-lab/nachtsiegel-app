# Historischer CI-Provisionierungsfehler auf 183192

Der unveränderte, SHA256-geprüfte ZIP enthält den fehlgeschlagenen Browser-Installationslauf. Offizielle Ubuntu-Indizes waren erfolgreich; eine unabhängige Microsoft-Quelle antwortete zweimal mit HTTP 429. Die integrierten Tests liefen nicht. Der Fehler bleibt als Fehler erhalten und hat die Veröffentlichung korrekt blockiert.

Nachverfolgung: https://github.com/Jagarex-lab/nachtsiegel-app/issues/33 . Eine spätere grüne QA gilt nur für ihren exakten neuen Commit und ersetzt diesen Fehlversuch nicht. Kein Workflow aus diesem Archiv wird aktiviert.

Der erste Reparatur-Head5364 wurde nicht gemergt: Seine Rechteprüfung passte nicht zum offiziellen Runner-Image, das /usr/share auf777 setzt. first-repair.json und zwei Originalarchive erhalten diesen Fehlversuch. ubuntu-keyring-provenance.json dokumentiert die unabhängig geprüfte Noble-Paket-/Signaturkette für die korrigierte Snapshot-Variante; es handelt sich ausschließlich um öffentliches Ubuntu-Schlüsselmaterial, nicht um einen privaten Schlüssel oder neue Zugangsberechtigungen. TLS, GPG und sämtliche Test-/Releasegates bleiben aktiv.
