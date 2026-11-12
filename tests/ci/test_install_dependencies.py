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
        self.os=self.root/'os-release';self.os.write_text('ID=ubuntu\nVERSION_CODENAME=noble\n')
        self.cli=self.root/'playwright';self.calls=self.root/'calls.jsonl';self.log=self.root/'install.log'
        self.cli.write_text("""#!/usr/bin/env python3
import json,os,pathlib,sys,time,subprocess,signal
root=pathlib.Path(os.environ['FAKE_APT_ROOT']);calls=pathlib.Path(os.environ['FAKE_CALLS'])
rows=calls.read_text().splitlines() if calls.exists() else []
entry={'arguments':sys.argv[1:],'mirror':(root/'apt-mirrors.txt').read_text() if (root/'apt-mirrors.txt').exists() else None,'configs':[p.read_text() for p in (root/'apt.conf.d').glob('*')]}
with calls.open('a') as output:output.write(json.dumps(entry)+'\\n')
codes=json.loads(os.environ.get('FAKE_CODES','[0]'));status=codes[min(len(rows),len(codes)-1)]
if os.environ.get('FAKE_SLEEP'):print('fake installer waiting',flush=True);time.sleep(3)
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
        self.environment=patch.dict(os.environ,{'FAKE_APT_ROOT':str(self.apt),'FAKE_CALLS':str(self.calls),'FAKE_CODES':'[0]','FAKE_ERROR':'Error: Installation process exited with code:100'},clear=False)
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

    def test_success_uses_original_mirrors_once_and_keeps_required_dependencies(self):
        self.assertEqual(self.run_installer(),0);rows=self.rows();self.assertEqual(len(rows),1)
        self.assertEqual(rows[0]['mirror'],self.original.decode())
        self.assertEqual(rows[0]['arguments'],['install','--with-deps','chromium','webkit'])
        self.assertEqual(rows[0]['configs'],[deps.APT_LIMITS])
        self.assert_restored()

    def test_existing_npm_bootstrap_diagnostics_are_preserved(self):
        self.log.write_text('npm bootstrap diagnostic\n')
        self.assertEqual(self.run_installer(),0)
        self.assertTrue(self.log.read_text().startswith('npm bootstrap diagnostic\n'))
        self.assert_restored()

    def test_actual_dependency_failure_gets_one_official_fallback_and_restores(self):
        os.environ['FAKE_CODES']='[1,0]'
        self.assertEqual(self.run_installer(),0);rows=self.rows();self.assertEqual(len(rows),2)
        self.assertEqual(rows[0]['mirror'],self.original.decode());self.assertEqual(rows[1]['mirror'],deps.OFFICIAL_MIRRORS)
        self.assertTrue(all(row['arguments']==['install','--with-deps','chromium','webkit'] for row in rows))
        self.assert_restored()

    def test_persistent_failure_stays_failed_without_third_attempt(self):
        os.environ['FAKE_CODES']='[1,7]'
        self.assertEqual(self.run_installer(),7);self.assertEqual(len(self.rows()),2)
        self.assertIn('CI remains failed',self.log.read_text());self.assert_restored()

    def test_browser_cdn_error_does_not_rewrite_dependency_mirrors(self):
        os.environ.update(FAKE_CODES='[1,0]',FAKE_ERROR='Failed to download Chromium: CDN returned503')
        self.assertEqual(self.run_installer(),1);self.assertEqual(len(self.rows()),1)
        self.assert_restored()

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

    def test_actual_workflow_bootstrap_failure_is_not_hidden_by_tee(self):
        checked=0
        for path in (ROOT/'.github/workflows').glob('*.yml'):
            workflow=yaml.load(path.read_text(),Loader=yaml.BaseLoader)
            for job in workflow['jobs'].values():
                for step in job.get('steps',[]):
                    script=step.get('run','')
                    if 'npm install ' not in script or 'install_dependencies.py' not in script:continue
                    # Execute the actual Bash flow, replacing only network/setup
                    # commands. A42 bootstrap failure must stop before the next
                    # step, even under GitHub's unspecified bash-e default.
                    script=re.sub(r'\$\{\{\s*matrix\.engine\s*\}\}','chromium',script)
                    script=re.sub(r'npm install [^\n]*?(?= 2>&1 \| tee)',"python3 -c 'import sys;sys.exit(42)'",script)
                    script=re.sub(r'^.*python3 tools/ci/install_dependencies\.py.*$', 'touch FAILED_BOOTSTRAP_WAS_IGNORED',script,flags=re.M)
                    folder=self.root/f'workflow-{checked}';folder.mkdir()
                    outcome=subprocess.run(['bash','-e','-c',script],cwd=folder,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
                    with self.subTest(workflow=path.name):
                        self.assertEqual(outcome.returncode,42,outcome.stdout)
                        self.assertFalse((folder/'FAILED_BOOTSTRAP_WAS_IGNORED').exists())
                    checked+=1
        self.assertEqual(checked,8,'all eight existing browser installation flows stay covered')


if __name__=='__main__':unittest.main()
