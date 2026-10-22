{smcl}
{* *! version 0.6.4  22oct2026}{...}
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
in memory, top-down and without feedback to the model (Reference Manual,
{it:The link to household surveys}). Each survey household belongs to a CGE household group and keeps
its own income composition and budget shares.

{phang2}- Each income component changes as the CGE says that source changes for
the household's group.{p_end}
{phang2}- Nominal consumption follows the household's income and its group's
direct tax and savings rates.{p_end}
{phang2}- Consumption is deflated by a price index from the household's own
budget shares, or its group's, at the prices households pay, including VAT.{p_end}

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
commodities whose prices apply; an item may instead name an activity, for home
consumption of its output, at the activity's price (from version 0.3.2). A
household's price index then uses its own budget shares; otherwise, its
group's base budget shares, including home consumption.

{phang}
{opt line(#)} is the poverty line, per person, in the units of consumption; it
must be positive.

{phang}
{opt generate(prefix)} creates {it:prefix}{cmd:_nom} (nominal consumption),
{it:prefix}{cmd:_price} (the household's price index),
{it:prefix}{cmd:_real} (real consumption) and {it:prefix}{cmd:_pc} (real
consumption per person). {opt replace} allows them to be replaced.

{phang}
{opt nodisplay} suppresses the table.


{title:Example}

{pstd}Setup: a tariff removal in the SYNTHETIC SAM of {helpb cge_synthetic}{p_end}
{phang2}{cmd:. cge_synthetic, clear}{p_end}
{phang2}{cmd:. cge_sam, labels(account)}{p_end}
{phang2}{cmd:. cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) factors(lab cap) households(hhd) government(gov) savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)}{p_end}
{phang2}{cmd:. cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)}{p_end}
{phang2}{cmd:. cge_shock tm, value(0)}{p_end}
{phang2}{cmd:. cge_solve, name(notariff)}{p_end}

{pstd}A SYNTHETIC survey of 1,000 households, all in the CGE household {cmd:hhd}{p_end}
{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. set seed 2026}{p_end}
{phang2}{cmd:. set obs 1000}{p_end}
{phang2}{cmd:. generate str3 group = "hhd"}{p_end}
{phang2}{cmd:. generate double hhsize = 1 + floor(6 * runiform())}{p_end}
{phang2}{cmd:. generate double weight = 100 + 50 * runiform()}{p_end}
{phang2}{cmd:. generate double wage = exp(rnormal(5, 0.7)) * hhsize}{p_end}
{phang2}{cmd:. generate double profit = cond(runiform() < 0.3, exp(rnormal(5, 1)), 0)}{p_end}
{phang2}{cmd:. generate double cons = 0.9 * (wage + profit)}{p_end}
{phang2}{cmd:. generate double food = 0.5 * cons}{p_end}
{phang2}{cmd:. generate double goods = 0.5 * cons}{p_end}

{pstd}Consumption and poverty after the tariff removal, by household{p_end}
{phang2}{cmd:. cge_microsim [pweight = weight], sim(notariff) group(group) consumption(cons) size(hhsize) income(wage:lab profit:cap) budget(food:com_agr goods:com_man) line(100) generate(nt)}{p_end}


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
