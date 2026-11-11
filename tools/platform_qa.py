#!/usr/bin/env python3
"""Real debug-platform builds, source-bound package inspection and native runs.

No publishing or store signing. Small parser fixtures in the unit suite are not
native runtime evidence; production runs always execute the installed tools.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import time
import uuid
import zipfile

ROOT = Path(__file__).resolve().parents[1]
MAGIC = b"GDPC"
FAILURES = re.compile(r"SCRIPT ERROR|^ERROR:|^FAIL:|instances leaked|resources still in use", re.M)
ANSI = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")
REQUIRED = ("data/production/cards.json", "data/production/starters.json", "data/production/art_manifest.json", "assets/fonts/LICENSE", "assets/fonts/Cinzel-OFL.txt", "LICENSE-NOTICE.md")
FORBIDDEN = ("tests/", "tools/", "work/", "docs/", "node_modules/", ".git/", "addons/orafold_art_delivery/")


def diagnostic_excerpt(text: str, max_lines: int = 40, max_chars: int = 6000) -> str:
    """Bounded original log context, never environment or process credentials."""
    lines = ANSI.sub("", text).splitlines()
    matches = [index for index, line in enumerate(lines) if FAILURES.search(line)]
    selected = set()
    for index in matches[:4]:
        selected.update(range(max(0, index - 1), min(len(lines), index + 6)))
    if not selected:
        selected.update(range(max(0, len(lines) - 12), len(lines)))
    rows = [f"{index + 1}: {lines[index]}" for index in sorted(selected)]
    if len(matches) > 4:
        rows.append(f"[{len(matches) - 4} additional failure markers; full log retained]")
    excerpt = "\n".join(rows[:max_lines])
    if len(excerpt) > max_chars:
        marker = "\n[excerpt truncated; full log retained]"
        excerpt = excerpt[:max(0, max_chars - len(marker))] + marker[:max_chars]
    return excerpt


def print_log_diagnostic(path: Path, text: str | None = None) -> None:
    try:
        if text is None:
            text = path.read_text(encoding="utf-8", errors="replace")
        excerpt = diagnostic_excerpt(text)
    except OSError as error:
        excerpt = "Unable to read retained log: " + type(error).__name__
    print("NATIVE FAILURE LOG (bounded excerpt): " + str(path), file=sys.stderr)
    print(excerpt or "[log is empty]", file=sys.stderr)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def source_snapshot(root: Path = ROOT) -> dict[str, str]:
    paths = [root / "project.godot", root / "export_presets.cfg", root / "LICENSE-NOTICE.md", root / "tools/platform_qa.py", root / "tools/build_platform_qa.sh"]
    for folder in ("scripts", "scenes", "data", "assets", "addons"):
        paths.extend(p for p in (root / folder).rglob("*") if p.is_file() and p.suffix not in (".uid", ".import", ".pyc") and "__pycache__" not in p.parts)
    return {p.relative_to(root).as_posix(): sha256(p) for p in sorted(paths)}


def read_exact(stream, count: int) -> bytes:
    value = stream.read(count)
    if len(value) != count:
        raise ValueError("Truncated native package")
    return value


def embedded_pck(path: Path) -> dict:
    """Read the actual Godot V2/V3 footer/directory, with bounded offsets.

    Layout checked against Godot4.6.3 core/io/file_access_pack.cpp. No executable
    code is run by this parser. Native smoke execution is a separate requirement.
    """
    length = path.stat().st_size
    with path.open("rb") as stream:
        if length < 120:
            raise ValueError("Native binary too short for embedded PCK")
        stream.seek(length - 12)
        packed_size, magic = struct.unpack("<Q4s", read_exact(stream, 12))
        start = length - 12 - packed_size
        if magic != MAGIC or start < 0 or packed_size < 100:
            raise ValueError("Missing/bad embedded PCK footer")
        stream.seek(start)
        magic, version, major, minor, patch, flags, base = struct.unpack("<4s5IQ", read_exact(stream, 32))
        if magic != MAGIC or version not in (2, 3) or (major, minor, patch) != (4, 6, 3) or flags & ~2:
            raise ValueError("Unsupported/encrypted native PCK header")
        if version == 3 or flags & 2:
            base += start
        if version == 3:
            directory = start + struct.unpack("<Q", read_exact(stream, 8))[0]
            if not start + 100 <= directory < length - 12:
                raise ValueError("PCK directory outside embedded pack")
            stream.seek(directory)
        else:
            stream.seek(64, 1)
        count = struct.unpack("<I", read_exact(stream, 4))[0]
        if not 1 <= count <= 100000:
            raise ValueError("Unreasonable native PCK directory size")
        entries = {}
        for _index in range(count):
            size = struct.unpack("<I", read_exact(stream, 4))[0]
            if not 1 <= size <= 4096:
                raise ValueError("Invalid PCK path length")
            raw = read_exact(stream, size).rstrip(b"\0")
            name = raw.decode("utf-8").removeprefix("res://")
            offset, size = struct.unpack("<QQ", read_exact(stream, 16))
            digest = read_exact(stream, 16).hex()
            entry_flags = struct.unpack("<I", read_exact(stream, 4))[0]
            if not name or "\0" in name or "\\" in name or name.startswith("/") or ".." in name.split("/") or name in entries:
                raise ValueError("Unsafe/duplicate native PCK path")
            absolute = base + offset
            if entry_flags or absolute < start or absolute + size > length - 12:
                raise ValueError("Invalid/encrypted native PCK entry")
            entries[name] = {"offset": absolute, "bytes": size, "md5": digest}
    return {"format_version": version, "engine": "4.6.3", "pack_offset": start, "pack_bytes": packed_size, "entries": entries}


def check_native_architecture(path: Path, platform: str) -> dict:
    with path.open("rb") as stream:
        if platform == "windows":
            header = read_exact(stream, 64)
            if header[:2] != b"MZ":
                raise ValueError("Windows artifact is not a PE executable")
            pe_offset = struct.unpack_from("<I", header, 60)[0]
            if not 64 <= pe_offset <= path.stat().st_size - 26:
                raise ValueError("PE header outside executable")
            stream.seek(pe_offset)
            pe = read_exact(stream, 26)
            if pe[:4] != b"PE\0\0" or struct.unpack_from("<H", pe, 4)[0] != 0x8664 or struct.unpack_from("<H", pe, 24)[0] != 0x20B:
                raise ValueError("Windows artifact is not x86_64 PE32+")
            return {"format": "PE32+", "architecture": "x86_64"}
        header = read_exact(stream, 20)
        if header[:6] != b"\x7fELF\x02\x01" or struct.unpack_from("<H", header, 18)[0] != 0x3E:
            raise ValueError("Linux artifact is not little-endian ELF64 x86_64")
        return {"format": "ELF64", "architecture": "x86_64"}


def inspect_native(path: Path, platform: str, root: Path = ROOT) -> dict:
    architecture = check_native_architecture(path, platform)
    pack = embedded_pck(path)
    entries = pack["entries"]
    for required in REQUIRED:
        if required not in entries:
            raise ValueError("Missing packed runtime/license file: " + required)
    bad = [name for name in entries if name.startswith(FORBIDDEN)]
    if bad:
        raise ValueError("Excluded checkout/build sources packed: " + repr(bad[:8]))
    contents = {}
    with path.open("rb") as stream:
        for name in REQUIRED:
            record = entries[name]
            if record["bytes"] > 16 * 1024 * 1024:
                raise ValueError("Oversize runtime metadata/license entry")
            stream.seek(record["offset"])
            data = read_exact(stream, record["bytes"])
            if hashlib.md5(data).hexdigest() != record["md5"] or hashlib.sha256(data).hexdigest() != sha256(root / name):
                raise ValueError("Packed source differs from checkout: " + name)
            contents[name] = data
    cards = json.loads(contents[REQUIRED[0]])["cards"]
    if len(cards) != 550 or len({card["id"] for card in cards}) != 550:
        raise ValueError("Packed production catalog is not exact550")
    manifest = json.loads(contents["data/production/art_manifest.json"])
    return {**architecture, "pack_format": pack["format_version"], "pack_bytes": pack["pack_bytes"], "file_count": len(entries), "paths": sorted(entries), "source_files_verified": list(REQUIRED), "catalog_cards": 550, "individual_illustrations_in_source_manifest": manifest["individual_original_count"]}


def inspect_apk(path: Path, root: Path = ROOT) -> dict:
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        if len(set(names)) != len(names) or archive.testzip() is not None:
            raise ValueError("Duplicate/corrupt Android package entry")
        for required in REQUIRED:
            name = "assets/" + required
            if name not in names or hashlib.sha256(archive.read(name)).hexdigest() != sha256(root / required):
                raise ValueError("Android runtime/license differs or missing: " + name)
        for abi in ("arm64-v8a", "x86_64"):
            library = f"lib/{abi}/libgodot_android.so"
            if library not in names:
                raise ValueError("Missing actual Godot Android ABI: " + abi)
            with archive.open(library) as stream:
                header = read_exact(stream, 20)
            if header[:6] != b"\x7fELF\x02\x01" or struct.unpack_from("<H", header, 18)[0] != (0xB7 if abi == "arm64-v8a" else 0x3E):
                raise ValueError("Android native library does not match declared ABI: " + abi)
        if any(name.removeprefix("assets/").startswith(FORBIDDEN) for name in names if name.startswith("assets/")):
            raise ValueError("Checkout/build sources in Android assets")
    return {"format": "APK", "abis": ["arm64-v8a", "x86_64"], "source_files_verified": list(REQUIRED), "file_count": len(names), "paths": sorted(names), "device_tested": False}


def clean_log(path: Path) -> str:
    text = ANSI.sub("", path.read_text(encoding="utf-8", errors="replace"))
    if FAILURES.search(text):
        print_log_diagnostic(path, text)
        raise ValueError("Native runtime contains errors/leaks: " + str(path))
    if "Godot Engine v4.6.3" not in text:
        print_log_diagnostic(path, text)
        raise ValueError("Native startup did not identify the actual4.6.3 engine")
    return text


def smoke_summary(path: Path) -> dict:
    rows = []
    for line in clean_log(path).splitlines():
        if line.startswith("{"):
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue
            if row.get("suite") == "production_native_exported":
                rows.append(row)
    if len(rows) != 1:
        print_log_diagnostic(path)
        raise ValueError("Expected one real native smoke summary")
    row = rows[0]
    if not isinstance(row.get("assertions"), int) or row["assertions"] < 12 or row.get("failures") != 0 or row.get("main_menu_verified") is not True or row.get("winner") not in ("hero", "enemy", "draw") or not isinstance(row.get("round"), int) or row["round"] < 1 or not re.fullmatch("[0-9a-f]{64}", row.get("catalog_fingerprint", "")):
        print_log_diagnostic(path)
        raise ValueError("Incomplete/failed actual native duel")
    return row


def configure_android(root: Path, output: Path, environment: dict) -> Path:
    sdk = Path(environment.get("ANDROID_SDK_ROOT") or environment.get("ANDROID_HOME") or root / "work/tools/android-sdk").resolve()
    build_tools = Path(environment.get("ANDROID_BUILD_TOOLS") or sdk / "build-tools/35.0.0").resolve()
    java = Path(environment.get("JAVA_HOME") or Path(shutil.which("javac") or "").resolve().parent.parent).resolve()
    for tool in (build_tools / "apksigner", build_tools / "aapt", sdk / "platforms/android-35/android.jar", java / "bin/java"):
        if not tool.is_file():
            raise ValueError("Missing actual Android/JDK tool: " + str(tool))
    key = output / "native-debug.keystore"
    command = [str(java / "bin/keytool"), "-genkeypair", "-keystore", str(key), "-storetype", "JKS", "-storepass", "android", "-keypass", "android", "-alias", "androiddebugkey", "-keyalg", "RSA", "-keysize", "2048", "-validity", "10000", "-dname", "CN=ORAFOLD Debug QA,OU=Testing,O=ORAFOLD,L=Test,ST=Test,C=DE"]
    with (output / "debug-key-generation.log").open("wb") as log:
        subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=60)
    # Dedicated work/XDG editor settings, not the developer's normal profile.
    settings = Path(environment["XDG_CONFIG_HOME"]) / "godot/editor_settings-4.6.tres"
    settings.parent.mkdir(parents=True, exist_ok=True)
    values = {"android_sdk_path": str(sdk), "java_sdk_path": str(java), "debug_keystore": str(key), "debug_keystore_user": "androiddebugkey", "debug_keystore_pass": "android"}
    settings.write_text('[gd_resource type="EditorSettings" format=3]\n\n[resource]\n' + "".join("export/android/" + name + " = " + json.dumps(value) + "\n" for name, value in values.items()), encoding="utf-8")
    return build_tools


class Runner:
    def __init__(self, platform: str, keep: bool, root: Path = ROOT):
        self.root = root
        self.output = root / "work/production/platforms"
        self.output.mkdir(parents=True, exist_ok=True)
        self.stage = self.output / ("run-" + uuid.uuid4().hex[:12])
        self.stage.mkdir()
        self.isolated = self.stage / "empty-working-directory"
        self.isolated.mkdir()
        self.engine = os.environ.get("GODOT_BIN", "godot")
        self.env = os.environ.copy()
        # Preserve the data/template search path installed by setup-godot.
        # The native_smoke_qa project feature isolates the game's user folder;
        # a fresh XDG_DATA_HOME here would hide the real export templates.
        for kind in ("config", "cache"):
            directory = self.stage / "xdg" / kind
            directory.mkdir(parents=True)
            self.env["XDG_" + kind.upper() + "_HOME"] = str(directory)
        self.env.setdefault("LP_NUM_THREADS", "2")
        self.keep = keep
        self.report = {"schema_version": 2, "status": "running", "platform": platform, "commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip(), "source_sha256": source_snapshot(root), "working_tree_status": subprocess.check_output(["git", "status", "--porcelain"], cwd=root, text=True).splitlines(), "run_directory": str(self.stage.relative_to(root)), "builds": {}, "commands": [], "physical_iphone_tested": False, "android_device_tested": False, "ios_native_build": "not-built: requires Apple Xcode/signing environment", "source_note": "Raw source/asset bytes are hashed; generated.uid/.import files are excluded. No test fixture or repository resource fallback is used by exported executables."}
        self.write()

    def write(self):
        target = self.output / "results.json"
        temporary = target.with_suffix(".json.tmp")
        temporary.write_text(json.dumps(self.report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        temporary.replace(target)
        (self.stage / "results.json").write_text(target.read_text(encoding="utf-8"), encoding="utf-8")

    def run(self, name: str, command: list[str], cwd: Path | None = None, timeout: int = 600) -> Path:
        log = self.stage / (name + ".log")
        started = time.monotonic()
        try:
            with log.open("wb") as stream:
                completed = subprocess.run(command, cwd=cwd or self.root, env=self.env, stdout=stream, stderr=subprocess.STDOUT, timeout=timeout)
        except subprocess.TimeoutExpired:
            self.report["commands"].append({"name": name, "timed_out": True, "seconds": round(time.monotonic() - started, 3), "log": str(log.relative_to(self.root))})
            self.write()
            print_log_diagnostic(log)
            raise
        self.report["commands"].append({"name": name, "exit_code": completed.returncode, "seconds": round(time.monotonic() - started, 3), "log": str(log.relative_to(self.root))})
        self.write()
        if completed.returncode:
            print_log_diagnostic(log)
            raise ValueError(f"Actual command {name} failed with exit{completed.returncode}; see{log}")
        return log

    def record(self, path: Path, inventory: dict):
        relatives = [path]
        if path.suffix in (".exe", ".x86_64"):
            for companion in [path.with_suffix(".console.exe"), path.with_suffix(".sh")]:
                if companion.is_file():
                    relatives.append(companion)
            if path.suffix == ".exe":
                relatives.extend(sorted(self.stage.glob("*.dll")))
        for artifact in relatives:
            digest = sha256(artifact)
            previous = self.report["builds"].get(artifact.name)
            if previous and previous["sha256"] != digest:
                raise ValueError("Export companion collision: " + artifact.name)
            self.report["builds"][artifact.name] = {"bytes": artifact.stat().st_size, "sha256": digest, "path": str(artifact.relative_to(self.root)), "retained": self.keep}
        (self.stage / (path.stem + "-inventory.json")).write_text(json.dumps(inventory, indent=2) + "\n", encoding="utf-8")
        self.write()
        if not self.keep:
            for artifact in relatives:
                artifact.unlink()

    def native_duels(self, executable: Path, name: str) -> Path:
        # Independent starts expose rare teardown leaks. This is not a retry:
        # every run must pass, and the first failure aborts the entire build.
        expected = None
        self.report["native_teardown_runs"] = []
        for index in range(8):
            run_name = name + "-runtime" + (f"-pass-{index + 1:02d}" if index else "")
            evidence = {"pass": index + 1, "status": "running", "commit": self.report["commit"],
                        "source_report_field": "source_sha256", "executable": str(executable.relative_to(self.root)),
                        "log": str((self.stage / (run_name + ".log")).relative_to(self.root))}
            self.report["native_teardown_runs"].append(evidence)
            self.write()
            try:
                log = self.run(run_name, [str(executable), "--headless", "--verbose", "--audio-driver", "Dummy"], self.isolated, timeout=300)
                summary = smoke_summary(log)
                evidence["summary"] = summary
                outcome = (summary["catalog_fingerprint"], summary["winner"], summary["round"])
                if expected is not None and outcome != expected:
                    print_log_diagnostic(log)
                    raise ValueError("Fixed-seed native outcome changed between independent executions")
                expected = outcome
                evidence["status"] = "passed"
                if index == 0:
                    self.report["native_exported_duel"] = summary
                    self.report["main_menu_verified"] = True
                self.write()
            except Exception as error:
                evidence.update(status="failed", error=str(error))
                self.write()
                raise
        return self.stage / (name + "-runtime.log")

    def desktop(self, platform: str):
        if (platform == "windows" and os.name != "nt") or (platform == "linux" and not sys.platform.startswith("linux")):
            raise ValueError("Actual Windows runtime evidence requires a Windows runner; no Linux/Wine substitution")
        title = "Windows" if platform == "windows" else "Linux"
        suffix = ".exe" if platform == "windows" else ".x86_64"
        for runtime in (False, True):
            name = "orafold-runtime-qa" if runtime else "orafold-preview"
            path = self.stage / (name + suffix)
            preset = title + (" Runtime QA" if runtime else " QA")
            self.run(name + "-export", [self.engine, "--headless", "--path", str(self.root), "--export-debug", preset, str(path)], timeout=1200)
            inventory = inspect_native(path, platform, self.root)
            inventory["runtime_executed"] = False
            if runtime:
                executable = path.with_suffix(".console.exe") if platform == "windows" else path
                if not executable.is_file():
                    raise ValueError("Missing actual debug console wrapper")
                log = self.native_duels(executable, name)
                inventory.update(runtime_executed=True, runtime_host=sys.platform, runtime_log=str(log.relative_to(self.root)))
            else:
                # --quit-after forces an engine exit and bypasses the real
                # audio owner's drain. The QA entry instantiates the actual
                # Shell, verifies its four actions, then quits through its owner.
                self.report["regular_game_pack_verified"] = True
                self.report["regular_binary_runtime_executed"] = False
            self.record(path, inventory)

    def android(self):
        tools = configure_android(self.root, self.stage, self.env)
        path = self.stage / "orafold-preview.apk"
        self.run("android-export", [self.engine, "--headless", "--path", str(self.root), "--export-debug", "Android QA", str(path)], timeout=1200)
        inventory = inspect_apk(path, self.root)
        self.run("android-signature", [str(tools / "apksigner"), "verify", "--verbose", str(path)])
        log = self.run("android-badging", [str(tools / "aapt"), "dump", "badging", str(path)])
        text = log.read_text(encoding="utf-8")
        if "package: name='com.jagarex.nachtsiegel'" not in text or "application-label:'ORAFOLD'" not in text:
            raise ValueError("Android package identity/label mismatch")
        self.report["android_debug_signature_verified"] = True
        self.report["android_debug_key_only"] = True
        self.record(path, inventory)

    def finish(self):
        if source_snapshot(self.root) != self.report["source_sha256"] or subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=self.root, text=True).strip() != self.report["commit"]:
            raise ValueError("Actual source/HEAD changed during platform builds")
        self.report["status"] = "passed"
        self.report["source_changed_during_run"] = False
        self.write()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--platform", choices=("linux-android", "linux", "windows"), default="linux-android")
    args = parser.parse_args()
    runner = Runner(args.platform, os.environ.get("PLATFORMS_KEEP_BINARIES", "1") != "0")
    try:
        runner.desktop("windows" if args.platform == "windows" else "linux")
        if args.platform == "linux-android":
            runner.android()
        runner.finish()
    except Exception as error:
        runner.report.update(status="failed", error=str(error))
        runner.write()
        print(str(error), file=sys.stderr)
        return 1
    print(json.dumps({key: value for key, value in runner.report.items() if key != "source_sha256"}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
