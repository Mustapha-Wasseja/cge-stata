{smcl}
{* *! version 0.2.0  16oct2026}{...}
{title:Title}

{p2colset 5 23 25 2}{...}
{p2col:{bf:cge_dynresults} {hline 2}}Results of a dynamic run as a dataset{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_dynresults}{cmd:,} {opt run(name)} {opt clear} [{opt base:line(name)}]


{title:Description}

{pstd}
{cmd:cge_dynresults} replaces the data in memory with the results of a run
solved by {helpb cge_dynamic}: one observation per period and variable element,
with the variables {cmd:period}, {cmd:variable}, {cmd:element1},
{cmd:element2}, {cmd:base} (the calibrated SAM) and {cmd:value}. With
{opt baseline()}, the variables {cmd:baseline} (the baseline run's value in the
same period) and {cmd:dev_pct} (the per cent difference from it, relative to
its absolute value) are added. Variable names follow docs/model_spec.md,
Section 3.


{title:Options}

{phang}
{opt run(name)} names the run.

{phang}
{opt clear} is required: the data in memory are replaced.

{phang}
{opt baseline(name)} names a run with the same periods to compare with.


{title:Example}

{phang2}{cmd:. cge_dynresults, run(exit) baseline(base) clear}{p_end}
{phang2}{cmd:. line dev_pct period if variable == "EH" & element1 == "hh_ru_p"}{p_end}


{title:Also see}

{psee}
{helpb cge_dynamic}, {helpb cge_report}
{p_end}
