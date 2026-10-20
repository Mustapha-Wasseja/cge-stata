{smcl}
{* *! version 0.3.2  20oct2026}{...}
{title:Title}

{p2colset 5 22 24 2}{...}
{p2col:{bf:cge_calibrate} {hline 2}}Calibrate the model to the SAM{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_calibrate}{cmd:,} {opt sigmava(numlist)} {opt sigmaq(numlist)} {opt sigmat(numlist)}
[{opt fq:uantities(matname)} {opt inc:elas(numlist)} {opt fris:ch(numlist)} {opt sigmaa(numlist)}
{opt healthcom(names)} {opt healthfac(names)} {opt healthelas(numlist)}
{opt vatc:redit(spec)} {opt debt(spec)} {opt int:erest(spec)} {opt debth:olders(spec)}
{opt for:eignborrowing(#)} {opt exporto:nly(names)} {opt exportd:emand(spec)}]


{title:Description}

{pstd}
{cmd:cge_calibrate} computes the base values of all variables and the model
parameters from the mapped SAM (docs/model_spec.md, Section 7), sets the
default closure and checks that the base solves every equation (benchmark
replication). It stops with an error if replication fails.

{pstd}
Elasticities have no defaults; they are part of the model specification and
must be stated.


{title:Options}

{phang}
{opt sigmava(numlist)} gives the elasticity of substitution between factors in
each activity: one value for all activities, or one value per activity in the
order of {cmd:activities()} in {helpb cge_map}. A value of 1 selects the
Cobb-Douglas form.

{phang}
{opt sigmaq(numlist)} gives the elasticity of substitution between imports and
domestic goods (Armington), one value or one per commodity. Version 0.1 requires
values different from 1 for imported commodities.

{phang}
{opt sigmat(numlist)} gives the elasticity of transformation between exports
and domestic sales (CET), one value or one per commodity. For a commodity whose
exports are at least its domestic output (re-exports, or exports supplied from
inventories), exports are drawn from composite supply instead, and its
{opt sigmat()} value is the price elasticity of those exports
(docs/model_spec.md, equation T9); calibration lists such commodities.

{phang}
{opt fquantities(matname)} supplies base factor quantities, for example
employment, as a matrix with one row per factor and one column per activity.
Without it, factor prices are 1 in the base and quantities equal payments.

{phang}
{opt sigmaa(numlist)} gives the elasticity of substitution between value added
and aggregate intermediate input (the top nest of production), one value or one
per activity: 0, the default, is the Leontief nest, 1 is Cobb-Douglas, and other
positive values give a CES nest, under which an activity uses relatively less
of whichever input becomes dearer. Activities without intermediate inputs keep
the Leontief nest.

{phang}
{opt incelas(numlist)} and {opt frisch(numlist)} select linear expenditure
system (LES) household demand instead of the default Cobb-Douglas demand.
{opt incelas()} gives positive income elasticities, one value or one per
commodity; they are scaled so that marginal budget shares sum to one, which
keeps their ratios. {opt frisch()} gives the Frisch parameter, one value or one
per household, below -1; supernumerary spending is then {it:-1/frisch} of
consumption spending. {opt frisch()} is required with {opt incelas()}; given
alone, income elasticities are 1. Household consumption must be non-negative.
Under LES, the equivalent variation reported by {helpb cge_results} uses the LES
expenditure function.

{phang}
{opt healthcom(names)}, {opt healthfac(names)} and {opt healthelas(numlist)}
link factor efficiency to health services (from version 0.1.14).
{opt healthcom()} lists the health commodities; {opt healthfac()} lists the
factors whose efficiency depends on them (all factors by default); and
{opt healthelas()} gives the elasticity of each factor's efficiency with
respect to the volume of health services consumed by households, the
government and the health insurance fund, one value or one per factor in
{opt healthfac()}, zero or positive. With elasticity {it:e}, the factor's
efficiency is {it:(HS/HS0)^e}, where {it:HS} is that volume and {it:HS0} its
base; the factor then enters value added in efficiency units while its
quantity, supply and wage stay in physical units. Without these options, or
with elasticity 0, efficiency changes only through the {cmd:af} parameter of
{helpb cge_shock}. The health commodities must have some consumption in the
base. These options must be typed in full.

{phang}
{opt vatcredit(spec)} gives, for a model with a VAT account (see {helpb cge_map}),
the share of the VAT on its inputs that each activity recovers as a credit
(from version 0.3.1; docs/model_spec.md, Section 12.2): {it:activity}{cmd::}{it:share}
pairs or one share for all, between 0 and 1. The default, 1, is full credit, so
that VAT falls on final demand only; 0 is an exempt or unregistered activity,
which bears VAT on its inputs. The VAT rate of each commodity is calibrated so
that VAT on its uses, net of credits, equals the SAM's VAT; the quantities of
the uses are their SAM values divided by one plus the VAT they bear.

{phang}
{opt debt(spec)} and {opt interest(spec)} give public debt at the start of the
base year and its interest rates, as {cmd:domestic:}{it:#} and
{cmd:foreign:}{it:#} (from version 0.3.1; Section 12.3). Domestic debt is in
SAM units, foreign debt in foreign currency (equal to SAM units at the base
exchange rate). Interest is assumed to be recorded within the government's
transfers to domestic institutions and abroad; it is separated from them, and
then paid in nominal terms on the debt, so that the base is unchanged and
interest rates and debt stocks can be shocked. A transfer smaller than its
interest is an error. In dynamic runs ({helpb cge_dynamic}) the deficit adds
to the debt.

{phang}
{opt debtholders(spec)} gives the shares of domestic interest received by
households and enterprises, as {it:institution}{cmd::}{it:share} pairs that sum
to one. By default they are proportional to the government's transfers to
each.

{phang}
{opt foreignborrowing(#)} is the share of the deficit borrowed abroad in
dynamic runs; by default the foreign share of the base debt.

{phang}
{opt exportonly(names)} lists commodities whose domestic output is all
exported (from version 0.3.2; docs/model_spec.md, Section 13.3): exports, net
of export taxes and export margins, must equal domestic output. Their output
is then exported directly, at the export price, without domestic sales, and
may pay export taxes. Without this option such a commodity's exports are drawn
from composite supply, as before; calibration lists the commodities whose
exports equal domestic output.

{phang}
{opt exportdemand(spec)} gives elasticities of export demand,
{it:commodity}{cmd::}{it:elasticity} pairs or one value for every commodity
exported from domestic output (Section 13.2). The world export price then
falls as more is exported, instead of being fixed; a shock to {cmd:pwe}
shifts world demand. The default is a small country, with an infinite
elasticity.


{title:Example}

{phang2}{cmd:. cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)}{p_end}
{phang2}{cmd:. cge_calibrate, sigmava(0.5 1 1.5) sigmaq(0.6 3 1.2) sigmat(0.7 4 1)}{p_end}
{phang2}{cmd:. cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) incelas(0.6 1 1.4) frisch(-2)}{p_end}
{phang2}{cmd:. cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) sigmaa(0 0.5 1)}{p_end}
{phang2}{cmd:. cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) healthcom(com_hlt) healthfac(lab) healthelas(0.3)}{p_end}
{phang2}{cmd:. cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) vatcredit(act_agr:0 act_ser:0.5)}{p_end}
{phang2}{cmd:. cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) debt(domestic:100 foreign:40) interest(domestic:0.05 foreign:0.03)}{p_end}


{title:Stored results}

{synoptset 18 tabbed}{...}
{p2col 5 18 22 2: Scalars}{p_end}
{synopt:{cmd:r(N_equations)}}number of equations{p_end}
{synopt:{cmd:r(max_residual)}}largest scaled residual at the base{p_end}


{title:Also see}

{psee}
{helpb cge}, {helpb cge_map}, {helpb cge_closure}, {helpb cge_solve}
{p_end}
