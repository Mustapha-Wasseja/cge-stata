{smcl}
{* *! version 0.37.0  30oct2026}{...}
{title:Title}

{p2colset 5 18 20 2}{...}
{p2col:{bf:cge_model} {hline 2}}A standalone model, written whole in the user language; model statistics; named models; roles of variables{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_model new}

{p 8 12 2}
{cmd:cge_model} {cmdab:d:escribe} [{it:model}]

{p 8 12 2}
{cmd:cge_model define} {it:model} {cmd:=} {it:list}

{p 8 12 2}
{cmd:cge_model drop} {it:model}|{cmd:_all}

{p 8 12 2}
{cmd:cge_model list}

{p 8 12 2}
{cmd:cge_model roles}{cmd:,} {opt group:s(set)} {opt good:s(set)} {opt price:s(varname)} {opt cons:umption(varname)} [{opt inc:ome(varname)}]

{p 8 12 2}
{cmd:cge_model roles} [{cmd:,} {opt list}|{opt clear}]


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
which writes the model as a GAMS program of its own, and, from version
0.37.0, {helpb cge_report}, from version 0.38.0, {helpb cge_sensitivity} and,
from version 0.39.0, {helpb cge_microsim}.
The commands that need a SAM and the built-in equations, such as
{helpb cge_calibrate} and {helpb cge_dynamic}, stop with an error.

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
With a model name, it describes that named model.

{pstd}
{cmd:cge_model define} (from version 0.17.0) names a model over a subset of
the equations of a standalone model, as GAMS's {cmd:model} statement: its
{it:list} names user equations, variables defined by an expression (their
defining equations), inequalities and models defined before, or {cmd:all},
separated by spaces or commas. A model of the same name is replaced.
{helpb cge_solve}, {opt model()}, solves it on its own: its equations, in the
free variables that appear in them, with the other variables at their
levels. {opt from()} starts a solve from the levels of a stored simulation
and {opt hold()} holds variables at their levels, as GAMS's {cmd:x.fx = x.l},
so that a model can be solved block by block. {cmd:cge_model drop} drops a
model, or all of them, and {cmd:cge_model list} lists them.

{pstd}
{cmd:cge_model roles} (from version 0.37.0) tells the commands that report
on households what the variables of a standalone model are: {opt groups()}
is the set of groups, households or any other; {opt goods()} the set of
goods they buy; {opt prices()} the variable of the prices they pay, indexed
by the goods; {opt consumption()} the variable of the quantities each group
buys of each good, indexed by the goods and the groups in either order; and
{opt income()}, optionally, that of each group's income. Groups and goods
must be user sets ({helpb cge_set}) and the variables user variables.
{helpb cge_report} then adds each group's expenditure, price indexes, real
expenditure and income, and its equivalent and compensating variations. The
roles are kept by {helpb cge_save}; {opt list} shows them and {opt clear}
removes them.


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

{pstd}A named model: incomes and demands at the equilibrium prices, with the prices held{p_end}

{phang2}{cmd:. cge_model define demand = Y X}{p_end}

{phang2}{cmd:. cge_solve, name(dem) model(demand) from(eq) hold(P)}{p_end}

{phang2}{cmd:. cge_model list}{p_end}

{pstd}
The standard model of the package, written in the user language from the
synthetic SAM, is the example {cmd:examples/standard_model.do} of the package
repository.

{pstd}The roles of a model's variables: two groups buying three goods{p_end}

{phang2}{cmd:. cge_model new}{p_end}

{phang2}{cmd:. cge_set c = g1 g2 g3}{p_end}

{phang2}{cmd:. cge_set h = h1 h2}{p_end}

{phang2}{cmd:. cge_parameter alpha(c,h), values(g1.h1:0.5 g2.h1:0.3 g3.h1:0.2 g1.h2:0.2 g2.h2:0.3 g3.h2:0.5)}{p_end}

{phang2}{cmd:. cge_parameter ybar(h), values(h1:100 h2:50)}{p_end}

{phang2}{cmd:. cge_parameter A(c) = sum(h, alpha(c,h) * ybar(h))}{p_end}

{phang2}{cmd:. cge_variable P(c), value(1)}{p_end}

{phang2}{cmd:. cge_variable Y(h) = ybar(h)}{p_end}

{phang2}{cmd:. cge_variable X(c) = A(c) * P(c)}{p_end}

{phang2}{cmd:. cge_variable Q(c,h) = alpha(c,h) * Y(h) / P(c)}{p_end}

{phang2}{cmd:. cge_equation MKT(c): sum(h, Q(c,h)) = X(c)}{p_end}

{phang2}{cmd:. cge_model roles, groups(h) goods(c) prices(P) consumption(Q) income(Y)}{p_end}

{phang2}{cmd:. cge_shock ybar, elements(h1) scale(1.1)}{p_end}

{phang2}{cmd:. cge_solve, name(richer)}{p_end}

{phang2}{cmd:. cge_report, tables(groups welfare)}{p_end}


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

{pstd}
{cmd:cge_model roles} stores {cmd:r(groups)}, {cmd:r(goods)}, {cmd:r(prices)},
{cmd:r(consumption)} and {cmd:r(income)}, empty without roles.


{title:Also see}

{psee}
{helpb cge_set}, {helpb cge_parameter}, {helpb cge_variable}, {helpb cge_equation}, {helpb cge_solve},
{helpb cge_report}, {helpb cge_gams}, {helpb cge}
{p_end}
