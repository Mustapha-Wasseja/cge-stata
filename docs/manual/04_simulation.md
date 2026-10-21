# 4. Closures, shocks and solving

## 4.1 Closures: `cge_closure`

The model has more variables than equations; the closure chooses which
variables are fixed. It reflects assumptions about how the economy adjusts,
and results can depend on it as much as on the shock. `cge_closure` sets five
blocks ([model_spec.md](../model_spec.md), Section 6):

| Block | Options | Default |
|---|---|---|
| External account | `flexexr`: foreign savings fixed, the exchange rate adjusts; `fixexr`: the exchange rate fixed, foreign savings adjust | `flexexr` |
| Government | `flexgsav`: tax rates fixed, government savings adjust; `fixgsav` with `direct`, `sales`, `import` or `vat`: government savings fixed, that tax's rates are scaled to keep them | `flexgsav` |
| Savings-investment | `savings`: savings rates fixed, investment adjusts; `investment`: investment fixed, savings rates are scaled | `savings` |
| Numeraire | `cpi` or `dpi` (producer prices of domestic sales) | `cpi` |
| Each factor | `mobile`, `specific` (fixed in each activity), `unemployed` (fixed wage), `wagecurve`, `minwage` (chapter 6) | `mobile` |

```stata
cge_closure, government(fixgsav direct)
cge_closure, external(fixexr) savinv(investment) factors(cap:specific)
```

The closure is checked to be square, displayed, and stored with each
simulation. A closure set with `cge_closure` stays until changed;
`cge_calibrate` resets the default.

**Swaps.** From version 0.4.5, `swap()` changes the closure element by
element, as GAMS modellers do by fixing and freeing variables. Each pair fixes
a variable that the closure leaves free and frees one that it fixes:

```stata
cge_closure, swap(GSAV GADJ)                 // fixed government savings, spending adjusts
cge_closure, swap(EXR CPI)                   // the exchange rate as numeraire
cge_closure, swap(QG(com_hlt) GADJ)          // fix health purchases, then shock them:
cge_shock QG, elements(com_hlt) scale(1.2)   //   other purchases scale with them
cge_closure, swap(none)                      // remove the swaps
```

`cge_closure` rejects a swap that leaves an equation with no free variable,
naming the equation, since the model would then have no unique solution.

## 4.2 Shocks: `cge_shock`

`cge_shock` changes a parameter, or a variable fixed by the closure, before
the next solve. Shocks accumulate until `cge_shock, reset`.

```stata
cge_shock tm, value(0)                         // remove every import tariff
cge_shock pwm, elements(com_man) scale(1.1)    // world price of manufactures +10%
cge_shock ad, elements(act_agr) scale(1.05)    // agricultural productivity +5%
cge_shock QFS, elements(lab) scale(1.05)       // labour supply +5% (fixed under mobile)
cge_shock FSAV, scale(0.8)                     // foreign savings -20% (fixed under flexexr)
cge_shock qg, elements(com_hlt) scale(1.2)     // government health purchases +20%
```

Parameters can be shocked whatever the closure; a variable only while the
closure fixes it. The parameters are:

| Group | Parameters |
|---|---|
| Taxes | `tm` import tariffs, `te` export taxes, `tq` sales taxes, `ta` activity taxes, `tv` VAT rates, `kappa` VAT credit shares |
| World prices | `pwm`, `pwe` (with finite export demand, a shift in world demand) |
| Productivity | `ad` value-added efficiency by activity, `af` factor efficiency |
| Spending and transfers | `qg`, `qinv`, `trdg`, `trdr`, `trfr`, `trgr`, `trrg` |
| Health fund | `tshi`, `qshi`, `trshi`, `trshir` |
| Public debt | `rd`, `rf`, `ddebt`, `fdebt` |
| Labour markets | `qlf`, `wmin`, `wref` |
| Health outcomes | `sick`, `mort` |

`help cge_shock` describes each one. Real transfers (`trdg`, `trshi`) are in
CPI terms; flows with the rest of the world in foreign currency.

## 4.3 Solving: `cge_solve`

```stata
cge_solve, name(notariff)
cge_solve, name(check) tolerance(1e-12) trace
```

`cge_solve` solves from the base under the current closure and shocks, and
stores the solution as a named simulation; solving under an existing name
replaces it. The method is Newton-Raphson with a backtracking line search on
scaled variables. It works on a reduced system: explicit definitions (such as
intermediate and household demand) are left out and computed from the other
variables, which makes large models much smaller. The Jacobian combines exact
derivatives for the equations with many variables with central differences,
taken over groups of variables that share no equation. If Newton fails,
Powell's hybrid method is tried, then Newton again to polish the result.

If that fails too, the shock is applied by **continuation** (from version
0.4.5): in 4 equal steps, then 16, each solution the start of the next.
`steps(#)` asks for a number of steps from the start, and `steps(1)` turns
continuation off. A shock that defeats both methods is often one that the
economy cannot absorb: government purchases ten times larger, for example.
The command then stops with error 430 and displays **diagnostics**:

- the equations with the largest residuals at the last point, by block and
  element;
- any equation with no free variable, and any free variable in no equation;
- the smallest pivot of the Jacobian, relative to the largest, and the
  variable it belongs to.

`cge_solve, diagnose` displays them after a solve that converges too.

The solution is accepted when the largest scaled residual, over every
equation, is below the tolerance (1e-10 by default). The residual and the
Walras slack (zero at a solution) are displayed with each solve.

## 4.4 Choosing instruments: `cge_optimize`

`cge_optimize` (from version 0.6.0) chooses a few instruments to maximise or
minimise a report measure, or to reach targets, solving the model at every
trial (model_spec.md, Section 18). Under a revenue-neutral closure, the
tariff on manufactures that maximises household welfare is:

```stata
cge_closure, government(fixgsav)
cge_optimize, instruments(tm(com_man)) maximize(welfare equivalent_variation hhd) ///
    lower(tm(com_man):-0.5) upper(tm(com_man):1)
```

On the synthetic SAM it is 30 per cent: the sales taxes and the tariff on
agriculture already distort demand, so free trade in manufactures alone is not
best. Targets are written `table measure [element] = value`, for example
`targets(government tax_import = 8)` to keep tariff revenue, and with no
objective there must be one target per instrument:

```stata
cge_closure, government(flexgsav)
cge_shock tm, value(0)
cge_optimize, instruments(TINSADJ) targets(government savings = 3)
```

finds the direct tax rate that keeps government savings at the base, which
is what the closure `fixgsav` does. The optimum is stored as a simulation
(`name()`, default `optimum`) and left as the current shock. The optimum may
be local; try other starting values.

## 4.5 User variables and equations: `cge_variable`, `cge_equation`

New relations among the model's variables can be added after calibration
(from version 0.6.1; model_spec.md, Section 19). A defined variable, swapped
into the closure, fixes an expression and frees another variable:

```stata
cge_variable GEXP = sum(c, PQ(c) * QG(c)), nominal   // government purchases, at market prices
cge_closure, swap(GEXP GADJ)                          // fixed in value; volumes adjust
cge_shock pwm, scale(1.1)
cge_solve, name(fixed_budget)
```

A variable given a value is determined by equations of its own:

```stata
cge_variable LAM, value(1)
cge_equation lam: QG(com_ser) = LAM * base(QG(com_ser))
```

Expressions may use model variables at an element (`PQ(com_hlt)`), the index
of the equation (`cge_variable PREL(c) = PQ(c) / CPI`), sums over a set
(`sum(c, ...)`), parameters that `cge_shock` changes (`tv(c)`), `base()` and
`exp()`, `ln()` and `sqrt()`. `cge_equation, list` lists them, and
`cge_equation, clear` removes them. They are solved in every simulation, kept
when the model is calibrated again, and written into the GAMS export.

## 4.6 Reading a simulation

A simulation is a counterfactual equilibrium compared with the base: the
model has no time in a static run, so a result is the change once the economy
has adjusted under the closure's assumptions. Report the closure with every
result. Compare simulations that differ in one respect: the same shock under
two closures, or two shocks under one closure.
