# Package design

This document sets out how `cge-stata` is organised and how version 0.1 will be
built. The model equations are in [model_spec.md](model_spec.md).

## 1. Principles

- **Stata 13 compatibility.** Every ado-file declares `version 13.0`, and the
  Mata code uses only functions available in Stata 13. The package must run on
  Stata/IC, so model arrays live in Mata rather than in Stata matrices, which
  are limited by `matsize`.
- **One specification, two implementations.** The Stata/Mata solver and the
  Python reference solver in `reference/` implement the same equations. The
  Python version runs in continuous integration; the Stata version is tested
  locally. Results must agree to 1e-6 relative tolerance.
- **No silent defaults for economic assumptions.** Elasticities and closures are
  stated by the user. A `default` keyword for elasticities exists for teaching
  and testing; output produced with it is labelled as such.
- **Checks bound to the values used.** Benchmark replication, Walras's law and
  closure counts are checked on the model actually solved, every time, and
  failures stop the command.

## 2. Commands (planned for version 0.1)

| Command | Purpose |
|---|---|
| `cge` | Package version and command list (available) |
| `cge_synthetic` | Load the synthetic SAM (available) |
| `cge_sam` | Import a SAM from a Stata dataset, CSV or Excel file; check that it is square, labelled consistently and balanced; aggregate accounts |
| `cge_map` | Assign SAM accounts to model roles: activities, commodities and their pairing, factors, households, government, tax accounts, savings-investment, rest of world |
| `cge_calibrate` | Compute base values and parameters from the mapped SAM and the elasticities; run the benchmark replication check |
| `cge_closure` | Choose closures for the external account, government, savings-investment, each factor and the numeraire; check that the system is square |
| `cge_shock` | Change exogenous values: tax rates, world prices, factor supplies, productivity, foreign savings, transfers |
| `cge_solve` | Solve the model and store a named simulation |
| `cge_results` | Report changes from the base for macro aggregates, sectors, prices, factor returns and household welfare (equivalent variation); export to a dataset or Excel |
| `cge_check` | Run the validation checks of model_spec.md, Section 8 |

Illustrative workflow (planned syntax, subject to change during development):

```stata
cge_synthetic, clear
cge_sam, from(memory) labels(account)
cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)       ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_closure, external(flexexr) government(flexgsav) savinv(savings) numeraire(cpi)
cge_shock tm, commodities(all) scale(0)
cge_solve, name(notariff)
cge_results, sim(notariff)
```

## 3. Data structures

- The SAM, the account mapping, the calibrated parameters, the base solution and
  each named simulation are held in a Mata structure stored as a Mata external
  global (`cge_model`), so that successive commands share the model.
- Variables are packed into one column vector for the solver, with an index
  table recording each variable's block, set elements and position. Fixed
  variables under the active closure are removed from the solver vector and
  held at their values.
- Results are written back to Stata as a long dataset (variable, element, base
  value, simulated value, change) for reporting and export.

## 4. Solver

- Mata `solvenl()` with Newton–Raphson and a numerical Jacobian is the default.
- Variables are scaled by their base values, and equations by base magnitudes,
  so that residual tolerances are comparable across blocks.
- If Newton–Raphson fails, the solver retries with damped Newton steps from the
  last good point and reports which equations have the largest residuals.
- Analytical Jacobians may be added later for large SAMs; they must be checked
  against numerical derivatives in the test suite.

## 5. Mata code organisation

During development, Mata functions live in `.mata` source files under `ado/`
and are loaded with `run` the first time a command needs them. For releases they
will be compiled into a Mata library (`lcge.mlib`) on Stata 13 so that one
library serves Stata 13 and later.

## 6. Testing

| Suite | Where it runs | Contents |
|---|---|---|
| `reference/tests` (pytest) | continuous integration and locally | synthetic SAM; Python reference model; validation checks |
| `tests/*.do` (Stata) | locally, via `tools/run_stata_tests.ps1` | package loading; SAM import; calibration; validation checks; agreement with stored Python results |

The Python suite writes its simulation results to `tests/expected/` as CSV
files. The Stata suite compares its own results with those files, which ties the
two implementations together without requiring Stata in continuous integration.

## 7. Roadmap

| Version | Content |
|---|---|
| 0.1 | Standard static model of model_spec.md; validation suite; documentation and worked example on the synthetic SAM |
| 0.2 | LES household demand; import-only and export-only commodities; multi-product activities; inter-household transfers and enterprises |
| 0.3 | SAM tools: aggregation, RAS and cross-entropy balancing, elasticity tables |
| 0.4 | Recursive dynamics: capital accumulation, labour force growth, baseline calibration to growth targets |
| 0.5 | Top-down link to household microsimulation |
