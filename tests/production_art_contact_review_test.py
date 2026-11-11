"""Actual delivered contact-review coverage, not another claimed visual review."""
from html.parser import HTMLParser
import hashlib
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class Links(HTMLParser):
    def __init__(self): super().__init__(); self.images=[]; self.originals=[]
    def handle_starttag(self, tag, attrs):
        values=dict(attrs)
        if tag=='img': self.images.append(values['src'])
        if tag=='a' and values.get('href','').endswith('.png'): self.originals.append(values['href'])


class ContactReview(unittest.TestCase):
    def test_actual_coverage_and_first_reviewer_overlap_remain_explicit(self):
        review=json.loads((ROOT/'docs/production/art-evidence/contact-review.json').read_text())
        source=json.loads((ROOT/'data/production/art_sources.json').read_text())['entries']
        self.assertEqual(len(source),550)
        self.assertEqual(set(review['coverage']['contact_ids']),set(source))
        self.assertEqual(review['coverage']['contact_ids_actually_viewed'],550)
        self.assertEqual(review['coverage']['contact_pages_actually_viewed'],10)
        self.assertEqual(review['coverage']['native_original_png_files_actually_opened'],22)
        self.assertEqual(len({r['id'] for r in review['native_followups']}),22)
        self.assertFalse(review['coverage']['all_550_full_native_second_review'])
        self.assertFalse(review['independence']['personally_independent_second_reviewer_for_all_550'])
        self.assertEqual(review['independence']['known_same_reviewer_artist_first_review_overlap']['total'],106)
        self.assertEqual(hashlib.sha256((ROOT/'data/production/art_sources.json').read_bytes()).hexdigest(),review['evidence']['source_manifest_sha256'])
        for row in review['native_followups']:
            self.assertEqual(row['source_png'],'assets/cards/originals/'+row['id']+'.png')
            self.assertEqual(row['source_sha256'],source[row['id']]['sha256'])
            self.assertFalse(row['commercially_cleared'])

    def test_portable_gallery_references_all_real_previews_and_originals_once(self):
        gallery=ROOT/'docs/production/art-evidence/contact-gallery.html'
        links=Links();links.feed(gallery.read_text())
        source=json.loads((ROOT/'data/production/art_sources.json').read_text())['entries']
        self.assertEqual(len(links.images),550);self.assertEqual(len(set(links.images)),550)
        self.assertEqual(len(links.originals),550);self.assertEqual(len(set(links.originals)),550)
        self.assertEqual({Path(v).stem for v in links.images},set(source))
        self.assertEqual({Path(v).stem for v in links.originals},set(source))
        for value in links.images+links.originals:
            path=(gallery.parent/value).resolve()
            self.assertTrue(path.is_relative_to(ROOT/'assets/cards'))
            self.assertTrue(path.is_file());self.assertFalse(path.is_symlink())
        manifest=json.loads((ROOT/'docs/production/art-evidence/contact-gallery-manifest.json').read_text())
        self.assertEqual(len(manifest['pages']),10)
        self.assertEqual(sum(len(row['ids']) for row in manifest['pages']),550)
        self.assertEqual({row['id'] for row in manifest['sources']},set(source))


if __name__=='__main__': unittest.main()
