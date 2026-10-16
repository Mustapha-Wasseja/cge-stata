{smcl}
{* *! version 0.2.2  16oct2026}{...}
{title:Title}

{p2colset 5 21 23 2}{...}
{p2col:{bf:cge_microsim} {hline 2}}Pass a simulation to household survey data{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_microsim} [{it:if}] [{it:in}] [{it:weight}]{cmd:,} {opt sim(name)} {opt group(varname)}
{opt cons:umption(varname)} [{opt size(varname)} {opt inc:ome(var:source ...)}
{opt bud:get(var:commodity ...)} {opt line(#)} {opt gen:erate(prefix)} {opt replace} {opt nod:isplay}]

{pstd}
{cmd:pweight}s, {cmd:aweight}s, {cmd:fweight}s and {cmd:iweight}s are allowed;
all are used as proportional household weights.


{title:Description}

{pstd}
{cmd:cge_microsim} passes the results of a simulation to the household survey
in memory, top-down and without feedback to the model (docs/model_spec.md,
Section 11). Each survey household belongs to a CGE household group and keeps
its own income composition and budget shares.

{phang2}- Each income component changes as the CGE says that source changes for
the household's group.{p_end}
{phang2}- Nominal consumption follows the household's income and its group's
direct tax and savings rates.{p_end}
{phang2}- Consumption is deflated by a price index from the household's own
budget shares, or its group's.{p_end}

{pstd}
The command then reports, for all households and for each group:

{phang2}- real consumption per person, at base prices;{p_end}
{phang2}- the poverty headcount and poverty gap, if a poverty line is given (severity is in {cmd:r(table)});{p_end}
{phang2}- the Gini coefficient over persons,{p_end}

{pstd}
each before and after the simulation.

{pstd}
The survey's own income and consumption data drive the results. The CGE
supplies only the changes, by source, price and group. This is Stata's
strength: the survey, its weights and its poverty line stay in Stata, and the
new variables can be analysed with any Stata command.


{title:Options}

{phang}
{opt sim(name)} names the simulation.

{phang}
{opt group(varname)} gives each household's CGE group: a string variable, or a
numeric one whose value labels (or values) are the labels of the model's
households.

{phang}
{opt consumption(varname)} is the household's total consumption, the welfare
measure, in the survey's units.

{phang}
{opt size(varname)} is the household's size; poverty and inequality are then
measured per person, over persons. The default is 1.

{phang}
{opt income(var:source ...)} lists the household's income components and
their sources:

{phang2}- a factor of the model (its group's income from that factor, or the factor's income if the group has none);{p_end}
{phang2}- {cmd:gov}, government transfers in real terms;{p_end}
{phang2}- {cmd:row}, transfers from abroad, such as remittances;{p_end}
{phang2}- {cmd:dom}, transfers from other domestic institutions, such as dividends;{p_end}
{phang2}- {cmd:cpi}, income indexed to the CPI;{p_end}
{phang2}- {cmd:fixed}, unchanged nominal income.{p_end}

{pmore}
Without {opt income()}, every household's nominal consumption changes as its
group's does.

{phang}
{opt budget(var:commodity ...)} lists spending on budget items and the
commodities whose prices apply. A household's price index then uses its own
budget shares; otherwise, its group's base budget shares.

{phang}
{opt line(#)} is the poverty line, per person, in the units of consumption.

{phang}
{opt generate(prefix)} creates {it:prefix}{cmd:_nom} (nominal consumption),
{it:prefix}{cmd:_price} (the household's price index),
{it:prefix}{cmd:_real} (real consumption) and {it:prefix}{cmd:_pc} (real
consumption per person). {opt replace} allows them to be replaced.

{phang}
{opt nodisplay} suppresses the table.


{title:Example}

{phang2}{cmd:. use survey, clear}{p_end}
{phang2}{cmd:. cge_microsim [pweight = hhweight], sim(donor_exit) group(cge_group) consumption(cons) size(hhsize) income(wage:lab_f casual:lab_i profit:cap remit:row grants:gov) budget(food:c_food medicine:c_phar clinic:c_hlth) line(1200) generate(de)}{p_end}


{title:Stored results}

{synoptset 18 tabbed}{...}
{p2col 5 18 22 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}number of households{p_end}
{synopt:{cmd:r(fgt0_base)}, {cmd:r(fgt0_sim)}}poverty headcount, base and simulated{p_end}
{synopt:{cmd:r(gini_base)}, {cmd:r(gini_sim)}}Gini coefficient, base and simulated{p_end}
{p2col 5 18 22 2: Matrices}{p_end}
{synopt:{cmd:r(table)}}for all households and each group: mean real consumption per person, base and simulated, and its per cent change; FGT0, FGT1 and FGT2, base and simulated; the Gini coefficient, base and simulated{p_end}


{title:Reference}

{phang}
Bourguignon, F., M. Bussolo and L. A. Pereira da Silva, eds. (2008). The
Impact of Macroeconomic Policies on Poverty and Income Distribution:
Macro-Micro Evaluation Techniques and Tools. World Bank and Palgrave
Macmillan.


{title:Also see}

{psee}
{helpb cge}, {helpb cge_report}, {helpb cge_dynamic}
{p_end}
