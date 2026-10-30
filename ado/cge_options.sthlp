{smcl}
{* *! version 0.43.0  30oct2026}{...}
{title:Title}

{p2colset 5 20 22 2}{...}
{p2col:{bf:cge_options} {hline 2}}Settings of the solver{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_options} [{cmd:,} {opt lin:solver(dense|sparse|auto|python)} {opt mcp(semismooth|activeset)}
{opt jac:obian(exact|differences)} {opt hes:sian(exact|differences)} {opt sca:ling(none|ruiz)}
{opt cond:itions(base|solve)} {opt tol:erance(#)} {opt iter:ate(#)} {opt time:limit(#)} {opt reset}]


{title:Description}

{pstd}
{cmd:cge_options} (from version 0.10.1; Reference Manual, {it:cge_options})
sets how the model is solved, as GAMS's {cmd:option} statement chooses a
solver; without options it displays the settings. They are saved with the
model and apply to every solve: {helpb cge_solve}, {helpb cge_dynamic},
{helpb cge_sensitivity}, {helpb cge_optimize} and {helpb cge_loop}.

{pstd}
{opt linsolver()} chooses the linear solver of Newton's steps, which solves
the system of the Jacobian at each step:

{p2colset 9 20 22 2}{...}
{p2col:{cmd:dense}}the dense LU factorisation of Mata, the default{p_end}
{p2col:{cmd:sparse}}a sparse LU factorisation{p_end}
{p2col:{cmd:auto}}the sparse LU for systems of 1,000 equations or more{p_end}
{p2col:{cmd:python}}SciPy's SuperLU through Python (from version 0.27.0), Stata 16 and later only{p_end}
{p2colreset}{...}

{pstd}
The sparse LU chooses a pivot order once, by Markowitz's rule with
threshold pivoting, and factorises each later Jacobian in that order; rows
with many entries, such as the sums of government revenue and the balances,
form a small dense block. Its memory grows with the number of entries rather
than with the square of the number of equations, so that it solves systems
far larger than the dense LU can hold, the full system of large models among
them; the order is kept for later solves of the same model. Both give the
same solution, to the solver's tolerance. {helpb cge_solve} takes
{opt sparse} or {opt dense} for one solve.

{pstd}
{cmd:linsolver(python)} (from version 0.27.0) is an experimental prototype:
SciPy's SuperLU factorises the Jacobians in the sparse LU's place, through
Stata's Python integration ({helpb python}) and the module
{cmd:cge_scipy.py}, installed with the package. {bf:Caution:} it works only
on Stata 16 and later with Python and SciPy; Stata 13 to 15 stop with an
error, and a model saved with it falls back to the sparse LU with a note.
It solves the largest models 2 to 2.5 times faster and is slower below
about 100 activities, where the calls to Python cost more than they save.


{pstd}
{opt mcp()} (from version 0.14.0) chooses the method for the constraints of
{helpb cge_constraint} and the inequalities of {helpb cge_equation}:
{cmd:semismooth}, the default, writes every constraint in Fischer-Burmeister
form and solves them at once with the rest of the model by the semismooth
Newton method of De Luca, Facchinei and Kanzow, with a non-monotone line
search, then polishes the solution in the regimes it finds; {cmd:activeset}
is the method of earlier versions, the smoothed conditions and then the
model solved in their regimes, a constraint whose other condition fails
changing regime. The active-set method also follows a failure of the
semismooth one.

{pstd}
{opt jacobian()} (from version 0.16.0) chooses the Jacobian of Newton's
method: {cmd:exact}, the exact derivatives with Broyden's updates (the
default), or {cmd:differences}, central differences over groups of columns
at each step. Both give the same solution.

{pstd}
{opt hessian()} (from version 0.28.0) chooses the Hessian of the Lagrangian
of nonlinear programmes ({helpb cge_solve} with {opt minimize()} or
{opt maximize()}): {cmd:exact}, from the second derivatives of the
objective and the equations (the default), or {cmd:differences}, central
differences of their exact first derivatives. Both take the same
iterations to the same solution; exact Hessians are much faster on larger
programmes.

{pstd}
{opt scaling()} (from version 0.33.0) chooses the scaling of the linear
systems of Newton's method and of the semismooth method, beyond the scales
of the variables and equations from the base: {cmd:none} (the default) or
{cmd:ruiz}, Ruiz's equilibration of each Jacobian, which divides its rows
and columns until their norms are close to 1, factorises the scaled matrix
and undoes the scales in each solve. The Newton step is the same in exact
arithmetic; the pivots and rounding are those of a better conditioned
matrix, which can help models whose base scales are poor, as variables with
a zero base that grow large. It applies with the dense and the sparse LU,
to runs with foresight and to linked regions (the first region's setting).

{pstd}
{opt conditions()} (from version 0.43.0) chooses when the conditions
({cmd:$}) of user variables and equations ({helpb cge_equation}) are
evaluated: {cmd:base} (the default), once, at the base, so that every
simulation has the terms and elements of the base; or {cmd:solve}, at the
parameters of each solve, as GAMS evaluates them when a {cmd:solve}
statement generates the model. A shock to a parameter that a condition uses
then brings elements of user variables and equations into their domains, or
takes them out, and terms into sums and conditional terms, at the next
{helpb cge_solve} and in each scenario of {helpb cge_loop}; the solves of
{helpb cge_sensitivity} and {helpb cge_nash} are those of {cmd:cge_solve}.
An element that comes into its domain starts from its definition, or its
{opt value()}, at the base; one that leaves it is 0. Conditions on variables
use their base levels. Under {cmd:solve}, a variable or equation whose
domain no element meets at the base is allowed: define it after
{cmd:cge_options, conditions(solve)}. {helpb cge_optimize} and
{helpb cge_dynamic} evaluate the conditions at the base.
{helpb cge_results}, {helpb cge_listing} and {helpb cge_gams} take each
simulation with the elements it was solved with, and {helpb cge_report} the
elements of every simulation it reports.
Back to {cmd:base}, the model takes the structure of the base again. In a
model from a SAM, the conditions are those of the user definitions; the
built-in equations keep the flows of the SAM, where a zero flow calibrates
to a zero share that no condition can switch on.

{pstd}
{opt tolerance(#)}, {opt iterate(#)} and {opt timelimit(#)} (from version
0.16.0) set the tolerance, iteration limit and time limit in seconds of
{helpb cge_solve} when it is not given them, as GAMS's {cmd:option iterlim}
and {cmd:reslim} apply to every later solve; the defaults are 1e-10, 100 and
none. A solve that reaches its iteration limit or time limit stops there,
without the fallbacks and continuation that follow other failures, and
reports GAMS's solver status 2 (iteration interrupt) or 3 (resource
interrupt) with model status 6 (intermediate infeasible). {opt reset}
restores every setting to its default.


{title:Examples}

{phang2}{cmd:. cge_options, linsolver(sparse)}{p_end}

{phang2}{cmd:. cge_solve, name(large)}{p_end}

{phang2}{cmd:. cge_options}{p_end}

{phang2}{cmd:. cge_options, mcp(activeset)}{p_end}

{phang2}{cmd:. cge_options, mcp(semismooth)}{p_end}

{phang2}{cmd:. cge_options, iterate(30) timelimit(60) tolerance(1e-12)}{p_end}

{phang2}{cmd:. cge_options, scaling(ruiz)}{p_end}

{phang2}{cmd:. cge_options, conditions(solve)}{p_end}

{phang2}{cmd:. cge_options, reset}{p_end}


{title:Stored results}

{pstd}
{cmd:cge_options} stores {cmd:r(linsolver)}, the linear solver ({cmd:python} for SuperLU), {cmd:r(mcp)},
the method for constraints, {cmd:r(jacobian)}, the Jacobian, {cmd:r(hessian)}, the Hessian, and
{cmd:r(scaling)}, the scaling, and {cmd:r(conditions)}, when conditions are evaluated (from version 0.43.0), as macros, and
{cmd:r(tolerance)}, {cmd:r(iterate)} and {cmd:r(timelimit)} (missing for none),
the defaults of {helpb cge_solve}, as scalars.


{title:Also see}

{psee}
{helpb cge_solve}, {helpb cge}
{p_end}
