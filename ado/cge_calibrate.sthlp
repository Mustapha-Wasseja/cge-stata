{smcl}
{* *! version 0.7.1  22oct2026}{...}
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
{opt for:eignborrowing(#)} {opt exporto:nly(names)} {opt exportd:emand(spec)}
{opt unemp:loyment(spec)} {opt wagec:urve(spec)} {opt minw:age(spec)} {opt smooth:ing(#)}
{opt sickd:ays(spec)} {opt sicke:las(spec)} {opt mort:ality(#)} {opt morte:las(#)}
{opt nest:s(spec)} {opt sigman:est(spec)} {opt sigmaac(spec)}]


{title:Description}

{pstd}
{cmd:cge_calibrate} computes the base values of all variables and the model
parameters from the mapped SAM (Reference Manual, {it:Calibration}), sets the
default closure and checks that the base solves every equation of the model
(benchmark replication). It stops with an error if replication fails. User
equations ({helpb cge_equation}) need not hold at the base, where they act as
shocks; from version 0.7.1 replication leaves them out, and a note says when
they do not hold.

{pstd}
Calibrating again starts the model afresh from the mapped SAM: shocks, swaps,
constraints and stored simulations are removed, and user variables and
equations are compiled again. User sets ({helpb cge_set}) are kept, and so are
user parameters ({helpb cge_parameter}), at their base values.

{pstd}
Elasticities have no defaults; they are part of the model specification and
must be stated. {helpb cge_elasticities} (from version 0.3.5) gives published
values with their sources and returns them as options for this command.


{title:Options}

{phang}
{opt sigmava(numlist)} gives the elasticity of substitution between factors in
each activity: one value for all activities, or one value per activity in the
order of {cmd:activities()} in {helpb cge_map}. A value of 1 selects the
Cobb-Douglas form.

{phang}
{opt sigmaq(numlist)} gives the elasticity of substitution between imports and
domestic goods (Armington), one value or one per commodity. Values must differ
from 1 for commodities that have both imports and domestic sales.

{phang}
{opt sigmat(numlist)} gives the elasticity of transformation between exports
and domestic sales (CET), one value or one per commodity. For a commodity whose
exports are at least its domestic output (re-exports, or exports supplied from
inventories), exports are drawn from composite supply instead, and its
{opt sigmat()} value is the price elasticity of those exports
(Reference Manual, equation T9); calibration lists such commodities.

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
{opt nests(spec)} (from version 0.5.1; Reference Manual, {it:Factor taxes, nests and output aggregation})
defines nests of value added, separated by commas, each as a name followed by
a colon and its members, factors or commodities, for example
{cmd:nests(labour: lab_hi lab_lo, ke: cap com_ene)}. Each nest is a CES or
Cobb-Douglas aggregate of its members, and value added combines the factors
in no nest with the nests, with the elasticity {opt sigmava()}. A commodity
in a nest, such as energy, leaves intermediate input: activities substitute
between it and the other members of its nest. A factor or commodity may be
in one nest only, and nests do not contain other nests. Results list the
quantity ({cmd:QNA}) and price ({cmd:PNA}) of each nest in each activity.

{phang}
{opt sigmanest(spec)} gives the elasticity of substitution within the nests:
one value for every nest, or {it:nest}{cmd::}{it:value} pairs. A value of 1
selects the Cobb-Douglas form.

{phang}
{opt sigmaac(spec)} (from version 0.5.2; Reference Manual, {it:Factor taxes, nests and output aggregation})
combines the outputs of a commodity from several activities by a CES
function, as in the IFPRI standard model, instead of treating them as perfect
substitutes: each activity is then paid its own price for the commodity
({cmd:PXAC}). Give {it:commodity}{cmd::}{it:elasticity} pairs, for example
{cmd:sigmaac(com_man:2)}, or one value for every commodity produced by more
than one activity. A value of 1 selects the Cobb-Douglas form.

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
(from version 0.3.1; Reference Manual, {it:Fiscal instruments}): {it:activity}{cmd::}{it:share}
pairs or one share for all, between 0 and 1. The default, 1, is full credit, so
that VAT falls on final demand only; 0 is an exempt or unregistered activity,
which bears VAT on its inputs. The VAT rate of each commodity is calibrated so
that VAT on its uses, net of credits, equals the SAM's VAT; the quantities of
the uses are their SAM values divided by one plus the VAT they bear.

{phang}
{opt debt(spec)} and {opt interest(spec)} give public debt at the start of the
base year and its interest rates, as {cmd:domestic:}{it:#} and
{cmd:foreign:}{it:#} (from version 0.3.1; Reference Manual, {it:Fiscal instruments}). Domestic debt is in
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
exported (from version 0.3.2; Reference Manual, {it:Trade and household extensions}): exports, net
of export taxes and export margins, must equal domestic output. Their output
is then exported directly, at the export price, without domestic sales, and
may pay export taxes. Without this option such a commodity's exports are drawn
from composite supply, as before; calibration lists the commodities whose
exports equal domestic output.

{phang}
{opt exportdemand(spec)} gives elasticities of export demand,
{it:commodity}{cmd::}{it:elasticity} pairs or one value for every commodity
exported from domestic output (Reference Manual, {it:Trade and household extensions}). The world export price then
falls as more is exported, instead of being fixed; a shock to {cmd:pwe}
shifts world demand. The default is a small country, with an infinite
elasticity.

{pstd}
{it:Labour-market regimes} (from version 0.3.3; Reference Manual, {it:Labour-market regimes})

{phang}
{opt unemployment(spec)} gives base unemployment rates,
{it:factor}{cmd::}{it:rate} pairs with rates at least 0 and below 1, for
example {cmd:unemployment(lab:0.15)}. SAMs record employment, not
unemployment, so the rate comes from a labour force survey. The factor's
labour force is then base employment divided by one minus the rate; reports
show the labour force and the unemployment rate, and the closures
{cmd:wagecurve} and {cmd:minwage} of {helpb cge_closure} become available. A
factor with unemployment in the base has a minimum wage at its base real
wage.

{phang}
{opt wagecurve(spec)} gives wage-curve elasticities, {it:factor}{cmd::}{it:elasticity}
pairs, for factors with unemployment in the base: under the closure
{cmd:wagecurve} the real wage falls by about {it:elasticity} per cent for each
per cent rise in the unemployment rate (Blanchflower and Oswald 1994; often
about 0.1). A small elasticity approaches a fixed real wage, a large one full
employment.

{phang}
{opt minwage(spec)} gives minimum real wages as shares of the base real wage,
{it:factor}{cmd::}{it:share}. With unemployment in the base the floor is the
base real wage (a share of 1, the default). With full employment in the base
(no rate in {opt unemployment()}), give a share below 1, for example
{cmd:minwage(lab:0.95)}: the floor then binds only after real wages fall by 5
per cent.

{phang}
{opt smoothing(#)} sets the smoothing parameter mu of the minimum-wage
condition; the default is 1e-10. Under the closure {cmd:minwage} the
condition that either unemployment is zero or the wage is at its floor is
solved, with the rest of the model, in the smoothed Fischer-Burmeister form,
in which the product of the unemployment rate and the proportional excess of
the real wage over the floor is mu. The solver finds which of the two holds;
the calibration lists the labour force and the floor.

{pstd}
{it:Health outcomes} (from version 0.3.4; Reference Manual, {it:Health}).
Outcomes respond to health services per head relative to the base, {it:R} =
{it:HS/HS0}, with constant elasticities. The elasticities are hypotheses
about how services become health and should come from studies of the
country or region; the package supplies none. An outcome with a zero
elasticity changes only when shocked and needs no {opt healthcom()}.

{phang}
{opt sickdays(spec)} gives the base share of working time lost to illness,
{it:factor}{cmd::}{it:share} pairs with shares at least 0 and below 1, for
example {cmd:sickdays(lab:0.05)} from a labour force or household survey.
Days worked per worker then scale the factor's effective input in
production; employment, wages and unemployment stay per worker. In real
terms this is the same as less labour measured in days.

{phang}
{opt sickelas(spec)} gives the elasticity of the share of time lost with
respect to health services per head, one value for every factor in
{opt sickdays()} or {it:factor}{cmd::}{it:elasticity} pairs; usually
negative. The share lost is {it:share x R^elasticity}.

{phang}
{opt mortality(#)} gives the base crude death rate, deaths per head per
period (for example 0.008 for 8 per 1,000 a year), and {opt mortelas(#)} its
elasticity with respect to health services per head. The death rate is
reported; it does not change the solution of a period, but in dynamic runs
it changes the growth of the population and, with {opt deathfactors()} of
{helpb cge_dynamic}, of labour from the next period.


{title:Example}

{pstd}Setup: the SYNTHETIC SAM of {helpb cge_synthetic}, mapped as in {helpb cge_map}{p_end}
{phang2}{cmd:. cge_synthetic, clear}{p_end}
{phang2}{cmd:. cge_sam, labels(account)}{p_end}
{phang2}{cmd:. cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) factors(lab cap) households(hhd) government(gov) savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)}{p_end}

{pstd}One elasticity for all, or one per activity and per commodity{p_end}
{phang2}{cmd:. cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)}{p_end}
{phang2}{cmd:. cge_calibrate, sigmava(0.5 1 1.5) sigmaq(0.6 3 1.2) sigmat(0.7 4 1)}{p_end}

{pstd}Linear expenditure demand, and a CES nest of value added and intermediate inputs{p_end}
{phang2}{cmd:. cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) incelas(0.6 1 1.4) frisch(-2)}{p_end}
{phang2}{cmd:. cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) sigmaa(0 0.5 1)}{p_end}

{pstd}Unemployment with a wage curve, or a minimum wage{p_end}
{phang2}{cmd:. cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) unemployment(lab:0.15) wagecurve(lab:0.1)}{p_end}
{phang2}{cmd:. cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) minwage(lab:0.95)}{p_end}

{pstd}VAT credits, with the SAM that has a VAT account{p_end}
{phang2}{cmd:. cge_synthetic, clear vat}{p_end}
{phang2}{cmd:. cge_sam, labels(account)}{p_end}
{phang2}{cmd:. cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) factors(lab cap) households(hhd) government(gov) savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) vattax(tax_vat)}{p_end}
{phang2}{cmd:. cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) vatcredit(act_agr:0 act_ser:0.5)}{p_end}

{pstd}Public debt and its interest, with the SAM whose government pays transfers abroad{p_end}
{phang2}{cmd:. cge_synthetic, clear institutions}{p_end}
{phang2}{cmd:. cge_sam, labels(account)}{p_end}
{phang2}{cmd:. cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) factors(lab cap) households(hhd npi) enterprises(ent) government(gov) savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)}{p_end}
{phang2}{cmd:. cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) debt(domestic:100 foreign:40) interest(domestic:0.05 foreign:0.03)}{p_end}

{pstd}Health outcomes, with the SAM that has a health sector and an insurance fund{p_end}
{phang2}{cmd:. cge_synthetic, clear health}{p_end}
{phang2}{cmd:. cge_sam, labels(account)}{p_end}
{phang2}{cmd:. cge_map, activities(act_agr act_man act_ser act_hlt) commodities(com_agr com_man com_ser com_hlt) factors(lab cap) households(hhd) government(gov) savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) insurance(shi)}{p_end}
{phang2}{cmd:. cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) healthcom(com_hlt) healthfac(lab) healthelas(0.3)}{p_end}
{phang2}{cmd:. cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) healthcom(com_hlt) sickdays(lab:0.05) sickelas(-0.4) mortality(0.01) mortelas(-0.3)}{p_end}

{pstd}Nests of value added: two labour types, and capital with energy{p_end}
{phang2}{cmd:. cge_synthetic, clear nests}{p_end}
{phang2}{cmd:. cge_sam, labels(account)}{p_end}
{phang2}{cmd:. cge_map, activities(act_agr act_man act_ser act_ene) commodities(com_agr com_man com_ser com_ene) factors(lab_hi lab_lo cap) households(hhd) government(gov) savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) factortax(tax_pay:lab_hi)}{p_end}
{phang2}{cmd:. cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) nests(labour: lab_hi lab_lo, ke: cap com_ene) sigmanest(labour:1.5 ke:0.4)}{p_end}


{title:Stored results}

{synoptset 18 tabbed}{...}
{p2col 5 18 22 2: Scalars}{p_end}
{synopt:{cmd:r(N_equations)}}number of equations{p_end}
{synopt:{cmd:r(max_residual)}}largest scaled residual at the base{p_end}


{title:References}

{phang}
Anyanwu, J. C. and A. E. O. Erhijakpor. 2009. Health expenditures and health
outcomes in Africa. {it:African Development Review} 21: 400-433.

{phang}
Blanchflower, D. G. and A. J. Oswald. 1994. {it:The Wage Curve}. Cambridge, MA: MIT Press.

{phang}
Bokhari, F. A. S., Y. Gai and P. Gottret. 2007. Government health
expenditures and health outcomes. {it:Health Economics} 16: 257-273.

{phang}
Fischer, A. 1992. A special Newton-type optimization method. {it:Optimization} 24: 269-284.

{phang}
Kanzow, C. 1996. Some noninterior continuation methods for linear
complementarity problems. {it:SIAM Journal on Matrix Analysis and Applications} 17: 851-868.


{title:Also see}

{psee}
{helpb cge}, {helpb cge_map}, {helpb cge_closure}, {helpb cge_solve}
{p_end}
