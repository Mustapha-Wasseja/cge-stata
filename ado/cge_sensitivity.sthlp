{smcl}
{* *! version 0.6.4  22oct2026}{...}
{title:Title}

{p2colset 5 24 26 2}{...}
{p2col:{bf:cge_sensitivity} {hline 2}}Sensitivity of a scenario's results to the elasticities{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_sensitivity}{cmd:,} {opt scen:ario(program)} {opt draw:s(#)} [{opt seed(#)} {opt spr:ead(#)}
{opt dist:ribution(uniform|triangular)} {opt common} {opt var:y(list)} {opt tab:les(list)}
{opt clear} {opt sav:ing(filename[, replace])} {opt nod:isplay}]


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


{title:Stored results}

{synoptset 16 tabbed}{...}
{p2col 5 16 20 2: Scalars}{p_end}
{synopt:{cmd:r(N_draws)}}number of draws{p_end}
{synopt:{cmd:r(N_converged)}}number of draws that converged{p_end}


{title:Also see}

{psee}
{helpb cge}, {helpb cge_report}, {helpb cge_calibrate}
{p_end}
