{smcl}
{* *! version 0.6.4  22oct2026}{...}
{title:Title}

{p2colset 5 22 24 2}{...}
{p2col:{bf:cge_aggregate} {hline 2}}Merge SAM accounts into groups{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_aggregate using} {it:template} [{cmd:,} {opt sheet(string)} {opt net:diagonal}]

{p 8 12 2}
{cmd:cge_aggregate,} {opt groups(new: old old ..., new: old ...)} [{opt net:diagonal}]


{title:Description}

{pstd}
{cmd:cge_aggregate} merges accounts of the SAM in memory into groups and starts
a new model from the result (Reference Manual, {it:SAM tools}). The groups are
given in the {cmd:group} column of a template written by {helpb cge_template},
or in {opt groups()}. Accounts not in a group keep their label.

{pstd}
Every cell of the new SAM is the sum of the cells it merges, so totals add up
and each group's balance is the sum of its members' balances. A group takes
the position of its first member. Group labels must be valid Stata names; a
group may take the label of one of its members but not of another account,
whether the groups come from {opt groups()} or from a template (from version
0.6.4 for templates).

{pstd}
Flows among the members of a group become a diagonal cell of the group, and
are kept as transfers within it: the model accepts diagonal cells for
households, enterprises and government, and {helpb cge_map} reports any other
as an unsupported flow. Their number and total are displayed.

{pstd}
With a template that has roles, the members of each group must have the same
role. After aggregation, {helpb cge_map} {cmd:using} the same template maps each
group with its members' role.


{title:Options}

{phang}
{opt groups()} lists the groups, separated by commas, each as a new label, a
colon and the accounts it merges.

{phang}
{opt sheet(string)} names the worksheet of an Excel template; the default is
{cmd:accounts}, or else the first sheet.

{phang}
{opt netdiagonal} removes all diagonal cells of the new SAM. Totals then fall
by the diagonal cells, and balances do not change.


{title:Examples}

{phang2}{cmd:. cge_synthetic, clear institutions}{p_end}
{phang2}{cmd:. cge_sam, labels(account)}{p_end}
{phang2}{cmd:. cge_aggregate, groups(act_nag: act_man act_ser, com_nag: com_man com_ser, hh: hhd npi)}{p_end}

{pstd}The groups of a template written by {helpb cge_template} and filled in{p_end}
{phang2}{cmd:. cge_aggregate using sam_roles.xlsx}{p_end}


{title:Stored results}

{synoptset 16 tabbed}{...}
{p2col 5 16 20 2: Scalars}{p_end}
{synopt:{cmd:r(N_accounts)}}number of accounts after aggregation{p_end}
{synopt:{cmd:r(total)}}sum of all cells{p_end}
{synopt:{cmd:r(maxdiff)}}largest row-column imbalance{p_end}
{synopt:{cmd:r(N_diagonal)}}number of non-zero diagonal cells before {opt netdiagonal}{p_end}
{synopt:{cmd:r(diagonal)}}their total{p_end}


{title:Also see}

{psee}
{helpb cge_template}, {helpb cge_balance}, {helpb cge_map}, {helpb cge_samexport}
{p_end}
