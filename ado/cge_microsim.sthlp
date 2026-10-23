{smcl}
{* *! version 0.9.6  23oct2026}{...}
{title:Title}

{p2colset 5 21 23 2}{...}
{p2col:{bf:cge_microsim} {hline 2}}Pass simulations to household survey data{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_microsim} [{it:if}] [{it:in}] [{it:weight}]{cmd:,} {opt sim(names)} {opt group(varname)}
{opt cons:umption(varname)} [{opt size(varname)} {opt inc:ome(var:source ...)}
{opt bud:get(var:commodity ...)} {opt line(lines)} {opt quant:iles(#)}
{opt mark:et(varname)} {opt dt:ax(varlist)} {opt trans:fers(varlist)} {opt it:ax(varlist)}
{opt sub:sidies(varlist)} {opt ink:ind(var:target ...)} {opt rew:eight(var:target ...)} {opt svy}
{opt band:s(name)}
{opt gen:erate(prefix)} {opt replace} {opt det:ail} {opt dec:ompose} {opt clear}
{opt sav:ing(filename[, replace])} {opt nod:isplay}
{opt graph(graphs)} {opt gname(stub)} {opt gexport(filename)} {opt glab:els(labels)} {opt gcolor} {opt gopts(options)}]

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
{phang2}- the growth incidence curve, the growth of each percentile of the distribution;{p_end}
{phang2}- each household's equivalent and compensating variations (from version 0.8.1);{p_end}
{phang2}- with {opt decompose}, the contribution of each channel, each source of income, direct taxes and savings, and prices, to every change, and the growth and redistribution components of the change in poverty (from version 0.8.1);{p_end}
{phang2}- with {opt market()} and the fiscal instruments, fiscal incidence as the Commitment to Equity (CEQ) method measures it: market, net market, disposable, consumable and final income, the concentration, Kakwani index, coverage and marginal contribution of each tax and benefit, the Reynolds-Smolensky index and fiscal impoverishment, in the base and after the simulation, with in-kind health benefits that follow the model's health spending (from version 0.8.2);{p_end}
{phang2}- with {opt reweight()}, the results for survey weights adjusted so that totals such as employment by sector follow the model; with {opt svy}, standard errors from the survey design; with {opt bands()}, the range of the results across draws of the elasticities (from version 0.8.3).{p_end}

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
consumption per person), {it:prefix}{cmd:_ev} and {it:prefix}{cmd:_cv} (the
household's equivalent and compensating variations, from version 0.8.1) and
{it:prefix}{cmd:_q} (the quantile group of base consumption per person). With
several simulations all but the last are numbered, {it:prefix}{cmd:_nom1}, {it:prefix}{cmd:_nom2}, and so on.
{opt replace} allows them to be replaced.

{phang}
{opt detail} also displays poverty for every line, the inequality measures
and incidence by quantile.

{phang}
{opt market(varname)} is the household's market income, before taxes and
transfers, which ranks persons for fiscal incidence (from version 0.8.2).
With it, the fiscal instruments are amounts the household pays or receives,
not negative:

{phang2}- {opt dtax(varlist)}, direct taxes and contributions; they change with market income and the group's direct tax rate;{p_end}
{phang2}- {opt transfers(varlist)}, direct transfers, which change as the group's transfers from the government;{p_end}
{phang2}- {opt itax(varlist)}, indirect taxes, which change with nominal spending and the share of sales tax and VAT in the prices the household pays;{p_end}
{phang2}- {opt subsidies(varlist)}, indirect subsidies, which change with nominal spending;{p_end}
{phang2}- {opt inkind(var:target ...)}, in-kind benefits, such as health or education services, valued at cost: each changes as the model's spending on its target, a commodity bought by the government, such as {cmd:com_hlt}, or {cmd:shi}, the purchases of the health insurance fund.{p_end}

{pmore}
Market income changes as the household's income components do, or as its
group's income without {opt income()}. All are deflated by the household's
price index. Net market income is market income less direct taxes;
disposable income adds transfers; consumable income subtracts indirect taxes
and adds subsidies; final income adds in-kind benefits.

{phang}
{opt reweight(var:target ...)} (from version 0.8.3) adjusts the survey
weights in the simulation so that the weighted total of each household
characteristic {it:var}, such as its number of workers in a sector, changes as
its target does: a factor of the model (its employment over all activities),
{it:factor}{cmd:.}{it:activity} (its employment in that activity), or a
positive number, a ratio given by the user, such as population growth. The
new weights are those closest to the survey's in relative entropy, w1 = w0
exp(x'b), so that a characteristic without a target keeps its distribution
as far as the targets allow. The simulated results use the new weights; the
base, the survey's.

{phang}
{opt svy} (from version 0.8.3) computes linearized standard errors of mean
consumption per person and of FGT0 to FGT2 for each line, in the base, in the
simulation and of the change, for all households and each group (as a
subpopulation), from the design declared by {helpb svyset}: one stage, with
strata and clusters, without a finite population correction. The weights are
those of {cmd:svyset}. Standard errors are in {cmd:r(se)} and, in the results
dataset, in {cmd:se_base}, {cmd:se_value} and {cmd:se_change}. They take the
model's changes as given: they measure the sampling error of the survey, not
the uncertainty of the model.

{phang}
{opt bands(name)} (from version 0.8.3) summarizes the results for all
households across the draws of a sensitivity analysis kept as the
simulations {it:name}{cmd:1}, {it:name}{cmd:2}, ... by
{helpb cge_sensitivity:cge_sensitivity, keep({it:name})}: for each measure,
its 5th, 50th and 95th percentiles and standard deviation across the draws,
beside its value in the first simulation of {opt sim()}.

{phang}
{opt decompose} divides the change in every measure for all households among
its channels by the Shapley method: each source of income in {opt income()},
direct taxes and savings ({cmd:taxsav}), the households that follow their
group's consumption ({cmd:group}), and prices; without {opt income()}, income
and prices. The contributions add up to the change. The change in poverty is
also divided into growth and redistribution (Datt and Ravallion 1992, in
Shapley form). With K channels the measures are computed for 2^K
distributions; K is at most 12.

{phang}
{opt clear} replaces the survey in memory with the results; see
{it:Results as a dataset} below. It cannot be combined with {opt generate()}.

{phang}
{opt saving(filename[, replace])} saves the results as a dataset and leaves the
survey in memory.

{phang}
{opt nodisplay} suppresses the tables.

{phang}
{opt graph(graphs)} (from version 0.9.6) draws graphs of the results: one or
more of {cmd:gic}, {cmd:incidence}, {cmd:poverty}, {cmd:groups},
{cmd:shapley}, {cmd:fiscal} and {cmd:bands}, or {cmd:all} for every graph that
the other options allow; see {it:Graphs} below.

{phang}
{opt gname(stub)} names the graphs {it:stub}{cmd:_}{it:graph}, such as
{cmd:microsim_gic}, the default stub being {cmd:microsim}.

{phang}
{opt gexport(filename)} saves each graph as a file, with the graph's name
before the extension: {cmd:gexport(fig.pdf)} writes {cmd:fig_gic.pdf} and so
on. The extension gives the format: {cmd:.pdf} or {cmd:.eps} for a journal,
{cmd:.png} (the default, 2,000 pixels wide) for slides and documents.

{phang}
{opt glabels(labels)} gives the simulations, in the order of {opt sim()},
the labels of the legends, such as {cmd:glabels("Tariffs removed" "Tariffs doubled")};
by default they are the names of the simulations.

{phang}
{opt gcolor} draws the series in the colours of Okabe and Ito, which readers
with colour blindness can tell apart, instead of shades of grey.

{phang}
{opt gopts(options)} adds graph options to every graph, such as
{cmd:gopts(title("Tariff reform"))} or {cmd:gopts(xsize(5) ysize(3.5))}.


{title:Welfare}

{pstd}
The equivalent variation of a household is the change in its consumption at
base prices that is worth as much as the simulation; the compensating
variation, the change at the new prices. They use the expenditure function of
the household's group, LES or Cobb-Douglas as calibrated, with the group's
subsistence quantities scaled by the household's base consumption relative to
its group's; with {opt budget()}, Cobb-Douglas in the household's own budget
shares. A household that follows its group has its group's welfare change
({helpb cge_report}) in proportion to its consumption.


{title:Fiscal incidence}

{pstd}
Persons are ranked by market income per person. For each instrument, the
concentration coefficient is the Gini formula applied to the instrument with
persons in that order; the Kakwani index is the concentration coefficient
less the Gini coefficient of market income for taxes, and the reverse for
benefits, so that it is positive when the instrument is progressive. The
redistributive effect is the Gini of market income less that of final income;
the Reynolds-Smolensky index uses the concentration coefficient of final
income instead, and reranking is their difference. The marginal contribution
of an instrument is the Gini (or headcount, at the first line) of final
income without it, less with it. Fiscal impoverishment is the share of
persons who are poor in consumable income and have less than their market
income (Higgins and Lustig 2016). Coverage is the share of persons in
households that receive or pay the instrument; coverage of the poor uses the
persons poor in market income, at the first line.


{title:Results as a dataset}

{pstd}
With {opt clear} or {opt saving()}, each observation is one result:
{cmd:sim} (the simulation), {cmd:table}, {cmd:group} ({cmd:all} or a household
group), {cmd:measure}, {cmd:line} (for poverty measures), {cmd:channel}
({cmd:shapley} and {cmd:growthred}), {cmd:q} (the quantile group or
percentile), {cmd:base}, {cmd:value} (simulated), {cmd:change} and
{cmd:pct} (per cent change). The tables are:

{p2colset 9 22 24 2}{...}
{p2col:{cmd:summary}}by group: {cmd:mean}; {cmd:ev} and {cmd:cv} per person, with {cmd:pct} their per cent of base consumption; for each line {cmd:fgt0}, {cmd:fgt1}, {cmd:fgt2} and {cmd:npoor}; {cmd:gini}, {cmd:theil}, {cmd:mld}, {cmd:ge2}, {cmd:atkinson_05}, {cmd:atkinson_1}, {cmd:atkinson_2}, {cmd:palma} and {cmd:s80s20}{p_end}
{p2col:{cmd:quantile}}by quantile group: {cmd:popshare}, {cmd:mean}, {cmd:share} (of total consumption), {cmd:inc_abs} (share of the total change, in {cmd:value}) and {cmd:ev}{p_end}
{p2col:{cmd:gic}}percentiles 1 to 99 of consumption per person, base and simulated: {cmd:pct} is the growth incidence curve{p_end}
{p2col:{cmd:shapley}}with {opt decompose}: for every measure of {cmd:summary} for all households and each channel, the base and the base plus the channel's contribution; {cmd:change} is the contribution{p_end}
{p2col:{cmd:growthred}}with {opt decompose}: the growth and redistribution components of each poverty measure{p_end}
{p2col:{cmd:fiscal}}with {opt market()}: for each income concept ({cmd:channel}: {cmd:market}, {cmd:net_market}, {cmd:disposable}, {cmd:consumable}, {cmd:final}) {cmd:mean}, {cmd:gini}, {cmd:conc} and the poverty measures; for each instrument {cmd:total}, {cmd:pct_market}, {cmd:conc}, {cmd:kakwani}, {cmd:coverage}, {cmd:coverage_poor}, {cmd:mc_gini} and {cmd:mc_fgt0}; and {cmd:re}, {cmd:rs}, {cmd:rerank} and {cmd:fi}{p_end}
{p2col:{cmd:fiscalq}}with {opt market()}: by quantile of market income per person, each instrument's {cmd:share} and its {cmd:pct_market} of the quantile's market income{p_end}
{p2col:{cmd:reweight}}with {opt reweight()}: each characteristic's weighted total, base and reweighted{p_end}
{p2col:{cmd:bands}}with {opt bands()}: for every measure for all households, its percentiles {cmd:p5}, {cmd:p50} and {cmd:p95} and its standard deviation {cmd:sd} across the draws, in {cmd:value}{p_end}
{p2colreset}{...}


{title:Graphs}

{pstd}
From version 0.9.6, {opt graph()} draws the results in the style of figures
in economics journals: a white background, axes on the left and below, light
horizontal grid lines, a line at zero, the legend below without a frame, and
no title, which a journal sets in the caption ({opt gopts(title())} adds
one). Series are told apart by shades of grey and line patterns, so that the
graphs print in black and white, or, with {opt gcolor}, by colour. The graphs
are 5 by 3.5 inches. The survey in memory is left as it was.

{p2colset 9 22 24 2}{...}
{p2col:{cmd:gic}}the growth incidence curve: the per cent change of each percentile of consumption per person, one line for each simulation{p_end}
{p2col:{cmd:incidence}}the per cent change in mean consumption per person of each quantile group of base consumption{p_end}
{p2col:{cmd:poverty}}the change in the poverty headcount, in percentage points, at each line; needs {opt line()}{p_end}
{p2col:{cmd:groups}}the per cent change in mean consumption per person of each household group{p_end}
{p2col:{cmd:shapley}}the contribution of each channel to the change in the headcount at the first line, in percentage points, or to the change in mean consumption without a line; needs {opt decompose}{p_end}
{p2col:{cmd:fiscal}}the Gini coefficient of each income concept, market to final, in the base and each simulation; needs {opt market()}{p_end}
{p2col:{cmd:bands}}the median and the 5th to 95th percentiles across the draws of the per cent change in mean consumption, the headcount at each line and the Gini coefficient; needs {opt bands()}{p_end}
{p2colreset}{...}


{title:Examples}

{pstd}Setup: a tariff removal in the SYNTHETIC SAM of {helpb cge_synthetic}{p_end}
{phang2}{cmd:. cge_synthetic, clear}{p_end}
{phang2}{cmd:. cge_sam, labels(account)}{p_end}
{phang2}{cmd:. cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) factors(lab cap) households(hhd) government(gov) savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)}{p_end}
{phang2}{cmd:. cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)}{p_end}
{phang2}{cmd:. cge_shock tm, value(0)}{p_end}
{phang2}{cmd:. cge_solve, name(notariff)}{p_end}
{phang2}{cmd:. cge_shock, reset}{p_end}
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

{pstd}Welfare by household, and the contributions of each channel{p_end}
{phang2}{cmd:. cge_microsim [pweight = weight], sim(notariff) group(group) consumption(cons) size(hhsize) income(wage:lab profit:cap) budget(food:com_agr goods:com_man) line(100) generate(w1) decompose}{p_end}

{pstd}Fiscal incidence, with in-kind services that follow government purchases{p_end}
{phang2}{cmd:. generate double market = wage + profit}{p_end}
{phang2}{cmd:. generate double dtx = 0.1 * market}{p_end}
{phang2}{cmd:. generate double itx = 0.05 * cons}{p_end}
{phang2}{cmd:. generate double school = cond(runiform() < 0.4, 20 * runiform(), 0)}{p_end}
{phang2}{cmd:. cge_microsim [pweight = weight], sim(notariff) group(group) consumption(cons) size(hhsize) income(wage:lab profit:cap) line(100) market(market) dtax(dtx) itax(itx) inkind(school:com_ser)}{p_end}

{pstd}Employment in agriculture as the model says, standard errors, and bands across 20 draws of the elasticities{p_end}
{phang2}{cmd:. generate double agri = runiform() < 0.4}{p_end}
{phang2}{cmd:. cge_microsim [pweight = weight], sim(notariff) group(group) consumption(cons) size(hhsize) income(wage:lab profit:cap) line(100) reweight(agri:lab.act_agr)}{p_end}
{phang2}{cmd:. generate long psu = ceil(_n / 10)}{p_end}
{phang2}{cmd:. svyset psu [pweight = weight]}{p_end}
{phang2}{cmd:. cge_microsim, sim(notariff) group(group) consumption(cons) size(hhsize) income(wage:lab profit:cap) line(100) svy}{p_end}
{phang2}{cmd:. svyset, clear}{p_end}
{phang2}{cmd:. program define scen_nt}{p_end}
{phang2}{cmd:  1.     cge_shock tm, value(0)}{p_end}
{phang2}{cmd:  2. end}{p_end}
{phang2}{cmd:. cge_sensitivity, scenario(scen_nt) draws(20) keep(dr) nodisplay}{p_end}
{phang2}{cmd:. cge_microsim [pweight = weight], sim(notariff) group(group) consumption(cons) size(hhsize) income(wage:lab profit:cap) line(100) bands(dr)}{p_end}

{pstd}Graphs of both simulations, with labels, saved as PDF files for a journal (from version 0.9.6){p_end}
{phang2}{cmd:. cge_microsim [pweight = weight], sim(notariff tariff2) group(group) consumption(cons) size(hhsize) income(wage:lab profit:cap) budget(food:com_agr goods:com_man) line(100 zreg) decompose graph(gic incidence poverty shapley) glabels("Tariffs removed" "Tariffs doubled") gexport(tariffs.pdf) nodisplay}{p_end}

{pstd}The same graphs in colour, as PNG files{p_end}
{phang2}{cmd:. cge_microsim [pweight = weight], sim(notariff tariff2) group(group) consumption(cons) size(hhsize) income(wage:lab profit:cap) line(100 zreg) graph(all) gcolor glabels("Tariffs removed" "Tariffs doubled") gexport(tariffs.png) nodisplay}{p_end}

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
{synopt:{cmd:r(rw_iterations)}}with {opt reweight()}: iterations of the reweighting{p_end}
{synopt:{cmd:r(rw_deviation)}}with {opt reweight()}: largest relative deviation from the targets{p_end}
{synopt:{cmd:r(N_draws)}}with {opt bands()}: number of draws{p_end}
{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(sims)}}the simulations{p_end}
{synopt:{cmd:r(lines)}}the poverty lines{p_end}
{synopt:{cmd:r(channels)}}the channels of {opt decompose}{p_end}
{synopt:{cmd:r(instlist)}}the fiscal instruments{p_end}
{synopt:{cmd:r(graphs)}}with {opt graph()}: the names of the graphs drawn{p_end}
{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:r(table)}}for all households and each group: mean real consumption per person, base and simulated, and its per cent change; FGT0, FGT1 and FGT2 at the first line, base and simulated; the Gini coefficient, base and simulated{p_end}
{synopt:{cmd:r(poverty)}}for each line ({cmd:line1}, {cmd:line2}, ...) and group: FGT0, FGT1, FGT2 and the number of poor, base and simulated{p_end}
{synopt:{cmd:r(inequality)}}for each group: the nine inequality measures, base and simulated{p_end}
{synopt:{cmd:r(quantiles)}}for each quantile group: population share, mean base and simulated, per cent change, share of consumption base and simulated, share of the total change{p_end}
{synopt:{cmd:r(gic)}}percentiles 1 to 99, base and simulated, and their per cent change{p_end}
{synopt:{cmd:r(welfare)}}for each group: EV and CV per person, and as per cent of base consumption{p_end}
{synopt:{cmd:r(shapley)}}with {opt decompose}: for each measure, the base, the contribution of each channel, and the simulated value{p_end}
{synopt:{cmd:r(growthred)}}with {opt decompose}: for each line and poverty measure, the base, growth, redistribution and the simulated value{p_end}
{synopt:{cmd:r(concepts)}}with {opt market()}: for each income concept, mean per person, Gini, concentration coefficient and (with a line) FGT0 to FGT2 and the number of poor, base and simulated{p_end}
{synopt:{cmd:r(instruments)}}with {opt market()}: for each instrument, the eight measures of the table {cmd:fiscal}, base and simulated{p_end}
{synopt:{cmd:r(redistribution)}}with {opt market()}: redistributive effect, Reynolds-Smolensky index, reranking and fiscal impoverishment, base and simulated{p_end}
{synopt:{cmd:r(fshare)}}with {opt market()}: the base share of each instrument by quantile of market income{p_end}
{synopt:{cmd:r(reweight)}}with {opt reweight()}: for each characteristic, its base total, target, total achieved and ratio{p_end}
{synopt:{cmd:r(se)}}with {opt svy}: for all households, the standard errors of mean consumption and of FGT0 to FGT2 for each line, base, simulated and of the change{p_end}
{synopt:{cmd:r(bands)}}with {opt bands()}: for each measure, the base, the value in the first simulation, the 5th, 50th and 95th percentiles and the standard deviation across the draws{p_end}


{title:References}

{phang}
Bourguignon, F., M. Bussolo and L. A. Pereira da Silva, eds. (2008). The
Impact of Macroeconomic Policies on Poverty and Income Distribution:
Macro-Micro Evaluation Techniques and Tools. World Bank and Palgrave
Macmillan.

{phang}
Datt, G., and M. Ravallion (1992). Growth and redistribution components of
changes in poverty measures: A decomposition with applications to Brazil and
India in the 1980s. Journal of Development Economics 38: 275-295.

{phang}
Higgins, S., and N. Lustig (2016). Can a poverty-reducing and progressive tax
and transfer system hurt the poor? Journal of Development Economics 122: 63-75.

{phang}
Corral, P., E. Mu{c n~}oz and I. Osorio-Rodarte (2022). Modeling the
distributional impact of macroeconomic shocks: ms_reweight. Stata Conference,
Washington, DC.

{phang}
Kakwani, N. C. (1977). Measurement of tax progressivity: An international
comparison. Economic Journal 87: 71-80.

{phang}
Lustig, N., ed. (2018). Commitment to Equity Handbook: Estimating the Impact of
Fiscal Policy on Inequality and Poverty. Brookings Institution Press and CEQ
Institute, Tulane University.

{phang}
Ravallion, M., and S. Chen (2003). Measuring pro-poor growth. Economics
Letters 78: 93-99.

{phang}
Reynolds, M., and E. Smolensky (1977). Public Expenditures, Taxes, and the
Distribution of Income: The United States, 1950, 1961, 1970. Academic Press.

{phang}
Wittenberg, M. (2010). An introduction to maximum entropy and minimum
cross-entropy estimation using Stata. Stata Journal 10: 315-330.

{phang}
Shorrocks, A. F. (2013). Decomposition procedures for distributional analysis:
a unified framework based on the Shapley value. Journal of Economic Inequality
11: 99-126.


{title:Also see}

{psee}
{helpb cge}, {helpb cge_report}, {helpb cge_dynamic}
{p_end}
