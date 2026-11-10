#!/usr/bin/env python3
"""Decode and validate ORAFOLD's checked-in audio pack, without Godot imports.

Requires Python 3, numpy and ffmpeg. This is an objective signal/manifest check;
it does not replace listening on headphones, speakers and target devices.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
REQUIRED_EVENTS = {
    'card.draw','card.hover','card.select','card.play','card.return','card.discard',
    'creature.summon','creature.attack','creature.hit','creature.defeated',
    'shield.gain','shield.absorb','block.activate','resonance.gain',
    'resonance.spend','resonance.high','relic.activate','relic.destroy',
    'convergence.prepare','convergence.complete','convergence.interrupt',
    'battle.victory','battle.defeat',
}
FACTIONS = {'zwoelf_haeuser','stillwacht','vielgestalt','neunte_stunde'}


def validate(root: Path = ROOT) -> dict:
    start = time.perf_counter()
    catalog = json.loads((root/'data/audio/audio_catalog.json').read_text())
    event_manifest = json.loads((root/'data/audio/audio_events.json').read_text())
    provenance_manifest = json.loads((root/'data/audio/asset_manifest.json').read_text())
    provenance = {asset['id']: asset for asset in provenance_manifest.get('assets', [])}
    errors: list[str] = []
    assertions = 0
    def check(ok: bool, label: str):
        nonlocal assertions
        assertions += 1
        if not ok:
            errors.append(label)
    check(catalog.get('version') == 1, 'catalog version')
    check(event_manifest.get('version') == 1, 'event version')
    clips = catalog.get('clips', {})
    events = event_manifest.get('events', {})
    check(bool(clips), 'nonempty clip catalog')
    check(set(provenance) == set(clips), 'every clip has exactly one provenance record')
    check(REQUIRED_EVENTS <= events.keys(), f'required events missing: {sorted(REQUIRED_EVENTS-events.keys())}')
    check(len(catalog.get('music', {})) >= 9, 'nine music contexts')
    check(len(events.get('card.draw', {}).get('variants', [])) >= 3, 'three draw variants')
    for name, event in events.items():
        variants = event.get('variants', [])
        check(isinstance(variants, list) and bool(variants), f'{name}: variants present')
        ids = list(variants)
        for layer in ('faction_layers', 'rarity_layers'):
            for value in event.get(layer, {}).values():
                ids.extend(value if isinstance(value, list) else [value])
        for clip in ids:
            check(clip in clips, f'{name}: missing reference {clip}')
        check(event.get('bus') in ('SFX', 'UI', 'Ambience'), f'{name}: event bus')
        check(0 <= event.get('cooldown_ms', 0) <= 30000, f'{name}: bounded cooldown')
        check(1 <= event.get('max_voices', 1) <= 16, f'{name}: bounded voices')
        check(0.5 <= event.get('pitch_min', 1) <= event.get('pitch_max', 1) <= 2, f'{name}: pitch range')
        if event.get('faction_layers'):
            check(set(event['faction_layers']) == FACTIONS, f'{name}: four faction identities')
    for context, clip in catalog.get('music', {}).items():
        check(clip in clips, f'music {context}: clip exists')
        check(clips.get(clip, {}).get('bus') == 'Music', f'music {context}: correct bus')
    rows = []
    unique_paths: set[Path] = set()
    pcm_total = 0
    for clip_id, clip in clips.items():
        path_string = clip.get('path', '')
        check(path_string.startswith('res://assets/audio/'), f'{clip_id}: audio-local path')
        file = root/path_string.removeprefix('res://')
        check(file.is_file(), f'{clip_id}: file exists {file}')
        if not file.is_file():
            continue
        check(file.resolve().is_relative_to((root/'assets/audio').resolve()), f'{clip_id}: no traversal')
        check(file.suffix in ('.wav', '.ogg'), f'{clip_id}: supported format')
        check(clip.get('bus') in ('SFX', 'UI', 'Ambience', 'Music'), f'{clip_id}: valid bus')
        check(-60 <= clip.get('gain_db', 0) <= 0, f'{clip_id}: safe gain')
        record = provenance.get(clip_id, {})
        check(record.get('path') == path_string.removeprefix('res://'), f'{clip_id}: provenance path')
        check(record.get('sha256') == hashlib.sha256(file.read_bytes()).hexdigest(), f'{clip_id}: provenance content hash')
        check(bool(record.get('license')) and bool(record.get('provenance')), f'{clip_id}: recorded rights and origin')
        if file in unique_paths:
            continue
        unique_paths.add(file)
        probe = subprocess.run(['ffprobe','-v','error','-show_entries','stream=sample_rate,channels','-show_entries','format=duration','-of','json',str(file)], check=True,capture_output=True)
        metadata = json.loads(probe.stdout)
        sample_rate = int(metadata['streams'][0]['sample_rate'])
        channels = int(metadata['streams'][0]['channels'])
        duration = float(metadata['format']['duration'])
        decoded = subprocess.run(['ffmpeg','-v','error','-i',str(file),'-f','f32le','-acodec','pcm_f32le','-'], check=True,capture_output=True)
        frames = np.frombuffer(decoded.stdout, dtype='<f4').reshape(-1, channels)
        peak = float(np.abs(frames).max())
        rms = float(np.sqrt(np.mean(frames*frames)))
        edge = max(float(np.abs(frames[0]).max()),float(np.abs(frames[-1]).max()))
        seam = float(np.abs(frames[0]-frames[-1]).max())
        check(np.isfinite(frames).all(), f'{clip_id}: finite PCM')
        check(0.001 < peak <= 0.90, f'{clip_id}: non-silent controlled peak {peak:.5f}')
        check(float(np.mean(np.abs(frames)>=0.999)) == 0, f'{clip_id}: zero clipped samples')
        if not clip.get('loop', False):
            check(edge <= 0.02, f'{clip_id}: click-safe one-shot edges {edge:.5f}')
        check(16000 <= sample_rate <= 48000, f'{clip_id}: platform rate')
        check(channels in (1,2), f'{clip_id}: mono/stereo')
        check(0.03 <= duration <= 180, f'{clip_id}: practical duration {duration}')
        if clip.get('loop', False):
            check(seam <= 0.02, f'{clip_id}: loop seam {seam:.5f}')
        if clip.get('bus') == 'Music':
            check(file.suffix == '.ogg', f'{clip_id}: compressed music')
            check(duration >= (2 if not clip.get('loop') else 12), f'{clip_id}: real music duration')
        else:
            pcm_total += frames.nbytes
        rows.append({'id':clip_id,'path':path_string,'bytes':file.stat().st_size,'seconds':round(duration,4),'channels':channels,'sample_rate':sample_rate,'peak':round(peak,6),'rms':round(rms,6),'edge_peak':round(edge,6),'loop_seam':round(seam,6),'sha256':hashlib.sha256(file.read_bytes()).hexdigest()})
    total_bytes = sum(r['bytes'] for r in rows)
    check(total_bytes <= 24*1024*1024, 'compressed pack <=24 MiB')
    check(pcm_total <= 48*1024*1024, 'non-music float PCM <=48 MiB')
    return {'assertions':assertions,'failures':len(errors),'errors':errors,'clip_ids':len(clips),'files':len(unique_paths),'events':len(events),'music_contexts':len(catalog.get('music',{})),'encoded_bytes':total_bytes,'non_music_float_pcm_bytes':pcm_total,'validation_seconds':round(time.perf_counter()-start,3),'assets':rows}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    result = validate()
    if args.report:
        args.report.parent.mkdir(parents=True,exist_ok=True)
        args.report.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k != 'assets'},indent=2))
    sys.exit(bool(result['failures']))
