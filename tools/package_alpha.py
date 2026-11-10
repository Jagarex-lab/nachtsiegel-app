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
archive=Path('work/alpha/orafold-alpha-0.3-'+commit[:12]+'.zip')
entries={p.name:p.read_bytes() for p in files}
entries['artifact-manifest.json']=manifest_path.read_bytes()
entries['serve_https.py']=Path('tools/serve_alpha_https.py').read_bytes()
entries['START.txt']=b'''ORAFOLD Alpha0.3 - prepared, not published
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
'''

with zipfile.ZipFile(archive,'w') as z:
 for name in sorted(entries):
  info=zipfile.ZipInfo(name,date_time=(1980,1,1,0,0,0));info.external_attr=0o100644<<16
  z.writestr(info,entries[name],compress_type=zipfile.ZIP_DEFLATED,compresslevel=6)
with zipfile.ZipFile(archive) as z:
 assert z.testzip() is None
 for name,digest in manifest['files'].items():assert hashlib.sha256(z.read(name)).hexdigest()==digest
print(json.dumps({'archive':str(archive),'bytes':archive.stat().st_size,'sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),'commit':commit},indent=2))
