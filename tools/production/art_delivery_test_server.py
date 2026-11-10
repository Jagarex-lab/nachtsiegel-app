#!/usr/bin/env python3
"""Loopback-only integration fixture serving actual committed full-art bodies."""
from __future__ import annotations
import argparse
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import socket
import threading
import time
from urllib.parse import urlsplit


def run(root: Path, ready: Path, log: Path) -> None:
    manifest = json.loads((root / "data/production/art_delivery.json").read_text())
    bodies = {}
    previews = json.loads((root / "data/production/art_preview_delivery.json").read_text())
    for entries, cache in [(manifest["entries"], "art-delivery-cache"), ({key: item for key, item in previews["entries"].items() if item["delivery"] == "external"}, "art-preview-delivery-cache")]:
        for entry in entries.values():
            body = (root / "work" / cache / (entry["web_sha256"] + ".webp")).read_bytes()
            if len(body) != entry["bytes"] or hashlib.sha256(body).hexdigest() != entry["web_sha256"]:
                raise ValueError("Actual encoded-art cache is missing/stale; prepare it before this test")
            bodies[entry["relative_url"]] = body
    lock = threading.Lock()
    log.write_text("")

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
    ready.write_text(json.dumps({"url": f"http://127.0.0.1:{server.server_port}/"}))
    server.serve_forever(poll_interval=0.1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--ready-file", type=Path, required=True)
    parser.add_argument("--log-file", type=Path, required=True)
    args = parser.parse_args()
    run(args.root, args.ready_file, args.log_file)
