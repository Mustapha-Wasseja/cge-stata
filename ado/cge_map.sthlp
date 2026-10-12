{smcl}
{* *! version 0.1.0  12oct2026}{...}
{title:Title}

{p2colset 5 16 18 2}{...}
{p2col:{bf:cge_map} {hline 2}}Assign SAM accounts to model roles{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_map}{cmd:,} {opt activities(names)} {opt commodities(names)} {opt factors(names)}
{opt households(names)} {opt government(name)} {opt savinv(name)} {opt row(name)}
[{opt dirtax(name)} {opt saltax(name)} {opt imptax(name)} {opt exptax(name)} {opt acttax(name)}
{opt report(filename)} {opt replace}]

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
{p 8 12 2}- activities paid by a commodity other than the one they are paired with (secondary production);{p_end}
{p 8 12 2}- negative cells where the model needs non-negative values.{p_end}

{pstd}
All problems are collected and summarised in one table, grouped by problem and
by the roles of the paying and receiving accounts, largest first, with each
group's share of the SAM. If there is any problem, {cmd:cge_map} then exits with
error 459. Unknown account names and accounts given two roles stop the command
at once.

{pstd}
Before the checks, two layouts common in national SAMs are rewritten into the
model's layout, and the amounts moved are displayed (docs/model_spec.md,
Section 7.0). Exports recorded as sales by an activity to the rest of the world
are moved to the commodity paired with the activity. Taxes paid directly to the
government account are routed through internal tax accounts; see the tax
options below. The SAM in memory is not changed.


{title:Options}

{phang}
{opt activities()} and {opt commodities()} list the activity and commodity
accounts. They are paired by position: the first activity produces the first
commodity, and so on. Version 0.1 requires one commodity for each activity.

{phang}
{opt factors()} and {opt households()} list the factor and household accounts.

{phang}
{opt government()}, {opt savinv()} and {opt row()} name the government,
savings-investment and rest-of-world accounts.

{phang}
{opt dirtax()}, {opt saltax()}, {opt imptax()}, {opt exptax()} and
{opt acttax()} name the accounts that collect direct taxes, sales taxes, import
tariffs, export taxes and activity taxes. A tax that is not mapped is zero.
If a SAM records a tax as a direct payment to the government, name the
government account in the tax option, for example {cmd:saltax(gov)}: the
government row's cells in the paying columns (households for {opt dirtax()},
commodities for {opt saltax()}, {opt imptax()} and {opt exptax()}, activities
for {opt acttax()}) are routed through an internal tax account. At most one of
{opt saltax()}, {opt imptax()} and {opt exptax()} may name the government
account.

{phang}
{opt report(filename)} saves every problem cell to a CSV file with the
columns {cmd:problem}, {cmd:paid_by}, {cmd:paid_by_role}, {cmd:received_by},
{cmd:received_by_role} and {cmd:value}. The file is written whether or not
problems are found.

{phang}
{opt replace} allows {opt report()} to overwrite an existing file.


{title:Example}

{phang2}{cmd:. cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) factors(lab cap) households(hhd) government(gov) savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)}{p_end}


{title:Also see}

{psee}
{helpb cge}, {helpb cge_sam}, {helpb cge_calibrate}
{p_end}
