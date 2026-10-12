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
[{opt dirtax(name)} {opt saltax(name)} {opt imptax(name)} {opt exptax(name)} {opt acttax(name)}]

{pstd}
Options must be typed in full.


{title:Description}

{pstd}
{cmd:cge_map} assigns the accounts of the SAM read by {helpb cge_sam} to the roles
of the model and checks the SAM against the flows the model represents
(docs/model_spec.md, Section 7.0). It stops with an error if:

{p 8 12 2}- the SAM is not balanced;{p_end}
{p 8 12 2}- an account with flows has no role, or an account has two roles;{p_end}
{p 8 12 2}- a non-zero cell is a flow the model does not represent; the message names the paying and receiving accounts;{p_end}
{p 8 12 2}- an activity is paid by a commodity other than the one it is paired with;{p_end}
{p 8 12 2}- a cell that must be non-negative is negative.{p_end}


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


{title:Example}

{phang2}{cmd:. cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) factors(lab cap) households(hhd) government(gov) savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)}{p_end}


{title:Also see}

{psee}
{helpb cge}, {helpb cge_sam}, {helpb cge_calibrate}
{p_end}
