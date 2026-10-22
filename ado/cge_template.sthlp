{smcl}
{* *! version 0.6.4  22oct2026}{...}
{title:Title}

{p2colset 5 21 23 2}{...}
{p2col:{bf:cge_template} {hline 2}}Write a template that maps SAM accounts to roles and groups{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_template using} {it:filename} [{cmd:,} {opt replace}]

{pstd}
{it:filename} ends in {cmd:.xlsx}, {cmd:.xls} or {cmd:.csv}.


{title:Description}

{pstd}
{cmd:cge_template} writes a template with one row per account of the SAM in
memory (Reference Manual, {it:SAM tools}). Fill it in, in Excel or any editor, and
use it with {helpb cge_map} {cmd:using} to map the SAM and with
{helpb cge_aggregate} {cmd:using} to merge accounts. A template is easier to
check and to keep than a long {cmd:cge_map} command, and it has no limit on the
number of accounts.

{pstd}
The columns are:

{p2colset 9 26 28 2}{...}
{p2col:{cmd:account}}the account label{p_end}
{p2col:{cmd:role}}the {cmd:cge_map} options that list the account, separated by spaces{p_end}
{p2col:{cmd:pair}}for an activity, the commodity it is paired with{p_end}
{p2col:{cmd:group}}for aggregation, the account it is merged into{p_end}
{p2col:{cmd:row_total}, {cmd:column_total}, {cmd:difference}}the account's totals and their difference{p_end}
{p2colreset}{...}

{pstd}
If the model in memory is mapped, {cmd:role} and {cmd:pair} are filled from the
mapping; otherwise they are blank. An Excel template also has a sheet
{cmd:roles} that lists the valid entries.

{pstd}
{bf:Roles.} A role is any option name of {helpb cge_map}: {cmd:activities},
{cmd:commodities}, {cmd:factors}, {cmd:households}, {cmd:enterprises},
{cmd:government}, {cmd:savinv}, {cmd:row}, {cmd:dirtax}, {cmd:saltax},
{cmd:imptax}, {cmd:exptax}, {cmd:acttax}, {cmd:margins}, {cmd:territorial},
{cmd:marginaccounts}, {cmd:stocks}, {cmd:insurance}, {cmd:vattax}, {cmd:domesticmargins},
{cmd:importmargins}, {cmd:exportmargins}, {cmd:factortax} or {cmd:factorincometax}
(from version 0.5.0), in either case; the
singular forms {cmd:activity}, {cmd:commodity}, {cmd:factor}, {cmd:household},
{cmd:enterprise}, {cmd:margin}, {cmd:marginaccount}, {cmd:stock}, {cmd:vat},
{cmd:domesticmargin}, {cmd:importmargin} and {cmd:exportmargin} are also
accepted, and several roles are separated by spaces or commas. An Excel
template's sheet {cmd:roles} lists every entry. VAT shares of the sales tax are not a role: give them with
{cmd:cge_map using}'s {opt vatshare()} option. An account may have several roles where {cmd:cge_map} allows it:
{cmd:activities margins} for a margin activity, {cmd:government saltax} when
sales taxes are paid to the government account. Leave the role blank only for
an account without flows. For an account with the role {cmd:factortax}, the
pair column names the factor whose use it taxes.

{pstd}
{bf:Pairs.} A blank {cmd:pair} pairs an activity with the commodity whose column
pays it most. Give the pair when the largest sale is not the activity's main
product, or when two activities would be paired with the same commodity.

{pstd}
{bf:Groups.} A blank {cmd:group} keeps the account. Accounts with the same
group are merged by {helpb cge_aggregate}; members of a group must have the
same role. After aggregation, {cmd:cge_map using} the same template maps each
group with its members' role.


{title:Options}

{phang}
{opt replace} allows an existing file to be replaced.


{title:Example}

{pstd}A SAM of your own, from a CSV file{p_end}
{phang2}{cmd:. cge_sam using national_sam.csv, clear}{p_end}
{phang2}{cmd:. cge_template using sam_roles.xlsx}{p_end}
{pstd}(fill in roles, pairs and groups in Excel){p_end}
{phang2}{cmd:. cge_aggregate using sam_roles.xlsx}{p_end}
{phang2}{cmd:. cge_balance}{p_end}
{phang2}{cmd:. cge_map using sam_roles.xlsx}{p_end}


{title:Stored results}

{synoptset 16 tabbed}{...}
{p2col 5 16 20 2: Scalars}{p_end}
{synopt:{cmd:r(N_accounts)}}number of accounts{p_end}


{title:Also see}

{psee}
{helpb cge_map}, {helpb cge_aggregate}, {helpb cge_sam}
{p_end}
