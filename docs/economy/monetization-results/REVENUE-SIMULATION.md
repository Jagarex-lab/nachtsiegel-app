# Illustrative cohort revenue sensitivity

All retention, conversion, baskets, spending and costs are hypothetical assumptions. Gross spending excludes VAT and precedes refunds/fees; no approved prices, forecast or purchase implementation.

10,000 acquired accounts; one cohort, no new acquisition; 24 months. Fixed costs are attributed to this cohort. Sampling p05/p95 excludes assumption uncertainty.

| Scenario | Model | 12m gross EUR | 24m gross EUR | 24m net LTV EUR | 24m contribution LTV EUR | 24m profit after fixed/CAC EUR |
|---|---|---:|---:|---:|---:|---:|
| pessimistic | baseline96 | 476 | 490 | 0.033 | 0.018 | -127820 |
| pessimistic | scarcity | 504 | 519 | 0.035 | 0.020 | -127801 |
| pessimistic | protected_weekly | 482 | 497 | 0.034 | 0.018 | -127816 |
| pessimistic | cosmetics_first | 520 | 538 | 0.036 | 0.021 | -127789 |
| base | baseline96 | 2526 | 2785 | 0.189 | 0.152 | -126476 |
| base | scarcity | 2671 | 2929 | 0.199 | 0.162 | -126378 |
| base | protected_weekly | 2561 | 2820 | 0.191 | 0.155 | -126452 |
| base | cosmetics_first | 2801 | 3108 | 0.211 | 0.174 | -126260 |
| optimistic | baseline96 | 7172 | 8616 | 0.585 | 0.513 | -122873 |
| optimistic | scarcity | 7559 | 9004 | 0.611 | 0.539 | -122611 |
| optimistic | protected_weekly | 7271 | 8716 | 0.592 | 0.519 | -122806 |
| optimistic | cosmetics_first | 8056 | 9772 | 0.664 | 0.590 | -122101 |

The complete JSON contains monthly product mix, actual distinct monthly payers, derived gross/net ARPPU, sampling bands, behavior conjectures and payer/CAC contours. Cumulative payer-months are not annual distinct payers.

No model-specific retention benefit is assumed. Inventory utility is an exogenous daily-player paid4 proxy; sparse-play timelines, whales, live product appeal, taxes and purchase feedback remain unmeasured. Full collection removes pack demand only; cosmetic demand is an independent assumption. Optional season passes and beginner bundles contain cosmetics only, with one beginner purchase maximum.
