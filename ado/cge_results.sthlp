{smcl}
{* *! version 0.6.4  22oct2026}{...}
{title:Title}

{p2colset 5 20 22 2}{...}
{p2col:{bf:cge_results} {hline 2}}Report simulation results{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_results} [{cmd:,} {opt sim(name)} {opt clear} {opt sav:ing(filename[, replace])} {opt nod:isplay}]


{title:Description}

{pstd}
{cmd:cge_results} displays a summary of a simulation: real value added, the
exchange rate, the CPI, investment, imports, exports, government savings, factor
prices and activity output, as percentage changes from the base (relative to
the absolute value of the base, so a fall is shown as negative even when the
base is negative, as for a government deficit); household equivalent
variation at base prices; and the Walras and GDP identity checks.

{pstd}
With {opt clear} or {opt saving()}, all results are written as a dataset with
one observation per variable element and the variables {cmd:variable},
{cmd:element1}, {cmd:element2}, {cmd:base} and {cmd:value}. Variable names
are those of the Reference Manual ({it:Notation and the social accounting matrix}).


{title:Options}

{phang}
{opt sim(name)} selects the simulation; the default is the last one stored (a
simulation solved again under its own name keeps its place).

{phang}
{opt clear} replaces the data in memory with the results.

{phang}
{opt saving(filename[, replace])} saves the results dataset.

{phang}
{opt nodisplay} suppresses the summary.


{title:Example}

{phang2}{cmd:. cge_results, sim(notariff)}{p_end}
{phang2}{cmd:. cge_results, sim(notariff) clear nodisplay}{p_end}
{phang2}{cmd:. list if variable == "QA"}{p_end}


{title:Stored results}

{synoptset 14 tabbed}{...}
{p2col 5 14 18 2: Scalars}{p_end}
{synopt:{cmd:r(converged)}}1 if the simulation converged (from version 0.16.0){p_end}
{synopt:{cmd:r(modelstat)}}its GAMS model status ({helpb cge_solve}); missing if solved before version 0.16.0{p_end}
{synopt:{cmd:r(solvestat)}}its GAMS solver status{p_end}
{p2col 5 14 18 2: Matrices}{p_end}
{synopt:{cmd:r(ev)}}equivalent variation by household{p_end}
{p2col 5 14 18 2: Macros}{p_end}
{synopt:{cmd:r(sim)}}simulation name{p_end}
{synopt:{cmd:r(model)}}the named model it solved, empty for the whole model (from version 0.17.0){p_end}


{title:Also see}

{psee}
{helpb cge}, {helpb cge_solve}, {helpb cge_check}, {helpb cge_report}
{p_end}
