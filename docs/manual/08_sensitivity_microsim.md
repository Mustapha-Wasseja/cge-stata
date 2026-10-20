# 8. Sensitivity analysis and household surveys

## 8.1 Sensitivity to the elasticities: `cge_sensitivity`

Elasticities are rarely estimated for the country and period of a SAM.
`cge_sensitivity` shows how much a scenario's results depend on them: for each
draw it multiplies the elasticities by random factors around one, recalibrates
the model, restores the closure, runs the scenario and solves.

```stata
program define tariff_cut
    cge_shock tm, value(0)
end
cge_sensitivity, scenario(tariff_cut) draws(200) spread(0.5) seed(2026)
cge_sensitivity, scenario(tariff_cut) draws(200) vary(q t) common tables(macro welfare) clear
```

- `spread(0.5)` draws factors between 0.5 and 1.5 (uniform, or `triangular`
  with `distribution()`);
- `vary()` chooses the elasticities: `va` (value added), `q` (Armington), `t`
  (CET), `a` (the top nest);
- `common` draws one factor per type of elasticity for all sectors; by
  default each sector's is drawn separately;
- the summary gives, for every report measure, the central result, the mean,
  the standard deviation and the 5th and 95th percentiles across the draws;
  `clear` loads every draw.

The draws do not estimate uncertainty about the elasticities. They show how
results change over a chosen range, so report the range, the distribution and
whether sectors move together with the results. The library's standard errors
(chapter 3) can guide the range. The model in memory is restored at the end.

## 8.2 The household survey link: `cge_microsim`

The model has a few household groups; poverty and inequality are measured on
household surveys. `cge_microsim` passes a simulation's results to the survey
data in memory, top-down and without feedback
([model_spec.md](../model_spec.md), Section 11; Bourguignon, Bussolo and
Pereira da Silva 2008):

```stata
use survey, clear
cge_microsim [pweight = hhweight], sim(notariff) group(cge_group) consumption(cons) ///
    size(hhsize) income(wage:lab profit:cap remit:row grants:gov)                  ///
    budget(food:com_agr goods:com_man services:com_ser) line(1200) generate(nt)
```

- `group()` gives each household's model group.
- `income()` lists its income components and their sources: a factor, `gov`
  (real transfers), `row` (transfers from abroad), `dom` (transfers from other
  domestic institutions), `cpi` (indexed to prices) or `fixed`. Each component
  changes as its source does for the household's group, and consumption also
  follows the group's direct tax and savings rates. Without `income()`, each
  household's consumption changes as its group's does.
- `budget()` lists spending on items and the commodities whose prices apply,
  so each household has its own price index; otherwise the group's budget
  shares are used.
- `line()` is the poverty line per person; poverty (FGT 0, 1 and 2) and the
  Gini coefficient are measured over persons, before and after, overall and by
  group. `generate()` keeps the household's new nominal and real consumption
  and price index.

Survey households keep their own income composition and budget shares, so
their average change can differ from their group's: a household that lives on
wages gains more than its group when wages rise relative to other income. Map
every substantial income source, and use the same base year for the survey
and the SAM where possible.

## References

Bourguignon, F., M. Bussolo and L. A. Pereira da Silva, eds. (2008). *The
Impact of Macroeconomic Policies on Poverty and Income Distribution:
Macro-Micro Evaluation Techniques and Tools*. World Bank and Palgrave
Macmillan.
