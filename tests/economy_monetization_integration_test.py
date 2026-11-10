"""Cross-module reproducibility and active-runtime isolation for commercial analysis."""
import contextlib
import hashlib
import io
import json
import math
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tools/economy'))
from simulate_monetization import run


class MonetizationIntegrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        cls.out = Path(cls.temp.name)/'analysis'
        cls.config = ROOT/'data/economy/analysis/monetization.json'
        cls.runtime_files = list((ROOT/'data/economy').glob('*.json')) + list((ROOT/'scripts/economy').glob('*.gd'))
        cls.before = {p: hashlib.sha256(p.read_bytes()).hexdigest() for p in cls.runtime_files}
        with contextlib.redirect_stdout(io.StringIO()):
            cls.collection, cls.revenue = run(cls.config, cls.out, repetitions=1)

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def test_analysis_runs_without_modifying_active_economy(self):
        after = {p: hashlib.sha256(p.read_bytes()).hexdigest() for p in self.runtime_files}
        self.assertEqual(self.before, after)
        self.assertEqual(self.collection['models']['baseline96']['profiles']['F2P45']['checkpoints']['30']['free_packs']['mean'], 96)
        self.assertEqual(self.collection['models']['protected_weekly']['profiles']['F2P45']['checkpoints']['30']['first_target_complete']['mean'], 1)

    def test_pipeline_artifacts_and_finance_are_consistent(self):
        for filename in ['collection_summary.json', 'collection_metrics.csv', 'collection_marginality.csv',
                         'collection_sensitivity.csv', 'collection_paid_gaps.csv', 'revenue_summary.json',
                         'analysis_metadata.json', 'MONETIZATION-REPORT.md']:
            self.assertTrue((self.out/filename).is_file(), filename)
        self.assertEqual(set(self.collection['models']), set(self.revenue['results']['base']))
        for models in self.revenue['results'].values():
            for data in models.values():
                total = data['expected']['horizons']['24']
                self.assertTrue(math.isfinite(total['operating_profit_after_acquisition_eur']))
                self.assertAlmostEqual(total['gross_spend_ex_vat_eur']-total['refunds_eur']-total['platform_fees_eur'], total['net_revenue_eur'])

    def test_hash_verified_reuse_reproduces_revenue(self):
        with contextlib.redirect_stdout(io.StringIO()):
            _, result = run(self.config, self.out, repetitions=1, reuse_collection=True)
        self.assertEqual(self.revenue, result)
        metadata = json.loads((self.out/'analysis_metadata.json').read_text())
        for path, expected in metadata['source_sha256'].items():
            self.assertEqual(hashlib.sha256((ROOT/path).read_bytes()).hexdigest(), expected)

    def test_stale_collection_cannot_silently_support_changed_assumptions(self):
        changed = json.loads(self.config.read_text())
        changed['costs']['fixed_cost_per_month_eur'] += 1
        path = Path(self.temp.name)/'changed.json'
        path.write_text(json.dumps(changed))
        with self.assertRaisesRegex(ValueError, 'Stale collection evidence'):
            run(path, self.out, repetitions=1, reuse_collection=True)
