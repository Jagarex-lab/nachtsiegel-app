#!/usr/bin/env python3
"""Keep native/export/web metadata in sync with the release identity, never a preview."""
import argparse,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def release_name(data):
    approved=data.get('approved_product_name')
    if approved is None:return data['legacy_product_name']
    if not isinstance(approved,str) or not approved.strip() or not isinstance(data.get('approval_reference'),str) or not data['approval_reference'].strip():
        raise ValueError('An approved product name requires a nonempty approval_reference; preview titles cannot be released.')
    return approved

def expected_files():
    d=json.loads((ROOT/'data/brand/identity.json').read_text());name=release_name(d)
    if name in d['preview'].values():raise ValueError('A working-title preview is not a release identity.')
    if any(c in name for c in '\n\r\t'):raise ValueError('Product names must be single-line labels.')
    out={}
    for file,replacements in {
        'project.godot':{'config/name':name,'config/description':name+' - '+d['description']},
        'export_presets.cfg':{'package/name':name,'package/unique_name':d['application_id']},
    }.items():
        p=ROOT/file;s=p.read_text()
        for key,value in replacements.items():
            s,n=re.subn(r'^'+re.escape(key)+r'=.*$',key+'='+json.dumps(value,ensure_ascii=False),s,flags=re.M)
            if n!=1:raise ValueError('Expected exactly one '+key+' in '+file)
        out[p]=s
    return out

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args()
    mismatches=[]
    for p,expected in expected_files().items():
        if p.read_text()!=expected:
            mismatches.append(str(p.relative_to(ROOT)))
            if not args.check:p.write_text(expected)
    if args.check and mismatches:raise SystemExit('Brand metadata out of sync: '+', '.join(mismatches))
    print('BRAND: release metadata synchronized; draft remains separate')
if __name__=='__main__':main()
