"""HTTP-fixture/lifecycle tests; command stubs are not Godot or art-codec proof.

Actual original WebP encoding and real Godot HTTPRequest behavior are checked by
the two separate shell suites. These small fixtures exercise cold CI prerequisites,
strict failure reporting and actual subprocess/loopback HTTP lifecycle behavior.
"""
from __future__ import annotations
import hashlib
import contextlib
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from unittest import mock
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from production.art_delivery_test_server import ensure_caches, load_bodies, publish_ready, wait_ready


class ArtHttpFixture(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="orafold-http-unit-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.data = self.root / "data/production"
        self.data.mkdir(parents=True)
        self.full = b"explicit encoded-body fixture; not a generated illustration"
        self.compact = b"explicit compact-body fixture; not a generated illustration"
        self.full_sha = hashlib.sha256(self.full).hexdigest()
        self.compact_sha = hashlib.sha256(self.compact).hexdigest()
        full = {"schema_version":1,"profile":"orafold-web-art-v1","entries":{"full-unit":{"web_sha256":self.full_sha,"relative_url":f"art/full/{self.full_sha}.webp","bytes":len(self.full)}}}
        pilots = [f"pilot-{index}" for index in range(5)]
        def preview(card, external=False):
            entry = {"delivery":"external" if external else "packed","asset_path":f"res://assets/cards/previews/{card}.png","source_sha256":"1"*64,"preview_sha256":"2"*64,"width":512,"height":362}
            if external: entry.update(web_sha256=self.compact_sha,relative_url=f"art/preview/{self.compact_sha}.webp",bytes=len(self.compact))
            return entry
        previews = {"schema_version":1,"profile":"orafold-web-preview-v1","resource_kind":"compact_preview","external_lossless":False,"quality":0.9,"external_codec":"webp","maximum_edge":512,"individual_original_count_added":0,"pinned_card_ids":pilots,"preview_count":6,"external_preview_count":1,"entries":{card:preview(card) for card in pilots}}
        previews["entries"]["preview-unit"] = preview("preview-unit",True)
        (self.data / "art_delivery.json").write_text(json.dumps(full))
        (self.data / "art_preview_delivery.json").write_text(json.dumps(previews))
        self.ready = self.root / "ready.json"
        self.log = self.root / "server.jsonl"

    def cache(self, preview=False):
        folder = "art-preview-delivery-cache" if preview else "art-delivery-cache"
        digest, body = (self.compact_sha,self.compact) if preview else (self.full_sha,self.full)
        cache = self.root / "work" / folder
        cache.mkdir(parents=True,exist_ok=True)
        target = cache / (digest + ".webp")
        target.write_bytes(body)
        return target

    def server_command(self):
        return [sys.executable,str(ROOT / "tools/production/art_delivery_test_server.py"),"--root",str(self.root),"--ready-file",str(self.ready),"--log-file",str(self.log)]

    def test_actual_cold_fixture_exits_nonzero_without_false_readiness(self):
        for has_full in (False,True):
            if has_full:self.cache()
            result = subprocess.run(self.server_command(),capture_output=True,text=True,timeout=5)
            self.assertEqual(result.returncode,1)
            self.assertFalse(self.ready.exists())
            self.assertIn("art-preview-delivery-cache" if has_full else "art-delivery-cache",result.stderr)
            self.assertEqual(self.log.read_text(),"")

    def test_actual_loopback_fixture_serves_both_hash_bound_groups(self):
        self.cache();self.cache(True)
        with (self.root / "stderr.log").open("w+") as output:
            child = subprocess.Popen(self.server_command(),stdout=output,stderr=subprocess.STDOUT)
            try:
                base = wait_ready(self.ready,child.pid,5)
                for folder,digest,body in (("full",self.full_sha,self.full),("preview",self.compact_sha,self.compact)):
                    with urlopen(base+f"ok/art/{folder}/{digest}.webp",timeout=5) as response:
                        self.assertEqual(response.status,200)
                        self.assertEqual(response.read(),body)
                deadline = time.monotonic()+2
                while len(self.log.read_text().splitlines()) < 2 and time.monotonic()<deadline:time.sleep(.01)
                rows = [json.loads(line) for line in self.log.read_text().splitlines()]
                self.assertEqual(len(rows),2)
                self.assertTrue(all(row["actual_manifest_body"] for row in rows))
            finally:
                child.terminate();child.wait(timeout=5)
            output.seek(0)
            self.assertEqual(output.read(),"")

    def test_wrong_bytes_and_symlink_cache_are_rejected(self):
        target = self.cache();self.cache(True)
        target.write_bytes(b"x"*len(self.full))
        with self.assertRaisesRegex(ValueError,"cache stale"):load_bodies(self.root)
        target.unlink()
        outside = self.root / "outside.webp";outside.write_bytes(self.full)
        target.symlink_to(outside)
        with self.assertRaisesRegex(ValueError,"cache missing/unsafe"):load_bodies(self.root)

    def test_atomic_ready_publication_has_no_partial_or_leftover_file(self):
        url = "http://127.0.0.1:12345/"
        self.ready.write_text(json.dumps({"url":"previous-complete-document"}))
        partial, release = threading.Event(), threading.Event()
        original_open = Path.open
        failures = []
        class SlowWriter:
            def __init__(self,stream):self.stream=stream
            def __enter__(self):return self
            def __exit__(self,*_args):self.stream.close()
            def write(self,value):
                middle=len(value)//2
                self.stream.write(value[:middle]);self.stream.flush();partial.set()
                if not release.wait(2):raise TimeoutError("controlled ready-file writer was not released")
                self.stream.write(value[middle:]);return len(value)
        def opening(path,mode='r',*args,**kwargs):
            stream=original_open(path,mode,*args,**kwargs)
            return SlowWriter(stream) if path.name.startswith('ready.json') and mode in ('w','x') else stream
        def writing():
            try:publish_ready(self.ready,url)
            except Exception as error:failures.append(error)
        with mock.patch.object(Path,'open',opening):
            writer=threading.Thread(target=writing);writer.start()
            try:
                self.assertTrue(partial.wait(2),"actual file writer reached a deliberately partial write")
                self.assertEqual(json.loads(self.ready.read_text()),{"url":"previous-complete-document"})
            finally:release.set();writer.join(timeout=5)
        self.assertEqual(failures,[])
        self.assertEqual(json.loads(self.ready.read_text()),{"url":url})
        self.assertEqual(list(self.root.glob("ready.json.*.tmp")),[])
        self.assertEqual(wait_ready(self.ready,os.getpid(),.1),url)

    def test_readiness_allows_real_delayed_startup_without_fixed_attempt_count(self):
        writer = threading.Thread(target=lambda:(time.sleep(.15),publish_ready(self.ready,"http://127.0.0.1:12345/")))
        writer.start()
        try:self.assertEqual(wait_ready(self.ready,os.getpid(),2),"http://127.0.0.1:12345/")
        finally:writer.join()

    def test_dead_child_is_reported_before_the_long_startup_deadline(self):
        child = subprocess.Popen([sys.executable,"-c","raise SystemExit(17)"])
        self.assertEqual(child.wait(timeout=5),17)
        with self.assertRaisesRegex(RuntimeError,"exited before readiness") as error:wait_ready(self.ready,child.pid,2)
        self.assertIsInstance(error.exception.__cause__,ProcessLookupError)

    def test_timeout_invalid_url_and_malformed_ready_are_not_ignored(self):
        with self.assertRaises(TimeoutError):wait_ready(self.ready,os.getpid(),.02)
        for url in ("https://127.0.0.1:123/","http://example.com:123/","http://127.0.0.1:123/unexpected","http://u:p@127.0.0.1:123/"):
            self.ready.write_text(json.dumps({"url":url}))
            with self.subTest(url=url),self.assertRaises(ValueError):wait_ready(self.ready,os.getpid(),.1)
        self.ready.write_text('{"url":')
        with self.assertRaises(json.JSONDecodeError):wait_ready(self.ready,os.getpid(),.1)

    def command_stub(self, behavior="pass"):
        # Explicit orchestration command stub. No native/art test is counted here.
        stub = self.root / "command-fixture.py"
        stub.write_text("#!/usr/bin/env python3\nimport json,sys\nfrom pathlib import Path\n"
            "Path('called.jsonl').open('a').write(json.dumps(sys.argv[1:])+'\\n')\n"
            "summary='PRODUCTION PREVIEW DELIVERY DATA' if 'tools/production/prepare_preview_delivery.gd' in sys.argv else 'PRODUCTION ART DELIVERY DATA'\n"
            + ("print('explicit orchestration failure');raise SystemExit(23)\n" if behavior=="fail" else
               "Path('data/production/art_delivery.json').write_text('{}')\nprint(summary+': 1 assertions, 0 failures')\n" if behavior=="mutate" else
               "print('ERROR: explicit fault injected after a zero-exit summary')\nprint(summary+': 1 assertions, 0 failures')\n" if behavior=="error" else
               "print(summary+': 1 assertions, 0 failures')\n"))
        stub.chmod(0o755)
        return str(stub)

    def test_preparation_requests_both_strict_modes_and_preserves_metadata(self):
        before = {path:path.read_bytes() for path in self.data.glob('*.json')}
        with contextlib.redirect_stdout(io.StringIO()):ensure_caches(self.root,self.root/'prepare',self.command_stub(),"5s")
        calls = [json.loads(line) for line in (self.root/'called.jsonl').read_text().splitlines()]
        self.assertEqual(len(calls),2)
        for call,kind in zip(calls,("art","preview")):
            self.assertIn(f"tools/production/prepare_{kind}_delivery.gd",call)
            self.assertEqual(call[-2:],["--","--ensure-cache"])
        self.assertEqual(before,{path:path.read_bytes() for path in before})

    def test_preparation_failure_zero_exit_errors_and_metadata_changes_fail(self):
        for behavior,expected in (("fail","exit=23"),("error","exit=0"),("mutate","metadata_unchanged=False")):
            before = {path:path.read_bytes() for path in self.data.glob('*.json')}
            with self.subTest(behavior=behavior),contextlib.redirect_stdout(io.StringIO()),self.assertRaisesRegex(RuntimeError,expected):ensure_caches(self.root,self.root/'prepare',self.command_stub(behavior),"5s")
            for path,data in before.items():path.write_bytes(data)

    def test_both_shell_wrappers_expose_actual_nested_fixture_failure_and_status(self):
        tools = self.root/'tools';(tools/'production').mkdir(parents=True)
        for name in ('art_delivery_test_server.py','stage_art_delivery.py'):
            shutil.copyfile(ROOT/'tools/production'/name,tools/'production'/name)
        for name in ('test_production_art_delivery.sh','test_production_art_preview_delivery.sh'):
            wrapper = tools/name;shutil.copyfile(ROOT/'tools'/name,wrapper)
            environment = os.environ.copy();environment.update(GODOT_BIN=self.command_stub(),ART_HTTP_READY_TIMEOUT='2')
            result = subprocess.run(['bash',str(wrapper)],cwd=self.root,env=environment,capture_output=True,text=True,timeout=10)
            self.assertNotEqual(result.returncode,0)
            self.assertIn('actual server exit=1',result.stderr)
            self.assertIn('Actual encoded-art cache missing/unsafe:',result.stderr)
            self.assertIn('art-delivery-cache',result.stderr)
            self.assertFalse(any(self.root.glob('work/production-art/.http-ready.*')))


if __name__ == '__main__':unittest.main()
