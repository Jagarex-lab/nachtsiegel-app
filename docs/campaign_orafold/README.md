# ORAFOLD – Kampagnenbasis

Technisch spielbarer, isolierter Prototyp auf einem eigenen Feature-Branch. **Keine freigegebene Hauptgeschichte.** Zwei Kapitel, 13 Szenen, zwei Entscheidungen, gespeicherte Konsequenzen, zwei Abschlussvarianten und ein tatsächliches Alpha-Übungsduell demonstrieren die Architektur.

```sh
godot --path . scenes/campaign_orafold/campaign_overview.tscn
bash tools/test_campaign_orafold.sh
```

Der reguläre Einstieg bleibt unverändert. Der separate Speicher ist `user://orafold_campaign_v2.json`; vorhandene Alpha- und Arvess-Spielstände werden nicht verändert. Nach einer Niederlage lässt sich das Übungsduell erneut spielen; abgeschlossene Kapitel können in einem isolierten Durchlauf wiederholt werden.

- [Architektur und Datenvertrag](ARCHITECTURE.md)
- [Integration und Adapter](INTEGRATION.md)
- [Story-Präsentation und Bedienung](PRESENTATION.md)
- [Audit und Migrationsbericht](MIGRATION.md)
- [Narrative Regeln, Dialoge und Charakterwissen](NARRATIVE-DESIGN.md)
- [Inhaltsstatus und Lore-Abgleich](CONTENT-STATUS.md)
- [Ausführlicher vorläufiger Kampagnenplan](CAMPAIGN-PLAN.md)
- [Tests, Belege und Abnahmegrenzen](QA.md)

Die [Lore-Bibel](../LORE-BIBLE.md) bleibt die zentrale Weltreferenz. Sena und die Beispielhandlung sind Vorschläge. Eira erhält weder ein erfundenes Aussehen noch eine aufgelöste Vergangenheit. Der längerfristige Kampagnenplan unterscheidet belegte Festlegungen, abgeleitete Möglichkeiten, neue Vorschläge und offene Entscheidungen.
