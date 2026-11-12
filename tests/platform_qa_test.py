"""Metadata/package guard tests only; synthetic containers are not native games.

Actual executable startup and full-duel evidence is required separately by the
platform CI jobs. These tests make malformed, incomplete and stale reports fail.
"""
import ast
import configparser
from contextlib import redirect_stderr
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import re
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


class ExportPresetConfiguration(unittest.TestCase):
    def test_actual_native_duel_command_keeps_verbose_and_strict_deadline(self):
        # Source/command contract only: this does not claim native execution.
        module = ast.parse(Path('tools/platform_qa.py').read_text())
        runner = next(node for node in module.body if isinstance(node, ast.ClassDef) and node.name == 'Runner')
        native_duels = next(node for node in runner.body if isinstance(node, ast.FunctionDef) and node.name == 'native_duels')
        commands = [node for node in ast.walk(native_duels) if isinstance(node, ast.Call)
                    and isinstance(node.func, ast.Attribute) and node.func.attr == 'run'
                    and len(node.args) > 1 and isinstance(node.args[1], ast.List)
                    and any(isinstance(arg, ast.Constant) and arg.value == '--audio-driver' for arg in node.args[1].elts)]
        self.assertEqual(len(commands), 1)
        command = commands[0]
        self.assertEqual([ast.literal_eval(arg) for arg in command.args[1].elts[1:]],
                         ['--headless', '--verbose', '--audio-driver', 'Dummy'])
        self.assertEqual(ast.unparse(command.args[1].elts[0]), 'str(executable)')
        self.assertEqual(ast.unparse(command.args[2]), 'self.isolated')
        self.assertEqual({item.arg: ast.literal_eval(item.value) for item in command.keywords}, {'timeout': 300})

    def test_native_jobs_upload_small_always_evidence_without_removing_binaries(self):
        workflow = Path('.github/workflows/native-platform-qa.yml').read_text()
        parts = re.split(r'(?m)^  ([a-z-]+):\s*$', workflow)
        jobs = dict(zip(parts[1::2], parts[2::2]))
        self.assertEqual(set(jobs), {'linux-android', 'windows'})
        expected = {'work/production/platforms/results.json',
                    'work/production/platforms/run-*/*.json',
                    'work/production/platforms/run-*/*.log'}
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            files = ['work/production/platforms/results.json',
                     'work/production/platforms/run-example/runtime.log',
                     'work/production/platforms/run-example/inventory.json',
                     'work/production/platforms/run-example/game.exe',
                     'work/production/platforms/run-example/game.x86_64',
                     'work/production/platforms/run-example/game.apk',
                     'work/production/platforms/run-example/godot.dll']
            for name in files:
                path = root / name;path.parent.mkdir(parents=True, exist_ok=True);path.write_text('artifact selection fixture')
            for platform, body in jobs.items():
                with self.subTest(platform=platform):
                    small = body.split('- name: Preserve small native diagnostic evidence without binaries\n', 1)[1].split('\n      - ', 1)[0]
                    self.assertIn('if: always()', small)
                    self.assertIn(f'name: orafold-{platform}-evidence-${{{{ github.sha }}}}', small)
                    paths = small.split('          path: |\n', 1)[1].split('          if-no-files-found:', 1)[0]
                    patterns = {line.strip() for line in paths.splitlines() if line.strip()}
                    self.assertEqual(patterns, expected)
                    selected = {path.relative_to(root).as_posix() for pattern in patterns for path in root.glob(pattern)}
                    self.assertEqual(selected, set(files[:3]), 'small artifact must exclude all real executable/ABI payloads')
                    self.assertIn(f'name: orafold-{platform}-debug-${{{{ github.sha }}}}', body)
                    self.assertIn('*.exe' if platform == 'windows' else '*.apk', body)

    def test_every_platform_excludes_editor_addon_and_checkout_sources(self):
        config = configparser.ConfigParser(interpolation=None)
        config.read('export_presets.cfg')
        presets = [name for name in config.sections() if name.startswith('preset.') and name.count('.') == 1]
        self.assertTrue(presets, 'actual export presets must exist')
        for name in presets:
            preset = config[name]
            with self.subTest(preset=preset['name']):
                excluded = set(preset['exclude_filter'].strip('"').split(','))
                self.assertTrue({'addons/orafold_art_delivery/*', 'work/*', 'tests/*', 'docs/*',
                                 'tools/*', 'node_modules/*', '.git/*'} <= excluded)
                self.assertEqual(preset['export_filter'], '"all_resources"')
                # Web streams original art externally; native packages retain it.
                self.assertEqual('assets/cards/originals/*' in excluded, preset['platform'] == '"Web"')
                included = set(preset['include_filter'].strip('"').split(','))
                self.assertTrue({'data/production/*.json', 'data/card_system/*.json',
                                 'assets/fonts/*LICENSE*', 'assets/fonts/*OFL*.txt',
                                 'LICENSE-NOTICE.md'} <= included)


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

    def test_exit_zero_runtime_still_rejects_errors_and_prints_the_actual_log_context(self):
        runner = self.runner_fixture()
        command = [sys.executable, '-c', 'print("Godot Engine v4.6.3\\nERROR: exact-native-cause\\n   at: shutdown_fixture (scene/main/node.cpp:123)")']
        log = runner.run('exit-zero-error-fixture', command)
        self.assertEqual(runner.report['commands'][0]['exit_code'], 0)
        original = log.read_bytes();output = io.StringIO()
        with redirect_stderr(output), self.assertRaisesRegex(ValueError, 'Native runtime contains errors/leaks'):
            p.smoke_summary(log)
        self.assertIn('NATIVE FAILURE LOG', output.getvalue())
        self.assertIn('ERROR: exact-native-cause', output.getvalue())
        self.assertIn('node.cpp:123', output.getvalue())
        self.assertEqual(log.read_bytes(), original, 'the original failure evidence remains untouched')
        self.assertNotEqual(runner.report['status'], 'passed')

    def test_failure_excerpt_finds_late_errors_strips_ansi_and_bounds_output(self):
        text = 'ordinary progress\n' * 5000 + '\x1b[31mSCRIPT ERROR: late actual failure\x1b[0m\n   at: actual_script.gd:41\n' + 'continuing progress\n' * 500
        excerpt = p.diagnostic_excerpt(text)
        self.assertIn('5001: SCRIPT ERROR: late actual failure', excerpt)
        self.assertIn('actual_script.gd:41', excerpt)
        self.assertNotIn('\x1b', excerpt)
        self.assertLessEqual(len(excerpt), 6000)
        self.assertLessEqual(len(excerpt.splitlines()), 40)
        huge = p.diagnostic_excerpt('ERROR: ' + 'x' * 100000)
        self.assertLessEqual(len(huge), 6000)
        self.assertIn('excerpt truncated', huge)
        many = p.diagnostic_excerpt(('ERROR: repetitive\ncontext\n' * 1000), max_lines=8, max_chars=200)
        self.assertLessEqual(len(many.splitlines()), 8)
        self.assertLessEqual(len(many), 200)

    def test_every_existing_strict_error_and_leak_still_fails_with_visible_evidence(self):
        for marker in ['SCRIPT ERROR: actual', 'ERROR: actual', 'FAIL: actual',
                       'WARNING: ObjectDB instances leaked at exit', 'resources still in use']:
            with self.subTest(marker=marker):
                output = io.StringIO()
                with redirect_stderr(output), self.assertRaises(ValueError):
                    p.smoke_summary(self.log('Godot Engine v4.6.3\n' + marker))
                self.assertIn(marker, output.getvalue())

    def test_diagnostic_print_does_not_dump_environment_or_change_success_logs(self):
        output = io.StringIO()
        with mock.patch.dict(os.environ, {'NATIVE_QA_PRIVATE_TEST_TOKEN':'not-for-diagnostic-output'}), redirect_stderr(output):
            p.print_log_diagnostic(self.log('ERROR: native failure\ncontext'))
        self.assertNotIn('not-for-diagnostic-output', output.getvalue())
        self.assertNotIn('NATIVE_QA_PRIVATE_TEST_TOKEN', output.getvalue())
        output = io.StringIO()
        with redirect_stderr(output):
            self.assertEqual(p.clean_log(self.log('Godot Engine v4.6.3\nordinary successful output')), 'Godot Engine v4.6.3\nordinary successful output')
        self.assertEqual(output.getvalue(), '')

    def test_failed_actual_subprocess_preserves_exit_failure_and_prints_its_log(self):
        runner = self.runner_fixture();output = io.StringIO()
        with redirect_stderr(output), self.assertRaisesRegex(ValueError, 'failed with exit7'):
            runner.run('nonzero-fixture', [sys.executable, '-c', 'import sys;print("ERROR: actual child failure");sys.exit(7)'])
        self.assertEqual(runner.report['commands'][0]['exit_code'], 7)
        self.assertIn('actual child failure', output.getvalue())
        self.assertTrue((runner.stage / 'nonzero-fixture.log').is_file())
        self.assertNotEqual(runner.report['status'], 'passed')

    def native_run_fixture(self, leak_on=None, changed=None):
        # Orchestration/parser fixtures run real independent Python children,
        # never claim that the fixture output is actual Godot native evidence.
        runner = self.runner_fixture()
        runner.isolated = self.root / 'isolated';runner.isolated.mkdir()
        executable = runner.stage / 'fixture-native-console.exe'
        original_run = runner.run;calls = []
        summary = {'suite':'production_native_exported','assertions':29,'failures':0,
                   'main_menu_verified':True,'winner':'hero','round':25,'catalog_fingerprint':'a'*64}
        def run_fixture(name, command, cwd, timeout):
            calls.append((name, command, cwd, timeout))
            row = summary | (changed if len(calls) == 2 and changed else {})
            text = 'Godot Engine v4.6.3\n' + json.dumps(row) + '\n'
            if len(calls) == leak_on:
                text += 'WARNING: ObjectDB instances leaked at exit\nERROR: 3 resources still in use at exit\n'
            return original_run(name, [sys.executable, '-c', 'import sys;sys.stdout.write(' + repr(text) + ')'], cwd, timeout)
        runner.run = run_fixture
        return runner, executable, calls, summary

    def test_eight_independent_runs_keep_original_first_log_and_source_bound_rows(self):
        runner, executable, calls, summary = self.native_run_fixture()
        first_log = runner.native_duels(executable, 'orafold-runtime-qa')
        expected_names = ['orafold-runtime-qa-runtime'] + [f'orafold-runtime-qa-runtime-pass-{i:02d}' for i in range(2, 9)]
        self.assertEqual([call[0] for call in calls], expected_names)
        self.assertEqual(first_log, runner.stage / 'orafold-runtime-qa-runtime.log')
        self.assertEqual(runner.report['native_exported_duel'], summary)
        self.assertTrue(runner.report['main_menu_verified'])
        for index, (call, evidence) in enumerate(zip(calls, runner.report['native_teardown_runs']), 1):
            self.assertEqual(call[1], [str(executable), '--headless', '--verbose', '--audio-driver', 'Dummy'])
            self.assertEqual(call[2:], (runner.isolated, 300))
            self.assertEqual(evidence['pass'], index)
            self.assertEqual(evidence['status'], 'passed')
            self.assertEqual(evidence['summary'], summary)
            self.assertEqual(evidence['commit'], runner.report['commit'])
            self.assertEqual(evidence['source_report_field'], 'source_sha256')
            self.assertEqual(evidence['executable'], str(executable.relative_to(self.root)))
            self.assertTrue((self.root / evidence['log']).is_file())
        self.assertEqual(len(runner.report['commands']), 8)
        self.assertTrue(all(row['exit_code'] == 0 for row in runner.report['commands']))
        self.assertNotEqual(runner.report['status'], 'passed', 'only full source-bound finish can pass the build')

    def test_midpass_exit_zero_leak_aborts_before_any_later_pass(self):
        runner, executable, calls, summary = self.native_run_fixture(leak_on=4)
        output = io.StringIO()
        with redirect_stderr(output), self.assertRaisesRegex(ValueError, 'Native runtime contains errors/leaks'):
            runner.native_duels(executable, 'orafold-runtime-qa')
        self.assertEqual(len(calls), 4, 'a later clean run must never mask an earlier leak')
        self.assertEqual([row['status'] for row in runner.report['native_teardown_runs']], ['passed'] * 3 + ['failed'])
        self.assertEqual(runner.report['commands'][-1]['exit_code'], 0)
        self.assertIn('3 resources still in use', output.getvalue())
        self.assertTrue((runner.stage / 'orafold-runtime-qa-runtime-pass-04.log').is_file())
        self.assertFalse((runner.stage / 'orafold-runtime-qa-runtime-pass-05.log').exists())
        retained = json.loads((runner.output / 'results.json').read_text())
        self.assertEqual(retained['native_teardown_runs'][-1]['status'], 'failed')
        self.assertEqual(retained['native_exported_duel'], summary)
        self.assertNotEqual(retained['status'], 'passed')

    def test_catalog_winner_or_round_drift_aborts_independent_fixed_seed_runs(self):
        original_root = self.root
        for field, value in [('catalog_fingerprint', 'b' * 64), ('winner', 'enemy'), ('round', 26)]:
            with self.subTest(field=field):
                self.root = original_root / field;self.root.mkdir()
                runner, executable, calls, _ = self.native_run_fixture(changed={field:value})
                with redirect_stderr(io.StringIO()), self.assertRaisesRegex(ValueError, 'Fixed-seed native outcome changed'):
                    runner.native_duels(executable, 'orafold-runtime-qa')
                self.assertEqual(len(calls), 2)
                self.assertEqual(runner.report['native_teardown_runs'][-1]['status'], 'failed')
                self.assertEqual(runner.report['native_teardown_runs'][-1]['summary'][field], value)
                self.assertNotEqual(runner.report['status'], 'passed')

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
