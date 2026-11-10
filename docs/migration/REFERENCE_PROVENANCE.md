# Herkunft der übernommenen Auditdokumentation

Für den Folgeauftrag P01a–P01c/P02a–P02c wurden die Dateien aus `docs/migration/` des weiterhin separaten [Audit-PR #1](https://github.com/Jagarex-lab/nachtsiegel-app/pull/1) übernommen.

- Quellbranch: `audit/legacy-functional-parity`.
- Quellcommit: `51ad544087dba200846b4420e493fcbe656c634f`.
- Grundlage des neuen Feature-Branches: `develop` bei `b1f5ea59a4754bac19df31e279bff8a295cb6ea8`.
- Übernahme: explizite Dateikopie mit `git restore --source … -- docs/migration`, **kein Merge, kein Cherry-pick des Auditcommits**. Die Auditdateien einschließlich damaliger Protokolle bleiben als historischer Nachweis unverändert.
- Der Auditbericht und seine Statuszahlen beschreiben den damaligen Vergleich. Die neue Kataloggrundlage behebt noch keine seiner fehlenden produktiven Kampffähigkeiten.
- Der alte Plan ist eine Referenz, kein Auftrag zur Umsetzung der übrigen Pakete. Für diesen PR gelten ausschließlich P01a–P01c und P02a–P02c. Weder Entscheidung über einen späteren Regelmodus noch Freigabe einer Namenszuordnung wird vorweggenommen.

Neue Implementierung, aktuelle Tests und offene Grenzen stehen in [LEGACY_FOUNDATIONS.md](LEGACY_FOUNDATIONS.md). Dateien unter `evidence/logs/` gehören zum früheren Audit; aktuelle Nachweise werden separat unter `foundations-evidence/` geführt.
