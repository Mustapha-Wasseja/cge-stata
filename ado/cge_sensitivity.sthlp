{smcl}
{* *! version 0.38.0  30oct2026}{...}
{title:Title}

{p2colset 5 24 26 2}{...}
{p2col:{bf:cge_sensitivity} {hline 2}}Sensitivity of a scenario's results to the elasticities or parameters{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_sensitivity}{cmd:,} {opt scen:ario(program)} {opt draw:s(#)} [{opt seed(#)} {opt spr:ead(#)}
{opt dist:ribution(uniform|triangular)} {opt common} {opt var:y(list)} {opt tab:les(list)}
{opt cal:ibrate(program)} {opt vari:ables(names)} {opt item:s(items)}
{opt keep(name)} {opt clear} {opt sav:ing(filename[, replace])} {opt nod:isplay}]


{title:Description}

{pstd}
Elasticities are rarely estimated for the country and period of a SAM, and
results can depend on them. {cmd:cge_sensitivity} shows how much. For each of
{opt draws()} draws it multiplies the elasticities by random factors around
one, recalibrates the model from the SAM, restores the closure, runs the
{opt scenario()} program (which applies shocks with {helpb cge_shock}) and
solves. It then summarises every report measure of {helpb cge_report} across
the draws that converged:

{phang2}- the result with the central elasticities;{p_end}

{phang2}- the mean and standard deviation;{p_end}

{phang2}- the 5th and 95th percentiles (order statistics).{p_end}

{pstd}
Every other calibration option is kept: factor quantities, LES demand and the
health link. The model in memory, with its simulations, is restored exactly
at the end.

{pstd}
From version 0.38.0, a standalone model ({helpb cge_model}) has its
parameters drawn instead: {opt vary()} names the user parameters
({helpb cge_parameter}) whose values are multiplied by the factors. Each
draw loads the model as it was, sets the drawn values, runs the program of
{opt calibrate()}, if any, and solves the model without the scenario's
shocks: that benchmark is the draw's base, from which its results are
measured, so that a draw that moves the benchmark is not mistaken for an
effect of the scenario. The summary covers the tables of
{helpb cge_report} for a standalone model: its variables, the items of
{opt items()} and, with {cmd:cge_model roles}, its groups' welfare.

{pstd}
The draws do not estimate uncertainty about the elasticities. They show how
the results change over a chosen range around the values used, so the range,
the distribution and whether sectors move together should be stated with the
results.


{title:Options}

{phang}
{opt scenario(program)} names a program, without arguments, that applies the
scenario's shocks to the freshly calibrated model.

{phang}
{opt draws(#)} sets the number of draws. Draw 0, with the central
elasticities, is always added.

{phang}
{opt seed(#)} sets the random-number seed; the default is 12345. The same
seed gives the same draws.

{phang}
{opt spread(#)} sets the range of the factors, from 1 - {it:#} to
1 + {it:#}; the default is 0.5, and {it:#} must be less than 1.

{phang}
{opt distribution()} draws the factors from a uniform distribution (the
default) or a symmetric triangular one on that range.

{phang}
{opt common} draws one factor per type of elasticity, applied to every sector;
by default each sector's elasticity is drawn separately.

{phang}
{opt vary(list)} lists the elasticities to vary: {cmd:va} (value added),
{cmd:q} (Armington), {cmd:t} (CET and exports from composite supply) and
{cmd:a} (the top nest). The default is {cmd:va q t}. A Leontief top nest
(elasticity 0) stays Leontief.

{phang}
{opt tables(list)} lists the report tables to display (see
{helpb cge_report}), or {cmd:all}; the default is {cmd:macro welfare}.

{phang}
For a standalone model, {opt vary(names)} names the user parameters to vary,
and is required. Each element of a parameter is drawn separately, or with
{opt common} the elements of a parameter together.

{phang}
{opt calibrate(program)} (from version 0.38.0; standalone models) names a
program, without arguments, run after the drawn values are set, that sets
the parameters that depend on them, typically with the assignments of
{helpb cge_parameter} that calibrate the model. In it, parameters used by
the equations may be assigned again. A model from a SAM is calibrated again
for each draw without it.

{phang}
{opt variables(names)} and {opt items(items)} (from version 0.38.0) add the
elements of variables and measures of the user language to the results, as
in {helpb cge_report}. A standalone model has every variable without
{opt variables()}.

{phang}
{opt keep(name)} (from version 0.8.3) keeps the solution of every draw that
converged as a simulation of the model, {it:name}{cmd:0} (the central
elasticities), {it:name}{cmd:1}, {it:name}{cmd:2}, ..., each with the
parameters of its draw. {helpb cge_microsim:cge_microsim, bands({it:name})}
then gives the range of poverty and inequality across the draws, and any
command that takes a simulation can use them. Simulations of the same names
are replaced.

{phang}
{opt clear} replaces the data in memory with the results: the report measures
of every draw that converged (variables {cmd:draw}, {cmd:table},
{cmd:measure}, {cmd:element}, {cmd:base}, {cmd:value} and {cmd:pct}), and the
elasticities of every draw ({cmd:table} {cmd:elasticity}).

{phang}
{opt saving(filename[, replace])} saves the same dataset.

{phang}
{opt nodisplay} suppresses the summary.


{title:Example}

{phang2}{cmd:. program define tariff_cut}{p_end}

{phang2}{cmd:  1.     cge_shock tm, value(0)}{p_end}

{phang2}{cmd:  2. end}{p_end}

{phang2}{cmd:. cge_sensitivity, scenario(tariff_cut) draws(200) spread(0.5) saving(sens.dta, replace)}{p_end}

{pstd}A standalone model: draws of the supply elasticities{p_end}

{phang2}{cmd:. cge_model new}{p_end}

{phang2}{cmd:. cge_set c = g1 g2 g3}{p_end}

{phang2}{cmd:. cge_set h = h1 h2}{p_end}

{phang2}{cmd:. cge_parameter alpha(c,h), values(g1.h1:0.5 g2.h1:0.3 g3.h1:0.2 g1.h2:0.2 g2.h2:0.3 g3.h2:0.5)}{p_end}

{phang2}{cmd:. cge_parameter ybar(h), values(h1:100 h2:50)}{p_end}

{phang2}{cmd:. cge_parameter eta(c), values(g1:1 g2:1 g3:0.5)}{p_end}

{phang2}{cmd:. cge_parameter A(c) = sum(h, alpha(c,h) * ybar(h))}{p_end}

{phang2}{cmd:. cge_variable P(c), value(1)}{p_end}

{phang2}{cmd:. cge_variable Y(h) = ybar(h)}{p_end}

{phang2}{cmd:. cge_variable X(c) = A(c) * P(c)^eta(c)}{p_end}

{phang2}{cmd:. cge_variable Q(c,h) = alpha(c,h) * Y(h) / P(c)}{p_end}

{phang2}{cmd:. cge_equation MKT(c): sum(h, Q(c,h)) = X(c)}{p_end}

{phang2}{cmd:. cge_model roles, groups(h) goods(c) prices(P) consumption(Q) income(Y)}{p_end}

{phang2}{cmd:. program define supply_cut}{p_end}

{phang2}{cmd:  1.     cge_shock A, elements(g2) scale(0.8)}{p_end}

{phang2}{cmd:  2. end}{p_end}

{phang2}{cmd:. cge_sensitivity, scenario(supply_cut) draws(50) vary(eta) items(pg2 = P(g2))}{p_end}


{title:Stored results}

{synoptset 16 tabbed}{...}
{p2col 5 16 20 2: Scalars}{p_end}
{synopt:{cmd:r(N_draws)}}number of draws{p_end}
{synopt:{cmd:r(N_converged)}}number of draws that converged{p_end}


{title:Also see}

{psee}
{helpb cge}, {helpb cge_report}, {helpb cge_calibrate}
{p_end}
