{smcl}
{* *! version 0.7.1  22oct2026}{...}
{title:Title}

{p2colset 5 21 23 2}{...}
{p2col:{bf:cge_equation} {hline 2}}User equations: new relations among the model's variables{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_equation} {it:name}[{cmd:(}{it:i}{cmd:)}]{cmd::} {it:expression} {cmd:=} {it:expression}

{p 8 12 2}
{cmd:cge_equation}{cmd:,} {opt list}

{p 8 12 2}
{cmd:cge_equation}{cmd:,} {opt clear}

{p 8 12 2}
{cmd:cge_variable} {it:name}[{cmd:(}{it:i}{cmd:)}] {cmd:=} {it:expression} [{cmd:,} {opt nominal}]

{p 8 12 2}
{cmd:cge_variable} {it:name}[{cmd:(}{it:i}{cmd:)}]{cmd:,} {opt value(#)} [{opt nominal}]


{title:Description}

{pstd}
{cmd:cge_variable} and {cmd:cge_equation} (from version 0.6.1;
Reference Manual, {it:User variables and equations}) add variables and equations to the calibrated
model. Stata compiles them for its solver, and {helpb cge_gams} writes them
into the GAMS program, so that GAMS solves the same model.

{pstd}
{cmd:cge_variable} {it:name} {cmd:=} {it:expression} adds a variable and the
equation that defines it; its base value is the expression at the base. Such
a variable is free: the definition determines it. Swapped into the closure
with {helpb cge_closure:cge_closure, swap()}, it fixes the expression and
frees another variable. For example, government consumption can be fixed in
nominal terms, with the volumes adjusting:

{phang2}{cmd:. cge_variable GEXP = sum(c, PQ(c) * QG(c)), nominal}{p_end}
{phang2}{cmd:. cge_closure, swap(GEXP GADJ)}{p_end}

{pstd}
{cmd:cge_variable} {it:name}{cmd:, value(}{it:#}{cmd:)} adds a free variable
with that base value and no equation; {cmd:cge_equation} then adds the
equations that determine it. Each equation needs one free variable, so that
the closure stays square.

{pstd}
With an index, {it:name}{cmd:(}{it:i}{cmd:)} is defined, or the equation
written, for every element of the set of {it:i}: {cmd:a} activities,
{cmd:c} commodities, {cmd:f} factors, {cmd:h} households, {cmd:d} households
and enterprises, {cmd:i} institutions receiving factor income, {cmd:n} nests
of value added, or a user set defined by {helpb cge_set} (from version
0.7.1), whose name is then the index. Digits may follow, as in {cmd:c2}.


{title:Expressions}

{pstd}
Expressions use numbers, {cmd:+ - * /}, {cmd:^} (power), parentheses, the
functions {cmd:exp()}, {cmd:ln()} (or {cmd:log()}) and {cmd:sqrt()}, and:

{p2colset 9 34 36 2}{...}
{p2col:{it:VAR} or {it:VAR}{cmd:(}{it:e}[{cmd:,} {it:e2}]{cmd:)}}a model or user variable, at an element such as {cmd:com_hlt} or the index of the equation or of a sum{p_end}
{p2col:{it:par}{cmd:(}{it:e}{cmd:)}}a parameter at its current value: {cmd:tm}, {cmd:te}, {cmd:tq}, {cmd:ta}, {cmd:tv}, {cmd:kappa}, {cmd:pwm}, {cmd:pwe}, {cmd:ad}, {cmd:af}, {cmd:qg}, {cmd:qinv}, {cmd:trdg}, {cmd:trdr}, {cmd:trfr}, {cmd:trgr}, {cmd:trrg}, {cmd:trgg}, {cmd:tshi}, {cmd:qshi}, {cmd:trshi}, {cmd:trshir}, {cmd:rd}, {cmd:rf}, {cmd:ddebt}, {cmd:fdebt}, {cmd:qlf}, {cmd:wmin}, {cmd:wref}, {cmd:sick}, {cmd:tfy} or {cmd:hs0}, for example {cmd:tv(c)} or {cmd:trgr}{p_end}
{p2col:{it:upar}[{cmd:(}{it:e}[{cmd:,} {it:e2}]{cmd:)}]}a user parameter defined by {helpb cge_parameter}, at its current value (from version 0.7.1){p_end}
{p2col:{cmd:base(}{it:VAR}[{cmd:(}{it:e}{cmd:)}]{cmd:)}}the base value of a variable{p_end}
{p2col:{cmd:sum(}{it:i}{cmd:,} {it:expression}{cmd:)}}the sum over the set of index {it:i}, a model set or a user set{p_end}
{p2colreset}{...}


{title:Options}

{phang}
{opt nominal} marks a user variable measured in local currency, so that the
homogeneity check of {helpb cge_check} expects it to scale with the
numeraire.

{phang}
{opt value(#)} gives the base value of a variable that equations determine.

{phang}
{opt list} lists the user variables and equations; {opt clear} removes them
all.


{title:Examples}

{pstd}Real government savings held at the base, the direct tax rate adjusting{p_end}
{phang2}{cmd:. cge_variable RGSAV = GSAV / CPI}{p_end}
{phang2}{cmd:. cge_closure, swap(RGSAV TINSADJ)}{p_end}
{phang2}{cmd:. cge_shock tm, value(0)}{p_end}
{phang2}{cmd:. cge_solve}{p_end}

{pstd}Prices relative to the consumer price index, by commodity{p_end}
{phang2}{cmd:. cge_variable PREL(c) = PQ(c) * (1 + tv(c)) / CPI}{p_end}

{pstd}Government purchases of services 10 per cent above the base, with GADJ adjusting{p_end}
{phang2}{cmd:. cge_variable LAM, value(1)}{p_end}
{phang2}{cmd:. cge_equation lam: QG(com_ser) = LAM * base(QG(com_ser))}{p_end}
{phang2}{cmd:. cge_closure, swap(LAM GADJ)}{p_end}
{phang2}{cmd:. cge_shock LAM, value(1.1)}{p_end}
{phang2}{cmd:. cge_solve}{p_end}


{title:Remarks}

{pstd}
User variables and equations are saved with the model, kept when it is
calibrated again (with base values from the new base) and solved in every
simulation, dynamic run and sensitivity draw. Their derivatives are found by
differences. Results list the user variables with the others.


{title:Stored results}

{pstd}
{cmd:cge_variable} and {cmd:cge_equation} store {cmd:r(name)} and
{cmd:r(N_elements)}; {cmd:cge_equation, list} stores {cmd:r(N_variables)} and
{cmd:r(N_equations)} (equation elements).


{title:Also see}

{psee}
{helpb cge_closure}, {helpb cge_shock}, {helpb cge_solve}, {helpb cge_gams}, {helpb cge}
{p_end}
