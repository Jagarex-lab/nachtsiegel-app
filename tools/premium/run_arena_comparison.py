#!/usr/bin/env python3
"""Serial native Godot comparison. Never starts a server or changes game data.

Run only with exclusive GPU ownership. Outputs genuine framebuffer PNGs and
source-qualified wall/process timings; Linux llvmpipe is not an iPhone GPU test.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import threading

MODES = ("flat", "spatial", "three_d")


def run() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--godot", default="godot4")
    parser.add_argument("--viewports", nargs="+", default=["844x390", "852x393", "932x430"])
    parser.add_argument("--modes", nargs="+", choices=MODES, default=list(MODES))
    parser.add_argument("--frames", type=int, default=90)
    parser.add_argument("--warmup", type=int, default=30)
    args = parser.parse_args()
    if not os.environ.get("DISPLAY"):
        parser.error("Native framebuffer comparison requires DISPLAY; no headless screenshot substitutes.")
    executable = shutil.which(args.godot)
    if not executable:
        parser.error(f"Godot is unavailable: {args.godot}")
    project, output = args.project.resolve(), args.out.resolve()
    output.mkdir(parents=True, exist_ok=True)
    source_sha = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=project, text=True).strip()
    dirty = subprocess.check_output(["git", "status", "--porcelain", "--untracked-files=no"], cwd=project, text=True)
    source_hashes = {str(p.relative_to(project)): hashlib.sha256(p.read_bytes()).hexdigest() for p in [
        project / "scripts/premium/arena_stage.gd", project / "scripts/premium/arena_comparison.gd",
        project / "scripts/alpha/card_view.gd", project / "scripts/alpha/style.gd", project / "scripts/card_system/card_face.gd", project / "scripts/premium/card_frames.gd", project / "scenes/premium/arena_comparison.tscn", project / "data/production/art_manifest.json", project / "data/production/cards.json"]}
    render_sources_committed = all(
        hashlib.sha256(subprocess.check_output(["git", "show", f"HEAD:{path}"], cwd=project)).hexdigest() == digest
        for path, digest in source_hashes.items()
    )
    if not render_sources_committed:
        raise AssertionError("A rendered component differs from its committed source; commit it before collecting evidence")
    reports = []
    for viewport in args.viewports:
        width, height = (int(part) for part in viewport.lower().split("x"))
        if width < 320 or height < 240:
            parser.error("Use a real target viewport of at least 320×240.")
        for mode in args.modes:
            folder = output / viewport
            folder.mkdir(parents=True, exist_ok=True)
            env = dict(os.environ, LP_NUM_THREADS="1", XDG_DATA_HOME=str(output / "userdata"), XDG_CACHE_HOME=str(output / "cache"))
            command = [executable, "--path", str(project), "--display-driver", "x11", "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy", "--disable-vsync", "--max-fps", "0", "--resolution", viewport, "--position", "0,0", "--scene", "res://scenes/premium/arena_comparison.tscn", "--", f"--arena-mode={mode}", f"--out={folder}", f"--frames={args.frames}", f"--warmup={args.warmup}"]
            process = subprocess.Popen(command, cwd=project, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            stop = threading.Event()
            rss_samples: list[int] = []
            def sample_rss() -> None:
                while not stop.is_set():
                    try:
                        for line in Path(f"/proc/{process.pid}/status").read_text().splitlines():
                            if line.startswith("VmRSS:"):
                                rss_samples.append(int(line.split()[1])); break
                    except (FileNotFoundError, PermissionError):
                        pass
                    stop.wait(.1)
            monitor = threading.Thread(target=sample_rss, daemon=True); monitor.start()
            try:
                stdout, _ = process.communicate(timeout=180)
            except subprocess.TimeoutExpired:
                process.kill(); stdout, _ = process.communicate()
                (folder / f"arena-{mode}.log").write_text(stdout)
                raise RuntimeError(f"Native comparison timed out: {viewport} {mode}")
            finally:
                stop.set(); monitor.join(timeout=1)
            (folder / f"arena-{mode}.log").write_text(stdout)
            if process.returncode or "SCRIPT ERROR" in stdout or "ERROR:" in stdout:
                print(stdout[-12000:], file=sys.stderr)
                raise RuntimeError(f"{viewport} {mode} failed; inspect {folder}/arena-{mode}.log")
            report = json.loads((folder / f"arena-{mode}.json").read_text())
            if report["viewport"] != [width, height]:
                raise AssertionError(f"Requested vs actual viewport differs: {viewport}, {report['viewport']}")
            if report["screenshot_error"] != 0 or not (folder / f"arena-{mode}.png").is_file():
                raise AssertionError("Actual framebuffer screenshot is absent")
            if not report["framebuffer"]["not_blank"]:
                raise AssertionError("Native framebuffer is blank or lacks the visible card composition")
            if mode == "three_d" and not report["card_textures_frozen"]:
                raise AssertionError("3D card faces have not finished rendering actual illustrations")
            if (mode == "three_d") != report["real_3d_camera"]:
                raise AssertionError("3D claim does not match an actual live Camera3D")
            if len(report["visible_card_art"]) != 16 or any(not item["pixels"] or item["pending"] for item in report["visible_card_art"]):
                raise AssertionError("The actual 16 visible illustrations did not bind real pixels")
            report["screenshot_sha256"] = hashlib.sha256((folder / f"arena-{mode}.png").read_bytes()).hexdigest()
            report["minimum_touch_44_pass"] = report["minimum_card_dimension"] >= 44
            report["process_rss_peak_kib_sampled"] = max(rss_samples, default=-1)
            report["process_rss_sampling_interval_ms"] = 100
            reports.append(report)
            print(f"{viewport} {mode}: p50 {report['frame_wall_ms_p50']:.2f} ms, smallest art {report['minimum_card_dimension']:.1f} px", flush=True)
    fingerprints = {report["fixture_projection_sha256"] for report in reports}
    if len(fingerprints) != 1:
        raise AssertionError("The three modes did not render the same frozen card fixture")
    summary = {"schema": 1, "source_commit": source_sha, "tracked_worktree_dirty": bool(dirty.strip()), "all_render_sources_match_commit": render_sources_committed, "source_file_sha256": source_hashes, "physical_device": False, "qualification": "Native Linux framebuffer. Wall timings and RSS are environment observations, not physical iPhone/Android GPU benchmarks. GPU timestamp is unavailable through this harness.", "reports": reports}
    (output / "comparison.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
    return 0

if __name__ == "__main__":
    raise SystemExit(run())
