#!/usr/bin/env python3
"""Validate actual paired resource evidence and reproducibly render its report.

Corruption checks mutate copies of completed evidence; they never invent games.
"""
from __future__ import annotations

import argparse
import collections
import copy
import hashlib
import json
import re
import statistics
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASELINE = "tests/fixtures/production/resource_baseline.json"
CONDITIONS = [
    {"id": "energy8_res15", "energy": 8, "resonance": 15},
    {"id": "energy10_res15", "energy": 10, "resonance": 15},
    {"id": "energy10_res20", "energy": 10, "resonance": 20},
]
STARTERS = {"starter-houses", "starter-stillwatch", "starter-morph", "starter-ninth"}
SOURCES = {
    "scripts/legacy/battle_engine.gd", "scripts/alpha/model.gd",
    "scripts/card_system/trigger_model.gd", "scripts/card_system/production_model.gd",
    "scripts/card_system/production_effects.gd", "scripts/card_system/runtime.gd",
    "scripts/production/ai_policy.gd", "scripts/production/catalog.gd",
    "data/production/cards.json", "data/production/starters.json",
    "tests/production_resource_models.gd", BASELINE,
}
METRICS = ("energy_at_actions", "known_card_energy_paid", "unspent_energy",
           "net_resonance_gain", "net_resonance_spent", "resonance_peak")
DIGEST_FIELDS = ("winner", "round", "convergence", "event_sha256", "final_state_sha256")


def require(ok, message):
    if not ok:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def case(game):
    return game["hero"], game["enemy"], game["seed"]


def validate(report, baseline, catalog, current_hashes):
    require(report["suite"] == "production_resource_models", "Wrong suite")
    require(report["conditions"] == CONDITIONS, "Changed resource profiles")
    require(report["failures"] == 0 and report["assertions"] > 0, "Failed engine checks")
    require(report["matrix_games"] == len(report["games"]) == 192, "Incomplete or extra matrix games")
    require(report["additional_verification_games"] == 10, "Missing replay/constructor controls")
    require(report["pre_seam_default_comparisons"] == 64, "Missing pre-seam comparisons")
    require(set(report["source_sha256"]) == SOURCES, "Missing or unexpected source bindings")
    require(report["source_sha256"] == current_hashes, "Executed sources differ from checkout")
    require(baseline["format"] == "ORAFOLD-PRE-SEAM-STARTER-EVIDENCE", "Wrong baseline")
    require(report["baseline_report_sha256"] == baseline["source_report_sha256"], "Mixed baseline report")
    require(len(baseline["games"]) == 64, "Incomplete baseline")
    expected = {case(g): g for g in baseline["games"]}
    require(len(expected) == 64, "Duplicate baseline case")
    require({key[:2] for key in expected} == {(a, b) for a in STARTERS for b in STARTERS}, "Wrong starter pairings")
    records = {}
    for condition in CONDITIONS:
        rows = [g for g in report["games"] if g["condition"] == condition["id"]]
        found = {case(g): g for g in rows}
        require(len(rows) == len(found) == 64 and set(found) == set(expected), "Missing, duplicate or extra planned case")
        for pair in {(a, b) for a in STARTERS for b in STARTERS}:
            starts = collections.Counter(g["first"] for g in rows if case(g)[:2] == pair)
            require(starts == {"hero": 2, "enemy": 2}, "Unbalanced first seats")
        for key, game in found.items():
            require(game["first"] == expected[key]["first"], "Changed first-side record")
            require(not game["censored"] and not game["error"], "Censored/error game")
            require(game["winner"] in ("hero", "enemy", "draw"), "Invalid winner")
            require(type(game["round"]) is int and game["round"] > 0, "Invalid round")
            require(type(game["convergence"]) is bool, "Invalid convergence flag")
            for field in ("event_sha256", "final_state_sha256"):
                require(re.fullmatch(r"[0-9a-f]{64}", game[field]) is not None, "Invalid full digest")
            for metric in METRICS:
                require(type(game[metric]) is int and game[metric] >= 0, "Invalid resource metric")
            require(game["resonance_peak"] <= condition["resonance"], "Resonance cap exceeded")
            require(set(game["cards_played"]) <= set(catalog), "Unknown played card")
            require(all(type(n) is int and n > 0 for n in game["cards_played"].values()), "Invalid card-use count")
            require(sum(catalog[id]["cost"] * n for id, n in game["cards_played"].items()) == game["known_card_energy_paid"], "Printed energy payments inconsistent")
            if condition == CONDITIONS[0]:
                require(all(game[f] == expected[key][f] for f in DIGEST_FIELDS), "Default differs from pre-seam full state/events")
        records[condition["id"]] = found
    return records


def rejection_checks(report, baseline, catalog, hashes):
    """Integrity checks only; corrupt copies never contribute played-game counts."""
    mutations = {
        "missing game": lambda r: r["games"].pop(),
        "extra game": lambda r: r["games"].append(copy.deepcopy(r["games"][0])),
        "duplicate case": lambda r: r["games"].__setitem__(1, copy.deepcopy(r["games"][0])),
        "censored game": lambda r: r["games"][0].__setitem__("censored", True),
        "engine error": lambda r: r["games"][0].__setitem__("error", "injected corruption"),
        "invalid winner": lambda r: r["games"][0].__setitem__("winner", None),
        "wrong first side": lambda r: r["games"][0].__setitem__("first", "hero" if r["games"][0]["first"] == "enemy" else "enemy"),
        "missing replay": lambda r: r.__setitem__("additional_verification_games", 9),
        "missing golden": lambda r: r.__setitem__("pre_seam_default_comparisons", 63),
        "wrong source": lambda r: r["source_sha256"].__setitem__("scripts/alpha/model.gd", "0" * 64),
        "missing source": lambda r: r["source_sha256"].pop(BASELINE),
        "mixed baseline": lambda r: r.__setitem__("baseline_report_sha256", "0" * 64),
        "altered default trace": lambda r: r["games"][0].__setitem__("event_sha256", "0" * 64),
        "altered default state": lambda r: r["games"][0].__setitem__("final_state_sha256", "0" * 64),
        "unknown condition": lambda r: r["games"][0].__setitem__("condition", "unplanned"),
        "changed cap": lambda r: r["conditions"][1].__setitem__("energy", 11),
        "unknown card": lambda r: r["games"][0]["cards_played"].__setitem__("invented-card", 1),
        "altered payment": lambda r: r["games"][0].__setitem__("known_card_energy_paid", -1),
        "failed checks": lambda r: r.__setitem__("failures", 1),
    }
    for name, mutate in mutations.items():
        damaged = copy.deepcopy(report)
        mutate(damaged)
        try:
            validate(damaged, baseline, catalog, hashes)
        except (ValueError, KeyError, TypeError):
            continue
        raise ValueError("Corrupt actual evidence accepted: " + name)
    return sorted(mutations)


def render(report, records, digest, guard_names, baseline):
    default = records[CONDITIONS[0]["id"]]
    summaries = {}
    pairs = {}
    for condition in CONDITIONS:
        id = condition["id"]
        rows = list(records[id].values())
        summary = {metric: sum(g[metric] for g in rows) for metric in METRICS if metric != "resonance_peak"}
        summary.update(games=64, mean_round=statistics.mean(g["round"] for g in rows), first_wins=sum(g["winner"] == g["first"] for g in rows), draws=sum(g["winner"] == "draw" for g in rows), convergence_wins=sum(g["convergence"] for g in rows), resonance_peak=max(g["resonance_peak"] for g in rows), games_over_resonance15=sum(g["resonance_peak"] > 15 for g in rows), winner_changes=sum(g["winner"] != default[case(g)]["winner"] for g in rows), event_changes=sum(g["event_sha256"] != default[case(g)]["event_sha256"] for g in rows), state_changes=sum(g["final_state_sha256"] != default[case(g)]["final_state_sha256"] for g in rows), paired_mean_round_delta=statistics.mean(g["round"] - default[case(g)]["round"] for g in rows))
        summaries[id] = summary
        for a in sorted(STARTERS):
            for b in sorted(STARTERS):
                games = [g for g in rows if (g["hero"], g["enemy"]) == (a, b)]
                pairs.setdefault(a + "/" + b, {})[id] = {"hero_wins": sum(g["winner"] == "hero" for g in games), "draws": sum(g["winner"] == "draw" for g in games), "enemy_wins": sum(g["winner"] == "enemy" for g in games), "mean_round": statistics.mean(g["round"] for g in games)}
    compact = {"schema_version": 1, "raw_evidence_sha256": digest, "source_sha256": report["source_sha256"], "baseline_report_sha256": report["baseline_report_sha256"], "assertions": report["assertions"], "failures": 0, "matrix_games": 192, "additional_verification_games": 10, "pre_seam_default_comparisons": 64, "negative_evidence_guards": guard_names, "conditions": summaries, "directed_pairs": pairs}
    compact["baseline_source_commit"] = baseline["source_commit"]
    compact["baseline_fixture_sha256"] = report["source_sha256"][BASELINE]
    history_dir = ROOT / "docs/production/resource-history/pre-semantics-b328500"
    history = json.loads((history_dir / "manifest.json").read_text())
    for name, historical_digest in history["files"].items():
        require(sha((history_dir / name).read_bytes()) == historical_digest, "Historical evidence changed: " + name)
    compact["historical_pre_semantics"] = {
        "source_commit": history["source_commit"],
        "raw_evidence_sha256": history["files"]["RESOURCE_MODEL_GAMES.json"],
        "excluded_from_current_totals": True,
    }
    same_resonance_traces = all(
        records["energy10_res15"][key][field] == records["energy10_res20"][key][field]
        for key in default for field in DIGEST_FIELDS
    )
    res15_peak = summaries["energy10_res15"]["resonance_peak"]
    res20_peak = summaries["energy10_res20"]["resonance_peak"]
    compact["resonance_pair_comparison"] = {
        "profiles": ["energy10_res15", "energy10_res20"],
        "paired_games": 64,
        "identical_state_event_pairs": sum(
            all(records["energy10_res15"][key][field] == records["energy10_res20"][key][field]
                for field in ("event_sha256", "final_state_sha256"))
            for key in default
        ),
        "all_results_and_digests_identical": same_resonance_traces,
    }
    resonance_changes = []
    for key in sorted(default):
        low = records["energy10_res15"][key]
        high = records["energy10_res20"][key]
        if any(low[field] != high[field] for field in DIGEST_FIELDS):
            resonance_changes.append({
                "hero": key[0], "enemy": key[1], "seed": key[2], "first": low["first"],
                "winner_10_15": low["winner"], "winner_10_20": high["winner"],
                "round_10_15": low["round"], "round_10_20": high["round"],
                "observed_resonance_peak_10_15": low["resonance_peak"],
                "observed_resonance_peak_10_20": high["resonance_peak"],
            })
    compact["resonance_pair_comparison"]["changed_cases"] = resonance_changes
    if same_resonance_traces and res20_peak <= 15:
        resonance_finding = "Der Vergleich von 10/15 mit 10/20 erreicht keine beobachtete Resonanz über 15 und liefert identische Zustands- und Ereignisdigests; er kann einen Vorteil des höheren Resonanzlimits daher nicht beurteilen."
    else:
        resonance_finding = f"Der beobachtete Resonanzpeak beträgt {res15_peak} bei 10/15 und {res20_peak} bei 10/20. Die vollständigen Verläufe beider Profile sind {'identisch' if same_resonance_traces else 'verschieden'}; daraus folgt ohne weitere Deck- und Menschentests keine Freigabe eines Ressourcenwechsels."
    resonance_limit = f"Bei 10/15 beträgt der beobachtete Peak {res15_peak}, bei 10/20 beträgt er {res20_peak}. "
    if res20_peak <= 15:
        resonance_limit += "Diese Profile sind deshalb kein Belastungsnachweis für einen ausgeschöpften 20er-Speicher. "
    energy_default = summaries["energy8_res15"]
    energy10 = summaries["energy10_res15"]
    energy_finding = f"Im gepaarten Vergleich 8/15 → 10/15 ändern sich die beobachtete ungenutzte Energie von {energy_default['unspent_energy']} auf {energy10['unspent_energy']} und die gedruckten Kartenzahlungen von {energy_default['known_card_energy_paid']} auf {energy10['known_card_energy_paid']}. "
    lines = ["# Ressourcenvergleich auf der Produktionsengine", "", "Empfehlung: **8 Energie / 15 Resonanz beibehalten.** " + energy_finding + resonance_finding, "", "## Tatsächlicher Nachweis", "", f"{report['assertions']} Engineprüfungen, 0 Fehler; 192 vollständige Matrixpartien und 10 zusätzliche Kontrollpartien. Vier reale 30-Karten-Starter über dem tatsächlichen 550-Karten-Katalog, alle 16 gerichteten Paarungen, je zwei Seeds mit jeder Startseite pro Profil. Dieselben 64 Paar-/Seed-Fälle laufen unverändert in allen drei Profilen. Keine zensierten oder fehlerhaften Partien werden als Ergebnis gezählt.", "", "Die 64 Standardpartien bestätigen Sieger, Halbzugzahl, Konvergenz sowie vollständige Zustands- und Ereignisdigests des vor dem Getter-Eingriff ausgeführten 848-Partien-Laufs. Sechs zusätzliche Wiederholungen und vier Kontrollen des gewöhnlichen Produktionskonstruktors prüfen Determinismus und die Gleichheit der Test-Subclass bei 8/15. Historische Partien und manipulierte Nachweiskopien werden nicht zu den 202 neuen Partien addiert.", "", "## Gepaarte Ergebnisse", "", "| Energie/Resonanz | Partien | Ø Halbzüge | Startspieler-Siege | Konvergenz | Andere Sieger als 8/15 | Andere Ereignisdigests | Ø Halbzugdifferenz zu 8/15 |", "|---|---:|---:|---:|---:|---:|---:|---:|"]
    baseline_section = [
        "## Korrigierter Kernel und explizite Baseline", "",
        "Diese Messung verwendet den Kernel nach den Korrekturen der gedruckten optionalen/sequenziellen Effekte, Wesenreaktionen und nativen KillWatcher-Pfade. Die Cap-Getter wurden darauf aufgesetzt; die Semantikfixes bleiben erhalten.", "",
        f"Die aktive 64er-Baseline ist eine byteidentische Kopie von `PRE_GETTER_STARTER_BASELINE.json`, Ankercommit `{baseline['source_commit']}`, vollständiger Pre-Getter-848-Rohbericht `{baseline['source_report_sha256']}`. Ihre 18 ausgeführten Quellenhashes werden gegen diesen Commit geprüft. Die neue Standardbedingung muss die tatsächlichen neuen Zustands-/Ereignisdigests bestätigen; die früheren Digests werden nicht auf neue Ergebnisse umgeschrieben.", "",
        "Die bisherigen Pre-Semantik-Nachweise bleiben unter `resource-history/pre-semantics-b328500/` mit Hashmanifest byteidentisch erhalten. Sie sind historische Ergebnisse und werden nicht zu den aktuellen 192+10 Partien addiert.", "",
    ]
    at = lines.index("## Gepaarte Ergebnisse")
    lines[at:at] = baseline_section
    for c in CONDITIONS:
        s = summaries[c["id"]]
        lines.append(f"| {c['energy']}/{c['resonance']} | 64 | {s['mean_round']:.4f} | {s['first_wins']}/64 | {s['convergence_wins']} | {s['winner_changes']} | {s['event_changes']} | {s['paired_mean_round_delta']:+.4f} |")
    lines += ["", "## Ressourcenmessung", "", "Summen über beide Sitzpositionen und 64 Partien je Profil. Energie zu Aktionsbeginn, bekannte gedruckte Kosten erfolgreich gespielter Karten und ungenutzte Energie sind getrennte Beobachtungen, keine geschlossene Bruttobilanz: Reliktkosten, automatische Effekte und Energiegewinne sind darin nicht vollständig aufgeschlüsselt. Resonanzwerte sind Nettodifferenzen pro KI-Aktion; gleichzeitig erzeugte und ausgegebene Resonanz kann sich aufheben. Die Peaks erfassen beobachtete Aktionsgrenzen, keine lückenlose interne Verlaufsmessung.", "", "| Energie/Resonanz | Energie zu Aktionsbeginn | Gedruckte Kartenzahlungen | Ungenutzte Energie | Netto-Resonanzgewinn | Netto-Verbrauch | Beobachteter Peak | Partien mit Peak >15 |", "|---|---:|---:|---:|---:|---:|---:|---:|"]
    for c in CONDITIONS:
        s = summaries[c["id"]]
        lines.append(f"| {c['energy']}/{c['resonance']} | " + " | ".join(str(s[k]) for k in (*METRICS, "games_over_resonance15")) + " |")
    lines += ["", "## Gerichtete Paarungen", "", "Je Feld: Siege Hero / Unentschieden / Siege Enemy; anschließend mittlere Halbzüge. Jede Zelle umfasst dieselben vier Seeds, davon zwei erste Züge pro Sitzposition. Spiegelpartien zählen hier weiterhin vier Partien und keine acht unabhängigen Fälle.", "", "| Hero / Enemy | 8/15 | 10/15 | 10/20 |", "|---|---|---|---|"]
    for pair, conditions in pairs.items():
        cells = [f"{s['hero_wins']}/{s['draws']}/{s['enemy_wins']}; {s['mean_round']:.2f}" for s in conditions.values()]
        lines.append("| " + pair.replace("starter-", "") + " | " + " | ".join(cells) + " |")
    lines += ["", "## Grenzen und Umsetzung", "", "Nur eine deterministische KI-Policy und vier unveränderte Starter: weder menschliche Balance noch sämtliche Interaktionen oder mögliche Decks der 550 Karten sind damit bewiesen. Gleiche Seeds erlauben einen kontrollierten Vergleich; sie sind keine 64 unabhängigen menschlichen Messungen. " + resonance_limit + "Für einen Ressourcenwechsel wären weitere legale resonanzintensive Decks und menschliche Partien nötig.", "", "Produktionsdefault, Session und UI bleiben bei 8/15. Nur die Test-Subclass überschreibt Getter. Energie-Refresh und generischer Energiegewinn verwenden denselben 8er-Default-Getter; gewöhnlicher Resonanzgewinn und natives Harvest verwenden denselben 15er-Default-Getter. Die Policy liest den Resonanzdeckel für Gewinnbewertungen und Reliktverfügbarkeit. Schwellen und Kosten der übrigen Aktionen ändern sich nicht. Grenztests prüfen beide Seiten und alle drei Profile einschließlich unverändertem 15er-Burst-Zugang.", "", f"Die Engine prüft den Quellenhash am Anfang und Ende. Der Berichtsgenerator verlangt danach denselben vollständigen Quellensatz wie im tatsächlichen Lauf und prüft die alte Baseline gegen deren Commit. {len(guard_names)} negative Evidenzwächter weisen beschädigte Kopien echter Ergebnisse zurück: fehlende, zusätzliche oder doppelte Fälle, Quellen-/Baselinewechsel, falsche Startseite, ungültige Ergebnisse, fehlende Kontrollen und manipulierte Standarddigests. Das sind Integritätsprüfungen, keine weiteren gespielten Partien.", "", "## Reproduktion", "", "```sh", "bash tools/test_production_resources.sh", "python3 tools/production/report_resources.py --verify-rejections", "python3 tools/production/report_resources.py --verify-rejections --check", "```", "", "Rohdaten: `docs/production/RESOURCE_MODEL_GAMES.json`; kompakter Bericht: `RESOURCE_MODEL_EXPERIMENT.json`. Der Generator kann die eingecheckten Rohdaten mit `--source docs/production/RESOURCE_MODEL_GAMES.json` prüfen. Alle Seeds und Zustands-/Ereignisdigests bleiben im Rohbericht erhalten.", "", f"Rohdaten-SHA-256: `{digest}`. Baseline des früheren 848-Partien-Laufs: `{report['baseline_report_sha256']}`.", ""]
    detail = ["## Einzelne Abweichungen bei höherem Resonanzlimit", ""]
    if not resonance_changes:
        detail.append("Zwischen 10/15 und 10/20 weichen in diesen 64 gepaarten Fällen weder Ergebnisse noch vollständige Zustands-/Ereignisdigests ab.")
    else:
        for item in resonance_changes:
            detail.append(f"- {item['hero']} / {item['enemy']}, Seed {item['seed']}, erste Sitzposition {item['first']}: Sieger {item['winner_10_15']} → {item['winner_10_20']}, Halbzüge {item['round_10_15']} → {item['round_10_20']}, beobachteter Resonanzpeak {item['observed_resonance_peak_10_15']} → {item['observed_resonance_peak_10_20']} (10/15 → 10/20).")
    detail += ["", "Diese wenigen verbundenen Fälle belegen konkrete Verlaufsunterschiede, aber keinen allgemeinen Vorteil oder eine menschliche Balancewirkung des höheren Limits.", ""]
    at = lines.index("## Grenzen und Umsetzung")
    lines[at:at] = detail
    return compact, "\n".join(lines)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=ROOT / "work/production/resource-models.json")
    parser.add_argument("--output-dir", type=Path, default=ROOT / "docs/production")
    parser.add_argument("--verify-rejections", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    raw = args.source.read_bytes()
    report = json.loads(raw)
    baseline = json.loads((ROOT / BASELINE).read_text())
    require((ROOT / BASELINE).read_bytes() == (ROOT / "docs/production/PRE_GETTER_STARTER_BASELINE.json").read_bytes(), "Active baseline differs from the explicit corrected pre-getter export")
    catalog = {c["id"]: c for c in json.loads((ROOT / "data/production/cards.json").read_text())["cards"]}
    hashes = {path: sha((ROOT / path).read_bytes()) for path in SOURCES}
    records = validate(report, baseline, catalog, hashes)
    anchor = json.loads(subprocess.check_output(["git", "show", baseline["source_commit"] + ":docs/production/simulation-results.json"], cwd=ROOT))
    require(anchor["matrix_games"] == 848 and anchor["failures"] == 0 and anchor["raw_evidence_sha256"] == baseline["source_report_sha256"], "Baseline is not bound to the completed 848-game report")
    for path, digest in baseline["source_sha256"].items():
        require(sha(subprocess.check_output(["git", "show", baseline["source_commit"] + ":" + path], cwd=ROOT)) == digest, "Pre-seam source commit mismatch: " + path)
    guards = rejection_checks(report, baseline, catalog, hashes) if args.verify_rejections else []
    summary, text = render(report, records, sha(raw), guards, baseline)
    outputs = {"RESOURCE_MODEL_GAMES.json": raw, "RESOURCE_MODEL_EXPERIMENT.json": (json.dumps(summary, ensure_ascii=False, indent=2) + "\n").encode(), "RESOURCE_MODEL_EXPERIMENT.md": text.encode()}
    if not args.check:
        args.output_dir.mkdir(parents=True, exist_ok=True)
    for name, data in outputs.items():
        target = args.output_dir / name
        if args.check:
            require(target.read_bytes() == data, "Report is not reproducible: " + name)
        else:
            # Replace a file atomically: historical checkout fixtures may be hardlinks.
            temp = target.with_suffix(target.suffix + ".tmp")
            temp.write_bytes(data)
            temp.replace(target)
    print(f"RESOURCE REPORT: 192+10 actual games; 64 exact pre-seam comparisons; {len(guards)} rejected corrupt copies; SHA256 {sha(raw)}")


if __name__ == "__main__":
    main()
