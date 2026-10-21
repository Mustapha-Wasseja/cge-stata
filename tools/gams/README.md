# Independent check in GAMS

`ado/cge_model.gms` implements the static model of
[docs/model_spec.md](../../docs/model_spec.md) (Sections 5 to 7) in GAMS. It
was written from the specification, not translated from the Stata or Python
code, so that a third implementation, in the language most CGE modellers use,
confirms the equations and the calibration. From version 0.4.3 the GAMS files
are installed with the package: `cge_gams` writes a model in Stata for this
GAMS program (docs/gams.md).

GAMS receives only what a user supplies:

- the SAM, after the layout rewrites of Section 7.0, which `cge_ref.prepare`
  performs;
- the mapping of accounts to roles;
- the elasticities and other calibration settings.

It calibrates every parameter itself, solves the base and each scenario, and
writes the solutions. Shocks are passed as changes to GAMS's own calibrated
parameters and fixed variables (for example, "world import prices times 1.1").

## Files

| File | Content |
|---|---|
| `ado/cge_model.gms` | data, calibration, equations, base solve; saves a GAMS work file |
| `ado/cge_closure.gms` | bounds, variables that do not exist, and the closure (Section 6) |
| `ado/cge_solve.gms` | the solve statement, for the chosen solver and model type |
| `ado/cge_write.gms` | writes a solution as `scenario, variable, element1, element2, value` |
| `cge_scenario.gms` | restarts from the work file, applies a scenario's shocks and closure, solves |
| `run_gams_check.py` | runs every case and compares the results |
| `gams_check_results.csv` | results of the last run with PATH, one row per scenario |
| `export_check.do`, `run_export_check.py` | the check of `cge_gams`: models exported from Stata and solved in GAMS |
| `export_check_results.csv` | its results, one row per case and solver |

## Running it

```
python tools/gams/run_gams_check.py [--gams C:/GAMS/54/gams.exe] [--work DIR]
    [--solver path|conopt|knitro|ipopt] [--type cns|nlp] [--only TEXT]
python tools/gams/run_export_check.py [--stata PATH] [--gams PATH] [--solver ...] [--type ...]
```

GAMS is required, with PATH for the default solver. The export check also
needs Stata for Windows, which it runs in batch mode.

The model is solved as a constrained nonlinear system (`--type cns`, with
PATH, CONOPT or KNITRO). With `--type nlp` it is solved as a nonlinear
programme with a constant objective, for NLP solvers such as IPOPT.

Work files, Stata logs and GAMS listings go to a temporary directory (outside
any synced folder by default). Listings and logs name the licence holders, so
they are not kept in the repository.

## What is compared

Every case of the Python test suite:

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
  employment, and left by moving to full employment (from version 0.3.3);
- days lost to illness responding to health services, alone and with the
  efficiency link, an epidemic, and unemployed labour (from version 0.3.4;
  the death rate enters only dynamic runs, which are not checked in GAMS);
- factor quantities, so that base wages and wage distortions differ from one,
  with CES and mixed elasticities and with a minimum wage (from version
  0.4.3; compared with the Python reference);
- constraints (from version 0.4.4): import quotas with rents to the
  government, households or abroad, quotas that do not bind or sit at the
  base, an export quota, capacity limits on services and on health services,
  a borrowing limit under a peg, a ban on government borrowing with spending
  or taxes adjusting, a floor on the nominal wage, and two constraints at
  once. GAMS solves them as mixed complementarity problems with PATH
  (`--cgetype=mcp`), against the Python reference, which finds the regimes by
  an active-set method;
- closure swaps (from version 0.4.5): government savings fixed with
  government consumption adjusting, and the exchange rate as numeraire.

For each case, every scenario is compared with the expected results in
`tests/expected`, which the Stata suite also matches. Alternative closures
are compared with the Python reference:

- fixed exchange rate, fixed government savings, investment-driven savings,
  DPI numeraire and capital specific to each activity;
- unemployed labour.

## Result (21 October 2026, GAMS 54.2, PATH)

169 scenarios; every expected value was found and solved.

- Base values from GAMS's own calibration agree to 4.9e-15 or better.
- Solutions agree to 2.9e-11 or better, relative to the larger of 1 and the
  value.
- WALRAS is zero in both, up to rounding (9.6e-11 at most).
- The 13 scenarios with constraints, solved as mixed complementarity problems,
  agree to 2.4e-12 or better, with every regime as in the Python reference.

On a 54-account synthetic health SAM (535 equations; testing work outside the
repository), GAMS agrees with the Python reference to 1.9e-9 in all 13
scenarios. That limit is set by PATH's convergence tolerance on an economy of
6.1 million.

**Other solvers** (version 0.4.3, the 10 scenarios of the standard layout):

| Solver | Type | Solved | Base | Solutions | WALRAS |
|---|---|---|---|---|---|
| CONOPT | CNS | 10 of 10 | 3.1e-16 | 1.3e-9 | 1.2e-8 |
| KNITRO | CNS | 10 of 10 | 3.1e-16 | 3.2e-14 | 2.9e-13 |
| IPOPT | NLP | 10 of 10 | 3.0e-15 | 3.6e-14 | 1.2e-13 |

CONOPT and KNITRO ran under the GAMS demo licence, which covers small models.
CONOPT stops at a looser feasibility tolerance than the others.

## Export check (version 0.4.3)

`run_export_check.py` checks `cge_gams` on the 17 cases of `export_check.do`.
For each case:

1. Stata solves the case and exports it.
2. GAMS calibrates and solves the exported model.
3. Stata compares the results.

The results are in [docs/gams.md](../../docs/gams.md), Section 5.
