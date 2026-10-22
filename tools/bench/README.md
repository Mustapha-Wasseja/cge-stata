# Scale benchmark

`gen_large_sam.py` builds synthetic SAMs of any size. They are SYNTHETIC: the
SAMs describe no country. Each has n activities paired with n commodities,
formal and informal labour, capital, h household groups, an enterprise,
government with three taxes, savings-investment and the rest of the world.
Intermediate input use covers about half of all commodity-activity cells, as
in a detailed national input-output table. `run_bench.py` reads, maps,
calibrates and solves each of them in Stata (a removal of all import tariffs,
uniform elasticities 0.8, 2 and 2), with the reduced system and, for the
smaller ones, the full system.

```
python tools/bench/run_bench.py [--sizes 40x5,80x10,120x10,160x20,200x20,250x20] [--full-up-to 120]
```

## Result with the exact Jacobian and Broyden's updates (version 0.7.0, 22 October 2026; Windows laptop)

```
python tools/bench/run_bench.py --stata "C:/Program Files (x86)/Stata13/Stata-64.exe" --sizes 40x5,80x10,120x10,160x20,200x20,250x20 --full-up-to 0 --gams C:/GAMS/54/gams.exe --out tools/bench/bench_results_070.csv
python tools/bench/run_bench.py --stata "C:/Program Files/StataNow19/StataMP-64.exe" --sizes 40x5,80x10,120x10,160x20,200x20,250x20 --full-up-to 0 --gams C:/GAMS/54/gams.exe --out tools/bench/bench_results_070_statanow19.csv
```

From version 0.7.0 the Jacobian is exact, and after each Newton step, full
or shortened by the line search, Newton's method continues with Broyden's
updates of the inverse Jacobian (Reference Manual, *The solution method*).
`bench_results_070.csv` (Stata 13.1/IC) and `bench_results_070_statanow19.csv`
(StataNow/MP 19.5) hold the runs with GAMS. Each 0.7.0 column gives two runs
of the same models, an earlier one without GAMS and the one with GAMS, to
show how much times vary; the 0.6.3 columns are those of the table below.

| Activities | Equations | Solved (reduced) | Jacobians, 0.6.3 | Jacobians, 0.7.0 | Stata 13.1/IC, 0.6.3 (s) | Stata 13.1/IC, 0.7.0 (s) | StataNow/MP 19.5, 0.6.3 (s) | StataNow/MP 19.5, 0.7.0 (s) | Stata vs GAMS |
|---|---|---|---|---|---|---|---|---|---|
| 40 | 1,814 | 711 | 3 | 2 | 0.4 | 0.5, 0.4 | 0.5 | 0.5, 0.5 | 1e-13 |
| 80 | 5,446 | 1,407 | 4 | 3 | 2.7 | 2.6, 1.7 | 2.7 | 1.8, 2.3 | 2e-12 |
| 120 | 10,555 | 2,045 | 3 | 3 | 5.0 | 3.2, 3.2 | 3.5 | 3.3, 4.9 | 5e-13 |
| 160 | 18,483 | 2,757 | 1 | 2 | 6.0 | 3.9, 5.2 | 5.6 | 6.0, 4.4 | 3e-13 |
| 200 | 26,858 | 3,418 | 4 | 3 | 37.8 | 14.5, 11.8 | 32.3 | 14.0, 11.1 | 6e-13 |
| 250 | 40,190 | 4,254 | 6 | 4 | 95.8 | 27.0, 54.4 | 71.7 | 29.0, 26.6 | 3e-9 |

The 250-activity model took 54.4 seconds in the run with GAMS, but 30.2 and
32.3 in two further runs straight after it: other work on the machine can
double a time. Taking the typical times, it solves about three times faster
in Stata 13.1/IC and two and a half times faster in StataNow/MP 19.5. Every
GAMS solution (model status 16, solved) satisfies the model's equations in
Stata to $2 \times 10^{-9}$ or better and agrees with Stata's solution to
$3 \times 10^{-9}$ or better. GAMS took 10 to 22 seconds for the whole run of
each model that day, against 1.8 to 4.7 seconds the day before (table below):
starting GAMS took 9 to 14 seconds then, even for a program with one scalar,
so the earlier times are the better measure of solving.

Building the exact Jacobian takes about 0.9 seconds for the 250-activity
model in Stata 13.1/IC, against an evaluation of the equations for each of
dozens of groups of columns before. Timed in Stata 13.1/IC, its solve spent
11.4 seconds in four LU factorisations of the 4,254-equation Jacobian, 3.6
in the four Jacobians and 6.3 in 30 evaluations of the equations: the dense
LU factorisation is now most of a large solve. A first form of the updates,
taken only after full Newton steps, needed six Jacobians for that model; the
first Newton steps of a large tariff removal are shortened by the line
search, and with updates after them four suffice.

## Result with one-sided differences (version 0.6.3, 21 October 2026; Windows laptop)

```
python tools/bench/run_bench.py --sizes 40x5,80x10,120x10,160x20,200x20,250x20 --full-up-to 0 --gams C:/GAMS/54/gams.exe
python tools/bench/run_bench.py --stata "C:/Program Files/StataNow19/StataMP-64.exe" --sizes 40x5,80x10,120x10,160x20,200x20,250x20 --full-up-to 0 --gams C:/GAMS/54/gams.exe --out tools/bench/bench_results_statanow19.csv
```

From version 0.6.3 Newton's Jacobian is built with one-sided differences: one
evaluation of the equations for each group of columns instead of two. Each
model is solved, exported, solved by GAMS and imported as for version 0.6.2
below; `bench_results.csv` (Stata 13.1/IC) and `bench_results_statanow19.csv`
(StataNow/MP 19.5) hold these results. The last two columns give the larger
value of the two Stata runs.

| Activities | Households | Accounts | Equations | Solved (reduced) | Jacobians | Stata 13.1/IC (s) | StataNow/MP 19.5, 4 cores (s) | GAMS, whole run (s) | GAMS solution in Stata: residual | Stata vs GAMS |
|---|---|---|---|---|---|---|---|---|---|---|
| 40 | 5 | 95 | 1,814 | 711 | 3 | 0.4 | 0.5 | 1.8 | 2e-13 | 5e-12 |
| 80 | 10 | 180 | 5,446 | 1,407 | 4 | 2.7 | 2.7 | 1.8 | 3e-13 | 9e-12 |
| 120 | 10 | 260 | 10,555 | 2,045 | 3 | 5.0 | 3.5 | 2.0 | 5e-13 | 3e-11 |
| 160 | 20 | 350 | 18,483 | 2,757 | 1 | 6.0 | 5.6 | 2.5 | 1e-13 | 6e-11 |
| 200 | 20 | 430 | 26,858 | 3,418 | 4 | 37.8 | 32.3 | 2.6 | 8e-13 | 5e-12 |
| 250 | 20 | 530 | 40,190 | 4,254 | 6 | 95.8 | 71.7 | 4.7 | 2e-09 | 3e-09 |

On the 200-activity model, in runs one after the other that alternated the
two methods, one-sided differences shortened the solve from 67.5 and 65.8
seconds to 47.5 and 43.8 in Stata 13.1/IC, and from 54.8 and 53.2 to 28.5 and
31.0 in StataNow/MP 19.5 on four cores. Both methods took 15 iterations and 4
Jacobians, and their solutions agree to 2e-13.

## Result with GAMS (version 0.6.2, 21 October 2026; Windows laptop)

```
python tools/bench/run_bench.py --sizes 40x5,80x10,120x10,160x20,200x20,250x20 --full-up-to 0 --gams C:/GAMS/54/gams.exe
python tools/bench/run_bench.py --stata "C:/Program Files/StataNow19/StataMP-64.exe" --sizes 40x5,80x10,120x10,160x20,200x20,250x20 --full-up-to 0 --gams C:/GAMS/54/gams.exe --out tools/bench/bench_results_statanow19.csv
```

Each model is solved in Stata 13.1/IC and in StataNow/MP 19.5 on four cores,
then exported, solved by GAMS 54.2 with PATH, and its GAMS solution imported
into Stata (`cge_gams ..., import()`), where it is checked against the
model's equations and compared with Stata's solution. The GAMS time is the
whole run: GAMS calibrates the model from the SAM, solves the base and then
the scenario. The last two columns give the larger value of the two Stata
runs. Version 0.6.2 built the Jacobian with central differences.

| Activities | Households | Accounts | Equations | Solved (reduced) | Jacobians | Stata 13.1/IC (s) | StataNow/MP 19.5, 4 cores (s) | GAMS, whole run (s) | GAMS solution in Stata: residual | Stata vs GAMS |
|---|---|---|---|---|---|---|---|---|---|---|
| 40 | 5 | 95 | 1,814 | 711 | 3 | 0.7 | 0.5 | 1.9 | 2e-13 | 5e-12 |
| 80 | 10 | 180 | 5,446 | 1,407 | 4 | 3.7 | 3.5 | 2.2 | 3e-13 | 9e-12 |
| 120 | 10 | 260 | 10,555 | 2,045 | 3 | 7.1 | 5.6 | 2.0 | 5e-13 | 3e-11 |
| 160 | 20 | 350 | 18,483 | 2,757 | 1 | 9.6 | 6.8 | 3.3 | 1e-13 | 6e-11 |
| 200 | 20 | 430 | 26,858 | 3,418 | 4 | 53.9 | 53.3 | 4.0 | 8e-13 | 5e-12 |
| 250 | 20 | 530 | 40,190 | 4,254 | 6 | 143.0 | 126.9 | 4.1 | 2e-09 | 3e-09 |

Times vary from run to run with other work on the machine, by as much as
40 per cent. To see where the time goes, the 200-activity model was solved again,
with timers added around the parts of the solver in a copy of the package,
in three runs one after the other: in Stata 13.1/IC, in StataNow/MP 19.5
limited to one core (`set processors 1`), and in StataNow/MP 19.5 on four
cores.

| Part of the solve (200 activities, 3,418 equations in the reduced system) | Calls | Stata 13.1/IC (s) | StataNow/MP 19.5, 1 core (s) | StataNow/MP 19.5, 4 cores (s) |
|---|---|---|---|---|
| Evaluations of the equations for the finite-difference Jacobian (67 groups of columns, two evaluations each, four Jacobians) | 536 | 40.8 | 38.3 | 28.5 |
| Analytic rows of the Jacobian | 4 | 2.3 | 1.9 | 2.4 |
| LU factorisation of the Jacobian (`_lud()`) | 4 | 4.5 | 15.6 | 4.2 |
| Triangular solves | 16 | 1.8 | 2.6 | 2.0 |
| Other evaluations of the equations (Newton steps and line search) | 21 | 1.6 | 1.4 | 0.7 |
| Whole solve | | 51.7 | 60.4 | 38.3 |

Most of the time goes into evaluating the model's equations to build the
Jacobian, so the time follows the number of Jacobians and of groups of
columns. These evaluations are long sequences of operations on vectors of a
few thousand elements, which four cores shortened by a quarter. StataNow's
LU factorisation is much faster than Stata 13's on a full matrix (1.5 against
19.0 seconds for a random 3,418 x 3,418 matrix, on one core), but on the
Jacobian, which is mostly zeros, Stata 13's took 1.1 seconds per
factorisation and StataNow's 3.9 on one core and 1.1 on four. On this model,
four cores made StataNow's solve 1.6 times faster than one core, and 1.4
times faster than Stata 13.1/IC.

GAMS, with analytic derivatives and a sparse solver, barely slows over this
range. Beyond about 2,000 equations in the reduced system, GAMS with PATH is
the faster route, and its solution can be used in Stata through `import()`.

## Result (version 0.2.0, 16 October 2026; Stata 13.1 IC, Windows laptop)

| Activities | Households | Accounts | Equations | Solved (reduced) | Jacobians | Solve, reduced (s) | Solve, full (s) | Reduced vs full |
|---|---|---|---|---|---|---|---|---|
| 40 | 5 | 95 | 1,814 | 711 | 3 | 1.9 | 10.1 | 3e-12 |
| 80 | 10 | 180 | 5,446 | 1,407 | 4 | 4.8 | 73.7 | 2e-11 |
| 120 | 10 | 260 | 10,555 | 2,045 | 3 | 17.8 | 370.9 | 2e-11 |
| 160 | 20 | 350 | 18,483 | 2,757 | 1 | 20.2 | | |
| 200 | 20 | 430 | 26,858 | 3,418 | 4 | 115.3 | | |
| 250 | 20 | 530 | 40,190 | 4,254 | 6 | 178.1 | | |

Times varied with other work on the machine, so they show orders of magnitude.
Before version 0.2.0 the practical limit was about 15,000 to 20,000
equations, set by the memory of the dense Jacobian of the full system. The
largest model above would need about 13 GB for that Jacobian. Stata IC holds
at most 2,048 variables; from version 0.3.0, `cge_sam` reads larger SAMs
directly from CSV files or from long data.
