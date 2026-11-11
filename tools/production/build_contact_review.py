#!/usr/bin/env python3
"""Build review-only contact derivatives from exact collected PNGs; never edit sources."""
from __future__ import annotations
import hashlib, html, io, json, textwrap
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

PROJECT = Path(__file__).resolve().parents[2]
ROOT = PROJECT / 'work/production-art/contact-review'
STAGING = PROJECT
MANIFEST = PROJECT / 'data/production/art_sources.json'
CATALOG = PROJECT / 'data/production/cards.json'
POWERS = [('houses', 'Zwölf Häuser'), ('stillwatch', 'Stillwacht'), ('morph', 'Morph'), ('ninth', 'Neunte Stunde'), ('neutral', 'Neutral')]
FONT_PATH = Path('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf')
FONT_BOLD_PATH = Path('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf')
CELL_W, CELL_H, COLS, ROWS, HEADER = 248, 244, 5, 11, 76
THUMB_W, THUMB_H = 240, 180

def sha(b): return hashlib.sha256(b).hexdigest()
def write_json(path, data): path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
def wrap_pixels(text, font, width):
    lines, current = [], ''
    for word in text.split():
        candidate = current + (' ' if current else '') + word
        if current and font.getlength(candidate) > width: lines.append(current); current = word
        else: current = candidate
    if current: lines.append(current)
    return lines

def main():
    ROOT.mkdir(parents=True, exist_ok=True)
    manifest_bytes, catalog_bytes = MANIFEST.read_bytes(), CATALOG.read_bytes()
    sources, data = json.loads(manifest_bytes), json.loads(catalog_bytes)
    assert sha(catalog_bytes) == sources['source_catalog_sha256'], 'Frozen catalog/source mismatch'
    entries, cards = sources['entries'], {c['id']: c for c in data['cards']}
    assert len(entries) == len(cards) == 550 and set(entries) == set(cards)
    font = ImageFont.truetype(str(FONT_PATH), 14)
    small = ImageFont.truetype(str(FONT_PATH), 11)
    bold = ImageFont.truetype(str(FONT_BOLD_PATH), 14)
    title = ImageFont.truetype(str(FONT_BOLD_PATH), 24)
    pages, source_rows = [], []
    for power, caption in POWERS:
        ids = sorted(k for k in entries if cards[k]['faction'] == power)
        assert len(ids) == 110
        for part in range(2):
            page_ids = ids[part * 55:(part + 1) * 55]
            canvas = Image.new('RGB', (CELL_W * COLS, HEADER + CELL_H * ROWS), '#171b1d')
            draw = ImageDraw.Draw(canvas)
            draw.text((8, 8), f'{caption} · {part + 1}/2 · 55 Originale', fill='#e8e4d8', font=title)
            draw.text((8, 42), 'Kontaktprüfung 240 × 180 px · Originale unverändert · kommerzielle Freigabe offen', fill='#b9c2c2', font=font)
            for index, card_id in enumerate(page_ids):
                entry, card = entries[card_id], cards[card_id]
                source = STAGING / entry['asset_path'].removeprefix('res://')
                assert source == STAGING / 'assets/cards/originals' / (card_id + '.png')
                original = source.read_bytes()
                assert sha(original) == entry['sha256'], f'Source hash mismatch: {card_id}'
                with Image.open(io.BytesIO(original)) as image:
                    assert image.size == (entry['original_width'], entry['original_height'])
                    thumbnail = image.convert('RGB')
                    thumbnail.thumbnail((THUMB_W, THUMB_H), Image.Resampling.LANCZOS, reducing_gap=2.0)
                x, y = (index % COLS) * CELL_W, HEADER + (index // COLS) * CELL_H
                canvas.paste(thumbnail, (x + 4, y))
                draw.text((x + 4, y + 181), card_id, fill='#f3d595', font=bold)
                name_lines = wrap_pixels(entry['name'], font, THUMB_W)
                assert len(name_lines) <= 2
                for n, line in enumerate(name_lines): draw.text((x + 4, y + 199 + n * 16), line, fill='#e8e8e0', font=font)
                species = ', '.join(card.get('species', [])) or card['kind']
                draw.text((x + 4, y + 232), species, fill='#a3b1b0', font=small)
                source_rows.append({'id': card_id, 'name': entry['name'], 'power': power, 'kind': card['kind'], 'species': card.get('species', []), 'source_png': str(source), 'source_sha256': entry['sha256'], 'source_dimensions': [entry['original_width'], entry['original_height']], 'commercially_cleared': entry['commercially_cleared']})
            filename = f'{len(pages) + 1:02d}-{power}-{part + 1}.jpg'
            target = ROOT / filename
            canvas.save(target, 'JPEG', quality=94, subsampling=0, optimize=True)
            pages.append({'page': len(pages) + 1, 'file': filename, 'power': power, 'part': part + 1, 'ids': page_ids, 'dimensions': list(canvas.size), 'sha256': sha(target.read_bytes()), 'bytes': target.stat().st_size})
            print(filename, len(page_ids), flush=True)
    assert len(source_rows) == len({r['id'] for r in source_rows}) == 550
    assert MANIFEST.read_bytes() == manifest_bytes and CATALOG.read_bytes() == catalog_bytes, 'Inputs changed during contact generation'
    result = {'schema_version': 1, 'source_manifest': str(MANIFEST), 'source_manifest_sha256': sha(manifest_bytes), 'source_catalog': str(CATALOG), 'source_catalog_sha256': sha(catalog_bytes), 'builder_sha256': sha(Path(__file__).read_bytes()), 'font_sha256': sha(FONT_PATH.read_bytes()), 'font_bold_sha256': sha(FONT_BOLD_PATH.read_bytes()), 'source_count': 550, 'contact_page_count': 10, 'thumbnail_pixels': [240, 180], 'originals_edited': False, 'source_hashes_verified': 550, 'commercially_cleared_count': sum(r['commercially_cleared'] for r in source_rows), 'pages': pages, 'sources': source_rows}
    write_json(ROOT / 'gallery-manifest.json', result)
    body = ['<!doctype html><meta charset="utf-8"><title>ORAFOLD Kontaktprüfung</title><style>body{background:#171b1d;color:#ddd;font:16px system-ui;margin:24px}img{max-width:100%;height:auto}section{margin-bottom:60px}</style><h1>ORAFOLD · 550 Bilder · Kontaktprüfung</h1><p>Nur Prüfansichten; Originale bleiben unverändert. Kein zweiter 550-Bilder-Vollauflösungsreview und keine juristische Freigabe.</p>']
    for page in pages:
        body.append(f'<section><h2>{page["page"]}. {html.escape(page["power"])} {page["part"]}/2</h2><a href="{page["file"]}"><img src="{page["file"]}" alt="Kontaktseite {page["page"]}"></a><details><summary>55 Originale öffnen</summary><ul>')
        for card_id in page['ids']: body.append(f'<li><a href="../production-staging/assets/cards/originals/{card_id}.png">{html.escape(card_id)} · {html.escape(entries[card_id]["name"])}</a></li>')
        body.append('</ul></details></section>')
    (ROOT / 'index.html').write_text('\n'.join(body))
    print(json.dumps({'pages': 10, 'images': 550, 'derivative_bytes': sum(p['bytes'] for p in pages), 'manifest_sha256': sha((ROOT / 'gallery-manifest.json').read_bytes())}), flush=True)

if __name__ == '__main__': main()
