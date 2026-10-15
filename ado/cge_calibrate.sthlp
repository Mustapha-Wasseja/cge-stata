{smcl}
{* *! version 0.1.14  15oct2026}{...}
{title:Title}

{p2colset 5 22 24 2}{...}
{p2col:{bf:cge_calibrate} {hline 2}}Calibrate the model to the SAM{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_calibrate}{cmd:,} {opt sigmava(numlist)} {opt sigmaq(numlist)} {opt sigmat(numlist)}
[{opt fq:uantities(matname)} {opt inc:elas(numlist)} {opt fris:ch(numlist)} {opt sigmaa(numlist)}
{opt healthcom(names)} {opt healthfac(names)} {opt healthelas(numlist)}]


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


{title:Example}

{phang2}{cmd:. cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)}{p_end}
{phang2}{cmd:. cge_calibrate, sigmava(0.5 1 1.5) sigmaq(0.6 3 1.2) sigmat(0.7 4 1)}{p_end}
{phang2}{cmd:. cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) incelas(0.6 1 1.4) frisch(-2)}{p_end}
{phang2}{cmd:. cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) sigmaa(0 0.5 1)}{p_end}
{phang2}{cmd:. cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) healthcom(com_hlt) healthfac(lab) healthelas(0.3)}{p_end}


{title:Stored results}

{synoptset 18 tabbed}{...}
{p2col 5 18 22 2: Scalars}{p_end}
{synopt:{cmd:r(N_equations)}}number of equations{p_end}
{synopt:{cmd:r(max_residual)}}largest scaled residual at the base{p_end}


{title:Also see}

{psee}
{helpb cge}, {helpb cge_map}, {helpb cge_closure}, {helpb cge_solve}
{p_end}
