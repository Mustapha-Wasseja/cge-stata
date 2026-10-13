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
| `inst_*.csv` | the five shocks above on the institutions layout (`data/cge_synthetic_sam_inst.csv`: an enterprise and a non-profit institution) |

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
