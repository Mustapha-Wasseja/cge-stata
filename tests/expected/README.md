# Expected simulation results

These files hold the Python reference model's solutions for the standard
simulations of docs/model_spec.md, validation check 7. The Stata test suite
compares its own results with them; the two implementations must agree to a
relative tolerance of 1e-6.

| File | Shock |
|---|---|
| `tariff_removal.csv` | all import tariff rates set to zero |
| `import_price_up10.csv` | world import prices raised by 10 per cent |
| `labour_supply_up5.csv` | labour supply raised by 5 per cent |
| `foreign_savings_down20.csv` | foreign savings reduced by 20 per cent |
| `agri_productivity_up5.csv` | value-added efficiency of `act_agr` raised by 5 per cent |
| `mixed_tariff_removal.csv` | all import tariff rates set to zero, with sector-specific elasticities (below) |
| `tc_*.csv` | the five shocks on the territorial-correction layout (`data/cge_synthetic_sam_tc.csv`, with an inventory run-down) |
| `mp_*.csv` | the five shocks on the multi-product layout (`data/cge_synthetic_sam_mp.csv`) |
| `cnm_*.csv` | the five shocks on the non-imported layout (`data/cge_synthetic_sam_cnm.csv`: a non-imported commodity with sales tax) |
| `margins_*.csv` | the five shocks on the margins layout (`data/cge_synthetic_sam_margins.csv`: margins netted out of `act_ser`) |
| `inst_*.csv` | the five shocks above on the institutions layout (`data/cge_synthetic_sam_inst.csv`: an enterprise and a non-profit institution) |
| `link_<case>_<region>.csv`, `link_<case>_routes.csv` | linked regions (version 0.12.0; `reference/cge_ref/regions.py`): the synthetic SAM (region A) and the institutions layout (region B, a SAM unit worth two world units) with the routes of `LINK_TRADE`; cases `base`, `fta` (no tariffs between the regions), `world` (the rest of the world's price of `com_man` up 10 per cent) and `prod` (efficiency of `act_man` in A up 5 per cent); each region's solution and the routes' quantities and prices |

Settings: the synthetic SAM (`data/cge_synthetic_sam.csv`); elasticities
`sigma_va = 0.8`, `sigma_q = 2.0` and `sigma_t = 2.0` for every sector, except in
`mixed_tariff_removal.csv`, which uses `sigma_va` = (0.5, 1.0, 1.5) for
(`act_agr`, `act_man`, `act_ser`), so `act_man` has Cobb-Douglas value added,
`sigma_q` = (0.6, 3.0, 1.2) and `sigma_t` = (0.7, 4.0, 1.0) for (`com_agr`,
`com_man`, `com_ser`); default
closure (flexible exchange rate, flexible government savings, savings-driven
investment, mobile fully employed factors, CPI numeraire); solver tolerance
1e-12 on scaled residuals.

Columns: `variable`, `element1`, `element2` (set elements, blank where not
applicable), `base` and `value`. Only existing elements are listed; for example,
there is no `QM` row for a commodity without imports.

Regenerate after any model change with:

```
python -m cge_ref.scenarios
```

run from the `reference` folder. The Python test suite fails if these files are
out of date.
