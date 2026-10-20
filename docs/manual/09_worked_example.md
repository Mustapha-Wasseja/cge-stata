# 9. A worked example: from a raw SAM to results

`examples/raw_sam_to_results.do` takes an unbalanced SAM through every step of
the workflow. The SAM and the household survey are SYNTHETIC: they are
constructed for testing and describe no country. The elasticities are
published values for Togo, applied to the synthetic SAM only to show the
commands, so the results illustrate the workflow and are not findings about
any country. The numbers below are those of Stata 13.1; the do-file declares
`version 13.0`, so its random draws are the same in later versions.

## 9.1 The raw SAM

```stata
cge_synthetic, clear unbalanced
cge_sam, labels(account)
```

The SAM has 17 accounts and a total of 1,860.5; its largest difference
between an account's row and column totals is 12.1. It has two household
accounts, households (`hhd`) and non-profit institutions (`npi`), and an
enterprise.

## 9.2 Roles, aggregation and balancing

`cge_template` writes the template; the do-file fills it in, as one would in
Excel, and merges `hhd` and `npi` into one household group, `hh`.
`cge_aggregate using` merges them (16 accounts) and `cge_balance, method(ce)
totals(hh:290)` balances the SAM by cross entropy, taking household income as
known. The method converges in 4 iterations: the largest imbalance falls to
6e-14, 61 of the 63 non-zero cells change, and the SAM total rises to 1,943.8.
The table of the largest changes shows where the data were adjusted (labour
income of households rises by 10.5 per cent, for example). These are the
changes to report with any result.

`cge_map using` the same template maps the SAM: 3 activities, 3 commodities, 2
factors, 1 household group and 1 enterprise, with no unsupported flows.

## 9.3 Elasticities and calibration

```stata
cge_elasticities sigmaq, country(TGO) values      // 0.620 for each commodity
cge_elasticities sigmat, country(TGO) values      // 0.542
cge_elasticities sigmava, country(AFR) values     // 0.5897
cge_elasticities incelas, country(TGO) values map(com_agr:food) others(other)
cge_elasticities frisch, values                   // -1.3661
cge_calibrate, sigmava(`va') sigmaq(`sq') sigmat(`st') incelas(`ie') frisch(`fr')
```

The income elasticities are 0.804 for food (agriculture) and 1.913 for the
other commodities (the "other" category); demand is LES. The model has 98
equations; benchmark replication holds to 7e-16, and every check of `cge_check,
homogeneity perturb(0.1)` passes. `cge_parameters` shows the implied rates:
import tariffs of 10.6 per cent on agriculture and 9.8 per cent on
manufactures, sales taxes of 5.7 to 7.7 per cent, and a direct tax rate of 6.6
per cent on households.

## 9.4 Three policy simulations

| Measure (per cent change) | Tariffs removed | Tariffs removed, direct tax replaces revenue | Government services +20% |
|---|---|---|---|
| Real GDP | 0.03 | 0.10 | -0.15 |
| Real consumption | 2.50 | -0.35 | 0.06 |
| Real investment | -11.86 | 4.02 | -16.58 |
| Real exports | 1.34 | 2.12 | -2.05 |
| Exchange rate | 4.62 | 4.68 | -0.50 |
| Government revenue | -10.46 | 1.02 | -0.72 |
| Equivalent variation (per cent of consumption) | 2.48 | -0.36 | 0.06 |

The closure matters as much as the shock. With government savings flexible,
the lost tariff revenue (8.2, or 11 per cent of revenue) becomes a larger
deficit; with savings-driven investment, investment falls by 11.9 per cent and
consumption rises. With direct taxes replacing the revenue, households pay for
it: consumption falls slightly and investment rises. The exchange rate
depreciates by 4.6 to 4.7 per cent in both cases, which raises exports. More
government purchases of services crowd out investment under the same closure.

`cge_report, ... saving("results.xlsx")` writes every table to Excel.

## 9.5 Sensitivity

`cge_sensitivity, scenario(tariff_cut) draws(50) spread(0.5)` recalibrates the
model for 50 draws of the elasticities, each within plus or minus 50 per cent
of the central values, sector by sector. All 50 converge. The welfare result
barely moves (equivalent variation 2.48 per cent; 5th to 95th percentile 2.48
to 2.49), nor does investment (-12.2 to -11.6 per cent), because they are set
by the closure. Trade responds more: exports rise by 0.9 to 1.8 per cent and
the exchange rate depreciates by 4.0 to 5.2 per cent.

## 9.6 Dynamics

A baseline (`cge_dynamic, ... gdpgrowth(0.04)`) grows real value added by 4 per
cent a period, with capital that accumulates from investment and is specific
to each activity; the efficiency factors that achieve it fall from 2.4 to 2.0
per cent a period. The scenario removes tariffs from period 1 with the
baseline's efficiency path (`baseline(base) shocks(tariff_from1)`). Because the
static closure lowers investment, capital grows more slowly: by period 5,
output is 2.2 per cent below the baseline in manufacturing, 1.4 per cent in
agriculture and 0.8 per cent in services, and real value added is about 1.4
per cent below it. The static gain in consumption has a dynamic cost, which a
static run does not show.

## 9.7 Poverty and inequality

The SYNTHETIC survey has 1,000 households with wages, profits and government
transfers, and budget shares for food, goods and services. Passing the
direct-tax simulation to it (`cge_microsim`), real consumption per person rises
by 0.64 per cent; the headcount ratio falls from 23.09 to 22.97 per cent and
the Gini coefficient is unchanged at 36.3 per cent. The households' gain
differs from the group's equivalent variation (-0.36 per cent) because they
keep their own income composition (here mostly wages, with no transfers from
enterprises) and budget shares, and because real consumption is not a welfare
measure. A real survey would map every income source of the households.

## 9.8 Saving the model

`cge_save` writes the model with its 15 simulations; `cge_use` reloads it and
`cge_report` reproduces the results without solving again.
