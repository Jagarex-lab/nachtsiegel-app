#!/usr/bin/env python3
"""Original mathematical synthesis, no recordings, samples or third-party assets.
Commercial use by the project owner follows LICENSE-NOTICE.md. Deterministic.
Run from repo root; ffmpeg encodes only our own generated atmosphere WAV.
"""
import math, random, struct, wave, subprocess
from pathlib import Path
RATE=24000
out=Path('assets/audio');out.mkdir(exist_ok=True)
def synth(name,duration,fn):
 rng=random.Random(2109+sum(map(ord,name)))
 with wave.open(str(out/(name+'.wav')),'wb') as wav:
  wav.setparams((1,2,RATE,0,'NONE','not compressed'))
  frames=[]
  for i in range(int(RATE*duration)):
   t=i/RATE;x=t/duration
   # Smooth raised-cosine attack and release prevent clicks in every cue.
   env=min(1,t/.012)*min(1,(duration-t)/.035)
   value=max(-.7,min(.7,fn(t,x,rng)))*env
   frames.append(struct.pack('<h',int(value*32767)))
  wav.writeframes(b''.join(frames))
S=math.sin;P=math.pi
synth('ui',.10,lambda t,x,r:.12*S(2*P*660*t)*math.exp(-x*6))
synth('draw',.24,lambda t,x,r:.18*r.uniform(-1,1)*S(P*x)**2)
synth('attack',.26,lambda t,x,r:.16*r.uniform(-1,1)*S(P*x)+.08*S(2*P*(180*t-120*t*t)))
synth('hit',.22,lambda t,x,r:(.19*S(2*P*76*t)+.14*r.uniform(-1,1))*math.exp(-x*8))
synth('ASH',.48,lambda t,x,r:(.16*r.uniform(-1,1)+.12*S(2*P*58*t))*math.exp(-x*4))
synth('TIDE',.5,lambda t,x,r:.12*S(2*P*(320*t+18*S(2*P*3*t))) * S(P*x)+.035*r.uniform(-1,1)*S(P*x))
synth('THORN',.40,lambda t,x,r:(.13*S(2*P*147*t)+.07*S(2*P*294*t)+.045*r.uniform(-1,1))*math.exp(-x*7))
synth('VEIL',.60,lambda t,x,r:.11*(S(2*P*220*t)+.5*S(2*P*331*t))*S(P*x)**2)
synth('turn',.4,lambda t,x,r:.11*(S(2*P*330*t)+.45*S(2*P*440*t))*S(P*x))
synth('win',.95,lambda t,x,r:.09*sum(S(2*P*f*t) for f in (220,277.1826,329.6276))*S(P*x))
synth('lose',.8,lambda t,x,r:.10*(S(2*P*146.8324*t)+S(2*P*155.5635*t))*S(P*x))
# Integer-cycle frequencies make the 12-second bed seamless and phase-continuous.
synth('atmosphere',12,lambda t,x,r:.027*sum(S(2*P*f*t) for f in (55,82.5,110,165))*(.8+.2*S(2*P*t/12)))
subprocess.run(['ffmpeg','-y','-loglevel','error','-i',str(out/'atmosphere.wav'),'-c:a','libvorbis','-q:a','3',str(out/'atmosphere.ogg')],check=True)
(out/'atmosphere.wav').unlink()
