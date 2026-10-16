# cge-stata

Computable general equilibrium (CGE) modelling in Stata.

`cge-stata` builds, calibrates and solves single-country CGE models from a
social accounting matrix (SAM) entirely within Stata and Mata. No external
modelling system (GAMS, GEMPACK or similar) is required.

## Status

Version 0.2.1 implements the standard single-country model described in
[docs/model_spec.md](docs/model_spec.md):

- CES or Cobb-Douglas value added, Leontief intermediate inputs; a Leontief,
  CES or Cobb-Douglas nest between value added and intermediate inputs (version
  0.1.12); activities may produce several commodities in fixed proportions
  (version 0.1.4);
- CET transformation between exports and domestic sales, Armington aggregation
  of imports and domestic goods;
- households with Cobb-Douglas or, from version 0.1.11, linear expenditure
  system (LES) demand (non-profit institutions can be mapped as households),
  enterprises, and transfers among institutions and with the rest of the world
  (version 0.1.2);
- government with direct, sales, import, export and activity taxes,
  savings-investment and the rest of the world;
- a social health insurance fund (version 0.1.13), financed by contributions on
  factor income and by transfers from the government and the rest of the world,
  which buys health services with its revenue less a fixed share saved;
- factors in efficiency units (version 0.1.14): an exogenous efficiency for each
  factor, and optionally an efficiency that rises with the volume of health
  services consumed, with an elasticity for each factor;
- selectable closures for the external account, government, savings-investment,
  the numeraire and each factor (mobile, activity-specific or unemployed);
- SAMs in national-accounts layout: exports recorded as sales by activities,
  taxes paid directly to the government account (version 0.1.1), trade and
  transport margins netted out of the margin activities (version 0.1.3), the
  territorial correction and inventory run-downs (version 0.1.4);
- SAMs in supply-use layout (version 0.1.7): margin accounts paid by
  commodities, commodities that are imported only, separate stock-change
  accounts, and account labels that are not valid Stata names (such as `s-i`);
- exports at least as large as domestic output, such as re-exports and exports
  from inventories, drawn from composite supply (version 0.1.8).

Version 0.1.9 speeds up the solver for large SAMs: the Jacobian combines exact
derivatives for the aggregate equations with grouped central differences for
the sparse rest (on a 4,439-equation model, about 3 seconds instead of about
250). It also repairs the fallback solver, which failed in Stata 13.
Version 0.1.10 adds shocks to government and investment demand by product and to
transfers, such as public spending on health services or donor funding.
Version 0.1.13 adds shocks to the fund's contribution rates, purchases and
transfers received; version 0.1.14 adds shocks to factor efficiency.
Version 0.2.0 adds recursive dynamics (`cge_dynamic`). Capital accumulates from
investment, which is allocated among activities by relative rental rates. Other
factors, population, government and foreign flows grow at given rates.
Efficiency grows at a given rate or is calibrated to a GDP growth target, and
scenarios reuse the baseline's efficiency path. Shocks can vary over time.
Every period is stored as a simulation for `cge_report`, and `cge_dynresults`
compares a run with its baseline. Five runs agree with the Python reference to
about 1e-13 in every period.
Version 0.2.1 adds sensitivity analysis (`cge_sensitivity`). It runs Monte Carlo
draws of the elasticities, recalibrates the model for each draw, and gives the
distribution of every report measure.
Version 0.2.0 also solves much larger models. Explicit definitions are left out of
the Newton system, and the rows with many variables get exact derivatives. LU
factors are reused across Newton steps. A synthetic SAM with 250 activities and
20 households (40,190 equations, 4,254 solved) solves a tariff removal in about
3 minutes on a laptop with Stata 13; see [tools/bench](tools/bench/README.md).
Stata IC limits a SAM to about 2,040 accounts (2,048 variables).
Version 0.1.15 adds standard report tables for several simulations side by side
(macroeconomic aggregates, government, institutions, factors, sectors, health,
and equivalent and compensating variations), to screen, Stata or Excel
(`cge_report`); the calibrated parameters as a dataset (`cge_parameters`); and
saving and loading a model with its simulations (`cge_save`, `cge_use`).

Version 0.1.5 keeps benchmark replication exact when a CET or Armington share
is close to one, as with a low elasticity and a very small trade share.
Version 0.1.6 makes the homogeneity and perturbed-start checks independent of
the units of the SAM.

| Milestone | Status |
|---|---|
| Model specification | complete |
| Python reference implementation and validation suite | complete |
| Stata/Mata implementation | complete; agrees with the reference to about 1e-13 |
| Application to country SAMs | an 85-account national SAM and a 240-account SAM in supply-use layout (4,439 equations) calibrate, pass all checks and solve shocks; policy simulations not yet done |

The model has been validated against the Python reference on synthetic SAMs,
and calibrated on one national SAM with illustrative elasticities. When applying
it to a country SAM, run `cge_check, homogeneity perturb(0.1)` and review the
elasticity choices; the package has not yet been used for published policy
analysis.

## Requirements

Stata 13 or later (Stata/IC is sufficient). No other Stata packages are needed.

## Installation

Install directly from GitHub:

```stata
net install cge, from("https://raw.githubusercontent.com/Mustapha-Wasseja/cge-stata/main/") replace
```

or from a local copy of the repository (cloned, or downloaded as a ZIP file
from GitHub):

```stata
net install cge, from("C:/path/to/cge-stata") replace
```

To run the test suite, use a local copy of the repository and, in Stata, run
`do run_all.do` from its `tests` folder. Each test prints `PASS` or `FAIL`, and
the last line is a summary.

## Quick start

```stata
cge_synthetic, clear
cge_sam, labels(account)
cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)       ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_shock tm, value(0)
cge_solve, name(notariff)
cge_results, sim(notariff)
cge_check, homogeneity perturb(0.1)
cge_report, sims(notariff) saving(notariff.xlsx, replace)
cge_save using mymodel, replace
```

See [examples/tariff_removal.do](examples/tariff_removal.do) for a worked
example, and `help cge` for the command list.

## Documentation

- [docs/model_spec.md](docs/model_spec.md): equations, calibration, closures
  and validation checks.
- [docs/design.md](docs/design.md): commands, data structures, solver, testing
  and roadmap.
- [CONTRIBUTING.md](CONTRIBUTING.md): development conventions.

## Validation

Every calibration is checked for benchmark replication. `cge_check` tests SAM
balance, closure consistency, Walras's law, the GDP identity, homogeneity and
convergence from perturbed starting values. A Python reference implementation
of the same equations (`reference/`) runs in continuous integration; the Stata
test suite compares its results with the reference (about 90 simulations, to
about 1e-13). From version 0.1.16 an independent implementation in GAMS
([tools/gams](tools/gams/README.md)), written from the specification and
calibrated from the SAM alone, reproduces every case: 84 scenarios across all
layouts, features and several closures, to 2e-11 or better.

## Author

Mustapha Wasseja

## Licence

No licence has been granted yet. All rights reserved until a licence is chosen
before public release.
