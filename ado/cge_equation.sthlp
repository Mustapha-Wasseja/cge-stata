{smcl}
{* *! version 0.9.1  23oct2026}{...}
{title:Title}

{p2colset 5 21 23 2}{...}
{p2col:{bf:cge_equation} {hline 2}}User equations: new relations among the model's variables{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_equation} {it:name}[{cmd:(}{it:i}[{cmd:,}{it:j}]{cmd:)}[{cmd:$(}{it:condition}{cmd:)}]]{cmd::} {it:expression} {cmd:=} {it:expression}

{p 8 12 2}
{cmd:cge_equation} {it:name}[{cmd:(}{it:i}[{cmd:,}{it:j}]{cmd:)}[{cmd:$(}{it:condition}{cmd:)}]]{cmd::} {it:expression} {cmd:=l=}|{cmd:=g=} {it:expression}{cmd:,}
{opt perp(variable[, up|down])}

{p 8 12 2}
{cmd:cge_equation}{cmd:,} {opt list}

{p 8 12 2}
{cmd:cge_equation}{cmd:,} {opt clear}

{p 8 12 2}
{cmd:cge_variable} {it:name}[{cmd:(}{it:i}[{cmd:,}{it:j}]{cmd:)}[{cmd:$(}{it:condition}{cmd:)}]] {cmd:=} {it:expression} [{cmd:,} {opt nominal}]

{p 8 12 2}
{cmd:cge_variable} {it:name}[{cmd:(}{it:i}[{cmd:,}{it:j}]{cmd:)}[{cmd:$(}{it:condition}{cmd:)}]]{cmd:,} {opt value(#)} [{opt fixed} {opt nominal}]

{p 8 12 2}
{cmd:cge_variable} {it:name}[...]{cmd:,} {opt lower(#)}|{opt upper(#)} [{opt nominal}]

{pstd}
{cmd:<=} and {cmd:>=} may be written for {cmd:=l=} and {cmd:=g=}; a defined
variable takes {opt lower(#)} and {opt upper(#)} after its expression.


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
A condition (see {it:Conditions} below) restricts the domain to some
elements. From version 0.9.1, a variable or an equation may have two indexes,
{it:name}{cmd:(}{it:i}{cmd:,}{it:j}{cmd:)}, and is then written for every pair
of elements of the two sets, or for the pairs that meet its condition; see
{it:Two indexes and sets of pairs} below.


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
{p2col:{cmd:sum((}{it:i}{cmd:,}{it:j}{cmd:),} {it:expression}{cmd:)}}the sum over every pair of elements of the sets of {it:i} and {it:j} (from version 0.9.1){p_end}
{p2col:{cmd:sum(}{it:map}{cmd:(}{it:i}{cmd:,}{it:j}{cmd:),} {it:expression}{cmd:)}}the sum over the pairs of a set of pairs defined by {helpb cge_set} (from version 0.9.1){p_end}
{p2col:{cmd:ord(}{it:i}{cmd:)}}the position of the element of index {it:i} in its set, from 1 (from version 0.7.2){p_end}
{p2colreset}{...}


{title:Conditions}

{pstd}
From version 0.7.2, a condition written {cmd:$(}{it:condition}{cmd:)}, as in
GAMS, restricts a sum, a term or a domain:

{p2colset 9 40 42 2}{...}
{p2col:{cmd:sum(}{it:i}{cmd:$(}{it:condition}{cmd:),} {it:expression}{cmd:)}}the sum over the elements for which the condition holds; 0 if there are none{p_end}
{p2col:{it:term}{cmd:$(}{it:condition}{cmd:)}}the term where the condition holds, else 0; {it:term} is a number, a reference such as {cmd:PQ(c)}, a function or an expression in parentheses{p_end}
{p2col:{it:name}{cmd:(}{it:i}{cmd:)$(}{it:condition}{cmd:)}}a user variable or equation for the elements for which the condition holds{p_end}
{p2colreset}{...}

{pstd}
A condition is an expression in which {cmd:>}, {cmd:<}, {cmd:>=}, {cmd:<=},
{cmd:==} and {cmd:!=} compare values, and {cmd:&} (and), {cmd:|} (or) and
{cmd:!} (not) combine them; any value other than 0 counts as true.
Arithmetic is evaluated first, then comparisons, {cmd:!}, {cmd:&} and
{cmd:|}. A condition may also use:

{p2colset 9 40 42 2}{...}
{p2col:{it:set}{cmd:(}{it:e}{cmd:)}}1 if element {it:e} belongs to a user set or a model set, as in {cmd:goods(c)}{p_end}
{p2col:{it:map}{cmd:(}{it:i}{cmd:,}{it:j}{cmd:)}}1 if the pair of elements belongs to a set of pairs (from version 0.9.1){p_end}
{p2col:{cmd:sameas(}{it:i}{cmd:,} {it:label}{cmd:)}}1 if the element of index {it:i} is {it:label}{p_end}
{p2col:{cmd:ord(}{it:i}{cmd:)}}the position of the element in its set{p_end}
{p2colreset}{...}

{pstd}
A condition is evaluated when the variable or equation is added, and again
when the model is calibrated, with the variables and parameters at their base
values, whatever the scenario. A shock to a parameter that a condition uses
therefore changes the value of the terms but not which terms are included, so the
system has the same size in every simulation, and {helpb cge_gams} writes out
the same terms. The elements of a user variable outside its domain do not
exist: the results leave them out, and a reference to one is 0.

{pstd}
Write the condition in parentheses after {cmd:$}: on a command line, Stata
reads {cmd:$}{it:name} as a global macro. A condition that is missing at the
base, or a domain that no element meets, stops the command with error 459.


{title:Two indexes and sets of pairs}

{pstd}
From version 0.9.1, user variables and equations may have two indexes, as the
model's {cmd:QH(c,h)} does. {cmd:cge_variable X(c,h) = PQ(c) * QH(c, h)} adds
a variable for every commodity and household, and
{cmd:cge_equation lh(c,h)$(base(QH(c, h)) > 0):} ... an equation for the
pairs that meet the condition. The two indexes must differ: for two indexes
over the same set, add digits, as in {cmd:(c,c2)}. A sum may run over two
indexes, {cmd:sum((c,h), X(c,h))}, with a condition if needed,
{cmd:sum((c,h)$(}{it:condition}{cmd:),} ...{cmd:)}.

{pstd}
A set of pairs, such as {cmd:cge_set map(a,c) = act_agr.com_agr act_man.com_man}
({helpb cge_set}), records a mapping between two sets.
{cmd:sum(map(a,c),} {it:expression}{cmd:)} sums over its pairs, and
{cmd:map(a,c)} in a condition is 1 for a pair of the set, so that
{cmd:cge_variable Y(a,c)$(map(a,c)) = PA(a) / PQ(c)} is defined for the pairs
only. An element of a variable with two indexes is written
{it:e1}{cmd:.}{it:e2} in {helpb cge_shock}, as in {cmd:elements(com_agr.hhd)};
an inequality with two indexes is paired with a variable over the same
indexes, as in {cmd:perp(FL(c,h))}. The results give the second index in
{cmd:element2}, and {helpb cge_gams} declares the variables over two sets of
accounts.


{title:Inequalities}

{pstd}
From version 0.9.0, a user equation may be an inequality, as in GAMS:
{it:lhs} {cmd:=l=} {it:rhs} (at most) or {it:lhs} {cmd:=g=} {it:rhs} (at
least). It is paired with a variable, {opt perp(variable)}, as in a mixed
complementarity problem: the variable stays at its level while the inequality
holds with room to spare, and moves, up or, with {opt perp(variable, down)},
down, when it binds, by as much as keeps it binding. The paired variable must
be fixed under the closure: a premium or rent ({cmd:RM}, {cmd:RE},
{cmd:RA}), a scaling factor such as {cmd:GADJ}, a tax adjuster that the
closure fixes, or an exogenous user variable. With an index, {cmd:perp(RA(a))}
pairs each element with the element of the same label; {cmd:perp(RA(act_man))}
names one element.

{pstd}
Inequalities are solved like the constraints of {helpb cge_constraint}: in a
smoothed form, then exactly in the regimes found. {cmd:cge_constraint, list}
shows them and whether they bind, and {helpb cge_gams} writes them into a
mixed complementarity problem for PATH. They are kept when the model is
saved, calibrated again or given another closure; an inequality whose paired
variable the new closure frees is left out, with a note, until a closure fixes
it again.

{pstd}
A user variable may be bounded. {cmd:cge_variable} {it:name} {cmd:=}
{it:expression}{cmd:, lower(}{it:#}{cmd:) upper(}{it:#}{cmd:)} holds the variable
within its bounds, at the expression or at the bound it would cross.
{cmd:cge_variable} {it:name}{cmd:, value(}{it:#}{cmd:) fixed} is exogenous, at
its value, which {helpb cge_shock} can change; {cmd:cge_variable}
{it:name}{cmd:, lower(}{it:#}{cmd:)} (or {opt upper(#)}) is exogenous at the
bound, from which an inequality paired with it may move it.


{title:Options}

{phang}
{opt nominal} marks a user variable measured in local currency, so that the
homogeneity check of {helpb cge_check} expects it to scale with the
numeraire.

{phang}
{opt value(#)} gives the base value of a variable that equations determine.

{phang}
{opt fixed} makes a variable given a value exogenous, as in the closure.

{phang}
{opt lower(#)} and {opt upper(#)} bound a variable (see {it:Inequalities}).

{phang}
{opt perp(variable[, up|down])} pairs an inequality with a variable fixed under
the closure, which moves up (the default) or down when it binds.

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

{pstd}An import quota on manufactures, with its premium; government revenue at least its base level, sales tax rates adjusting; and a relative price held within bounds (from version 0.9.0){p_end}
{phang2}{cmd:. cge_equation quota: QM(com_man) =l= 1.02 * base(QM(com_man)), perp(RM(com_man))}{p_end}
{phang2}{cmd:. cge_equation rev: YG >= base(YG), perp(TQADJ)}{p_end}
{phang2}{cmd:. cge_variable PRA = PQ(com_agr) / CPI, lower(0.999) upper(1.001)}{p_end}
{phang2}{cmd:. cge_solve}{p_end}
{phang2}{cmd:. cge_constraint, list}{p_end}

{pstd}Spending on the imports that carry a tariff, and the tariff revenue by commodity, defined only for them{p_end}
{phang2}{cmd:. cge_variable MT = sum(c$(tm(c) > 0), PM(c) * QM(c)), nominal}{p_end}
{phang2}{cmd:. cge_variable TMV(c)$(tm(c) > 0) = tm(c) * PM(c) * QM(c)}{p_end}

{pstd}Government purchases of goods, and of agricultural goods and services{p_end}
{phang2}{cmd:. cge_set goods = c, except(com_ser)}{p_end}
{phang2}{cmd:. cge_variable GG = sum(c, (PQ(c) * QG(c))$(goods(c)))}{p_end}
{phang2}{cmd:. cge_variable GAS = sum(c$(sameas(c, com_agr) | sameas(c, com_ser)), PQ(c) * QG(c))}{p_end}

{pstd}Household spending by commodity and household, its total, and the output of activities paired with their commodities (from version 0.9.1){p_end}
{phang2}{cmd:. cge_variable XH(c,h) = PQ(c) * QH(c, h), nominal}{p_end}
{phang2}{cmd:. cge_variable XS = sum((c,h), XH(c,h)), nominal}{p_end}
{phang2}{cmd:. cge_set map(a,c) = act_agr.com_agr act_man.com_man}{p_end}
{phang2}{cmd:. cge_variable VMAP = sum(map(a,c), PA(a) * QA(a)), nominal}{p_end}
{phang2}{cmd:. cge_variable PR(a,c)$(map(a,c)) = PA(a) / PQ(c)}{p_end}


{title:Remarks}

{pstd}
User variables and equations are saved with the model, kept when it is
calibrated again (with base values from the new base) and solved in every
simulation, dynamic run and sensitivity draw. Their derivatives are exact
(from version 0.7.0). Results list the user variables with the others.


{title:Stored results}

{pstd}
{cmd:cge_variable} and {cmd:cge_equation} store {cmd:r(name)} and
{cmd:r(N_elements)}, the number of elements in the domain; an inequality also
{cmd:r(N_constraints)}, the number of constraints of the model; {cmd:cge_equation, list} stores {cmd:r(N_variables)} and
{cmd:r(N_equations)} (equation elements).


{title:Also see}

{psee}
{helpb cge_closure}, {helpb cge_shock}, {helpb cge_solve}, {helpb cge_gams}, {helpb cge}
{p_end}
