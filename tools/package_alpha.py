#!/usr/bin/env python3
"""Package only the commit-addressed local build, never old exports or Pages."""
import hashlib,json,re,zipfile
from pathlib import Path
root=Path('work/alpha/web');meta=json.loads((root/'build-info.json').read_text())
commit=meta['commit'];assert re.fullmatch('[0-9a-f]{40}',commit)
prefix='orafold-'+commit[:12]
assert prefix in (root/'index.html').read_text()
files=[root/'index.html',root/'build-info.json',*sorted(root.glob(prefix+'.*'))]
assert any(p.suffix=='.wasm' for p in files) and any(p.suffix=='.pck' for p in files)
manifest={'source_commit':commit,'version':meta['version'],'status':'prepared-not-published','files':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in files}}
manifest_path=Path('work/alpha/artifact-manifest.json');manifest_path.write_text(json.dumps(manifest,indent=2)+'\n')
archive=Path('work/alpha/orafold-alpha-0.1-'+commit[:12]+'.zip')
with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for p in files:z.write(p,p.name)
 z.write(manifest_path,'artifact-manifest.json')
 z.writestr('START.txt','ORAFOLD Alpha0.1 - prepared, not published\nExtract this directory. Run: python3 -m http.server 8788 --bind 127.0.0.1\nOpen http://127.0.0.1:8788/ in your browser. Do not use file://.\nNo account, shop or online service. Data is local to the browser origin.\n')
with zipfile.ZipFile(archive) as z:
 assert z.testzip() is None
 for name,digest in manifest['files'].items():assert hashlib.sha256(z.read(name)).hexdigest()==digest
print(json.dumps({'archive':str(archive),'bytes':archive.stat().st_size,'sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),'commit':commit},indent=2))
