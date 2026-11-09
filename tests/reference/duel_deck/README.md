# Fixierte JavaScript-Testreferenz

`engine.js` ist eine byteidentische Kopie aus [duel-deck, Commit 34b3062c3f22c0950d9323ad9b97b17c41d1d14f](https://github.com/Jagarex-lab/duel-deck/blob/34b3062c3f22c0950d9323ad9b97b17c41d1d14f/engine.js). Kein Patch und keine Neuimplementierung. `source.lock.json` hält Commit, Git-Blob und SHA-256; `tools/legacy/reference.cjs` prüft alle drei gegen die festen Referenzwerte, bevor es die Engine in einer frischen VM lädt. Keine Netzwerkabhängigkeit beim Testlauf.

Verwendung ausschließlich als Testoracle/Fixturegenerator; weder Browser noch Arena laden diese Datei. Die bestehenden Godot-Referenzregeln bleiben separat erhalten. Optionaler Checkout-Nachweis prüft HEAD **und** Dateibytes und lehnt andere Commits oder lokale Änderungen an engine.js ab.

Die Quelle gehört zum vom Auftraggeber benannten Repository. In diesem fixierten Upstream ist keine LICENSE-/COPYING-Datei versioniert; hier wird keine neue Lizenz oder kommerzielle Nutzungserlaubnis behauptet. Eine spätere Produktfreigabe benötigt die entsprechende Rechteklärung durch den Rechteinhaber. Die Referenz wird nicht als Produktions-Kampfengine integriert.
