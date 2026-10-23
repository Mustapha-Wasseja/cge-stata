{smcl}
{* *! version 0.9.5  23oct2026}{...}
{title:Title}

{p2colset 5 20 22 2}{...}
{p2col:{bf:cge_listing} {hline 2}}Equation listing and infeasibility report{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_listing} [{cmd:,} {opt sim(name)} {opt base} {opt cur:rent} {opt block:s(list)} {opt all}
{opt top(#)} {opt tol:erance(#)} {opt clear}]


{title:Description}

{pstd}
{cmd:cge_listing} (from version 0.9.5; Reference Manual, {it:cge_listing})
lists the equations of the model at a point, as the equation listing and the
infeasibility report of a GAMS run do. For every block of equations
({cmd:P1} import price, {cmd:T2} export supply, {cmd:S2} commodity market,
and so on, as in Section 5 of the specification, and {cmd:U} for the user
equations) it shows the elements in the system, the largest scaled
residual and where it occurs, and the number of elements whose scaled
residual exceeds the tolerance, which are infeasible there. It then lists
the infeasible elements, largest first, with their left and right sides.
Elements replaced by user equations ({helpb cge_equation}, {opt replace()})
are counted apart.

{pstd}
The point is a stored simulation, {opt sim(name)}, by default the last one
stored; the base, {opt base}; or the current point, {opt current}: the
base values with the current shocks and fixed values, from which the next
{helpb cge_solve} starts, so that the listing shows which equations a shock
moves away from the base. After a solve that does not converge, the listing
of its simulation shows where the system is furthest from a solution.


{title:Options}

{phang}
{opt sim(name)}, {opt base} and {opt current} choose the point; give at most
one. The default is the last simulation stored, or the base if there is
none.

{phang}
{opt blocks(list)} lists every element of the blocks named, such as
{cmd:blocks(P1 I8)}, with its left side, right side and scaled residual;
{opt all} lists every block.

{phang}
{opt top(#)} sets how many infeasible elements are listed; the default is 20.

{phang}
{opt tolerance(#)} sets the scaled residual above which an element is
infeasible; the default is 1e-8, the tolerance of the solution check of
{helpb cge_check}.

{phang}
{opt clear} replaces the data in memory with one observation per element of
the model's equations: {cmd:block}, {cmd:element}, {cmd:description},
{cmd:lhs}, {cmd:rhs}, {cmd:residual} (left less right side), {cmd:scaled},
and the indicators {cmd:insystem}, {cmd:replaced} and {cmd:infeasible}.


{title:Remarks}

{pstd}
The scaled residual of an element is its residual divided by the larger of
its two sides at the base, or by 1 where both are near zero, as in
{helpb cge_solve}. An
element with two indexes is labelled by both, as {cmd:lab,act_agr}.


{title:Examples}

{pstd}Setup: the SYNTHETIC SAM, mapped and calibrated{p_end}
{phang2}{cmd:. cge_synthetic, clear}{p_end}
{phang2}{cmd:. cge_sam, labels(account)}{p_end}
{phang2}{cmd:. cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) factors(lab cap) households(hhd) government(gov) savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)}{p_end}
{phang2}{cmd:. cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)}{p_end}

{pstd}At the base, every equation holds{p_end}
{phang2}{cmd:. cge_listing, base}{p_end}

{pstd}Tariffs removed, before the model is solved: the equations the shock moves, and every element of the import prices and of government revenue{p_end}
{phang2}{cmd:. cge_shock tm, value(0)}{p_end}
{phang2}{cmd:. cge_listing, current blocks(P1 I8)}{p_end}

{pstd}The solution, and every element as a dataset{p_end}
{phang2}{cmd:. cge_solve, name(notariff)}{p_end}
{phang2}{cmd:. cge_listing, sim(notariff) clear}{p_end}
{phang2}{cmd:. list if block == "T2", noobs}{p_end}


{title:Stored results}

{synoptset 18 tabbed}{...}
{p2col 5 18 22 2: Scalars}{p_end}
{synopt:{cmd:r(N_equations)}}elements in the system{p_end}
{synopt:{cmd:r(N_replaced)}}elements replaced by user equations{p_end}
{synopt:{cmd:r(N_infeasible)}}elements in the system above the tolerance{p_end}
{synopt:{cmd:r(N_listed)}}elements listed by {opt blocks()} or {opt all}{p_end}
{synopt:{cmd:r(max_residual)}}the largest scaled residual in the system{p_end}
{synopt:{cmd:r(tolerance)}}the tolerance{p_end}
{p2col 5 18 22 2: Macros}{p_end}
{synopt:{cmd:r(block)}}the block of the largest scaled residual{p_end}
{synopt:{cmd:r(element)}}its element{p_end}
{synopt:{cmd:r(point)}}the point listed{p_end}


{title:Also see}

{psee}
{helpb cge_solve}, {helpb cge_check}, {helpb cge_equation}, {helpb cge}
{p_end}
