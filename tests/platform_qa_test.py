"""Metadata/package guard tests only; synthetic containers are not native games.

Actual executable startup and full-duel evidence is required separately by the
platform CI jobs. These tests make malformed, incomplete and stale reports fail.
"""
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
import zipfile

spec = importlib.util.spec_from_file_location('platform_qa', Path('tools/platform_qa.py'))
p = importlib.util.module_from_spec(spec)
spec.loader.exec_module(p)


def elf(machine=0x3e):
    data = bytearray(64)
    data[:6] = b'\x7fELF\x02\x01'
    struct.pack_into('<H', data, 18, machine)
    return bytes(data)


def pe(machine=0x8664, optional=0x20b):
    data = bytearray(512)
    data[:2] = b'MZ'
    struct.pack_into('<I', data, 60, 64)
    data[64:68] = b'PE\0\0'
    struct.pack_into('<H', data, 68, machine)
    struct.pack_into('<H', data, 88, optional)
    return bytes(data)


def synthetic_pck(files, version=3, engine=(4, 6, 3), flags=2, entry_flags=0, entry_offset=0):
    # A parser fixture, deliberately not executable machine code.
    base = 104 if version == 3 else 96
    payload = b''.join(files.values())
    directory = struct.pack('<I', len(files))
    offset = 0
    for name, data in files.items():
        encoded = name.encode()
        encoded += b'\0' * (-len(encoded) % 4)
        directory += struct.pack('<I', len(encoded)) + encoded + struct.pack('<QQ', offset + entry_offset, len(data)) + hashlib.md5(data).digest() + struct.pack('<I', entry_flags)
        offset += len(data)
    header = struct.pack('<4s5IQ', b'GDPC', version, *engine, flags, base)
    if version == 3:
        header += struct.pack('<Q', base + len(payload))
    header += b'\0' * 64
    assert len(header) == base
    content = header + payload + directory if version == 3 else header + directory + payload
    if version == 2:
        # V2 stores its directory in the header; its file base follows it.
        file_base = len(header) + len(directory)
        header = struct.pack('<4s5IQ', b'GDPC', version, *engine, flags, file_base) + b'\0' * 64
        content = header + directory + payload
    return content + struct.pack('<Q4s', len(content), b'GDPC')


class PlatformEvidence(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.files = {name: (name + '\n').encode() for name in p.REQUIRED}
        self.files[p.REQUIRED[0]] = json.dumps({'cards': [{'id': 'parser-fixture-%03d' % i} for i in range(550)]}).encode()
        self.files['data/production/art_manifest.json'] = b'{"individual_original_count":0}'
        for name, data in self.files.items():
            target = self.root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)

    def native(self, files=None, prefix=None, **kwargs):
        target = self.root / 'synthetic-container.bin'
        target.write_bytes((prefix or elf()) + synthetic_pck(files or self.files, **kwargs))
        return target

    def log(self, text):
        target = self.root / 'runtime.log'
        target.write_text(text)
        return target

    def test_v3_metadata_is_bound_to_exact_packed_source_bytes(self):
        info = p.inspect_native(self.native(), 'linux', self.root)
        self.assertEqual(info['catalog_cards'], 550)
        self.assertEqual(info['pack_format'], 3)
        self.assertEqual(info['source_files_verified'], list(p.REQUIRED))
        self.assertNotIn('runtime_executed', info)

    def test_v2_reader_retains_relative_filebase_support(self):
        info = p.inspect_native(self.native(version=2), 'linux', self.root)
        self.assertEqual(info['pack_format'], 2)

    def test_pe_structure_is_not_misreported_as_windows_execution(self):
        info = p.inspect_native(self.native(prefix=pe()), 'windows', self.root)
        self.assertEqual(info['format'], 'PE32+')
        self.assertNotIn('runtime_executed', info)
        for prefix in [pe(machine=0x14c), pe(optional=0x10b), elf()]:
            with self.subTest(prefix=prefix[:4]), self.assertRaises(ValueError):
                p.inspect_native(self.native(prefix=prefix), 'windows', self.root)

    def test_wrong_magic_truncation_version_encryption_and_offsets_fail(self):
        for kwargs in [{'version': 4}, {'engine': (4, 7, 0)}, {'flags': 1}, {'entry_flags': 1}, {'entry_offset': 10**9}]:
            with self.subTest(kwargs=kwargs), self.assertRaises(ValueError):
                p.embedded_pck(self.native(**kwargs))
        for bad in [b'not a game', self.native().read_bytes()[:-1]]:
            target = self.root / 'bad.bin';target.write_bytes(bad)
            with self.assertRaises(ValueError):p.embedded_pck(target)

    def test_path_traversal_and_checkout_sources_fail(self):
        for name in ['../escape', 'tools/hidden.gd', 'work/result.json', 'docs/private.md', 'addons/orafold_art_delivery/plugin.gd']:
            files = dict(self.files);files[name] = b'x'
            with self.subTest(name=name), self.assertRaises(ValueError):p.inspect_native(self.native(files), 'linux', self.root)

    def test_missing_license_wrong_source_and_incomplete_catalog_fail(self):
        missing = dict(self.files);missing.pop('assets/fonts/LICENSE')
        changed = dict(self.files);changed['assets/fonts/LICENSE'] = b'wrong license'
        short = dict(self.files);short[p.REQUIRED[0]] = b'{"cards":[]}'
        for files in [missing, changed, short]:
            with self.subTest(files=list(files)), self.assertRaises(ValueError):p.inspect_native(self.native(files), 'linux', self.root)

    def apk(self, arm_machine=0xb7):
        target = self.root / 'synthetic-unsigned-container.apk'
        with zipfile.ZipFile(target, 'w') as archive:
            for name, data in self.files.items():archive.writestr('assets/' + name, data)
            archive.writestr('lib/arm64-v8a/libgodot_android.so', elf(arm_machine))
            archive.writestr('lib/x86_64/libgodot_android.so', elf())
        return target

    def test_android_container_guard_does_not_claim_signature_or_device(self):
        info = p.inspect_apk(self.apk(), self.root)
        self.assertFalse(info['device_tested'])
        self.assertNotIn('signature_verified', info)
        self.assertEqual(info['abis'], ['arm64-v8a', 'x86_64'])
        with self.assertRaises(ValueError):p.inspect_apk(self.apk(arm_machine=0x3e), self.root)

    def test_actual_runtime_summary_cannot_be_replaced_by_exit_zero(self):
        valid = {'suite':'production_native_exported','assertions':12,'failures':0,'main_menu_verified':True,'winner':'hero','round':25,'catalog_fingerprint':'a'*64}
        self.assertEqual(p.smoke_summary(self.log('Godot Engine v4.6.3\n' + json.dumps(valid)))['round'], 25)
        for patch in [{'assertions':0}, {'failures':1}, {'main_menu_verified':False}, {'main_menu_verified':None}, {'winner':None}, {'round':0}, {'catalog_fingerprint':'bad'}]:
            row = valid | patch
            with self.subTest(patch=patch), self.assertRaises(ValueError):p.smoke_summary(self.log('Godot Engine v4.6.3\n' + json.dumps(row)))
        with self.assertRaises(ValueError):p.smoke_summary(self.log('Godot Engine v4.6.3\n'))
        with self.assertRaises(ValueError):p.smoke_summary(self.log('Godot Engine v4.6.3\n' + json.dumps(valid) + '\n' + json.dumps(valid)))

    def test_native_errors_and_resource_leaks_are_not_suppressed(self):
        for error in ['SCRIPT ERROR: broken', 'ERROR: lost resource', 'FAIL: mismatch', 'instances leaked at exit', 'resources still in use']:
            with self.subTest(error=error), self.assertRaises(ValueError):p.clean_log(self.log('Godot Engine v4.6.3\n' + error))
        with self.assertRaises(ValueError):p.clean_log(self.log('Godot Engine v4.5.1\n'))

    def runner_fixture(self, keep=False):
        # Reporting/cleanup fixture, no fake native command runner.
        runner = p.Runner.__new__(p.Runner)
        runner.root = self.root;runner.keep = keep;runner.env = os.environ.copy()
        runner.output = self.root / 'work/platforms';runner.output.mkdir(parents=True)
        runner.stage = runner.output / 'run-fixture';runner.stage.mkdir()
        runner.report = {'status':'running','builds':{},'commands':[],'commit':'a'*40,'source_sha256':{'actual':'before'}}
        return runner

    def test_sparse_mode_hashes_then_deletes_only_generated_artifacts(self):
        runner = self.runner_fixture()
        target = runner.stage / 'game.exe';target.write_bytes(b'binary parser fixture')
        console = target.with_suffix('.console.exe');console.write_bytes(b'wrapper parser fixture')
        unrelated = runner.stage / 'preserve.txt';unrelated.write_text('evidence')
        digest = p.sha256(target);runner.record(target, {'format':'test-only metadata'})
        self.assertFalse(target.exists());self.assertFalse(console.exists());self.assertTrue(unrelated.exists())
        self.assertEqual(runner.report['builds']['game.exe']['sha256'], digest)
        self.assertFalse(runner.report['builds']['game.exe']['retained'])
        self.assertEqual(runner.report['status'], 'running')

    def test_keep_mode_retains_the_actual_recorded_bytes(self):
        runner = self.runner_fixture(keep=True)
        target = runner.stage / 'game.x86_64';target.write_bytes(b'fixture')
        runner.record(target, {})
        self.assertTrue(target.exists());self.assertTrue(runner.report['builds']['game.x86_64']['retained'])

    def test_source_or_head_drift_never_becomes_a_success_report(self):
        runner = self.runner_fixture()
        for sources, head in [({'actual':'changed'}, 'a'*40), ({'actual':'before'}, 'b'*40)]:
            with self.subTest(sources=sources,head=head), mock.patch.object(p,'source_snapshot',return_value=sources), mock.patch.object(p.subprocess,'check_output',return_value=head):
                with self.assertRaises(ValueError):runner.finish()
                self.assertNotEqual(runner.report['status'], 'passed')

    def test_editor_config_isolated_without_hiding_installed_templates(self):
        with mock.patch.object(p,'source_snapshot',return_value={}), mock.patch.object(p.subprocess,'check_output',side_effect=['a'*40,'']), mock.patch.dict(os.environ,{'XDG_DATA_HOME':'existing-template-data'}):
            runner=p.Runner('linux',False,self.root)
        self.assertEqual(runner.env['XDG_DATA_HOME'],'existing-template-data')
        self.assertEqual(Path(runner.env['XDG_CONFIG_HOME']).parent,runner.stage/'xdg')
        self.assertEqual(Path(runner.env['XDG_CACHE_HOME']).parent,runner.stage/'xdg')

    def test_real_subprocess_timeout_is_logged_not_counted_as_runtime_pass(self):
        runner = self.runner_fixture()
        with self.assertRaises(subprocess.TimeoutExpired):runner.run('intentional-timeout',[sys.executable,'-c','import time; time.sleep(1)'],timeout=.01)
        self.assertTrue(runner.report['commands'][0]['timed_out'])
        self.assertEqual(runner.report['status'], 'running')


if __name__ == '__main__':unittest.main()
