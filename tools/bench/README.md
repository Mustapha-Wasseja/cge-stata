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
largest model above would need about 13 GB for that Jacobian. Stata IC
limits a SAM to about 2,040 accounts (2,048 variables when it is read);
Stata SE and MP allow more.
