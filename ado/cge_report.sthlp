{smcl}
{* *! version 0.3.4  20oct2026}{...}
{title:Title}

{p2colset 5 19 21 2}{...}
{p2col:{bf:cge_report} {hline 2}}Standard report tables for one or more simulations{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_report} [{cmd:,} {opt sim:s(names)} {opt run(name)} {opt tab:les(list)} {opt clear}
{opt sav:ing(filename[, replace])} {opt nod:isplay}]


{title:Description}

{pstd}
{cmd:cge_report} computes the standard report measures of docs/model_spec.md,
Section 9, for one or more simulations and displays them as percentage changes
from the base, side by side. The tables are:

{p2colset 9 24 26 2}{...}
{p2col:{cmd:macro}}nominal and real GDP, the GDP deflator, real consumption,
government consumption, investment, purchases of the health insurance fund,
exports and imports, real value added, price indexes, the exchange rate and
the real exchange rate, private savings, investment and foreign savings{p_end}
{p2col:{cmd:government}}revenue, spending, savings and revenue by tax, including VAT{p_end}
{p2col:{cmd:debt}}interest paid at home and abroad, the primary balance, and public debt at the end of the period, at home, abroad (in local and foreign currency), in total and in per cent of nominal GDP, when the model has debt (from version 0.3.1){p_end}
{p2col:{cmd:institutions}}income of households and enterprises; household consumption{p_end}
{p2col:{cmd:factors}}wage, real wage, income and supply of each factor, and the labour force and unemployment rate (per cent) of factors with a labour force (from version 0.3.3){p_end}
{p2col:{cmd:activities}}output, price and value added of each activity{p_end}
{p2col:{cmd:commodities}}supply, price, output, domestic sales, exports and imports of each commodity{p_end}
{p2col:{cmd:health}}health services and services per head, factor efficiency, the share of working time lost to illness (per cent) and days worked, the death rate (per 1,000) and the population index (from version 0.3.4), and the health insurance fund, when the model has them{p_end}
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


{title:Options}

{phang}
{opt sims(names)} lists the simulations; {cmd:_all} selects every stored
simulation. The default is the most recent one. At most six are displayed;
all are saved.

{phang}
{opt run(name)} selects every period of a run solved by {helpb cge_dynamic},
in period order, instead of {opt sims()}.

{phang}
{opt tables(list)} lists the tables to display, or {cmd:all}. The default is
{cmd:macro government debt institutions factors health welfare}. Every table is
saved.

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

{phang2}{cmd:. cge_report, sims(base_shock donor_exit)}{p_end}
{phang2}{cmd:. cge_report, sims(_all) tables(all) saving(results.xlsx, replace)}{p_end}
{phang2}{cmd:. cge_report, clear nodisplay}{p_end}


{title:Stored results}

{synoptset 16 tabbed}{...}
{p2col 5 16 20 2: Scalars}{p_end}
{synopt:{cmd:r(N_measures)}}number of measures{p_end}
{synopt:{cmd:r(N_sims)}}number of simulations{p_end}


{title:Also see}

{psee}
{helpb cge}, {helpb cge_results}, {helpb cge_parameters}, {helpb cge_save}
{p_end}
