{smcl}
{* *! version 0.9.7  24oct2026}{...}
{title:Title}

{p2colset 5 18 20 2}{...}
{p2col:{bf:cge_macro} {hline 2}}Macros of the language of user variables and equations{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_macro} {it:name}[{cmd:(}{it:a}[{cmd:,} {it:b} ...]{cmd:)}] {cmd:=} {it:expression}

{p 8 12 2}
{cmd:cge_macro} {cmd:,} {opt list}

{p 8 12 2}
{cmd:cge_macro} {cmd:,} {opt clear}


{title:Description}

{pstd}
{cmd:cge_macro} (from version 0.9.7; Reference Manual,
{it:User variables and equations}) defines a macro of the language of
{helpb cge_variable} and {helpb cge_equation}, as GAMS's {cmd:$macro} does.
In an expression, {it:name}{cmd:(}{it:x}{cmd:,} {it:y}{cmd:)} is replaced by
the macro's expression with {it:x} in place of {it:a} and {it:y} in place of
{it:b}. An argument that is more than a name or a number is put in
parentheses, so that {cmd:sq(x) = x * x} gives {cmd:(QA(a) + 1) * (QA(a) + 1)}
for {cmd:sq(QA(a) + 1)}. A macro without parameters stands for its
expression.

{pstd}
The expression may use anything an expression of a user variable may:
variables, parameters, user sets and parameters, sums, conditions, the
functions of {it:Functions and macros} in {helpb cge_equation}, and other
macros, which are replaced in turn. A macro may not use itself, directly or
through others. Its arguments may be indexes: {cmd:cesq(c)} in the domain of
a variable over {cmd:c} writes the macro out for every element.

{pstd}
Macros are replaced when a variable or equation is added, and again each time
the model is calibrated. They are saved with the model and kept when it is
calibrated again; a macro that variables or equations use stays until they
are removed. {helpb cge_gams} writes the macros out, so the GAMS program
does not need {cmd:$macro}.

{pstd}
A name must be new: not a variable, parameter, element, set, equation,
function or another macro. A parameter is a name, used once. {cmd:cge_macro, clear}
removes every macro once no user variable or equation uses one.


{title:Options}

{phang}
{opt list} displays the macros; {opt clear} removes them all.


{title:Examples}

{pstd}Setup: the SYNTHETIC SAM, mapped and calibrated{p_end}
{phang2}{cmd:. cge_synthetic, clear}{p_end}
{phang2}{cmd:. cge_sam, labels(account)}{p_end}
{phang2}{cmd:. cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) factors(lab cap) households(hhd) government(gov) savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)}{p_end}
{phang2}{cmd:. cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)}{p_end}

{pstd}A CES aggregate of two quantities, a price relative to the CPI, and a constant{p_end}
{phang2}{cmd:. cge_macro ces(x, y, d, r) = (d * x^(-r) + (1 - d) * y^(-r))^(-1 / r)}{p_end}
{phang2}{cmd:. cge_macro rel(v) = v / CPI}{p_end}
{phang2}{cmd:. cge_macro half = 0.5}{p_end}

{pstd}A macro that uses others, and variables defined with them{p_end}
{phang2}{cmd:. cge_macro cesq(c) = ces(QD(c), QM(c), half, half)}{p_end}
{phang2}{cmd:. cge_variable CQ(c)$(base(QM(c)) > 0) = cesq(c)}{p_end}
{phang2}{cmd:. cge_variable RP(c) = rel(PQ(c))}{p_end}
{phang2}{cmd:. cge_macro, list}{p_end}

{pstd}A tariff removal{p_end}
{phang2}{cmd:. cge_shock tm, value(0)}{p_end}
{phang2}{cmd:. cge_solve}{p_end}


{title:Stored results}

{synoptset 16 tabbed}{...}
{p2col 5 16 20 2: Scalars}{p_end}
{synopt:{cmd:r(N_macros)}}number of macros{p_end}
{p2col 5 16 20 2: Macros}{p_end}
{synopt:{cmd:r(name)}}name of the macro defined{p_end}


{title:Also see}

{psee}
{helpb cge_variable}, {helpb cge_equation}, {helpb cge_set}, {helpb cge_parameter}, {helpb cge}
{p_end}
