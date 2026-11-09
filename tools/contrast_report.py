#!/usr/bin/env python3
"""WCAG ratios against actual rendered backgrounds, not nominal palette swatches.
Antialias fringe pixels are not treated as text ink: WCAG compares the intended
foreground colour against the background. Rotated region masks follow the exact
Godot canvas transform; backgrounds are captured with ink hidden, layout frozen.
"""
import argparse, json, functools, warnings
warnings.filterwarnings("ignore", category=DeprecationWarning)
from pathlib import Path
from PIL import Image, ImageDraw

@functools.lru_cache(maxsize=65536)
def luminance(rgb):
    c = [v/255 for v in rgb[:3]]
    c = [v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4 for v in c]
    return c[0]*.2126+c[1]*.7152+c[2]*.0722

def ratio(a,b):
    x,y=luminance(a),luminance(b)
    return (max(x,y)+.05)/(min(x,y)+.05)

def inspect(path):
    scene=json.loads(path.read_text())
    image=Image.open(path.with_name(path.stem+'-background.png')).convert('RGB')
    result=[]
    for sample in scene['samples']:
        points=[tuple(p) for p in sample['polygon']]
        # Pixel centres must be inside the transformed region, not its AABB.
        mask=Image.new('1',image.size)
        ImageDraw.Draw(mask).polygon(points,fill=1)
        box=mask.getbbox()
        if not box:
            result.append({**sample,'ratio':0,'error':'off screen'})
            continue
        colors=image.crop(box).getdata(); bits=mask.crop(box).getdata()
        ink=tuple(bytes.fromhex(sample['color']))
        worst=100
        count=0
        for pixel,inside in zip(colors,bits):
            if inside:
                worst=min(worst,ratio(ink,pixel));count+=1
        result.append({'role':sample['role'],'threshold':sample['threshold'],'ratio':round(worst,3),'pixels':count})
    return {'state':scene['tag'],'samples':result}

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--directory',default='work/ux')
    parser.add_argument('--output',default='work/ux/contrast-report.json')
    args=parser.parse_args()
    cases=[]
    for file in sorted(Path(args.directory).glob('*.json')):
        if file.with_name(file.stem+'-background.png').exists():cases.append(inspect(file))
    if not cases:raise SystemExit('No paired rendered contrast states found')
    failed=[{'state':c['state'],**s} for c in cases for s in c['samples'] if s['ratio']<s['threshold']]
    report={'method':'WCAG sRGB; intended ink versus every rendered background pixel within transformed region','cases':cases,'failures':failed}
    Path(args.output).write_text(json.dumps(report,indent=2))
    for sample in failed[:40]:print('CONTRAST FAIL:',sample)
    print(f'CONTRAST: {len(cases)} rendered states, {sum(len(c["samples"]) for c in cases)} regions, {len(failed)} failures')
    raise SystemExit(bool(failed))
if __name__=='__main__':main()
