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
| `cge_sam` | Read a SAM from memory or from a CSV, Stata or Excel file, wide or long, of any size (a wide CSV file is parsed directly when its accounts do not fit as variables); check that it is square and consistently labelled; report its balance |
| `cge_template` | Write an Excel or CSV template of the accounts, with roles, pairs and aggregation groups to fill in (sam_tools.md, Section 3) |
| `cge_aggregate` | Merge accounts into groups, from a template or an option (sam_tools.md, Section 4) |
| `cge_balance` | Balance the SAM by generalised RAS or cross entropy, keeping signs, zeros and fixed cells (sam_tools.md, Section 5) |
| `cge_samexport` | Write the SAM, as read, aggregated or balanced, or after the layout rewrites, to a file or to memory |
| `cge_map` | Assign SAM accounts to model roles, with options or from a template, including a VAT account or VAT shares of the sales tax, and check the SAM against the supported flows (model_spec.md, Section 7.0) |
| `cge_calibrate` | Compute base values and parameters from the mapped SAM and the elasticities, VAT credit shares and public debt; check benchmark replication |
| `cge_closure` | Choose closures for the external account, government, savings-investment, the numeraire and each factor; check that the system is square |
| `cge_shock` | Change tax rates, world prices or productivity, or any variable fixed by the closure (factor supplies, foreign savings, and so on) |
| `cge_solve` | Solve the model and store a named simulation |
| `cge_results` | Display a summary of changes from the base, including household equivalent variation; load or save all results as a dataset |
| `cge_check` | Run the validation checks of model_spec.md, Section 8 |
| `cge_listing` | List every equation element at a point, with its residual: the equation listing and infeasibility report (from version 0.9.5) |

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
- Reduced system (from version 0.2.0). Explicit definitions whose variables
  appear in no row with exact derivatives are left out of the Newton system.
  They are P1, P2, P6, Q5, Q6, I5, T8, I13 and H2, and their variables are
  computed from the others (`_cge_derive`) before each residual evaluation.
  A definition is left out only when its equation elements are exactly the
  existing elements of its variable (`_cge_reduce_setup`). The pattern of the
  reduced system is found by substituting each left-out variable by the
  columns of its definition row. Q5 (intermediate demand) and I5 (household
  demand) grow with the square of the number of sectors, so most of a large
  model's equations are left out: 4,254 of 40,190 remain for a SAM with 250
  activities and 20 households. `cge_solve, full` keeps every equation; the
  test suite checks that both systems give the same solution and that both
  exact Jacobians equal the column-by-column central differences.
- From version 0.2.0 the market-clearing (S2) and activity-price (P7) rows
  also have exact derivatives (`_cge_dense2`). In the reduced system these are
  total derivatives through the left-out variables. Without them, each of
  these rows involves most activities or commodities, and the number of
  groups of central differences grows with the number of sectors.
- LU factors are reused for further Newton steps while each step at least
  halves the residual norm (before version 0.7.0 a chord method, from 0.7.0
  with Broyden's updates). Otherwise a new Jacobian is computed. Mata's
  `_lud()` returns $A = (LU)[p, .]$, so systems are solved with the right-hand
  side permuted by `invorder(p)`.
- From version 0.7.0 the Jacobian is exact (`_cge_jacobian_exact`).
  `_cge_jtrip` writes the derivatives of every block as triplets (row,
  column, value) of d(L - R)/dx in the stacked variables; the old exact rows
  (`_cge_dense`) are reused for P8, P9, I1, I8, I9, S1, S3 and S5. User
  equations are differentiated in forward mode (`_cge_u_dvalue`). In the
  reduced system, each left-out variable d of a definition row D is replaced
  in the other rows by its dependencies y, with dd/dy = -(dD/dy) / (dD/dd)
  from the triplets of D (implicit differentiation; no left-out definition
  depends on another). Duplicates are summed with `panelsum()` after sorting
  by position, and the entries are written into the dense matrix row by row.
  `_cge_jexcheck()` and `_cge_jexall()` compare it with column-by-column
  central differences, at the current point, a simulation's solution or a
  perturbed point. Mata pitfall: a column vector `:*` a row vector is not
  c-conformable; outer products need `*`.
- Broyden's updates (from version 0.7.0): after each Newton step, full or
  shortened by the line search, the inverse Jacobian is updated as
  H+ = (I + a s') H, a = (s - Hy)/(s'Hy) (good method, Sherman-Morrison),
  stored as the LU factors times the factors (I + a s'); H y = H F+ + d uses
  the last direction d, so each step needs one LU solve (`_cge_hsolve`).
  Broyden steps take a line search of at most two halvings; a new Jacobian
  after a failure, a step that reduces the norm by less than a tenth, or 30
  updates. A first version took Broyden steps only after full Newton steps
  (Kelley's compact form, steps that halve the residual): on the
  250-activity benchmark it needed 6 Jacobians, the damped form 4, because
  the first Newton steps are shortened by the line search. The LU
  factorisation is now most of the time of a large solve. After convergence up to
  three more steps toward tol/1000 (a solution just inside the tolerance made
  `cge_optimize` fail to converge in a test case). `cge_optimize` solves
  with mode 3 (exact Jacobian, chord steps): from a warm start Broyden's
  updates do not help, and 293 solves against 591 were needed in that case.
  `_cge_newton()` modes: 0 exact + Broyden (default), 1 central differences,
  2 one-sided differences, 3 exact without the updates; `_cge_newtoncheck(m1,
  m2)` compares two of them.
- From version 0.6.3 Newton's Jacobian uses one-sided differences, with step
  $10^{-7} \max(1, |z|)$ in the scaled variables: the residuals at the
  current point are already known, so each group of columns needs one
  evaluation of the equations instead of two. The error of the Jacobian is
  about $4 \times 10^{-7}$ (central differences: about $10^{-10}$), too
  small to change the Newton steps in the test models. If Newton fails, it
  is tried again from the start with central differences, before Powell's
  method. From version 0.7.0 the diagnostics use the exact Jacobian; the test
  hook `_cge_jaccheck()` keeps the grouped differences, still the fallback.
- Recursive dynamics (from version 0.2.0) solve each period with the static
  solver, starting from the previous period's solution. The state of a run is
  kept in a separate structure (`cge_dyn`, external `cge__dyn`) while
  `cge_dynamic` runs. Each period is stored as an ordinary simulation, tagged
  with its run, period and efficiency factor.
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
| `reference/tests` (pytest) | continuous integration and locally | synthetic SAM; calibration; validation checks; dual unit-cost checks; closures; direction of effects; SAM aggregation and balancing (signs, zeros and fixed cells kept, targets met, cross entropy with every total known equal to RAS, optimality conditions) |
| `tests/*.do` (Stata) | locally, via `tools/run_stata_tests.ps1` | Mata solver; synthetic SAM; agreement with the Python results for about 100 simulations; validation checks; all 64 closure combinations; alternative closures; factor quantities; error handling; SAM tools against the Python balanced and aggregated SAMs, mapping from templates, the three readers and a 2,100-account SAM; the extensions of versions 0.3.1 to 0.3.4 and the elasticity library; every worked example in examples/ |

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
| 0.1.10 | Shocks to government and investment demand by product (qg, qinv) and to transfers (trdg, trdr, trfr, trgr, trrg) (done) |
| 0.1.11 | Linear expenditure system (LES) household demand, calibrated from income elasticities and Frisch parameters; LES equivalent variation (done) |
| 0.1.12 | Leontief, CES or Cobb-Douglas top nest between value added and aggregate intermediate input, by activity (done) |
| 0.1.13 | Social health insurance fund: contributions on factor income, transfers from government and the rest of the world, purchases of health services, savings; mapping option insurance() and synthetic health layout (done) |
| 0.1.14 | Factors in efficiency units: exogenous factor efficiency (af) and an efficiency linked to the volume of health services consumed, with an elasticity by factor (done) |
| 0.1.15 | Standard report tables for several simulations, to screen, Stata or Excel, with equivalent and compensating variations (cge_report); calibrated parameters as a dataset (cge_parameters); saving and loading a model (cge_save, cge_use) (done) |
| 0.2.0 | Recursive dynamics (model_spec.md, Section 10): capital accumulation with investment allocated by relative rental rates, growth of factors, population and exogenous flows, efficiency growth given or calibrated to GDP growth targets, time-varying shocks, results against a baseline (cge_dynamic, cge_dynresults); larger models: a reduced Newton system without explicit definitions, exact derivatives for market clearing and activity prices, reuse of LU factors, so that 40,190 equations solve in about 3 minutes (tools/bench) (done) |
| 0.1.16 | Independent check in GAMS: the model written from the specification in GAMS, calibrated from the SAM alone and solved with PATH, reproduces every test case (tools/gams) (done) |
| 0.2.1 | Sensitivity analysis: Monte Carlo draws of elasticities (uniform or triangular, by sector or common), recalibration for each draw, and the distribution of every report measure (cge_sensitivity) (done) |
| 0.2.2 | Top-down link to household survey data (model_spec.md, Section 11): income sources, consumption and prices by survey household, poverty (FGT) and inequality (Gini) before and after (cge_microsim) (done) |
| 0.3.0 | SAM tools (docs/sam_tools.md): SAMs of any size, read directly from CSV or from long data; a mapping template in Excel or CSV for roles, pairs and groups (cge_template, cge_map using); aggregation (cge_aggregate); balancing by generalised RAS or cross entropy with known totals and fixed cells (cge_balance); writing the SAM (cge_samexport) (done) |
| 0.3.1 | Fiscal instruments (model_spec.md, Section 12): revenue-neutral closures with direct, sales, import or VAT rates adjusting (TQADJ, TMADJ, TVADJ); VAT with input credits by activity (cge_map vattax(), vatshare(); cge_calibrate vatcredit()); public debt and interest, separated from the SAM's transfers, with deficits borrowed in dynamic runs (cge_calibrate debt(), interest(), debtholders(), foreignborrowing()); a public debt report table; models saved by earlier versions upgraded on loading (done) |
| 0.3.2 | Trade and household extensions (model_spec.md, Section 13): home consumption of own produce at producer prices, from the SAM's household payments to activities; finite export demand with an endogenous world export price (cge_calibrate exportdemand()); export-only commodities (exportonly()); margins on domestic sales, imports and exports (cge_map domesticmargins(), importmargins(), exportmargins()); home consumption in the survey link (done) |
| 0.3.3 | Labour-market regimes (model_spec.md, Section 14): a labour force from the base unemployment rate (cge_calibrate unemployment()); a wage curve (wagecurve()); a minimum real wage with the regime found by the solver, through a smoothed Fischer-Burmeister condition (minwage(), smoothing()); factor closures wagecurve and minwage; shocks to the labour force, minimum wage and reference wage; the labour force and unemployment rate in reports, with rates in percentage points; labour-force growth in dynamic runs (done) |
| 0.3.4 | Health outcomes and demography (model_spec.md, Section 15): working time lost to illness and a death rate responding to health services per head with constant elasticities (cge_calibrate sickdays(), sickelas(), mortality(), mortelas()); days worked as per-worker efficiency (DW, equation H3); deaths changing population and labour growth from the next period in dynamic runs (cge_dynamic deathfactors(), deathshare(), workingage()); shocks sick and mort; health report rows (done) |
| 0.3.5 | Elasticity library (docs/elasticities.md): 531 published entries -- aggregate Armington and CET for 51 African countries, income elasticities for 47, a Frisch parameter, capital-labour substitution, wage-curve and health-outcome elasticities -- with source, location and check; built and checked from the source documents (tools/elasticities); cge_elasticities to list, load and return calibration options, with user files (done) |
| 0.7.1 | User sets and parameters: cge_set name = elements [, except()] (labels, model set letters and other user sets), usable as indexes of user variables, equations, sums and parameters; cge_parameter with no index, one or two, values from = #, values() or the data in memory (from() labels()), changed by cge_shock, carried by continuation and dynamic runs, an element as an instrument of cge_optimize, listed by cge_parameters, kept by calibration and save/use, written to GAMS as UP_name; benchmark replication over the model's own equations, so a user equation that acts as a shock no longer stops calibration again; tests against sums written out, a direct shock with the same effect, continuation, save/use, the optimiser and GAMS (export check case usersets) (done) |
| 0.9.0 | Inequalities in user equations (=l=, =g=, <=, >=) paired with a variable fixed under the closure, perp(V[, down]), as GAMS MCP pairs, through slack variables and the constraints of Section 16; exogenous user variables (fixed, or lower()/upper() without a definition); bounds on defined user variables (max/min through adjusters); constraints made again on calibration, closure changes and cge_constraint, clear; tests against cge_constraint (quota, capacity over a conditional domain), closed forms for a floor with GADJ and for max/min, save/use, calibration, closures, dynamic runs, the GAMS files and GAMS as MCP (export check case inequalities) (done) |
| 0.9.1 | Two indexes for user variables and equations, NAME(i,j)[$(q)]; sums over two indexes, sum((i,j)$(q), g); sets of pairs, cge_set map(a,c) = e1.f1 ..., in sums and conditions, as GAMS mapping sets; shocks and perp() over pairs; GAMS domains over (AC, AC); tests against nested sums and closed forms, save/use, calibration, the GAMS files and GAMS as MCP (export check case pairs) (done) |
| 0.9.2 | Lags in user equations, lag(V[(e)][, k]) for k up to 4: the solutions of earlier periods of a dynamic run, the base before the first period and in static simulations; stored with each period and saved; GAMS parameters LAGk_V set period by period; tests against the period results (differences, two-period lags, partial adjustment), save/use, recalibration, the GAMS files and GAMS period by period (export check case dynlag) (done) |
| 0.9.3 | User equations that replace elements of built-in equation blocks, replace(B) or replace(B(e)): 49 blocks by domain, those with coded derivatives excluded; the elements masked in the system, saved and kept on calibration; cge_model.gms leaves out the elements of XRP; tests that the same equation written by the user leaves the solution unchanged (for a whole block and for the cells of one activity, which checks the orientation), other rules against closed forms, Walras's law, save/use, calibration, a dynamic run, the GAMS files, the errors and GAMS (export check case replace) (done) |
| 0.9.4 | cge_optimize: objectives and targets as expressions of the user language, with expressions on either side of a target; inequality constraints, constraints(h <= v, h >= v), by the method of Powell, Hestenes and Rockafellar with the targets; tests that an expression gives the optimum of the measure it equals, a closed form, an expression target with a sum, binding constraints (>= on an expression, <= on a measure) against the same conditions as targets, constraints that do not bind, and the errors (done) |
| 0.9.5 | cge_listing: the equation listing and infeasibility report at a simulation, the base or the current point, by block and element, with the largest scaled residuals, every element of the blocks asked for, and the listing as a dataset; the solve diagnostics point to it; one table of block domains for labels and replacements; tests at the base, at a shocked point against the tariffs element by element, the labels of two indexes, a failed solve against its residual, replaced elements and the errors (done) |
| 0.27.0 | Prototype (experimental) of solver links through Stata's Python, Stata 16 and later with SciPy: ado/cge_scipy.py; data through binary files of doubles written by Mata's bufio (sfi's Mata.get took 2.8 s for the 161,000 entries of a Jacobian, the files 0.02 s); Python run from an ado-file gets a namespace of its own each time, so every call imports the module again (_cge_py_pre); cge_options, linsolver(python): SuperLU factorises Newton's Jacobians (_cge_pylu_update and _cge_pylu_solve behind _cge_slu_update and _cge_slu_solve, F.ok 2), 2 to 2.5 times faster whole solves from 200 activities, slower below 100 (tools/bench/bench_results_0270_*); cge_solve, solver(highs): linear and mixed-integer programmes of standalone models by HiGHS (scipy.optimize.linprog and milp), linearity checked at a second point within the bounds, marginals of linear programmes, GAMS statuses 1, 3, 4, 10 and 14; Stata 13 to 15 stop with error 198; tests against the package's sparse LU, a closed form, the interior point's marginals, enumeration of a knapsack and an assignment (done) |
| 0.26.0 | Lags and leads on ordered sets: an argument t+n or t-n (n a whole number) is the element n places after or before, t++n and t--n count round the set, and an element beyond the set makes its reference 0, with base() of it (_cge_u_substl in sums and every domain, _cge_u_none in the compiler); the library's Ramsey model writes K(t+1) instead of a set of pairs; tests against the values, a telescoping sum and capital accumulated by a lag and by a lead; export case lagindex (done) |
| 0.25.0 | Symbols with three or more indexes: a set code "S1\|S2\|S3" lays a symbol out as rows of the first set and columns of the product of the later ones, whose labels are the tuples joined by periods, the last index changing fastest (_cge_setsize, _cge_setlab, _cge_nidx, _cge_setcodes); NAME(i,j,k) in cge_variable, cge_equation and cge_parameter (_cge_u_head, _cge_u_idxlist); the indexes of a domain put in by _cge_u_substd (positions of each index from the position in the product, for ord()); sums sum((i,j,k), e) and sum(m(i,j,k), e) as sums within sums (_cge_u_sumpairs, _cge_u_tuple); sets of tuples cge_set m(i,j,k) = e1.e2.e3 and their membership in conditions; references, base(), values(e1.e2.e3:#), from() in long form with one label variable per index, shocks, bounds and results by e1.e2.e3; GAMS declares (AC, AC, AC) and (*, *, *); tests against closed forms and enumeration; export case multiindex (done) |
| 0.24.0 | cge_nash solve, method(newton): a semismooth Newton method on the stacked first-order conditions, z - mid(lo, z + G(z), hi) = 0, with G from cge_optimize's exact derivatives (the players' objectives as its targets, set up by _cge_optimize(..., setup)) and its Jacobian from forward differences, and a check of each player's second-order conditions; damping() of best responses; the leader's followers solved by the same method; cge_solve, starts(#): multi-start of the interior point and of each relaxation of branch and bound, from points drawn by a generator of its own (MINSTD); cge_loop, parallel() from batch mode on Windows through Python's subprocess on Stata 16 and later (Stata 13 to 15 keep the sequential fallback, with a note naming the version); tests: a game whose best responses diverge, a duopoly at a bound, the standard model's game, a cubic's global minimum, a trap of branch and bound, two and three processes from batch mode (done) |
| 0.23.0 | Fixes: a label put in for an index is marked (char(2)) when it is the name of an index, so that a sum over that alias within does not replace it again, and the compiler removes the marks (_cge_u_mk, _cge_u_um); a sum over the equation's own index is an error for such labels too; cge_optimize scales an instrument by no less than 1 per cent of a finite range, of a single bound's size (at least 1), or 0.01 without bounds; run_export_check.py tries a GAMS run again after return code 7; tests of sums, nested sums and a parameter with labels g1 to g3, of starts at 1e-4, 1e-7 and 1e-10, and an export case labalias (done) |
| 0.22.1 | Fix: in an equation over two indexes, the first element goes in through a placeholder, so that a label equal to the name of the second index (labels t1, t2 with the alias t2) is not replaced again (_cge_u_subst2); a test of pairs of consecutive years (done) |
| 0.22.0 | cge_optimize starts an instrument on or beyond a bound inside it (5 per cent of a finite range, or 1 per cent of the bound's size), with a note, instead of stopping; a Ramsey growth model in the library (30 years, capital over pairs of consecutive years, Euler equation to 1.7e-11); known limitation recorded: labels equal to index names in conditions on sets of pairs (done) |
| 0.21.0 | Model library and error positions: cge_modlib list|describe|run|copy over eight models in the user language (exchange, crusoe, markets, hs071, transport, ras, knapsack, cournot), each a do-file cge_ml_*.do with title, kind, reference and expected result in *! lines, installed with the package; syntax errors in expressions show the expression with a marker under the place (_cge_u_fail in _cge_u_compile), as GAMS's $ errors; tests run every model against its result (done) |
| 0.20.0 | Nash equilibria and leaders: cge_nash player (instruments, objective and bounds as in cge_optimize, M.nashdef, saved), solve by Gauss-Seidel best responses of cge_optimize (exact derivatives) until a round changes no instrument by more than the tolerance; leader() by a projected Newton method with central differences of the leader's objective at the followers' equilibrium; list, clear; tests against Cournot and Stackelberg closed forms, three firms, a game on the standard model whose equilibrium each player's optimum confirms (done) |
| 0.19.0 | Parallel scenario runs: cge_loop, parallel(#) saves the model, splits the scenarios into contiguous groups, writes a do-file per group (absolute ado-path, cge_use, cge_loop with paired values and first(), cge_save, return code), starts Stata in batch mode for each (winexec /e on Windows, shell -b & elsewhere) in the temporary folder, waits for the return codes and merges the simulations under the names of one run; stataexe(); first(#) numbers the scenarios; in batch mode on Windows the scenarios are solved in the session with a note; tests in batch mode and a run across processes in an interactive session (done) |
| 0.18.0 | Integer and binary variables: cge_bound, integer|binary|continuous (M.intdef, standalone models); nonlinear programmes with them solved by branch and bound (_cge_bb: depth first, relaxations by the interior point or Newton's method at square nodes, most fractional branching, pruning by the incumbent and optcr, final solve with integers fixed), cge_solve nodes() optcr(), statuses 1/8/10/14, r(nodes) r(bestbound) r(gap); interior point accepts stalled points at IPOPT's acceptable level; GAMS export as MINLP/MIP (integer and binary declarations, SCIP default), set AC(*) for models without sets, power(x, n) for integer exponents; fix of solving after loading a model saved without simulations; tests against enumeration and SCIP (export check cases miknap, miils) (done) |
| 0.17.0 | Named models over subsets of equations, as GAMS's model statement: cge_model define/drop/list and describe NAME (M.mdef: lists of equations, defined variables, inequalities, models and all, expanded when used); cge_solve, model() solves the model's equations in the free variables that appear in them (_cge_submodel: constraints subset, U elements masked, pattern rebuilt, other free variables fixed), from() starts from a stored simulation and hold() holds variables at their levels (GAMS's .fx = .l); simulations keep their model (M.simmodel); nonlinear programmes of a model; GAMS export with model cgesub and .fx for the variables outside; tests: closed forms of a two-market model and its blocks solved in sequence, save/use, errors, GAMS (export check case namedmodel) (done) |
| 0.16.0 | Solver options and status codes: cge_options tolerance() iterate() timelimit() jacobian(exact|differences) reset, saved with the model (M.opttol optit opttime optjac) and used by cge_solve when it is not given them; time limit by a deadline external checked at each iteration of Newton, semismooth Newton and the interior point; a limit reached ends the solve without fallbacks or continuation; GAMS's model and solver statuses (16 solved, 1 optimal with constraints, 2 locally optimal, 5, 6, 7, 13; solver 1-5) for every solve, stored per simulation (M.simstat) and returned by cge_solve, cge_optimize, cge_results and cge_gams compare; tests of every status, limits from the command and the options, save/use and old files (done) |
| 0.15.0 | Exact derivatives and nonlinear programmes: cge_optimize's derivatives with respect to the instruments by the implicit function theorem at each solution (_cge_opt_grad: the exact Jacobian factorised once, dF/du by differences of the residuals, the measures along the tangent), the Hessian from differences of the exact gradient of the Lagrangian with the penalty's Gauss-Newton part, gradient(exact|differences); cge_solve, minimize()/maximize() on standalone models: a primal-dual interior point after Waechter and Biegler (2006) with exact first derivatives, the Hessian from differences of them, inertia correction on the null space of J, an l1 merit line search, marginals of the equations; the objective stored with the simulation (M.simobj); starts outside new bounds allowed in standalone models; GAMS export as an NLP with IPOPT; tests: frontiers with closed forms (instruments free, at a bound, under a constraint, ten goods), exact against differences on the standard model, HS071 against its published optimum with marginals against differences, Rosenbrock, cross entropy against RAS, GAMS IPOPT (export check cases nlphs071, nlpentropy, nlpfrontier) (done) |
| 0.14.0 | Semismooth Newton for complementarity problems (cge_options, mcp(semismooth|activeset)): every active constraint in Fischer-Burmeister form (regime 4 of _cge_bres), solved with the model by _cge_ssnewton: exact generalised Jacobian (1 - 1/sqrt(2) at the kink), Newton steps of sufficient descent with a non-monotone Armijo search on f'f/2 (memory 10), steepest descent of the merit otherwise; regimes read from the solution and polished; the active-set method as fallback and option; M.mcpsolver saved; cge_bound level() for adjusting variables and exogenous user variables at bounds; tests: MCPLIB josephy and kojshin (degenerate solution, several starts), an MPSGE-style economy against its linear programme, many binding constraints against the active-set method, GAMS PATH (export check cases mcpjosephy, mcptech, manycons) (done) |
| 0.13.0 | Standalone models (cge_model new, describe): a model written whole in the user language, as a GAMS program, without a SAM or the built-in equations; member M.standalone and _cge_sa(); layout of user variables only; blocks B1 and U, their pattern and exact Jacobian (_cge_pattern_sa, _cge_jtrip_ub), no reduced system; closure from fixed user variables and swaps; free set names, new labels and sets from data (cge_set, from()); assignments in cge_parameter, NAME(i)$(q) = expression, element by element at the base, assigned again while unused, wide data from(varlist) labels(var); value(expression) in cge_variable; GAMS export with a driver of its own; GDX, loops, the optimiser (expressions), listings, save/use; commands that need a SAM stop with 459; model statistics as GAMS's; tests: an exchange economy against its closed form, assignments and data against direct computations, the standard model in the language against the built-in model (base and four scenarios, at most 7.6e-13), GAMS (export check cases standalone and exchange) (done) |
| 0.12.0 | cge_region: linked regions (add, select, trade, tariff, world, solve, results, list, clear); each region's model in an external cge__rg_<name>, the one in memory kept in step (_cge_rg_sync, not over a model of other accounts); routes with exporter, importer, commodity, base value in world units (units() per region) and tariffs, those of the rest of the world closing each region's trade and giving its average tariff; link variables per import pair (pwm relative to the base, tm) and export pair (pwe), set into the region's parameters (_cge_lk_par); link equations (_cge_lk_eqs): CES price index of the routes with tariffs, tariff revenue, exports as the routes out; stacked full systems and links solved by Newton with the sparse LU (cge__slu_reg), each region's exact Jacobian, central differences for the link variables in the regions and for the link equations; models through pointers to their externals, never copied in evaluations; solutions stored in every region with the link variables as parameters, routes kept with the links; Python reference (reference/cge_ref/regions.py) with the same routes, solved with the reference models; tests: base, free-trade area, rest-of-world price, productivity in one region against the reference to 1e-8, each region's solution on its own, start from regions alone, errors (done) |
| 0.11.0 | cge_nest: declared CES/CET blocks as MPSGE's production blocks (begin, nest, input/output, end; list, drop), written by _cge_nest_text as user variables (leaf price per unit and quantity in units, price index and quantity of each nest, price index of the block) and equations (each leaf's demand or supply, the price of the output) in calibrated share form with base() values, replacing built-in equations (replace() with the equation's index beside a label, as Q4(lab, a), mapped by _cge_u_repel); base() of parameters (_cge_u_parbase); tf(f, a) in expressions (_cge_u_parel); the declarations kept in M.unest; the model restored if a block fails; tests: one nest against the built-in CES under tariff, efficiency and factor-efficiency shocks, after calibration again, two nests with one elasticity, Cobb-Douglas, two nests with a payroll tax against the built-in nests of value added, a CET block against T1/T2/P4, all to 1e-10; GAMS export check (done) |
| 0.10.2 | Perfect foresight (cge_dynamic, foresight terminal(constant|growth|base) start(recursive|base)): the exogenous path set period by period first (_cge_fs_advance, the shocks, _cge_fs_record); states for what a recursive run carries between periods (capital stocks by factor and activity, domestic and foreign debt, the efficiency index of growth targets, population and the workers of death factors relative to their exogenous paths), with the updates of Section 10 as equations and analytic derivatives (the allocation of new capital to specific factors included); shocks to capital and debt as after = a + b before, found by running the shocks program twice (_cge_fs_probe); stacked system of the full systems of all periods and the updates, Newton with a line search and the sparse LU in its own external; exact Jacobian within periods (capital stocks as extra columns of _cge_jac_trip), central differences for states entering through parameters, derivatives of user equations with respect to lags and leads across periods (codes in _cge_u_dvalue) and through the terminal condition; lead() (postfix type 11), tperiod/tfirst/tlast (type 12, p.tinfo), p.xlead; start from a recursive run with expectations from the period before, or the base; GAMS exports LEADk_ parameters and TPERIOD, TFIRST, TLAST; tests: foresight against recursive runs to 1e-9 for mobile and specific capital, shocks to capital and debt, growth targets, baselines, debt, deaths and lags, from both starts; the stacked Jacobian against central differences with both terminal conditions; leads against backward recursions; Tobin's q, each period re-solved alone and its leads against the next period; the period in user equations; errors (done) |
| 0.10.1 | Sparse LU for Newton's steps (cge_options, linsolver(dense|sparse|auto); cge_solve, sparse|dense): rows with more than max(50, 10 x average) entries set apart; Markowitz's rule with threshold pivoting (u = 0.1) on the rest, from a pool of 64 lowest-count columns refreshed every 16 steps, right-looking on the pattern with values; a column whose active entries fall to 1e-10 of its largest entry in the rows not set apart (rows that cancel, entries lost to rounding) is left over; the sparse block factorised left-looking in that order, A12 and A21 kept as entries, and the dense Schur complement formed a group of columns of inv(A11) A12 at a time; refactorisation in the same order while the pattern holds (entries within it allowed) and pivots stay above 1e-8 of their column of L and 1e-10 of their column of A11, the analysis kept for later solves; the fallbacks with central or one-sided differences use the sparse LU too (_cge_jac_cdtrip), and Powell's dense method is left out above 10,000 equations; the exact Jacobian as entries (_cge_jac_trip); tests: random matrices against dense solves, refactorisation, singular matrices, a pivot that falls below the threshold, dense rows with pairs of rows that cancel (which fail without the rounding check), the fallbacks' differences, and solutions with the sparse LU against the dense one for the reduced and full systems, constraints, user equations, a dynamic run, the optimiser and a loop; benchmark against the dense LU (done) |
| 0.10.0 | cge_gdx: write (a GAMS program, with 17 significant digits, that GAMS runs: AC and roles, SAM(AC,AC), LEVEL(sim,*,*,*) and CAL(*,*,*), '-' for missing indexes; labels ignore case, so the levels come first), read (gdxdump with dFormat=hexponential, read exactly through a table of exact powers of two; Mata's 2^k is not exact; Eps 0, infinities and NA missing; indexes named after domains; parameters, variables and equations with all fields, sets with text) and list; scripts run with shell, or written with norun for batch mode; cge_sam reads a SAM from a GDX symbol; tools/build_manual.py runs two-pass examples with the scripts between; tests: the program and scripts, hex floats and special values, variables, sets, scalars, the symbol list, a SAM from a GDX file; tools/gams/run_gdx_check.py: the round trip exact (SAM, CAL, LEVEL), GAMS's solution through its GDX file (4e-14) and a SAM from it (exact) (done) |
| 0.9.9 | cge_loop: scenario loops as GAMS loops and GUSS: targets as the instruments of cge_optimize (parameters, user parameters, fixed variables), values() lists in order or grid (every combination), scale, or a long dataset (scenario, target, value) with targets left out kept; each scenario from the shocks in place, warm-started from the scenario before (cold from the base), then from the base and by continuation, failures recorded; stored as name1, name2, ... with a loop record; measures (report measures or expressions), the results as a dataset; the shocks in place left unchanged; cge_gams, loop() writes and compares the scenarios as the periods of a run; tests against each scenario solved on its own, cold starts, a grid, multiples, fixed variables, shocks in place, measures against cge_results and cge_report, the dataset, a dataset of scenarios, a failure, the GAMS files and GAMS (export check case loop) (done) |
| 0.9.8 | cge_bound: attributes of model and user variables as GAMS's .lo/.up (domain bounds of a square system: points outside rejected by the solver's function, a note when the solution is at a bound, the nearest bounds after a failure), .scale (replacing the automatic scale), .l (starting levels of cge_solve) and .fx (exogenous variables only); definitions applied in order, relative to the base, saved, applied again on calibration, dropped with user variables; GAMS cge_bounds.inc (bounds left out of MCP scenarios); cge_listing, solution: the GAMS solution listing (LOWER, LEVEL, UPPER, MARGINAL) with the constraints' room and marginal; cge_gams writes adjusting variables at their fixed levels so that PATH finds the regimes, and compares GAMS's room and marginals (cge_cons_write.inc); cge_optimize: shadow prices of targets and constraints from the augmented Lagrangian's multipliers and reduced costs of instruments at bounds; tests against the solutions without attributes, the premiums and adjustments, finite differences of re-optimisations, save/use, calibration, the GAMS files and GAMS (export check cases bounds and boundscon) (done) |
| 0.9.7 | Functions of GAMS in the user language: max(), min() of two or more arguments, abs(), sqr(), log10(), ifthen(condition, x, y) with a condition on parameters, lags and numbers; prod(), smax() and smin() with the domains of sum() (one or two indexes, sets of pairs, conditions); card(); macros, cge_macro name(a, b) = expression, written out before the indexes, nested, saved and kept on calibration; postfix rows of type 10 with exact derivatives; GAMS text with the GAMS functions and eq/ne/and/or; tests against the formulas computed from the results, the exact Jacobian against central differences, save/use, calibration, the GAMS file and the errors, and GAMS (export check case functions) (done) |
| 0.9.6 | cge_microsim graph(): gic, incidence, poverty, groups, shapley, fiscal and bands, drawn from the results dataset in the style of journal figures (grey shades and line patterns, or Okabe-Ito colours with gcolor; no titles; 5 x 3.5 inches), gname(), gexport() to PDF, EPS or PNG, glabels(), gopts(); the manual's first figures (tools/build_manual.py copies fig_* files from the examples); tests that the GIC plots the results' percentiles (serset), the survey is unchanged, the files are written, and the errors (done) |
| 0.8.3 | cge_microsim: reweight() to the model's employment by factor or factor and activity, or given ratios, by minimum relative entropy (Newton), with a weights channel in decompose; svy: linearized standard errors of the mean and FGT measures (base, simulated, change; groups as subpopulations) from svyset's one-stage design; bands() across the draws of cge_sensitivity, keep(), with percentiles 5, 50, 95 and the standard deviation; tests against closed forms, the model's employment, svy: ratio, lincom and subpop, and _pctile across draws (done) |
| 0.8.2 | cge_microsim: CEQ fiscal incidence with market(), dtax(), transfers(), itax(), subsidies() and inkind(): market, net market, disposable, consumable and final income; concentration coefficients (mid-ranks), Kakwani, coverage (all and poor), marginal contributions to the Gini and headcount, Reynolds-Smolensky, reranking and fiscal impoverishment, base and simulated; instruments changing with the model (direct tax rates, transfers, consumption tax wedges, government and insurance health spending for in-kind benefits); incidence by quantile of market income; tests against direct formulas, homogeneity and the model's health spending (done) |
| 0.8.1 | cge_microsim: equivalent and compensating variations by household (the group's LES scaled to the household, or Cobb-Douglas in its own budget shares), by group, by quantile and as variables; option decompose: Shapley decomposition of every summary measure among channels (each income source, direct taxes and savings, households following their group, prices) and Datt-Ravallion growth and redistribution in Shapley form; tests against cge_report's group EV and CV (Cobb-Douglas and LES), Cobb-Douglas formulas, homogeneity, efficiency, a dummy channel, the two-channel formula and the growth formula (done) |
| 0.8.0 | cge_microsim: several simulations per call (sim(a b ...), numbered generate() variables); every result as a dataset (clear, saving()); several poverty lines, numbers or variables with a line for each household, with the number of poor; Theil, mean log deviation, GE(2), Atkinson (0.5, 1, 2), Palma and S80/S20; incidence by quantile of base consumption per person (quantiles(#), as xtile) and the growth incidence curve at percentiles 1-99 (as _pctile); option detail; tests against xtile, _pctile and direct computations, closed forms for the Lorenz-curve ratios, and single runs (done) |
| 0.7.2 | Conditions, as GAMS's dollar operator: sum(i$(cond), ...), term$(cond), and conditional domains NAME(i)$(cond) of user variables and equations; comparisons, & | !, set membership, sameas() and ord(); evaluated at the base when a definition is added and when the model is calibrated, so the system is the same in every scenario; elements outside a domain do not exist (0 where referred to, fixed at 0 in GAMS); a comparison with a missing value is an error; tests against sums written out and the model without user equations, Jacobian check, save/use, calibration again, a shock to a parameter that a condition uses, and GAMS (export check case conditions) (done) |
| 0.7.0 | Faster solves: the exact Jacobian (derivatives of every block as triplets, the old exact rows reused, forward differentiation of user equations, chain rule through the left-out definitions of the reduced system, checked against column-by-column central differences at the base, at solutions and at perturbed points in every layout); Newton's method continues after each step, full or shortened, with Broyden's good updates of the inverse Jacobian in product form, and polishes a converged solution toward tol/1000; cge_optimize solves without the updates; cge_solve notes collapsed solutions (r(N_collapsed)); the 250-activity benchmark 27 s instead of 96 in Stata 13.1/IC, 29 instead of 72 in StataNow/MP 19.5 (done) |
| 0.6.4 | Help files and fixes: every help file checked against its command, references to developer documents replaced by the Reference Manual; cge_solve checks that the system is square (error 459, as after cge_variable value() without an equation); cge_shock uses the set of a user variable's index; the roles sheet of cge_template lists every role; template groups may not take the label of an account outside the group; cge_report writes the debt sheet; cge_dynresults keeps the data in memory on failure; cge_save and cge_use add .cgem when the file name has no extension, whatever the folder names; cge_microsim requires a positive poverty line; cge_results stores its results with nodisplay; cge_multiplier ignores decompose with inject(); cge_sam, cge_gams and cge_sensitivity return only their own results; a dynamic run that fails stores nothing and leaves the model, its shocks and an earlier run of the same name as they were, and a run solved again replaces every period of the earlier one (before, a failed rerun could mix periods of two runs); the help examples run on the shipped SYNTHETIC data (the cge_dynamic example used an account of a country SAM), and two SMCL faults in the cge_map and cge_balance help are fixed; tests for each fix (done) |
| Manual | The user manual rewritten as the cge-stata Reference Manual (docs/manual/cge-stata-manual.pdf), typeset from LaTeX in the form of Stata's manuals: a user's guide with a worked example; the model's notation, every equation, the closures, calibration, solution method, checks, reporting measures and extensions, and the methods of the commands; and an entry for each command with its syntax, options, examples and their output, stored results, and methods and formulas. tools/build_manual.py builds it and runs its examples in Stata, keeping only the marked output and refusing output that names a path, a user or a licence (done) |
| 0.6.3 | Faster solves: Newton's Jacobian from one-sided differences (one evaluation of the equations per group of columns instead of two; step 1e-7), with a second Newton attempt with central differences before Powell's method; the 200-activity benchmark solves about a third faster in Stata 13.1/IC and almost half in StataNow/MP 19.5, with the same iterations and solutions; tests check the one-sided Jacobian against the column-by-column one and both kinds of Newton against each other, also across the switch of a minimum-wage regime (done) |
| 0.6.2 | Larger models: cge_gams import() stores a GAMS solution as a Stata simulation after checking it against the model's equations; the benchmark (tools/bench) times Stata 13.1/IC and StataNow/MP 19.5 against GAMS with PATH and imports each GAMS solution; the manual's guidance on when to solve in GAMS. A sparse solver in Mata, which has no sparse matrices, is not attempted. Tested in StataNow/MP 19.5 as well as Stata 13.1/IC: cge_use now reads models saved in Stata 13 in later versions of Stata (the check of the file's identifier depended on the length of the current version's header), and in Stata 13 stops with a message on files saved in later versions, whose Mata file format it cannot read; the benchmark's do-files set a line size that keeps their results on one line; the export check (tools/gams) no longer adds another copy of the rows of the cases with constraints to its results file at each run (done) |
| 0.6.1 | User variables and equations (model_spec.md, Section 19): cge_variable and cge_equation; a small expression language (variables, parameters, base(), sums, exp, ln, sqrt) compiled to postfix rows, solved as block U with differences on its pattern; saved, kept on recalibration; written into the GAMS export (cge_user.inc) (done) |
| 0.6.0 | Policy optimisation (model_spec.md, Section 18): cge_optimize instruments() maximize() minimize() targets() lower() upper(); projected Newton with central differences, an active set for bounds, Newton on the targets, the augmented Lagrangian for targets with an objective; a Python reference with scipy (done) |
| 0.5.3 | Dynamic runs exported to GAMS: cge_gams dynamic(); each period's changes from the period before, as ratios, including subsistence quantities, the base of the health link and government transfers within government; a driver that solves the periods in order; comparison of every period (done) |
| 0.5.2 | Output of a commodity from several activities (model_spec.md, Section 17.3): cge_calibrate sigmaac(); a CES or Cobb-Douglas aggregate of the activities' outputs with a price for each activity (PXAC, QXAC), in place of perfect substitutes; the GAMS model and export (done) |
| 0.5.1 | Nests of value added (model_spec.md, Section 17.2): cge_calibrate nests() and sigmanest(); nests of factors and commodities, CES or Cobb-Douglas, at the top of value added; commodities in nests leave intermediate input; QNA and PNA; value added in reports and the income side of GDP exclude nest commodities; the GAMS model and export; a synthetic SAM with labour types and energy (done) |
| 0.5.0 | Taxes on factor use by activity and on factor income (model_spec.md, Section 17.1): cge_map factortax(account:factor) and factorincometax(); rates tf and tfy calibrated from the SAM, in the factor first-order conditions, value added at factor cost and the distribution of factor income; shocks, reports, templates, the GAMS model and export; a synthetic factor-tax SAM (done) |
| 0.4.5 | Closure swaps (cge_closure, swap(); model_spec.md, Section 6) with a structural check that no equation is left without a free variable, exported to GAMS; continuation for large shocks (cge_solve, steps(), and automatically after a failure); diagnostics after a failure or on request (diagnose): largest residuals by block and element, empty rows and columns, smallest pivot (done) |
| 0.4.4 | Bounds and complementarity (model_spec.md, Section 16): rents on imports, exports and activity output (RM, RE, RA) with a chosen recipient; constraints pairing a bound on one element of a variable with an adjusting variable that the closure fixes, solved as complementarity conditions, first smoothed and then exactly (cge_constraint); import and export quotas, capacity limits, a borrowing limit under a peg, deficit ceilings and wage floors; rents in GDP; the regimes reported and stored with each simulation; exported to GAMS as a mixed complementarity problem and checked with PATH (done) |
| 0.4.3 | Export to GAMS (docs/gams.md): the SAM, the roles of its accounts and the calibration settings, with the independent GAMS model, which calibrates itself, and a scenario as ratios to the base; solved with PATH, CONOPT or KNITRO as a system of equations or with NLP solvers such as IPOPT, and compared with Stata's solution (cge_gams); factor quantities in the GAMS model; the check run with other solvers (done) |
| 0.4.2 | Structural path analysis (docs/sam_tools.md, Section 7): elementary paths between two accounts with direct influence, path multiplier (the determinant of the multiplier matrix on the path's accounts) and total influence, which add up to the multiplier; limits on path length and influence (cge_spa) (done) |
| 0.4.1 | SAM multiplier analysis (docs/sam_tools.md, Section 6): accounting multipliers, the Pyatt-Round decomposition into transfer, open-loop and closed-loop effects, and injections, from the mapped SAM (cge_multiplier) (done) |
| 0.4.0 | User manual (docs/manual, ten chapters); a worked example from an unbalanced SAM to policy results, sensitivity, dynamics and poverty (examples/raw_sam_to_results.do); every example run by the test suite (tests/test_examples.do); a draft article for the Stata Journal, kept outside the repository until submission (done) |

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
