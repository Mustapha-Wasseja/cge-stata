{smcl}
{* *! version 0.46.0  01nov2026}{...}
{title:Title}

{p2colset 5 18 20 2}{...}
{p2col:{bf:cge_mpsge} {hline 2}}Models in the form of MPSGE{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_mpsge} {it:statement}

{p 8 12 2}
{cmd:cge_mpsge end} [{cmd:,} {opt num:eraire(name[(labels)])} {opt st:art(levels)}]

{p 8 12 2}
{cmd:cge_mpsge using} {it:filename} [{cmd:,} {opt num:eraire(name[(labels)])} {opt st:art(levels)}]

{p 8 12 2}
{cmd:cge_mpsge,} {opt list} [{opt gen:erated}] | {opt drop}

{pstd}
where a {it:statement} is one of

{p2colset 9 44 46 2}{...}
{p2col:{cmd:model:}{it:name}}the model's name{p_end}
{p2col:{cmd:sectors:} {it:names}}activity levels, as {cmd:X Y(s)}{p_end}
{p2col:{cmd:commodities:} {it:names}}prices, as {cmd:PL P(g)}{p_end}
{p2col:{cmd:consumers:} {it:names}}incomes, as {cmd:RA HH(h)}{p_end}
{p2col:{cmd:auxiliary:} {it:names}}auxiliary variables, as {cmd:TAU U(r)} (from version 0.45.0){p_end}
{p2col:{cmd:prod:}{it:sector}[{cmd:$(}{it:cond}{cmd:)}] [{it:fields}] [{it:records}]}a production block{p_end}
{p2col:{cmd:demand:}{it:consumer}[{cmd:$(}{it:cond}{cmd:)}] [{it:fields}] [{it:records}]}a demand block{p_end}
{p2col:{cmd:constraint:}{it:aux}[{cmd:$(}{it:cond}{cmd:)}] {it:equation}}the constraint of an auxiliary variable{p_end}
{p2col:{cmd:report:} [{it:reports}]}report variables{p_end}
{p2col:{it:records}}records of the block being read{p_end}
{p2colreset}{...}

{pstd}
and the fields and records are written {it:key}{cmd::}{it:value}, as MPSGE
writes them:

{p2colset 9 30 32 2}{...}
{p2col:{cmd:s:}{it:e}}elasticity of substitution at the top of the inputs or demands; default 0{p_end}
{p2col:{cmd:t:}{it:e}}elasticity of transformation at the top of the outputs; default 0{p_end}
{p2col:{it:nest}{cmd::}{it:e}}a nest within {cmd:s}; {it:nest}{cmd:(}{it:parent}{cmd:):}{it:e} within another nest or within {cmd:t}{p_end}
{p2col:{it:g}{cmd:.tl:}{it:e}}a nest for each element of the set of index {it:g}, with elasticity {it:e} (from version 0.46.0); {it:g}{cmd:.tl(}{it:parent}{cmd:):}{it:e} within a nest{p_end}
{p2col:{cmd:o:}{it:commodity}}an output (production){p_end}
{p2col:{cmd:i:}{it:commodity}}an input (production){p_end}
{p2col:{cmd:d:}{it:commodity}}a final demand (demand){p_end}
{p2col:{cmd:e:}{it:commodity}}an endowment (demand){p_end}
{p2col:{cmd:q:}{it:expression}}reference quantity of a record; default 1{p_end}
{p2col:{cmd:p:}{it:expression}}reference price of a record; default 1{p_end}
{p2col:{cmd:a:}{it:consumer} {cmd:t:}{it:expression}}a tax on the record at rate {cmd:t:}, paid to the agent {cmd:a:}{p_end}
{p2col:{cmd:n:}{it:aux} [{cmd:m:}{it:expression}]}an endogenous rate of the tax, the auxiliary variable {cmd:n:} times {cmd:m:} (default 1), added to {cmd:t:}{p_end}
{p2col:{cmd:r:}{it:aux}}the multiplier of an endowment, an auxiliary variable{p_end}
{p2col:{it:nest}{cmd::}}the nest of a record, or {it:g}{cmd:.tl:}; default {cmd:s} for inputs and demands, {cmd:t} for outputs{p_end}
{p2colreset}{...}

{pstd}
and a report, {cmd:v:}{it:name} with one of {cmd:o:}{it:commodity} or
{cmd:i:}{it:commodity} and {cmd:prod:}{it:sector}, {cmd:d:}{it:commodity}
and {cmd:demand:}{it:consumer}, or {cmd:w:}{it:consumer}.


{title:Description}

{pstd}
{cmd:cge_mpsge} (from version 0.44.0) writes a standalone model
({helpb cge_model}) as MPSGE writes one (Rutherford 1999): sectors whose
activity levels produce outputs from inputs, commodities whose prices clear
their markets, and consumers whose incomes come from endowments and taxes.
Each sector has a production block, {cmd:prod:}, and each consumer a demand
block, {cmd:demand:}, whose records give the quantities and prices at a
reference point; the functions are nested CES functions of the inputs and
demands and CET functions of the outputs, calibrated to those quantities and
prices. {cmd:cge_mpsge end} writes the model as user variables and equations
({helpb cge_variable}, {helpb cge_equation}): the mixed complementarity
problem of Mathiesen (1985) that MPSGE generates, with zero profit paired
with each activity level, market clearing with each price and income
balance with each income.

{pstd}
The fields are expressions in the parameters of the model
({helpb cge_parameter}): reference quantities, prices, elasticities and tax
rates. They are evaluated at the parameters of each solve, as MPSGE
generates the model again before each solve, so that {helpb cge_shock}
changes a tax, an endowment or a technology. The model is then solved,
reported and exported like any standalone model: {helpb cge_solve},
{helpb cge_results}, {helpb cge_loop}, {helpb cge_gams}.


{title:Statements}

{pstd}
Each {cmd:cge_mpsge} command holds a statement: the header of a section and,
after it, names of the section or fields of the block. A block may be written
on one line, with as many records as needed, or over several lines, each
continuing the block before it:

{phang2}{cmd:. cge_mpsge prod:X s:0.5  o:PX q:100  i:PL q:40 p:1.25 a:CONS t:tx  i:PK q:50}{p_end}

{phang2}{cmd:. cge_mpsge prod:Y s:1.5}{p_end}

{phang2}{cmd:. cge_mpsge    o:PY q:100}{p_end}

{phang2}{cmd:. cge_mpsge    i:PL q:60  i:PK q:40}{p_end}

{pstd}
On a command line, Stata reads {cmd:$}{it:name} as a global macro, so the
sections are written without the dollar sign of MPSGE ({cmd:prod:} for
{cmd:$prod:}) and a condition in parentheses, {cmd:i:P(g)$(id0(g,s))}.
{cmd:cge_mpsge using} reads a file written as MPSGE writes a model, with
the dollar signs and conditions such as {cmd:$id0(g,s)}: from the line
{cmd:$model:} to {cmd:$offtext}, or the whole file, so that it reads the
model of a GAMS program between {cmd:$ontext} and {cmd:$offtext}. Lines that
begin with an asterisk are comments. The sets and parameters are those of
the model in Stata ({helpb cge_set}, {helpb cge_parameter}), under the same
names; names are case sensitive.

{pstd}
A block or record over indexes runs over their sets: {cmd:prod:Y(s)} is a
block for each element of set {cmd:s}, and {cmd:i:P(g) q:id0(g,s)} in it an
input of every commodity {cmd:P(g)}, the inputs with a reference quantity of
zero left out, as MPSGE leaves them out. A block takes the indexes of its
sector's or consumer's declaration, and a condition after the dollar sign
restricts a block or a record. Labels name single elements, as
{cmd:i:PF(lab)}.


{title:The functions}

{pstd}
In a nest with elasticity {it:e}, a record {it:k} with reference quantity
{it:q_k} and price {it:p_k} has the value {it:v_k} = {it:p_k q_k} at
reference prices and the relative price {it:r_k} = {it:P_k} (1 + {it:t_k}) /
{it:p_k} (an input or demand) or {it:P_k} (1 - {it:t_k}) / {it:p_k} (an
output), with {it:P_k} its commodity's price and {it:t_k} the sum of its
tax rates. As in MPSGE, the reference price of an input includes the tax at
the reference point and that of an output is net of it: an input taxed at
20 per cent at the reference point takes {cmd:p:1.2}. The price index of
the nest is

{p 8 8 2}
{it:C} = (sum {it:v_k} {it:r_k}^(1-{it:e}) / {it:V})^(1/(1-{it:e})),  {it:V} = sum {it:v_k}

{pstd}
over its records and inner nests (an inner nest with its own index in place
of {it:r_k}); the geometric mean at {it:e} = 1 and the weighted sum at
{it:e} = 0. A nest of outputs has the exponent 1 + {it:e}. A record's
quantity per unit of activity is {it:q_k} times ({it:C}/{it:r_k})^{it:e}
(outputs: ({it:r_k}/{it:C})^{it:e}) and the same factor for each nest above
it. A consumer's demands are those of the utility index {it:U} =
{it:M}/({it:V C}), with {it:M} the income, 1 at the reference point. An
elasticity given by a parameter takes the Cobb-Douglas form where it is 1:
a shock that makes it 1 needs {cmd:cge_options, conditions(solve)}, under
which the forms follow the parameters of each solve ({helpb cge_options}).

{pstd}
The defaults are those of GAMS's MPSGE: {cmd:s:0} and {cmd:t:0}, in a demand
block as in a production block, so that a demand block without {cmd:s:} is
Leontief.


{title:What is written}

{pstd}
For sector {it:B}, consumer {it:H}, commodity {it:P} and the {it:k}th record
of a block:

{p2colset 9 32 34 2}{...}
{p2col:{it:B}, {it:P}, {it:H}}activity levels and prices, 1 at the reference point, and incomes at their reference values{p_end}
{p2col:{it:B}{cmd:_s}, {it:B}{cmd:_t}, {it:B}{cmd:_}{it:nest}}price indexes of the nests of the block, 1 at the reference point{p_end}
{p2col:{it:B}{cmd:_i}{it:k}, {it:B}{cmd:_o}{it:k}}quantities of the inputs and outputs{p_end}
{p2col:{it:B}{cmd:_tx}{it:k}}revenue of the tax on the record{p_end}
{p2col:{it:H}{cmd:_s}, {it:H}{cmd:_u}, {it:H}{cmd:_d}{it:k}}price index and utility of the consumer, 1 at the reference point, and the quantities of its demands{p_end}
{p2col:{it:B}{cmd:_zp}}zero profit, paired with {it:B}{p_end}
{p2col:{it:P}{cmd:_mkt}}market clearing, supply less demand, paired with {it:P}{p_end}
{p2col:{it:H}{cmd:_inc}}income balance, paired with {it:H}{p_end}
{p2colreset}{...}

{pstd}
The equations are box pairs with the lower bound 0 ({it:Box pairs} in
{helpb cge_equation}): a sector whose cost exceeds its revenue stays at 0, a
commodity in excess supply has the price 0, as in MPSGE.
{cmd:cge_mpsge, list generated} lists the definitions.

{pstd}
{bf:The numeraire.} {opt numeraire()} fixes a price or an income at its
value at the reference point, and its equation is left out, as Walras's law
makes it hold. Without it, the income of the consumer with the largest
income at the reference point is fixed, as MPSGE does; MPSGE fixes it at
its value at the start of each solve, so that prices and incomes may differ
from those of GAMS by a common factor, and quantities do not.

{pstd}
{bf:The reference point.} {cmd:cge_mpsge end} reports the largest relative
gap of the equations at the reference point: 0 where the data are a
benchmark equilibrium. A sector that does not pay at the reference prices
starts at 0 with {cmd:cge_bound} {it:B}{cmd:, level(0)}, as GAMS's
{it:B}{cmd:.l = 0} ({helpb cge_bound}).

{pstd}
{bf:Auxiliary variables.} From version 0.45.0, an auxiliary variable
({cmd:auxiliary:}) is determined by its constraint, {cmd:constraint:}{it:aux}
followed by an equation in the variables and parameters of the model, with
{cmd:=g=}, {cmd:=e=} or {cmd:=l=}, which may go on over the statements that
follow it, to a semicolon or the next section. As in MPSGE, the variable is
at least 0 and starts at 0: a constraint {it:lhs} {cmd:=g=} {it:rhs} (or
{cmd:=e=}) is written as the box pair {it:lhs} - {it:rhs} with the variable
at 0 where the difference is positive, {cmd:=l=} as {it:rhs} - {it:lhs}
({it:aux}{cmd:_con}). An auxiliary variable may be the endogenous rate of a
tax, {cmd:n:}, as a tax that keeps the government's real revenue constant,
or the multiplier of an endowment, {cmd:r:}, as unemployment that holds a
floor on the real wage; a consumer's name in a constraint is its income.

{pstd}
{bf:Report variables.} {cmd:report:} defines variables from the model's: an
output ({cmd:o:}) or input ({cmd:i:}) of a production block, a demand
({cmd:d:}) of a demand block, the sum over the records of the block for
the commodity, or the welfare index of a consumer ({cmd:w:}), its utility
{it:H}{cmd:_u}. A report variable takes the indexes of its block and
commodity that it names, and sums over the others: {cmd:v:LAB(s) i:PF(lab) prod:Y(s)}
is the labour of each sector. Labels name single elements.

{pstd}
{bf:Starting levels.} {opt start()} gives the levels at which sectors,
commodities and auxiliary variables start, as GAMS's {cmd:.l} before a
solve, and at which the incomes are evaluated at the reference point:
{cmd:start(TAU:0.1 Z:0)}, or {cmd:start(Y(agr):0)} for one element.

{pstd}
{bf:Indexed nests.} From version 0.46.0, {it:g}{cmd:.tl:}{it:e} declares a
nest for each element of the set of index {it:g}, as GTAP's models nest
imports and domestic goods for each commodity:
{cmd:prod:C s:0.5 m:1.5 g.tl(m):sig(g)} with {cmd:i:PD(g) q:dd0(g) g.tl:} and
{cmd:i:PM(g) q:mm0(g) g.tl:}. A record in it runs over {it:g} and belongs to
the nest of its element; the elasticity may differ by element, and the nests
may be within a nest of their own, not within each other. Their price
indexes are {it:B}{cmd:_}{it:g}{cmd:tl(}{it:g}{cmd:)}. The letters of fields
other than {cmd:s} and {cmd:t} may name nests, as {cmd:m:} above: a field
without a value puts a record in the nest of that name.


{title:Options}

{phang}
{opt numeraire(name[(labels)])} fixes the price of a commodity or the income
of a consumer, with labels for an element of one with indexes, as
{cmd:numeraire(PF(lab))}.

{phang}
{opt start(levels)} (from version 0.45.0) gives starting levels,
{it:name}{cmd::}{it:#} or {it:name}{cmd:(}{it:labels}{cmd:):}{it:#}, of
sectors (default 1), commodities (default 1) and auxiliary variables
(default 0).

{phang}
{opt list} lists the model being read and the models written;
{opt generated} lists the definitions written in place of the statements.
{opt drop} drops the model being read. {helpb cge_equation}{cmd:, clear}
removes the models written with the other user variables and equations.


{title:Examples}

{pstd}Two goods, two factors, a utility sector and a tax on labour in sector
X (SYNTHETIC data){p_end}

{phang2}{cmd:. cge_model new}{p_end}

{phang2}{cmd:. cge_parameter tx = 0.25}{p_end}

{phang2}{cmd:. cge_mpsge sectors: X Y W}{p_end}

{phang2}{cmd:. cge_mpsge commodities: PX PY PL PK PW}{p_end}

{phang2}{cmd:. cge_mpsge consumers: CONS}{p_end}

{phang2}{cmd:. cge_mpsge prod:X s:0.5  o:PX q:100  i:PL q:40 p:1.25 a:CONS t:tx  i:PK q:50}{p_end}

{phang2}{cmd:. cge_mpsge prod:Y s:1.5  o:PY q:100  i:PL q:60  i:PK q:40}{p_end}

{phang2}{cmd:. cge_mpsge prod:W s:1    o:PW q:200  i:PX q:100  i:PY q:100}{p_end}

{phang2}{cmd:. cge_mpsge demand:CONS   d:PW q:200  e:PL q:100  e:PK q:90}{p_end}

{phang2}{cmd:. cge_mpsge end, numeraire(PL)}{p_end}

{phang2}{cmd:. cge_shock tx, value(0)}{p_end}

{phang2}{cmd:. cge_solve, name(notax)}{p_end}

{pstd}Sectors over a set, with intermediate inputs in fixed proportions and a
nest of labour and capital whose elasticity varies by sector, and more
capital for the consumer{p_end}

{phang2}{cmd:. cge_model new}{p_end}

{phang2}{cmd:. cge_set s = a b}{p_end}

{phang2}{cmd:. cge_set g = s}{p_end}

{phang2}{cmd:. cge_parameter y0(s), values(a:100 b:100)}{p_end}

{phang2}{cmd:. cge_parameter id0(g,s), values(a.a:10 a.b:20 b.a:20 b.b:10)}{p_end}

{phang2}{cmd:. cge_parameter ld0(s), values(a:40 b:50)}{p_end}

{phang2}{cmd:. cge_parameter kd0(s), values(a:30 b:20)}{p_end}

{phang2}{cmd:. cge_parameter c0(g), values(a:70 b:70)}{p_end}

{phang2}{cmd:. cge_parameter esub(s), values(a:0.5 b:1)}{p_end}

{phang2}{cmd:. cge_parameter kend = 50}{p_end}

{phang2}{cmd:. cge_mpsge sectors: Y(s)}{p_end}

{phang2}{cmd:. cge_mpsge commodities: P(s) PL PK}{p_end}

{phang2}{cmd:. cge_mpsge consumers: RA}{p_end}

{phang2}{cmd:. cge_mpsge prod:Y(s) s:0 va:esub(s)  o:P(s) q:y0(s)  i:P(g) q:id0(g,s)}{p_end}

{phang2}{cmd:. cge_mpsge    i:PL q:ld0(s) va:  i:PK q:kd0(s) va:}{p_end}

{phang2}{cmd:. cge_mpsge demand:RA s:1  d:P(g) q:c0(g)  e:PL q:90  e:PK q:kend}{p_end}

{phang2}{cmd:. cge_mpsge end, numeraire(PL)}{p_end}

{phang2}{cmd:. cge_mpsge, list generated}{p_end}

{phang2}{cmd:. cge_shock kend, value(60)}{p_end}

{phang2}{cmd:. cge_solve, name(capital)}{p_end}

{pstd}
A model of a GAMS program, between {cmd:$ontext} and {cmd:$offtext}, is read
with {cmd:cge_mpsge using} {it:filename}{cmd:, numeraire(}{it:name}{cmd:)},
the sets and parameters it uses defined first under the same names.

{pstd}An equal-yield tax on the output of X and a floor on the real wage,
with auxiliary variables (from version 0.45.0){p_end}

{phang2}{cmd:. cge_model new}{p_end}

{phang2}{cmd:. cge_parameter kend = 90}{p_end}

{phang2}{cmd:. cge_parameter grev = 10}{p_end}

{phang2}{cmd:. cge_mpsge sectors: X Y W}{p_end}

{phang2}{cmd:. cge_mpsge commodities: PX PY PL PK PW}{p_end}

{phang2}{cmd:. cge_mpsge consumers: CONS GOVT}{p_end}

{phang2}{cmd:. cge_mpsge auxiliary: TAU U}{p_end}

{phang2}{cmd:. cge_mpsge prod:X s:0.5  o:PX q:100 p:0.9 a:GOVT n:TAU  i:PL q:40  i:PK q:50}{p_end}

{phang2}{cmd:. cge_mpsge prod:Y s:1.5  o:PY q:100  i:PL q:60  i:PK q:40}{p_end}

{phang2}{cmd:. cge_mpsge prod:W s:1    o:PW q:200  i:PX q:100  i:PY q:100}{p_end}

{phang2}{cmd:. cge_mpsge demand:CONS   d:PW q:190  e:PL q:100  e:PL q:(-100) r:U  e:PK q:kend}{p_end}

{phang2}{cmd:. cge_mpsge demand:GOVT   d:PW q:10}{p_end}

{phang2}{cmd:. cge_mpsge constraint:TAU  GOVT =e= grev * PW}{p_end}

{phang2}{cmd:. cge_mpsge constraint:U    PL =g= PW}{p_end}

{phang2}{cmd:. cge_mpsge report:  v:XL i:PL prod:X  v:WC w:CONS}{p_end}

{phang2}{cmd:. cge_mpsge end, numeraire(PL) start(TAU:0.1)}{p_end}

{phang2}{cmd:. cge_shock kend, value(70)}{p_end}

{phang2}{cmd:. cge_solve, name(lesscap)}{p_end}

{pstd}
The model library has the first example: {cmd:cge_modlib run mpsge}
({helpb cge_modlib}).


{title:Stored results}

{pstd}{cmd:cge_mpsge end} and {cmd:cge_mpsge using} store:

{synoptset 22 tabbed}{...}
{p2col 5 22 26 2: Scalars}{p_end}
{synopt:{cmd:r(N_sectors)}}activity levels (elements){p_end}
{synopt:{cmd:r(N_commodities)}}prices (elements){p_end}
{synopt:{cmd:r(N_consumers)}}incomes (elements){p_end}
{synopt:{cmd:r(N_auxiliary)}}auxiliary variables (elements){p_end}
{synopt:{cmd:r(N_reports)}}report variables{p_end}
{synopt:{cmd:r(N_blocks)}}blocks{p_end}
{synopt:{cmd:r(N_variables)}}user variables written{p_end}
{synopt:{cmd:r(N_equations)}}equations written, besides the definitions{p_end}
{synopt:{cmd:r(N_elements)}}equation elements written, with the definitions{p_end}
{synopt:{cmd:r(numeraire_value)}}value of the numeraire{p_end}
{synopt:{cmd:r(gap)}}largest relative gap of the equations at the reference point{p_end}
{p2col 5 22 26 2: Macros}{p_end}
{synopt:{cmd:r(name)}}the model's name ({cmd:mpsge} without {cmd:model:}){p_end}
{synopt:{cmd:r(numeraire)}}the numeraire{p_end}

{pstd}{cmd:cge_mpsge, list} stores {cmd:r(N_models)} and {cmd:r(models)}.


{title:References}

{phang}
Mathiesen, L. (1985). Computation of economic equilibria by a sequence of
linear complementarity problems. Mathematical Programming Study 23: 144-162.

{phang}
Rutherford, T. F. (1995). Extension of GAMS for complementarity problems
arising in applied economic analysis. Journal of Economic Dynamics and
Control 19: 1299-1324.

{phang}
Rutherford, T. F. (1999). Applied general equilibrium modeling with MPSGE as
a GAMS subsystem: an overview of the modeling framework and syntax.
Computational Economics 14: 1-46.


{title:Also see}

{psee}
{helpb cge_model}, {helpb cge_variable}, {helpb cge_equation}, {helpb cge_nest}, {helpb cge_solve}
{p_end}
