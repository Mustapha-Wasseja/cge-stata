{smcl}
{* *! version 0.40.0  30oct2026}{...}
{title:Title}

{p2colset 5 21 23 2}{...}
{p2col:{bf:cge_variable} {hline 2}}User variables, defined by an expression or determined by user equations{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_variable} {it:name}[{cmd:(}{it:i}[{cmd:,}{it:j}]{cmd:)}[{cmd:$(}{it:condition}{cmd:)}]] {cmd:=} {it:expression} [{cmd:,} {opt nominal} {opt lower(#)} {opt upper(#)} {opt add(block)}]

{p 8 12 2}
{cmd:cge_variable} {it:name}[{cmd:(}{it:i}[{cmd:,}{it:j}]{cmd:)}[{cmd:$(}{it:condition}{cmd:)}]]{cmd:,} {opt value(expression)} [{opt fixed} {opt nominal} {opt add(block)}]

{p 8 12 2}
{cmd:cge_variable} {it:name}[...]{cmd:,} {opt lower(#)}|{opt upper(#)} [{opt nominal}]


{title:Description}

{pstd}
{cmd:cge_variable} (from version 0.6.1) adds a variable to the calibrated
model: with an expression, the variable and the equation that defines it;
with {opt value()}, a free variable that user equations determine. See
{helpb cge_equation} for the expressions, the options and examples. The
index may be that of a user set ({helpb cge_set}), and expressions may use
user parameters ({helpb cge_parameter}). From version 0.7.2, a condition,
{it:name}{cmd:(}{it:i}{cmd:)$(}{it:condition}{cmd:)}, defines the variable
only for the elements that meet it; see {it:Conditions} in
{helpb cge_equation}. From version 0.9.1, a variable may have two indexes,
{it:name}{cmd:(}{it:i}{cmd:,}{it:j}{cmd:)}, as in {cmd:X(c,h)}, and from
version 0.25.0 three or more, as in {cmd:X(i,j,k)}; see
{it:Two indexes and sets of pairs} in {helpb cge_equation}. From version
0.9.2, an expression may use the values of earlier periods of a dynamic run,
{cmd:lag(}{it:VAR}{cmd:)}, and from version 0.10.2 those of later periods of a
run with perfect foresight, {cmd:lead(}{it:VAR}{cmd:)}, and the period,
{cmd:tperiod}, {cmd:tfirst} and {cmd:tlast}; see {it:Lags} in
{helpb cge_equation}.

{pstd}
From version 0.13.0, {opt value()} takes an expression, which gives the base
value of each element as a definition does, with the indexes written out:
{cmd:value(sam(f, a))} starts {cmd:QF(f,a)} at the SAM's flows. It is the
starting level of a variable in a standalone model ({helpb cge_model}).

{pstd}
From version 0.9.0, {opt lower(#)} and {opt upper(#)} hold a defined variable
within bounds; {opt fixed} makes a variable given a value exogenous, as in the
closure, and {opt lower(#)} or {opt upper(#)} without a definition makes it
exogenous at that bound, from which an inequality paired with it may move it.
See {it:Inequalities} in {helpb cge_equation}.

{pstd}
From version 0.40.0, {opt add(block)} adds the variable to the right side of
the elements of a built-in equation block, named as in Section 5 of the
model's specification: a term in the model's own equations, as a GAMS
modeller would write one, while their own formula stays. A variable with an
index is added to the elements of the block with the labels of its own, and
one without, to the block without an index or the element given, as for
{opt replace()} of {helpb cge_equation}: {opt add(I8)}, government revenue;
{opt add(S2(com_man))}, market clearing for manufactures; {opt add(I7)} for
{cmd:WG(c)}, government purchases of each commodity. Unlike {opt replace()},
{opt add()} takes the blocks with derivatives of their own, such as
government revenue {cmd:I8} and market clearing {cmd:S2}, but not the
constraints or the user equations. Several variables may be added to one
element. The system stays square: a defined variable brings its own
equation, and an exogenous one ({opt fixed}) is shocked with
{helpb cge_shock}. A definition that the reduced system leaves out, such as
the import price {cmd:P1}, is kept in the system when something is added to
it. A term that is not zero at the base acts as a shock from the base.
{helpb cge_gams} writes the terms into the GAMS model. For example, a tax on
the absorption of manufactures paid to the government:

{phang2}{cmd:. cge_parameter ttx = 0}{p_end}

{phang2}{cmd:. cge_variable TX = ttx * PQ(com_man) * QQ(com_man), add(I8)}{p_end}

{phang2}{cmd:. cge_shock ttx, value(0.05)}{p_end}

{pstd}
A variable added with {opt value()} needs an equation added with
{helpb cge_equation}, or {helpb cge_solve} stops with error 459: the system
would not be square. Simulations stored before a variable is added keep its
base value until they are solved again.


{title:Also see}

{psee}
{helpb cge_equation}, {helpb cge_closure}, {helpb cge}
{p_end}
