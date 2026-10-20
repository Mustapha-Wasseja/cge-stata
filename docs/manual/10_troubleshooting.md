# 10. Validation, performance and troubleshooting

## 10.1 How results are validated

**Three implementations.** The equations of [model_spec.md](../model_spec.md)
are implemented in Stata and Mata, in a Python reference model
(`reference/cge_ref`) and in GAMS (`tools/gams`). The Python model runs in
continuous integration and writes the expected results of every test case;
the Stata test suite (`tests/run_all.do`) compares every variable of every
case with them and requires agreement to 1e-6 (in practice 1e-11 or better).
The GAMS model was written from the specification, calibrates from the SAM
alone and is solved with PATH; it reproduces the same 139 scenarios to 3e-11
or better (`tools/gams/README.md`).

**Checks in every run.** Calibration checks benchmark replication; `cge_check`
adds SAM balance, a square closure, homogeneity of degree zero in prices, a
perturbed start, Walras's law and the GDP identity (chapter 3). Run it after
building a model and after changing the closure.

## 10.2 Performance

The solver works on a reduced system and computes the Jacobian by groups of
columns (chapter 4). On a Windows laptop with Stata 13.1/IC, synthetic SAMs of
increasing size solved a tariff removal in these times (`tools/bench`):

| Activities | Accounts | Equations | Solved (reduced) | Solve (seconds) |
|---|---|---|---|---|
| 40 | 95 | 1,814 | 711 | 1.9 |
| 120 | 260 | 10,555 | 2,045 | 17.8 |
| 250 | 530 | 40,190 | 4,254 | 178.1 |

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
| `cge_solve` exits with error 430 | the shock is too large for the starting point, or the closure has no solution: try the shock in steps, check the closure, and look at `trace` |
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
