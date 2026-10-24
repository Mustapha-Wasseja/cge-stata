{smcl}
{* *! version 0.13.0  24oct2026}{...}
{title:Title}

{p2colset 5 18 20 2}{...}
{p2col:{bf:cge_model} {hline 2}}A standalone model, written whole in the user language; model statistics{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_model new}

{p 8 12 2}
{cmd:cge_model} {cmdab:d:escribe}


{title:Description}

{pstd}
{cmd:cge_model new} (from version 0.13.0; Reference Manual, {it:cge_model})
starts a standalone model in place of the model in memory: a model written
whole in the language of {helpb cge_variable} and {helpb cge_equation},
without a SAM or the built-in equations, as a GAMS program is. Its sets are
declared with {helpb cge_set}, with labels of their own or from the data in
memory; its parameters with {helpb cge_parameter}, as numbers, data or
assignments, which calibrate the model; its variables with
{helpb cge_variable}, at starting levels given by expressions, fixed where
they are exogenous; and its equations with {helpb cge_equation}, inequalities
paired with variables included. {helpb cge_solve} then solves it, from the
starting levels, by Newton's method with the exact Jacobian.

{pstd}
The commands that work on any model work on a standalone model:
{helpb cge_macro}, {helpb cge_bound}, {helpb cge_shock} (of user parameters
and fixed variables), {helpb cge_closure} (with {opt swap()} only),
{helpb cge_solve}, {helpb cge_options}, {helpb cge_results},
{helpb cge_listing}, {helpb cge_parameters}, {helpb cge_loop} and
{helpb cge_optimize} (with expressions as objectives and targets),
{helpb cge_save} and {helpb cge_use}, {helpb cge_gdx} and {helpb cge_gams},
which writes the model as a GAMS program of its own. The commands that need
a SAM and the built-in equations, such as {helpb cge_calibrate},
{helpb cge_report} and {helpb cge_dynamic}, stop with an error.

{pstd}
In a standalone model the letters {cmd:a c f h d i n} are not the indexes of
model sets: sets may take any names, and the index of a set with a digit
after it, such as {cmd:i2}, runs over the same set, as an alias. An
assignment gives a parameter its values once, as in GAMS: a parameter
computed from another does not follow later shocks to it, which belong in
the equations.

{pstd}
{cmd:cge_model describe} displays the statistics of the model in memory,
standalone or from a SAM, as GAMS's model statistics: the blocks and single
equations and variables, the fixed and free variables, the non-zero entries
of the Jacobian at the current point, and whether the system is square.


{title:Examples}

{pstd}An exchange economy of two goods and two consumers{p_end}
{phang2}{cmd:. cge_model new}{p_end}
{phang2}{cmd:. cge_set g = g1 g2}{p_end}
{phang2}{cmd:. cge_set h = h1 h2}{p_end}
{phang2}{cmd:. cge_parameter alpha(h,g), values(h1.g1:0.3 h1.g2:0.7 h2.g1:0.6 h2.g2:0.4)}{p_end}
{phang2}{cmd:. cge_parameter e(h,g), values(h1.g1:10 h1.g2:2 h2.g1:3 h2.g2:8)}{p_end}
{phang2}{cmd:. cge_variable P(g), value(1)}{p_end}
{phang2}{cmd:. cge_variable Y(h) = sum(g, P(g) * e(h,g))}{p_end}
{phang2}{cmd:. cge_variable X(h,g) = alpha(h,g) * Y(h) / P(g)}{p_end}
{phang2}{cmd:. cge_variable WALRAS, value(0)}{p_end}
{phang2}{cmd:. cge_equation NUM: P(g1) = 1}{p_end}
{phang2}{cmd:. cge_equation MKT(g): sum(h, X(h,g)) = sum(h, e(h,g)) + WALRAS}{p_end}
{phang2}{cmd:. cge_model describe}{p_end}
{phang2}{cmd:. cge_solve, name(eq)}{p_end}
{phang2}{cmd:. cge_results, sim(eq)}{p_end}

{pstd}
The standard model of the package, written in the user language from the
synthetic SAM, is the example {cmd:examples/standard_model.do} of the package
repository.


{title:Stored results}

{pstd}
{cmd:cge_model new} stores {cmd:r(standalone)}, 1. {cmd:cge_model describe}
stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(standalone)}}1 for a standalone model, 0 for a model from a SAM{p_end}
{synopt:{cmd:r(N_eq_blocks)}}blocks of equations{p_end}
{synopt:{cmd:r(N_equations)}}single equations{p_end}
{synopt:{cmd:r(N_var_blocks)}}blocks of variables{p_end}
{synopt:{cmd:r(N_variables)}}single variables{p_end}
{synopt:{cmd:r(N_fixed)}}fixed variables{p_end}
{synopt:{cmd:r(N_free)}}free variables{p_end}
{synopt:{cmd:r(N_nonzeros)}}non-zero entries of the Jacobian at the current point{p_end}
{synopt:{cmd:r(N_sets)}}user sets{p_end}
{synopt:{cmd:r(N_parameters)}}user parameters{p_end}
{synopt:{cmd:r(N_constraints)}}constraints{p_end}
{synopt:{cmd:r(square)}}1 if the system is square{p_end}
{synopt:{cmd:r(N_reduced)}}equations of the reduced system (a model from a SAM){p_end}
{p2colreset}{...}


{title:Also see}

{psee}
{helpb cge_set}, {helpb cge_parameter}, {helpb cge_variable}, {helpb cge_equation}, {helpb cge_solve},
{helpb cge_gams}, {helpb cge}
{p_end}
