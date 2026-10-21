{smcl}
{* *! version 0.4.2  21oct2026}{...}
{title:Title}

{p2colset 5 16 18 2}{...}
{p2col:{bf:cge_spa} {hline 2}}Structural path analysis of a SAM multiplier{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_spa}{cmd:,} {opt from(account)} {opt to(account)}
[{opt max:length(#)} {opt thr:eshold(#)} {opt top(#)}
{opt endo:genous(accounts)} {opt exo:genous(accounts)} {opt clear}]


{title:Description}

{pstd}
{cmd:cge_spa} decomposes the accounting multiplier of account {opt to()} with
respect to an injection into account {opt from()} into the paths along which
the injection travels through the SAM (from version 0.4.2; docs/sam_tools.md,
Section 7; Defourny and Thorbecke 1984). The SAM is the one mapped by
{helpb cge_map}, and the endogenous accounts are those of
{helpb cge_multiplier}.

{pstd}
A path is a chain of payments that passes through no account twice, for
example {cmd:com_hlt > act_hlt > lab > hhd}: spending on health services is
received by the health activity, which pays labour, which pays households.
For each path the command reports:

{p2colset 9 26 28 2}{...}
{p2col:direct influence}the product of the spending shares along the path, the effect with every other account held fixed{p_end}
{p2col:path multiplier}the feedback of the loops through the path's accounts: the determinant of the block of the multiplier matrix on those accounts{p_end}
{p2col:total influence}direct influence times path multiplier{p_end}
{p2col:% global}the total influence as a percentage of the global influence, the multiplier itself{p_end}
{p2colreset}{...}

{pstd}
The total influences of all paths add up to the global influence. The search
stops at paths of {opt maxlength()} arcs and drops a path, with its
extensions, once its direct influence falls below {opt threshold()} times the
global influence; the percentage of the global influence that the paths found
explain is reported. Like the multipliers, the paths assume fixed prices and
unused capacity.


{title:Options}

{phang}
{opt from(account)} and {opt to(account)} name the origin, where the
injection enters, and the destination; both must be endogenous and differ.

{phang}
{opt maxlength(#)} sets the largest number of arcs in a path; the default is 6.

{phang}
{opt threshold(#)} sets the smallest direct influence kept, as a share of the
global influence; the default is 0.001. {cmd:threshold(0)} with a large
{opt maxlength()} finds every path, which can take long in a large SAM; the
search stops beyond 100,000 paths.

{phang}
{opt top(#)} sets the number of paths displayed, largest total influence
first; the default is 10.

{phang}
{opt endogenous(accounts)} and {opt exogenous(accounts)} choose the
endogenous accounts, as in {helpb cge_multiplier}.

{phang}
{opt clear} replaces the data in memory with every path found ({cmd:path},
{cmd:length}, {cmd:direct}, {cmd:multiplier}, {cmd:total}, {cmd:share}). The
model in memory is not changed.


{title:Examples}

{phang2}{cmd:. cge_synthetic, clear health}{p_end}
{phang2}{cmd:. cge_sam, labels(account)}{p_end}
{phang2}{cmd:. cge_map, activities(act_agr act_man act_ser act_hlt) commodities(com_agr com_man com_ser com_hlt) factors(lab cap) households(hhd) government(gov) savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) insurance(shi)}{p_end}
{phang2}{cmd:. cge_spa, from(com_hlt) to(hhd)}{p_end}
{phang2}{cmd:. cge_spa, from(com_hlt) to(lab) maxlength(8) threshold(0.0001) clear}{p_end}


{title:Stored results}

{synoptset 16 tabbed}{...}
{p2col 5 16 20 2: Scalars}{p_end}
{synopt:{cmd:r(global)}}global influence (the multiplier){p_end}
{synopt:{cmd:r(N_paths)}}number of paths found{p_end}
{synopt:{cmd:r(explained)}}sum of their total influences{p_end}
{synopt:{cmd:r(share)}}that sum as a percentage of the global influence{p_end}
{synopt:{cmd:r(total1)}}total influence of the largest path{p_end}
{p2col 5 16 20 2: Macros}{p_end}
{synopt:{cmd:r(path1)}}the largest path{p_end}


{title:Reference}

{phang}
Defourny, J. and E. Thorbecke. 1984. Structural path analysis and multiplier
decomposition within a social accounting matrix framework. {it:Economic Journal}
94(373): 111-136.


{title:Also see}

{psee}
{helpb cge_multiplier}, {helpb cge_map}, {helpb cge}
{p_end}
