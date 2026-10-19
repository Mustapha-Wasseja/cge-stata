{smcl}
{* *! version 0.3.1  20oct2026}{...}
{title:Title}

{p2colset 5 16 18 2}{...}
{p2col:{bf:cge_map} {hline 2}}Assign SAM accounts to model roles{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_map}{cmd:,} {opt activities(names)} {opt commodities(names)} {opt factors(names)}
{opt households(names)} {opt government(name)} {opt savinv(name)} {opt row(name)}
[{opt enterprises(names)} {opt marginaccounts(names)} {opt stocks(names)} {opt insurance(name)} {opt margins(names)} {opt territorial(names)} {opt dirtax(name)} {opt saltax(name)} {opt imptax(name)} {opt exptax(name)} {opt acttax(name)} {opt vattax(name)} {opt vatshare(spec)}
{opt report(filename)} {opt replace}]

{p 8 12 2}
{cmd:cge_map using} {it:template} [{cmd:,} {opt vatshare(spec)} {opt sheet(string)} {opt report(filename)} {opt replace}]

{pstd}
Options must be typed in full.


{title:Description}

{pstd}
{cmd:cge_map} assigns the accounts of the SAM read by {helpb cge_sam} to the roles
of the model and checks the SAM against the flows the model represents
(docs/model_spec.md, Section 7.0). It looks for:

{p 8 12 2}- accounts that are not balanced;{p_end}
{p 8 12 2}- accounts with flows but no role;{p_end}
{p 8 12 2}- non-zero cells that are flows the model does not represent;{p_end}
{p 8 12 2}- negative cells where the model needs non-negative values.{p_end}

{pstd}
All problems are collected and summarised in one table, grouped by problem and
by the roles of the paying and receiving accounts, largest first, with each
group's share of the SAM. If there is any problem, {cmd:cge_map} then exits with
error 459. Unknown account names and accounts given two roles stop the command
at once.

{pstd}
Before the checks, layouts common in national SAMs are rewritten into the
model's layout, and the amounts moved are displayed (docs/model_spec.md,
Section 7.0). Exports recorded as sales by an activity to the rest of the world
are moved to the commodity paired with the activity. Margins netted out of the
activities listed in {opt margins()} are moved to their output. Stock-change
accounts listed in {opt stocks()} are merged into savings-investment. Taxes paid
directly to the government account are routed through internal tax accounts;
see the tax options below. The SAM in memory is not changed.


{pstd}
With {cmd:using}, the roles are read from a template written by
{helpb cge_template} and filled in (docs/sam_tools.md, Section 3). Each
account's {cmd:role} names the options that list it; activities are paired with
the commodities in the {cmd:pair} column or, where it is blank, with the
commodity whose column pays them most. If the SAM was aggregated with the same
template ({helpb cge_aggregate}), each group takes the role of its members.
The equivalent {cmd:cge_map} command is displayed and stored in
{cmd:r(command)}. A template avoids long option lists for large SAMs.


{title:Options}

{phang}
{opt activities()} and {opt commodities()} list the activity and commodity
accounts, paired by position: each activity's primary commodity, used when
rewriting national-accounts layouts. An activity may also produce other
commodities, in fixed proportions taken from the SAM. Each activity needs a
paired commodity. Commodities without a producing activity, such as commodities
that are imported only, are listed after the paired ones. An activity account
with no flows at all is left out.

{phang}
{opt factors()} and {opt households()} list the factor and household accounts.
Non-profit institutions serving households can be listed as households.

{phang}
{opt enterprises()} lists enterprise accounts (corporations). Enterprises
receive factor income and transfers, pay direct taxes and save; the rest of
their income is transferred to other institutions or abroad. They do not
consume, so an enterprise that buys commodities is reported as an unsupported
flow.

{phang}
{opt government()}, {opt savinv()} and {opt row()} name the government,
savings-investment and rest-of-world accounts.

{phang}
{opt marginaccounts()} lists margin accounts: accounts that collect trade or
transport margins from commodities (the margin account's row, the commodities'
columns) and spend them on margin services (commodity rows, the margin
account's column). A margin account may have no other flows. Margins enter the
model as a fixed quantity of services per unit of each commodity's composite
supply, and their cost enters the commodity's price (docs/model_spec.md,
equations P3 and T8). The SAM records one margin payment per commodity, so
margins on domestic sales, imports and exports are not distinguished.

{phang}
{opt stocks()} lists stock-change accounts: accounts financed by
savings-investment that buy commodities, with negative cells for a fall in
inventories. Their purchases are moved to the savings-investment account, so
changes in inventories become part of investment demand. A stock-change account
may receive payments only from savings-investment.

{phang}
{opt insurance()} names a social health insurance fund (from version 0.1.13).
The fund may receive contributions from factors (its row, the factors'
columns), transfers from the government and from the rest of the world, and may
buy commodities and save; it may have no other flows. Contributions enter the
model as a fixed rate on each factor's income, taken before that income is
distributed to institutions. The fund buys a fixed basket of commodities,
scaled so that it spends its revenue less a fixed share saved
(docs/model_spec.md, equations I2 and I12 to I14). A donor-funded non-profit
institution that buys health services is mapped as a household instead.

{phang}
{opt margins()} lists activities, typically trade and transport, whose margin
revenue the SAM nets out of their output by recording a negative use of their
own product. That negative cell is moved to the activity's output, so the
margins enter the model as the producing activities' purchases of trade and
transport services, as the SAM records them (docs/model_spec.md, Section 7.0).
The activity's own use of its product cannot be separated from the netted
margins and becomes zero. Naming an activity without a negative use of its own
product is an error.

{phang}
{opt territorial(commodity [activity])} names the territorial-correction
commodity and, optionally, its activity. The correction's imports (residents'
purchases abroad) become household payments to the rest of the world, and its
exports (non-residents' purchases in the country) become transfers from the rest
of the world to households, divided among households in proportion to their
consumption of the correction. The correction accounts then have no flows and
must not be mapped to other roles.

{phang}
{opt dirtax()}, {opt saltax()}, {opt imptax()}, {opt exptax()} and
{opt acttax()} name the accounts that collect direct taxes, sales taxes, import
tariffs, export taxes and activity taxes. A tax that is not mapped is zero.
If a SAM records a tax as a direct payment to the government, name the
government account in the tax option, for example {cmd:saltax(gov)}: the
government row's cells in the paying columns (households for {opt dirtax()},
commodities for {opt saltax()}, {opt imptax()} and {opt exptax()}, activities
for {opt acttax()}) are routed through an internal tax account. At most one of
{opt saltax()}, {opt imptax()}, {opt exptax()} and {opt vattax()} may name the
government account.

{phang}
{opt vattax(name)} names the account that collects value added tax (VAT) from
the commodities, net of input credits, and pays it to the government (from
version 0.3.1; docs/model_spec.md, Section 12.2). VAT is then a tax on final
demand, at a rate by commodity, with credits for the VAT on inputs in the
shares given by {helpb cge_calibrate}'s {opt vatcredit()}; exports and margin
services are zero-rated.

{phang}
{opt vatshare(spec)} is for SAMs that record VAT within the sales tax account:
it moves the given share of each commodity's sales tax to an internal VAT
account {cmd:_vatshare}, as {it:commodity}{cmd::}{it:share} pairs or one share
for every commodity, between 0 and 1. Commodities not listed have share 0.
{cmd:vatshare(0)} creates an empty VAT account, so that a VAT can be introduced
by a shock to {cmd:tv}. {opt vattax()} and {opt vatshare()} may not be combined.

{phang}
{opt sheet(string)} names the worksheet of an Excel template; the default is
{cmd:accounts}, or else the first sheet.

{phang}
{opt report(filename)} saves every problem cell to a CSV file with the
columns {cmd:problem}, {cmd:paid_by}, {cmd:paid_by_role}, {cmd:received_by},
{cmd:received_by_role} and {cmd:value}. The file is written whether or not
problems are found.

{phang}
{opt replace} allows {opt report()} to overwrite an existing file.


{title:Examples}

{phang2}{cmd:. cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) factors(lab cap) households(hhd) government(gov) savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)}{p_end}

{pstd}
A supply-use layout with margin accounts, a commodity imported only
({cmd:com_fuel}, listed last) and a stock-change account:

{phang2}{cmd:. cge_synthetic, clear sut}{p_end}
{phang2}{cmd:. cge_sam, labels(account)}{p_end}
{phang2}{cmd:. cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser com_fuel) factors(lab cap) households(hhd) government(gov) savinv(si) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) marginaccounts(trd trp) stocks(dstk)}{p_end}

{pstd}
Health services and a social health insurance fund:

{phang2}{cmd:. cge_synthetic, clear health}{p_end}
{phang2}{cmd:. cge_sam, labels(account)}{p_end}
{phang2}{cmd:. cge_map, activities(act_agr act_man act_ser act_hlt) commodities(com_agr com_man com_ser com_hlt) factors(lab cap) households(hhd) government(gov) savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) insurance(shi)}{p_end}


{pstd}
From a template, filled in Excel:

{phang2}{cmd:. cge_template using roles.xlsx}{p_end}
{phang2}{cmd:. cge_map using roles.xlsx}{p_end}

{pstd}
VAT, as a separate account or as shares of the sales tax:

{phang2}{cmd:. cge_synthetic, clear vat}{p_end}
{phang2}{cmd:. cge_sam, labels(account)}{p_end}
{phang2}{cmd:. cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) factors(lab cap) households(hhd) government(gov) savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) vattax(tax_vat)}{p_end}
{phang2}{cmd:. cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) factors(lab cap) households(hhd) government(gov) savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) vatshare(com_man:0.5 com_ser:1)}{p_end}


{title:Stored results}

{synoptset 22 tabbed}{...}
{p2col 5 22 26 2: Scalars}{p_end}
{synopt:{cmd:r(N_negative_sales)}}number of negative sales of commodities by activities{p_end}
{synopt:{cmd:r(vat_moved)}}VAT moved out of the sales tax by {opt vatshare()}{p_end}
{p2col 5 22 26 2: Macros}{p_end}
{synopt:{cmd:r(command)}}with a template, the equivalent {cmd:cge_map} command{p_end}


{title:Also see}

{psee}
{helpb cge}, {helpb cge_sam}, {helpb cge_template}, {helpb cge_aggregate}, {helpb cge_calibrate}
{p_end}
