{smcl}
{* *! version 0.9.7  24oct2026}{...}
{title:Title}

{p2colset 5 21 23 2}{...}
{p2col:{bf:cge_equation} {hline 2}}User equations: new relations among the model's variables{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_equation} {it:name}[{cmd:(}{it:i}[{cmd:,}{it:j}]{cmd:)}[{cmd:$(}{it:condition}{cmd:)}]]{cmd::} {it:expression} {cmd:=} {it:expression} [{cmd:,} {opt replace(block)}]

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
functions {cmd:exp()}, {cmd:ln()} (or {cmd:log()}) and {cmd:sqrt()}, those of
{it:Functions and macros} below (from version 0.9.7), and:

{p2colset 9 34 36 2}{...}
{p2col:{it:VAR} or {it:VAR}{cmd:(}{it:e}[{cmd:,} {it:e2}]{cmd:)}}a model or user variable, at an element such as {cmd:com_hlt} or the index of the equation or of a sum{p_end}
{p2col:{it:par}{cmd:(}{it:e}{cmd:)}}a parameter at its current value: {cmd:tm}, {cmd:te}, {cmd:tq}, {cmd:ta}, {cmd:tv}, {cmd:kappa}, {cmd:pwm}, {cmd:pwe}, {cmd:ad}, {cmd:af}, {cmd:qg}, {cmd:qinv}, {cmd:trdg}, {cmd:trdr}, {cmd:trfr}, {cmd:trgr}, {cmd:trrg}, {cmd:trgg}, {cmd:tshi}, {cmd:qshi}, {cmd:trshi}, {cmd:trshir}, {cmd:rd}, {cmd:rf}, {cmd:ddebt}, {cmd:fdebt}, {cmd:qlf}, {cmd:wmin}, {cmd:wref}, {cmd:sick}, {cmd:tfy} or {cmd:hs0}, for example {cmd:tv(c)} or {cmd:trgr}{p_end}
{p2col:{it:upar}[{cmd:(}{it:e}[{cmd:,} {it:e2}]{cmd:)}]}a user parameter defined by {helpb cge_parameter}, at its current value (from version 0.7.1){p_end}
{p2col:{cmd:base(}{it:VAR}[{cmd:(}{it:e}{cmd:)}]{cmd:)}}the base value of a variable{p_end}
{p2col:{cmd:sum(}{it:i}{cmd:,} {it:expression}{cmd:)}}the sum over the set of index {it:i}, a model set or a user set{p_end}
{p2col:{cmd:sum((}{it:i}{cmd:,}{it:j}{cmd:),} {it:expression}{cmd:)}}the sum over every pair of elements of the sets of {it:i} and {it:j} (from version 0.9.1){p_end}
{p2col:{cmd:sum(}{it:map}{cmd:(}{it:i}{cmd:,}{it:j}{cmd:),} {it:expression}{cmd:)}}the sum over the pairs of a set of pairs defined by {helpb cge_set} (from version 0.9.1){p_end}
{p2col:{cmd:ord(}{it:i}{cmd:)}}the position of the element of index {it:i} in its set, from 1 (from version 0.7.2){p_end}
{p2col:{cmd:lag(}{it:VAR}[{cmd:(}{it:e}{cmd:)}][{cmd:,} {it:k}]{cmd:)}}the value of a variable {it:k} periods before, 1 to 4, 1 if omitted; the base outside dynamic runs (from version 0.9.2){p_end}
{p2col:{cmd:lead(}{it:VAR}[{cmd:(}{it:e}{cmd:)}][{cmd:,} {it:k}]{cmd:)}}the value of a variable {it:k} periods after, 1 to 4, in a run with perfect foresight; the base in a static simulation (from version 0.10.2){p_end}
{p2col:{cmd:tperiod}, {cmd:tfirst}, {cmd:tlast}}the period of a dynamic run, and 1 in its first or last period, else 0; all 0 in a static simulation (from version 0.10.2){p_end}
{p2col:{cmd:card(}{it:set}{cmd:)}}the number of elements of a model or user set, or of pairs of a set of pairs (from version 0.9.7){p_end}
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


{title:Lags}

{pstd}
From version 0.9.2, {cmd:lag(}{it:VAR}{cmd:)} is the value of a variable in the
period before, and {cmd:lag(}{it:VAR}{cmd:(}{it:e}{cmd:),} {it:k}{cmd:)} its
value {it:k} periods before, for {it:k} from 1 to 4, as {it:VAR}{cmd:(t-1)}
and {it:VAR}{cmd:(t-}{it:k}{cmd:)} in a GAMS model with a time index. In a
period of a dynamic run ({helpb cge_dynamic}), the values are those of the
periods solved before it, and of the base before the first period; within
the period they are given, as the capital stock is. In a static simulation,
the period before is the base, so {cmd:lag(}{it:VAR}{cmd:)} is the base value
of {it:VAR}. Lags let user equations carry stocks and partial adjustment from
one period to the next, for example government purchases that move halfway
towards revenue each period:

{phang2}{cmd:. cge_variable GL, value(1)}{p_end}
{phang2}{cmd:. cge_equation gl: GL = 0.5 * lag(GL) + 0.5 * YG / base(YG)}{p_end}

{pstd}
A defined variable may not refer to its own lag, whose base value would
depend on itself; give it {opt value()} and an equation instead. The lagged
values are stored with each period, and {helpb cge_gams} writes them as
parameters, {cmd:LAG1_}{it:VAR}, that each period of a dynamic run sets.

{pstd}
From version 0.10.2, {cmd:lead(}{it:VAR}{cmd:)} and
{cmd:lead(}{it:VAR}{cmd:(}{it:e}{cmd:),} {it:k}{cmd:)} are the values of later
periods, {it:VAR}{cmd:(t+1)} and {it:VAR}{cmd:(t+}{it:k}{cmd:)}, in a run with
perfect foresight ({helpb cge_dynamic}, {opt foresight}), which solves the
periods together; beyond the last period they follow the run's
{opt terminal()} condition. A recursive run cannot have them. In a static
simulation they are the base values. For example, the value of a unit of
capital that earns the real rental rate and depreciates at 5 per cent, at an
interest rate of 5 per cent:

{phang2}{cmd:. cge_variable RK = W(cap) / CPI}{p_end}
{phang2}{cmd:. cge_variable Q, value(10)}{p_end}
{phang2}{cmd:. cge_equation qeq: Q = (lead(RK) + 0.95 * lead(Q)) / 1.05}{p_end}

{pstd}
{cmd:tperiod} is the period, and {cmd:tfirst} and {cmd:tlast} are 1 in the
first and in the last period of a dynamic run and 0 otherwise; all three are
0 in a static simulation. An equation of its own for the last period, a
terminal condition, is written with {cmd:ifthen(tlast,} {it:x}{cmd:,}
{it:y}{cmd:)}. They may not be used in conditions ({cmd:$}), which are
evaluated once, at the base. {helpb cge_gams} writes values of later periods
as parameters {cmd:LEAD1_}{it:VAR}, and the period as {cmd:TPERIOD},
{cmd:TFIRST} and {cmd:TLAST}.


{title:Functions and macros}

{pstd}
From version 0.9.7, expressions may use the functions of GAMS that a
square system solves, and macros, as GAMS's {cmd:$macro}:

{p2colset 9 40 42 2}{...}
{p2col:{cmd:max(}{it:x}{cmd:,} {it:y}[{cmd:,} ...]{cmd:)}, {cmd:min()}}the largest or smallest of two or more arguments{p_end}
{p2col:{cmd:abs(}{it:x}{cmd:)}, {cmd:sqr(}{it:x}{cmd:)}, {cmd:log10(}{it:x}{cmd:)}}the absolute value, the square and the logarithm to base 10{p_end}
{p2col:{cmd:ifthen(}{it:condition}{cmd:,} {it:x}{cmd:,} {it:y}{cmd:)}}{it:x} where the condition holds, else {it:y}; the condition uses parameters, lags, leads, the period and numbers{p_end}
{p2col:{cmd:prod(}{it:i}[{cmd:$(}{it:condition}{cmd:)}]{cmd:,} {it:expression}{cmd:)}}the product over a set, 1 if no element meets the condition{p_end}
{p2col:{cmd:smax(}{it:i}[{cmd:$(}{it:condition}{cmd:)}]{cmd:,} {it:expression}{cmd:)}, {cmd:smin()}}the largest or smallest value over a set{p_end}
{p2col:{cmd:card(}{it:set}{cmd:)}}the number of elements or pairs of a set{p_end}
{p2colreset}{...}

{pstd}
{cmd:prod()}, {cmd:smax()} and {cmd:smin()} take the domains of {cmd:sum()}:
two indexes, {cmd:smax((c,h),} ...{cmd:)}, a set of pairs,
{cmd:smax(map(a,c),} ...{cmd:)}, and a condition. A maximum or minimum over a
set that no element meets stops the command with error 459; over a set of
pairs, the elements of the first index that have no pair are left out.

{pstd}
The derivatives are exact. {cmd:max()}, {cmd:min()} and {cmd:abs()} have a
kink where two arguments are equal, or the argument of {cmd:abs()} is 0;
there the solver takes the derivative of the first of the equal arguments, and
that of {cmd:abs()} is 0. A model that settles on a kink may
need more iterations, as it does in GAMS. The condition of {cmd:ifthen()} is
evaluated at the current values of parameters and lags, so a shock to the
parameter switches it; a switch on endogenous variables is an inequality
(see {it:Inequalities}), which GAMS solves as a complementarity problem.

{pstd}
{helpb cge_macro} {it:name}{cmd:(}{it:a}{cmd:,} {it:b}{cmd:) =} {it:expression}
defines a macro: {it:name}{cmd:(}{it:x}{cmd:,} {it:y}{cmd:)} in an expression
is replaced by the expression with {it:x} for {it:a} and {it:y} for {it:b}, each
argument in parentheses. Macros may use other macros and the indexes of the
equation or of a sum, and a macro without parameters stands for its
expression. For example, a CES aggregate of domestic goods and imports:

{phang2}{cmd:. cge_macro ces(x, y, d, r) = (d * x^(-r) + (1 - d) * y^(-r))^(-1 / r)}{p_end}
{phang2}{cmd:. cge_variable CQ(c)$(base(QM(c)) > 0) = ces(QD(c), QM(c), 0.5, 0.5)}{p_end}

{pstd}
{helpb cge_gams} writes the functions as GAMS's, {cmd:ifthen()} with
{cmd:eq}, {cmd:ne}, {cmd:and} and {cmd:or}, and the macros written out; GAMS
solves such a model with PATH as CNS or MCP.


{title:Replacing built-in equations}

{pstd}
From version 0.9.3, {opt replace(block)} makes an equation take the place of
elements of a built-in equation block, named as in Section 5 of the model's
specification ({cmd:T2} for the export supply of a commodity, {cmd:I7} for
government purchases, and so on): a change to the model's own equations, as a
GAMS modeller would edit them. An equation with an index replaces the
elements of the block with the labels of its own, over the same sets or user
sets within them; one without an index replaces the block without an index,
or the element given, {opt replace(block(e))}. For example, exports of
agricultural goods held at the base, and government purchases of goods 10 per
cent above the rule of {cmd:I7}:

{phang2}{cmd:. cge_equation qe: QE(com_agr) = base(QE(com_agr)), replace(T2(com_agr))}{p_end}
{phang2}{cmd:. cge_equation g7(c)$(goods(c)): QG(c) = 1.1 * qg(c) * GADJ, replace(I7)}{p_end}

{pstd}
The replaced elements leave the system, which stays square: the closure does
not change. {cmd:cge_equation, list} shows {opt replace()}; the replacements
are kept when the model is saved or calibrated again, and {helpb cge_gams}
leaves the elements out of the GAMS equations. The blocks with derivatives
coded in the package, {cmd:P7}, {cmd:P8}, {cmd:P9}, {cmd:I1}, {cmd:I8},
{cmd:I9}, {cmd:S1}, {cmd:S2}, {cmd:S3} and {cmd:S5}, cannot be replaced. A
replacement must keep the accounting of the model consistent; Walras's law,
whose residual {cmd:WALRAS} every simulation reports, shows when it does not.


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
{opt replace(block)} replaces the elements of a built-in equation block, or
{opt replace(block(e))} one element (see {it:Replacing built-in equations}).

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

{pstd}Government purchases that move halfway towards revenue each period of a dynamic run, and the change in output from the period before (from version 0.9.2); the earlier user equations are removed first{p_end}
{phang2}{cmd:. cge_closure, swap(none)}{p_end}
{phang2}{cmd:. cge_equation, clear}{p_end}
{phang2}{cmd:. cge_variable GL, value(1)}{p_end}
{phang2}{cmd:. cge_equation gl: GL = 0.5 * lag(GL) + 0.5 * YG / base(YG)}{p_end}
{phang2}{cmd:. cge_variable LAMG, value(1)}{p_end}
{phang2}{cmd:. cge_equation lamg: GADJ = LAMG * GL}{p_end}
{phang2}{cmd:. cge_closure, swap(LAMG GADJ)}{p_end}
{phang2}{cmd:. cge_variable DQA(a) = QA(a) - lag(QA(a))}{p_end}
{phang2}{cmd:. cge_dynamic, name(lagged) periods(0/3) capital(cap) depreciation(0.05) rental(0.15) growth(lab:0.02)}{p_end}

{pstd}Exports of agricultural goods held at the base, in place of their export supply, and government purchases of services 10 per cent above the base (from version 0.9.3); the earlier user equations are removed first{p_end}
{phang2}{cmd:. cge_closure, swap(none)}{p_end}
{phang2}{cmd:. cge_equation, clear}{p_end}
{phang2}{cmd:. cge_equation qe: QE(com_agr) = base(QE(com_agr)), replace(T2(com_agr))}{p_end}
{phang2}{cmd:. cge_equation gs: QG(com_ser) = 1.1 * base(QG(com_ser)), replace(I7(com_ser))}{p_end}
{phang2}{cmd:. cge_shock tm, value(0)}{p_end}
{phang2}{cmd:. cge_solve}{p_end}

{pstd}The largest export, the product of prices, a tariff switch and a CES aggregate defined by a macro (from version 0.9.7); the earlier user equations are removed first{p_end}
{phang2}{cmd:. cge_shock, reset}{p_end}
{phang2}{cmd:. cge_equation, clear}{p_end}
{phang2}{cmd:. cge_variable QEMAX = smax(c, QE(c))}{p_end}
{phang2}{cmd:. cge_variable PPROD = prod(c, PQ(c))}{p_end}
{phang2}{cmd:. cge_variable MSW = ifthen(tm(com_man) > 0, QM(com_man), 0)}{p_end}
{phang2}{cmd:. cge_macro ces(x, y, d, r) = (d * x^(-r) + (1 - d) * y^(-r))^(-1 / r)}{p_end}
{phang2}{cmd:. cge_variable CQ(c)$(base(QM(c)) > 0) = ces(QD(c), QM(c), 0.5, 0.5)}{p_end}
{phang2}{cmd:. cge_shock tm, value(0)}{p_end}
{phang2}{cmd:. cge_solve}{p_end}


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
{helpb cge_macro}, {helpb cge_set}, {helpb cge_closure}, {helpb cge_shock}, {helpb cge_solve}, {helpb cge_gams}, {helpb cge}
{p_end}
