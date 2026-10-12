{smcl}
{* *! version 0.1.0  12oct2026}{...}
{title:Title}

{p2colset 5 18 20 2}{...}
{p2col:{bf:cge_shock} {hline 2}}Change a parameter or a fixed variable{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_shock} {it:name} [{cmd:,} {opt el:ements(list)}] {c -(}{opt sc:ale(#)}|{opt val:ue(#)}{c )-}

{p 8 12 2}
{cmd:cge_shock}{cmd:,} {opt reset}


{title:Description}

{pstd}
{cmd:cge_shock} changes the model before the next {helpb cge_solve}. Shocks
accumulate until {cmd:cge_shock, reset} restores all base values.

{pstd}
{it:name} is either a parameter:

{p2colset 9 18 20 2}{...}
{p2col:{cmd:tm}}import tariff rates (commodities){p_end}
{p2col:{cmd:te}}export tax rates (commodities){p_end}
{p2col:{cmd:tq}}sales tax rates (commodities){p_end}
{p2col:{cmd:ta}}activity tax rates (activities){p_end}
{p2col:{cmd:pwm}}world import prices (commodities){p_end}
{p2col:{cmd:pwe}}world export prices (commodities){p_end}
{p2col:{cmd:ad}}value-added efficiency, that is productivity (activities){p_end}
{p2colreset}{...}

{pstd}
or a model variable that is fixed under the current closure, such as {cmd:QFS}
(factor supply), {cmd:FSAV}, {cmd:EXR}, {cmd:GSAV}, {cmd:IADJ}, {cmd:GADJ},
{cmd:CPI} or {cmd:W}. Variable names are in upper case. Changing a variable that
the closure leaves free is an error.


{title:Options}

{phang}
{opt elements(list)} lists the commodities, activities, factors or households
to change; the default is all. For variables indexed by factor and activity
({cmd:QF}, {cmd:WFDIST}), the list names factors.

{phang}
{opt scale(#)} multiplies the current values by {it:#}.

{phang}
{opt value(#)} sets the values to {it:#}.

{phang}
{opt reset} removes all shocks.


{title:Examples}

{phang2}{cmd:. cge_shock tm, value(0)}{p_end}
{phang2}{cmd:. cge_shock pwm, elements(com_man) scale(1.1)}{p_end}
{phang2}{cmd:. cge_shock QFS, elements(lab) scale(1.05)}{p_end}
{phang2}{cmd:. cge_shock, reset}{p_end}


{title:Also see}

{psee}
{helpb cge}, {helpb cge_closure}, {helpb cge_solve}
{p_end}
