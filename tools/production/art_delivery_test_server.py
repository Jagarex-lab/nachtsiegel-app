#!/usr/bin/env python3
"""Loopback-only integration fixture serving actual committed full-art bodies."""
from __future__ import annotations
import argparse
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import re
import socket
import subprocess
import threading
import time
from urllib.parse import urlsplit

if __package__:
    from .stage_art_delivery import external_entries
else:
    from stage_art_delivery import external_entries


def ensure_caches(root: Path, output_prefix: Path, engine: str = "godot", timeout: str = "600s") -> None:
    """Prepare both immutable caches; never generate/rewrite their manifests."""
    names = ("art_delivery.json", "art_preview_delivery.json")
    before = {name: (root / "data/production" / name).read_bytes() for name in names}
    output_prefix.parent.mkdir(parents=True, exist_ok=True)
    for kind, summary in (("art", "PRODUCTION ART DELIVERY DATA"), ("preview", "PRODUCTION PREVIEW DELIVERY DATA")):
        log = output_prefix.with_name(output_prefix.name + "-prepare-" + kind + ".log")
        command = ["timeout", timeout, engine, "--headless", "--path", str(root), "--audio-driver", "Dummy", "--script", "tools/production/prepare_" + kind + "_delivery.gd", "--", "--ensure-cache"]
        with log.open("wb") as output:
            result = subprocess.run(command, cwd=root, stdout=output, stderr=subprocess.STDOUT)
        text = log.read_text(encoding="utf-8", errors="replace")
        print(text, end="" if text.endswith("\n") else "\n", flush=True)
        unchanged = all((root / "data/production" / name).read_bytes() == before[name] for name in names)
        if result.returncode or not unchanged or re.search(r"SCRIPT ERROR|^ERROR:|^FAIL:|instances leaked|resources still in use", text, re.M) or not re.search(re.escape(summary) + r": \d+ assertions, 0 failures", text):
            raise RuntimeError(f"Strict {kind} cache preparation failed: exit={result.returncode}, metadata_unchanged={unchanged}; actual output: {log}")


def wait_ready(ready: Path, pid: int, timeout: float = 60.0) -> str:
    """Wait for an atomically published URL, without hiding a dead child."""
    if pid <= 0 or not 0 < timeout <= 600:
        raise ValueError("A real child PID and bounded positive readiness timeout are required")
    deadline = time.monotonic() + timeout
    while True:
        if ready.is_file():
            url = json.loads(ready.read_text(encoding="utf-8"))["url"]
            parsed = urlsplit(url)
            if parsed.scheme != "http" or parsed.hostname != "127.0.0.1" or not parsed.port or parsed.username or parsed.password or parsed.path != "/" or parsed.query or parsed.fragment:
                raise ValueError("Fixture readiness must name its actual loopback HTTP listener")
            return url
        try:
            os.kill(pid, 0)
        except ProcessLookupError as error:
            raise RuntimeError("HTTP fixture exited before readiness; report its actual stderr and wait status") from error
        if time.monotonic() >= deadline:
            raise TimeoutError(f"HTTP fixture did not become ready within {timeout:g}s; report its actual stderr and wait status")
        time.sleep(min(0.05, max(0.0, deadline - time.monotonic())))


def publish_ready(ready: Path, url: str) -> None:
    temporary = ready.with_name(ready.name + f".{os.getpid()}.tmp")
    try:
        with temporary.open("x", encoding="utf-8") as output:
            output.write(json.dumps({"url": url}) + "\n")
        temporary.replace(ready)
    finally:
        temporary.unlink(missing_ok=True)


def load_bodies(root: Path) -> dict[str, bytes]:
    manifest = json.loads((root / "data/production/art_delivery.json").read_text())
    previews = json.loads((root / "data/production/art_preview_delivery.json").read_text())
    bodies = {}
    for entries, folder in ((external_entries(manifest), "art-delivery-cache"), (external_entries(previews, True), "art-preview-delivery-cache")):
        cache = root / "work" / folder
        for card_id, entry in entries.items():
            path = cache / (entry["web_sha256"] + ".webp")
            if cache.is_symlink() or path.is_symlink() or not path.is_file():
                raise ValueError(f"Actual encoded-art cache missing/unsafe: {folder}/{path.name} ({card_id}); prepare both strict caches before this test")
            body = path.read_bytes()
            if len(body) != entry["bytes"] or hashlib.sha256(body).hexdigest() != entry["web_sha256"]:
                raise ValueError(f"Actual encoded-art cache stale: {path} ({card_id}); prepare both strict caches before this test")
            bodies[entry["relative_url"]] = body
    return bodies


def run(root: Path, ready: Path, log: Path) -> None:
    # Never leave successful request rows from an earlier run on startup failure.
    log.write_text("")
    bodies = load_bodies(root)
    lock = threading.Lock()

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_args: object) -> None:
            pass

        def do_GET(self) -> None:
            path = urlsplit(self.path).path.lstrip("/")
            route, _, relative = path.partition("/")
            original = bodies.get(relative)
            code = 200
            body = original
            if route == "disconnect":
                with lock, log.open("a") as output:
                    output.write(json.dumps({"route": route, "code": 0, "actual_manifest_body": False}) + "\n")
                self.connection.shutdown(socket.SHUT_RDWR)
                self.connection.close()
                return
            if original is None or route == "missing":
                code, body = 404, b"deliberately missing actual art"
            elif route == "hash":
                altered = bytearray(original)
                altered[len(altered) // 2] ^= 1
                body = bytes(altered)
            elif route == "redirect":
                code, body = 302, b"redirect deliberately refused"
            elif route == "oversized":
                body = bytes(8 * 1024 * 1024 + 1)
            elif route == "slow":
                time.sleep(0.35)
            elif route not in {"ok", "dimensions"}:
                code, body = 404, b"unknown integration route"
            assert body is not None
            self.send_response(code)
            self.send_header("Content-Type", "image/webp")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            if code == 302:
                self.send_header("Location", "/ok/" + relative)
            self.end_headers()
            try:
                self.wfile.write(body)
            except (BrokenPipeError, ConnectionResetError):
                pass  # Expected when the real HTTPRequest enforces its limit.
            with lock, log.open("a") as output:
                output.write(json.dumps({"route": route, "relative_url": relative, "code": code,
                                         "bytes": len(body), "sha256": hashlib.sha256(body).hexdigest(),
                                         "actual_manifest_body": body == original}) + "\n")

    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    server.daemon_threads = True
    publish_ready(ready, f"http://127.0.0.1:{server.server_port}/")
    server.serve_forever(poll_interval=0.1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--ready-file", type=Path, required=True)
    parser.add_argument("--log-file", type=Path, required=True)
    parser.add_argument("--wait-pid", type=int)
    parser.add_argument("--ready-timeout", type=float, default=60.0)
    args = parser.parse_args()
    if args.wait_pid is not None:
        print(wait_ready(args.ready_file, args.wait_pid, args.ready_timeout))
    else:
        run(args.root, args.ready_file, args.log_file)
