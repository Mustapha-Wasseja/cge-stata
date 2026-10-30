{smcl}
{* *! version 0.42.0  30oct2026}{...}
{title:Title}

{p2colset 5 18 20 2}{...}
{p2col:{bf:cge_solve} {hline 2}}Solve the model{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_solve} [{cmd:,} {opt name(name)} {opt tol:erance(#)} {opt iter:ate(#)} {opt time:limit(#)} {opt step:s(#)} {opt trace}
{opt diag:nose} {opt full} {opt sp:arse} {opt den:se} {opt min:imize(expression)} {opt max:imize(expression)}
{opt mod:el(name)} {opt from(sim)} {opt hold(varlist)} {opt nod:es(#)} {opt optcr(#)} {opt starts(#)} {opt sol:ver(name)}
{opt block:s}]


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
With constraints or inequalities, from version 0.14.0, the semismooth Newton
method of {helpb cge_options} solves them with the rest of the model, and
{cmd:r(method)} is {cmd:semismooth}.
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
From version 0.15.0, with {opt minimize()} or {opt maximize()}, {cmd:cge_solve}
solves a standalone model ({helpb cge_model}) as a nonlinear programme: it
chooses the free variables to minimise or maximise an expression subject to
the model's equations and the bounds of {helpb cge_bound}, as GAMS's
{cmd:solve} ... {cmd:using nlp minimizing} does with CONOPT or IPOPT. The
method is a primal-dual interior-point method after Waechter and Biegler
(2006), with exact derivatives of the objective and the equations, the
exact Hessian of the Lagrangian (from version 0.28.0; before, and with
{cmd:cge_options, hessian(differences)}, differences of its exact gradient), and a line
search on an l1 merit function. The solution is stored as a simulation, with
the objective in {cmd:r(objective)} and the marginals of the equations, the
change in the objective per unit increase in each right side, in
{cmd:r(marginals)}. The model must have more free variables than equations;
an inequality is written as an equation with a slack variable bounded at
zero. {helpb cge_gams} exports such a simulation as an NLP, solved with IPOPT
by default.

{pstd}
From version 0.36.0, the interior point has a feasibility restoration phase,
as IPOPT's: where it cannot find a step, its line search fails, or its step
is too short to move, at a point that does not satisfy the equations, it
minimises the norm of the scaled residuals near that point, within the
bounds, until the norm falls by a tenth, and goes on from there. Where the
infeasibility has a local minimum, the programme is locally infeasible
(model status 5), and the method stops there rather than at its iteration
limit. {cmd:r(N_restorations)} counts the restorations. The example of
Waechter and Biegler (2000), min x1 subject to x1^2 = x2 + 1, x1 = x3 + 1/2,
x2 >= 0 and x3 >= 0 from (-2, 3, 1), on which the method stalled at an
infeasible point, solves with two. {helpb cge_iis} finds the bounds and
constraints that leave a scenario without a solution.

{pstd}
From version 0.16.0, every solve reports GAMS's model status and solver
status in {cmd:r(modelstat)} and {cmd:r(solvestat)}, stores them with the
simulation and displays them after a failure. Model status 16 (solved) is a
solution of a system, 1 (optimal) one of a system with constraints, 2
(locally optimal) that of a nonlinear programme, 5 (locally infeasible) a
failure, 6 (intermediate infeasible) a solve stopped by a limit, 7 (feasible
solution) a nonlinear programme stopped at a feasible point and 13 (error, no
solution) equations that cannot be evaluated at the start; for branch and
bound (from version 0.18.0), 1 is an integer solution after a complete search,
8 (integer solution) one found before a limit stopped the search, 10 (integer
infeasible) a complete search without one and 14 (no solution returned) a
limit reached without one; for HiGHS and SCIP, 3 (unbounded) and 4
(infeasible), and for SCIP (from version 0.42.0), 1 is a global optimum.
Solver status 1 is normal completion, 2 an iteration interrupt, 3 a resource (time) interrupt,
4 termination by the solver and 5 an evaluation error.

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
residual; the default is 1e-10, or that of {helpb cge_options} (from version
0.16.0).

{phang}
{opt iterate(#)} sets the maximum number of Newton iterations; the default is
100, or that of {helpb cge_options}. From version 0.16.0, a solve that reaches
it stops there, without the fallbacks and continuation that follow other
failures.

{phang}
{opt timelimit(#)} (from version 0.16.0) sets a time limit in seconds, as
GAMS's {cmd:reslim}; by default there is none, or that of {helpb cge_options}.
The solvers check it at each iteration, to the second.

{phang}
{opt trace} displays the largest scaled residual at each iteration.

{phang}
{opt full} solves the full system, with every equation, instead of the
reduced one. Both give the same solution; {opt full} is for checks.

{phang}
{opt sparse} and {opt dense} (from version 0.10.1) choose the linear solver of
Newton's steps for this solve, the sparse or the dense LU, in place of that of
{helpb cge_options}. The sparse LU holds systems far larger than the dense one,
the full system of large models among them; both give the same solution.

{phang}
{opt steps(#)} applies the shock in {it:#} equal steps. The default, 0,
does so only after a direct solve fails; {cmd:steps(1)} never does.

{phang}
{opt minimize(expression)} and {opt maximize(expression)} (from version
0.15.0) solve a standalone model as a nonlinear programme, minimising or
maximising {it:expression}, an expression of the user language of
{helpb cge_equation}, such as
{cmd:minimize(sum((r,c), X(r,c) * ln(X(r,c) / a(r,c))))}. The tolerance
applies to the scaled conditions for an optimum. A start outside a
variable's bounds is moved within them.

{phang}
{opt model(name)} (from version 0.17.0) solves named model {it:name} of a
standalone model, defined by {helpb cge_model}, as GAMS's {cmd:solve}
{it:name}: its equations, in the free variables that appear in them, with the
other variables at their levels. Solved as a system it must be square; with
{opt minimize()} or {opt maximize()} it is a nonlinear programme over its
variables.

{phang}
{opt from(sim)} (from version 0.17.0) starts the solve of a standalone model
from the levels of stored simulation {it:sim}, as GAMS's levels carry over
from one solve to the next.

{phang}
{opt hold(varlist)} (from version 0.17.0) holds variables of a standalone
model at their levels for this solve, as GAMS's {cmd:x.fx = x.l}: whole
variables, {cmd:hold(P Q)}, or elements, {cmd:hold(P(g1))}.

{phang}
{opt nodes(#)} and {opt optcr(#)} (from version 0.18.0) set the node limit and
the relative gap of branch and bound, as GAMS's {cmd:nodlim} and {cmd:optcr}:
a nonlinear programme with integer or binary variables ({helpb cge_bound}) is
solved by branch and bound, depth first, each node's relaxation by the
interior point, branching on the most fractional variable. The defaults are
10,000 nodes and a gap of 0 (to 1e-9). Branch and bound is exact when the
relaxations are convex, as linear and convex quadratic ones are, and a
heuristic otherwise.

{phang}
{opt starts(#)} (from version 0.24.0) solves a nonlinear programme from #
points: the start and # - 1 points of the free variables drawn within their
bounds (within max(1, |x|) of the start where a bound is missing), keeping
the best solution that converges; with integer variables, every relaxation
of branch and bound. The points repeat from run to run and leave Stata's
random numbers alone. Multi-start makes a global optimum of a nonconvex
problem more likely, not certain; the default is 1.

{phang}
{opt solver(highs)} (from version 0.27.0, an experimental prototype) solves
a linear or mixed-integer linear programme with HiGHS, through SciPy and
Stata's Python integration ({helpb python}), in place of the interior point
and branch and bound. The equations and the objective must be linear
(error 459 otherwise); a linear programme returns the marginals of its
equations. {bf:Caution:} it works only on Stata 16 and later with Python and
SciPy; Stata 13 to 15 stop with an error.

{phang}
{opt solver(ipopt)} (from version 0.41.0, experimental) solves a nonlinear
programme with IPOPT (Waechter and Biegler 2006), through the Python package
{browse "https://cyipopt.readthedocs.io":cyipopt}, in place of the package's
interior point, as GAMS does with {cmd:option nlp = ipopt}. IPOPT works in the
scaled variables of the package's interior point and asks Mata for each value
it needs: the objective and its gradient, the residuals of the equations and
their sparse Jacobian, and the exact Hessian of the Lagrangian, or IPOPT's
limited-memory approximation with {cmd:cge_options, hessian(differences)}
(which may need {cmd:iterate(1000)}). {opt tolerance()}, {opt iterate()} and
{opt timelimit()} pass to IPOPT, and {opt trace} displays its output. The
marginals of the equations are in the units of the interior point's, and the
statuses follow those of GAMS's link to IPOPT: 5 for a point that is locally
infeasible, 6 or 7 for an iteration limit. It takes continuous programmes:
integer and binary variables, and {opt starts()}, stop with error 198. The
first solve of a session also loads IPOPT, which took about 7 seconds on
Windows. {bf:Caution:} it works only on Stata 16 and later with Python,
SciPy and cyipopt ({cmd:pip install cyipopt}, which needs a build of IPOPT);
without them, the option stops with error 198.

{phang}
{opt solver(scip)} (from version 0.42.0, experimental) solves a programme
with SCIP (Bolusani and others 2024), through the Python package
{browse "https://github.com/scipopt/PySCIPOpt":PySCIPOpt}, in place of the
interior point and branch and bound, as GAMS does with {cmd:option nlp = scip}
or {cmd:option minlp = scip}: nonlinear and mixed-integer programmes,
nonconvex ones included, to a global optimum within SCIP's tolerances, by
spatial branch and bound. The objective and the equations go to SCIP as
expressions, with the parameters and the fixed variables as numbers; min(),
max(), ifthen(), comparisons and {cmd:not} have no form there and stop with
error 459. SCIP's feasibility tolerance is {opt tolerance()}, within 1e-9 and
1e-6; {opt nodes()}, {opt optcr()} and {opt timelimit()} set its node limit,
relative gap and time limit, and {opt trace} displays its log when it ends.
A global optimum, or one within {opt optcr()}, has model status 1, and
{cmd:r(nodes)}, {cmd:r(bestbound)} and {cmd:r(gap)} report the search;
{cmd:r(iterations)} counts its LP iterations. Where the objective is 0 at
the optimum, a relative gap is not defined: add a constant to the objective
and set {opt optcr()}. SCIP's point is as accurate as its tolerances allow,
3e-5 from the published optimum of Hock and Schittkowski's problem 71
against 3e-7 for the interior point; solving again with the interior point,
{opt from()} the simulation of SCIP, polishes it and gives the marginals of
the equations, which SCIP does not. SCIP solves in a separate Python
process: its libraries bring a runtime of OpenMP that cannot share Stata's
process with Stata's own. Each solve starts that process, which took
about 1 second, after a first solve of about 8 seconds that also starts
Stata's Python and SciPy, on Windows. {opt starts()} stops with error 198.
{bf:Caution:} it works only on Stata 16 and later with Python, SciPy and
PySCIPOpt ({cmd:pip install pyscipopt}, whose wheels include SCIP); without
them, the option stops with error 198.

{phang}
{opt blocks} (from version 0.35.0) solves a standalone model ({helpb cge_model})
block by block: the blocks of its square part that {helpb cge_structure}
finds, in an order in which each depends only on itself and on those before
it, each by Newton's method on its own equations and variables, each
equation evaluated and differentiated alone. The whole system is then
checked, and polished by Newton's method if it is not within the tolerance.
The solution is that of the whole system; a recursive model is solved one
equation at a time. A structurally singular system stops with error 459, and
{helpb cge_structure} names its parts. It is for standalone models without
constraints or inequalities; {cmd:r(N_blocks)} and {cmd:r(largest_block)}
give the blocks.

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
{synopt:{cmd:r(modelstat)}}GAMS's model status (from version 0.16.0){p_end}
{synopt:{cmd:r(solvestat)}}GAMS's solver status{p_end}
{synopt:{cmd:r(tolerance)}}the tolerance applied{p_end}
{synopt:{cmd:r(iterate)}}the iteration limit applied{p_end}
{synopt:{cmd:r(objective)}}the objective at the optimum, for a nonlinear programme{p_end}
{synopt:{cmd:r(N_dof)}}free variables less equations, for a nonlinear programme{p_end}
{p2col 5 18 22 2: Macros}{p_end}
{synopt:{cmd:r(name)}}simulation name{p_end}
{synopt:{cmd:r(method)}}solution method ({cmd:nlp} for a nonlinear programme){p_end}
{synopt:{cmd:r(objective_expr)}}the objective of a nonlinear programme{p_end}
{synopt:{cmd:r(model)}}the named model solved, if any (from version 0.17.0){p_end}
{synopt:{cmd:r(from)}}the simulation the solve started from, if any{p_end}
{synopt:{cmd:r(hold)}}the variables held, if any{p_end}
{synopt:{cmd:r(N_integer)}}integer and binary elements, for a nonlinear programme (from version 0.18.0){p_end}
{synopt:{cmd:r(nodes)}}nodes of branch and bound, or of SCIP (from version 0.42.0){p_end}
{synopt:{cmd:r(bestbound)}}its best bound{p_end}
{synopt:{cmd:r(gap)}}its relative gap{p_end}
{synopt:{cmd:r(starts)}}starts of the interior point (from version 0.24.0){p_end}
{synopt:{cmd:r(best_start)}}the start of the best solution, with starts() and no integers{p_end}
{synopt:{cmd:r(N_starts_converged)}}the starts that converged{p_end}
{synopt:{cmd:r(solver)}}{cmd:ipm}, {cmd:bb}, {cmd:highs} (from version 0.27.0), {cmd:ipopt} (from version 0.41.0) or {cmd:scip} (from version 0.42.0){p_end}
{synopt:{cmd:r(hessian)}}the Hessians of the interior point: {cmd:exact} or {cmd:differences} (from version 0.28.0){p_end}
{synopt:{cmd:r(N_hessian_exact)}}its iterations with exact Hessians{p_end}
{synopt:{cmd:r(N_hessian_differences)}}its iterations with differences{p_end}
{synopt:{cmd:r(N_restorations)}}its feasibility restorations (from version 0.36.0){p_end}
{synopt:{cmd:r(linsolver)}}the linear solver: {cmd:dense}, {cmd:sparse} or {cmd:auto} (from version 0.10.1){p_end}
{synopt:{cmd:r(closure)}}closure{p_end}
{synopt:{cmd:r(constraints)}}the constraints and their regimes, if any{p_end}
{p2col 5 18 22 2: Matrices}{p_end}
{synopt:{cmd:r(marginals)}}the marginals of the equations of a nonlinear programme{p_end}
{p2col 5 18 22 2: Diagnostics}{p_end}
{synopt:{cmd:r(diag_block)}}block of the largest residual, and {cmd:r(diag_element)} its element{p_end}
{synopt:{cmd:r(diag_residual)}}that residual{p_end}
{synopt:{cmd:r(diag_N_empty_rows)}}equations with no free variable{p_end}
{synopt:{cmd:r(diag_N_empty_cols)}}free variables in no equation{p_end}
{synopt:{cmd:r(diag_pivot_ratio)}}smallest pivot of the Jacobian relative to the largest{p_end}
{synopt:{cmd:r(diag_singular)}}1 if the Jacobian is singular or nearly so{p_end}


{title:Also see}

{psee}
{helpb cge}, {helpb cge_shock}, {helpb cge_constraint}, {helpb cge_results}, {helpb cge_check}, {helpb cge_model}, {helpb cge_optimize}
{p_end}
