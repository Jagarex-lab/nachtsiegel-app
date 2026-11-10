#!/usr/bin/env python3
"""Wait for isolated HTTP fixtures; never retry application startup failures."""
import json,os,sys,time,urllib.request,urllib.error
if len(sys.argv)<2:raise SystemExit('Usage: wait_http.py BUILD_INFO_URL [...]')
expected=os.environ.get('EXPECTED_COMMIT')
for url in sys.argv[1:]:
 deadline=time.monotonic()+30
 while True:
  try:
   with urllib.request.urlopen(url,timeout=1) as response:data=json.load(response)
  except (urllib.error.URLError,TimeoutError,OSError) as error:
   if time.monotonic()>=deadline:raise SystemExit(f'Test server not ready: {url}: {error}')
   time.sleep(.1)
   continue
  if expected and data.get('commit')!=expected:raise SystemExit(f'Unexpected server commit at {url}: {data.get("commit")}')
  print('HTTP fixture ready:',url,data.get('commit'),flush=True)
  break
