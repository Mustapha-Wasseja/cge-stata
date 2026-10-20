# 6. Model extensions

Each extension is switched on by the SAM's layout or by options of
`cge_map` and `cge_calibrate`, and leaves the standard model unchanged when it
is not used. The equations are in [model_spec.md](../model_spec.md), Sections
12 to 15; `examples/` has a do-file for each group.

## 6.1 Fiscal instruments (Section 12)

**Revenue-neutral tax replacement.** Under `cge_closure, government(fixgsav
direct)` (or `sales`, `import`, `vat`), government savings are fixed and that
tax's rates are scaled by a common factor (`TINSADJ`, `TQADJ`, `TMADJ`,
`TVADJ`) to keep them. A tariff removal can then be compared with and without
a replacement tax.

**VAT with input credits.** Map the VAT account with `cge_map, vattax()`, or
the VAT share of the sales tax with `vatshare()`. VAT is levied on final
demand at a rate by commodity; activities recover the VAT on their inputs in
the shares given by `cge_calibrate, vatcredit()` (one by default), so an
exempt activity (`vatcredit(act_hlt:0)`) bears VAT on its inputs. Shocks:
`tv`, `kappa`. `vatshare(0)` creates an empty VAT account, so that a VAT can
be introduced.

**Public debt.** `cge_calibrate, debt(domestic:# foreign:#) interest(domestic:#
foreign:#)` separates interest on the stated debt from the SAM's government
transfers (to the holders in `debtholders()`, by default in proportion to the
transfers). In dynamic runs the deficit is borrowed, the share
`foreignborrowing()` abroad, and the report has a debt table. Shocks: `rd`,
`rf`, `ddebt`, `fdebt` (for example debt relief).

## 6.2 Trade and households (Section 13)

**Home consumption.** A household's payment to an activity in the SAM is
consumption of its own produce, valued at the activity's price, without
taxes or margins.

**Export demand.** `cge_calibrate, exportdemand(com_man:4)` gives a finite
elasticity of world demand: the world export price falls as more is exported,
and a shock to `pwe` shifts world demand.

**Export-only commodities.** `exportonly(com_cash)` exports all of a
commodity's domestic output directly, without domestic sales, for products
such as cash crops that the SAM records as wholly exported.

**Margins by market.** `cge_map, domesticmargins() importmargins()
exportmargins()` for SAMs that separate the margins on domestic sales,
imports and exports.

## 6.3 Labour markets (Section 14)

`cge_calibrate, unemployment(lab:0.15)` gives a factor a labour force from the
base unemployment rate, taken from a labour force survey. Two closures then
use it:

- **Wage curve** (`cge_closure, factors(lab:wagecurve)`, with
  `wagecurve(lab:0.1)` at calibration): the real wage falls as unemployment
  rises, with the given elasticity (about 0.1 in many countries; Blanchflower
  and Oswald 1995).
- **Minimum wage** (`factors(lab:minwage)`): the real wage cannot fall below a
  floor, by default the base wage when there is unemployment in the base, or
  a share of it with full employment (`minwage(lab:0.95)`). Either the floor
  binds and unemployment absorbs the shock, or the wage is above the floor and
  labour is fully employed; the solver finds which, through a smoothed
  complementarity condition (`smoothing()`).

Reports show the labour force and the unemployment rate; shocks `qlf`, `wmin`
and `wref` change the labour force, the floor and the wage curve's reference.

## 6.4 Health (Sections 5.2, 7.0 and 15)

**A social health insurance fund.** `cge_map, insurance(shi)` maps a fund
financed by contributions on factor income and by transfers from the
government and the rest of the world, which buys health services with its
revenue less a fixed share saved. Shocks: `tshi`, `qshi`, `trshi`, `trshir`.

**Factor efficiency.** `cge_calibrate, healthcom(com_hlt) healthfac(lab)
healthelas(0.3)` makes labour's efficiency rise with health services per head,
with the given elasticity; `af` shocks efficiency directly.

**Health outcomes.** `sickdays(lab:0.05) sickelas(-0.4)` give the base share of
working time lost to illness and its elasticity with respect to health
services per head; days worked then scale effective labour per worker. The
shock `sick` raises the share lost, for example in an epidemic.
`mortality(0.01) mortelas(-0.3)` give a crude death rate, which is reported
and, in dynamic runs, changes population and labour growth from the next
period (chapter 7). The elasticities are hypotheses to take from studies of
the country; the package supplies none for days lost or the death rate.

## References

Blanchflower, D. G. and A. J. Oswald (1995). An introduction to the wage curve.
*Journal of Economic Perspectives* 9(3): 153-167.
