#!/usr/bin/env python3
"""Provenance-compatible signal checks; no subjective/hardware listening claim."""
import array,math,wave,json
from pathlib import Path
rows=[]
for file in sorted(Path('assets/audio').glob('*.wav')):
 with wave.open(str(file),'rb') as wav:
  assert wav.getnchannels()==1 and wav.getsampwidth()==2 and wav.getframerate()==24000
  values=array.array('h',wav.readframes(wav.getnframes()))
  peak=max(abs(x) for x in values)/32768
  rms=math.sqrt(sum((x/32768)**2 for x in values)/len(values))
  assert .005<rms<.3 and peak<.3,(file,peak,rms)
  assert abs(values[0])<40 and abs(values[-1])<40,(file,'click boundary')
  rows.append({'name':file.name,'samples':len(values),'peak':peak,'rms':rms})
assert len(rows)==11
# Conservative coherent sum at all three bus gains = 100%; includes 0.12 bed bound.
sfx=max(x['peak'] for x in rows if x['name']!='ui.wav')
ui=next(x['peak'] for x in rows if x['name']=='ui.wav')
bound=8*sfx*10**(-10/20)+2*ui*10**(-8/20)+.12*10**(-6/20)
assert bound<1,bound
Path('work/combat').mkdir(exist_ok=True)
Path('work/combat/audio-signals.json').write_text(json.dumps({'signals':rows,'conservative_max_mix_bound':bound,'provenance':'tools/generate_audio.py; original deterministic synthesis, no sampled source'},indent=2))
print(f'AUDIO SIGNALS: 11 original cues, format/envelope/peak checks passed; conservative full-gain mix bound {bound:.3f}')
