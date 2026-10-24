# Solving the model in GAMS (from version 0.4.3)

`cge_gams` writes the calibrated model and one scenario as a GAMS program, so
that anyone with GAMS can:

- solve the model with PATH, CONOPT, KNITRO, IPOPT or another solver;
- check the results of cge-stata with a second, independent implementation;
- extend the equations, which the Stata package does not allow.

## 1. What is written

GAMS receives what a user supplies, not the parameters that Stata calibrated:

- the SAM after the layout rewrites of `cge_map` (model_spec.md, Section 7.0);
- the roles of its accounts;
- the settings given to `cge_calibrate`: elasticities, income elasticities
  and Frisch parameters, VAT credit shares, public debt and interest rates,
  export-only commodities and export demand, labour-market settings, days
  lost to illness, and factor quantities.

The GAMS program calibrates every parameter itself, solves the base, and then
solves the scenario. Its equations are an independent implementation of
model_spec.md, written in GAMS rather than translated from Mata. They are the
same file that the package's independent check has used since version 0.1.16
(tools/gams).

| File | Content |
|---|---|
| `cge_run.gms` | driver: includes the model, then the scenario |
| `cge_model.gms` | data, calibration, equations and base solve |
| `cge_closure.gms` | bounds, variables that do not exist, and the closure |
| `cge_solve.gms` | the solve statement, for the chosen solver and model type |
| `cge_write.gms` | writes a solution |
| `cge_data.inc` | the SAM, the roles of its accounts and the calibration settings |
| `cge_shock_par.inc` | parameter changes and the closure |
| `cge_shock_var.inc` | changes to fixed variables |
| `cge_constraints.inc` | constraints, as complementarity pairs, and model `cgecon` (from version 0.4.4) |
| `cge_user.inc`, `cge_user_write.inc` | user variables and equations, and their results (from version 0.6.1) |

The scenario is either the shocks and closure in memory (what the next
`cge_solve` would solve) or, with `sim()`, those of a stored simulation.
Changed parameters and fixed variables are written as ratios to their base
values, for example `tm('com_man') = 0 * tm('com_man');` and
`QFS.fx('lab') = 1.05 * QFS.l('lab');`. GAMS therefore applies them to its
own calibrated values. A parameter whose base value is zero is set to its new
value.

Numbers are written with the fewest significant digits (15, 16 or 17) that
give back the same double.

GAMS writes `cge_base.csv` and `cge_<name>.csv`. Each has one row per
variable and element (scenario, variable, element1, element2, value), with
the model status in the first row.

**Dynamic runs** (from version 0.5.3). `cge_gams using dir, dynamic(run)`
exports every period of a run of `cge_dynamic`. Each period's changes from
the period before are written as ratios, to parameters
(for example capital accumulation, population growth of subsistence
quantities and the base of the health link, and growth of government and
foreign flows) and to fixed variables, in files named after the period's
simulation: `cge_dn1_par.inc` and `cge_dn1_var.inc` for the simulation
`dn1`. The driver solves the base and then the periods in order, each from
the solution of the period before, and writes `cge_dn1.csv` and so on for
each:

```
$include cge_model.gms
$include cge_constraints.inc
* Period dn1: changes from the period before, then the closure and fixed variables
$include cge_dn1_par.inc
$include cge_closure.gms
$include cge_dn1_var.inc
$batinclude cge_solve.gms cgecon
...
```

`compare` then compares every period with Stata's. Runs with constraints are
not exported.

**Not exported:**

- microsimulation and sensitivity runs;
- the death rate, which enters dynamic runs only through the labour supply of
  the next period, which is exported.

## 2. Running GAMS

```
cge_gams using gams_notariff, sim(notariff)
```
writes the files. Then, in that folder:
```
gams cge_run.gms                                    PATH, as a constrained nonlinear system (CNS)
gams cge_run.gms --cgesolver=conopt                 another CNS solver: CONOPT or KNITRO
gams cge_run.gms --cgesolver=ipopt --cgetype=nlp    an NLP solver
```

With `run`, Stata starts GAMS itself. It writes a script (`cge_run.cmd` on
Windows, `cge_run.sh` elsewhere) in the folder and runs it with `shell`; the
script can be run again by hand. `compare` then reads the results and compares
them with Stata's:
```
cge_gams using gams_notariff, sim(notariff) replace run compare gams(C:/GAMS/54/gams.exe)
cge_gams using gams_notariff, sim(notariff) noexport run compare solver(conopt) gams(C:/GAMS/54/gams.exe)
```

`noexport` uses the files already in the folder. It serves two purposes:

- solving again after the GAMS files have been edited;
- with `compare` alone, comparing results that GAMS wrote earlier.

Stata for Windows cannot start other programs in batch mode. There, run
`cge_run.gms` with GAMS and then use `compare noexport`.

The comparison computes |GAMS − Stata| / max(1, |Stata|) for every variable
and element that exists in the model. It reports the largest value for the
base and for the scenario, with the variable where it occurs.

**The GAMS solution in Stata** (from version 0.6.2). `import(name)` stores
the GAMS solution as a Stata simulation: the free variables take GAMS's
values, the fixed ones Stata's, and Stata evaluates the model's equations at
the result and reports the largest scaled residual. For a model too large for
Stata's dense solver, the route is to build, calibrate and shock the model in
Stata, export it, solve it with PATH, and import the solution for reports,
microsimulation or comparison:

```stata
cge_gams using big, replace                 // the current shocks
* in GAMS: gams cge_run.gms
cge_gams using big, noexport import(big_path)
cge_report, sims(big_path)
```

## 3. Solvers and model types

| `type()` | GAMS model | Solvers |
|---|---|---|
| `cns` (default) | constrained nonlinear system: the equations, square, with no objective | PATH, CONOPT, KNITRO |
| `nlp` | the same equations and a constant objective, `OBJ =e= 0` | IPOPT, CONOPT, KNITRO, MINOS, SNOPT |
| `mcp` (from version 0.4.4; the default with constraints) | a mixed complementarity problem: the equations, unpaired, and each constraint's bound paired with a slack | PATH |
| `nlp` for a nonlinear programme (from version 0.15.0; the default for one) | the equations of a standalone model and its objective, `OBJV =e=` the expression of `cge_solve, minimize()` or `maximize()`, solved by `solve cgeprog using nlp minimizing OBJV` (or `maximizing`) after the scenario's changes; the base, its starting levels, is written but not solved | IPOPT (the default), CONOPT, KNITRO, MINOS, SNOPT |

**Constraints.** A scenario with constraints (`cge_constraint`; model_spec.md,
Section 16) can only be written as a mixed complementarity problem. For
constraint *k*, `cge_constraints.inc` declares:

- a slack `SLK`*k* ≥ 0;
- the bound `BND`*k*, σ (b − Y) / s<sup>Y</sup> ≥ 0, paired with the slack;
- the link `LNK`*k*, X = x̄ + δ s<sup>X</sup> `SLK`*k*, an unpaired equality
  that frees the adjusting variable X.

When the slack is zero, Y may lie within its bound and X stays at x̄; when it
is positive, Y is at its bound. This is the complementarity condition of
Section 16.2, which GAMS passes to PATH exactly, without smoothing. The
variables with no pair must be free or fixed, so the bounds that keep prices
and quantities positive in the CNS form are left out. The base is solved as
model `cgebase`, the scenario as `cgecon`.

Convergence tolerances are absolute, so they are scaled to the largest SAM
cell, within what double precision allows (`ptol`, the larger of 1e-11 and
1e-13 times the largest cell). When it runs, the GAMS program writes an
option file for four solvers:

| Solver | Option file | Settings |
|---|---|---|
| PATH | `path.opt` | `convergence_tolerance` = ptol |
| CONOPT | `conopt.opt` | `rtnwma` = ptol relative to the largest cell |
| IPOPT | `ipopt.opt` | `tol` = 1e-12, `constr_viol_tol` = ptol; for a nonlinear programme also `bound_relax_factor` = 0 |
| KNITRO | `knitro.opt` | `feastol_abs` = ptol, `feastol` = 1e-12 |

Other solvers use their defaults.

A GAMS licence is needed. GAMS runs solvers that the licence does not cover
only for small models; the CONOPT and KNITRO results below were obtained that
way, on the synthetic SAMs.

## 4. Extending the model

The equations in `cge_model.gms` carry the labels of model_spec.md, with a
prefix for each block:

| Prefix | Block | Example |
|---|---|---|
| EP | prices (Section 5.1) | `EP1` is P1 |
| EQ | production | |
| ET | trade | |
| EI | institutions | |
| ES | system constraints | |
| EH | health links | |
| EL | labour-market regimes | |

To add an equation:

1. Declare a new variable and its equation after the existing ones.
2. Fix one variable less, or free one more, so that the system stays square.
3. Run `gams cge_run.gms`.

The closure in `cge_closure.gms` fixes variables at their current levels. A
new variable needs a starting level (`.l`) before the base solve.

## 5. Checks

`tools/gams/run_export_check.py` checks the export:

1. Stata solves each case of `tools/gams/export_check.do` and exports it.
2. GAMS solves every exported model.
3. Stata solves each case again and compares the results (`compare noexport`).

There are 53 cases (version 0.15.0). Together they cover:

- the standard, institutions, margins, territorial and supply-use layouts;
- mixed elasticities and top nests, and LES demand;
- the health insurance fund and the health link, days lost to illness;
- VAT with input credits, and public debt;
- margins by market, export demand and an export-only crop, and home
  consumption;
- the wage curve and the minimum wage, and factor quantities;
- every closure option: fixed exchange rate, fixed government savings with
  sales, import or VAT rates adjusting, investment-driven savings, the DPI
  numeraire, capital specific to each activity, and unemployed labour;
- constraints (from version 0.4.4): an import quota whose rent goes to
  households, a capacity limit on health services with the rent to capital,
  a borrowing limit under a peg, an import quota with rents paid abroad
  together with a ban on government borrowing, and a floor on the nominal
  wage;
- closure swaps (from version 0.4.5): government savings fixed with
  consumption adjusting, and labour unemployed at a fixed wage, by swaps;
- taxes on factor use and income (from version 0.5.0): a payroll tax on
  labour halved;
- nests of value added (from version 0.5.1): labour types and a nest of
  capital and energy, with Cobb-Douglas forms, and a nest of capital and a
  commodity that bears VAT;
- output of a commodity from several activities (from version 0.5.2),
  combined by a CES function;
- dynamic runs (from version 0.5.3), with every period solved in order:
  LES demand with population growth, the health link with a growth target and
  a donor exit, and public debt with debt relief;
- user variables and equations (from version 0.6.1): real government savings
  and nominal government consumption fixed through them, an indexed
  variable, and an equation with base(), exp() and ln(), which GAMS
  differentiates itself.
- in later versions: conditions, functions, bounds, replaced equations,
  declared nests, scenario loops, linked regions, standalone models and
  complementarity problems;
- nonlinear programmes of standalone models (from version 0.15.0): problem 71
  of Hock and Schittkowski, a matrix balanced by cross entropy and a frontier
  with a binding bound, which IPOPT solves as NLPs to 6.8e-13, 3.1e-13 and
  3.9e-12 of the interior-point solutions.

Results (21 October 2026, GAMS 54.2; `tools/gams/export_check_results.csv`):

| Solver | Type | Cases solved | Base, largest relative difference | Scenario, largest relative difference |
|---|---|---|---|---|
| PATH | CNS | 26 of 26 | 4.3e-16 | 1.6e-11 |
| PATH | MCP, with constraints | 5 of 5 | 2.8e-17 | 2.4e-12 |
| CONOPT | CNS | 17 of 17 | 4.3e-16 | 3.6e-9 |
| KNITRO | CNS | 17 of 17 | 4.3e-16 | 1.6e-11 |
| IPOPT | NLP | 17 of 17 | 5.6e-15 | 1.6e-11 |

CONOPT, KNITRO and IPOPT do not solve complementarity problems, so they were
not run on the five cases with constraints. NLPEC, which reformulates a
complementarity problem as a nonlinear programme for CONOPT, was also tried.
With its default settings it solved the 17 cases without constraints to
1.1e-9, but the five with constraints only to between 7e-6 and 3.5e-4.

Stata solved every case with a tolerance of 1e-12 on the scaled residuals.
Differences of about 1e-11 are therefore at the precision of the two
solutions; CONOPT stops at a looser feasibility tolerance.

`tests/test_gams.do`, part of the Stata test suite, needs no GAMS. It checks
the files written and the comparison, using results that GAMS (PATH) wrote
for one case (`tests/data/gams`).

The independent check of the model itself (`tools/gams/run_gams_check.py`)
uses the same GAMS files. From version 0.4.3 it also covers factor
quantities and accepts `--solver` and `--type`; its results are in
tools/gams/README.md.
