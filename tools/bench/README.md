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
runs.

| Activities | Households | Accounts | Equations | Solved (reduced) | Jacobians | Stata 13.1/IC (s) | StataNow/MP 19.5, 4 cores (s) | GAMS, whole run (s) | GAMS solution in Stata: residual | Stata vs GAMS |
|---|---|---|---|---|---|---|---|---|---|---|
| 40 | 5 | 95 | 1,814 | 711 | 3 | 0.7 | 0.5 | 1.9 | 2e-13 | 5e-12 |
| 80 | 10 | 180 | 5,446 | 1,407 | 4 | 3.7 | 3.5 | 2.2 | 3e-13 | 9e-12 |
| 120 | 10 | 260 | 10,555 | 2,045 | 3 | 7.1 | 5.6 | 2.0 | 5e-13 | 3e-11 |
| 160 | 20 | 350 | 18,483 | 2,757 | 1 | 9.6 | 6.8 | 3.3 | 1e-13 | 6e-11 |
| 200 | 20 | 430 | 26,858 | 3,418 | 4 | 53.9 | 53.3 | 4.0 | 8e-13 | 5e-12 |
| 250 | 20 | 530 | 40,190 | 4,254 | 6 | 143.0 | 126.9 | 4.1 | 2e-09 | 3e-09 |

Times vary from run to run with other work on the machine. In a second run
of the 200-activity model, with timers added around the parts of the solver
in a copy of the package, the solve took 66.0 seconds in Stata 13.1/IC and
44.9 in StataNow/MP 19.5:

| Part of the solve (200 activities, 3,418 equations in the reduced system) | Calls | Stata 13.1/IC (s) | StataNow/MP 19.5, 4 cores (s) |
|---|---|---|---|
| Evaluations of the equations for the finite-difference Jacobian (67 groups of columns, two evaluations each, four Jacobians) | 536 | 53.0 | 33.9 |
| Analytic rows of the Jacobian | 4 | 2.7 | 1.8 |
| LU factorisation of the Jacobian (`_lud()`) | 4 | 5.2 | 4.4 |
| Triangular solves | 16 | 2.2 | 2.8 |
| Other evaluations of the equations (Newton steps and line search) | 21 | 2.0 | 1.4 |
| Whole solve | | 66.0 | 44.9 |

Most of Stata's time goes into evaluating the model's equations to build the
Jacobian, about 0.1 second for each evaluation in Stata 13.1/IC and 0.06 in
StataNow/MP, so the time follows the number of Jacobians and of groups of
columns. The LU factorisation takes less than a tenth, and four cores
shorten it little. GAMS, with analytic derivatives and a sparse solver,
barely slows over this range. Beyond about 2,000 equations in the reduced
system, GAMS with PATH is the faster route, and its solution can be used in
Stata through `import()`.

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
