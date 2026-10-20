# cge-stata

Computable general equilibrium (CGE) modelling in Stata.

`cge-stata` builds, calibrates and solves single-country CGE models from a
social accounting matrix (SAM) entirely within Stata and Mata. No external
modelling system (GAMS, GEMPACK or similar) is required.

## Status

Version 0.4.1 implements the standard single-country model described in
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
  the numeraire and each factor (mobile, activity-specific, unemployed, or,
  from version 0.3.3, a wage curve or a minimum wage);
- SAMs in national-accounts layout: exports recorded as sales by activities,
  taxes paid directly to the government account (version 0.1.1), trade and
  transport margins netted out of the margin activities (version 0.1.3), the
  territorial correction and inventory run-downs (version 0.1.4);
- SAMs in supply-use layout (version 0.1.7): margin accounts paid by
  commodities, commodities that are imported only, separate stock-change
  accounts, and account labels that are not valid Stata names (such as `s-i`);
- exports at least as large as domestic output, such as re-exports and exports
  from inventories, drawn from composite supply (version 0.1.8);
- fiscal instruments (version 0.3.1, [Section 12](docs/model_spec.md)): VAT
  with input credits by activity, so that exempt activities bear VAT on their
  inputs; revenue-neutral closures in which direct, sales, import or VAT rates
  adjust to hold government savings; and public debt, with interest separated
  from the SAM's transfers, paid on domestic and foreign debt, and deficits
  added to the debt in dynamic runs;
- trade and household extensions (version 0.3.2, [Section 13](docs/model_spec.md)):
  home consumption of own produce at producer prices; export demand that falls
  as world export prices rise; commodities whose output is all exported; and
  margins that differ between domestic sales, imports and exports;
- labour-market regimes (version 0.3.3, [Section 14](docs/model_spec.md)): a
  labour force from the base unemployment rate; a wage curve, on which real
  wages fall as unemployment rises; and a minimum real wage, below which wages
  cannot fall, with the regime (unemployment at the floor, or full employment
  above it) found by the solver;
- health outcomes and demography (version 0.3.4, [Section 15](docs/model_spec.md)):
  working time lost to illness and a death rate that respond to health
  services per head; days worked scale labour input, and in dynamic runs
  deaths change the growth of the population and of labour.

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
Version 0.4.1 adds SAM multiplier analysis (`cge_multiplier`; Pyatt and Round
1979): the accounting multipliers of the mapped SAM, their decomposition into
transfer, open-loop and closed-loop effects, and the fixed-price effects of
injections such as more government spending on health services, without
calibrating a model.
Version 0.4.0 adds a user manual ([docs/manual](docs/manual/README.md)), in ten
chapters from preparing a SAM to validation and troubleshooting, and a worked
example that takes an unbalanced SAM through every step: a template,
aggregation, balancing, mapping, elasticities from the library, calibration
and checks, three policy simulations, report tables, sensitivity analysis, a
dynamic baseline and scenario, and poverty and inequality in a household
survey (`examples/raw_sam_to_results.do`). The test suite runs every example.
Version 0.3.5 adds a library of published elasticities
([docs/elasticities.md](docs/elasticities.md)): aggregate Armington and CET
elasticities for 51 African countries, income elasticities for nine
consumption categories in 47 African countries, a Frisch parameter, an African
capital-labour substitution elasticity, wage-curve elasticities and health
outcome elasticities, each with its source, the table and page where it is
printed, and the check made when it was read. `cge_elasticities` lists or
loads entries and returns them as options for `cge_calibrate`, mapping model
commodities to consumption categories; users can add their own entries.
Version 0.3.4 adds the health outcomes above. `cge_calibrate` gains
`sickdays()`, `sickelas()`, `mortality()` and `mortelas()`; `cge_shock`
changes the share of time lost (`sick`, for example an epidemic) and the
death rate (`mort`); the health report shows services per head, the share of
time lost, days worked, the death rate and the population; and
`cge_dynamic` gains `deathfactors()`, `deathshare()` and `workingage()`.
Deaths respond to health services within a period and change population and
labour from the next one. The elasticities are the user's, from studies of
the country; the package supplies none.
Version 0.3.3 adds the labour-market regimes above. `cge_calibrate` gains
`unemployment()`, `wagecurve()`, `minwage()` and `smoothing()`; `cge_closure`
gains the factor closures `wagecurve` and `minwage`; `cge_shock` changes the
labour force, the minimum wage and the wage curve's reference wage; reports
show the labour force and the unemployment rate, with rates in percentage
points; and the labour force grows in dynamic runs. The minimum-wage condition
is a complementarity condition, solved with the rest of the model in a
smoothed Fischer-Burmeister form, and the tests check it against the exact
regimes.
Version 0.3.2 adds the trade and household extensions above: home consumption
is read from the SAM's household payments to activities; `cge_map` gains
`domesticmargins()`, `importmargins()` and `exportmargins()`; `cge_calibrate`
gains `exportonly()` and `exportdemand()`; and `cge_microsim` prices home
consumption at the activity price.
Version 0.3.1 adds the fiscal instruments above. `cge_map` gains `vattax()`
and `vatshare()` (VAT recorded separately or within the sales tax);
`cge_calibrate` gains `vatcredit()`, `debt()`, `interest()`, `debtholders()`
and `foreignborrowing()`; `cge_closure, government(fixgsav sales)` and the
like choose the tax that replaces lost revenue; `cge_shock` changes VAT rates,
credit shares, interest rates and debt stocks; and `cge_report` adds VAT
revenue and a public debt table. A model saved by an earlier version is
upgraded when it is loaded.
Version 0.3.0 adds tools to prepare a SAM ([docs/sam_tools.md](docs/sam_tools.md)).
`cge_sam` reads SAMs of any size, as wide CSV files parsed directly (beyond
the 2,048 variables of Stata/IC) or as long data with one observation per
cell. `cge_template` writes an Excel or CSV template in which accounts are
given their roles, pairs and aggregation groups; `cge_map using` and
`cge_aggregate using` read it. `cge_aggregate` merges accounts. `cge_balance`
balances a SAM by generalised RAS, given every account's total, or by cross
entropy, estimating the totals subject to balance and any known totals; both
keep signs, zeros and fixed cells. `cge_samexport` writes the SAM.
Version 0.2.2 links simulations to household survey data (`cge_microsim`).
Each survey household's income sources, consumption and prices change as the
model says they change for its group. The command reports poverty and
inequality before and after, using the survey's own weights and poverty line.
Version 0.2.1 adds sensitivity analysis (`cge_sensitivity`). It runs Monte Carlo
draws of the elasticities, recalibrates the model for each draw, and gives the
distribution of every report measure.
Version 0.2.0 also solves much larger models. Explicit definitions are left out of
the Newton system, and the rows with many variables get exact derivatives. LU
factors are reused across Newton steps. A synthetic SAM with 250 activities and
20 households (40,190 equations, 4,254 solved) solves a tariff removal in about
3 minutes on a laptop with Stata 13; see [tools/bench](tools/bench/README.md).
From version 0.3.0, a SAM with more accounts than Stata/IC can hold as
variables is read directly from a CSV file or from long data.
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

Stata 13 cannot connect to GitHub over HTTPS (its Java runtime uses an old
TLS version, and the connection fails with "protocol_version"); current
versions of Stata, such as Stata 19, use a newer one. With Stata 13, install
from a local copy of the repository (cloned, or downloaded as a ZIP file from
GitHub):

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

Preparing a national SAM:

```stata
cge_sam using national_sam.csv, clear
cge_template using sam_roles.xlsx      // fill in roles, pairs and groups in Excel
cge_aggregate using sam_roles.xlsx
cge_balance, method(ce)
cge_map using sam_roles.xlsx
```

See [examples/tariff_removal.do](examples/tariff_removal.do) for a worked
example, and `help cge` for the command list.

## Documentation

- [docs/manual](docs/manual/README.md): the user manual, with the worked
  examples in [examples/](examples).
- [docs/model_spec.md](docs/model_spec.md): equations, calibration, closures
  and validation checks.
- [docs/elasticities.md](docs/elasticities.md): the elasticity library.
- [docs/sam_tools.md](docs/sam_tools.md): reading, writing, aggregating and
  balancing SAMs, and the mapping template.
- [docs/design.md](docs/design.md): commands, data structures, solver, testing
  and roadmap.
- [CONTRIBUTING.md](CONTRIBUTING.md): development conventions.

## Validation

Every calibration is checked for benchmark replication. `cge_check` tests SAM
balance, closure consistency, Walras's law, the GDP identity, homogeneity and
convergence from perturbed starting values. A Python reference implementation
of the same equations (`reference/`) runs in continuous integration; the Stata
test suite compares its results with the reference (every variable of every
test case, to about 1e-11 or better). From version 0.1.16 an independent
implementation in GAMS ([tools/gams](tools/gams/README.md)), written from the
specification and calibrated from the SAM alone, reproduces every case: 139
scenarios across all layouts, features, fiscal instruments, labour-market
regimes, health outcomes and several closures, to 3e-11 or better.

## Author

Mustapha Wasseja

## Licence

No licence has been granted yet. All rights reserved until a licence is chosen
before public release.
