#!/usr/bin/env python3
"""Local stdlib-only serialized bridge to the production Godot worker.

No game rules live here. Private Unix sockets (0700 directory/0600 socket)
serve one NDJSON request at a time; the durable journal remains in SQLite.
"""
import argparse
import base64
import hashlib
import json
import os
import pathlib
import socket
import subprocess
import sys
import tempfile
import time

LIMIT = 8 * 1024 * 1024


def read_line(stream):
    line = stream.readline(LIMIT + 1)
    if not line or len(line) > LIMIT or not line.endswith(b"\n"):
        raise ValueError("invalid bridge frame")
    return line


def daemon(args, address):
    directory = pathlib.Path(address).parent
    env = dict(os.environ, XDG_DATA_HOME=str(directory), XDG_CACHE_HOME=str(directory))
    diagnostics = None
    if os.environ.get("ORAFOLD_GODOT_DIAGNOSTICS"):
        log_path = pathlib.Path(os.environ["ORAFOLD_GODOT_DIAGNOSTICS"])
        log_path.parent.mkdir(parents=True, exist_ok=True)
        diagnostics = os.fdopen(os.open(log_path, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600), "ab", buffering=0)
    child = subprocess.Popen(
        [args.godot, "--headless", "--path", args.project, "--script",
         "res://scripts/online/server_worker.gd", "--", "--persistent"],
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=diagnostics or subprocess.DEVNULL,
        env=env,
    )
    server = socket.socket(socket.AF_UNIX)
    try:
        server.bind(address)
    except OSError:
        child.terminate()
        return
    os.chmod(address, 0o600)
    server.listen(8)
    server.settimeout(300)
    try:
        while True:
            try:
                connection, _ = server.accept()
            except socket.timeout:
                break
            with connection:
                connection.settimeout(120)
                try:
                    payload = read_line(connection.makefile("rb"))
                    if json.loads(payload).get("op") == "shutdown":
                        connection.sendall(b'{"ok":true}\n')
                        break
                    encoded = base64.b64encode(payload)
                    child.stdin.write(b"\n".join(encoded[i:i+900] for i in range(0, len(encoded), 900)) + b"\nORAFOLD_END\n")
                    child.stdin.flush()
                    while True:
                        reply = read_line(child.stdout)
                        if reply.startswith(b"ORAFOLD_RESULT "):
                            connection.sendall(reply[15:])
                            break
                        if diagnostics:
                            diagnostics.write(reply)
                except (OSError, ValueError):
                    try:
                        connection.sendall(b'{"ok":false,"error":"RULE_ENGINE_UNAVAILABLE"}\n')
                    except OSError:
                        pass
                    break
    finally:
        try:
            child.stdin.close()
            child.wait(timeout=5)
        except (subprocess.TimeoutExpired, OSError):
            child.terminate()
            try:
                child.wait(timeout=5)
            except subprocess.TimeoutExpired:
                child.kill()
        if diagnostics:
            diagnostics.close()
        server.close()
        pathlib.Path(address).unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--daemon", action="store_true")
    parser.add_argument("--stop", action="store_true")
    args = parser.parse_args()
    project = pathlib.Path(args.project).resolve()
    # A source edit selects a fresh worker, so development never uses stale
    # bytecode. Multiple Node processes for the same project serialize here.
    digest = hashlib.sha256(str(project).encode())
    sources = []
    for folder in ["scripts/card_system", "scripts/legacy", "scripts/production"]:
        sources.extend((project / folder).rglob("*.gd"))
    for source in ["scripts/alpha/model.gd", "scripts/alpha/catalog.gd", "scripts/alpha/session.gd",
                   "scripts/online/server_worker.gd", "scripts/online/authority_model.gd", "scripts/online/authority_session.gd"]:
        sources.append(project / source)
    for folder in ["data/alpha", "data/legacy", "data/card_system"]:
        sources.extend((project / folder).rglob("*.json"))
    sources.append(project / "data/production/cards.json")
    for source in sorted(set(sources)):
        digest.update(source.read_bytes())
    directory = pathlib.Path(tempfile.gettempdir()) / ("orafold-authority-" + str(os.getuid()))
    directory.mkdir(mode=0o700, exist_ok=True)
    address = str(directory / (digest.hexdigest()[:24] + ".sock"))
    if args.daemon:
        daemon(args, address)
        return
    payload = b'{"op":"shutdown"}\n' if args.stop else read_line(sys.stdin.buffer)
    client = socket.socket(socket.AF_UNIX)
    client.settimeout(120)
    try:
        client.connect(address)
    except (FileNotFoundError, ConnectionRefusedError):
        if args.stop:
            return
        pathlib.Path(address).unlink(missing_ok=True)
        subprocess.Popen(
            [sys.executable, __file__, "--project", str(project), "--godot", args.godot, "--daemon"],
            stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
        for _ in range(200):
            try:
                client.connect(address)
                break
            except (FileNotFoundError, ConnectionRefusedError):
                time.sleep(0.05)
        else:
            raise RuntimeError("Godot bridge startup failed")
    with client:
        client.sendall(payload)
        sys.stdout.buffer.write(b"ORAFOLD_RESULT " + read_line(client.makefile("rb")))


if __name__ == "__main__":
    main()
