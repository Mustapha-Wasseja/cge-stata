# cge-stata

Computable general equilibrium (CGE) modelling in Stata.

`cge-stata` builds, calibrates and solves CGE models in Stata. Its built-in
SAM-based model supports static simulations, recursive dynamics and
perfect-foresight runs with user-specified forward-looking equations.
Calibrated single-country models can be linked through bilateral trade.
Users can also write standalone models in a language close to GAMS, with
their own sets, parameters, variables and equations, or in the form of
MPSGE, as sectors, commodities, consumers and nested production and demand
blocks. The package also provides policy optimisation, Nash and Stackelberg
games, sensitivity analysis and household microsimulation, for questions of
trade, taxation, factor markets, public finance, health or any other field
a model can represent.

The built-in solvers run in Stata and Mata on Stata 13 or later. Optional,
experimental solver links require Stata 16 or later with Python and SciPy,
and the links to IPOPT and SCIP the Python packages cyipopt and PySCIPOpt
as well. GAMS export and GDX data exchange are also available; solving an
exported model in GAMS requires GAMS and the selected solver.

## Features

### The standard model from a SAM

The built-in model, specified in [docs/model_spec.md](docs/model_spec.md),
follows the IFPRI and PEP traditions:

- production with CES or Cobb-Douglas value added and Leontief intermediate
  inputs, an optional nest between them, nests within value added (labour of
  several skills, capital with energy), activities that produce several
  commodities, and the output of a commodity from several activities
  combined by a CES function;
- trade through a CET function between exports and domestic sales and an
  Armington function between imports and domestic goods, with finite export
  demand, commodities that are only exported, re-exports and margins that
  differ by market;
- households with Cobb-Douglas or linear expenditure system demand and home
  consumption, enterprises, the government, savings-investment and the rest
  of the world, with transfers among them;
- public finance: direct, sales, import, export, activity and factor taxes,
  VAT with input credits, revenue-neutral closures and public debt;
- factor markets: mobile, activity-specific or unemployed factors, a wage
  curve, a minimum wage, and factors in efficiency units;
- health: a social health insurance fund, labour efficiency and working
  time linked to health services, mortality and population;
- limits that bind in some scenarios and not in others, such as quotas and
  capacity limits with their rents, a peg that holds until borrowing reaches
  a limit, or a deficit ceiling, solved as complementarity conditions;
- closures for the external account, the government, savings-investment,
  the numeraire and each factor, with swaps of any variable;
- SAMs in national-accounts or supply-use layout, of any size.

### Simulation and analysis

- Recursive dynamics, and perfect foresight with leads and terminal
  conditions (`cge_dynamic`, `cge_dynresults`).
- Linked regions with bilateral trade and tariffs by route (`cge_region`).
- Scenario loops over lists and grids of values, optionally in several
  Stata processes at once (`cge_loop`).
- Policy optimisation with exact derivatives, constraints and shadow prices
  (`cge_optimize`); Nash equilibria and Stackelberg leaders (`cge_nash`).
- Sensitivity of results to the elasticities or to any parameter
  (`cge_sensitivity`).
- Report tables for several simulations, on screen, as data or in Excel,
  with measures written in the user language (`cge_results`, `cge_report`).
- The link to household surveys (`cge_microsim`): poverty, inequality,
  incidence, the growth incidence curve, each household's equivalent and
  compensating variations, the Shapley decomposition by channel, fiscal
  incidence by the Commitment to Equity method, reweighting, standard errors
  from the survey design, bands across draws and journal-style graphs.
- SAM multipliers and structural path analysis (`cge_multiplier`, `cge_spa`).

### The user language and standalone models

`cge_set`, `cge_parameter`, `cge_variable`, `cge_equation` and `cge_macro`
extend the standard model, or write a model of one's own:

- sets defined by set algebra (subsets with a domain, `+`, `*`, `-`, `not`,
  `yes`, `no` and conditions), and sets of pairs and tuples;
- parameters assigned element by element from expressions or from data, and
  symbols with any number of indexes;
- GAMS's `$` conditions on sums, terms and domains, evaluated at the base or,
  as GAMS does, at each solve;
- lags and leads, over the periods of a dynamic run and on ordered sets
  (`K(t-1)`, `K(t+1)`, `t++1`);
- GAMS's functions, products and extremes over sets, `ord()`, `card()` and
  macros;
- inequalities paired with variables, and box pairs, as PATH writes a mixed
  complementarity problem;
- equations that replace elements of the standard model's own equations, and
  variables added to them;
- nested CES and CET blocks (`cge_nest`).

A standalone model (`cge_model new`) is written whole in the language, as a
GAMS program is: a system of equations, a complementarity problem, or a
nonlinear or mixed-integer programme, with named models over subsets of its
equations. With the roles of its variables (`cge_model roles`) it is
reported, analysed for sensitivity and passed to household surveys as a
model from a SAM is. `cge_modlib` supplies ready-to-run models, from an
exchange economy to Dantzig's transportation problem, a knapsack, a
Stackelberg game and a Ramsey growth model.

### Models in the form of MPSGE

`cge_mpsge` writes a model as MPSGE writes one: sectors, commodities and
consumers, with production and demand blocks whose records give reference
quantities, prices and taxes of nested CES and CET functions, at any depth
and indexed by sets. Auxiliary variables and constraints, endogenous taxes,
rationed endowments and report variables are supported. The statements are
given as commands, or read from the model of a GAMS program. `cge_mpsge end`
writes the mixed complementarity problem that MPSGE generates, zero profits,
market clearing and income balance, as user variables and equations, so
that the rest of the package solves, reports, loops over and exports it. On
five test models the solutions agree with GAMS/MPSGE to about 1e-13.

### Solvers and diagnostics

- Newton's method with an exact Jacobian, by forward or reverse
  differentiation, Broyden's updates, a dense or sparse LU, Ruiz's
  equilibration, continuation and fallbacks.
- A semismooth Newton method for complementarity problems.
- A primal-dual interior-point method for nonlinear programmes, with exact
  Hessians, feasibility restoration, several starts and the marginals of the
  equations; branch and bound for integer and binary variables.
- Standalone models solved block by block.
- Solver options as GAMS's option statement, with GAMS's model and solver
  statuses (`cge_options`), and the attributes of variables: bounds, scales,
  starting levels, fixed values and integrality (`cge_bound`).
- Experimental links, on Stata 16 and later with Python: SuperLU and HiGHS
  through SciPy, IPOPT through cyipopt, and SCIP, for global solutions of
  nonconvex and mixed-integer programmes, through PySCIPOpt.
- Diagnostics: the model checks (`cge_check`); the equation listing,
  infeasibility report and solution listing (`cge_listing`); the structure of
  the system, which names the equations and variables at fault in a
  structurally singular one and finds its blocks (`cge_structure`); and an
  irreducible infeasible set of bounds and constraints (`cge_iis`).

### SAM tools, elasticities and GAMS

- Reading SAMs from CSV files, data in memory or GDX files, a mapping
  template, aggregation, balancing by RAS or cross entropy, and export
  (`cge_sam`, `cge_template`, `cge_aggregate`, `cge_balance`,
  `cge_samexport`); SYNTHETIC SAMs for testing (`cge_synthetic`).
- A library of published elasticities with their sources
  (`cge_elasticities`).
- `cge_gams` writes any model as a GAMS program: the standard model with an
  independent GAMS implementation that calibrates itself from the SAM, and a
  standalone model as a program of its own. It runs GAMS, compares the
  solution with Stata's and brings it back. `cge_gdx` writes and reads GDX
  files.

## Status

The current version is 0.47.1. Every change, version by version, is listed
in [CHANGELOG.md](CHANGELOG.md).

| Milestone | Status |
|---|---|
| Model specification | complete |
| Python reference implementation and validation suite | complete |
| Stata/Mata implementation | complete; agrees with the reference to about 1e-13 |
| User language, standalone models and models in the form of MPSGE | complete; checked against GAMS with PATH, IPOPT and SCIP, and against GAMS/MPSGE |
| Application to country SAMs | an 85-account national SAM and a 240-account SAM in supply-use layout (4,439 equations) calibrate, pass all checks and solve shocks; policy simulations not yet done |

The model has been validated against the Python reference on synthetic SAMs,
and calibrated on one national SAM with illustrative elasticities. When applying
it to a country SAM, run `cge_check, homogeneity perturb(0.1)` and review the
elasticity choices; the package has not yet been used for published policy
analysis.

## Requirements

Stata 13 or later (Stata/IC is sufficient). No other Stata packages are needed.
The test suite passes in Stata 13.1/IC and in StataNow/MP 19.5. Stata 13
cannot read model files (`cge_save`) saved in later versions of Stata, whose
Mata file format differs; later versions read those saved in Stata 13.

Optional, on Stata 16 and later: Python with SciPy for the SuperLU and HiGHS
links, and the Python packages cyipopt and PySCIPOpt for the IPOPT and SCIP
links; Python also lets `cge_loop, parallel()` run from batch mode. These
links are experimental. Solving an exported model in GAMS requires GAMS and
the selected solver.

## Installation

Install directly from GitHub (tested with StataNow 19.5):

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

A model from the SYNTHETIC SAM that comes with the package:

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

A standalone model, an exchange economy of two households and two goods:

```stata
cge_model new
cge_set g = g1 g2
cge_set h = h1 h2
cge_parameter alpha(h,g), values(h1.g1:0.3 h1.g2:0.7 h2.g1:0.6 h2.g2:0.4)
cge_parameter e(h,g), values(h1.g1:10 h1.g2:2 h2.g1:3 h2.g2:8)
cge_variable P(g), value(1)
cge_variable Y(h) = sum(g, P(g) * e(h,g))
cge_variable X(h,g) = alpha(h,g) * Y(h) / P(g)
cge_variable WALRAS, value(0)
cge_equation NUM: P(g1) = 1
cge_equation MKT(g): sum(h, X(h,g)) = sum(h, e(h,g)) + WALRAS
cge_solve, name(eq)
cge_results, sim(eq)
```

The same kind of economy in the form of MPSGE, with a tax on labour in one
sector, removed:

```stata
cge_model new
cge_parameter tx = 0.25
cge_mpsge model:taxlab
cge_mpsge sectors: X Y W
cge_mpsge commodities: PX PY PL PK PW
cge_mpsge consumers: CONS
cge_mpsge prod:X s:0.5  o:PX q:100  i:PL q:40 p:1.25 a:CONS t:tx  i:PK q:50
cge_mpsge prod:Y s:1.5  o:PY q:100  i:PL q:60  i:PK q:40
cge_mpsge prod:W s:1    o:PW q:200  i:PX q:100  i:PY q:100
cge_mpsge demand:CONS   d:PW q:200  e:PL q:100  e:PK q:90
cge_mpsge end, numeraire(PL)
cge_shock tx, value(0)
cge_solve, name(notax)
cge_results, sim(notax)
```

See [examples/tariff_removal.do](examples/tariff_removal.do) for a worked
example, `help cge` for the command list, and `cge_modlib list` for the
library of ready-to-run models.

## Documentation

- [The cge-stata Reference Manual](docs/manual/cge-stata-manual.pdf) (PDF), in
  the form of Stata's own manuals: a user's guide with a worked example from a
  raw SAM to results; the model's equations, closures, calibration and
  solution method, and the methods of every command; and a reference entry
  for each command, with its syntax, options, examples and their output, and
  stored results. It is built from the LaTeX sources in
  [docs/manual/tex](docs/manual/tex) with `tools/build_manual.py`.
- `help cge` in Stata: the help files of the commands.
- [examples/](examples): do-files that run on the synthetic SAMs.
- [CHANGELOG.md](CHANGELOG.md): the changes in each version.

Developer notes:

- [docs/model_spec.md](docs/model_spec.md): the specification of the
  equations, calibration, closures and validation checks, which the Stata,
  Python and GAMS implementations follow, and of every feature added since.
- [docs/elasticities.md](docs/elasticities.md): the elasticity library.
- [docs/sam_tools.md](docs/sam_tools.md): reading, writing, aggregating and
  balancing SAMs, and the mapping template.
- [docs/gams.md](docs/gams.md): the GAMS export.
- [docs/design.md](docs/design.md): commands, data structures, solver, testing
  and roadmap.
- [CONTRIBUTING.md](CONTRIBUTING.md): development conventions.

## Validation

Every calibration is checked for benchmark replication. `cge_check` tests SAM
balance, closure consistency, Walras's law, the GDP identity, homogeneity and
convergence from perturbed starting values, and `cge_listing` shows the residual
of every equation element at a point. A Python reference implementation
of the same equations (`reference/`) runs in continuous integration; the Stata
test suite, 63 test files, compares its results with the reference (every
variable of every test case, to about 1e-11 or better). An independent
implementation in GAMS ([tools/gams](tools/gams/README.md)), written from the
specification and calibrated from the SAM alone, reproduces every case: 186
scenarios across all layouts, features, fiscal instruments, labour-market
regimes, health outcomes and several closures, to 3e-11 or better.

The GAMS export check solves 67 cases written by `cge_gams`, from the
standard model to standalone systems, complementarity problems, models in
the form of MPSGE and nonlinear and mixed-integer programmes, with PATH,
CONOPT, KNITRO, IPOPT and SCIP; GAMS reproduces Stata's solutions to 2.1e-11
or better (3.6e-9 with CONOPT, whose feasibility tolerance is looser). Five
models written for GAMS's own MPSGE agree with `cge_mpsge` to about 1e-13 in
every scenario. The solvers are also checked against published problems:
complementarity problems of MCPLIB, problem 71 of Hock and Schittkowski, and
Waechter and Biegler's counterexample for feasibility restoration.

## Author

Mustapha Wasseja Mohammed

## Licence

No licence has been granted yet. All rights reserved until a licence is chosen
before public release.
