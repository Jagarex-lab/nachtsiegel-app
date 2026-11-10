#!/usr/bin/env python3
"""Reproducible 30-card reference compositions from actual production mechanics.

No card, rule, reward or collection unlock is invented here. These are transparent
heuristic starting points for AI simulation, not a claim of optimized balance.
"""
from __future__ import annotations
import argparse
import collections
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONFIGS = [
    dict(id="prod-aggro", name="Offene Wirklichkeit", strategy="aggro", power="morph", kinds=(23,6,1), effects=["haste","modify_attack","surge","deal_damage"], text="Früher Pfaddruck, Angriffsverstärkung und direkte Heldenangriffe über freie Gegenpfade."),
    dict(id="prod-midrange", name="Erinnerte Stärke", strategy="midrange", power="houses", kinds=(22,6,2), effects=["modify_attack","heal_target","return_card","summon_card"], text="Eine gestaffelte Kostenkurve verbindet widerstandsfähige Wesen mit Wiederkehr und Rekonstruktion."),
    dict(id="prod-control", name="Die ruhende Linie", strategy="control", power="stillwatch", kinds=(17,10,3), effects=["stun_unit","weaken_unit","deal_damage","delay_damage"], text="Stasis und Schwächung begrenzen gegnerische Angriffe; gezielter Schaden öffnet Gegenpfade."),
    dict(id="prod-shield", name="Kristallene Schwelle", strategy="shield", power="stillwatch", kinds=(21,6,3), effects=["grant_shield","ward","relic_ward","heal_target"], text="Schild schützt Wesen und Held über mehrere Züge. Pfadkontrolle bleibt für den Sieg erforderlich."),
    dict(id="prod-block", name="Ein gehaltener Augenblick", strategy="block", power="stillwatch", kinds=(21,7,2), effects=["grant_block","guard","weaken_unit","stun_unit"], text="Block absorbiert Schaden nach den Kampfregeln; schwächere gegnerische Angriffe erleichtern die Stabilisierung."),
    dict(id="prod-recurrence", name="Die offene Rückkehr", strategy="recurrence", power="houses", kinds=(21,6,3), effects=["return_card","recall","harvest","draw_cards"], text="Karten aus dem Ablagestapel kehren zurück. Neue Wesen müssen weiterhin Pfad- und Beschwörungsregeln erfüllen."),
    dict(id="prod-resonance", name="Nachhall der Eingriffe", strategy="resonance", power="ninth", kinds=(19,8,3), effects=["gain_resonance","weave","harvest","relic_res"], text="Resonanzaufbau versorgt besondere Fähigkeiten und Entfesselung; Energie bleibt die Ausspielressource."),
    dict(id="prod-movement", name="Wandernde Schneisen", strategy="movement", power="morph", kinds=(22,6,2), effects=["move_unit","shift","displace","surge"], text="Positionswechsel schaffen freie Gegenpfade oder unterbrechen die gegnerische Pfadkontrolle."),
    dict(id="prod-species", name="Gestalten im Verbund", strategy="species", power="morph", kinds=(24,4,2), effects=["modify_attack","grant_shield","summon_card"], species="morphid", text="Morphiden bilden den Kern. Nur ausdrücklich artspezifische Karteneffekte gewähren einen Artenbonus; die Zuordnung allein erzeugt keinen Bonus."),
    dict(id="prod-relic", name="Tragende Erinnerungen", strategy="relic", power="houses", kinds=(19,7,4), effects=["return_card","draw_cards","gain_resonance","heal_target"], text="Ausgelöste und aktivierbare Reliktfähigkeiten liefern langfristigen Wert. Es bleibt höchstens ein Relikt aktiv."),
    dict(id="prod-impulse", name="Verknüpfte Möglichkeiten", strategy="impulse", power="ninth", kinds=(16,11,3), effects=["deal_damage","draw_cards","delay_damage","gain_energy"], text="Impulse verbinden Kartennachschub mit Schaden und verzögerten Eingriffen; ausreichend Wesen sichern die Pfade."),
    dict(id="prod-convergence", name="Drei gehaltene Wege", strategy="convergence", power="stillwatch", kinds=(23,5,2), effects=["grant_shield","stun_unit","modify_attack","heal_target"], text="Drei kontrollierte Pfade bereiten Konvergenz vor. Der Gegner erhält die reguläre Gelegenheit, diese Vorbereitung zu brechen."),
    dict(id="prod-time", name="Die verschobene Antwort", strategy="time", power="ninth", kinds=(18,9,3), effects=["delay_damage","stun_unit","move_unit","draw_cards"], text="Verzögerte Effekte und Stasis verändern das Timing. Schaden folgt dem festgelegten Pfad und dem tatsächlichen Auflösungszeitpunkt."),
    dict(id="prod-resource", name="Ökonomie der Eingriffe", strategy="resource_control", power="ninth", kinds=(19,8,3), effects=["gain_energy","gain_resonance","draw_cards","discard_card"], text="Ressourcen- und Kartenfluss werden aufeinander abgestimmt. Gegenerische Ressourcen werden nur durch ausdrücklich entsprechend zielende Effekte beeinflusst."),
]


def card_effects(card: dict) -> list[str]:
    return [str(a["effect"]) for a in card.get("abilities", [])] or [str(card.get("effect", ""))]


def score(card: dict, cfg: dict) -> float:
    tags = set(card.get("archetypes", []))
    total = 7.0 * (cfg["strategy"] in tags)
    total += sum(2.8 for e in card_effects(card) if e in cfg["effects"])
    total += 1.3 if card["faction"] == cfg["power"] else 0.0
    if cfg.get("species"):
        total += 4.0 if cfg["species"] in card.get("species", []) else -2.0
        for ability in card.get("abilities", []):
            if ability.get("target") == "own_species":
                total += 3.0 if ability.get("params", {}).get("species") == cfg["species"] else -1.5
    total += 1.2 if 2 <= int(card["cost"]) <= 4 else 0.0
    if cfg["strategy"] == "aggro":
        total += max(0, 5 - int(card["cost"])) * 1.5
    elif cfg["strategy"] in ("control", "relic", "time"):
        total += 0.25 * min(int(card["cost"]), 5)
    if card["id"] == "oa-ninth-e01":
        return -1000.0  # documented Alpha prerequisite gap; not a reference-deck promise
    return total


def build(cards: list[dict], cfg: dict) -> dict:
    eligible = [c for c in cards if c["faction"] in (cfg["power"], "neutral") and c["id"] != "oa-ninth-e01"]
    by_id = {c["id"]: c for c in eligible}
    chosen: list[str] = []
    counts: collections.Counter = collections.Counter()
    curve: collections.Counter = collections.Counter()
    for kind, wanted in zip(("creature", "event", "relic"), cfg["kinds"]):
        pool = [c for c in eligible if c["kind"] == kind]
        for _ in range(wanted):
            legal = [c for c in pool if counts[c["id"]] < (1 if c["rarity"] == "legendary" else 3)]
            if not legal:
                raise ValueError(f"Insufficient legal {kind}: {cfg['id']}")
            def dynamic(c: dict):
                # Diversity and curve constraints are explicit composition choices;
                # they never modify the card or the match rules.
                cost = int(c["cost"])
                curve_penalty = max(0, curve[cost] - 5) * 0.9
                expensive_penalty = max(0, sum(n for k, n in curve.items() if k >= 6) - 3) * 1.8 if cost >= 6 else 0.0
                value = score(c, cfg) - counts[c["id"]] * 1.4 - curve_penalty - expensive_penalty
                return (-value, c["id"])
            card = sorted(legal, key=dynamic)[0]
            chosen.append(card["id"])
            counts[card["id"]] += 1
            curve[int(card["cost"])] += 1
    # Actual shield/control seed2 reached the500-call horizon: pure repeated
    # protection had no credible way through a full weakened board. An existing
    # recurring attack-growth relic supplies a legal win plan without changing
    # any card, resource, lane or victory rule.
    has_growth_finisher = cfg["strategy"] in {"control", "shield", "block", "convergence"}
    if has_growth_finisher:
        finisher="of-stillwatch-097"
        assert by_id[finisher]["rarity"]!="legendary"
        chosen=[finisher if by_id[id]["kind"]=="relic" else id for id in chosen]
        counts=collections.Counter(chosen)
        curve=collections.Counter(int(by_id[id]["cost"]) for id in chosen)
    chosen.sort(key=lambda id: (int(by_id[id]["cost"]), by_id[id]["kind"], id))
    assert len(chosen) == 30
    assert {by_id[id]["faction"] for id in chosen} <= {cfg["power"], "neutral"}
    assert all(n <= (1 if by_id[id]["rarity"] == "legendary" else 3) for id,n in counts.items())
    focus = sorted({e for id in counts for e in card_effects(by_id[id]) if e in cfg["effects"]})
    matched = sorted(id for id in counts if cfg["strategy"] in by_id[id].get("archetypes", []))
    if has_growth_finisher:
        if "modify_attack" not in focus:focus.append("modify_attack");focus.sort()
        matched=["of-stillwatch-097"]+[id for id in matched if id!="of-stillwatch-097"]
        cfg=cfg.copy()
        cfg["text"]+=" Ungebrochene Scheibe verstärkt zu Zugbeginn den Angriff des eigenen Wesens mit dem wenigsten Leben und öffnet eine Gewinnlinie durch lange defensive Blockaden."
    return dict(id=cfg["id"], name_de=cfg["name"], strategy=cfg["strategy"], power=cfg["power"], description_de=cfg["text"], limitations_de="Reproduzierbare Referenzzusammensetzung, kein Nachweis optimaler Spielweise oder gleicher Gewinnchancen. Die KI bewertet Ketten heuristisch.", key_card_ids=matched[:6], focus_effects=focus, species_focus=[cfg["species"]] if cfg.get("species") else [], cards=chosen, metrics=dict(kind_counts=dict(collections.Counter(by_id[id]["kind"] for id in chosen)), cost_curve={str(k):v for k,v in sorted(curve.items())}, unique_cards=len(counts), archetype_matching_unique_cards=len(matched)))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    source = ROOT / "data/production/cards.json"
    parsed = json.loads(source.read_text())
    cards = parsed["cards"]
    assert len(cards) == 550, f"Expected real 550-card catalog, got {len(cards)}"
    decks = [build(cards, cfg) for cfg in CONFIGS]
    differences = {}
    for i, a in enumerate(decks):
        for b in decks[i+1:]:
            overlap = sum((collections.Counter(a["cards"]) & collections.Counter(b["cards"])).values())
            differences[a["id"] + "/" + b["id"]] = 30 - overlap
            assert overlap < 30, f"Identical compositions: {a['id']}, {b['id']}"
    result = dict(schema_version=1, format="ORAFOLD-TEST-DECKS", ruleset_id="production-550-v1", source_catalog="data/production/cards.json", scope_de="Vierzehn echte 30-Karten-Referenzdecks aus dem aktiven Produktionskatalog; keine neuen Karten oder Sonderregeln.", balance_note_de="Heuristische Referenzdecks. Vollständige AI-Partien und deren Stichprobengröße werden separat dokumentiert; keine abschließende Balancebehauptung.", generator="tools/production/build_test_decks.py", decks=decks, pairwise_replaced_copies=differences)
    output = ROOT / "data/production/test_decks.json"
    text = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    if args.check:
        assert output.read_text() == text, "Reference decks differ from reproducible generator"
    else:
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(text)
    print(f"PRODUCTION DECKS: {len(decks)} legal 30-card compositions; {sum(len(d['cards']) for d in decks)} slots; minimum {min(differences.values())} replaced copies between decks")

if __name__ == "__main__":
    main()
