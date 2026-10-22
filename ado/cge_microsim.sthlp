{smcl}
{* *! version 0.8.0  23oct2026}{...}
{title:Title}

{p2colset 5 21 23 2}{...}
{p2col:{bf:cge_microsim} {hline 2}}Pass simulations to household survey data{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_microsim} [{it:if}] [{it:in}] [{it:weight}]{cmd:,} {opt sim(names)} {opt group(varname)}
{opt cons:umption(varname)} [{opt size(varname)} {opt inc:ome(var:source ...)}
{opt bud:get(var:commodity ...)} {opt line(lines)} {opt quant:iles(#)}
{opt gen:erate(prefix)} {opt replace} {opt det:ail} {opt clear}
{opt sav:ing(filename[, replace])} {opt nod:isplay}]

{pstd}
{cmd:pweight}s, {cmd:aweight}s, {cmd:fweight}s and {cmd:iweight}s are allowed;
all are used as proportional household weights.


{title:Description}

{pstd}
{cmd:cge_microsim} passes the results of one or more simulations to the
household survey in memory, top-down and without feedback to the model
(Reference Manual, {it:The link to household surveys}). Each survey household
belongs to a CGE household group and keeps its own income composition and
budget shares.

{phang2}- Each income component changes as the CGE says that source changes for
the household's group.{p_end}
{phang2}- Nominal consumption follows the household's income and its group's
direct tax and savings rates.{p_end}
{phang2}- Consumption is deflated by a price index from the household's own
budget shares, or its group's, at the prices households pay, including VAT.{p_end}

{pstd}
The command then reports, before and after each simulation:

{phang2}- real consumption per person, at base prices, for all households and each group;{p_end}
{phang2}- for each poverty line, the headcount, poverty gap, severity and number of poor;{p_end}
{phang2}- the Gini coefficient, Theil index, mean log deviation, GE(2), Atkinson indexes and the Palma and S80/S20 ratios;{p_end}
{phang2}- incidence by decile, or by any number of quantiles, of base consumption per person;{p_end}
{phang2}- the growth incidence curve, the growth of each percentile of the distribution.{p_end}

{pstd}
The survey's own income and consumption data drive the results. The CGE
supplies only the changes, by source, price and group. All results can be
saved as a dataset, and the new consumption of each household added to the
data, for analysis with any Stata command.


{title:Options}

{phang}
{opt sim(names)} names the simulations, one or more (several from version
0.8.0), such as the periods of a dynamic run.

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
consumption of its output, at the activity's price. A household's price index
then uses its own budget shares; otherwise, its group's base budget shares,
including home consumption.

{phang}
{opt line(lines)} gives one or more poverty lines per person, in the units of
consumption: positive numbers, or numeric variables that give each
household its own line, such as regional lines (from version 0.8.0). The
first line is the one in the table and in {cmd:r(table)}.

{phang}
{opt quantiles(#)} sets the number of quantile groups for incidence, from 2 to
100; the default is 10, deciles. Persons are ranked by base consumption per
person as {helpb xtile} ranks them.

{phang}
{opt generate(prefix)} creates {it:prefix}{cmd:_nom} (nominal consumption),
{it:prefix}{cmd:_price} (the household's price index),
{it:prefix}{cmd:_real} (real consumption), {it:prefix}{cmd:_pc} (real
consumption per person) and {it:prefix}{cmd:_q} (the quantile group of base
consumption per person). With several simulations the first four are
numbered, {it:prefix}{cmd:_nom1}, {it:prefix}{cmd:_nom2}, and so on.
{opt replace} allows them to be replaced.

{phang}
{opt detail} also displays poverty for every line, the inequality measures
and incidence by quantile.

{phang}
{opt clear} replaces the survey in memory with the results; see
{it:Results as a dataset} below. It cannot be combined with {opt generate()}.

{phang}
{opt saving(filename[, replace])} saves the results as a dataset and leaves the
survey in memory.

{phang}
{opt nodisplay} suppresses the tables.


{title:Results as a dataset}

{pstd}
With {opt clear} or {opt saving()}, each observation is one result:
{cmd:sim} (the simulation), {cmd:table}, {cmd:group} ({cmd:all} or a household
group), {cmd:measure}, {cmd:line} (for poverty measures), {cmd:q} (the quantile
group or percentile), {cmd:base}, {cmd:value} (simulated), {cmd:change} and
{cmd:pct} (per cent change). The tables are:

{p2colset 9 22 24 2}{...}
{p2col:{cmd:summary}}by group: {cmd:mean}; for each line {cmd:fgt0}, {cmd:fgt1}, {cmd:fgt2} and {cmd:npoor}; {cmd:gini}, {cmd:theil}, {cmd:mld}, {cmd:ge2}, {cmd:atkinson_05}, {cmd:atkinson_1}, {cmd:atkinson_2}, {cmd:palma} and {cmd:s80s20}{p_end}
{p2col:{cmd:quantile}}by quantile group: {cmd:popshare}, {cmd:mean}, {cmd:share} (of total consumption) and {cmd:inc_abs} (share of the total change, in {cmd:value}){p_end}
{p2col:{cmd:gic}}percentiles 1 to 99 of consumption per person, base and simulated: {cmd:pct} is the growth incidence curve{p_end}
{p2colreset}{...}


{title:Examples}

{pstd}Setup: a tariff removal in the SYNTHETIC SAM of {helpb cge_synthetic}{p_end}
{phang2}{cmd:. cge_synthetic, clear}{p_end}
{phang2}{cmd:. cge_sam, labels(account)}{p_end}
{phang2}{cmd:. cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) factors(lab cap) households(hhd) government(gov) savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)}{p_end}
{phang2}{cmd:. cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)}{p_end}
{phang2}{cmd:. cge_shock tm, value(0)}{p_end}
{phang2}{cmd:. cge_solve, name(notariff)}{p_end}
{phang2}{cmd:. cge_shock tm, scale(2)}{p_end}
{phang2}{cmd:. cge_solve, name(tariff2)}{p_end}

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
{phang2}{cmd:. generate double zreg = cond(runiform() < 0.5, 90, 110)}{p_end}

{pstd}Consumption and poverty after the tariff removal, by household{p_end}
{phang2}{cmd:. cge_microsim [pweight = weight], sim(notariff) group(group) consumption(cons) size(hhsize) income(wage:lab profit:cap) budget(food:com_agr goods:com_man) line(100) generate(nt)}{p_end}

{pstd}Two simulations, a national and a regional line, and every table{p_end}
{phang2}{cmd:. cge_microsim [pweight = weight], sim(notariff tariff2) group(group) consumption(cons) size(hhsize) income(wage:lab profit:cap) line(100 zreg) detail}{p_end}

{pstd}The results as a dataset, and the growth incidence curve{p_end}
{phang2}{cmd:. cge_microsim [pweight = weight], sim(notariff tariff2) group(group) consumption(cons) size(hhsize) income(wage:lab profit:cap) line(100 zreg) clear nodisplay}{p_end}
{phang2}{cmd:. list q pct if sim == "notariff" & table == "gic" & inlist(q, 10, 50, 90), noobs}{p_end}


{title:Stored results}

{pstd}
The results in {cmd:r()} are those of the first simulation of {opt sim()}.

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}number of households{p_end}
{synopt:{cmd:r(fgt0_base)}, {cmd:r(fgt0_sim)}}poverty headcount at the first line, base and simulated{p_end}
{synopt:{cmd:r(gini_base)}, {cmd:r(gini_sim)}}Gini coefficient, base and simulated{p_end}
{synopt:{cmd:r(N_sims)}}number of simulations{p_end}
{synopt:{cmd:r(N_lines)}}number of poverty lines{p_end}
{synopt:{cmd:r(N_quantiles)}}number of quantile groups{p_end}
{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(sims)}}the simulations{p_end}
{synopt:{cmd:r(lines)}}the poverty lines{p_end}
{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:r(table)}}for all households and each group: mean real consumption per person, base and simulated, and its per cent change; FGT0, FGT1 and FGT2 at the first line, base and simulated; the Gini coefficient, base and simulated{p_end}
{synopt:{cmd:r(poverty)}}for each line ({cmd:line1}, {cmd:line2}, ...) and group: FGT0, FGT1, FGT2 and the number of poor, base and simulated{p_end}
{synopt:{cmd:r(inequality)}}for each group: the nine inequality measures, base and simulated{p_end}
{synopt:{cmd:r(quantiles)}}for each quantile group: population share, mean base and simulated, per cent change, share of consumption base and simulated, share of the total change{p_end}
{synopt:{cmd:r(gic)}}percentiles 1 to 99, base and simulated, and their per cent change{p_end}


{title:References}

{phang}
Bourguignon, F., M. Bussolo and L. A. Pereira da Silva, eds. (2008). The
Impact of Macroeconomic Policies on Poverty and Income Distribution:
Macro-Micro Evaluation Techniques and Tools. World Bank and Palgrave
Macmillan.

{phang}
Ravallion, M., and S. Chen (2003). Measuring pro-poor growth. Economics
Letters 78: 93-99.


{title:Also see}

{psee}
{helpb cge}, {helpb cge_report}, {helpb cge_dynamic}
{p_end}
