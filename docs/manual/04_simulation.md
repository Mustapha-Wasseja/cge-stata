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
Powell's hybrid method is tried, then Newton again to polish the result. The
command stops with error 430 if the model does not converge.

The solution is accepted when the largest scaled residual, over every
equation, is below the tolerance (1e-10 by default). The residual and the
Walras slack (zero at a solution) are displayed with each solve.

## 4.4 Reading a simulation

A simulation is a counterfactual equilibrium compared with the base: the
model has no time in a static run, so a result is the change once the economy
has adjusted under the closure's assumptions. Report the closure with every
result. Compare simulations that differ in one respect: the same shock under
two closures, or two shocks under one closure.
