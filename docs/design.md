# Package design

This document sets out how `cge-stata` is organised. The model equations are in
[model_spec.md](model_spec.md).

## 1. Principles

- **Stata 13 compatibility.** Every ado-file declares `version 13.0`, and the
  Mata code uses only functions available in Stata 13. The package runs on
  Stata/IC: model arrays live in Mata rather than in Stata matrices, which are
  limited by `matsize`.
- **One specification, two implementations.** The Stata/Mata implementation and
  the Python reference implementation in `reference/` implement the same
  equations. The Python version runs in continuous integration; the Stata
  version is tested locally. Results must agree to 1e-6 relative tolerance; in
  version 0.1 they agree to about 1e-13.
- **No defaults for economic assumptions.** Elasticities have no default values
  and must be stated in `cge_calibrate`. The closure starts from the documented
  default and is displayed with every simulation.
- **Checks bound to the values used.** Benchmark replication is checked on
  every calibration and stops the command if it fails. `cge_check` runs the
  checks of model_spec.md, Section 8, on the model and simulation actually
  solved.

## 2. Commands

| Command | Purpose |
|---|---|
| `cge` | Package version and command list |
| `cge_synthetic` | Load the synthetic SAM |
| `cge_sam` | Read a SAM from memory or from a CSV, Stata or Excel file; check that it is square and consistently labelled; report its balance |
| `cge_map` | Assign SAM accounts to model roles and check the SAM against the supported flows (model_spec.md, Section 7.0) |
| `cge_calibrate` | Compute base values and parameters from the mapped SAM and the elasticities; check benchmark replication |
| `cge_closure` | Choose closures for the external account, government, savings-investment, the numeraire and each factor; check that the system is square |
| `cge_shock` | Change tax rates, world prices or productivity, or any variable fixed by the closure (factor supplies, foreign savings, and so on) |
| `cge_solve` | Solve the model and store a named simulation |
| `cge_results` | Display a summary of changes from the base, including household equivalent variation; load or save all results as a dataset |
| `cge_check` | Run the validation checks of model_spec.md, Section 8 |

Typical workflow:

```stata
cge_synthetic, clear
cge_sam, labels(account)
cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)       ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_closure, external(flexexr) government(flexgsav) savinv(savings) numeraire(cpi)
cge_shock tm, value(0)
cge_solve, name(notariff)
cge_results, sim(notariff)
cge_check, homogeneity perturb(0.1)
```

## 3. Data structures

- The SAM, the account mapping, the base and current parameters, the base
  solution, the closure and every named simulation are held in one Mata
  structure (`cge_model`), stored as the Mata global `cge__model` so that
  successive commands share the model. `cge_sam` starts a new model.
- All variables are stacked in one column vector, with a layout table giving
  each variable's offset, dimensions and index sets. Element order is row-major,
  matching the Python reference. Variables that do not exist (for example
  imports of a commodity that is not imported) stay in the vector at zero and
  are excluded from the solver.
- Results are written back to Stata as a long dataset (`variable`, `element1`,
  `element2`, `base`, `value`), the same layout as the expected-results files.

## 4. Solver

- Newton–Raphson with a backtracking line search on the residual norm, the
  same algorithm as the Python reference.
  Variables are scaled by their base values and equations by their base
  magnitudes, so the tolerance applies uniformly across blocks.
- Points with non-positive prices or quantities are rejected explicitly, because
  Mata's sum functions treat missing values as zero.
- If Newton–Raphson fails, Powell's hybrid method (`solvenl()`, technique
  `broydenpowell`) is tried, followed by Newton steps to polish the result.
- Jacobian (from version 0.1.9). Rows of the aggregate equations, which each
  involve many variables (P8, P9, I1, I8, I9, S1, S3 and S5), have exact
  derivatives. The other rows are sparse: their pattern follows from the
  equations and is built at calibration, and their derivatives are central
  differences taken over groups of columns that share none of these rows
  (Curtis, Powell and Reid, 1974; greedy colouring, most connected columns
  first). One pair of residual evaluations per group replaces one pair per
  column. The test suite compares this Jacobian with column-by-column central
  differences on every synthetic layout, after shocks and under another
  closure. Before version 0.1.9 the Jacobian was column by column: on a
  240-account SAM (4,439 equations) it took about 250 seconds per Newton
  iteration on Stata 13/IC, against a dense LU solve of under 3 seconds.
- Solve times on Stata 13/IC for a tariff shock before version 0.1.9: 93
  equations (3 sectors), under one second; 561 equations (15 sectors), about
  3 seconds; 1,551 equations (30 sectors), about 12 seconds.

## 5. Mata code organisation

The Mata code is in `ado/cge_mata.mata`. `_cge_load` runs it the first time a
command needs it in a Stata session. During development, run `clear all` (or
`mata: mata clear`) after editing the file so that the new version is loaded.
For releases the code may be compiled into a Mata library (`lcge.mlib`) on
Stata 13, so that one library serves Stata 13 and later.

## 6. Testing

| Suite | Where it runs | Contents |
|---|---|---|
| `reference/tests` (pytest) | continuous integration and locally | synthetic SAM; calibration; validation checks; dual unit-cost checks; closures; direction of effects |
| `tests/*.do` (Stata) | locally, via `tools/run_stata_tests.ps1` | Mata solver; synthetic SAM; agreement with the Python results for six simulations; validation checks; all 64 closure combinations; alternative closures; factor quantities; error handling |

The Python suite writes its simulation results to `tests/expected/` as CSV
files. The Stata suite compares its own results with those files, which ties the
two implementations together without requiring Stata in continuous integration.

## 7. Roadmap

| Version | Content |
|---|---|
| 0.1 | Standard static model of model_spec.md; validation suite; documentation and worked example on the synthetic SAM |
| 0.1.1 | Taxes paid directly to the government account and exports recorded in activity rows, rewritten when the SAM is mapped (done) |
| 0.1.2 | Enterprises; non-profit institutions mapped as households; transfers among institutions, within government and with the rest of the world; factor income from abroad (done) |
| 0.1.3 | Margins netted out of margin activities, moved to their output when the SAM is mapped, so that margins enter as the producers' purchases of trade and transport services (done) |
| 0.1.4 | Multi-product activities with fixed yields (including negative secondary sales, reported as notes); the territorial correction rewritten as household transfers to and from the rest of the world; inventory run-downs; equation T6 corrected for non-imported commodities with sales tax (done) |
| 0.1.5 | CET and Armington share complements stored at calibration, so that benchmark replication holds when one share is close to one (low elasticity, very small trade share) (done) |
| 0.1.6 | Homogeneity and perturbed-start checks independent of the SAM's units: WALRAS measured against the largest SAM entry (done) |
| 0.1.7 | Supply-use layouts: margin accounts paid by commodities (margin services per unit of composite supply), commodities imported only, stock-change accounts merged into savings-investment, and account labels that are not valid Stata names (done) |
| 0.1.8 | Exports drawn from composite supply, with a price-elastic export function, for commodities whose exports are at least their domestic output (re-exports, exports from inventories, exports at purchaser prices) (done) |
| 0.1.9 | Faster Jacobian: exact derivatives for the aggregate equations and grouped central differences for the sparse rest; the fallback solver repaired (solvenl() takes at most three extra arguments in Stata 13) (done) |
| 0.2 | Export-only commodities; LES household demand; elasticity tables; margins that differ between domestic sales, imports and exports, once margin data by market are available |
| 0.3 | SAM tools: aggregation, RAS and cross-entropy balancing, elasticity tables |
| 0.4 | Recursive dynamics: capital accumulation, labour force growth, baseline calibration to growth targets |
| 0.5 | Top-down link to household microsimulation |

## 8. First trial on a national SAM

In October 2026 version 0.1 was tried on an 85-account national SAM built from
the national accounts (38 activities, 38 products, 2 factors, 5 institutions,
capital, rest of the world). The SAM balanced, but `cge_map` found 238 cells
representing flows outside version 0.1, 15.8 per cent of the sum of absolute
cell values. Grouped by the feature they need, the largest are: corporations and
non-profit institutions (about 7 per cent); exports recorded as sales by
activities (3.5 per cent); taxes paid directly to the government account
(2 per cent); trade and transport margins recorded as negative own use by the
trade and transport activities (2 per cent); and secondary production
(0.4 per cent). Version 0.1.1 handles the export and tax layouts, which reduced
the unsupported share to 10.2 per cent, and version 0.1.2 (institutions and
transfers) to 2.6 per cent, and version 0.1.3 (margins netted out of the trade
and transport activities) to 0.67 per cent. With version 0.1.4 every flow is
represented; the SAM calibrates (2,005 equations, largest base residual
3.3e-14), passes all checks of `cge_check`, and a 25 per cent world oil price
shock solves in 5 Newton iterations (about 16 seconds on Stata 13/IC). The trial
also exposed a bug in equation T6 for non-imported commodities with sales tax,
which no synthetic SAM exercised; a synthetic test now covers it.
Country data are not stored in this repository.
