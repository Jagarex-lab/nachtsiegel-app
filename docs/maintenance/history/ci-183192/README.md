# Historischer CI-Provisionierungsfehler auf 183192

Der unveränderte, SHA256-geprüfte ZIP enthält den fehlgeschlagenen Browser-Installationslauf. Offizielle Ubuntu-Indizes waren erfolgreich; eine unabhängige Microsoft-Quelle antwortete zweimal mit HTTP 429. Die integrierten Tests liefen nicht. Der Fehler bleibt als Fehler erhalten und hat die Veröffentlichung korrekt blockiert.

Nachverfolgung: https://github.com/Jagarex-lab/nachtsiegel-app/issues/33 . Eine spätere grüne QA gilt nur für ihren exakten neuen Commit und ersetzt diesen Fehlversuch nicht. Kein Workflow aus diesem Archiv wird aktiviert.
