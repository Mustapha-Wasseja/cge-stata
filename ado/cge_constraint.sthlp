{smcl}
{* *! version 0.6.4  26oct2026}{...}
{title:Title}

{p2colset 5 23 25 2}{...}
{p2col:{bf:cge_constraint} {hline 2}}Limits that bind in some scenarios and not in others{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_constraint} {it:variable}{cmd:,} {opt up:per(#)}|{opt lo:wer(#)}
[{opt el:ements(list)} {opt sc:ale} {opt adj:ust(variable [elements])}
{opt up}|{opt down} {opt rent:s(account)}]

{p 8 12 2}
{cmd:cge_constraint}{cmd:,} {opt list}

{p 8 12 2}
{cmd:cge_constraint}{cmd:,} {opt clear}


{title:Description}

{pstd}
{cmd:cge_constraint} puts a bound on one element of a model variable, such as
imports of a commodity or the output of an activity, and pairs it with an
adjusting variable, which the closure fixes and which may move in one
direction only (from version 0.4.4; Reference Manual, {it:Bounds and complementarity}). In
every solution one of two things holds:

{phang2}o  the limited variable is within its bound and the adjusting variable is at its fixed level; or{p_end}

{phang2}o  the limited variable is at its bound and the adjusting variable has moved to keep it there.{p_end}

{pstd}
{helpb cge_solve} finds which, for each constraint: the conditions are
complementarity conditions, solved with the rest of the model, first in a
smoothed form and then exactly.

{pstd}
Quotas and capacity limits work through rents, which are zero in the base:

{p2colset 9 30 32 2}{...}
{p2col:{cmd:RM} {it:c}}premium on imports of commodity {it:c}, per unit of the world price{p_end}
{p2col:{cmd:RE} {it:c}}premium on exports of {it:c}, per unit of the world price{p_end}
{p2col:{cmd:RA} {it:a}}rent on the output of activity {it:a}, per unit of its price{p_end}
{p2colreset}{...}

{pstd}
A bound on {cmd:QM}, {cmd:QE} or {cmd:QA} is paired by default with the
rent of the same element, which may rise. The rent is income of the
recipient given in {opt rents()}: the government by default (as with
auctioned quota licences), a household or enterprise, a factor (such as the
owners of capital), or the rest of the world (as with a voluntary export
restraint, whose rents foreign exporters keep). Other limits switch the
closure. For example, a pegged exchange rate can hold until foreign
borrowing reaches a limit, after which the currency depreciates; and
government consumption can be cut once the deficit reaches a ceiling.

{p2colset 9 50 52 2}{...}
{p2col:{it:limit}}{it:command}{p_end}
{p2col:import quota}{cmd:cge_constraint QM, elements(com_man) upper(1.02) scale}{p_end}
{p2col:capacity}{cmd:cge_constraint QA, elements(act_hlt) upper(1.03) scale rents(hhd)}{p_end}
{p2col:borrowing limit under a peg}{cmd:cge_constraint FSAV, upper(30) adjust(EXR) up}{p_end}
{p2col:deficit ceiling}{cmd:cge_constraint GSAV, lower(0) adjust(GADJ) down}{p_end}
{p2col:nominal wage floor}{cmd:cge_constraint W, elements(lab) lower(1) scale adjust(QFS) down}{p_end}
{p2colreset}{...}

{pstd}
The limited variable must be free and the adjusting variable fixed under
the closure; each constraint adds one equation and frees one variable, so
the system stays square. A constraint on the same element with the same type
of bound replaces the earlier one. Constraints are kept by
{cmd:cge_shock, reset}, in dynamic runs, in sensitivity analysis and by
{helpb cge_save}; {cmd:cge_constraint, clear} removes them all.

{pstd}
A premium can also be set by hand, without a constraint: {cmd:cge_shock RM,}
{cmd:elements(com_man) value(0.05)} acts as a tariff of 5 per cent whose
revenue goes to the recipient.


{title:Options}

{phang}
{opt upper(#)} or {opt lower(#)} gives the bound, as a level or, with
{opt scale}, as a multiple of the base value.

{phang}
{opt elements(list)} names the elements of the limited variable; there is
one constraint for each. Without it, every existing element of a variable
with one index is bounded. A variable with two indexes takes one element of
each.

{phang}
{opt scale} reads the bound as a multiple of each element's base value.

{phang}
{opt adjust(variable [elements])} names the adjusting variable. Without
elements it takes the element of the limited variable, when the two
variables have the same index; a variable without index serves one constraint.

{phang}
{opt up} or {opt down} gives the direction in which the adjusting variable
may move from its fixed level; rents rise by default.

{phang}
{opt rents(account)} names the recipient of a rent: a factor, household or
enterprise, the government or the rest of the world.

{phang}
{opt list} displays the constraints, with their regime in the last
solution. {opt clear} removes them, and sends every rent to the government.


{title:Examples}

{phang2}{cmd:. cge_synthetic, clear health}{p_end}

{phang2}{cmd:. cge_sam, labels(account)}{p_end}

{phang2}{cmd:. cge_map, activities(act_agr act_man act_ser act_hlt) commodities(com_agr com_man com_ser com_hlt) factors(lab cap)}
{cmd:households(hhd) government(gov) savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) insurance(shi)}{p_end}

{phang2}{cmd:. cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)}{p_end}

{phang2}{cmd:. cge_shock qg, elements(com_hlt) scale(1.2)}{p_end}

{phang2}{cmd:. cge_constraint QA, elements(act_hlt) upper(1.03) scale rents(hhd)}{p_end}

{phang2}{cmd:. cge_solve, name(capacity)}{p_end}

{phang2}{cmd:. cge_constraint, list}{p_end}


{title:Stored results}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(N_constraints)}}number of constraints (also after adding one, and 0 after {opt clear}){p_end}
{synopt:{cmd:r(N_binding)}}number binding in the last solution ({opt list}){p_end}


{title:Remarks}

{pstd}
The minimum real wage of {helpb cge_closure}'s {cmd:minwage} closure is a
complementarity condition of the same kind, with its own calibration
(Reference Manual, {it:Labour-market regimes}). The Python reference finds the regimes
by an active-set method, and GAMS ({helpb cge_gams}) solves them as a mixed
complementarity problem with PATH; the three agree on every test case.


{title:Also see}

{psee}
{helpb cge_solve}, {helpb cge_closure}, {helpb cge_shock}, {helpb cge_gams}, {helpb cge}
{p_end}
