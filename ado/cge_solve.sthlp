{smcl}
{* *! version 0.7.1  22oct2026}{...}
{title:Title}

{p2colset 5 18 20 2}{...}
{p2col:{bf:cge_solve} {hline 2}}Solve the model{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_solve} [{cmd:,} {opt name(name)} {opt tol:erance(#)} {opt iter:ate(#)} {opt step:s(#)} {opt trace}
{opt diag:nose} {opt full}]


{title:Description}

{pstd}
{cmd:cge_solve} solves the model under the current closure and shocks, starting
from the base, and stores the solution as a named simulation for
{helpb cge_results} and {helpb cge_check}. Solving again under an existing name
replaces that simulation.

{pstd}
The solver is Newton-Raphson with a backtracking line search, applied to
variables and equations scaled by their base values. From version 0.2.0 it
works on a reduced system. Explicit definitions are left out of the Newton
system and their variables computed directly from the others:
intermediate demand, household demand, import and export prices, the price of
intermediate input, output by commodity, margin demand, the purchases of the
health insurance fund, factor efficiency and days worked. Their equations still hold
exactly. Intermediate and household demand grow with the square of the number
of sectors, so the reduced system is much smaller for large SAMs: for a SAM
with 250 activities and 20 households, 4,254 of 40,190 equations.

{pstd}
From version 0.7.0 the Jacobian is exact: the derivatives of every equation of
the model are written out, user equations ({helpb cge_equation}) are
differentiated in forward mode, and in the reduced system the variables of
the left-out definitions are eliminated by the chain rule. After each Newton
step, further steps use the LU factors of that Jacobian with Broyden's
updates, with a short line search; a new Jacobian is computed when such a
step fails or reduces the residual little. Once the tolerance is met, up to three more such steps
bring the residual toward a thousandth of the tolerance. If Newton fails, it
is tried again with a Jacobian from central differences, then Powell's hybrid
method ({cmd:solvenl()}), followed by Newton steps to polish the result.
{cmd:cge_solve} exits with error 430 if the
model does not converge, and with error 459 if the system is not square, for
example after a variable added with {cmd:cge_variable, value()} without the
equation that determines it.

{pstd}
With constraints ({helpb cge_constraint}, from version 0.4.4), the
complementarity conditions are first solved in a smoothed form, which finds
whether each constraint binds; the model is then solved again with the exact
conditions, changing the regime of any constraint whose other condition
fails. The regimes are displayed and stored with the simulation.

{pstd}
A solution of the equations need not make economic sense. From version
0.7.0, after a solve that converges, {cmd:cge_solve} notes any quantity,
price, income or scaling factor of demand that is negative or below one
millionth of its positive base value, such as negative investment after a
shock far outside the range of the base, and stores their number in
{cmd:r(N_collapsed)}.

{pstd}
From version 0.4.5, a solve that fails is tried again by continuation: the
shock is applied in 4 equal steps, then 16, each solution the start of the
next, with parameters and fixed values moving in proportion from the base.
After a failure, diagnostics are displayed: the equations with the largest
residuals, by block and element; equations with no free variable and free
variables in no equation; and the smallest pivot of the Jacobian, relative
to the largest, with the variable it belongs to.


{title:Options}

{phang}
{opt name(name)} names the simulation; the default is {cmd:sim}{it:#}.

{phang}
{opt tolerance(#)} sets the convergence tolerance on the largest scaled
residual; the default is 1e-10.

{phang}
{opt iterate(#)} sets the maximum number of Newton iterations; the default is
100.

{phang}
{opt trace} displays the largest scaled residual at each iteration.

{phang}
{opt full} solves the full system, with every equation, instead of the
reduced one. Both give the same solution; {opt full} is for checks.

{phang}
{opt steps(#)} applies the shock in {it:#} equal steps. The default, 0,
does so only after a direct solve fails; {cmd:steps(1)} never does.

{phang}
{opt diagnose} displays the diagnostics after a solve that converges too.
{helpb cge_listing} lists every equation element at the solution, or where a
solve stopped (from version 0.9.5).


{title:Stored results}

{synoptset 18 tabbed}{...}
{p2col 5 18 22 2: Scalars}{p_end}
{synopt:{cmd:r(converged)}}1 if converged, 0 otherwise{p_end}
{synopt:{cmd:r(iterations)}}number of iterations{p_end}
{synopt:{cmd:r(max_residual)}}largest scaled residual, over every equation{p_end}
{synopt:{cmd:r(N_solved)}}number of equations in the system solved{p_end}
{synopt:{cmd:r(jacobians)}}number of Jacobians computed{p_end}
{synopt:{cmd:r(broyden)}}number of steps with Broyden's updates{p_end}
{synopt:{cmd:r(N_collapsed)}}number of values of a solution that are negative or below one millionth of their base value{p_end}
{synopt:{cmd:r(walras)}}value of the WALRAS slack variable{p_end}
{synopt:{cmd:r(steps)}}steps of continuation (0 for a direct solve){p_end}
{synopt:{cmd:r(N_constraints)}}number of constraints, if any{p_end}
{synopt:{cmd:r(N_binding)}}number of constraints that bind{p_end}
{p2col 5 18 22 2: Macros}{p_end}
{synopt:{cmd:r(name)}}simulation name{p_end}
{synopt:{cmd:r(method)}}solution method{p_end}
{synopt:{cmd:r(closure)}}closure{p_end}
{synopt:{cmd:r(constraints)}}the constraints and their regimes, if any{p_end}
{p2col 5 18 22 2: Diagnostics}{p_end}
{synopt:{cmd:r(diag_block)}}block of the largest residual, and {cmd:r(diag_element)} its element{p_end}
{synopt:{cmd:r(diag_residual)}}that residual{p_end}
{synopt:{cmd:r(diag_N_empty_rows)}}equations with no free variable{p_end}
{synopt:{cmd:r(diag_N_empty_cols)}}free variables in no equation{p_end}
{synopt:{cmd:r(diag_pivot_ratio)}}smallest pivot of the Jacobian relative to the largest{p_end}
{synopt:{cmd:r(diag_singular)}}1 if the Jacobian is singular or nearly so{p_end}


{title:Also see}

{psee}
{helpb cge}, {helpb cge_shock}, {helpb cge_constraint}, {helpb cge_results}, {helpb cge_check}
{p_end}
