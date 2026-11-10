import copy
import importlib.util
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tools/economy'))
import monetization_revenue as revenue


class RevenueTests(unittest.TestCase):
    def setUp(self):
        self.config = revenue.load_config()
        self.utility = [1.0] * 24

    def run_model(self, **kwargs):
        return revenue.simulate_cohort(self.config, 'baseline96', 'base', self.utility, **kwargs)

    def test_zero_retention_has_no_purchases(self):
        self.config['revenue_scenarios']['base']['retention_probability'] = {k: 0 for k in self.config['revenue_scenarios']['base']['retention_probability']}
        result = self.run_model()
        self.assertEqual(result['horizons']['24']['gross_spend_ex_vat_eur'], 0)
        self.assertEqual(result['horizons']['24']['active_player_days'], 0)
        self.assertEqual(sum(r['distinct_monthly_payers'] for r in result['monthly']), 0)

    def test_flat_survival_has_exact_assumed_active_days(self):
        scenario = self.config['revenue_scenarios']['base']
        scenario['retention_probability'] = {k: 1 for k in scenario['retention_probability']}
        scenario['active_days_per_retained_month'] = 10
        result = self.run_model()
        for row in result['monthly']:
            self.assertAlmostEqual(row['active_player_days'], row['retained_month_members'] * 10)

    def test_zero_buy_probability_has_no_revenue_or_payers(self):
        self.config['revenue_scenarios']['base']['monthly_payer_probability'] = 0
        result = self.run_model()
        self.assertEqual(result['horizons']['24']['net_revenue_eur'], 0)
        self.assertEqual(result['horizons']['24']['payer_months'], 0)
        self.assertLess(result['horizons']['24']['contribution_eur'], 0)
        self.assertFalse(result['horizons']['24']['break_even_before_fixed_feasible_at_zero_cac'])
        self.assertLess(result['horizons']['24']['raw_break_even_cac_after_fixed_eur'], 0)

    def test_free_products_never_count_as_payers(self):
        for key in ('cosmetic_unit_gross_eur', 'season_pass_gross_eur', 'pack_gross_eur', 'beginner_package_gross_eur'):
            self.config['products'][key] = 0
        result = self.run_model()
        self.assertEqual(result['horizons']['24']['gross_spend_ex_vat_eur'], 0)
        self.assertEqual(result['horizons']['24']['payer_months'], 0)

    def test_full_collection_removes_packs_only(self):
        open_collection = self.run_model()
        full = revenue.simulate_cohort(self.config, 'baseline96', 'base', [0.] * 24)
        for left, right in zip(open_collection['monthly'], full['monthly']):
            self.assertEqual(right['gross_by_product_eur']['packs'], 0)
            for product in ('cosmetics', 'season_pass', 'beginner'):
                self.assertAlmostEqual(left['gross_by_product_eur'][product], right['gross_by_product_eur'][product])
            self.assertGreaterEqual(left['distinct_monthly_payers'], right['distinct_monthly_payers'])

    def test_beginner_once_and_season_pass_opt_in(self):
        result = self.run_model(seed=77)
        self.assertLessEqual(result['horizons']['24']['beginner_packages'], self.config['cohort']['acquired_players'])
        self.assertEqual(result['horizons']['24']['beginner_packages'], result['monthly'][0]['purchases']['beginner'])
        for month in result['monthly'][1:]:
            self.assertEqual(month['purchases']['beginner'], 0)
        for index, month in enumerate(result['monthly']):
            if index % 3:
                self.assertEqual(month['purchases']['season_pass'], 0)

    def test_accounting_conservation_and_no_overlap_double_count(self):
        for seed in (None, 33):
            result = self.run_model(seed=seed)
            for row in result['monthly']:
                gross = row['gross_spend_ex_vat_eur']
                self.assertAlmostEqual(gross, sum(row['gross_by_product_eur'].values()))
                self.assertAlmostEqual(gross, row['refunds_eur'] + row['platform_fees_eur'] + row['net_revenue_eur'])
                self.assertAlmostEqual(row['net_revenue_eur'], row['variable_cost_eur'] + row['contribution_eur'])
                self.assertAlmostEqual(row['operating_profit_after_acquisition_eur'], row['contribution_eur'] - row['fixed_cost_eur'] - row['acquisition_cost_eur'])
                self.assertLessEqual(row['distinct_monthly_payers'], row['purchase_intents'] + 1e-8)
                self.assertLessEqual(row['purchase_intents'], row['retained_month_members'] + 1e-8)
                self.assertGreaterEqual(row['active_player_days'], row['retained_month_members'])
                if row['distinct_monthly_payers']:
                    self.assertAlmostEqual(row['gross_monthly_arppu_eur'], gross / row['distinct_monthly_payers'])
            self.assertEqual(result['horizons']['24']['acquisition_cost_eur'], 8000)
            self.assertEqual(result['horizons']['24']['fixed_cost_eur'], 120000)
            self.assertAlmostEqual(result['horizons']['24']['net_revenue_ltv_eur'], result['horizons']['24']['net_revenue_eur'] / 10000)

    def test_sampling_reproducible_and_retention_controlled(self):
        result = self.run_model(seed=22)
        self.assertEqual(result, self.run_model(seed=22))
        other = revenue.simulate_cohort(self.config, 'cosmetics_first', 'base', self.utility, seed=22)
        self.assertEqual([row['retained_month_members'] for row in result['monthly']], [row['retained_month_members'] for row in other['monthly']])

    def test_invalid_probabilities_and_weights_rejected(self):
        cases = []
        for value in (-.1, 1.1, float('nan'), True):
            changed = copy.deepcopy(self.config)
            changed['revenue_scenarios']['base']['monthly_payer_probability'] = value
            cases.append(changed)
        bad = copy.deepcopy(self.config)
        bad['revenue_scenarios']['base']['retention_probability']['7'] = .99
        cases.append(bad)
        bad = copy.deepcopy(self.config)
        bad['models']['baseline96']['payer_basket_weights']['all'] = .9
        cases.append(bad)
        bad = copy.deepcopy(self.config)
        bad['products']['beginner_max_purchases_per_account'] = 2
        cases.append(bad)
        bad = copy.deepcopy(self.config)
        bad['cohort']['new_players_per_month'] = 1000
        cases.append(bad)
        bad = copy.deepcopy(self.config)
        bad['behavior_sensitivities']['low_cosmetic_demand']['cosmetic_purchase_probability'] = -1
        cases.append(bad)
        for config in cases:
            with self.assertRaises(ValueError):
                revenue.validate_config(config)

    def test_collection_report_required_and_bounded(self):
        with self.assertRaises(ValueError):
            revenue.utilities_from_report({}, 'baseline96', 'paid4', 24)
        with self.assertRaises(ValueError):
            revenue.simulate_cohort(self.config, 'baseline96', 'base', [1.1] * 24)
        with self.assertRaises(ValueError):
            revenue.simulate_cohort(self.config, 'baseline96', 'base', [1.] * 23)

    def test_pack_demand_collapse_does_not_change_cosmetics_or_retention(self):
        baseline = self.run_model()
        collapse = self.run_model(sensitivity_name='pack_demand_collapse')
        for left, right in zip(baseline['monthly'], collapse['monthly']):
            self.assertEqual(left['retained_month_members'], right['retained_month_members'])
            self.assertEqual(right['gross_by_product_eur']['packs'], 0)
            self.assertAlmostEqual(left['gross_by_product_eur']['cosmetics'], right['gross_by_product_eur']['cosmetics'])

    def test_playset_gap_and_heavy_inventory_are_separate_hypotheses(self):
        self.config['repetitions'] = 2
        report = {'models': {name: {'profiles': {profile: {'monthly': [
            {'month': month, 'unsaturation_factor': 0., 'mean_playset_pct': 50.}
            for month in range(1, 25)]} for profile in ('paid4', 'paid40')}}
            for name in self.config['models']}}
        result = revenue.analyse(self.config, report)
        sensitivity = result['inventory_demand_sensitivity']['baseline96']
        self.assertEqual(sensitivity['playset_gap_proxy']['monthly'][0]['pack_utility_proxy'], .5)
        self.assertGreater(sensitivity['playset_gap_proxy']['monthly'][0]['gross_by_product_eur']['packs'], 0)
        self.assertEqual(sensitivity['paid40_daily_inventory_proxy']['monthly'][0]['gross_by_product_eur']['packs'], 0)
        self.assertEqual(len(result['steady_state_organic_sensitivity']), 12)
        self.assertEqual(len(result['spending_sensitivity']), 16)


if __name__ == '__main__':
    unittest.main()
