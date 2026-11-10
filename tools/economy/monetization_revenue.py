#!/usr/bin/env python3
"""Assumption-labelled cohort accounting; no commerce or economy-runtime changes.

Collection utility is measured elsewhere. Its conversion into pack purchase
probability, all retention curves, prices and purchase intents are hypotheses.
Monte Carlo intervals describe finite-cohort sampling, NOT parameter confidence.
"""
from __future__ import annotations
import argparse
import copy
import json
import math
from pathlib import Path
import random
import statistics

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CONFIG = ROOT / 'data/economy/analysis/monetization.json'


def _number(value, low=0.0, high=math.inf):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value) and low <= value <= high


def validate_config(config):
    """Reject invalid assumptions rather than silently clipping financial inputs."""
    if config.get('schema_version') != 1:
        raise ValueError('unsupported analysis schema')
    cohort = config['cohort']
    for key in ('acquired_players', 'months', 'days_per_month'):
        if not _number(cohort.get(key), 1) or int(cohort[key]) != cohort[key]:
            raise ValueError('invalid cohort ' + key)
    if cohort.get('new_players_per_month') != 0:
        raise ValueError('this is a closed acquisition cohort; new players require a separate cohort model')
    if not _number(cohort['acquisition_cost_per_player_eur']):
        raise ValueError('invalid CAC')
    if not _number(config.get('repetitions'), 1) or int(config['repetitions']) != config['repetitions']:
        raise ValueError('invalid repetitions')
    if not _number(config.get('seed'), 0) or int(config['seed']) != config['seed']:
        raise ValueError('invalid deterministic seed')
    for basket in config['baskets'].values():
        if not _number(basket.get('cosmetic_units')) or int(basket['cosmetic_units']) != basket['cosmetic_units'] or not isinstance(basket.get('season_pass'), bool) or not isinstance(basket.get('packs'), bool):
            raise ValueError('invalid payer basket contents')
    for scenario in config['revenue_scenarios'].values():
        if not _number(scenario.get('monthly_payer_probability'), 0, 1):
            raise ValueError('invalid monthly payer probability')
        if not _number(scenario.get('active_days_per_retained_month'), 1, cohort['days_per_month']):
            raise ValueError('invalid active-day assumption')
        curve = sorted((int(day), value) for day, value in scenario['retention_probability'].items())
        if not curve or curve[0][0] != 1 or curve[-1][0] < cohort['months'] * cohort['days_per_month']:
            raise ValueError('retention curve does not cover cohort horizon')
        previous = 1.0
        for day, probability in curve:
            if day < 1 or not _number(probability, 0, previous):
                raise ValueError('invalid/non-monotone retention probability')
            previous = probability
    for model in config['models'].values():
        weights = model['payer_basket_weights']
        if not weights or not all(key in config['baskets'] and _number(weight, 0, 1) for key, weight in weights.items()) or not math.isclose(sum(weights.values()), 1.0, abs_tol=1e-9):
            raise ValueError('invalid/disjoint payer basket distribution')
    products = config['products']
    for key in ('cosmetic_unit_gross_eur', 'season_pass_gross_eur', 'pack_gross_eur', 'beginner_package_gross_eur', 'packs_per_purchase'):
        if not _number(products.get(key)):
            raise ValueError('invalid illustrative product amount: ' + key)
    if not _number(products.get('beginner_addon_probability'), 0, 1):
        raise ValueError('invalid beginner probability')
    if products.get('beginner_max_purchases_per_account') != 1 or products.get('season_pass_auto_renew') is not False or products.get('season_pass_cosmetics_only') is not True or products.get('beginner_package_cosmetics_only') is not True:
        raise ValueError('beginner bounded/optional cosmetic product contract required')
    if not _number(products.get('season_length_months'), 1) or int(products['season_length_months']) != products['season_length_months']:
        raise ValueError('invalid season length')
    costs = config['costs']
    for key in ('platform_fee_fraction', 'refund_fraction', 'tax_fraction'):
        if not _number(costs.get(key), 0, 1):
            raise ValueError('invalid accounting fraction: ' + key)
    if costs['tax_fraction'] != 0:
        raise ValueError('tax modelling is not implemented; tax omission must stay explicit')
    for key in ('variable_per_retained_account_month_eur', 'variable_per_payer_month_eur', 'fixed_cost_per_month_eur'):
        if not _number(costs.get(key)):
            raise ValueError('invalid cost: ' + key)
    if not _number(config['collection_demand'].get('elasticity'), .01):
        raise ValueError('invalid demand elasticity')
    for sensitivity in config.get('behavior_sensitivities', {}).values():
        for model in sensitivity.get('apply_to_models', []):
            if model not in config['models']:
                raise ValueError('unknown sensitivity model')
        for key in ('retention_probability_multiplier', 'payer_probability_multiplier', 'cosmetic_purchase_probability', 'pass_purchase_probability', 'pack_purchase_probability_multiplier'):
            if key in sensitivity and not _number(sensitivity[key], 0, 1):
                raise ValueError('invalid behavioral sensitivity probability')
    if not all(_number(multiplier, .01) for multiplier in config.get('spending_sensitivity_multipliers', [])):
        raise ValueError('invalid spending sensitivity')
    return config


def load_config(path=DEFAULT_CONFIG):
    return validate_config(json.loads(Path(path).read_text(encoding='utf-8')))


def retention_at(curve, day):
    points = sorted((int(d), float(p)) for d, p in curve.items())
    if day <= points[0][0]:
        return points[0][1]
    for (left_day, left), (right_day, right) in zip(points, points[1:]):
        if day <= right_day:
            fraction = (day - left_day) / (right_day - left_day)
            # Log interpolation preserves long-tail shape; linear at zero endpoint.
            return math.exp(math.log(left) * (1 - fraction) + math.log(right) * fraction) if left > 0 and right > 0 else left * (1 - fraction) + right * fraction
    return points[-1][1]


def _binomial(rng, n, probability):
    if rng is None:
        return n * probability
    n = int(n)
    if probability <= 0:
        return 0
    if probability >= 1:
        return n
    # Python3.12 provides exact efficient binomial draws; fallback stays exact.
    return rng.binomialvariate(n, probability) if hasattr(rng, 'binomialvariate') else sum(rng.random() < probability for _ in range(n))


def _baskets(rng, count, weights):
    remaining, mass = count, 1.0
    items = list(weights.items())
    result = {}
    for index, (name, weight) in enumerate(items):
        chosen = remaining if index == len(items) - 1 else _binomial(rng, remaining, min(1.0, weight / mass))
        result[name] = chosen
        remaining -= chosen
        mass -= weight
    return result


def _cashflows(config, model, intent_count, month, utility, rng, sensitivity):
    """Partition each disjoint basket by products, retaining distinct payer union."""
    products = config['products']
    unit_prices = {'cosmetics': products['cosmetic_unit_gross_eur'], 'season_pass': products['season_pass_gross_eur'], 'packs': products['packs_per_purchase'] * products['pack_gross_eur'], 'beginner': products['beginner_package_gross_eur']}
    purchase_counts = {key: 0.0 for key in unit_prices}
    distinct = 0.0
    pack_probability = utility ** config['collection_demand']['elasticity'] * sensitivity.get('pack_purchase_probability_multiplier', 1.0)
    for name, count in _baskets(rng, intent_count, model['payer_basket_weights']).items():
        basket = config['baskets'][name]
        probabilities = {'cosmetics': sensitivity.get('cosmetic_purchase_probability', 1.0) if basket['cosmetic_units'] else 0.0,
                        'season_pass': sensitivity.get('pass_purchase_probability', 1.0) if basket['season_pass'] and month % products['season_length_months'] == 0 else 0.0,
                        'packs': pack_probability if basket['packs'] else 0.0,
                        'beginner': products['beginner_addon_probability'] if month == 0 else 0.0}
        groups = {False: count, True: 0.0}
        for product, probability in probabilities.items():
            next_groups = {False: 0.0, True: 0.0}
            for paid, group_count in groups.items():
                buyers = _binomial(rng, group_count, probability)
                purchase_counts[product] += buyers * (basket['cosmetic_units'] if product == 'cosmetics' else 1)
                # A zero-price/free product never turns an account into a payer.
                next_groups[paid or unit_prices[product] > 0] += buyers
                next_groups[paid] += group_count - buyers
            groups = next_groups
        distinct += groups[True]
    gross_by_product = {key: purchase_counts[key] * unit_prices[key] for key in unit_prices}
    return sum(gross_by_product.values()), distinct, purchase_counts, gross_by_product


def simulate_cohort(config, model_name, scenario_name, utilities, seed=None, sensitivity_name=None):
    validate_config(config)
    cohort, costs = config['cohort'], config['costs']
    model, scenario = config['models'][model_name], config['revenue_scenarios'][scenario_name]
    sensitivity = config.get('behavior_sensitivities', {}).get(sensitivity_name, {}) if sensitivity_name else {}
    if model_name not in sensitivity.get('apply_to_models', [model_name]):
        sensitivity = {}
    retention_multiplier = sensitivity.get('retention_probability_multiplier', 1.0)
    payer_probability = scenario['monthly_payer_probability'] * sensitivity.get('payer_probability_multiplier', 1.0)
    if not _number(payer_probability, 0, 1):
        raise ValueError('sensitivity generates invalid payer probability')
    if len(utilities) < cohort['months'] or not all(_number(u, 0, 1) for u in utilities):
        raise ValueError('missing or invalid measured collection utilities')
    retention_rng = random.Random(seed ^ 0x5F3759DF) if seed is not None else None
    purchase_rng = random.Random(seed) if seed is not None else None
    previous_survival, active = 1.0, cohort['acquired_players']
    rows = []
    for month in range(cohort['months']):
        start_day, end_day = month * cohort['days_per_month'] + 1, (month + 1) * cohort['days_per_month']
        survival = retention_at(scenario['retention_probability'], start_day) * retention_multiplier
        active = _binomial(retention_rng, active, survival / previous_survival if previous_survival else 0)
        previous_survival = survival
        intents = _binomial(purchase_rng, active, payer_probability)
        gross, payers, purchase_counts, by_product = _cashflows(config, model, intents, month, utilities[month], purchase_rng, sensitivity)
        refunds = gross * costs['refund_fraction']
        fees = (gross - refunds) * costs['platform_fee_fraction']
        revenue = gross - refunds - fees
        variable = active * costs['variable_per_retained_account_month_eur'] + payers * costs['variable_per_payer_month_eur']
        contribution = revenue - variable
        acquisition = cohort['acquired_players'] * cohort['acquisition_cost_per_player_eur'] if month == 0 else 0
        fixed = costs['fixed_cost_per_month_eur']
        # Every month-start member has one activity; remaining activity is an
        # explicit propensity, not an assumption that retained accounts play daily.
        tail = sum(retention_at(scenario['retention_probability'], day) * retention_multiplier for day in range(start_day + 1, end_day + 1))
        remaining_activity_probability = (scenario['active_days_per_retained_month'] - 1) / (cohort['days_per_month'] - 1) if cohort['days_per_month'] > 1 else 0
        active_days = active * (1 + tail / survival * remaining_activity_probability) if survival else 0
        rows.append({'month': month + 1, 'cohort_age_start_day': start_day, 'retained_month_members': active, 'active_player_days': active_days, 'purchase_intents': intents, 'distinct_monthly_payers': payers, 'realized_payer_probability': payers / active if active else 0,
                     'gross_spend_ex_vat_eur': gross, 'refunds_eur': refunds, 'platform_fees_eur': fees, 'net_revenue_eur': revenue, 'variable_cost_eur': variable, 'contribution_eur': contribution, 'fixed_cost_eur': fixed, 'acquisition_cost_eur': acquisition, 'operating_profit_after_acquisition_eur': contribution - fixed - acquisition,
                     'gross_monthly_arppu_eur': gross / payers if payers else 0, 'net_monthly_arppu_eur': revenue / payers if payers else 0, 'pack_utility_proxy': utilities[month], 'purchases': purchase_counts, 'gross_by_product_eur': by_product})
    horizons = {}
    for horizon in (12, 24):
        if horizon > cohort['months']:
            continue
        selected = rows[:horizon]
        totals = {key: sum(row[key] for row in selected) for key in ('gross_spend_ex_vat_eur', 'refunds_eur', 'platform_fees_eur', 'net_revenue_eur', 'variable_cost_eur', 'contribution_eur', 'fixed_cost_eur', 'acquisition_cost_eur', 'operating_profit_after_acquisition_eur', 'distinct_monthly_payers', 'active_player_days')}
        totals['payer_months'] = totals.pop('distinct_monthly_payers')
        for key, source in [('gross_ltv_eur', 'gross_spend_ex_vat_eur'), ('net_revenue_ltv_eur', 'net_revenue_eur'), ('contribution_ltv_before_cac_eur', 'contribution_eur')]:
            totals[key] = totals[source] / cohort['acquired_players']
        totals['maximum_break_even_cac_before_fixed_eur'] = max(0.0, totals['contribution_ltv_before_cac_eur'])
        totals['maximum_break_even_cac_after_fixed_eur'] = max(0.0, (totals['contribution_eur'] - totals['fixed_cost_eur']) / cohort['acquired_players'])
        totals['raw_break_even_cac_before_fixed_eur'] = totals['contribution_ltv_before_cac_eur']
        totals['raw_break_even_cac_after_fixed_eur'] = (totals['contribution_eur'] - totals['fixed_cost_eur']) / cohort['acquired_players']
        totals['break_even_before_fixed_feasible_at_zero_cac'] = totals['raw_break_even_cac_before_fixed_eur'] >= 0
        totals['break_even_after_fixed_feasible_at_zero_cac'] = totals['raw_break_even_cac_after_fixed_eur'] >= 0
        totals['beginner_packages'] = sum(row['purchases']['beginner'] for row in selected)
        horizons[str(horizon)] = totals
    return {'model': model_name, 'scenario': scenario_name, 'sensitivity': sensitivity_name, 'monthly': rows, 'horizons': horizons}


def utilities_from_report(report, model, profile, months):
    try:
        rows = report['models'][model]['profiles'][profile]['monthly']
        by_month = {int(row['month']): row['unsaturation_factor'] for row in rows}
        result = [by_month[m] for m in range(1, months + 1)]
    except (KeyError, TypeError, ValueError) as exc:
        raise ValueError(f'missing measured monthly utilities for {model}/{profile}') from exc
    if not all(_number(u, 0, 1) for u in result):
        raise ValueError('invalid measured collection utility')
    return result


def _summary(values):
    values = sorted(values)
    def quantile(probability):
        index = probability * (len(values) - 1)
        low = int(index)
        return values[low] + (values[min(low + 1, len(values) - 1)] - values[low]) * (index - low)
    return {'mean': statistics.mean(values), 'p05': quantile(.05), 'p95': quantile(.95)}


def analyse(config, collection_report):
    output = {'metadata': {'assumptions': config, 'uncertainty': '200 seeded finite-cohort Monte Carlo draws by default; p05/p95 are sampling outcomes, not empirical confidence or parameter uncertainty.', 'collection_linkage': 'paid4 calendar-age marginal utility is a deliberately saturated daily-player trajectory proxy; sparse-play inventory and endogenous purchase feedback are not modelled. Unique-gap utility may reach zero while playable copies are missing; playset-gap and paid40 alternative hypotheses are reported separately. None measures actual willingness to pay.', 'retention_semantics': 'Hypothetical survival of retained month members, with one activity at month start; active-player-days use a separate frequency assumption. No DAU inference. Accounting begins first-return day1.', 'payer_semantics': 'Distinct within each month; cumulative payer_months are not distinct annual payers. ARPPU is derived after product overlap and utility effects.'}, 'results': {}, 'behavior_sensitivities': {}, 'inventory_demand_sensitivity': {}, 'break_even_sensitivity': [], 'spending_sensitivity': [], 'steady_state_organic_sensitivity': []}
    for scenario in config['revenue_scenarios']:
        output['results'][scenario] = {}
        for model in config['models']:
            utility = utilities_from_report(collection_report, model, config['collection_demand']['profile'], config['cohort']['months'])
            expected = simulate_cohort(config, model, scenario, utility)
            samples = [simulate_cohort(config, model, scenario, utility, config['seed'] + n) for n in range(config['repetitions'])]
            intervals = {horizon: {metric: _summary([sample['horizons'][horizon][metric] for sample in samples]) for metric in expected['horizons'][horizon] if not isinstance(expected['horizons'][horizon][metric], bool)} for horizon in expected['horizons']}
            output['results'][scenario][model] = {'expected': expected, 'sampling_intervals': intervals}
    for sensitivity, definition in config.get('behavior_sensitivities', {}).items():
        output['behavior_sensitivities'][sensitivity] = {}
        for model in definition['apply_to_models']:
            utility = utilities_from_report(collection_report, model, config['collection_demand']['profile'], config['cohort']['months'])
            output['behavior_sensitivities'][sensitivity][model] = simulate_cohort(config, model, 'base', utility, sensitivity_name=sensitivity)
    for model in config['models']:
        try:
            rows = collection_report['models'][model]['profiles'][config['collection_demand']['profile']]['monthly']
            by_month = {int(row['month']): row for row in rows}
            playset_gap = [1 - by_month[month]['mean_playset_pct'] / 100 for month in range(1, config['cohort']['months'] + 1)]
        except (KeyError, TypeError, ValueError) as exc:
            raise ValueError('missing measured playset-gap sensitivity input') from exc
        heavy_utility = utilities_from_report(collection_report, model, 'paid40', config['cohort']['months'])
        output['inventory_demand_sensitivity'][model] = {
            'playset_gap_proxy': simulate_cohort(config, model, 'base', playset_gap),
            'paid40_daily_inventory_proxy': simulate_cohort(config, model, 'base', heavy_utility),
            'note': 'Alternative unvalidated pack-purchase hypotheses. A unique set is not a full playable set; playset gaps may sustain demand. Paid40 is a faster daily-player inventory trajectory, not an endogenous revenue segment.'}
    # Controlled scalar contours: vary payer propensity and acquisition cost;
    # retain the same measured inventory and base retention for every model.
    for model in config['models']:
        utility = utilities_from_report(collection_report, model, config['collection_demand']['profile'], config['cohort']['months'])
        for conversion in (.01, .02, .04, .08, .12):
            changed = copy.deepcopy(config)
            changed['revenue_scenarios']['base']['monthly_payer_probability'] = conversion
            result = simulate_cohort(changed, model, 'base', utility)
            horizon = result['horizons']['24']
            for cac in (0., .25, .5, 1., 2.):
                output['break_even_sensitivity'].append({'model': model, 'monthly_payer_probability': conversion, 'acquisition_cost_per_player_eur': cac, 'contribution_ltv_before_cac_eur': horizon['contribution_ltv_before_cac_eur'], 'profit_after_fixed_and_cac_eur': horizon['contribution_eur'] - horizon['fixed_cost_eur'] - cac * config['cohort']['acquired_players']})
        for multiplier in config.get('spending_sensitivity_multipliers', [.5, 1., 2., 4.]):
            changed = copy.deepcopy(config)
            for key in ('cosmetic_unit_gross_eur', 'season_pass_gross_eur', 'pack_gross_eur', 'beginner_package_gross_eur'):
                changed['products'][key] *= multiplier
            result = simulate_cohort(changed, model, 'base', utility)
            horizon = result['horizons']['24']
            output['spending_sensitivity'].append({'model': model, 'assumed_basket_spend_multiplier': multiplier, 'contribution_ltv_before_cac_eur': horizon['contribution_ltv_before_cac_eur'], 'net_revenue_ltv_eur': horizon['net_revenue_ltv_eur'], 'note': 'Monetary basket-value sensitivity only; no evidence of demand at altered prices or inventory feedback.'})
        # A separate stationary stream overlays age0..23 cohorts. It is NOT the
        # original closed cohort, and omits all contributions after month24.
        expected = output['results']['base'][model]['expected']['horizons']['24']
        base_ltv = expected['contribution_ltv_before_cac_eur']
        fixed = config['costs']['fixed_cost_per_month_eur']
        total_members = sum(row['retained_month_members'] for row in output['results']['base'][model]['expected']['monthly'])
        total_gross = expected['gross_spend_ex_vat_eur']
        payers = expected['payer_months']
        retained_cost = total_members * config['costs']['variable_per_retained_account_month_eur']
        payer_cost = payers * config['costs']['variable_per_payer_month_eur']
        net_fraction = (1 - config['costs']['refund_fraction']) * (1 - config['costs']['platform_fee_fraction'])
        for new_users in config.get('steady_state_organic_new_users_per_month', [10000, 50000, 100000]):
            scale = new_users / config['cohort']['acquired_players']
            required_gross = (fixed + (retained_cost + payer_cost) * scale) / net_fraction
            gross_per_payer_month = required_gross / (payers * scale) if payers else None
            # Gross and per-payer costs scale linearly with pre-utility intent;
            # retained-account cost is fixed at the controlled retention curve.
            intent_contribution = (expected['net_revenue_eur'] - payer_cost) * scale
            required_conversion = config['revenue_scenarios']['base']['monthly_payer_probability'] * (fixed + retained_cost * scale) / intent_contribution if intent_contribution > 0 else None
            output['steady_state_organic_sensitivity'].append({'model': model, 'monthly_organic_new_users': new_users, 'monthly_profit_before_acquisition_eur': new_users * base_ltv - fixed, 'minimum_monthly_organic_new_users_for_fixed_cost': fixed / base_ltv if base_ltv > 0 else None, 'required_gross_weighted_monthly_arppu_eur': gross_per_payer_month, 'required_pre_utility_monthly_payer_probability': required_conversion, 'conversion_threshold_feasible': required_conversion is not None and required_conversion <= 1, 'note': 'Separate stationary flow of 24 cohort ages; zero CAC assumed, older ages omitted. Required ARPPU holds payer counts fixed, required conversion holds basket assumptions fixed.'})
    return output


def run_revenue(config, collection_summary, output_dir, repetitions=None):
    config = copy.deepcopy(config)
    if repetitions is not None:
        config['repetitions'] = repetitions
    validate_config(config)
    result = analyse(config, collection_summary)
    destination = Path(output_dir)
    destination.mkdir(parents=True, exist_ok=True)
    (destination/'revenue_summary.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    write_report(result, destination/'REVENUE-SIMULATION.md')
    return result


def write_report(result, path):
    lines = ['# Illustrative cohort revenue sensitivity', '', 'All retention, conversion, baskets, spending and costs are hypothetical assumptions. Gross spending excludes VAT and precedes refunds/fees; no approved prices, forecast or purchase implementation.', '', '10,000 acquired accounts; one cohort, no new acquisition; 24 months. Fixed costs are attributed to this cohort. Sampling p05/p95 excludes assumption uncertainty.', '', '| Scenario | Model | 12m gross EUR | 24m gross EUR | 24m net LTV EUR | 24m contribution LTV EUR | 24m profit after fixed/CAC EUR |', '|---|---|---:|---:|---:|---:|---:|']
    for scenario, models in result['results'].items():
        for model, data in models.items():
            first, second = data['expected']['horizons']['12'], data['expected']['horizons']['24']
            lines.append(f"| {scenario} | {model} | {first['gross_spend_ex_vat_eur']:.0f} | {second['gross_spend_ex_vat_eur']:.0f} | {second['net_revenue_ltv_eur']:.3f} | {second['contribution_ltv_before_cac_eur']:.3f} | {second['operating_profit_after_acquisition_eur']:.0f} |")
    lines += ['', 'The complete JSON contains monthly product mix, actual distinct monthly payers, derived gross/net ARPPU, sampling bands, behavior conjectures and payer/CAC contours. Cumulative payer-months are not annual distinct payers.', '', 'No model-specific retention benefit is assumed. Inventory utility is an exogenous daily-player paid4 proxy; sparse-play timelines, whales, live product appeal, taxes and purchase feedback remain unmeasured. Full collection removes pack demand only; cosmetic demand is an independent assumption. Optional season passes and beginner bundles contain cosmetics only, with one beginner purchase maximum.']
    Path(path).write_text('\n'.join(lines) + '\n', encoding='utf-8')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', type=Path, default=DEFAULT_CONFIG)
    parser.add_argument('--collection-report', type=Path, default=ROOT/'docs/economy/monetization-results/collection_summary.json')
    parser.add_argument('--output', type=Path, default=ROOT/'docs/economy/monetization-results/revenue_summary.json')
    parser.add_argument('--markdown', type=Path, default=ROOT/'docs/economy/monetization-results/REVENUE-SIMULATION.md')
    args = parser.parse_args()
    config = load_config(args.config)
    collection = json.loads(args.collection_report.read_text(encoding='utf-8'))
    result = analyse(config, collection)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    write_report(result, args.markdown)
    print(f'Revenue assumptions: {len(config["models"])} models x {len(config["revenue_scenarios"])} scenarios x {config["repetitions"]} seeded cohorts; {args.output}')


if __name__ == '__main__':
    main()
