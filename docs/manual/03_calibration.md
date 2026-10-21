# 3. Mapping and calibration

## 3.1 Model roles: `cge_map`

`cge_map` assigns each SAM account to a role of the model and checks that
every non-zero cell is a flow the model represents
([model_spec.md](../model_spec.md), Section 7.0). Roles are given as options or
from a template (chapter 2):

```stata
cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)       ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
cge_map using "roles.xlsx"
```

`activities()` and `commodities()` are paired by position: each activity's
main commodity comes first, in the same order. An activity may produce other
commodities in fixed proportions taken from the SAM; commodities that are only
imported are listed after the paired ones. Households may include non-profit
institutions; `enterprises()` lists corporations, which receive factor income
and transfers, pay direct taxes and save but do not consume.

**Factor taxes** (from version 0.5.0). A SAM may record payroll taxes or taxes
on capital paid by activities, and taxes on factor income paid by the factor
accounts. Map each tax-on-use account with the factor it taxes, and the
account of taxes on factor income:

```stata
cge_map, ... factortax(tax_pay:lab) factorincometax(tax_fy)
```

The rates are calibrated from the SAM: each tax over the factor payment, or
over the factor's income (chapter 6.6).

**The mapping report.** `cge_map` collects every problem before stopping:
unbalanced accounts, accounts with flows but no role, cells the model cannot
represent, and negative cells where values must be non-negative. Problems are
grouped by type and by the roles of the paying and receiving accounts,
largest first, with each group's share of the SAM. Fix the SAM, or map the
accounts differently, until the report is clear; `report(filename)` saves
every problem cell to a CSV file. `cge_map` options must be typed in full.

## 3.2 National-accounts layouts

National SAMs often record flows in ways that differ from the model's layout.
`cge_map` rewrites the common ones and displays the amounts moved; the SAM in
memory is not changed.

| SAM records | Option | Rewrite |
|---|---|---|
| exports as sales by activities to the rest of the world | (automatic) | moved to the paired commodity |
| taxes paid directly to the government account | name the government in the tax option, e.g. `saltax(gov)` | routed through an internal tax account |
| margins netted out of trade and transport activities (negative own use) | `margins()` | moved to the activities' output |
| margin accounts paid by commodities (supply-use layout) | `marginaccounts()` | margins per unit of composite supply |
| margins by market: domestic sales, imports, exports | `domesticmargins()`, `importmargins()`, `exportmargins()` | margins per unit of each market |
| stock-change accounts | `stocks()` | merged into savings-investment |
| a territorial correction (residents abroad, non-residents here) | `territorial()` | household transfers to and from abroad |
| a VAT account, or VAT within the sales tax | `vattax()`, `vatshare()` | VAT on final demand with input credits |
| a social health insurance fund | `insurance()` | contributions, transfers and purchases of the fund |
| household payments to activities | (automatic) | home consumption of own produce |

`cge_samexport, mapped` writes the SAM after these rewrites.

## 3.3 Elasticities

The model's free parameters are elasticities: of substitution between factors
(`sigmava`), between imports and domestic goods (`sigmaq`, Armington), of
transformation between exports and domestic sales (`sigmat`, CET), and,
optionally, between value added and intermediate inputs (`sigmaa`), income
elasticities and a Frisch parameter for LES demand, and the elasticities of
the extensions (chapter 6). None has a default.

The library of published estimates ([elasticities.md](../elasticities.md))
gives values with their sources:

```stata
cge_elasticities, country(TGO)                         // what the library holds
cge_elasticities sigmaq, country(TGO) values           // one value per commodity
local sq `r(values)'
cge_elasticities incelas, country(TGO) values map(com_agr:food com_hlt:health) others(other)
local ie `r(values)'
```

Read the definitions first. The library's trade elasticities are aggregate
estimates from national series, lower than sector values; its income
elasticities come from a cross-country demand system for 2005. A user can add
entries from a file (`cge_elasticities ... using`). Chapter 8 shows how to
measure how much results depend on the values chosen.

## 3.4 Calibration: `cge_calibrate`

`cge_calibrate` computes every parameter and the base value of every variable
from the mapped SAM and the elasticities ([model_spec.md](../model_spec.md),
Section 7), sets the default closure, and checks that the base solves every
equation:

```stata
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_calibrate, sigmava(0.5 1 1.5) sigmaq(0.6 3 1.2) sigmat(0.7 4 1)    // by sector
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) incelas(0.6 1 1.4) frisch(-2)
```

Each elasticity option takes one value for every sector or one value per
activity (`sigmava`, `sigmaa`) or commodity (`sigmaq`, `sigmat`, `incelas`),
in the order of `cge_map`. A value of 1 for `sigmava` gives Cobb-Douglas value
added. Prices are one in the base, so quantities equal SAM values, unless
`fquantities()` supplies factor quantities, such as employment.

**Benchmark replication.** The calibrated base must solve every equation. The
largest scaled residual is displayed and stored in `r(max_residual)`; above
1e-9 the command stops with an error. A failure points to a problem in the SAM
or the mapping, not to a solver issue.

**Household demand.** By default households have Cobb-Douglas demand: fixed
budget shares and income elasticities of one. `incelas()` and `frisch()` give
linear expenditure system demand: marginal budget shares proportional to the
income elasticities, and subsistence quantities from the Frisch parameter
(below -1).

**Options of the extensions** are described in chapter 6:

| Group | Options |
|---|---|
| Top nest | `sigmaa()` |
| Health link | `healthcom()`, `healthfac()`, `healthelas()` |
| VAT and public debt | `vatcredit()`, `debt()`, `interest()`, `debtholders()`, `foreignborrowing()` |
| Trade | `exportonly()`, `exportdemand()` |
| Labour markets | `unemployment()`, `wagecurve()`, `minwage()`, `smoothing()` |
| Health outcomes | `sickdays()`, `sickelas()`, `mortality()`, `mortelas()` |

## 3.5 Inspecting the calibration

`cge_parameters, clear` loads every calibrated parameter as a dataset
(parameter, set elements, value); names follow
[model_spec.md](../model_spec.md), Section 4. `cge_check` runs the validation
checks:

```stata
cge_check, homogeneity perturb(0.1)
```

| Check | What it tests |
|---|---|
| SAM balance | every account's row and column totals agree |
| benchmark replication | the base solves every equation |
| closure is square | as many free variables as equations |
| homogeneity | doubling every fixed nominal value doubles all prices and nominal values and leaves quantities unchanged |
| perturbed start | the solver returns to the base from perturbed starting values |

After a simulation, `cge_check` also tests its residual, Walras's law and the
GDP identity. It exits with an error if any check fails.
