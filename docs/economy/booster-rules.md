# Konfigurierbare Karten- und Boosterökonomie

Alle Werte unten sind **Testkonfiguration, nicht kommerziell freigegeben**. Policyformat versioniert; veröffentlichte Revisionen immutable. Freie und bezahlte Standardbooster können dieselbe Ziehpolicy verwenden, Produktangebot/Preis ist davon getrennt. Kein Geschäftsparameter als versteckte Konstante im Client.

## Vorschlag für einen vollständigen Ziehvertrag

```json
{
  "schema_version":1,
  "booster_id":"standard-test",
  "revision":1,
  "pool_ref":"legacy-test@1",
  "rarity_order":["common","rare","epic","legendary"],
  "rarity_weights_bps":{"common":7000,"rare":2400,"epic":500,"legendary":100},
  "slots":[{"count":2,"minimum_rarity":"common"},{"count":1,"minimum_rarity":"rare"}],
  "guarantee":{"kind":"dedicated_slot","minimum":"rare","count":1},
  "within_rarity":{"algorithm":"uniform_eligible_card_id","without_replacement_in_pack":false},
  "duplicates":{"policy":"prefer_under_target_then_allow","basis":"lifetime_obtained","target_by_rarity":{"common":3,"rare":3,"epic":3,"legendary":1},"include_starter":false,"include_loans":false,"on_exhausted":"allow_duplicates"},
  "pity":{"scope":"account_and_pool_family","family":"standard-test","threshold_packs_without_legendary":10,"guaranteed_slot_index":2,"on_trigger":"legendary","reset_on_any_legendary":true,"carry_over":"same_family_only"},
  "binding":{"default":"unbound","exceptions":[]},
  "salvage":{"enabled":true,"policy_ref":"salvage-test@1","automatic":false},
  "distribution_algorithm":"ordered-slots-v1",
  "status":"draft"
}
```

Basisgewichte sum10000; common70%, rare24%, epic5%, legendary1% für unbeschränkten Slot. Mindestslot filtert common heraus und normalisiert **2400:500:100**, also rare80%, epic16⅔%, legendary3⅓% vor Pity und Duplikatschutz. Basisgewichte sind keine Packwahrscheinlichkeit; die tatsächlichen Slot-/Packchancen müssen aus der zusammengesetzten Policy offengelegt werden. Pity und Besitzhistorie machen Wahrscheinlichkeiten zustandsabhängig. Keine irreführende pauschale „1%“ für alle Ergebnisse.

## Exakte Reihenfolge und Zählung

1. Policy/Poolrevision der PackUnit und relevanten account+family-Zähler sperren. Server prüft nichtleeren zulässigen Kartenpool je Rarität/Zweig, Zeit/Zugangsfreigabe. Defekte Konfiguration verhindert Öffnung **ohne Verbrauch**; kein stilles Herabstufen einer Garantie.
2. `misses` zählt aufeinanderfolgende abgeschlossene Packs ohne legendäre Karte. Wenn beim Beginn `misses>=9`, ist dieses zehnte Pack spätestens garantiert legendär in Slotindex2 (nullbasiert), sofern bis dahin kein legendärer Slot gefallen ist. Bei natürlicher Legendärer zuvor greift kein zusätzlicher Zwang; mindestens eine ist erfüllt.
3. Slots von0 an ziehen: Mindestseltenheit anwenden; falls dieser Slot nach Schritt2 erzwungen ist, rarity=legendary, sonst Integergewicht im erlaubten Raritätsraum per CSPRNG. Rejection Sampling vermeidet Modulo-Bias. Danach innerhalb der Seltenheit Karte aus dem eingefrorenen Pool auswählen.
4. Duplikatschutz nur innerhalb gezogener Rarität: Kandidaten bevorzugen, deren dauerhafte Erwerbshistorie unter Zielanzahl liegt. Zur Historie gehören nach Policy auch verkaufte/verwertete geeignete Karten und frühere Slots **dieses** Packs; Leihrechte nie. Ist die Seltenheit vollständig am Ziel, gleichverteilt aus ihr ziehen; kein endloser Reroll, keine freie Seltenheitsaufwertung. Temporärer Besitzabbau setzt Schutz nicht zurück.
5. Instanzen mit Bindung nach Ursprungs-/Ausnahmepolicy erzeugen; Standard ist unbound. Wenn im Pack mindestens eine legendäre Karte liegt, misses=0, sonst misses+1. Genau einmal pro committed Pack aktualisieren, nicht pro Request oder Slot. Gesamtpaket committen wie im [Transaktionsvertrag](inventory-transactions.md).

Poolfamilien teilen Pity nur explizit; saisonaler Wechsel setzt keinen bezahlten Fortschritt unangekündigt zurück. Bereits erworbene Packs pinnen Policy und Pool. Familienmigration braucht definierte Konversion/Kommunikation; `carry_over` ist keine spontane Serverheuristik. Keine Ratenänderung durch individuelle Zahlungsbereitschaft, Verlustserie im Kampf oder verdeckte Experimente.

## Kartenherkunft und Bindungsregeln

| Herkunft | Defaultvorschlag / Konfiguration | Einschränkung |
|---|---|---|
| Regulärer kostenloser Booster | unbound | Genau wie bezahlter Booster grundsätzlich handelbar |
| Regulärer bezahlter Booster | unbound | Handel ggf. expliziter veröffentlichter Sicherheitscooldown; bezahlter Handel bis Produkt-/Rechts-/Chargebackfreigabe nicht aktiv |
| Vollständiger Tutorialstarter | separater `starter-complete@1`-Grant; account_bound als offene Empfehlung | Explizite Gratisreward-Ausnahme, nicht stiller Ausschluss normaler Boosterkarten |
| Saisonaler Booster | Pool und Policyrevision pinnen, unbound | Rotation regelt Spielbarkeit, nicht Eigentumsentzug |
| Legacy-Karten | stabile Original-ID/Regelrevision, gleiche Defaultbindung bei Boosterzug | Kein Rückschluss von aktuellen Prototypnamen auf Besitz; alte lokale Sammlung nicht verifiziert |
| Draft-/Sealed-Leihe | Entitlement, keine CardInstance | Nicht verkauf-/verwert-/übertragbar; separat deklarierter Reward kann neue dauerhafte Instanz erzeugen |
| Promotion/Supportreward | explizite Binding-Ausnahme mit reason, policy_ref | Vorher sichtbar; keine globale unbekannte Ausnahme |

Policy-Publisher lehnt unbekannte/implizite Bindung, leere Dropgruppen, negative Gewichte, Summe≠10000, fehlende Garantie-/Pity-Kandidaten oder gebrochene Counts ab. `trade_after` ist ein zeitlicher Trade-Gate, keine rückwirkende permanente Bindung. Bereits veröffentlichte Ursprungsbindung bleibt im Audit; Sicherheitsquarantäne hat eigenen Grund und Beschwerdepfad.

## Sammlung über kostenlose und bezahlte Booster

Tutorialgrant garantiert vollständiges versioniertes START-Deck ohne Kauf, Markt oder Zufall. Bei Legacy-Ziel bedeutet das25 konkrete Originalkopien; Auswahl dieses Decks bleibt an die spätere Legacy-Spielbarkeitsentscheidung gekoppelt. Alle regelmäßigen Erweiterungen primär über transparente Gratis-/Spielbelohnungsbooster und optional bezahlte Booster; einzelne Event-/Tutorial-/Supportkarten als benannte Ausnahme. Regelmäßige Gratisbooster an serververifizierte, gedeckelte Quellen binden (z.B. Wochencheckpoint), nicht an beliebige wiederholbare Clientmeldungen oder Geräteuhr.

Konfiguration enthält pro Rewardquelle `quota`, `period`, eligibility und policy_ref. Kein hier festgelegter Preis, Tageszwang oder Verkaufsplan. Ein Premiumprodukt kann mehr Packs/Kosmetik statt stärkere Werte enthalten; exklusive spielstarke Karten oder zahlungsabhängige Raten sind nicht vorgesehen. F2P-Zeit bis konkurrenzfähiges Deck und Anteil boosterbasierter dauerhafter Kartenerwerbe messen; Zielschwellen müssen Produktdesign bestätigen.

Duplikatverwertung nur bewusst je eigener Instanz mit konfigurierter Ausbeute. Rückkopplung beachten: garantiertes Pack + Pity + Schutz + Salvage + Markt darf keine unlimitierte profitable Farming-Schleife erzeugen. Erst Simulation, dann Freigabe der Parameter.

## Abnahmefälle für spätere Implementierung

Exakte Garantien/Pity per Zustandsautomat prüfen, nicht nur über Stichprobenerwartung. Slots vor/auf/nach Zehntpackgrenze, natürliche Legendäre in Slot0, leere Raritätsgruppe, komplette Sammlung, Verkauf zur Schutzmanipulation, zwei Öffnungen parallel, fehlgeschlagener Commit, doppelte Keys, Saisonwechsel und Ursprungsbindung testen. Statistische Tests mit dokumentiertem Konfidenzniveau ergänzen deterministische Grenztests; CSPRNG und ökonomische Fairness sind verschiedene Nachweise. Keine dieser Tests ist hier als implementiert bezeichnet.
