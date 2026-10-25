{smcl}
{* *! version 0.13.0  24oct2026}{...}
{title:Title}

{p2colset 5 21 23 2}{...}
{p2col:{bf:cge_variable} {hline 2}}User variables, defined by an expression or determined by user equations{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_variable} {it:name}[{cmd:(}{it:i}[{cmd:,}{it:j}]{cmd:)}[{cmd:$(}{it:condition}{cmd:)}]] {cmd:=} {it:expression} [{cmd:,} {opt nominal} {opt lower(#)} {opt upper(#)}]

{p 8 12 2}
{cmd:cge_variable} {it:name}[{cmd:(}{it:i}[{cmd:,}{it:j}]{cmd:)}[{cmd:$(}{it:condition}{cmd:)}]]{cmd:,} {opt value(expression)} [{opt fixed} {opt nominal}]

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
A variable added with {opt value()} needs an equation added with
{helpb cge_equation}, or {helpb cge_solve} stops with error 459: the system
would not be square. Simulations stored before a variable is added keep its
base value until they are solved again.


{title:Also see}

{psee}
{helpb cge_equation}, {helpb cge_closure}, {helpb cge}
{p_end}
