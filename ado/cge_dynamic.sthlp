{smcl}
{* *! version 0.10.2  26oct2026}{...}
{title:Title}

{p2colset 5 20 22 2}{...}
{p2col:{bf:cge_dynamic} {hline 2}}Solve a dynamic run, recursive or with perfect foresight{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_dynamic}{cmd:,} {opt name(name)} {opt per:iods(numlist)}
[{opt cap:ital(factors)} {opt dep:reciation(numlist)} {opt rent:al(numlist)} {opt sens:itivity(#)}
{opt grow:th(factor:rate ...)} {opt tfp(numlist)} {opt gdp:growth(numlist)} {opt base:line(name)}
{opt pop:ulation(#)} {opt gov:growth(#)} {opt for:eigngrowth(#)} {opt shock:s(program)}
{opt deathf:actors(factors)} {opt deaths:hare(#)} {opt work:ingage(#)}
{opt fores:ight} {opt term:inal(constant|growth|base)} {opt start(recursive|base)}
{opt tol:erance(#)} {opt iter:ate(#)}]


{title:Description}

{pstd}
{cmd:cge_dynamic} solves the calibrated model for a sequence of periods. The
first period in {opt periods()} is the calibrated base; each later period is
an equilibrium given stocks and exogenous values updated from the period
before (Reference Manual, {it:Dynamics}). Agents do not look ahead, unless
the run has perfect foresight (from version 0.10.2; see below). Each period
is stored as the simulation {it:name}{it:period}, for example {cmd:base2025},
so {helpb cge_report}, {helpb cge_results} and {helpb cge_save} work with it.
The run uses the current closure and starts from the base; the parameters and
fixed values of the model are restored when it ends. A run solved again
replaces every period of the earlier run of that name. If a period cannot be
solved, or the {opt shocks()} program fails, the run stops and nothing is
stored: the model, its shocks and its stored simulations are as they were
before the run (from version 0.6.4).

{pstd}
Before each period after the first, in this order:

{phang2}1. Capital factors lose {opt depreciation()} and gain new capital from
the previous period's real investment. With a base gross rental rate
{opt rental()}, one unit of real investment adds {it:rental} units of the
factor (the base capital stock is base capital income divided by the rental
rate). New capital is shared among capital factors by base income. For capital
specific to each activity, it is allocated by relative rental rates, with
sensitivity {opt sensitivity()}.{p_end}

{phang2}2. Other factors grow at the rates in {opt growth()}.{p_end}

{phang2}3. Subsistence consumption (LES) and the base of the health link grow
with {opt population()}. With a death rate ({helpb cge_calibrate},
{opt mortality()}; from version 0.3.4), population growth is
{opt population()} plus the base death rate less the previous period's death
rate, and the factors in {opt deathfactors()} lose workers to deaths at
working ages.{p_end}

{phang2}4. Government consumption and real transfers grow at
{opt govgrowth()}; flows in foreign currency, and fixed foreign savings, at
{opt foreigngrowth()}.{p_end}

{phang2}5. With public debt ({helpb cge_calibrate}, {opt debt()}), the previous
period's deficit is borrowed, the share {opt foreignborrowing()} abroad, and
interest is paid on the new stocks; a surplus repays debt in the same shares
(from version 0.3.1).{p_end}

{phang2}6. The program in {opt shocks()} is called with the period as its
argument; it may use {helpb cge_shock}, for example to cancel debt with
{cmd:cge_shock fdebt}. Shocks persist in later periods, so a shock with
{opt scale()} should be applied only once.{p_end}

{phang2}7. Value-added efficiency grows at {opt tfp()}; or follows the path
of the run named in {opt baseline()}; or, with {opt gdpgrowth()}, grows
uniformly at the rate for which real value added at base prices grows at the
target.{p_end}

{pstd}
Rates are per period. Each step between listed periods is one period. No rate
has a default other than zero, and none is estimated by the package.

{pstd}
From version 0.9.2, user equations ({helpb cge_equation}) may refer to the
values of variables in the periods before, {cmd:lag(}{it:VAR}{cmd:)} or
{cmd:lag(}{it:VAR}{cmd:(}{it:e}{cmd:),} {it:k}{cmd:)} for up to four periods;
before the first period they are the base values. Stocks and partial
adjustment that the model does not update itself can so be written in the
model's own terms.

{pstd}
{bf:Perfect foresight} (from version 0.10.2). With {opt foresight}, the periods
are solved together, and user equations may also refer to later periods,
{cmd:lead(}{it:VAR}{cmd:)} or {cmd:lead(}{it:VAR}{cmd:(}{it:e}{cmd:),}
{it:k}{cmd:)} for up to four periods: agents act on the path that the run
finds, so a shock known in advance moves the periods before it, for example
investment that follows the expected return to capital. The updates of steps
2 to 4 and 7 and the shocks of step 6 are made period by period first; what a
recursive run carries from one solution to the next -- capital stocks, public
debt, the efficiency factor of growth targets and, with a death rate,
population and the factors that lose workers -- become unknowns of the stacked
system, whose equations are the updates of steps 1, 3 and 5. Newton's method
solves it with the sparse LU. Without leads it gives the recursive run. A
shock to a capital or debt stock is found by running the {opt shocks()}
program twice for the period, the second time quietly, and holds as
{it:after = a + b before}; with {opt gdpgrowth()} efficiency may not be
shocked, nor, with a death rate, population or the factors in
{opt deathfactors()}; the closure stays the same. Beyond the last period a
lead follows {opt terminal()}. {cmd:tperiod}, {cmd:tfirst} and {cmd:tlast} in
a user equation are the period and 1 in the first or last period (0
otherwise), so that {cmd:ifthen(tlast,} ...{cmd:)} writes an equation of its
own for the last period.


{title:Options}

{phang}
{opt name(name)} names the run; with the period, it names the simulations.

{phang}
{opt periods(numlist)} lists the periods, the base first, for example
{cmd:periods(2018/2030)}.

{phang}
{opt capital(factors)} lists the factors that accumulate. They need
{opt depreciation()} and {opt rental()}, one value or one per capital factor,
and may be mobile or specific to each activity, not unemployed or under a
labour-market regime.

{phang}
{opt sensitivity(#)} sets how strongly new capital moves to activities with
above-average rental rates; 0 allocates it in proportion to capital stocks.
The default is 1.

{phang}
{opt growth(factor:rate ...)} sets the growth of other factors, for example
{cmd:growth(lab_f:0.03 lab_i:0.025)}. An unemployed factor's supply is
endogenous and cannot grow, unless it has a labour force (from version
0.3.3; {helpb cge_calibrate}, {opt unemployment()}): the labour force of a
factor with one grows at the factor's rate, whatever its closure, so that
under {cmd:unemployed}, {cmd:wagecurve} or {cmd:minwage} employment and
unemployment follow from labour demand.

{phang}
{opt tfp(numlist)}, {opt gdpgrowth(numlist)} and {opt baseline(name)} set
efficiency growth; choose one. {opt tfp()} takes one rate or one per activity.
{opt gdpgrowth()} takes one target or one per period after the first, and
reports the efficiency factor of each period. {opt baseline()} names a run
solved with {opt gdpgrowth()} (or itself with {opt baseline()}) and reuses its
efficiency factors, so that a policy scenario does not change efficiency. The
baseline must have every period of this run, and may have more.

{phang}
{opt population(#)}, {opt govgrowth(#)} and {opt foreigngrowth(#)} set the
growth of population, government flows and foreign flows. The population
growth rate is taken to hold at the base death rate.

{phang}
{opt deathfactors(factors)}, {opt deathshare(#)} and {opt workingage(#)}
(from version 0.3.4; Reference Manual, {it:Health}) make labour respond to
deaths. {opt deathfactors()} lists the labour factors, which may not be
capital; {opt deathshare()} is the share of deaths at working ages and
{opt workingage()} the working-age share of the population (default 1). Each
listed factor then grows at its {opt growth()} rate plus
{it:deathshare/workingage} times the base death rate less the previous
period's death rate; a factor's labour force grows at the same rate. They
need a death rate. In a baseline, rising health services per head lower the
death rate and raise population growth above {opt population()}, so compare
scenarios with a baseline run with the same settings.

{phang}
{opt shocks(program)} names a program called as {it:program period} before
each period after the first.

{phang}
{opt foresight} (from version 0.10.2) solves the periods together, with
perfect foresight; it is needed for {cmd:lead()}.

{phang}
{opt terminal(constant|growth|base)} sets the value of a lead beyond the last
period: that of the last period ({cmd:constant}, the default), the growth of the
last period continued ({cmd:growth}), or the base ({cmd:base}).

{phang}
{opt start(recursive|base)} sets the start of Newton's method: a recursive run
in which each period expects the later ones to repeat the period before
({cmd:recursive}, the default), or the base in every period ({cmd:base}).

{phang}
{opt tolerance(#)} and {opt iterate(#)} are passed to the solver of each
period, or of the stacked system with {opt foresight}; the default tolerance
is 1e-12.


{title:Examples}

{pstd}{bf:Example 1: recursive dynamics and withdrawal of donor funding}{p_end}

{pstd}
This example uses a SYNTHETIC SAM with a health sector and a social health
insurance fund partly financed by donors abroad. The data and growth rates
are illustrative and describe no country.{p_end}

{pstd}{bf:1. Set up and calibrate the model}{p_end}

{phang2}{cmd:cge_synthetic, clear health}{p_end}

{phang2}{cmd:cge_sam, labels(account)}{p_end}

{phang2}{cmd:cge_map, activities(act_agr act_man act_ser act_hlt) commodities(com_agr com_man com_ser com_hlt) factors(lab cap) households(hhd)}
{cmd:government(gov) savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) insurance(shi)}{p_end}

{phang2}{cmd:cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) healthcom(com_hlt) healthfac(lab) healthelas(0.3)}{p_end}

{phang2}{cmd:cge_closure, factors(cap:specific)}{p_end}

{pstd}{bf:2. Solve the baseline}{p_end}

{pstd}
Calibrate the baseline efficiency path to 5 per cent annual GDP growth.
The baseline retains the donors' contributions.{p_end}

{phang2}{cmd:cge_dynamic, name(base) periods(2018/2030) capital(cap) depreciation(0.05) rental(0.15) growth(lab:0.03) population(0.025) gdpgrowth(0.05)}{p_end}

{pstd}{bf:3. Define and solve the donor-withdrawal scenario}{p_end}

{pstd}
The following program sets foreign transfers to the insurance fund
({cmd:trshir}) to zero from 2022. The scenario uses the baseline's efficiency
path, so GDP can respond to the withdrawal.{p_end}

{phang2}{cmd:program define donor_exit}{p_end}

{p 12 16 2}{cmd:args t}{p_end}

{p 12 16 2}{cmd:if `t' >= 2022 cge_shock trshir, value(0)}{p_end}

{phang2}{cmd:end}{p_end}

{phang2}{cmd:cge_dynamic, name(exit) periods(2018/2030) capital(cap) depreciation(0.05) rental(0.15) growth(lab:0.03) population(0.025) baseline(base) shocks(donor_exit)}{p_end}

{pstd}{bf:4. Compare and report the results}{p_end}

{pstd}
Load the scenario's results relative to the baseline into Stata's data in
memory, then display the scenario's macroeconomic and health tables.{p_end}

{phang2}{cmd:cge_dynresults, run(exit) baseline(base) clear}{p_end}

{phang2}{cmd:cge_report, run(exit) tables(macro health)}{p_end}


{pstd}{bf:Example 2: perfect foresight}{p_end}

{pstd}Investment-driven savings, with investment that
follows Tobin's q, the expected value of a unit of capital, and a tariff cut
in 2022 known from 2018. This example uses a separate synthetic model.{p_end}

{phang2}{cmd:cge_synthetic, clear}{p_end}

{phang2}{cmd:cge_sam, labels(account)}{p_end}

{phang2}{cmd:cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) factors(lab cap) households(hhd) government(gov)}
{cmd:savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)}{p_end}

{phang2}{cmd:cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)}{p_end}

{phang2}{cmd:cge_closure, savinv(investment)}{p_end}

{phang2}{cmd:cge_variable RK = W(cap) / CPI}{p_end}

{phang2}{cmd:cge_variable Q, value(10)}{p_end}

{phang2}{cmd:cge_equation qeq: Q = (lead(RK) + 0.95 * lead(Q)) / 1.05}{p_end}

{phang2}{cmd:cge_variable IRULE = IADJ / (Q / base(Q))^2}{p_end}

{phang2}{cmd:cge_closure, swap(IRULE IADJ)}{p_end}

{phang2}{cmd:program define tariff_cut}{p_end}

{p 12 16 2}{cmd:args t}{p_end}

{p 12 16 2}{cmd:if `t' == 2022 cge_shock tm, value(0)}{p_end}

{phang2}{cmd:end}{p_end}

{phang2}{cmd:cge_dynamic, name(tq) periods(2018/2030) capital(cap) depreciation(0.05) rental(0.10) growth(lab:0.02) shocks(tariff_cut) foresight}{p_end}


{title:Stored results}

{synoptset 16 tabbed}{...}
{p2col 5 16 20 2: Macros}{p_end}
{synopt:{cmd:r(name)}}name of the run{p_end}
{synopt:{cmd:r(sims)}}simulations of the run, in period order{p_end}
{synopt:{cmd:r(foresight)}}{cmd:foresight} for a run with perfect foresight{p_end}


{title:References}

{phang}
Lau, M. I., A. Pahlke, and T. F. Rutherford (2002). Approximating
infinite-horizon models in a complementarity format: a primer in dynamic
general equilibrium analysis. Journal of Economic Dynamics and Control 26:
577-609.

{phang}
Thurlow, J. (2004). A dynamic computable general equilibrium (CGE) model for
South Africa: extending the static IFPRI model. Trade and Industrial Policy
Strategies, Working Paper 1-2004.


{title:Also see}

{psee}
{helpb cge}, {helpb cge_dynresults}, {helpb cge_report}, {helpb cge_shock}
{p_end}
