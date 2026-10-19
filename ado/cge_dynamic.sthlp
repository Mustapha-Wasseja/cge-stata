{smcl}
{* *! version 0.3.1  20oct2026}{...}
{title:Title}

{p2colset 5 20 22 2}{...}
{p2col:{bf:cge_dynamic} {hline 2}}Solve a recursive dynamic run{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_dynamic}{cmd:,} {opt name(name)} {opt per:iods(numlist)}
[{opt cap:ital(factors)} {opt dep:reciation(numlist)} {opt rent:al(numlist)} {opt sens:itivity(#)}
{opt grow:th(factor:rate ...)} {opt tfp(numlist)} {opt gdp:growth(numlist)} {opt base:line(name)}
{opt pop:ulation(#)} {opt gov:growth(#)} {opt for:eigngrowth(#)} {opt shock:s(program)}
{opt tol:erance(#)} {opt iter:ate(#)}]


{title:Description}

{pstd}
{cmd:cge_dynamic} solves the calibrated model for a sequence of periods. The
first period in {opt periods()} is the calibrated base; each later period is
an equilibrium given stocks and exogenous values updated from the period
before (docs/model_spec.md, Section 10). Agents do not look ahead. Each period
is stored as the simulation {it:name}{it:period}, for example {cmd:base2025},
so {helpb cge_report}, {helpb cge_results} and {helpb cge_save} work with it.
The run uses the current closure and starts from the base; the parameters and
fixed values of the model are restored when it ends.

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
with {opt population()}.{p_end}
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


{title:Options}

{phang}
{opt name(name)} names the run; with the period, it names the simulations.

{phang}
{opt periods(numlist)} lists the periods, the base first, for example
{cmd:periods(2018/2030)}.

{phang}
{opt capital(factors)} lists the factors that accumulate. They need
{opt depreciation()} and {opt rental()}, one value or one per capital factor,
and may be mobile or specific to each activity, not unemployed.

{phang}
{opt sensitivity(#)} sets how strongly new capital moves to activities with
above-average rental rates; 0 allocates it in proportion to capital stocks.
The default is 1.

{phang}
{opt growth(factor:rate ...)} sets the growth of other factors, for example
{cmd:growth(lab_f:0.03 lab_i:0.025)}. An unemployed factor's supply is
endogenous and cannot grow.

{phang}
{opt tfp(numlist)}, {opt gdpgrowth(numlist)} and {opt baseline(name)} set
efficiency growth; choose one. {opt tfp()} takes one rate or one per activity.
{opt gdpgrowth()} takes one target or one per period after the first, and
reports the efficiency factor of each period. {opt baseline()} names a run
solved with {opt gdpgrowth()} and reuses its efficiency factors, so that a
policy scenario does not change efficiency.

{phang}
{opt population(#)}, {opt govgrowth(#)} and {opt foreigngrowth(#)} set the
growth of population, government flows and foreign flows.

{phang}
{opt shocks(program)} names a program called as {it:program period} before
each period after the first.

{phang}
{opt tolerance(#)} and {opt iterate(#)} are passed to the solver of each
period; the default tolerance is 1e-12.


{title:Examples}

{pstd}A baseline calibrated to 5 per cent growth, and a donor exit from 2022:{p_end}

{phang2}{cmd:. cge_closure, factors(cap:specific)}{p_end}
{phang2}{cmd:. cge_dynamic, name(base) periods(2018/2030) capital(cap) depreciation(0.05) rental(0.15) growth(lab:0.03) population(0.025) gdpgrowth(0.05)}{p_end}
{phang2}{cmd:. program define donor_exit}{p_end}
{phang2}{cmd:  1.     args t}{p_end}
{phang2}{cmd:  2.     if `t' >= 2022 cge_shock trdr, elements(npish) value(0)}{p_end}
{phang2}{cmd:  3. end}{p_end}
{phang2}{cmd:. cge_dynamic, name(exit) periods(2018/2030) capital(cap) depreciation(0.05) rental(0.15) growth(lab:0.03) population(0.025) baseline(base) shocks(donor_exit)}{p_end}
{phang2}{cmd:. cge_dynresults, run(exit) baseline(base) clear}{p_end}
{phang2}{cmd:. cge_report, run(exit) tables(macro health)}{p_end}


{title:Stored results}

{synoptset 16 tabbed}{...}
{p2col 5 16 20 2: Macros}{p_end}
{synopt:{cmd:r(name)}}name of the run{p_end}
{synopt:{cmd:r(sims)}}simulations of the run, in period order{p_end}


{title:Reference}

{phang}
Thurlow, J. (2004). A dynamic computable general equilibrium (CGE) model for
South Africa: extending the static IFPRI model. Trade and Industrial Policy
Strategies, Working Paper 1-2004.


{title:Also see}

{psee}
{helpb cge}, {helpb cge_dynresults}, {helpb cge_report}, {helpb cge_shock}
{p_end}
