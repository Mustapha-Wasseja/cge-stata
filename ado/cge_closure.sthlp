{smcl}
{* *! version 0.1.0  12oct2026}{...}
{title:Title}

{p2colset 5 20 22 2}{...}
{p2col:{bf:cge_closure} {hline 2}}Choose the model closure{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_closure} [{cmd:,} {opt ext:ernal(flexexr|fixexr)} {opt gov:ernment(flexgsav|fixgsav)}
{opt sav:inv(savings|investment)} {opt num:eraire(cpi|dpi)} {opt fac:tors(spec)}]


{title:Description}

{pstd}
{cmd:cge_closure} sets the closure (docs/model_spec.md, Section 6) and checks
that the model has as many free variables as equations. Options not specified
keep their current setting. Without options, the current closure is displayed.
{helpb cge_calibrate} sets the default closure, listed first below.


{title:Options}

{phang}
{opt external()}: {cmd:flexexr}, a flexible exchange rate with fixed foreign
savings; or {cmd:fixexr}, a fixed exchange rate with flexible foreign savings.

{phang}
{opt government()}: {cmd:flexgsav}, fixed tax rates with flexible government
savings; or {cmd:fixgsav}, fixed government savings with a flexible direct tax
scaling factor.

{phang}
{opt savinv()}: {cmd:savings}, savings-driven investment (fixed savings rates);
or {cmd:investment}, investment-driven savings (fixed investment, flexible
savings rates).

{phang}
{opt numeraire()}: {cmd:cpi}, the consumer price index; or {cmd:dpi}, the
producer price index for domestic sales.

{phang}
{opt factors(spec)} sets the closure of each factor as
{it:factor}{cmd::}{it:type}, where {it:type} is {cmd:mobile} (fully employed and
mobile across activities), {cmd:specific} (fixed in each activity) or
{cmd:unemployed} (fixed wage, flexible supply). Factors not listed are mobile.


{title:Example}

{phang2}{cmd:. cge_closure, external(fixexr) savinv(investment) factors(lab:unemployed cap:specific)}{p_end}


{title:Stored results}

{synoptset 16 tabbed}{...}
{p2col 5 16 20 2: Macros}{p_end}
{synopt:{cmd:r(closure)}}closure in one line{p_end}


{title:Also see}

{psee}
{helpb cge}, {helpb cge_shock}, {helpb cge_solve}
{p_end}
