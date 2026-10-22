{smcl}
{* *! version 0.6.4  22oct2026}{...}
{title:Title}

{p2colset 5 21 23 2}{...}
{p2col:{bf:cge_variable} {hline 2}}User variables, defined by an expression or determined by user equations{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_variable} {it:name}[{cmd:(}{it:i}{cmd:)}] {cmd:=} {it:expression} [{cmd:,} {opt nominal}]

{p 8 12 2}
{cmd:cge_variable} {it:name}[{cmd:(}{it:i}{cmd:)}]{cmd:,} {opt value(#)} [{opt nominal}]


{title:Description}

{pstd}
{cmd:cge_variable} (from version 0.6.1) adds a variable to the calibrated
model: with an expression, the variable and the equation that defines it;
with {opt value()}, a free variable that user equations determine. See
{helpb cge_equation} for the expressions, the options and examples.

{pstd}
A variable added with {opt value()} needs an equation added with
{helpb cge_equation}, or {helpb cge_solve} stops with error 459: the system
would not be square. Simulations stored before a variable is added keep its
base value until they are solved again.


{title:Also see}

{psee}
{helpb cge_equation}, {helpb cge_closure}, {helpb cge}
{p_end}
