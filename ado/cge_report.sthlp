{smcl}
{* *! version 0.37.0  30oct2026}{...}
{title:Title}

{p2colset 5 19 21 2}{...}
{p2col:{bf:cge_report} {hline 2}}Standard report tables for one or more simulations{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_report} [{cmd:,} {opt sim:s(names)} {opt run(name)} {opt tab:les(list)} {opt var:iables(names)}
{opt item:s(items)} {opt clear} {opt sav:ing(filename[, replace])} {opt nod:isplay}]


{title:Description}

{pstd}
{cmd:cge_report} computes the standard report measures of the Reference Manual
({it:Reporting measures and welfare}) for one or more simulations and displays them as percentage changes
from the base, side by side. The tables are:

{p2colset 9 24 26 2}{...}
{p2col:{cmd:macro}}nominal and real GDP, the GDP deflator, real consumption,
government consumption, investment, purchases of the health insurance fund,
exports and imports, real value added, price indexes, the exchange rate and
the real exchange rate, private savings, investment and foreign savings{p_end}
{p2col:{cmd:government}}revenue, spending, savings and revenue by tax, including VAT{p_end}
{p2col:{cmd:debt}}interest paid at home and abroad, the primary balance, and public debt at the end of the period, at home, abroad (in local and foreign
currency), in total and in per cent of nominal GDP, when the model has debt (from version 0.3.1){p_end}
{p2col:{cmd:institutions}}income of households and enterprises; household consumption{p_end}
{p2col:{cmd:factors}}wage, real wage, income and supply of each factor, and the labour force and unemployment rate (per cent) of factors with a labour force (from version 0.3.3){p_end}
{p2col:{cmd:activities}}output, price and value added of each activity{p_end}
{p2col:{cmd:commodities}}supply, price, output, domestic sales, exports and imports of each commodity{p_end}
{p2col:{cmd:health}}health services and services per head, factor efficiency, the share of working time lost to illness (per cent) and days worked, the death
rate (per 1,000) and the population index (from version 0.3.4), and the health insurance fund, when the model has them{p_end}
{p2col:{cmd:welfare}}equivalent and compensating variations of each household, in per cent of base consumption{p_end}
{p2colreset}{...}

{pstd}
Real measures are valued at base prices, and trade at base world prices.
With VAT, final demand is valued at the prices final users pay, including VAT.
Consumption and GDP include home consumption at activity prices, and the
{cmd:macro} table then shows it separately; the {cmd:commodities} table shows
the world export price of commodities with finite export demand (from version
0.3.2).
The equivalent variation is the change in base-price spending that gives the
new utility; the compensating variation is the change in spending at the new
prices that would restore base utility. Both use the household's
Cobb-Douglas or LES expenditure function, and both are positive for a gain.
Rates -- the unemployment rate, public debt in per cent of GDP (from
version 0.3.3), the share of working time lost and the death rate per 1,000
(from version 0.3.4) -- are shown as changes in points, and other measures as
percentage changes.

{pstd}
From version 0.37.0, {opt items()} adds measures of the user language to the
report of any model, and {opt variables()} the elements of variables, in the
tables {cmd:items} and {cmd:variables}. A standalone model
({helpb cge_model}) has these tables in place of the standard ones:

{p2colset 9 24 26 2}{...}
{p2col:{cmd:variables}}every element of its variables, or of those in {opt variables()}{p_end}
{p2col:{cmd:items}}the items of {opt items()}{p_end}
{p2col:{cmd:groups}}with the roles of its variables ({cmd:cge_model roles}), each group's expenditure on the goods, the Laspeyres and geometric price
indexes of its base budget shares, its real expenditure and, with an income, its income and real income{p_end}
{p2col:{cmd:welfare}}each group's equivalent and compensating variations, in per cent of its base expenditure{p_end}
{p2colreset}{...}

{pstd}
The variations of a standalone model are those of Cobb-Douglas preferences
in the group's base budget shares: with the geometric price index G and
expenditure E, EV = E1/G - E0 and CV = E1 - E0 G. They are exact for
Cobb-Douglas demands, and a first-order approximation for others.


{title:Options}

{phang}
{opt sims(names)} lists the simulations; {cmd:_all} (or {cmd:all}) selects
every stored simulation. The default is the last one stored (a simulation
solved again under its own name keeps its place). At most six are displayed;
all are saved.

{phang}
{opt run(name)} selects every period of a run solved by {helpb cge_dynamic},
in period order, instead of {opt sims()}.

{phang}
{opt tables(list)} lists the tables to display, or {cmd:all}. The default is
{cmd:macro government debt institutions factors health welfare}. Every table is
saved.

{phang}
{opt variables(names)} adds the table {cmd:variables}, every element of the
variables named, at the base and in each simulation. A standalone model
reports every variable without it.

{phang}
{opt items(items)} adds the table {cmd:items}: each item,
{it:name} {cmd:=} {it:expression}, separated by semicolons, is an expression
of the user language ({helpb cge_variable}) in the model's variables and
parameters, evaluated at the base and in each simulation with that
simulation's parameters, as in {cmd:items(absorption = sum(c, PQ(c) * QQ(c)); pman = PQ(com_man))}.

{phang}
{opt clear} replaces the data in memory with the report, one observation per
simulation and measure, with the variables {cmd:sim}, {cmd:table},
{cmd:measure}, {cmd:element}, {cmd:base}, {cmd:value} and {cmd:pct}.

{phang}
{opt saving(filename[, replace])} saves the report. A file ending in
{cmd:.xlsx} or {cmd:.xls} is written as an Excel workbook with one sheet per
table, one row per measure, and a value and a percentage change for each
simulation; any other file is saved as a Stata dataset in the format of
{opt clear}.

{phang}
{opt nodisplay} suppresses the tables.


{title:Examples}

{pstd}Setup: two simulations of the SYNTHETIC SAM of {helpb cge_synthetic}{p_end}

{phang2}{cmd:. cge_synthetic, clear}{p_end}

{phang2}{cmd:. cge_sam, labels(account)}{p_end}

{phang2}{cmd:. cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) factors(lab cap) households(hhd)}
{cmd:government(gov) savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)}{p_end}

{phang2}{cmd:. cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)}{p_end}

{phang2}{cmd:. cge_shock tm, value(0)}{p_end}

{phang2}{cmd:. cge_solve, name(notariff)}{p_end}

{phang2}{cmd:. cge_shock, reset}{p_end}

{phang2}{cmd:. cge_shock qg, scale(1.1)}{p_end}

{phang2}{cmd:. cge_solve, name(gov_up)}{p_end}

{pstd}Report{p_end}

{phang2}{cmd:. cge_report, sims(notariff gov_up)}{p_end}

{phang2}{cmd:. cge_report, sims(_all) tables(all) saving(results.xlsx, replace)}{p_end}

{phang2}{cmd:. cge_report, clear nodisplay}{p_end}

{pstd}Measures of the user language and the elements of a variable{p_end}

{phang2}{cmd:. cge_report, sims(notariff gov_up) items(absorption = sum(c, PQ(c) * QQ(c)); pman = PQ(com_man)) variables(QA)}{p_end}

{pstd}A standalone model: two groups buying three goods from upward-sloping supplies{p_end}

{phang2}{cmd:. cge_model new}{p_end}

{phang2}{cmd:. cge_set c = g1 g2 g3}{p_end}

{phang2}{cmd:. cge_set h = h1 h2}{p_end}

{phang2}{cmd:. cge_parameter alpha(c,h), values(g1.h1:0.5 g2.h1:0.3 g3.h1:0.2 g1.h2:0.2 g2.h2:0.3 g3.h2:0.5)}{p_end}

{phang2}{cmd:. cge_parameter ybar(h), values(h1:100 h2:50)}{p_end}

{phang2}{cmd:. cge_parameter A(c) = sum(h, alpha(c,h) * ybar(h))}{p_end}

{phang2}{cmd:. cge_variable P(c), value(1)}{p_end}

{phang2}{cmd:. cge_variable Y(h) = ybar(h)}{p_end}

{phang2}{cmd:. cge_variable X(c) = A(c) * P(c)}{p_end}

{phang2}{cmd:. cge_variable Q(c,h) = alpha(c,h) * Y(h) / P(c)}{p_end}

{phang2}{cmd:. cge_equation MKT(c): sum(h, Q(c,h)) = X(c)}{p_end}

{phang2}{cmd:. cge_shock A, elements(g2) scale(0.8)}{p_end}

{phang2}{cmd:. cge_solve, name(supply)}{p_end}

{phang2}{cmd:. cge_model roles, groups(h) goods(c) prices(P) consumption(Q) income(Y)}{p_end}

{phang2}{cmd:. cge_report, items(revenue = sum(c, P(c) * X(c)))}{p_end}


{title:Stored results}

{synoptset 16 tabbed}{...}
{p2col 5 16 20 2: Scalars}{p_end}
{synopt:{cmd:r(N_measures)}}number of measures{p_end}
{synopt:{cmd:r(N_sims)}}number of simulations{p_end}


{title:Also see}

{psee}
{helpb cge}, {helpb cge_results}, {helpb cge_parameters}, {helpb cge_save}
{p_end}
