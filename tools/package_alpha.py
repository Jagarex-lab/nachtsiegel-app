#!/usr/bin/env python3
"""Package the exact local Web build including validated lazy illustrations."""
from __future__ import annotations
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import tempfile
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parent))
from production.stage_art_delivery import checked_delivery_files

ROOT = Path(__file__).resolve().parents[1]
START_TEXT = b'''ORAFOLD Alpha0.3 - prepared, not published
Desktop: extract; run python3 -m http.server 8788 --bind 127.0.0.1
Open http://127.0.0.1:8788/ (not file://).
Phone: HTTPS with a certificate trusted by the device is REQUIRED.
Plain http://<LAN-IP> is not a secure context and Godot refuses it.
Use an existing trusted HTTPS test host, or generate a local test certificate
with mkcert for the computer LAN IP. Install only its public root certificate
on the test phone and enable trust manually. Never share the root private key.
Keep certificate/private key files OUTSIDE this served/export directory.
Run: python3 serve_https.py --bind 0.0.0.0 --cert /path/cert.pem --key /path/key.pem
Open https://<certificate-hostname-or-IP>:9443/ on the same network.
Remove a temporary test CA trust profile after testing.
Full procedure: docs/production/PLAN.md and docs/release/PAGES_RELEASE_SAFETY.md.
No production site, account, shop or online service is changed.
Data is local to the browser origin; changing HTTP/HTTPS host changes storage.
Keep art-delivery.json and the complete art/ directory beside index.html.
'''

def package(root: Path, output: Path, project: Path = ROOT) -> dict:
    if not root.is_dir() or root.is_symlink(): raise ValueError("Real Web export directory required")
    meta = json.loads((root / "build-info.json").read_text())
    commit = meta["commit"]
    if not re.fullmatch(r"[0-9a-f]{40}", commit): raise ValueError("Full commit SHA required")
    prefix = "orafold-" + commit[:12]
    if prefix not in (root / "index.html").read_text(): raise ValueError("Index/build commit mismatch")
    files = [root / "index.html", root / "build-info.json", *sorted(root.glob(prefix + ".*"))]
    if not any(p.suffix == ".wasm" for p in files) or not any(p.suffix == ".pck" for p in files): raise ValueError("Missing actual Web core files")
    art_count = 0
    if (root / "art-delivery.json").exists():
        delivery = json.loads((root / "art-delivery.json").read_text())
        art = checked_delivery_files(root, delivery)
        files.extend([root / "art-delivery.json", *art]); art_count = len(art)
    elif (root / "art").exists(): raise ValueError("Unmanifested art directory")
    for path in files:
        if not path.is_file() or any(p.is_symlink() for p in [path, *path.parents] if p != root.parent): raise ValueError(f"Unsafe export file: {path.name}")
        if not path.resolve().is_relative_to(root.resolve()): raise ValueError("Export traversal")
    entries = {p.relative_to(root).as_posix(): p.read_bytes() for p in files}
    manifest = {"source_commit": commit, "version": meta["version"], "status": "prepared-not-published", "full_art_assets": art_count, "files": {name: hashlib.sha256(body).hexdigest() for name, body in entries.items()}}
    output.mkdir(parents=True, exist_ok=True)
    manifest_data = (json.dumps(manifest, indent=2) + "\n").encode()
    entries["artifact-manifest.json"] = manifest_data
    entries["serve_https.py"] = (project / "tools/serve_alpha_https.py").read_bytes()
    entries["START.txt"] = START_TEXT
    archive = output / ("orafold-alpha-0.3-" + commit[:12] + ".zip")
    descriptor, temporary = tempfile.mkstemp(dir=output, prefix=".orafold-package-", suffix=".zip")
    os.close(descriptor)
    try:
        with zipfile.ZipFile(temporary, "w") as zipped:
            for name in sorted(entries):
                info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0)); info.external_attr = 0o100644 << 16
                zipped.writestr(info, entries[name], compress_type=zipfile.ZIP_DEFLATED, compresslevel=6)
        with zipfile.ZipFile(temporary) as zipped:
            if zipped.testzip() is not None or set(zipped.namelist()) != set(entries): raise ValueError("ZIP integrity/entry mismatch")
            for name, sha in manifest["files"].items():
                if hashlib.sha256(zipped.read(name)).hexdigest() != sha: raise ValueError("ZIP body/hash mismatch")
        os.replace(temporary, archive)
        (output / "artifact-manifest.json").write_bytes(manifest_data)
    finally:
        if Path(temporary).exists(): Path(temporary).unlink()
    return {"archive": str(archive), "bytes": archive.stat().st_size, "sha256": hashlib.sha256(archive.read_bytes()).hexdigest(), "commit": commit, "full_art_assets": art_count}

if __name__ == "__main__":
    print(json.dumps(package(ROOT / "work/alpha/web", ROOT / "work/alpha"), indent=2))
