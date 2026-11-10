#!/usr/bin/env python3
"""Offline illustration authoring gate. Never changes the active card catalog."""
from __future__ import annotations

import argparse
from collections import Counter
from datetime import date
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import sys
import unicodedata

ROOT = Path(__file__).resolve().parents[2]
AFFILIATIONS = ('Zwölf Häuser', 'Stillwacht', 'Vielgestalt', 'Neunte Stunde', 'Neutral')
COLORS = dict(zip(AFFILIATIONS, ('Kupfer', 'Eisblau', 'Jadegrün', 'Amethyst', 'Graphit/Stahl')))
BRIEF_FILES = ('houses.json', 'stillwatch.json', 'morph.json', 'ninth.json', 'neutral.json')
SCENE_FIELDS = ('subject', 'action', 'setting', 'composition', 'distinctive_detail')
STATES = ('missing', 'generated', 'reviewed', 'final')
COMMON_AVOID = ('Kein Text, keine Zahlen, keine Kartenrahmen oder UI.',
                'Keine Signatur, kein Wasserzeichen, keine fremden Marken.',
                'Keine Erklärung von Eiras Geheimnis oder der Zeitkorrektur.',
                'Keine ungewollten zusätzlichen Gliedmaßen oder verschmolzenen Gesichter.')


class ValidationError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise ValidationError(message)


def load_json(path):
    try:
        return json.loads(Path(path).read_text(encoding='utf-8'))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise ValidationError(f'{path}: ungültiges oder unlesbares JSON: {exc}') from exc


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def brief_sha256(brief):
    """Bind an asset to its complete brief independently of JSON key ordering."""
    canonical = json.dumps(brief, ensure_ascii=False, sort_keys=True, separators=(',', ':'))
    return hashlib.sha256(canonical.encode('utf-8')).hexdigest()


def normalized(value):
    return re.sub(r'\s+', ' ', unicodedata.normalize('NFKC', value).casefold()).strip()


def text_field(obj, key, minimum=2):
    value = obj.get(key)
    require(isinstance(value, str) and len(value.strip()) >= minimum,
            f'{obj.get("card_id", "Eintrag")}: {key} muss mindestens {minimum} Zeichen enthalten')
    require(not re.search(r'[\x00-\x08\x0b\x0c\x0e-\x1f]', value), f'{key}: Steuerzeichen unzulässig')
    return value


def validate_briefs(source, briefs):
    require(isinstance(source, list) and len(source) == 550, 'Quelle muss genau 550 Konzepte enthalten')
    require(all(isinstance(card, dict) for card in source), 'Konzept muss Objekt sein')
    require(all(isinstance(card.get('id'), str) for card in source), 'Konzept-ID fehlt')
    source_by_id = {card['id']: card for card in source}
    require(len(source_by_id) == 550, 'Doppelte Konzept-ID')
    require(all(isinstance(card.get('name'), str) and card['name'].strip()
                and isinstance(card.get('affiliation'), str) for card in source),
            'Konzeptname und Zugehörigkeit müssen Texte sein')
    require(Counter(card.get('affiliation') for card in source) == Counter({p:110 for p in AFFILIATIONS}),
            'Quelle benötigt genau 110 Konzepte pro Zugehörigkeit')
    require(isinstance(briefs, list) and len(briefs) == 550, 'Genau 550 Briefs erforderlich')
    ids, names, scenes = set(), set(), set()
    for brief in briefs:
        require(isinstance(brief, dict), 'Brief muss Objekt sein')
        card_id = brief.get('card_id')
        require(isinstance(card_id, str) and card_id in source_by_id, f'Unbekannte Konzept-ID: {card_id}')
        require(card_id not in ids, f'Doppelter Brief: {card_id}')
        ids.add(card_id)
        require(brief.get('source_name') == source_by_id[card_id].get('name'), f'{card_id}: source_name ist veraltet')
        require(brief.get('lore_status') == 'VORSCHLAG', f'{card_id}: Brief darf keinen Kanon behaupten')
        name = text_field(brief, 'proposed_name')
        key = normalized(name)
        require(key not in names, f'Doppelter vorgeschlagener Name: {name}')
        names.add(key)
        parts = [normalized(text_field(brief, field, 20)) for field in SCENE_FIELDS]
        # Removing names/IDs prevents a renamed copy from passing as another scene.
        scene = ' | '.join(parts)
        for token in (card_id, brief['source_name'], name):
            scene = scene.replace(normalized(token), '<name>')
        require(scene not in scenes, f'{card_id}: identisches Motiv trotz anderer ID/Name')
        scenes.add(scene)
        avoid = brief.get('avoid')
        require(isinstance(avoid, list) and all(isinstance(item, str) and item.strip() for item in avoid),
                f'{card_id}: avoid muss eine Liste nichtleerer Texte sein')
    require(ids == set(source_by_id), 'Briefs und Konzepte sind nicht bijektiv')
    return source_by_id


def read_briefs(directory):
    briefs = []
    for filename in BRIEF_FILES:
        entries = load_json(Path(directory) / filename)
        require(isinstance(entries, list) and len(entries) == 110,
                f'{filename}: Array mit genau 110 Briefs erforderlich')
        briefs.extend(entries)
    return briefs


def safe_asset(root, relative):
    require(isinstance(relative, str) and relative and '\\' not in relative,
            'asset_path benötigt relativen POSIX-Pfad')
    parts = relative.split('/')
    require(len(parts) >= 2 and parts[0] == 'assets' and all(p not in ('', '.', '..') for p in parts),
            'asset_path muss sicher innerhalb assets/ liegen')
    require(not PurePosixPath(relative).is_absolute() and not re.search(r'[\x00-\x1f:%?#]', relative),
            'Unsicherer asset_path')
    root = Path(root).resolve()
    asset = root.joinpath(*parts)
    # No symlinks, including in-root aliases: asset provenance follows one real file.
    current = root
    for part in parts:
        current = current / part
        require(not current.is_symlink(), f'Asset-Symlink unzulässig: {relative}')
    require(asset.resolve().is_relative_to(root / 'assets'), 'Asset verlässt assets/')
    require(asset.is_file(), f'Bilddatei fehlt: {relative}')
    require(asset.suffix.lower() in ('.png', '.jpg', '.jpeg', '.webp'), 'Nur PNG/JPEG/WebP in Produktionsinventar')
    require(0 < asset.stat().st_size <= 32 * 1024 * 1024, 'Bilddatei muss zwischen 1 Byte und 32 MiB liegen')
    return asset


def image_dimensions(path):
    try:
        from PIL import Image, UnidentifiedImageError
    except ImportError as exc:
        raise ValidationError('Bildprüfung benötigt Pillow; keine Bildprüfung oder Freigabe erfolgt') from exc
    try:
        with Image.open(path) as image:
            require(image.format in ('PNG', 'JPEG', 'WEBP'), f'Nicht unterstütztes Bildformat: {path}')
            expected_format = {'.png': 'PNG', '.jpg': 'JPEG', '.jpeg': 'JPEG', '.webp': 'WEBP'}.get(Path(path).suffix.lower())
            require(image.format == expected_format, f'Bildformat passt nicht zur Dateiendung: {path}')
            require(image.width <= 8192 and image.height <= 8192 and image.width * image.height <= 32000000,
                    'Bild überschreitet Produktionslimit von 8192 Pixeln je Achse oder 32 Megapixeln')
            image.verify()
        with Image.open(path) as image:
            image.load()  # Header-only checks are not evidence of a decodable image.
            require(not getattr(image, 'is_animated', False), 'Animierte Originaldatei unzulässig')
            return image.size
    except (OSError, ValueError, UnidentifiedImageError, Image.DecompressionBombError) as exc:
        raise ValidationError(f'Bild kann nicht vollständig dekodiert werden: {path}: {exc}') from exc


def validate_assets(root, manifest, source_by_id, source_hash, briefs_by_id):
    states = {card_id: 'missing' for card_id in source_by_id}
    if manifest is None:
        return states
    require(isinstance(manifest, dict) and manifest.get('schema_version') == 1, 'Manifest schema_version muss 1 sein')
    require(manifest.get('source_sha256') == source_hash, 'Manifest source_sha256 ist veraltet')
    entries = manifest.get('entries')
    require(isinstance(entries, list), 'Manifest entries muss Array sein')
    seen_ids, seen_hashes = set(), set()
    shared = Path(root) / 'assets/art/atlas.png'
    shared_hash = sha256(shared) if shared.is_file() else None
    for entry in entries:
        require(isinstance(entry, dict), 'Asset-Eintrag muss Objekt sein')
        card_id = entry.get('card_id')
        require(isinstance(card_id, str) and card_id in source_by_id, f'Unbekannte Asset-Konzept-ID: {card_id}')
        require(card_id not in seen_ids, f'Doppelte Asset-Karten-ID: {card_id}')
        seen_ids.add(card_id)
        status = entry.get('status')
        require(status in STATES, f'{card_id}: ungültiger Assetstatus')
        states[card_id] = status
        if status == 'missing':
            require(set(entry) == {'card_id', 'status'}, f'{card_id}: missing darf keine vorhandene Illustration behaupten')
            continue
        require(card_id in briefs_by_id, f'{card_id}: aktueller Bildbrief fehlt')
        require(entry.get('brief_sha256') == brief_sha256(briefs_by_id[card_id]),
                f'{card_id}: brief_sha256 fehlt oder ist veraltet; Bild-/Reviewzuordnung erneut prüfen')
        require(entry.get('asset_id') == 'orafold-' + card_id.lower(),
                f'{card_id}: asset_id muss orafold- plus kleingeschriebene Konzept-ID sein')
        text_field(entry, 'alternative_text')
        edits = entry.get('edits')
        require(isinstance(edits, list) and all(isinstance(edit, str) and edit.strip() for edit in edits),
                f'{card_id}: edits benötigt eine Liste dokumentierter Bearbeitungen (leer bei unverändertem Original)')
        asset = safe_asset(root, entry.get('asset_path'))
        digest = sha256(asset)
        require(entry.get('sha256') == digest, f'{card_id}: SHA256 stimmt nicht mit Bild überein')
        require(digest not in seen_hashes, f'{card_id}: identische Bilddatei für mehrere Karten')
        require(digest != shared_hash, f'{card_id}: gemeinsamer Konzeptatlas ist kein individuelles Original')
        seen_hashes.add(digest)
        width, height = image_dimensions(asset)
        require(type(entry.get('width')) is int and type(entry.get('height')) is int,
                f'{card_id}: width/height müssen Ganzzahlen sein')
        require((entry['width'], entry['height']) == (width, height), f'{card_id}: Bildmaße stimmen nicht')
        require(width >= 672 and height >= 500, f'{card_id}: Mindestauflösung 672 × 500 unterschritten')
        if status == 'final':
            require(width >= 1344 and height >= 1000,
                    f'{card_id}: final benötigt mindestens 1344 × 1000 echte dekodierte Pixel')
        provenance = entry.get('provenance')
        require(isinstance(provenance, dict), f'{card_id}: Herkunft fehlt')
        for field in ('creator_or_generator', 'created_on', 'source_or_prompt', 'commercial_usage_basis'):
            text_field(provenance, field)
        try:
            date.fromisoformat(provenance['created_on'])
        except ValueError as exc:
            raise ValidationError(f'{card_id}: created_on benötigt ISO-Datum') from exc
        refs = provenance.get('reference_sources')
        require(isinstance(refs, list) and all(isinstance(ref, str) and ref.strip() for ref in refs),
                f'{card_id}: reference_sources fehlt (leeres Array für keine Referenzen)')
        review = entry.get('review')
        require(isinstance(review, dict), f'{card_id}: Reviewstatus fehlt')
        for field in ('visual', 'lore', 'rights'):
            require(review.get(field) in ('pending', 'passed'), f'{card_id}: Review {field} ungültig')
        if status in ('reviewed', 'final'):
            require(review['visual'] == review['lore'] == 'passed', f'{card_id}: reviewed braucht Bild-/Loreprüfung')
            text_field(review, 'reviewer')
            text_field(review, 'note')
        if status == 'final':
            require(review['rights'] == 'passed', f'{card_id}: final braucht Rechteprüfung')
    return states


def build_prompts(source_by_id, briefs, source_hash):
    entries = []
    for brief in sorted(briefs, key=lambda item: item['card_id']):
        source = source_by_id[brief['card_id']]
        prompt = '\n'.join((
            f'ORAFOLD — eigenständige Kartenillustration: {brief["proposed_name"]}.',
            'Status: unverbindlicher Bild-/Namensvorschlag, keine neue Kanonentscheidung.',
            'Hochwertige malerische Science-Fantasy, präzise Materialien, starke Silhouette.',
            f'Kartentyp: {source.get("card_type")}; Arten: {", ".join(source.get("species", [])) or "keine"}.',
            f'Dominante Machtpalette: {COLORS[source["affiliation"]]}.',
            *(f'{field}: {brief[field]}' for field in SCENE_FIELDS),
            'Nur Illustration, keine vollständige Spielkarte. Bildfenster 672 × 500, Fokus in mittleren 70 %.',
            'Das Bild muss auch im kleinen Kartenformat klar erkennbar bleiben.',
            'Vermeiden: ' + ' '.join((*COMMON_AVOID, *brief['avoid'])),
        ))
        entries.append({'card_id': brief['card_id'], 'proposed_name': brief['proposed_name'],
                        'brief_sha256': brief_sha256(brief), 'lore_status': 'VORSCHLAG', 'prompt': prompt})
    return {'schema_version': 1, 'source_sha256': source_hash, 'purpose': 'illustration_proposals_only',
            'entry_count': len(entries), 'entries': entries}


def make_report(source_by_id, briefs, states, source_hash):
    counts = Counter(states.values())
    return {'schema_version': 1, 'source_sha256': source_hash, 'concept_count': len(source_by_id),
            'validated_brief_count': len(briefs), 'affiliations': dict(Counter(c['affiliation'] for c in source_by_id.values())),
            'asset_states': {state: counts[state] for state in STATES},
            'release_ready': counts['final'] == 550,
            'active_cards_changed': 0, 'gameplay_validated': False,
            'note': 'Briefs sind Vorschläge; Bildinventar ist weder Spieltest noch juristischer Rechtebeweis.'}


def write_output(value, destination, overwrite=False):
    text = json.dumps(value, ensure_ascii=False, indent=2) + '\n'
    if destination is None:
        print(text, end='')
        return
    path = Path(destination)
    # Exclusive creation prevents an implicit overwrite, including symlink aliases.
    require(not path.is_symlink(), 'Ausgabedatei darf kein Symlink sein')
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        with path.open('w' if overwrite else 'x', encoding='utf-8') as handle:
            handle.write(text)
    except OSError as exc:
        raise ValidationError(f'Ausgabe nicht geschrieben: {exc}; zum Ersetzen --overwrite angeben') from exc


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=('validate', 'prompts', 'report'))
    parser.add_argument('--root', type=Path, default=ROOT)
    parser.add_argument('--source', type=Path, default=None)
    parser.add_argument('--briefs', type=Path, default=None)
    parser.add_argument('--manifest', type=Path, default=None)
    parser.add_argument('--out', type=Path)
    parser.add_argument('--overwrite', action='store_true')
    parser.add_argument('--release-ready', action='store_true', help='fail unless every concept has final artwork')
    args = parser.parse_args(argv)
    try:
        source_path = args.source or args.root / 'data/lore/card-concepts.json'
        brief_dir = args.briefs or args.root / 'data/production/art-briefs'
        source, briefs = load_json(source_path), read_briefs(brief_dir)
        source_by_id = validate_briefs(source, briefs)
        source_hash = sha256(source_path)
        manifest_path = args.manifest or args.root / 'data/production/art-assets.json'
        # An explicitly supplied missing manifest is an error, not an empty inventory.
        manifest = load_json(manifest_path) if args.manifest or manifest_path.exists() else None
        states = validate_assets(args.root, manifest, source_by_id, source_hash,
                                 {brief['card_id']: brief for brief in briefs})
        report = make_report(source_by_id, briefs, states, source_hash)
        require(not args.release_ready or report['release_ready'],
                f'Release blockiert: {550 - report["asset_states"]["final"]} individuelle Illustrationen nicht final')
        result = build_prompts(source_by_id, briefs, source_hash) if args.command == 'prompts' else report
        write_output(result, args.out, args.overwrite)
        return 0
    except ValidationError as exc:
        print(f'ART PIPELINE: {exc}', file=sys.stderr)
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
