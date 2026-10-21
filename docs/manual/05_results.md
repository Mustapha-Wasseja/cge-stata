# 5. Results

## 5.1 A summary of one simulation: `cge_results`

```stata
cge_results, sim(notariff)
cge_results, sim(notariff) clear nodisplay
```

`cge_results` displays real value added, the exchange rate, the CPI,
investment, trade, government savings, factor prices and activity output as
percentage changes from the base, the equivalent variation of each household,
and the Walras and GDP identity checks. With `clear` or `saving()` it writes
every variable of the solution as a dataset (`variable`, `element1`,
`element2`, `base`, `value`), with the names of
[model_spec.md](../model_spec.md), Section 3.

Percentage changes are relative to the absolute value of the base, so a fall
is negative even when the base is negative, as for a government deficit.

## 5.2 Report tables: `cge_report`

`cge_report` computes standard measures for several simulations side by side
([model_spec.md](../model_spec.md), Section 9):

```stata
cge_report, sims(notariff notariff_direct) tables(macro government welfare)
cge_report, sims(_all) tables(all) saving("results.xlsx", replace) nodisplay
cge_report, run(base) tables(macro)
```

| Table | Measures |
|---|---|
| `macro` | nominal and real GDP, deflator, real consumption, government consumption, investment, insurance-fund purchases, exports, imports, value added, price indexes, exchange rates, savings |
| `government` | revenue, spending, savings, and revenue by tax |
| `debt` | interest and public debt at the end of the period, when the model has debt |
| `institutions` | income and consumption |
| `factors` | wages, real wages, income, supply; labour force and unemployment rate where defined |
| `activities` | output, price, value added |
| `commodities` | supply, price, output, domestic sales, exports, imports |
| `health` | health services, factor efficiency, health outcomes, the insurance fund |
| `welfare` | equivalent and compensating variation of each household, in per cent of base consumption |

Real measures are valued at base prices and trade at base world prices.
Changes are percentages, except rates (unemployment, debt in per cent of GDP,
the share of time lost to illness, the death rate), which change in points.
`saving()` writes an Excel file with one sheet per table; `clear` loads the
measures as data, one observation per simulation and measure.

**Welfare.** The equivalent variation is the change in spending at base
prices that gives the new utility; the compensating variation is the change
in spending at new prices that would restore base utility. Both use the
household's Cobb-Douglas or LES expenditure function and are positive for a
gain. Neither values public goods, the environment or leisure; state what
they leave out.

## 5.3 Parameters: `cge_parameters`

`cge_parameters, clear` loads the calibrated parameters (`sim()` gives those of
a simulation, with its shocks; `current` those in memory). It is the place to
check the implied tax rates, shares and elasticities before simulating.

## 5.4 Saving a model: `cge_save`, `cge_use`

```stata
cge_save using "model.cgem", replace
cge_use using "model.cgem"
```

A saved model holds the SAM, the mapping, the calibration, the closure and
every simulation, so results can be reported later without recomputing them.
Models saved by earlier versions are upgraded when loaded. Model files are
written in Mata's file format, which changed after Stata 13: later versions
of Stata read files saved in Stata 13, but Stata 13 cannot read files saved
in later versions (tested with StataNow 19.5), so a model to be shared with
users of Stata 13 is best saved in Stata 13.
