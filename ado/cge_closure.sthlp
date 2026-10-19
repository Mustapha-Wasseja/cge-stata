{smcl}
{* *! version 0.3.1  20oct2026}{...}
{title:Title}

{p2colset 5 20 22 2}{...}
{p2col:{bf:cge_closure} {hline 2}}Choose the model closure{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_closure} [{cmd:,} {opt ext:ernal(flexexr|fixexr)} {opt gov:ernment(flexgsav|fixgsav [direct|sales|import|vat])}
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
savings; or {cmd:fixgsav}, fixed government savings, with one tax adjusting
(from version 0.3.1; docs/model_spec.md, Section 12.1): direct tax rates
({cmd:fixgsav} or {cmd:fixgsav direct}, scaled by {cmd:TINSADJ}), sales tax
rates ({cmd:fixgsav sales}, {cmd:TQADJ}), import tariffs ({cmd:fixgsav import},
{cmd:TMADJ}) or VAT rates ({cmd:fixgsav vat}, {cmd:TVADJ}). The adjusting tax
must raise revenue in the base; its rates are scaled in proportion, so rates
that are zero stay zero. With real government consumption fixed, this keeps a
policy change revenue neutral: for example, after a tariff cut the scaling
factor shows the rise in VAT or sales tax rates that replaces the lost
revenue. A colon may replace the space ({cmd:fixgsav:vat}), which is how the
closure is displayed.

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
