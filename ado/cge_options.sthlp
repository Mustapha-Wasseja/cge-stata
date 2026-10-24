{smcl}
{* *! version 0.14.0  24oct2026}{...}
{title:Title}

{p2colset 5 20 22 2}{...}
{p2col:{bf:cge_options} {hline 2}}Settings of the solver{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_options} [{cmd:,} {opt lin:solver(dense|sparse|auto)} {opt mcp(semismooth|activeset)}]


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


{title:Examples}

{phang2}{cmd:. cge_options, linsolver(sparse)}{p_end}
{phang2}{cmd:. cge_solve, name(large)}{p_end}
{phang2}{cmd:. cge_options}{p_end}
{phang2}{cmd:. cge_options, mcp(activeset)}{p_end}
{phang2}{cmd:. cge_options, mcp(semismooth)}{p_end}


{title:Stored results}

{pstd}
{cmd:cge_options} stores {cmd:r(linsolver)}, the linear solver, and {cmd:r(mcp)}, the method for constraints.


{title:Also see}

{psee}
{helpb cge_solve}, {helpb cge}
{p_end}
