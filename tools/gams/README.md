# Independent check in GAMS

`cge_model.gms` implements the static model of
[docs/model_spec.md](../../docs/model_spec.md) (Sections 5 to 7) in GAMS. It
was written from the specification, not translated from the Stata or Python
code, so that a third implementation, in the language most CGE modellers use,
confirms the equations and the calibration.

GAMS receives only what a user supplies: the SAM (after the layout rewrites of
Section 7.0, which `cge_ref.prepare` performs), the mapping of accounts to
roles, and the elasticities. It calibrates every parameter itself, solves the
base and each scenario as a constrained nonlinear system with PATH, and writes
the solutions. Shocks are passed as changes to GAMS's own calibrated
parameters and fixed variables (for example, "world import prices times 1.1").

## Files

| File | Content |
|---|---|
| `cge_model.gms` | data, calibration, equations, base solve; saves a GAMS work file |
| `cge_scenario.gms` | restarts from the work file, applies a scenario's shocks and closure, solves |
| `closure.gms` | bounds, variables that do not exist, and the closure (Section 6) |
| `write.gms` | writes a solution as `scenario, variable, element1, element2, value` |
| `run_gams_check.py` | runs every case and compares the results |
| `gams_check_results.csv` | results of the last run, one row per scenario |

## Running it

```
python tools/gams/run_gams_check.py [--gams C:/GAMS/54/gams.exe] [--work DIR]
```

GAMS with the PATH solver is required. Work files and GAMS listings go to a
temporary directory (outside any synced folder by default). Listings name the
licence holder, so they are not kept in the repository.

## What is compared

Every case of the Python test suite, including:
- the standard, institutions, margins, territorial, multi-product,
  non-imported and supply-use layouts;
- mixed elasticities, the top nest and LES demand;
- the health insurance fund and the health link;
- VAT with input credits, VAT within the sales tax and a VAT introduced where
  the SAM has none, revenue-neutral closures (direct, sales, import and VAT
  rates adjusting) and public debt with interest (from version 0.3.1);
- home consumption, with Cobb-Douglas and LES demand; an export-only cash
  crop; margins on domestic sales, imports and exports; and finite export
  demand (from version 0.3.2);
- a wage curve and a minimum wage, binding in the base or reached from full
  employment, and left by moving to full employment (from version 0.3.3).

For each case, every scenario is compared with the expected results in
`tests/expected`, which the Stata suite also matches. Alternative closures
are compared with the Python reference:
- fixed exchange rate, fixed government savings, investment-driven savings,
  DPI numeraire and capital specific to each activity;
- unemployed labour.

## Result (20 October 2026, GAMS 54.2, PATH)

130 scenarios; every expected value was found and solved.

- Base values from GAMS's own calibration agree to 5e-15 or better.
- Solutions agree to 3e-11 or better, relative to the larger of 1 and the
  value.
- WALRAS is zero in both, up to rounding.

On a 54-account synthetic health SAM (535 equations; testing work outside the
repository), GAMS agrees with the Python reference to 1.9e-9 in all 13
scenarios. That limit is set by PATH's convergence tolerance on an economy of
6.1 million.
