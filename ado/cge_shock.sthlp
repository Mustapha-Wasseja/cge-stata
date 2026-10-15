{smcl}
{* *! version 0.1.10  15oct2026}{...}
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
{p2col:{cmd:qg}}government consumption in real terms (commodities), for example public spending on health services{p_end}
{p2col:{cmd:qinv}}investment demand in real terms (commodities){p_end}
{p2col:{cmd:trdg}}government transfers to households and enterprises (real terms){p_end}
{p2col:{cmd:trdr}}transfers from the rest of the world to households and enterprises (foreign currency), for example donor funding of a non-profit institution mapped as a household{p_end}
{p2col:{cmd:trfr}}factor income from abroad (factors; foreign currency){p_end}
{p2col:{cmd:trgr}}transfers from the rest of the world to the government, for example budget support (foreign currency; no elements){p_end}
{p2col:{cmd:trrg}}government transfers to the rest of the world (foreign currency; no elements){p_end}
{p2col:{cmd:tshi}}health insurance contribution rates on factor income (factors){p_end}
{p2col:{cmd:qshi}}base purchases of the health insurance fund (commodities), which {cmd:SHIADJ} scales{p_end}
{p2col:{cmd:trshi}}government transfers to the health insurance fund (real terms; no elements){p_end}
{p2col:{cmd:trshir}}transfers from the rest of the world to the health insurance fund (foreign currency; no elements){p_end}
{p2colreset}{...}

{pstd}
{cmd:qg} and {cmd:qinv} are base quantities that {cmd:GADJ} and {cmd:IADJ}
scale; changing them changes the composition of government consumption or
investment. In the default closure government savings adjust to a change in
government spending or transfers. {cmd:tshi}, {cmd:qshi}, {cmd:trshi} and
{cmd:trshir} need a fund named with {cmd:cge_map, insurance()}; the fund
spends its revenue less a fixed share saved, so a higher contribution rate or
larger transfers raise its purchases.

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
{phang2}{cmd:. cge_shock qg, elements(com_ser) scale(1.2)}{p_end}
{phang2}{cmd:. cge_shock trdr, elements(npi) value(0)}{p_end}
{phang2}{cmd:. cge_shock, reset}{p_end}


{title:Also see}

{psee}
{helpb cge}, {helpb cge_closure}, {helpb cge_solve}
{p_end}
