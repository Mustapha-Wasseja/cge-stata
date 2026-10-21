{smcl}
{* *! version 0.6.1  21oct2026}{...}
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


{title:Also see}

{psee}
{helpb cge_equation}, {helpb cge_closure}, {helpb cge}
{p_end}
