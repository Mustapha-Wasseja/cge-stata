# 10. Validation, performance and troubleshooting

## 10.1 How results are validated

**Three implementations.** The equations of [model_spec.md](../model_spec.md)
are implemented in Stata and Mata, in a Python reference model
(`reference/cge_ref`) and in GAMS (`tools/gams`). The Python model runs in
continuous integration and writes the expected results of every test case;
the Stata test suite (`tests/run_all.do`) compares every variable of every
case with them and requires agreement to 1e-6 (in practice 1e-11 or better).
The GAMS model was written from the specification, calibrates from the SAM
alone and is solved with PATH; it reproduces the same 159 scenarios, 13 of them
with constraints solved as complementarity problems, to 3e-11 or better
(`tools/gams/README.md`). From version 0.4.3 `cge_gams` writes any model for
that GAMS program; 22 exported cases, solved with PATH, CONOPT, KNITRO and
IPOPT, reproduce Stata's solutions to 4e-9 or better (chapter 11).

**Checks in every run.** Calibration checks benchmark replication; `cge_check`
adds SAM balance, a square closure, homogeneity of degree zero in prices, a
perturbed start, Walras's law and the GDP identity (chapter 3). Run it after
building a model and after changing the closure.

## 10.2 Performance

The solver works on a reduced system and computes the Jacobian by groups of
columns (chapter 4). On a Windows laptop, synthetic SAMs of increasing size
solved a tariff removal in these times, in Stata 13.1/IC, in StataNow/MP 19.5
on four cores, and in GAMS with PATH (`tools/bench`, version 0.6.2):

| Activities | Accounts | Equations | Solved (reduced) | Stata 13.1/IC (s) | StataNow/MP 19.5, 4 cores (s) | GAMS, whole run (s) |
|---|---|---|---|---|---|---|
| 40 | 95 | 1,814 | 711 | 0.7 | 0.5 | 1.9 |
| 80 | 180 | 5,446 | 1,407 | 3.7 | 3.5 | 2.2 |
| 120 | 260 | 10,555 | 2,045 | 7.1 | 5.6 | 2.0 |
| 160 | 350 | 18,483 | 2,757 | 9.6 | 6.8 | 3.3 |
| 200 | 430 | 26,858 | 3,418 | 53.9 | 53.3 | 4.0 |
| 250 | 530 | 40,190 | 4,254 | 143.0 | 126.9 | 4.1 |

Most of Stata's time goes into evaluating the model's equations to build the
Jacobian by finite differences: about four fifths of the solve for the
200-activity model in Stata 13.1/IC. In runs one after the other, four cores
of StataNow/MP made that solve about 1.6 times faster than one core, and 1.4
times faster than Stata 13.1/IC. StataNow is about ten to thirty times faster
than Stata 13 at large dense matrix operations, which the solver uses little
(`tools/bench/README.md`). GAMS uses analytic derivatives and a sparse
solver, and its time, which includes calibration and the base solve, barely
grows over this range.
For models with more than about 2,000 equations in the reduced system, export
the scenario to GAMS and bring the solution back with
`cge_gams ..., import()` (chapter 11.4); the solution is checked against the
model's equations in Stata.

Times vary with other work on the machine; they show orders of magnitude.
Calibration and mapping are fast compared with solving. Stata/IC holds at
most 2,048 variables, but `cge_sam` reads larger SAMs directly from CSV
files or long data.

## 10.3 Common problems

| Symptom | Likely cause and remedy |
|---|---|
| `cge_map` exits with error 459 and a table of problems | cells the model does not represent, unbalanced accounts, or accounts without roles: map the accounts differently (chapter 3), use a layout option, or correct the SAM |
| "activity output does not equal its sales" | an activity's column total differs from its row of sales: balance the SAM, or check that exports and home consumption are recorded as the model expects |
| "every activity needs positive value added" | an activity without factor payments: merge it with another activity or remove it |
| benchmark replication fails | an error in the SAM or mapping that the checks did not catch; check negative cells, zero sales and the elasticities (for example `sigmaq(1)` for an imported commodity is not allowed) |
| "closure is not square" | a closure fixes too many or too few variables, for example a factor closure that the model's data cannot support |
| `cge_solve` exits with error 430 | the shock has no solution, or one too far from the base: read the diagnostics (the equations with the largest residuals, and the smallest pivot), try more steps with `steps()`, check the closure, and look at `trace` |
| "the closure is singular" | a swap leaves an equation with no free variable: free a variable of that equation, or undo the swap |
| a shock "is not fixed under the current closure" | the variable is endogenous under the closure: change the closure, or shock a parameter |
| a negative or missing value appears in a report | percentage changes of negative bases (a deficit) are relative to the absolute value; a zero base gives a missing change |
| Stata 13 cannot install from GitHub | its TLS version is too old: install from a downloaded copy (chapter 1) |

`help cge_map` lists every flow the model represents, and model_spec.md,
Section 7.0, the rules behind the checks.

## 10.4 Reporting results

State with every result: the SAM, its year and source, and how it was
prepared (aggregation, balancing, totals given); the elasticities and their
sources; the closure; and the sensitivity of the main results to the
elasticities. `cge_report, saving()` and `cge_save` keep the record.
