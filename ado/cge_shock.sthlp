{smcl}
{* *! version 0.5.0  21oct2026}{...}
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
{p2col:{cmd:tv}}VAT rates (commodities; from version 0.3.1, with a VAT account){p_end}
{p2col:{cmd:kappa}}VAT credit shares, between 0 and 1 (activities){p_end}
{p2col:{cmd:pwm}}world import prices (commodities){p_end}
{p2col:{cmd:pwe}}world export prices (commodities); with finite export demand ({helpb cge_calibrate}, {opt exportdemand()}), a shift in world demand{p_end}
{p2col:{cmd:ad}}value-added efficiency, that is productivity (activities){p_end}
{p2col:{cmd:af}}factor efficiency in every activity (factors; one in the base), for example lower labour productivity from illness{p_end}
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
{p2col:{cmd:rd}, {cmd:rf}}interest rates on domestic and foreign public debt (no elements; with debt, from version 0.3.1){p_end}
{p2col:{cmd:ddebt}, {cmd:fdebt}}domestic debt (local currency) and foreign debt (foreign currency) at the start of the period, for example debt relief (no elements){p_end}
{p2col:{cmd:qlf}}labour force (factors with a labour force; from version 0.3.3){p_end}
{p2col:{cmd:wmin}}real minimum wage (factors with a labour force), for example a rise in the statutory minimum{p_end}
{p2col:{cmd:wref}}reference real wage of the wage curve (factors with a labour force){p_end}
{p2col:{cmd:sick}}share of working time lost to illness before the response to health services (factors with {opt sickdays()}; from version 0.3.4), for example an epidemic{p_end}
{p2col:{cmd:mort}}crude death rate before the response to health services (no elements; with {opt mortality()}){p_end}
{p2col:{cmd:tf}}rates of tax on the use of factors (factors; from version 0.5.0), in every activity that uses them: {cmd:scale()} changes each rate, {cmd:value()} sets one rate for every activity, which introduces a tax where the SAM has none{p_end}
{p2col:{cmd:tfy}}rates of tax on factor income (factors){p_end}
{p2colreset}{...}

{pstd}
{cmd:qg} and {cmd:qinv} are base quantities that {cmd:GADJ} and {cmd:IADJ}
scale; changing them changes the composition of government consumption or
investment. In the default closure government savings adjust to a change in
government spending or transfers. {cmd:tshi}, {cmd:qshi}, {cmd:trshi} and
{cmd:trshir} need a fund named with {cmd:cge_map, insurance()}; the fund
spends its revenue less a fixed share saved, so a higher contribution rate or
larger transfers raise its purchases. {cmd:af} multiplies the efficiency of a
factor: factor quantities and wages stay in physical units, so with mobile
factors a 2 per cent fall in labour efficiency has the same real effects as 2
per cent less labour. When {helpb cge_calibrate} links efficiency to health
services, more health services also raise the efficiency variable {cmd:EFF}.

{pstd}
{cmd:tv} and {cmd:kappa} need a VAT account ({helpb cge_map}, {opt vattax()} or
{opt vatshare()}; {cmd:vatshare(0)} creates an empty one, so that VAT can be
introduced). {cmd:rd}, {cmd:rf}, {cmd:ddebt} and {cmd:fdebt} need public debt
({helpb cge_calibrate}, {opt debt()} and {opt interest()}); interest is paid on
the stocks at the rates. The tax scaling factors {cmd:TQADJ}, {cmd:TMADJ} and
{cmd:TVADJ}, like {cmd:TINSADJ}, are variables that can be set while the
closure fixes them. So are the rents {cmd:RM}, {cmd:RE} and {cmd:RA} (from
version 0.4.4): a premium on imports set by hand acts as a tariff whose
revenue goes to its recipient ({helpb cge_constraint}).

{pstd}
{cmd:cge_shock, reset} removes every shock but keeps the constraints of
{helpb cge_constraint}.

{pstd}
{cmd:qlf}, {cmd:wmin} and {cmd:wref} need a labour force ({helpb cge_calibrate},
{opt unemployment()} or {opt minwage()}). Under the closure {cmd:wagecurve} or
{cmd:minwage} of {helpb cge_closure}, a larger labour force raises unemployment
unless demand for labour grows with it; real wages are measured with the CPI.

{pstd}
{cmd:sick} and {cmd:mort} need days lost to illness or a death rate
({helpb cge_calibrate}, {opt sickdays()} or {opt mortality()}); both must stay
at least 0 and below 1. Doubling {cmd:sick} doubles the share of working time
lost at base health services per head. A higher death rate changes no
result within a period; in a dynamic run it slows population and labour
growth from the next period.

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
