import importlib.util
import json
from pathlib import Path
import struct
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('stage_pwa',ROOT/'tools/premium/stage_pwa.py')
stage=importlib.util.module_from_spec(spec);spec.loader.exec_module(stage)

class PWAStageTests(unittest.TestCase):
 def test_commit_addressed_manifest_icons_and_bounded_worker(self):
  with tempfile.TemporaryDirectory() as name:
   dest=Path(name);commit='1'*40
   (dest/'index.html').write_text((ROOT/'web/shell.html').read_text())
   (dest/'build-info.json').write_text(json.dumps({'commit':commit}))
   result=stage.stage(dest)
   manifest=json.loads((dest/'manifest.webmanifest').read_text())
   self.assertEqual(manifest['display'],'standalone')
   self.assertEqual(manifest['scope'],'./');self.assertEqual(manifest['start_url'],'./')
   self.assertNotIn('orientation',manifest)
   for size,filename in [(192,'app-icon-192.png'),(512,'app-icon-512.png'),(180,'apple-touch-icon.png')]:
    data=(dest/filename).read_bytes();self.assertEqual(data[:8],b'\x89PNG\r\n\x1a\n')
    self.assertEqual(struct.unpack('>II',data[16:24]),(size,size));self.assertLess(len(data),100000)
   html=(dest/'index.html').read_text();self.assertIn('rel="apple-touch-icon"',html);self.assertIn('rel="manifest"',html)
   worker=(dest/result['worker']).read_text();self.assertIn(commit,worker);self.assertNotIn('__COMMIT__',worker)
   self.assertNotIn('caches.match(event.request)',worker)
   self.assertNotIn('.wasm',worker.split("const BRAND = ")[1].split(';')[0])
   self.assertFalse(result['offline_game'])
   self.assertEqual(json.loads((dest/'build-info.json').read_text())['commit'],commit)
 def test_unknown_commit_cannot_stage(self):
  with tempfile.TemporaryDirectory() as name:
   dest=Path(name);(dest/'build-info.json').write_text('{"commit":"latest"}')
   with self.assertRaises(ValueError):stage.stage(dest)
   self.assertFalse((dest/'manifest.webmanifest').exists())
 def test_icons_are_reproducible(self):
  self.assertEqual(stage.icon_png(32),stage.icon_png(32))

if __name__=='__main__':unittest.main()
