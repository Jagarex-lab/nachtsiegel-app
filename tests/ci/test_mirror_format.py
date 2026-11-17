"""Real APT mirror parsing against loopback; no packages or system APT writes."""
import http.server
import importlib.util
import os
from pathlib import Path
import pwd
import shutil
import subprocess
import tempfile
import threading
import unittest

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('mirror_deps',ROOT/'tools/ci/install_dependencies.py')
deps=importlib.util.module_from_spec(spec);spec.loader.exec_module(deps)


class MirrorFormat(unittest.TestCase):
    def test_official_mirrors_use_required_tab_delimited_metadata(self):
        self.assertEqual(deps.OFFICIAL_MIRRORS.splitlines(),[
            'https://archive.ubuntu.com/ubuntu\tpriority:1',
            'https://security.ubuntu.com/ubuntu\tpriority:2'])

    def test_actual_apt_parser_requests_clean_uri_and_rejects_space_regression(self):
        # Linux CI requires APT. Missing APT is explicitly unsupported, never a
        # simulated success; other installer contracts remain platform-neutral.
        if not shutil.which('apt-get'):self.skipTest('Actual apt-get unavailable; mirror parser not tested.')
        requests=[]
        class Handler(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                requests.append(self.path);self.send_error(404)
            def log_message(self,*args):pass
        with tempfile.TemporaryDirectory(prefix='orafold-apt-parser-') as folder:
            root=Path(folder)
            for path in ['apt.conf.d','lists/partial','cache','sourceparts']:(root/path).mkdir(parents=True)
            server=http.server.ThreadingHTTPServer(('127.0.0.1',0),Handler)
            thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
            try:
                port=server.server_address[1]
                mirrors=root/'mirrors';sources=root/'sources.list';config=root/'isolated.conf'
                sources.write_text(f'deb mirror+file:{mirrors} test main\n')
                # APT reads only this temporary configuration/state/cache. The
                # loopback endpoint intentionally has no signed release: update
                # MUST fail100, while recorded requests prove URI parsing.
                config.write_text(f'Dir::Etc "{root}";\nDir::Etc::sourcelist "{sources}";\n'
                    f'Dir::Etc::sourceparts "{root}/sourceparts";\nDir::State::lists "{root}/lists";\n'
                    f'Dir::Cache "{root}/cache";\nAPT::Sandbox::User "{pwd.getpwuid(os.geteuid()).pw_name}";\n'
                    'Acquire::Retries "0";\nAcquire::http::Timeout "3";\n')
                actual=deps.OFFICIAL_MIRRORS.replace('https://archive.ubuntu.com/ubuntu',f'http://127.0.0.1:{port}/archive').replace('https://security.ubuntu.com/ubuntu',f'http://127.0.0.1:{port}/security')
                for content,valid in [(actual,True),(actual.replace('\t',' ').splitlines()[0]+'\n',False)]:
                    with self.subTest(valid_metadata=valid):
                        requests.clear();mirrors.write_text(content)
                        result=subprocess.run(['apt-get','update'],env={**os.environ,'APT_CONFIG':str(config)},
                            stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=15)
                        self.assertEqual(result.returncode,100,result.stdout)
                        clean=any(path in ('/archive/dists/test/InRelease','/security/dists/test/InRelease') for path in requests)
                        self.assertEqual(clean,valid,{'requests':requests,'output':result.stdout})
                        if valid:
                            self.assertTrue(requests)
                            self.assertTrue(all('priority' not in path and '%20' not in path for path in requests),requests)
                        else:self.assertIn('priority:1',result.stdout)
            finally:
                server.shutdown();server.server_close();thread.join(timeout=5)
                self.assertFalse(thread.is_alive(),'Owned loopback server terminates.')


if __name__=='__main__':unittest.main()
