import importlib.util
import json
import os
import re
from pathlib import Path
import signal
import stat
import subprocess
import tempfile
import time
import unittest
from unittest.mock import Mock,patch
import yaml

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('deps',ROOT/'tools/ci/install_dependencies.py')
deps=importlib.util.module_from_spec(spec);spec.loader.exec_module(deps)


class DependencyInstaller(unittest.TestCase):
    def setUp(self):
        self.directory=tempfile.TemporaryDirectory();self.root=Path(self.directory.name)
        self.apt=self.root/'apt';(self.apt/'apt.conf.d').mkdir(parents=True)
        self.mirror=self.apt/'apt-mirrors.txt';self.original=b'http://azure.archive.ubuntu.com/ubuntu priority:1\n'
        self.mirror.write_bytes(self.original);self.mirror.chmod(0o640)
        self.os=self.root/'os-release';self.os.write_text('ID=ubuntu\nVERSION_ID="24.04"\nVERSION_CODENAME=noble\n')
        self.keyring=self.root/'ubuntu-archive-keyring.gpg';self.keyring.write_bytes(b'fixture keyring; no network signature verification performed')
        self.keyring_original=self.keyring.read_bytes();self.keyring_before=self.keyring.stat()
        self.keyring_patch=patch.object(deps,'UBUNTU_KEYRING',self.keyring);self.keyring_patch.start();self.addCleanup(self.keyring_patch.stop)
        (self.apt/'sources.list.d').mkdir();self.sources=self.apt/'sources.list.d'/'ubuntu.sources'
        self.sources.write_text(f'Types: deb\nURIs: mirror+file:{self.mirror}\nSuites: noble noble-updates noble-backports noble-security\nComponents: main restricted universe multiverse\nSigned-By: {self.keyring}\n')
        self.source_original=self.sources.read_bytes();self.source_before=self.sources.stat()
        self.thirdparty=self.apt/'sources.list.d'/'microsoft-prod.list'
        self.thirdparty.write_text('deb [arch=amd64] https://packages.microsoft.com/ubuntu/24.04/prod noble main\n');self.thirdparty.chmod(0o640)
        self.thirdparty_original=self.thirdparty.read_bytes();self.thirdparty_before=self.thirdparty.stat()
        self.scoped_configuration=deps.APT_LIMITS+deps.ubuntu_source_configuration(self.apt,self.os)
        self.cli=self.root/'playwright';self.calls=self.root/'calls.jsonl';self.log=self.root/'install.log'
        self.cli.write_text("""#!/usr/bin/env python3
import json,os,pathlib,sys,time,subprocess,signal,stat
root=pathlib.Path(os.environ['FAKE_APT_ROOT']);calls=pathlib.Path(os.environ['FAKE_CALLS'])
rows=calls.read_text().splitlines() if calls.exists() else []
entry={'arguments':sys.argv[1:],'mirror':(root/'apt-mirrors.txt').read_text() if (root/'apt-mirrors.txt').exists() else None,'configs':[p.read_text() for p in (root/'apt.conf.d').glob('*')]}
entry['sources']={p.name:p.read_text() for p in (root/'sources.list.d').glob('*')}
if os.environ.get('FAKE_APT_PRINT_CONFIG'):
 result=subprocess.run(['/usr/bin/apt-get','update','--print-uris'],env={**os.environ,'APT_CONFIG':os.environ['FAKE_APT_PRINT_CONFIG']},stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=10)
 entry['apt_status']=result.returncode;entry['apt_uris']=result.stdout
if (root/'apt-mirrors.txt').exists():
 info=(root/'apt-mirrors.txt').stat();entry['mirror_metadata']=[info.st_uid,info.st_gid,stat.S_IMODE(info.st_mode)]
with calls.open('a') as output:output.write(json.dumps(entry)+'\\n')
codes=json.loads(os.environ.get('FAKE_CODES','[0]'));status=codes[min(len(rows),len(codes)-1)]
if os.environ.get('FAKE_SLEEP') or os.environ.get('FAKE_SLEEP_STAGE')==sys.argv[1]:
 print(os.environ.get('FAKE_WAIT_OUTPUT','fake installer waiting'),flush=True)
 if os.environ.get('FAKE_READY'):pathlib.Path(os.environ['FAKE_READY']).write_text('ready')
 time.sleep(3)
if os.environ.get('FAKE_CHILD'):
 child=subprocess.Popen([sys.executable,'-c','import time;time.sleep(30)'])
 def terminate(signum,frame):child.wait(timeout=2);sys.exit(143)
 signal.signal(signal.SIGTERM,terminate)
 pathlib.Path(os.environ['FAKE_CHILD']).write_text(str(child.pid))
 print('fake installer child waiting',flush=True);time.sleep(30)
print(os.environ.get('FAKE_ERROR','Error: Installation process exited with code:100') if status else 'actual fake process completed')
sys.exit(status)
""")
        self.cli.chmod(0o755)
        self.environment=patch.dict(os.environ,{'GITHUB_ACTIONS':'false','FAKE_APT_ROOT':str(self.apt),'FAKE_CALLS':str(self.calls),'FAKE_CODES':'[0]','FAKE_ERROR':'Error: Installation process exited with code:100'},clear=False)
        self.environment.start()
        self.before=self.mirror.stat()

    def tearDown(self):
        self.environment.stop();self.directory.cleanup()

    def local_root(self,command):
        # Real cp/install/rm against temporary files; never sudo or /etc.
        for part in command[1:]:
            if part.startswith('/'):
                self.assertTrue(part.startswith(str(self.root)) or part.startswith('/tmp/orafold-ci-deps-'),part)
        subprocess.run(command,check=True)

    def run_installer(self,**kwargs):
        return deps.install('playwright',[str(self.cli),'chromium','webkit'],self.log,apt_root=self.apt,os_release=self.os,root_command=self.local_root,**kwargs)

    def rows(self):return [json.loads(row) for row in self.calls.read_text().splitlines()]

    def assert_restored(self):
        self.assertEqual(self.mirror.read_bytes(),self.original)
        after=self.mirror.stat()
        self.assertEqual((after.st_uid,after.st_gid,stat.S_IMODE(after.st_mode)),(self.before.st_uid,self.before.st_gid,stat.S_IMODE(self.before.st_mode)))
        self.assertEqual(list((self.apt/'apt.conf.d').iterdir()),[])
        for path,content,before in [(self.sources,self.source_original,self.source_before),(self.thirdparty,self.thirdparty_original,self.thirdparty_before),(self.keyring,self.keyring_original,self.keyring_before)]:
            self.assertEqual(path.read_bytes(),content)
            after=path.stat();self.assertEqual((after.st_uid,after.st_gid,stat.S_IMODE(after.st_mode)),(before.st_uid,before.st_gid,stat.S_IMODE(before.st_mode)))

    def test_success_uses_original_mirrors_once_and_keeps_required_dependencies(self):
        self.assertEqual(self.run_installer(),0);rows=self.rows();self.assertEqual(len(rows),2)
        self.assertEqual(rows[0]['mirror'],self.original.decode())
        self.assertEqual(rows[0]['arguments'],['install-deps','chromium','webkit'])
        self.assertEqual(rows[0]['configs'],[deps.APT_LIMITS])
        self.assertEqual(rows[1]['arguments'],['install','chromium','webkit'])
        self.assertEqual(rows[1]['mirror'],self.original.decode())
        self.assertEqual(rows[1]['configs'],[],'APT configuration is restored before browser download')
        self.assert_restored()

    def test_existing_npm_bootstrap_diagnostics_are_preserved(self):
        self.log.write_text('npm bootstrap diagnostic\n')
        self.assertEqual(self.run_installer(),0)
        self.assertTrue(self.log.read_text().startswith('npm bootstrap diagnostic\n'))
        self.assert_restored()

    def test_github_actions_first_attempt_uses_official_https_and_restores_before_browser(self):
        os.environ['GITHUB_ACTIONS']='true'
        self.assertEqual(self.run_installer(),0);rows=self.rows();self.assertEqual(len(rows),2)
        self.assertEqual(rows[0]['arguments'],['install-deps','chromium','webkit'])
        self.assertEqual(rows[0]['mirror'],deps.OFFICIAL_MIRRORS)
        self.assertEqual(rows[0]['mirror'].splitlines(),['https://archive.ubuntu.com/ubuntu\tpriority:1','https://security.ubuntu.com/ubuntu\tpriority:2'])
        self.assertEqual(rows[0]['configs'],[self.scoped_configuration])
        self.assertTrue(rows[0]['configs'][0].startswith('Acquire::Retries "2";\nAcquire::http::Timeout "20";\nAcquire::https::Timeout "20";\nAPT::Update::Error-Mode "any";\n'))
        self.assertEqual(rows[1]['arguments'],['install','chromium','webkit'])
        self.assertEqual(rows[1]['mirror'],self.original.decode())
        self.assertEqual(rows[1]['mirror_metadata'],[self.before.st_uid,self.before.st_gid,stat.S_IMODE(self.before.st_mode)])
        self.assertEqual(rows[1]['configs'],[])
        self.assertIn('Attempt1: official Ubuntu archive/security HTTPS mirrors',self.log.read_text())
        self.assertIn('GitHub Actions Ubuntu regular mirrorlist avoids slow runner HTTP mirrors',self.log.read_text())
        self.assert_restored()

    def test_github_actions_flag_must_be_exactly_true(self):
        for flag in ('false','TRUE','1',''):
            with self.subTest(flag=flag):
                os.environ['GITHUB_ACTIONS']=flag
                self.assertEqual(self.run_installer(),0)
                self.assertEqual(self.rows()[-2]['mirror'],self.original.decode())
                self.assert_restored()

    def test_github_actions_download_failure_retries_official_mirrors_once(self):
        os.environ.update(GITHUB_ACTIONS='true',FAKE_CODES='[1,0]')
        self.assertEqual(self.run_installer(),0);rows=self.rows();self.assertEqual(len(rows),3)
        self.assertEqual([row['mirror'] for row in rows],[deps.OFFICIAL_MIRRORS,deps.OFFICIAL_MIRRORS,self.original.decode()])
        self.assertTrue(all(row['arguments']==['install-deps','chromium','webkit'] for row in rows[:2]))
        self.assertEqual(rows[2]['configs'],[])
        self.assertEqual(rows[2]['mirror_metadata'],[self.before.st_uid,self.before.st_gid,stat.S_IMODE(self.before.st_mode)])
        self.assertIn('one bounded retry after an Ubuntu dependency-download failure',self.log.read_text())
        self.assert_restored()

    def test_github_actions_persistent_download_failure_stops_after_two_official_attempts(self):
        os.environ.update(GITHUB_ACTIONS='true',FAKE_CODES='[1,7,0]')
        self.assertEqual(self.run_installer(),7);rows=self.rows();self.assertEqual(len(rows),2)
        self.assertTrue(all(row['mirror']==deps.OFFICIAL_MIRRORS for row in rows))
        self.assertTrue(all(row['arguments'][0]=='install-deps' for row in rows))
        self.assertIn('CI remains failed',self.log.read_text());self.assert_restored()

    def test_github_actions_browser_failure_is_fatal_once_after_cleanup(self):
        os.environ.update(GITHUB_ACTIONS='true',FAKE_CODES='[0,100,0]',FAKE_ERROR='Failed to install browser dependencies')
        self.assertEqual(self.run_installer(),100);rows=self.rows();self.assertEqual(len(rows),2)
        self.assertEqual(rows[0]['mirror'],deps.OFFICIAL_MIRRORS)
        self.assertEqual(rows[1]['mirror'],self.original.decode());self.assertEqual(rows[1]['configs'],[])
        self.assertNotIn('Attempt2:',self.log.read_text());self.assert_restored()

    def test_github_actions_postconfigure_timeout_never_retries_or_infers_success(self):
        # Main44231456766/job134565476520: the EC2 HTTP transfer consumed4m15s
        # before a300s deadline stopped libc-bin triggers, before any browser.
        # A real controlled process exercises cancellation after those lines;
        # it does not perform APT/network work or wait for the original delay.
        ready=self.root/'installer.ready'
        os.environ.update(GITHUB_ACTIONS='true',FAKE_SLEEP='yes',FAKE_READY=str(ready),FAKE_WAIT_OUTPUT='Fetched 32.1 MB in 4min 15s (126 kB/s)\nSetting up libgbm1:amd64 (25.2.8-0ubuntu0.24.04.5) ...\nProcessing triggers for libc-bin (2.39-0ubuntu8.7) ...')
        real_popen=deps.subprocess.Popen
        def ready_popen(command,*args,**kwargs):
            process=real_popen(command,*args,**kwargs)
            if command[0]!=str(self.cli):return process
            ready_deadline=time.monotonic()+10
            try:
                while not ready.exists():
                    self.assertIsNone(process.poll(),'Fake installer exited before configuration output.')
                    self.assertLess(time.monotonic(),ready_deadline,'Fake installer did not reach configuration output.')
                    time.sleep(.01)
            except BaseException:
                if process.poll() is None:os.killpg(process.pid,signal.SIGKILL)
                process.communicate(timeout=5)
                raise
            return process
        with patch.object(deps.subprocess,'Popen',side_effect=ready_popen):
            self.assertEqual(self.run_installer(timeout=.1),124)
        rows=self.rows();self.assertEqual(len(rows),1);self.assertEqual(rows[0]['mirror'],deps.OFFICIAL_MIRRORS)
        text=self.log.read_text();self.assertIn('Fetched 32.1 MB in 4min 15s (126 kB/s)',text)
        self.assertIn('Processing triggers for libc-bin',text);self.assertIn('no success was inferred',text)
        self.assertNotIn('Attempt2:',text);self.assertNotIn('Browser download and host validation phase:',text)
        self.assert_restored()

    def test_github_actions_unsupported_mirrorlist_or_os_never_overwrites(self):
        os.environ.update(GITHUB_ACTIONS='true',FAKE_CODES='[1,0]')
        # A valid direct HTTPS source can still be isolated when the optional
        # mirrorlist is unsupported; that mirrorlist must remain untouched.
        self.sources.write_text(self.sources.read_text().replace('mirror+file:'+str(self.mirror),'https://archive.ubuntu.com/ubuntu/'))
        for case in ('missing','symlink','non-ubuntu'):
            with self.subTest(case=case):
                self.calls.unlink(missing_ok=True);self.mirror.unlink(missing_ok=True)
                self.os.write_text('ID=other\n' if case=='non-ubuntu' else 'ID=ubuntu\nVERSION_ID=24.04\nVERSION_CODENAME=noble\n')
                if case=='symlink':
                    target=self.root/'other-mirror';target.write_bytes(self.original);self.mirror.symlink_to(target)
                elif case=='non-ubuntu':self.mirror.write_bytes(self.original)
                self.assertEqual(self.run_installer(),1);rows=self.rows();self.assertEqual(len(rows),1)
                self.assertEqual(rows[0]['mirror'],None if case=='missing' else self.original.decode())
                self.assertIn('supported regular Ubuntu mirrorlist unavailable',self.log.read_text())
                if case=='symlink':
                    self.assertTrue(self.mirror.is_symlink());self.assertEqual(target.read_bytes(),self.original)
                elif case=='missing':self.assertFalse(self.mirror.exists())
                else:self.assertEqual(self.mirror.read_bytes(),self.original);self.assertEqual(rows[0]['configs'],[])
                self.assertEqual(list((self.apt/'apt.conf.d').iterdir()),[])

    def test_github_actions_mirror_backup_or_first_write_failure_cleans_up_before_execute(self):
        os.environ['GITHUB_ACTIONS']='true'
        for stage in ('backup','first-write'):
            with self.subTest(stage=stage):
                def failed_setup(command):
                    if stage=='backup' and command[:2]==['cp','-p'] and command[2]==str(self.mirror):raise OSError('test backup refused')
                    self.local_root(command)
                    if stage=='first-write' and command[0]=='cp' and 'official-mirrors.txt' in command[1]:raise OSError('test write interrupted')
                with self.assertRaises(OSError):
                    deps.install('playwright',[str(self.cli),'chromium'],self.log,apt_root=self.apt,os_release=self.os,root_command=failed_setup)
                self.assertFalse(self.calls.exists());self.assert_restored()

    def test_github_actions_restore_failure_prevents_browser_and_remains_fatal(self):
        os.environ['GITHUB_ACTIONS']='true'
        def failed_restore(command):
            if command[:2]==['cp','-p'] and 'original-mirrors' in command[2]:raise OSError('test restore refused')
            self.local_root(command)
        with self.assertRaises(RuntimeError):
            deps.install('playwright',[str(self.cli),'chromium'],self.log,apt_root=self.apt,os_release=self.os,root_command=failed_restore)
        self.assertEqual(len(self.rows()),1);self.assertEqual(self.rows()[0]['arguments'][0],'install-deps')
        self.assertIn('cleanup failed',self.log.read_text());self.assertEqual(list((self.apt/'apt.conf.d').iterdir()),[])

    def test_real_apt_excludes_microsoft_only_during_system_phase_without_editing_sources(self):
        # Main44309750137/job134820510983: official Ubuntu succeeded, but a
        # preinstalled Microsoft feed returned429 and apt update failed100.
        # Real APT --print-uris enumerates both phases' source configuration
        # without fetching metadata/packages or touching system APT state.
        self.sources.write_bytes(self.source_original.replace(('mirror+file:'+str(self.mirror)).encode(),b'https://archive.ubuntu.com/ubuntu/'))
        self.source_original=self.sources.read_bytes()
        lists=self.root/'lists';(lists/'partial').mkdir(parents=True)
        config=self.root/'apt-parser.conf'
        config.write_text(f'Dir::Etc "{self.apt}";\nDir::Etc::parts "{self.apt}/apt.conf.d";\nDir::Etc::main "-";\nDir::State::lists "{lists}";\nDebug::NoLocking "true";\n')
        os.environ.update(GITHUB_ACTIONS='true',FAKE_APT_PRINT_CONFIG=str(config))
        self.assertEqual(self.run_installer(),0);rows=self.rows();self.assertEqual(len(rows),2)
        for row in rows:
            self.assertEqual(row['apt_status'],0,row['apt_uris'])
            self.assertIn('https://archive.ubuntu.com/ubuntu/dists/noble/InRelease',row['apt_uris'])
            self.assertEqual(row['sources'],{'ubuntu.sources':self.source_original.decode(),'microsoft-prod.list':self.thirdparty_original.decode()})
        self.assertNotIn('packages.microsoft.com',rows[0]['apt_uris'])
        self.assertIn('packages.microsoft.com/ubuntu/24.04/prod/dists/noble/InRelease',rows[1]['apt_uris'])
        self.assertEqual(rows[1]['configs'],[]);self.assert_restored()

    def test_github_actions_source_validation_rejects_unsafe_or_incomplete_deb822(self):
        os.environ['GITHUB_ACTIONS']='true'
        original=self.source_original.decode()
        bad_sources={
            'third-party URI':original.replace('mirror+file:'+str(self.mirror),'https://packages.microsoft.com/ubuntu/24.04/prod'),
            'HTTP URI':original.replace('mirror+file:'+str(self.mirror),'http://archive.ubuntu.com/ubuntu'),
            'host suffix':original.replace('mirror+file:'+str(self.mirror),'https://archive.ubuntu.com.evil.invalid/ubuntu'),
            'URI userinfo':original.replace('mirror+file:'+str(self.mirror),'https://user@archive.ubuntu.com/ubuntu'),
            'URI query':original.replace('mirror+file:'+str(self.mirror),'https://archive.ubuntu.com/ubuntu?trusted=yes'),
            'foreign mirrorlist':original.replace(str(self.mirror),str(self.root/'foreign-mirrors')),
            'foreign key':original.replace(str(self.keyring),str(self.root/'foreign-key.gpg')),
            'inline key':original.replace(str(self.keyring),'-----BEGIN PGP PUBLIC KEY BLOCK-----\n key-data'),
            'trusted yes':original+'Trusted: yes\n',
            'signature override':original+'Allow-Insecure: yes\n',
            'TLS override':original+'Verify-Peer: false\n',
            'duplicate key field':original+f'sIgNeD-bY: {self.keyring}\n',
            'continued URI':original.replace('URIs:',' URIs:'),
            'wrong suite':original.replace('noble-updates','jammy-updates'),
            'missing security suite':original.replace(' noble-security',''),
            'missing base suite':original.replace('Suites: noble ','Suites: '),
            'missing component':original.replace(' multiverse',''),
            'disabled source':original+'Enabled: no\n',
            'unsupported architecture':original+'Architectures: amd64 foreign\n',
            'missing signature key':re.sub(r'^Signed-By:.*\n','',original,flags=re.M),
            'empty file':'',
            'unvalidated second stanza':original+'\n'+original.replace('mirror+file:'+str(self.mirror),'https://example.invalid/ubuntu'),
        }
        for reason,content in bad_sources.items():
            with self.subTest(reason=reason):
                self.sources.write_text(content)
                with self.assertRaisesRegex(RuntimeError,'Unsupported GitHub Actions Ubuntu APT sources'):
                    self.run_installer()
                self.assertFalse(self.calls.exists());self.assertEqual(self.sources.read_text(),content)
                self.assertEqual(self.mirror.read_bytes(),self.original);self.assertEqual(self.thirdparty.read_bytes(),self.thirdparty_original)
                self.assertEqual(list((self.apt/'apt.conf.d').iterdir()),[])

    def test_github_actions_source_or_keyring_must_be_regular_unwritable_and_present(self):
        os.environ['GITHUB_ACTIONS']='true'
        for path in (self.sources,self.keyring):
            content=path.read_bytes()
            for kind in ('missing','symlink','directory','writable'):
                with self.subTest(path=path.name,kind=kind):
                    path.unlink()
                    if kind=='symlink':
                        target=self.root/'foreign-file';target.write_bytes(content);path.symlink_to(target)
                    elif kind=='directory':path.mkdir()
                    elif kind=='writable':path.write_bytes(content);path.chmod(0o666)
                    with self.assertRaisesRegex(RuntimeError,'Unsupported GitHub Actions Ubuntu APT sources'):
                        self.run_installer()
                    self.assertFalse(self.calls.exists());self.assertEqual(self.mirror.read_bytes(),self.original)
                    self.assertEqual(self.thirdparty.read_bytes(),self.thirdparty_original);self.assertEqual(list((self.apt/'apt.conf.d').iterdir()),[])
                    if kind=='directory':path.rmdir()
                    else:path.unlink(missing_ok=True)
                    path.write_bytes(content);path.chmod(0o644)

    def test_github_actions_unsupported_ubuntu_release_fails_before_source_isolation(self):
        os.environ['GITHUB_ACTIONS']='true'
        for release in ('ID=ubuntu\nVERSION_ID=22.04\nVERSION_CODENAME=jammy\n','ID=ubuntu\nVERSION_ID=24.04\nVERSION_CODENAME=jammy\n','ID=ubuntu\nVERSION_CODENAME=noble\n'):
            with self.subTest(release=release):
                self.os.write_text(release)
                with self.assertRaisesRegex(RuntimeError,'expected Ubuntu24.04/noble'):
                    self.run_installer()
                self.assertFalse(self.calls.exists());self.assert_restored()

    def test_github_actions_symlink_source_directory_is_not_used(self):
        os.environ['GITHUB_ACTIONS']='true'
        directory=self.apt/'sources.list.d';real_directory=self.root/'sourceparts';directory.rename(real_directory);directory.symlink_to(real_directory,target_is_directory=True)
        try:
            with self.assertRaisesRegex(RuntimeError,'regular ubuntu.sources required'):
                self.run_installer()
            self.assertFalse(self.calls.exists());self.assertTrue(directory.is_symlink());self.assert_restored()
        finally:
            directory.unlink();real_directory.rename(directory)

    def test_github_actions_source_scope_cleanup_failure_prevents_browser(self):
        os.environ['GITHUB_ACTIONS']='true'
        def failed_removal(command):
            if command[:3]==['rm','-f','--']:raise OSError('test temporary configuration removal refused')
            self.local_root(command)
        with self.assertRaisesRegex(RuntimeError,'could not be restored'):
            deps.install('playwright',[str(self.cli),'chromium'],self.log,apt_root=self.apt,os_release=self.os,root_command=failed_removal)
        rows=self.rows();self.assertEqual(len(rows),1);self.assertEqual(rows[0]['arguments'][0],'install-deps')
        self.assertEqual(rows[0]['configs'],[self.scoped_configuration]);self.assertIn('temporary configuration removal: OSError',self.log.read_text())
        for config in (self.apt/'apt.conf.d').iterdir():config.unlink()
        self.assert_restored()

    def test_github_actions_existing_disabled_sourceparts_path_is_rejected(self):
        os.environ['GITHUB_ACTIONS']='true';disabled=self.apt/'-'
        for kind in ('directory','symlink'):
            with self.subTest(kind=kind):
                if kind=='directory':disabled.mkdir();(disabled/'thirdparty.list').write_bytes(self.thirdparty_original)
                else:disabled.symlink_to(self.root/'missing-sourceparts',target_is_directory=True)
                with self.assertRaisesRegex(RuntimeError,'disabled sourceparts path must be absent'):
                    self.run_installer()
                self.assertFalse(self.calls.exists());self.assert_restored()
                if kind=='directory':(disabled/'thirdparty.list').unlink();disabled.rmdir()
                else:disabled.unlink()

    def test_github_actions_standard_two_stanza_sources_and_valid_optional_fields_are_supported(self):
        os.environ['GITHUB_ACTIONS']='true'
        base=self.source_original.decode().replace(' noble-security','')+'Architectures: amd64\nEnabled: yes\n'
        security=self.source_original.decode().replace('mirror+file:'+str(self.mirror),'https://security.ubuntu.com/ubuntu/').replace('noble noble-updates noble-backports noble-security','noble-security')
        self.sources.write_text('# Standard Ubuntu deb822 sources\n'+base+'\n'+security);self.source_original=self.sources.read_bytes()
        self.assertEqual(self.run_installer(),0);rows=self.rows();self.assertEqual(len(rows),2)
        self.assertEqual(rows[0]['configs'],[self.scoped_configuration]);self.assertEqual(rows[1]['configs'],[])
        self.assert_restored()

    def test_local_install_keeps_unrecognized_sources_and_third_party_feeds_unchanged(self):
        self.sources.write_text('unrecognized local source configuration\n');self.source_original=self.sources.read_bytes()
        self.assertEqual(self.run_installer(),0);rows=self.rows();self.assertEqual(len(rows),2)
        self.assertEqual(rows[0]['configs'],[deps.APT_LIMITS])
        self.assertEqual(rows[1]['configs'],[]);self.assert_restored()

    def test_actual_dependency_failure_gets_one_official_fallback_and_restores(self):
        os.environ['FAKE_CODES']='[1,0]'
        self.assertEqual(self.run_installer(),0);rows=self.rows();self.assertEqual(len(rows),3)
        self.assertEqual(rows[0]['mirror'],self.original.decode());self.assertEqual(rows[1]['mirror'],deps.OFFICIAL_MIRRORS)
        self.assertTrue(all(row['arguments']==['install-deps','chromium','webkit'] for row in rows[:2]))
        self.assertEqual(rows[2]['arguments'],['install','chromium','webkit'])
        self.assertEqual(rows[2]['mirror'],self.original.decode())
        self.assertEqual(rows[2]['configs'],[],'retry cleanup precedes browser download')
        self.assert_restored()

    def test_persistent_failure_stays_failed_without_third_attempt(self):
        os.environ['FAKE_CODES']='[1,7]'
        self.assertEqual(self.run_installer(),7);self.assertEqual(len(self.rows()),2)
        self.assertTrue(all(row['arguments'][0]=='install-deps' for row in self.rows()),'failed system dependencies prevent browser download')
        self.assertIn('CI remains failed',self.log.read_text());self.assert_restored()

    def test_browser_cdn_error_does_not_rewrite_dependency_mirrors(self):
        os.environ.update(FAKE_CODES='[0,1,0]',FAKE_ERROR='Failed to download Chromium: CDN returned503')
        self.assertEqual(self.run_installer(),1);rows=self.rows();self.assertEqual(len(rows),2)
        self.assertTrue(all(row['mirror']==self.original.decode() for row in rows))
        self.assertEqual(rows[1]['configs'],[])
        self.assert_restored()

    def test_real_ubuntu_transfer_timeout_gets_one_bounded_official_fallback(self):
        # Terminal subprocess lines from Main44202171157/job134458772372:
        # the300second deadline stopped APT before it could emit an E: error.
        stalled='''Installing dependencies...
Get:9 http://us-east-2.ec2.archive.ubuntu.com/ubuntu noble-updates/main amd64 libgbm1 amd64 25.2.8-0ubuntu0.24.04.5 [34.2 kB]
Get:10 http://us-east-2.ec2.archive.ubuntu.com/ubuntu noble-updates/main amd64 mesa-libgallium amd64 25.2.8-0ubuntu0.24.04.5 [10.8 MB]
CI dependency attempt exceeded 300s; no success was inferred.
'''
        calls=[]
        def execute(commands,timeout,root_command):
            calls.append({'timeout':timeout,'mirror':self.mirror.read_text(),'commands':commands})
            return (124,stalled) if len(calls)==1 else (0,'Dependencies and browser installed.\n')
        with patch.object(deps,'execute',side_effect=execute):
            self.assertEqual(self.run_installer(),0)
        self.assertEqual(len(calls),3)
        self.assertEqual([call['timeout'] for call in calls],[300,300,300])
        self.assertEqual([call['mirror'] for call in calls],[self.original.decode(),deps.OFFICIAL_MIRRORS,self.original.decode()])
        self.assertEqual(calls[0]['commands'],calls[1]['commands'])
        self.assertEqual(calls[2]['commands'],[[str(self.cli),'install','chromium','webkit']])
        self.assert_restored()

    def test_slow_successful_system_phase_does_not_consume_browser_deadline(self):
        # Main44204333910/job134476925062: APT completed, then Chrome's197.8MiB
        # reached100%, but the old shared deadline killed download/unpacking.
        # A controlled clock exercises execute's actual deadline arithmetic;
        # no network, sleeps, or assumption about fixture startup speed.
        clock=[0.0];timeouts=[];commands=[]
        def popen(command,**kwargs):
            commands.append(command)
            process=Mock();process.returncode=0
            def communicate(timeout):
                timeouts.append(timeout)
                clock[0]+=299.0
                return ('system dependencies installed' if command[1]=='install-deps' else 'browser downloaded, unpacked and host validation reached','')
            process.communicate.side_effect=communicate
            return process
        with patch.object(deps.time,'monotonic',side_effect=lambda:clock[0]),patch.object(deps.subprocess,'Popen',side_effect=popen):
            # This test examines Popen deadline logic, not temporary cp/install;
            # cleanup paths are executed by the real-process cases above.
            self.assertEqual(deps.install('playwright',[str(self.cli),'chromium'],self.log,apt_root=self.apt,os_release=self.os,root_command=lambda command:None),0)
        self.assertEqual(commands,[[str(self.cli),'install-deps','chromium'],[str(self.cli),'install','chromium']])
        self.assertEqual(timeouts,[300,300])
        self.assertEqual(clock[0],598)

    def test_browser_timeout_at_100_percent_is_not_success_or_an_apt_retry(self):
        text='Downloading Chrome for Testing158.0.8127.18 (197.8MiB)\n100% of197.8MiB\nCI dependency attempt exceeded 300s; no success was inferred.\n'
        with patch.object(deps,'execute',side_effect=[(0,'System dependencies installed\n'),(124,text)]) as execute:
            self.assertEqual(self.run_installer(),124)
        self.assertEqual(execute.call_count,2)
        self.assertIn('Browser installation failed with exit124; CI remains failed',self.log.read_text())
        self.assertNotIn('Attempt2:',self.log.read_text());self.assert_restored()

    def test_browser_stage_failure_never_reenters_system_dependency_retry(self):
        os.environ.update(FAKE_CODES='[0,100,0]',FAKE_ERROR='Failed to install browser dependencies')
        self.assertEqual(self.run_installer(),100)
        rows=self.rows();self.assertEqual(len(rows),2)
        self.assertTrue(all(row['mirror']==self.original.decode() for row in rows))
        self.assertEqual(rows[1]['configs'],[])
        self.assertNotIn('Attempt2:',self.log.read_text());self.assert_restored()

    def test_browser_stage_has_its_own_actual_process_deadline(self):
        os.environ['FAKE_SLEEP_STAGE']='install'
        real_execute=deps.execute;calls=[]
        def execute(commands,timeout,root_command):
            calls.append((commands,timeout))
            # Don't make unrelated system-fixture startup speed a prerequisite
            # for testing the real browser process cancellation. Other cases
            # execute both actual phases; this one isolates the second stage.
            if len(calls)==1:return 0,'system phase completed\n'
            self.assert_restored()
            return real_execute(commands,timeout,root_command)
        with patch.object(deps,'execute',side_effect=execute):
            self.assertEqual(self.run_installer(timeout=.1),124)
        self.assertEqual(calls,[([[str(self.cli),'install-deps','chromium','webkit']],.1),([[str(self.cli),'install','chromium','webkit']],.1)])
        self.assertIn('Browser installation failed with exit124',self.log.read_text())
        self.assert_restored()

    def test_ubuntu_transfer_timeout_is_not_inferred_from_old_or_unrelated_output(self):
        apt='Get:10 http://us-east-2.ec2.archive.ubuntu.com/ubuntu noble-updates/main amd64 mesa-libgallium amd64 25.2.8 [10.8 MB]\n'
        timeout='CI dependency attempt exceeded 300s; no success was inferred.\n'
        for text,status in [(apt+timeout,1),(apt,124),('fake installer waiting\n'+timeout,124),
                            (apt+'Downloading Chromium from https://cdn.playwright.dev/\n'+timeout,124),
                            (apt+'Fetched32.1MB\n'+timeout,124),
                            ('Get:10 https://ubuntu.com.evil.invalid/ubuntu noble Packages\n'+timeout,124)]:
            with self.subTest(text=text,status=status):
                self.assertFalse(deps.dependency_failure(text,status))
                with patch.object(deps,'execute',return_value=(status,text)) as execute:
                    self.assertEqual(self.run_installer(),status)
                    self.assertEqual(execute.call_count,1)
                self.assert_restored()

    def test_persistent_ubuntu_download_timeout_stays_failed_after_exactly_two_attempts(self):
        text='Get:1 https://archive.ubuntu.com/ubuntu noble/main amd64 package amd64 1.0 [10 MB]\nCI dependency attempt exceeded 300s; no success was inferred.\n'
        with patch.object(deps,'execute',return_value=(124,text)) as execute:
            self.assertEqual(self.run_installer(),124)
            self.assertEqual(execute.call_count,2)
        self.assertIn('CI remains failed',self.log.read_text());self.assert_restored()

    def test_unsupported_or_symlink_mirror_is_not_replaced(self):
        os.environ['FAKE_CODES']='[1,0]'
        self.mirror.unlink();other=self.root/'other-mirror';other.write_bytes(self.original);self.mirror.symlink_to(other)
        self.assertEqual(self.run_installer(),1);self.assertEqual(len(self.rows()),1)
        self.assertTrue(self.mirror.is_symlink());self.assertEqual(other.read_bytes(),self.original)
        self.assertEqual(list((self.apt/'apt.conf.d').iterdir()),[])

    def test_non_ubuntu_keeps_configuration_untouched(self):
        self.os.write_text('ID=other\n');os.environ['FAKE_CODES']='[1,0]'
        self.assertEqual(self.run_installer(),1);self.assertEqual(len(self.rows()),1)
        self.assertEqual(self.rows()[0]['configs'],[]);self.assert_restored()

    def test_deadline_returns_failure_and_restores_without_hanging(self):
        os.environ['FAKE_SLEEP']='yes'
        self.assertEqual(self.run_installer(timeout=.1),124)
        self.assertIn('exceeded',self.log.read_text());self.assert_restored()

    def test_deadline_terminates_owned_child_group_before_cleanup(self):
        child_file=self.root/'child.pid';os.environ['FAKE_CHILD']=str(child_file)
        real_popen=deps.subprocess.Popen
        def child_ready_popen(command,*args,**kwargs):
            process=real_popen(command,*args,**kwargs)
            if command[0]!=str(self.cli):return process
            # The deadline tests cancellation of an existing child, not Python
            # startup speed on a busy runner. Synchronize only this actual
            # fixture; execute still owns the timeout and group termination.
            ready_deadline=time.monotonic()+10
            try:
                while True:
                    self.assertIsNone(process.poll(),'Fake installer exited before its child was ready.')
                    ready_pid=child_file.read_text() if child_file.exists() else ''
                    if ready_pid.isdigit():break
                    self.assertLess(time.monotonic(),ready_deadline,'Fake installer child was not ready within10seconds.')
                    time.sleep(.01)
                self.assertIsNone(process.poll(),'Fake installer must be alive when the timeout is exercised.')
            except BaseException:
                # A setup failure must not leave a real process group behind.
                if process.poll() is None:os.killpg(process.pid,signal.SIGKILL)
                process.communicate(timeout=5)
                raise
            return process
        with patch.object(deps.subprocess,'Popen',side_effect=child_ready_popen):
            self.assertEqual(self.run_installer(timeout=.2),124)
        pid=int(child_file.read_text())
        with self.assertRaises(ProcessLookupError):os.kill(pid,0)
        self.assert_restored()

    def test_unexpected_open_pipe_after_group_kill_cannot_hang_or_pass(self):
        process=Mock();process.pid=123456
        process.communicate.side_effect=[subprocess.TimeoutExpired('fake',1)]*3
        signals=[]
        with patch.object(deps.subprocess,'Popen',return_value=process):
            with self.assertRaises(RuntimeError):deps.execute([['fake']],1,signals.append)
        self.assertEqual(signals,[['kill','-TERM','--','-123456'],['kill','-KILL','--','-123456']])
        process.stdout.close.assert_called_once();process.wait.assert_called_once_with(timeout=5)

    def test_invalid_binary_or_arguments_create_failure_log_but_never_execute(self):
        for args in [['missing','chromium'],[str(self.cli),'chromium;echo'],[str(self.cli),'--skip-validation']]:
            with self.subTest(args=args):
                self.assertEqual(deps.install('playwright',args,self.log,apt_root=self.apt,os_release=self.os,root_command=self.local_root),2)
        self.assertFalse(self.calls.exists());self.assertTrue(self.log.is_file());self.assert_restored()

    def test_existing_configuration_is_not_overwritten(self):
        config=self.apt/'apt.conf.d'/f'99-orafold-playwright-{os.getpid()}.conf';config.write_text('existing')
        with self.assertRaises(RuntimeError):self.run_installer()
        self.assertEqual(config.read_text(),'existing');self.assertFalse(self.calls.exists());config.unlink();self.assert_restored()

    def test_restore_failure_cannot_be_reported_as_success(self):
        os.environ['FAKE_CODES']='[1,0]'
        def failed_restore(command):
            if command[:2]==['cp','-p'] and 'original-mirrors' in command[2]:raise OSError('test restore refused')
            self.local_root(command)
        with self.assertRaises(RuntimeError):
            deps.install('playwright',[str(self.cli),'chromium'],self.log,apt_root=self.apt,os_release=self.os,root_command=failed_restore)
        self.assertIn('cleanup failed',self.log.read_text())
        self.assertTrue(all(row['arguments'][0]=='install-deps' for row in self.rows()),'failed cleanup prevents browser download')
        self.assertEqual(list((self.apt/'apt.conf.d').iterdir()),[])

    def test_ffmpeg_mode_still_runs_real_apt_update_and_install(self):
        attempts=[]
        def fake_execute(commands,timeout,root_command):
            attempts.append(commands)
            return (100,'E: Failed to fetch Ubuntu package') if len(attempts)==1 else (0,'installed')
        with patch.object(deps,'execute',side_effect=fake_execute):
            self.assertEqual(deps.install('apt',['ffmpeg'],self.log,apt_root=self.apt,os_release=self.os,root_command=self.local_root),0)
        self.assertEqual(len(attempts),2)
        for commands in attempts:
            self.assertEqual(commands[0][-2:],['apt-get','update'])
            self.assertEqual(commands[1][-4:],['apt-get','install','-y','ffmpeg'])
        self.assert_restored()

    def test_github_actions_ffmpeg_uses_official_first_and_at_most_one_bounded_retry(self):
        os.environ['GITHUB_ACTIONS']='true'
        for statuses in ((0,),(100,0),(100,7,0)):
            with self.subTest(statuses=statuses):
                calls=[]
                def execute(commands,timeout,root_command):
                    calls.append((commands,timeout,self.mirror.read_text(),[p.read_text() for p in (self.apt/'apt.conf.d').iterdir()]))
                    status=statuses[len(calls)-1]
                    return status,'E: Failed to fetch Ubuntu package\n' if status else 'ffmpeg installed\n'
                with patch.object(deps,'execute',side_effect=execute):
                    self.assertEqual(deps.install('apt',['ffmpeg'],self.log,apt_root=self.apt,os_release=self.os,root_command=self.local_root),statuses[min(1,len(statuses)-1)])
                self.assertEqual(len(calls),min(2,len(statuses)))
                for commands,timeout,mirror,configs in calls:
                    self.assertEqual(commands[0][-2:],['apt-get','update'])
                    self.assertEqual(commands[1][-4:],['apt-get','install','-y','ffmpeg'])
                    self.assertEqual(timeout,300);self.assertEqual(mirror,deps.OFFICIAL_MIRRORS)
                    self.assertEqual(configs,[self.scoped_configuration])
                self.assert_restored()

    def test_real_ffmpeg_package_transfer_timeout_gets_the_same_one_official_fallback(self):
        # Main44202171157/audio job134458772680 timed out in apt install,
        # after apt update succeeded. APT mode must use the same narrow rule.
        text='Get:20 http://us-east-2.ec2.archive.ubuntu.com/ubuntu noble/universe amd64 libsvtav1enc1d1 amd64 1.7.0+dfsg-2build1 [2425 kB]\nCI dependency attempt exceeded 300s; no success was inferred.\n'
        calls=[]
        def execute(commands,timeout,root_command):
            calls.append((commands,timeout,self.mirror.read_text()))
            return (124,text) if len(calls)==1 else (0,'ffmpeg installed\n')
        with patch.object(deps,'execute',side_effect=execute):
            self.assertEqual(deps.install('apt',['ffmpeg'],self.log,apt_root=self.apt,os_release=self.os,root_command=self.local_root),0)
        self.assertEqual(len(calls),2)
        self.assertEqual(calls[0][0],calls[1][0])
        self.assertEqual([call[1] for call in calls],[300,300])
        self.assertEqual([call[2] for call in calls],[self.original.decode(),deps.OFFICIAL_MIRRORS])
        self.assert_restored()

    def test_actual_workflow_bootstrap_failure_is_not_hidden_by_tee(self):
        checked=[]
        for path in (ROOT/'.github/workflows').glob('*.yml'):
            workflow=yaml.load(path.read_text(),Loader=yaml.BaseLoader)
            for job_id,job in workflow['jobs'].items():
                for step in job.get('steps',[]):
                    script=step.get('run','')
                    if 'npm install ' not in script or 'install_dependencies.py' not in script:continue
                    # Execute the actual Bash flow, replacing only network/setup
                    # commands. A42 bootstrap failure must stop before the next
                    # step, even under GitHub's unspecified bash-e default.
                    script=re.sub(r'\$\{\{\s*matrix\.engine\s*\}\}','chromium',script)
                    script=re.sub(r'npm install [^\n]*?(?= 2>&1 \| tee)',"python3 -c 'import sys;sys.exit(42)'",script)
                    script=re.sub(r'^.*python3 tools/ci/install_dependencies\.py.*$', 'touch FAILED_BOOTSTRAP_WAS_IGNORED',script,flags=re.M)
                    folder=self.root/f'workflow-{len(checked)}';folder.mkdir()
                    outcome=subprocess.run(['bash','-e','-c',script],cwd=folder,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
                    with self.subTest(workflow=path.name):
                        self.assertEqual(outcome.returncode,42,outcome.stdout)
                        self.assertFalse((folder/'FAILED_BOOTSTRAP_WAS_IGNORED').exists())
                    checked.append((path.name,job_id))
        self.assertCountEqual(checked,[
            ('pages-release.yml','verify-public'),('alpha-qa.yml','browser'),
            ('campaign-orafold-qa.yml','isolated-campaign'),('alpha03-integration-qa.yml','integrated-modules'),
            ('web-preview.yml','browser'),('web-preview.yml','premium-browser'),
            ('web-preview.yml','production-art-browser'),('economy-qa.yml','economy'),('audio-qa.yml','audio')
        ],'all nine concrete browser installation flows, including the public release probe, stay covered')


if __name__=='__main__':unittest.main()
