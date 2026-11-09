# Tatsächlich implementierter Kartenpool

Quelle: `data/alpha/cards.json`. 55 verschiedene IDs: 37 Kreaturen,12 Ereignisse,6 Relikte. 15 neutrale und10 je Macht. Alle55 besitzen konkrete ausführbare Effekte und werden auf beiden Spielerseiten geprüft; keine Konzeptkarte wird als spielbar gezählt. Illustrationen: klar gekennzeichnete wiederverwendete Platzhalter.

Vier Starter unter `starters`: je30 Karten, eine Macht plus neutral,3er-Kopienlimit/Legendär1. Alle Karten für lokale Tests freigeschaltet. Vier Archetyp-Bezeichnungen je Macht unter `identities` sind Gestaltungsrichtungen, **keine16 fertigen Decks**. Der getrennte Legacy-Katalog enthält100 Originalkreaturen mit unveränderten IDs/Werten und fünf Originallisten. Die sieben Archivkarten zählen zu keinem dieser Pools.

| ID | Name | Macht | Typ | Kosten | ATK/LP | Effekt |
|---|---|---|---|---:|---|---|
| oa-neutral-c01 | Pfadkundiger | neutral | creature | 1 | 1/3 | strike (1) |
| oa-neutral-c02 | Torwache | neutral | creature | 2 | 2/4 | guard (1) |
| oa-neutral-c03 | Prismaträger | neutral | creature | 2 | 1/4 | ward (1) |
| oa-neutral-c04 | Feldärztin | neutral | creature | 2 | 2/4 | mend (1) |
| oa-neutral-c05 | Bündnisträger | neutral | creature | 3 | 2/5 | rally (2) |
| oa-neutral-c06 | Chronist | neutral | creature | 2 | 2/4 | draw (1) |
| oa-neutral-c07 | Eilbote | neutral | creature | 3 | 2/5 | haste (2) |
| oa-neutral-c08 | Wegweber | neutral | creature | 3 | 3/5 | shift (2) |
| oa-neutral-c09 | Resonanzträger | neutral | creature | 2 | 1/4 | weave (1) |
| oa-houses-c01 | Namenhüter | houses | creature | 1 | 1/3 | harvest (1) |
| oa-houses-c02 | Eidärztin | houses | creature | 2 | 2/4 | mend (1) |
| oa-houses-c03 | Blutarchivar | houses | creature | 2 | 1/4 | drain (1) |
| oa-houses-c04 | Erinnerungsleserin | houses | creature | 2 | 2/4 | draw (1) |
| oa-houses-c05 | Erbenwall | houses | creature | 3 | 2/5 | guard (2) |
| oa-houses-c06 | Ahnenrufer | houses | creature | 3 | 3/5 | weave (2) |
| oa-houses-c07 | Die letzte Erbin | houses | creature | 6 | 5/8 | pulse (3) |
| oa-stillwatch-c01 | Glaskonservator | stillwatch | creature | 1 | 1/3 | ward (1) |
| oa-stillwatch-c02 | Ewigwächter | stillwatch | creature | 2 | 2/4 | guard (1) |
| oa-stillwatch-c03 | Nullsekunde | stillwatch | creature | 2 | 1/4 | silence (1) |
| oa-stillwatch-c04 | Siegelrichter | stillwatch | creature | 2 | 2/4 | retaliate (1) |
| oa-stillwatch-c05 | Bewahrerin | stillwatch | creature | 3 | 2/5 | mend (2) |
| oa-stillwatch-c06 | Winterherold | stillwatch | creature | 3 | 3/5 | weaken (2) |
| oa-stillwatch-c07 | Die unbewegte Königin | stillwatch | creature | 6 | 5/8 | pulse (3) |
| oa-morph-c01 | Sprunglarve | morph | creature | 1 | 1/3 | haste (1) |
| oa-morph-c02 | Schwarmrufer | morph | creature | 2 | 2/4 | rally (1) |
| oa-morph-c03 | Pfadwanderin | morph | creature | 2 | 1/4 | shift (1) |
| oa-morph-c04 | Sporenträger | morph | creature | 2 | 2/4 | harvest (1) |
| oa-morph-c05 | Häutungsweiser | morph | creature | 3 | 2/5 | draw (2) |
| oa-morph-c06 | Gegendorn | morph | creature | 3 | 3/5 | retaliate (2) |
| oa-morph-c07 | Die Vielstimmige | morph | creature | 6 | 5/8 | pulse (3) |
| oa-ninth-c01 | Kausaljäger | ninth | creature | 1 | 1/3 | strike (1) |
| oa-ninth-c02 | Spaltenspeer | ninth | creature | 2 | 2/4 | pierce (1) |
| oa-ninth-c03 | Vorzeichner | ninth | creature | 2 | 1/4 | weaken (1) |
| oa-ninth-c04 | Uhrlose | ninth | creature | 2 | 2/4 | silence (1) |
| oa-ninth-c05 | Schuldzehrer | ninth | creature | 3 | 2/5 | drain (2) |
| oa-ninth-c06 | Möglichkeitsweber | ninth | creature | 3 | 3/5 | weave (2) |
| oa-ninth-c07 | Der neunte Zeuge | ninth | creature | 6 | 5/8 | pulse (3) |
| oa-neutral-e01 | Prismenblitz | neutral | event | 2 | 0/0 | bolt (3) |
| oa-neutral-e02 | Atempause | neutral | event | 2 | 0/0 | heal (5) |
| oa-neutral-e03 | Festes Bild | neutral | event | 2 | 0/0 | stasis (2) |
| oa-neutral-e04 | Doppelter Schritt | neutral | event | 3 | 0/0 | surge (1) |
| oa-houses-e01 | Wiederkehr | houses | event | 3 | 0/0 | recall (1) |
| oa-houses-e02 | Letzter Eid | houses | event | 1 | 0/0 | heal (3) |
| oa-stillwatch-e01 | Aufgeschobenes Urteil | stillwatch | event | 2 | 0/0 | delay (4) |
| oa-stillwatch-e02 | Konservierung | stillwatch | event | 2 | 0/0 | stasis (2) |
| oa-morph-e01 | Seitenwechsel | morph | event | 2 | 0/0 | displace (1) |
| oa-morph-e02 | Rascher Wandel | morph | event | 3 | 0/0 | surge (1) |
| oa-ninth-e01 | Umleitung | ninth | event | 1 | 0/0 | redirect (1) |
| oa-ninth-e02 | Echosalve | ninth | event | 5 | 0/0 | cascade (10) |
| oa-neutral-r01 | Wanderkompass | neutral | relic | 2 | 0/0 | relic_res (1) |
| oa-neutral-r02 | Feldspiegel | neutral | relic | 2 | 0/0 | relic_ward (1) |
| oa-houses-r01 | Ahnenregister | houses | relic | 2 | 0/0 | relic_heal (1) |
| oa-stillwatch-r01 | Bewahrungsuhr | stillwatch | relic | 2 | 0/0 | relic_ward (1) |
| oa-morph-r01 | Schwarmknoten | morph | relic | 2 | 0/0 | relic_res (1) |
| oa-ninth-r01 | Vorhersagelinse | ninth | relic | 3 | 0/0 | relic_draw (1) |
