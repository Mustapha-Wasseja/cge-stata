{smcl}
{* *! version 0.36.0  30oct2026}{...}
{title:Title}

{p2colset 5 16 18 2}{...}
{p2col:{bf:cge_iis} {hline 2}}An irreducible infeasible set of bounds and constraints{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_iis} [{cmd:,} {opt tol:erance(#)} {opt iter:ate(#)} {opt trace}]


{title:Description}

{pstd}
{cmd:cge_iis} (from version 0.36.0; Reference Manual, {it:cge_iis}) looks
for the reason a scenario cannot be solved among its bounds
({helpb cge_bound}) and constraints ({helpb cge_constraint}, and the
inequalities of {helpb cge_equation}). It finds an irreducible infeasible
set, as CPLEX's and Gurobi's IIS for linear programmes: bounds and
constraints that together leave the scenario without a solution, while it
solves without any one of them.

{pstd}
It uses the deletion filter of Chinneck and Dravnieks (1991). The scenario
must fail to solve with every bound and constraint and solve without them
all; each in turn is then left out for good if the scenario still fails
without it. What remains is the set. The search takes one solve for each
bound and constraint, and two more. A failure to solve stands for
infeasibility, so the set is that of the solver as much as of the model.
For a square system, whose solution is unique, a set is typically one bound
that the solution crosses, or a constraint with a bound on the variable
that adjusts for it.

{pstd}
Each solve is of the square system of the scenario, as {helpb cge_solve}
without {opt minimize()} or {opt maximize()} makes it, at the first of three
levels at which the scenario without its bounds and constraints solves:
Newton's method from the base; with the fallbacks of {cmd:cge_solve}
(central differences, then Powell's hybrid method); and with them in 4 and
then 16 steps. Most scenarios solve at the first level, where a solve that
fails stops at once, so that the search takes seconds where the fallbacks
would take minutes.

{pstd}
The equations themselves are not candidates: without one, the system would
not be square. When the scenario cannot be solved even without its bounds
and constraints, {cmd:cge_iis} stops with error 459; {helpb cge_listing}
shows where the solve stops and {helpb cge_structure} whether the system is
structurally singular.


{title:Options}

{phang}
{opt tolerance(#)} is the tolerance of each solve; the default is that of
{helpb cge_options}.

{phang}
{opt iterate(#)} limits the iterations of each solve; the default is that of
{helpb cge_options}.

{phang}
{opt trace} shows the outcome of each step.


{title:Examples}

{pstd}Setup{p_end}

{phang2}{cmd:. cge_synthetic, clear}{p_end}

{phang2}{cmd:. cge_sam, labels(account)}{p_end}

{phang2}{cmd:. cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) factors(lab cap)}
{cmd:households(hhd) government(gov) savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)}{p_end}

{phang2}{cmd:. cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)}{p_end}

{pstd}A tariff removal with imports of manufactures held below their base, among bounds that do not bind{p_end}

{phang2}{cmd:. cge_shock tm, value(0)}{p_end}

{phang2}{cmd:. cge_bound QM(com_man), upper(1) relative}{p_end}

{phang2}{cmd:. cge_bound QM(com_agr), lower(0.5) relative}{p_end}

{phang2}{cmd:. cge_bound PQ, lower(0.5) upper(2) relative}{p_end}

{phang2}{cmd:. cge_iis, trace}{p_end}

{phang2}{cmd:. cge_bound, clear}{p_end}

{pstd}A quota whose rent is capped below what it needs: the inequality and the cap together{p_end}

{phang2}{cmd:. cge_equation quota: QM(com_man) =l= 0.98 * base(QM(com_man)), perp(RM(com_man))}{p_end}

{phang2}{cmd:. cge_bound RM(com_man), upper(0.0487)}{p_end}

{phang2}{cmd:. cge_iis}{p_end}

{phang2}{cmd:. cge_bound, clear}{p_end}

{phang2}{cmd:. cge_equation, clear}{p_end}



{title:Stored results}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(N_candidates)}}bounds and constraints of the scenario{p_end}
{synopt:{cmd:r(N_iis)}}bounds and constraints in the set (0 if the scenario solves){p_end}
{synopt:{cmd:r(N_solves)}}solves of the search{p_end}
{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(iis)}}the bounds and constraints of the set{p_end}


{title:Reference}

{phang}
Chinneck, J. W., and E. W. Dravnieks. 1991. Locating minimal infeasible
constraint sets in linear programs. {it:ORSA Journal on Computing} 3(2):
157-168.{p_end}

{title:Also see}

{psee}
{helpb cge_bound}, {helpb cge_constraint}, {helpb cge_listing}, {helpb cge_structure}, {helpb cge_solve}, {helpb cge}
{p_end}
