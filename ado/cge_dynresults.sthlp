{smcl}
{* *! version 0.6.4  26oct2026}{...}
{title:Title}

{p2colset 5 23 25 2}{...}
{p2col:{bf:cge_dynresults} {hline 2}}Results of a dynamic run as a dataset{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_dynresults}{cmd:,} {opt run(name)} {opt clear} [{opt base:line(name)}]


{title:Description}

{pstd}
{cmd:cge_dynresults} replaces the data in memory (which are kept if the run
cannot be loaded) with the results of a run
solved by {helpb cge_dynamic}: one observation per period and variable element,
with the variables {cmd:period}, {cmd:variable}, {cmd:element1},
{cmd:element2}, {cmd:base} (the calibrated SAM) and {cmd:value}. With
{opt baseline()}, a run with every period of this one, the variables
{cmd:baseline} (the baseline run's value in the same period) and {cmd:dev_pct} (the per cent difference from it, relative to
its absolute value) are added. Variable names are those of the Reference Manual
({it:Notation and the social accounting matrix}).


{title:Options}

{phang}
{opt run(name)} names the run.

{phang}
{opt clear} is required: the data in memory are replaced.

{phang}
{opt baseline(name)} names a run with the same periods to compare with.


{title:Example}

{pstd}After the example in {helpb cge_dynamic}:{p_end}

{phang2}{cmd:. cge_dynresults, run(exit) baseline(base) clear}{p_end}

{phang2}{cmd:. line dev_pct period if variable == "EH" & element1 == "hhd"}{p_end}


{title:Also see}

{psee}
{helpb cge_dynamic}, {helpb cge_report}
{p_end}
