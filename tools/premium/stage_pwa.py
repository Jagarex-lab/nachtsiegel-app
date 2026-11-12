#!/usr/bin/env python3
"""Stage small, original ORAFOLD app branding and a safe online-first PWA.

Only generated Web output is changed; no export setting, release permission or
stored player data is touched. Uses Python's standard library exclusively.
"""
from __future__ import annotations
import argparse
import json
import math
from pathlib import Path
import re
import struct
import zlib

ROOT = Path(__file__).resolve().parents[2]

def icon_png(size: int) -> bytes:
    # Original geometric fold mark derived from the project's assets/icon.svg.
    # Opaque safe-zone art works with both ordinary and maskable app launchers.
    scale = 2
    side = size * scale
    pixels = bytearray(side * side * 3)
    def polygon(points, color):
        for y in range(max(0, int(min(p[1] for p in points))), min(side, int(max(p[1] for p in points))+1)):
            xs=[]
            for i, a in enumerate(points):
                b=points[(i+1)%len(points)]
                if (a[1] <= y+.5 < b[1]) or (b[1] <= y+.5 < a[1]):
                    xs.append(a[0]+(y+.5-a[1])*(b[0]-a[0])/(b[1]-a[1]))
            xs.sort()
            for k in range(0,len(xs)-1,2):
                for x in range(max(0,math.ceil(xs[k]-.5)), min(side,math.ceil(xs[k+1]-.5))):
                    at=(y*side+x)*3;pixels[at:at+3]=bytes(color)
    def pts(values): return [(x*side,y*side) for x,y in values]
    for y in range(side):
        for x in range(side):
            glow=max(0,1-math.hypot(x/side-.5,y/side-.43)*1.4)
            at=(y*side+x)*3;pixels[at:at+3]=bytes((int(8+glow*13),int(13+glow*22),int(24+glow*27)))
    polygon(pts([(.5,.13),(.82,.315),(.82,.685),(.5,.87),(.18,.685),(.18,.315)]),(185,130,74))
    polygon(pts([(.5,.155),(.798,.328),(.798,.672),(.5,.845),(.202,.672),(.202,.328)]),(13,24,37))
    polygon(pts([(.5,.235),(.635,.5),(.5,.765),(.365,.5)]),(224,205,167))
    polygon(pts([(.5,.27),(.606,.5),(.5,.73),(.394,.5)]),(109,171,181))
    polygon(pts([(.5,.27),(.5,.73),(.606,.5)]),(48,93,119))
    polygon(pts([(.287,.365),(.352,.5),(.287,.635),(.309,.5)]),(185,130,74))
    polygon(pts([(.713,.365),(.691,.5),(.713,.635),(.648,.5)]),(185,130,74))
    raw=bytearray()
    for y in range(size):
        raw.append(0)
        for x in range(size):
            for c in range(3):
                raw.append(sum(pixels[((y*2+dy)*side+x*2+dx)*3+c] for dy in range(2) for dx in range(2))//4)
    def chunk(kind,body):return struct.pack('>I',len(body))+kind+body+struct.pack('>I',zlib.crc32(kind+body)&0xffffffff)
    return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',size,size,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(raw,9))+chunk(b'IEND',b'')

def stage(destination: Path) -> dict:
    info=json.loads((destination/'build-info.json').read_text())
    commit=info.get('commit','')
    if not re.fullmatch('[0-9a-f]{40}',commit):raise ValueError('PWA requires the exact 40-character build commit.')
    html_path=destination/'index.html'
    html=html_path.read_text()
    marker='<!-- ORAFOLD_PWA_HEAD: generated for a complete Alpha export only. -->'
    if html.count(marker)!=1:raise ValueError('Expected exactly one reviewed PWA head marker.')
    worker=f'orafold-worker-{commit[:12]}.js'
    head=f'''<link rel="manifest" href="./manifest.webmanifest">
        <link rel="icon" type="image/png" sizes="192x192" href="./app-icon-192.png">
        <link rel="apple-touch-icon" sizes="180x180" href="./apple-touch-icon.png">
        <meta name="orafold-worker" content="./{worker}">'''
    html_path.write_text(html.replace(marker,head))
    manifest={'id':'./','name':'ORAFOLD','short_name':'ORAFOLD','description':'Fünf Pfade. Vier Mächte. Dein Deck.','lang':'de','start_url':'./','scope':'./','display':'standalone','background_color':'#0B111D','theme_color':'#0B111D','icons':[{'src':f'./app-icon-{size}.png','sizes':f'{size}x{size}','type':'image/png','purpose':'any maskable'} for size in (192,512)]}
    (destination/'manifest.webmanifest').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    for size,name in [(192,'app-icon-192.png'),(512,'app-icon-512.png'),(180,'apple-touch-icon.png')]:
        (destination/name).write_bytes(icon_png(size))
    (destination/worker).write_text((ROOT/'web/pwa/service-worker.js').read_text().replace('__COMMIT__',commit))
    info['pwa']={'display':'standalone','worker':worker,'offline_game':False,'cache':'branding-only','install_icons':[192,512,180]}
    (destination/'build-info.json').write_text(json.dumps(info,ensure_ascii=False,indent=2)+'\n')
    return info['pwa']

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('directory',type=Path)
    print(json.dumps(stage(parser.parse_args().directory),ensure_ascii=False))
