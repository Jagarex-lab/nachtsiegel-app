"""Adversarial tests for offline art production; no engine or active assets touched."""
import copy
from datetime import date
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from PIL import Image  # Required: a header-only substitute would weaken these tests.

MODULE = Path(__file__).resolve().parents[2] / 'tools/production/art_pipeline.py'
SPEC = importlib.util.spec_from_file_location('art_pipeline', MODULE)
pipeline = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(pipeline)


def fixtures():
    source, briefs = [], []
    for power_index, affiliation in enumerate(pipeline.AFFILIATIONS):
        for index in range(110):
            identifier = f'fixture-{power_index}-{index:03}'
            name = f'Quellenname {power_index} {index}'
            source.append({'id': identifier, 'name': name, 'affiliation': affiliation,
                           'card_type': 'Wesen', 'species': ['Menschen']})
            briefs.append({'card_id': identifier, 'source_name': name,
                           'proposed_name': f'Vorschlag {power_index} {index}', 'lore_status': 'VORSCHLAG',
                           'subject': f'Eine Handwerkerin trägt Werkzeug im Detail {index} und Bereich {power_index}.',
                           'action': f'Sie repariert ein sichtbar anderes Scharnier im Bereich {power_index}-{index}.',
                           'setting': 'Eine enge Werkstatt an einem offenen Wasserkanal.',
                           'composition': 'Nahansicht der Hände vor unscharfem Werkstatthintergrund.',
                           'distinctive_detail': f'Der Werkzeuggriff zeigt eine einzigartige Einlage {power_index}-{index}.',
                           'avoid': []})
    return source, briefs


class ArtPipelineTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.source, self.briefs = fixtures()
        self.source_map = pipeline.validate_briefs(self.source, self.briefs)
        self.source_path = self.root / 'source.json'
        self.source_path.write_text(json.dumps(self.source), encoding='utf-8')
        self.source_hash = pipeline.sha256(self.source_path)
        self.briefs_by_id = {brief["card_id"]: brief for brief in self.briefs}

    def tearDown(self):
        self.tmp.cleanup()

    def asset(self, index=0, color=(12, 100, 150), status='generated', size=(700, 500)):
        path = self.root / f'assets/production/illustrations/{index}.png'
        path.parent.mkdir(parents=True, exist_ok=True)
        Image.new('RGB', size, color).save(path)
        return {'card_id': self.source[index]['id'], 'status': status,
                'asset_id': 'orafold-' + self.source[index]['id'].lower(),
                'alternative_text': 'Eine einfarbige synthetische Testfläche ohne Produktionsmotiv.', 'edits': [],
                'asset_path': path.relative_to(self.root).as_posix(), 'sha256': pipeline.sha256(path),
                'width': size[0], 'height': size[1], 'brief_sha256': pipeline.brief_sha256(self.briefs[index]),
                'provenance': {'creator_or_generator': 'Test fixture generator',
                               'created_on': date.today().isoformat(),
                               'source_or_prompt': 'Solid test fixture only; not production artwork.',
                               'reference_sources': [], 'commercial_usage_basis': 'Test fixture, no production approval.'},
                'review': {'visual': 'pending', 'lore': 'pending', 'rights': 'pending'}}

    def manifest(self, *entries):
        return {'schema_version': 1, 'source_sha256': self.source_hash, 'entries': list(entries)}

    def test_all_550_briefs_and_prompts_are_deterministic(self):
        prompts = pipeline.build_prompts(self.source_map, self.briefs, self.source_hash)
        self.assertEqual(550, prompts['entry_count'])
        self.assertEqual(prompts, pipeline.build_prompts(self.source_map, list(reversed(self.briefs)), self.source_hash))
        self.assertIn('keine neue Kanonentscheidung', prompts['entries'][0]['prompt'])
        self.assertIn('Kein Text', prompts['entries'][0]['prompt'])
        self.assertEqual(self.source_hash, prompts['source_sha256'])
        first = self.briefs_by_id[prompts['entries'][0]['card_id']]
        self.assertEqual(pipeline.brief_sha256(first), prompts['entries'][0]['brief_sha256'])

    def test_brief_digest_is_canonical_and_binds_unicode_and_complete_brief(self):
        brief = self.briefs[0]
        self.assertEqual(pipeline.brief_sha256(brief), pipeline.brief_sha256(dict(reversed(list(brief.items())))))
        canonical = json.dumps(brief, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode('utf-8')
        import hashlib
        self.assertEqual(hashlib.sha256(canonical).hexdigest(), pipeline.brief_sha256(brief))
        changed = copy.deepcopy(brief)
        changed['avoid'].append('Keine andere Anordnung der Werkzeuge.')
        self.assertNotEqual(pipeline.brief_sha256(brief), pipeline.brief_sha256(changed))

    def test_missing_brief_digest_rejects_existing_art(self):
        entry = self.asset()
        del entry['brief_sha256']
        with self.assertRaisesRegex(pipeline.ValidationError, 'brief_sha256 fehlt oder ist veraltet'):
            pipeline.validate_assets(self.root, self.manifest(entry), self.source_map, self.source_hash, self.briefs_by_id)

    def test_changed_scene_or_proposed_name_invalidates_all_existing_art_states(self):
        for status in ('generated', 'reviewed', 'final'):
            for field in ('subject', 'proposed_name'):
                with self.subTest(status=status, field=field):
                    entry = self.asset(status=status)
                    entry['review'].update(visual='passed', lore='passed', rights='passed',
                                           reviewer='Fixture reviewer', note='Test review only.')
                    briefs = copy.deepcopy(self.briefs_by_id)
                    briefs[entry['card_id']][field] += ' — geänderte redaktionelle Fassung'
                    with self.assertRaisesRegex(pipeline.ValidationError, 'brief_sha256 fehlt oder ist veraltet'):
                        pipeline.validate_assets(self.root, self.manifest(entry), self.source_map, self.source_hash, briefs)

    def test_duplicate_ids_source_names_and_proposals_are_rejected(self):
        for key, replacement, expected in (
            ('card_id', self.briefs[0]['card_id'], 'Doppelter Brief'),
            ('source_name', 'veralteter Name', 'source_name'),
            ('proposed_name', self.briefs[0]['proposed_name'], 'Doppelter vorgeschlagener Name')):
            with self.subTest(key=key):
                bad = copy.deepcopy(self.briefs)
                bad[1][key] = replacement
                with self.assertRaisesRegex(pipeline.ValidationError, expected):
                    pipeline.validate_briefs(self.source, bad)

    def test_renamed_identical_scenes_are_rejected(self):
        bad = copy.deepcopy(self.briefs)
        for field in pipeline.SCENE_FIELDS:
            bad[1][field] = bad[0][field]
        with self.assertRaisesRegex(pipeline.ValidationError, 'identisches Motiv'):
            pipeline.validate_briefs(self.source, bad)

    def test_counts_and_canon_and_empty_fields_fail(self):
        for change in ('count', 'affiliation', 'canon', 'empty', 'avoid'):
            source, briefs = copy.deepcopy(self.source), copy.deepcopy(self.briefs)
            if change == 'count':
                briefs.pop()
            elif change == 'affiliation':
                source[0]['affiliation'] = 'Fünfte Macht'
            elif change == 'canon':
                briefs[0]['lore_status'] = 'KANON'
            elif change == 'empty':
                briefs[0]['subject'] = 'Platzhalter'
            else:
                briefs[0]['avoid'] = None
            with self.subTest(change=change), self.assertRaises(pipeline.ValidationError):
                pipeline.validate_briefs(source, briefs)

    def test_partial_inventory_counts_missing_honestly(self):
        entry = self.asset()
        states = pipeline.validate_assets(self.root, self.manifest(entry), self.source_map, self.source_hash, self.briefs_by_id)
        report = pipeline.make_report(self.source_map, self.briefs, states, self.source_hash)
        self.assertEqual({'missing': 549, 'generated': 1, 'reviewed': 0, 'final': 0}, report['asset_states'])
        self.assertFalse(report['release_ready'])
        self.assertFalse(report['gameplay_validated'])

    def test_stale_manifest_hash_and_missing_provenance_fail(self):
        manifest = self.manifest()
        manifest['source_sha256'] = '0' * 64
        with self.assertRaisesRegex(pipeline.ValidationError, 'veraltet'):
            pipeline.validate_assets(self.root, manifest, self.source_map, self.source_hash, self.briefs_by_id)
        entry = self.asset()
        del entry['provenance']['commercial_usage_basis']
        with self.assertRaisesRegex(pipeline.ValidationError, 'commercial_usage_basis'):
            pipeline.validate_assets(self.root, self.manifest(entry), self.source_map, self.source_hash, self.briefs_by_id)

    def test_duplicate_image_content_and_duplicate_card_fail(self):
        first, second = self.asset(0), self.asset(1)
        with self.assertRaisesRegex(pipeline.ValidationError, 'identische Bilddatei'):
            pipeline.validate_assets(self.root, self.manifest(first, second), self.source_map, self.source_hash, self.briefs_by_id)
        with self.assertRaisesRegex(pipeline.ValidationError, 'Doppelte Asset'):
            pipeline.validate_assets(self.root, self.manifest(first, first), self.source_map, self.source_hash, self.briefs_by_id)

    def test_traversal_absolute_paths_and_symlink_aliases_fail(self):
        entry = self.asset()
        for unsafe in ('assets/../0.png', '/tmp/0.png', 'assets//0.png', 'assets\\0.png', 'assets/%2e%2e/0.png'):
            entry['asset_path'] = unsafe
            with self.subTest(path=unsafe), self.assertRaises(pipeline.ValidationError):
                pipeline.validate_assets(self.root, self.manifest(entry), self.source_map, self.source_hash, self.briefs_by_id)
        alias = self.root / 'assets/alias.png'
        alias.symlink_to(self.root / 'assets/production/illustrations/0.png')
        entry['asset_path'] = 'assets/alias.png'
        with self.assertRaisesRegex(pipeline.ValidationError, 'Symlink'):
            pipeline.validate_assets(self.root, self.manifest(entry), self.source_map, self.source_hash, self.briefs_by_id)

    def test_image_hash_dimensions_and_truncated_decode_fail(self):
        for corruption in ('hash', 'dimensions', 'truncated'):
            entry = self.asset()
            if corruption == 'hash':
                entry['sha256'] = '0' * 64
            elif corruption == 'dimensions':
                entry['height'] = 501
            else:
                path = self.root / entry['asset_path']
                path.write_bytes(path.read_bytes()[:50])
                entry['sha256'] = pipeline.sha256(path)
            with self.subTest(corruption=corruption), self.assertRaises(pipeline.ValidationError):
                pipeline.validate_assets(self.root, self.manifest(entry), self.source_map, self.source_hash, self.briefs_by_id)

    def test_wrong_extension_for_decodable_image_is_rejected(self):
        entry = self.asset()
        path = self.root / entry['asset_path']
        Image.new('RGB', (700, 500), (50, 100, 150)).save(path, format='JPEG')
        entry['sha256'] = pipeline.sha256(path)
        with self.assertRaisesRegex(pipeline.ValidationError, 'Bildformat passt nicht zur Dateiendung'):
            pipeline.validate_assets(self.root, self.manifest(entry), self.source_map, self.source_hash, self.briefs_by_id)

    def test_shared_atlas_copy_is_not_individual_original(self):
        entry = self.asset()
        shared = self.root / 'assets/art/atlas.png'
        shared.parent.mkdir(parents=True)
        shared.write_bytes((self.root / entry['asset_path']).read_bytes())
        with self.assertRaisesRegex(pipeline.ValidationError, 'Konzeptatlas'):
            pipeline.validate_assets(self.root, self.manifest(entry), self.source_map, self.source_hash, self.briefs_by_id)

    def test_final_requires_explicit_reviews_and_does_not_imply_gameplay(self):
        entry = self.asset(status='final', size=(1344, 1000))
        with self.assertRaisesRegex(pipeline.ValidationError, 'Bild-/Loreprüfung'):
            pipeline.validate_assets(self.root, self.manifest(entry), self.source_map, self.source_hash, self.briefs_by_id)
        entry['review'].update(visual='passed', lore='passed', reviewer='Fixture reviewer', note='Test review only.')
        with self.assertRaisesRegex(pipeline.ValidationError, 'Rechteprüfung'):
            pipeline.validate_assets(self.root, self.manifest(entry), self.source_map, self.source_hash, self.briefs_by_id)
        entry['review']['rights'] = 'passed'
        states = pipeline.validate_assets(self.root, self.manifest(entry), self.source_map, self.source_hash, self.briefs_by_id)
        self.assertEqual('final', states[entry['card_id']])
        self.assertFalse(pipeline.make_report(self.source_map, self.briefs, states, self.source_hash)['release_ready'])

    def test_final_requires_production_resolution_even_with_passed_reviews(self):
        entry = self.asset(status='final')
        entry['review'].update(visual='passed', lore='passed', rights='passed',
                               reviewer='Fixture reviewer', note='Test review only.')
        with self.assertRaisesRegex(pipeline.ValidationError, '1344 × 1000 echte dekodierte Pixel'):
            pipeline.validate_assets(self.root, self.manifest(entry), self.source_map, self.source_hash, self.briefs_by_id)
        # The same lower-resolution file remains a valid nonfinal production candidate.
        for status in ('generated', 'reviewed'):
            entry['status'] = status
            states = pipeline.validate_assets(self.root, self.manifest(entry), self.source_map, self.source_hash, self.briefs_by_id)
            self.assertEqual(status, states[entry['card_id']])

    def test_existing_art_requires_stable_id_alternative_text_and_edit_history(self):
        for field in ('asset_id', 'alternative_text', 'edits'):
            with self.subTest(field=field):
                entry = self.asset()
                del entry[field]
                with self.assertRaisesRegex(pipeline.ValidationError, field):
                    pipeline.validate_assets(self.root, self.manifest(entry), self.source_map, self.source_hash, self.briefs_by_id)
        entry = self.asset()
        entry['edits'] = ['']
        with self.assertRaisesRegex(pipeline.ValidationError, 'edits'):
            pipeline.validate_assets(self.root, self.manifest(entry), self.source_map, self.source_hash, self.briefs_by_id)

    def test_missing_asset_cannot_claim_a_path(self):
        missing = {'card_id': self.source[0]['id'], 'status': 'missing', 'asset_path': 'assets/no.png'}
        with self.assertRaisesRegex(pipeline.ValidationError, 'missing darf'):
            pipeline.validate_assets(self.root, self.manifest(missing), self.source_map, self.source_hash, self.briefs_by_id)

    def test_no_implicit_overwrite_or_symlink_output(self):
        output = self.root / 'out.json'
        pipeline.write_output({'old': True}, output)
        with self.assertRaises(pipeline.ValidationError):
            pipeline.write_output({'new': True}, output)
        self.assertEqual({'old': True}, pipeline.load_json(output))
        pipeline.write_output({'new': True}, output, overwrite=True)
        self.assertEqual({'new': True}, pipeline.load_json(output))
        alias = self.root / 'output-alias.json'
        alias.symlink_to(output)
        with self.assertRaisesRegex(pipeline.ValidationError, 'Symlink'):
            pipeline.write_output({}, alias, overwrite=True)

    def test_malformed_json_is_a_clean_error(self):
        self.source_path.write_text('{broken', encoding='utf-8')
        with self.assertRaisesRegex(pipeline.ValidationError, 'ungültiges'):
            pipeline.load_json(self.source_path)

    def test_cli_release_gate_and_missing_explicit_manifest_do_not_write(self):
        brief_dir = self.root / 'briefs'
        brief_dir.mkdir()
        for index, filename in enumerate(pipeline.BRIEF_FILES):
            (brief_dir / filename).write_text(json.dumps(self.briefs[index*110:(index+1)*110]), encoding='utf-8')
        output = self.root / 'report.json'
        args = ['report', '--root', str(self.root), '--source', str(self.source_path),
                '--briefs', str(brief_dir), '--out', str(output)]
        with patch('sys.stderr'):
            self.assertEqual(2, pipeline.main(args + ['--release-ready']))
            self.assertFalse(output.exists())
            self.assertEqual(2, pipeline.main(args + ['--manifest', str(self.root / 'missing.json')]))
            self.assertFalse(output.exists())
        self.assertEqual(0, pipeline.main(args))
        self.assertEqual(550, pipeline.load_json(output)['asset_states']['missing'])


if __name__ == '__main__':
    unittest.main()
