#!/usr/bin/env python3
"""Linux-only reproducible process-resource measurement; not a physical phone test."""
from pathlib import Path
import json,os,re,resource,subprocess,time
root=Path(__file__).resolve().parents[3]
work=root/'work/combat';work.mkdir(parents=True,exist_ok=True)
env=os.environ.copy()
for key,folder in [('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache')]:env[key]=str(root/'work/xdg'/folder)
source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()
start=time.monotonic()
result=subprocess.run(['godot','--path',str(root),'--audio-driver','Dummy','--script','tests/combat_presentation.gd'],cwd=root,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
usage=resource.getrusage(resource.RUSAGE_CHILDREN)
(work/'profile.log').write_text(result.stdout)
report={'source':source,'scope':'Linux Xvfb / Mesa llvmpipe; no simultaneous movie recording; not mobile hardware','elapsed_seconds':time.monotonic()-start,'cpu_user_seconds':usage.ru_utime,'cpu_system_seconds':usage.ru_stime,'peak_process_rss_bytes':usage.ru_maxrss*1024,'exit_code':result.returncode}
(work/'process-resources.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
assert result.returncode==0 and not re.search(r'SCRIPT ERROR|^ERROR:|^FAIL:',result.stdout,re.M),result.stdout
assert 'COMBAT PRESENTATION:' in result.stdout and '0 failures' in result.stdout
