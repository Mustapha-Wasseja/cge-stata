{smcl}
{* *! version 0.6.4  22oct2026}{...}
{title:Title}

{p2colset 5 20 22 2}{...}
{p2col:{bf:cge_closure} {hline 2}}Choose the model closure{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_closure} [{cmd:,} {opt ext:ernal(flexexr|fixexr)} {opt gov:ernment(flexgsav|fixgsav [direct|sales|import|vat])}
{opt sav:inv(savings|investment)} {opt num:eraire(cpi|dpi)} {opt fac:tors(spec)}
{opt swap(fix free [fix free ...])}]


{title:Description}

{pstd}
{cmd:cge_closure} sets the closure (Reference Manual, {it:Closures}) and checks
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
(from version 0.3.1; Reference Manual, {it:Fiscal instruments}): direct tax rates
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
mobile across activities), {cmd:specific} (fixed in each activity),
{cmd:unemployed} (fixed wage, flexible supply), {cmd:wagecurve} or
{cmd:minwage}. Factors not listed are mobile.

{pmore}
{cmd:wagecurve} and {cmd:minwage} (from version 0.3.3; Reference Manual,
{it:Labour-market regimes}) need a labour force, from {helpb cge_calibrate} with
{opt unemployment()} or {opt minwage()}. Under both, the wage and employment
are endogenous and the labour force is fixed. With {cmd:wagecurve}
(and {opt wagecurve()} at calibration) the real wage falls as the
unemployment rate rises. With {cmd:minwage} the real wage cannot fall below
its floor: either the floor binds and unemployment absorbs the shock, or the
wage is above the floor and the labour force is fully employed. The solver
finds which.

{phang}
{opt swap(fix free [fix free ...])} (from version 0.4.5) changes the closure
element by element, after the options above: each pair fixes the first
variable, which the closure leaves free, and frees the second, which it
fixes. Elements are written {it:NAME}, {it:NAME}{cmd:(}{it:e1}{cmd:)} or
{it:NAME}{cmd:(}{it:e1}{cmd:,}{it:e2}{cmd:)}, for example {cmd:W(lab)}. For
example:

{phang2}o  {cmd:swap(GSAV GADJ)} fixes government savings and lets government consumption adjust;{p_end}
{phang2}o  {cmd:swap(EXR CPI)} makes the exchange rate the numeraire;{p_end}
{phang2}o  {cmd:swap(QG(com_hlt) GADJ)} fixes government purchases of health services, which can then be shocked, and scales the other purchases with them.{p_end}

{pmore}
Swaps replace any earlier ones and stay until changed; {cmd:swap(none)}
removes them. They are recorded with each simulation, saved with the model,
kept in sensitivity analysis and exported by {helpb cge_gams}. Variables
computed from their definitions (such as household demand) cannot be fixed.

{pstd}
The closure must be square, with as many free variables as equations, and
from version 0.4.5 it must not leave an equation without a free variable:
such a closure is singular, and {cmd:cge_closure} names the equation.


{title:Example}

{pstd}Setup: the SYNTHETIC SAM of {helpb cge_synthetic}, mapped as in {helpb cge_map}{p_end}
{phang2}{cmd:. cge_synthetic, clear}{p_end}
{phang2}{cmd:. cge_sam, labels(account)}{p_end}
{phang2}{cmd:. cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) factors(lab cap) households(hhd) government(gov) savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)}{p_end}
{phang2}{cmd:. cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)}{p_end}

{pstd}A fixed exchange rate, investment-driven savings, unemployment at a fixed wage and sector-specific capital{p_end}
{phang2}{cmd:. cge_closure, external(fixexr) savinv(investment) factors(lab:unemployed cap:specific)}{p_end}

{pstd}Fixed government savings, with government consumption adjusting{p_end}
{phang2}{cmd:. cge_closure, swap(GSAV GADJ)}{p_end}

{pstd}A wage curve, and a minimum wage, which need a labour force from {helpb cge_calibrate}{p_end}
{phang2}{cmd:. cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) unemployment(lab:0.15) wagecurve(lab:0.1)}{p_end}
{phang2}{cmd:. cge_closure, factors(lab:wagecurve)}{p_end}
{phang2}{cmd:. cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) minwage(lab:0.95)}{p_end}
{phang2}{cmd:. cge_closure, factors(lab:minwage cap:specific)}{p_end}


{title:Stored results}

{synoptset 16 tabbed}{...}
{p2col 5 16 20 2: Scalars}{p_end}
{synopt:{cmd:r(N_swaps)}}number of swaps{p_end}
{p2col 5 16 20 2: Macros}{p_end}
{synopt:{cmd:r(closure)}}closure in one line, with the swaps{p_end}


{title:Also see}

{psee}
{helpb cge}, {helpb cge_shock}, {helpb cge_solve}
{p_end}
