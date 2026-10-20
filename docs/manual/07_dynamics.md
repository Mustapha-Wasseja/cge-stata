# 7. Recursive dynamics

`cge_dynamic` solves the model for a sequence of periods
([model_spec.md](../model_spec.md), Section 10). Agents do not look ahead:
each period is an equilibrium given that period's stocks, which are updated
from the previous period's solution (Thurlow 2004).

## 7.1 A baseline

```stata
cge_closure, factors(cap:specific)
cge_dynamic, name(base) periods(2018/2030) capital(cap) depreciation(0.05) rental(0.15) ///
    growth(lab:0.03) population(0.025) govgrowth(0.03) foreigngrowth(0.02) gdpgrowth(0.04)
```

Before each period:

1. **Capital** (`capital()`) depreciates at `depreciation()` and grows with
   the previous period's real investment; `rental()` is the base gross rental
   rate, so one unit of real investment adds `rental` units of capital. With
   capital specific to each activity, new capital goes to activities in
   proportion to their capital, tilted towards those whose rental rate is above
   average (`sensitivity()`).
2. **Other factors** grow at the rates in `growth()`.
3. **Population** (`population()`) scales subsistence consumption and the base
   of the health link.
4. **Government and foreign flows** grow at `govgrowth()` and
   `foreigngrowth()`.
5. **Public debt**, if any, adds the previous deficit.
6. **Shocks** for the period are applied (`shocks()`).
7. **Efficiency** grows at `tfp()`, or, with `gdpgrowth()`, by the uniform
   factor that makes real value added grow at the target rate.

Each period is stored as a simulation named with the run and the period
(`base2018`, ..., `base2030`), so `cge_report, run(base)` reports the run.

## 7.2 Scenarios against a baseline

A scenario reuses the baseline's efficiency path, so that efficiency does not
respond to the policy:

```stata
program define tariff_cut
    args t
    if `t' == 2020 cge_shock tm, value(0)
end
cge_dynamic, name(lib) periods(2018/2030) capital(cap) depreciation(0.05) rental(0.15) ///
    growth(lab:0.03) population(0.025) govgrowth(0.03) foreigngrowth(0.02)            ///
    baseline(base) shocks(tariff_cut)
cge_dynresults, run(lib) baseline(base) clear
```

The `shocks()` program is called with the period before each period after
the first; a shock stays in force in later periods unless the program
changes it. `cge_dynresults` loads every variable of every period with its
baseline value and the difference in per cent.

## 7.3 Population, deaths and labour

With a death rate (`cge_calibrate, mortality()`), population growth becomes
the rate in `population()` plus the base death rate less the previous
period's, so health services that lower the death rate raise population
growth. With `deathfactors(lab) deathshare(0.3) workingage(0.55)`, labour also
loses the deaths at working ages: 30 per cent of deaths, in a population of
which 55 per cent is of working age. In a baseline, rising health services per
head lower the death rate, so compare scenarios with a baseline run with the
same settings.

## 7.4 Labour force and unemployment

A factor with a labour force (chapter 6) has its labour force grow at its
growth rate; under the wage curve, a minimum wage or unemployment at a fixed
wage, employment follows labour demand and the unemployment rate changes.

## References

Thurlow, J. (2004). *A Dynamic Computable General Equilibrium (CGE) Model for
South Africa: Extending the Static IFPRI Model*. Trade and Industrial Policy
Strategies, Working Paper 1-2004.
