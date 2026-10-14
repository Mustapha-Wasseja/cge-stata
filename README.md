# cge-stata

Computable general equilibrium (CGE) modelling in Stata.

`cge-stata` builds, calibrates and solves single-country CGE models from a
social accounting matrix (SAM) entirely within Stata and Mata. No external
modelling system (GAMS, GEMPACK or similar) is required.

## Status

Version 0.1.7 implements the standard static model described in
[docs/model_spec.md](docs/model_spec.md):

- CES or Cobb-Douglas value added, Leontief intermediate inputs; activities may
  produce several commodities in fixed proportions (version 0.1.4);
- CET transformation between exports and domestic sales, Armington aggregation
  of imports and domestic goods;
- households with Cobb-Douglas demand (non-profit institutions can be mapped as
  households), enterprises, and transfers among institutions and with the rest
  of the world (version 0.1.2);
- government with direct, sales, import, export and activity taxes,
  savings-investment and the rest of the world;
- selectable closures for the external account, government, savings-investment,
  the numeraire and each factor (mobile, activity-specific or unemployed);
- SAMs in national-accounts layout: exports recorded as sales by activities,
  taxes paid directly to the government account (version 0.1.1), trade and
  transport margins netted out of the margin activities (version 0.1.3), the
  territorial correction and inventory run-downs (version 0.1.4);
- SAMs in supply-use layout (version 0.1.7): margin accounts paid by
  commodities, commodities that are imported only, separate stock-change
  accounts, and account labels that are not valid Stata names (such as `s-i`).

Version 0.1.5 keeps benchmark replication exact when a CET or Armington share
is close to one, as with a low elasticity and a very small trade share.
Version 0.1.6 makes the homogeneity and perturbed-start checks independent of
the units of the SAM.

| Milestone | Status |
|---|---|
| Model specification | complete |
| Python reference implementation and validation suite | complete |
| Stata/Mata implementation | complete; agrees with the reference to about 1e-13 |
| Application to country SAMs | an 85-account national SAM calibrates and passes all checks; a 240-account SAM in supply-use layout maps fully but records exports that exceed domestic output, which the model does not yet represent; policy simulations not yet done |

The model has been validated against the Python reference on synthetic SAMs,
and calibrated on one national SAM with illustrative elasticities. When applying
it to a country SAM, run `cge_check, homogeneity perturb(0.1)` and review the
elasticity choices; the package has not yet been used for published policy
analysis.

## Requirements

Stata 13 or later (Stata/IC is sufficient). No other Stata packages are needed.

## Installation

The repository is private during development. Clone it, then install from the
local copy:

```stata
net install cge, from("C:/path/to/cge-stata") replace
```

Once the repository is public it will also install directly from GitHub:

```stata
net install cge, from("https://raw.githubusercontent.com/Mustapha-Wasseja/cge-stata/main/") replace
```

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
test suite compares its results with the reference for six simulations.

## Author

Mustapha Wasseja

## Licence

No licence has been granted yet. All rights reserved until a licence is chosen
before public release.
