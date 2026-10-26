{smcl}
{* *! version 0.13.0  26oct2026}{...}
{title:Title}

{p2colset 5 22 24 2}{...}
{p2col:{bf:cge_parameter} {hline 2}}User parameters: values, assignments and data{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_parameter} {it:name}[{cmd:(}{it:i}[{cmd:,}{it:j}]{cmd:)}][{cmd:$(}{it:condition}{cmd:)}] {cmd:=} {it:expression} [{cmd:,} {opt def:ault(#)}]

{p 8 12 2}
{cmd:cge_parameter} {it:name}{cmd:(}{it:i}[{cmd:,}{it:j}]{cmd:)}{cmd:,} {opt val:ues(spec)} [{opt def:ault(#)}]

{p 8 12 2}
{cmd:cge_parameter} {it:name}{cmd:(}{it:i}[{cmd:,}{it:j}]{cmd:)}{cmd:,} {opt from(varname)} {opt lab:els(varlist)} [{opt def:ault(#)}]

{p 8 12 2}
{cmd:cge_parameter} {it:name}{cmd:(}{it:i}{cmd:,}{it:j}{cmd:)}{cmd:,} {opt from(varlist)} {opt lab:els(varname)} [{opt def:ault(#)}]

{p 8 12 2}
{cmd:cge_parameter} {cmd:,} {opt list}

{p 8 12 2}
{cmd:cge_parameter} {cmd:,} {opt clear}

{pstd}
{it:i} and {it:j} are indexes of model sets ({cmd:a c f h d i n}) or of user
sets ({helpb cge_set}); in a standalone model ({helpb cge_model}), of user
sets only. Do not confuse {cmd:cge_parameter}, which defines a
user parameter, with {helpb cge_parameters}, which lists the parameters of
the model, user parameters included, as a dataset.


{title:Description}

{pstd}
{cmd:cge_parameter} (from version 0.7.1; Reference Manual,
{it:User variables and equations}) adds a parameter, with no index, one or two, whose values the
user gives. User variables ({helpb cge_variable}) and equations
({helpb cge_equation}) refer to it by name, as {it:name}, {it:name}{cmd:(}{it:e}{cmd:)}
or {it:name}{cmd:(}{it:e1}{cmd:,}{it:e2}{cmd:)}, with elements or indexes.
The values given are its base values. {helpb cge_shock} changes them in a
scenario ({cmd:cge_shock} {it:name}{cmd:, elements(}{it:e}{cmd:) value(}{it:#}{cmd:)}),
{helpb cge_optimize} may take an element as an instrument, continuation and
dynamic runs carry them like the model's parameters, and {helpb cge_gams}
writes them into the GAMS program, as {cmd:UP_}{it:name}.

{pstd}
From version 0.13.0 the value is an expression, as GAMS's assignments: of
numbers, user parameters, the model's parameters, the base values of
variables ({cmd:base(}{it:X}{cmd:)}), sums, conditions and the functions of
{helpb cge_equation}, with the indexes of the parameter written out element
by element, so that {cmd:share(c,a) = io(c,a) / sum(c2, io(c2,a))} gives the
share of each element. A condition, {it:name}{cmd:(}{it:i}{cmd:)$(}{it:condition}{cmd:)},
limits the elements assigned; the others take {opt default()}. An assignment
to a parameter that exists, over the same sets, assigns its elements again,
as in GAMS, if no user variable, equation or macro uses it. The values are
computed once: a parameter computed from another does not follow later
shocks to it, which belong in the equations. A parameter's value may not use
variables themselves; their base values are {cmd:base(}{it:X}{cmd:)}.

{pstd}
User parameters are saved with the model and kept, at their base values, when
it is calibrated again. {cmd:cge_parameter, list} displays them, with their
current and base values; {cmd:cge_parameter, clear} removes them all, once no
user variable or equation uses them.


{title:Options}

{phang}
{opt values(spec)} gives values by element, as {it:element}{cmd::}{it:#}
pairs separated by spaces, for example {cmd:values(com_agr:0.3 com_man:0.5)};
for a parameter with two indexes, {it:e1}{cmd:.}{it:e2}{cmd::}{it:#}, and with
three, {it:e1}{cmd:.}{it:e2}{cmd:.}{it:e3}{cmd::}{it:#} (from version 0.25.0).
Elements not given take {opt default()}.

{phang}
{opt from(varname)} takes the values from the numeric variable {it:varname}
of the data in memory, one observation per element, and {opt labels(varlist)}
names the string variables that hold the element labels, one for each index
(any number of them from version 0.25.0).
Observations with a missing value or an empty label are skipped; elements
without an observation take {opt default()}.

{pmore}
For a parameter with two indexes, {opt from(varlist)} with
{opt labels(varname)} reads data in wide form, as a SAM in memory: from
version 0.13.0, the string variable {it:varname} labels the elements of the
first index, one observation each, and each variable of {it:varlist},
abbreviations and ranges allowed, holds the values for the element of the
second index whose label is its name.

{phang}
{opt default(#)} gives the value of the elements that {opt values()} or
{opt from()} leaves out; the default is 0.


{title:Examples}

{pstd}Setup: the SYNTHETIC SAM with a health sector, mapped and calibrated{p_end}

{phang2}{cmd:. cge_synthetic, clear health}{p_end}

{phang2}{cmd:. cge_sam, labels(account)}{p_end}

{phang2}{cmd:. cge_map, activities(act_agr act_man act_ser act_hlt) commodities(com_agr com_man com_ser com_hlt) factors(lab cap)}
{cmd:households(hhd) government(gov) savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) insurance(shi)}{p_end}

{phang2}{cmd:. cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)}{p_end}

{pstd}A target for government health purchases, 1.1 times the base, that a
user equation enforces with government consumption adjusting{p_end}

{phang2}{cmd:. cge_parameter hgoal = 1.1}{p_end}

{phang2}{cmd:. cge_variable LAM, value(1)}{p_end}

{phang2}{cmd:. cge_equation lam: QG(com_hlt) = LAM * hgoal * base(QG(com_hlt))}{p_end}

{phang2}{cmd:. cge_closure, swap(LAM GADJ)}{p_end}

{phang2}{cmd:. cge_solve, name(goal)}{p_end}

{pstd}A scenario with a higher target{p_end}

{phang2}{cmd:. cge_shock hgoal, value(1.2)}{p_end}

{phang2}{cmd:. cge_solve, name(goal12)}{p_end}

{pstd}Assignments: the share of each commodity in intermediate input, by activity, and the import tariff rates, where there are imports{p_end}

{phang2}{cmd:. cge_parameter qint0(c,a) = base(QINT(c,a))}{p_end}

{phang2}{cmd:. cge_parameter share(c,a) = qint0(c,a) / sum(c2, qint0(c2,a))}{p_end}

{phang2}{cmd:. cge_parameter tm2(c)$(base(QM(c)) > 0) = tm(c)}{p_end}

{pstd}Weights by commodity, and a price index of the user's own{p_end}

{phang2}{cmd:. cge_parameter w(c), values(com_agr:0.4 com_man:0.3 com_ser:0.2 com_hlt:0.1)}{p_end}

{phang2}{cmd:. cge_variable PIDX = sum(c, w(c) * PQ(c))}{p_end}

{phang2}{cmd:. cge_parameter, list}{p_end}


{title:Stored results}

{synoptset 16 tabbed}{...}
{p2col 5 16 20 2: Scalars}{p_end}
{synopt:{cmd:r(N_elements)}}number of values of the parameter defined{p_end}
{synopt:{cmd:r(N_parameters)}}number of user parameters ({opt list}){p_end}
{p2col 5 16 20 2: Macros}{p_end}
{synopt:{cmd:r(name)}}name of the parameter defined{p_end}


{title:Also see}

{psee}
{helpb cge_set}, {helpb cge_variable}, {helpb cge_equation}, {helpb cge_shock},
{helpb cge_parameters}, {helpb cge}
{p_end}
