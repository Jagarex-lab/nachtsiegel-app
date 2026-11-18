"""Actual delivered contact-review coverage, not another claimed visual review."""
from html.parser import HTMLParser
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("contact_art_manifest", ROOT / "tools/production/art_manifest.py")
ART = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ART)


def historical_contact_source_bytes(document):
    """Verify the additive migration, then recover the exact historical ledger.

    This keeps the original contact-review checksum and its limited review scope.
    No old image, prompt, approval, rights or provenance field is excluded.
    """
    expected = {
        "schema_version": 1, "source_commit": "6c99dfcbd1bc68b550b3aa61f9dc762f4be8635f",
        "input_blobs": {
            "data/production/art_sources.json": "80b55db7a203e65c2241a6172996504e0045bb4e",
            "data/production/cards.json": "3ad4863e10c0c3144e98f09650a728020952736f",
            "data/production/art_briefs.json": "be46a10455ae8ade272b51dafd43a6950d9771b8",
        },
        "scope": "Technical snapshot of existing visual approval; no fresh visual review or commercial clearance.",
        "new_visual_review": False, "commercial_clearance": False,
    }
    baseline = document.get("brief_binding_baseline")
    if (baseline != expected or type(baseline.get("schema_version")) is not int
            or baseline.get("new_visual_review") is not False or baseline.get("commercial_clearance") is not False):
        raise ValueError("Contact review requires the exact technical binding baseline")
    cards = {c["id"]: c for c in ART.load(ROOT / "data/production/cards.json")["cards"]}
    briefs = {b["id"]: b for b in ART.load(ROOT / "data/production/art_briefs.json")["cards"]}
    if len(document["entries"]) != 550 or set(document["entries"]) != set(cards) or set(briefs) != set(cards):
        raise ValueError("Contact review source identities changed")
    for card_id, source in document["entries"].items():
        if source.get("card_id") != card_id or "reviewed_brief" not in source:
            raise ValueError("Contact review source lacks its migrated identity/binding")
        ART.validate_brief_binding(source, cards[card_id], briefs[card_id])
    historical = copy.deepcopy(document)
    del historical["brief_binding_baseline"]
    for source in historical["entries"].values(): del source["reviewed_brief"]
    data = ART.serialized(historical).encode("utf-8")
    blob = hashlib.sha1(b"blob " + str(len(data)).encode("ascii") + b"\0" + data).hexdigest()
    if blob != expected["input_blobs"]["data/production/art_sources.json"]:
        raise ValueError("Historical contact-review source ledger changed")
    return data


class Links(HTMLParser):
    def __init__(self): super().__init__(); self.images=[]; self.originals=[]
    def handle_starttag(self, tag, attrs):
        values=dict(attrs)
        if tag=='img': self.images.append(values['src'])
        if tag=='a' and values.get('href','').endswith('.png'): self.originals.append(values['href'])


class ContactReview(unittest.TestCase):
    def test_actual_coverage_and_first_reviewer_overlap_remain_explicit(self):
        review=json.loads((ROOT/'docs/production/art-evidence/contact-review.json').read_text())
        document=json.loads((ROOT/'data/production/art_sources.json').read_text())
        source=document['entries']
        self.assertEqual(len(source),550)
        self.assertEqual(set(review['coverage']['contact_ids']),set(source))
        self.assertEqual(review['coverage']['contact_ids_actually_viewed'],550)
        self.assertEqual(review['coverage']['contact_pages_actually_viewed'],10)
        self.assertEqual(review['coverage']['native_original_png_files_actually_opened'],22)
        self.assertEqual(len({r['id'] for r in review['native_followups']}),22)
        self.assertFalse(review['coverage']['all_550_full_native_second_review'])
        self.assertFalse(review['independence']['personally_independent_second_reviewer_for_all_550'])
        self.assertEqual(review['independence']['known_same_reviewer_artist_first_review_overlap']['total'],106)
        self.assertEqual(hashlib.sha256(historical_contact_source_bytes(document)).hexdigest(),review['evidence']['source_manifest_sha256'])
        for row in review['native_followups']:
            self.assertEqual(row['source_png'],'assets/cards/originals/'+row['id']+'.png')
            self.assertEqual(row['source_sha256'],source[row['id']]['sha256'])
            self.assertFalse(row['commercially_cleared'])

    def test_genuine_old_source_edits_cannot_hide_behind_technical_metadata(self):
        original=json.loads((ROOT/'data/production/art_sources.json').read_text())
        first=next(iter(original['entries']))
        for key,value in [('sha256','0'*64),('source_prompt','A changed production prompt'),
                          ('status','concept'),('production_review','pending'),
                          ('commercially_cleared',True),('commercial_review','passed'),
                          ('reference_sources',[{'kind':'unidentified'}]),
                          ('production_review_notes_de','A different review claim')]:
            with self.subTest(field=key):
                changed=copy.deepcopy(original);changed['entries'][first][key]=value
                with self.assertRaisesRegex(ValueError,'Historical contact-review source ledger changed'):
                    historical_contact_source_bytes(changed)

    def test_binding_metadata_is_validated_before_historical_reconstruction(self):
        original=json.loads((ROOT/'data/production/art_sources.json').read_text())
        first=next(iter(original['entries']))
        for field,value in [('source_commit','0'*40),('schema_version',True),('schema_version',1.0),
                            ('new_visual_review',True),('new_visual_review',0),
                            ('commercial_clearance',True),('commercial_clearance',0)]:
            with self.subTest(field=field):
                changed=copy.deepcopy(original);changed['brief_binding_baseline'][field]=value
                with self.assertRaisesRegex(ValueError,'exact technical binding baseline'):
                    historical_contact_source_bytes(changed)
        changed=copy.deepcopy(original);changed['entries'][first]['reviewed_brief']['sha256']='0'*64
        with self.assertRaisesRegex(ValueError,'Stale reviewed art brief binding'):
            historical_contact_source_bytes(changed)
        changed=copy.deepcopy(original);del changed['entries'][first]['reviewed_brief']
        with self.assertRaisesRegex(ValueError,'migrated identity/binding'):
            historical_contact_source_bytes(changed)

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
