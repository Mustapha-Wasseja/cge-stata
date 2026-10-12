{smcl}
{* *! version 0.1.0  12oct2026}{...}
{title:Title}

{p2colset 5 18 20 2}{...}
{p2col:{bf:cge_solve} {hline 2}}Solve the model{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_solve} [{cmd:,} {opt name(name)} {opt tol:erance(#)} {opt iter:ate(#)} {opt trace}]


{title:Description}

{pstd}
{cmd:cge_solve} solves the model under the current closure and shocks, starting
from the base, and stores the solution as a named simulation for
{helpb cge_results} and {helpb cge_check}. Solving again under an existing name
replaces that simulation.

{pstd}
The solver is Newton-Raphson with a numerical Jacobian and a backtracking line
search, applied to variables and equations scaled by their base values. If it
fails, Powell's hybrid method ({cmd:solvenl()}) is tried, followed by Newton
steps to polish the result. {cmd:cge_solve} exits with error 430 if the model
does not converge.


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


{title:Stored results}

{synoptset 18 tabbed}{...}
{p2col 5 18 22 2: Scalars}{p_end}
{synopt:{cmd:r(converged)}}1 if converged, 0 otherwise{p_end}
{synopt:{cmd:r(iterations)}}number of iterations{p_end}
{synopt:{cmd:r(max_residual)}}largest scaled residual{p_end}
{synopt:{cmd:r(walras)}}value of the WALRAS slack variable{p_end}
{p2col 5 18 22 2: Macros}{p_end}
{synopt:{cmd:r(name)}}simulation name{p_end}
{synopt:{cmd:r(method)}}solution method{p_end}
{synopt:{cmd:r(closure)}}closure{p_end}


{title:Also see}

{psee}
{helpb cge}, {helpb cge_shock}, {helpb cge_results}, {helpb cge_check}
{p_end}
