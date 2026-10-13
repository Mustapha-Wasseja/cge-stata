{smcl}
{* *! version 0.0.1  12oct2026}{...}
{title:Title}

{p2colset 5 22 24 2}{...}
{p2col:{bf:cge_synthetic} {hline 2}}Load the synthetic social accounting matrix{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_synthetic} [{cmd:,} {opt clear} {opt nat:ional} {opt ins:titutions}]


{title:Options}

{phang}
{opt clear} replaces the data in memory.

{phang}
{opt national} loads the same economy in the layout of many national SAMs:
exports are recorded as sales by activities to the rest of the world, and sales
and direct taxes are paid directly to the government account (13 accounts; the
{cmd:tax_sal} and {cmd:tax_dir} accounts are absent). Map it with
{cmd:saltax(gov)} and {cmd:dirtax(gov)}; it gives the same model as the
standard layout.

{phang}
{opt institutions} loads a 17-account variant with an enterprise ({cmd:ent})
and a non-profit institution ({cmd:npi}). It includes transfers among
institutions, transfers to and from the rest of the world, factor income from
and to abroad, transfers within government, and negative savings. Map it with
{cmd:households(hhd npi)} and {cmd:enterprises(ent)}.


{title:Description}

{pstd}
{cmd:cge_synthetic} loads the synthetic social accounting matrix (SAM) bundled
with {bf:cge-stata} and checks that it is square, that row and column labels
match, and that every account balances.

{pstd}
The SAM is constructed for testing and teaching. It does not describe any
country. It has 15 accounts: three activities ({cmd:act_agr}, {cmd:act_man},
{cmd:act_ser}), three commodities ({cmd:com_agr}, {cmd:com_man},
{cmd:com_ser}), two factors ({cmd:lab}, {cmd:cap}), one household
({cmd:hhd}), government ({cmd:gov}), direct, sales and import-tariff tax
accounts ({cmd:tax_dir}, {cmd:tax_sal}, {cmd:tax_imp}), savings-investment
({cmd:sav}) and the rest of the world ({cmd:row}).

{pstd}
Each cell is a payment from the column account to the row account. The string
variable {cmd:account} holds the row labels; there is one numeric variable per
column account.


{title:Example}

{phang2}{cmd:. cge_synthetic, clear}{p_end}
{phang2}{cmd:. list account act_agr act_man act_ser, noobs}{p_end}


{title:Stored results}

{pstd}
{cmd:cge_synthetic} stores the following in {cmd:r()}:

{synoptset 18 tabbed}{...}
{p2col 5 18 22 2: Scalars}{p_end}
{synopt:{cmd:r(N_accounts)}}number of accounts{p_end}
{synopt:{cmd:r(total)}}sum of all cells{p_end}
{synopt:{cmd:r(maxdiff)}}largest absolute row-column imbalance{p_end}

{p2col 5 18 22 2: Macros}{p_end}
{synopt:{cmd:r(accounts)}}account labels in SAM order{p_end}
{synopt:{cmd:r(filename)}}path of the bundled SAM file{p_end}


{title:Author}

{pstd}
Mustapha Wasseja{p_end}


{title:Also see}

{psee}
Help: {helpb cge}
{p_end}
