{smcl}
{* *! version 0.6.4  26oct2026}{...}
{title:Title}

{p2colset 5 20 22 2}{...}
{p2col:{bf:cge_balance} {hline 2}}Balance a SAM by RAS or cross entropy{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_balance} [{cmd:,} {opt meth:od(ras|ce)} {opt targ:ets(average|rows|columns)}
{opt tot:als(account:value ...)} {opt fix:ed(list)} {opt tol:erance(#)} {opt iter:ate(#)}
{opt nod:isplay}]


{title:Description}

{pstd}
{cmd:cge_balance} makes the SAM in memory balanced, so that every account's row
total equals its column total, and starts a new model from the result
(Reference Manual, {it:SAM tools}). Both methods keep the sign of every cell, every
zero cell and the cells listed in {opt fixed()}, and both minimise the same
measure of the information added to the SAM (Junius and Oosterhaven 2003;
Lenzen, Wood and Gallego 2007),

{p 8 8 2}
D = sum over cells of |x| ln(|x| / |x0|) - |x| + |x0|,

{pstd}
where x0 is the cell before balancing and x after. For a SAM without negative
cells this is the cross entropy that RAS minimises (McDougall 1999). The
methods differ in what is known about the totals.

{pstd}
{bf:RAS} ({cmd:method(ras)}, the default) sets every account's row and column
total to a target: by default the average of its row and column totals, or the
totals given in {opt totals()}. Negative cells are handled by generalised RAS
(GRAS). An account whose row or column cannot change has that total as its
target.

{pstd}
{bf:Cross entropy} ({cmd:method(ce)}) needs no targets: it estimates the totals
with the cells, subject to balance and to any totals given in {opt totals()}.
It is solved by Newton's method on the dual problem. With every total given, it
gives the RAS solution.

{pstd}
This is not the column-coefficient cross entropy of Robinson, Cattaneo and
El-Said (2001), which measures the distance between column shares rather than
cells.

{pstd}
Targets may be impossible to meet with the zeros and fixed cells of a SAM. For
example, in a SAM whose activities and product-tax accounts are paid only by
commodities, fixing every import cell fixes the difference between the
commodities' totals and theirs; RAS targets that do not respect it cannot be
met, and RAS stops when its gap no longer falls (error 430). Cross entropy,
which needs fewer totals, can often balance such a SAM.

{pstd}
The balanced SAM is an estimate: state which totals were given, which cells were
fixed and which method was used with any results.


{title:Options}

{phang}
{opt method(ras|ce)} chooses the method.

{phang}
{opt targets(average|rows|columns)} sets the RAS targets of accounts not in
{opt totals()}: the average of row and column totals (the default), the row
totals or the column totals. With {cmd:method(ce)}, which estimates the
totals that are not given, only {cmd:targets(average)} is accepted, and it has
no effect.

{phang}
{opt totals(account:value ...)} gives known account totals: targets for RAS,
constraints for cross entropy.

{phang}
{opt fixed(list)} lists cells kept at their values: {it:row}{cmd::}{it:col},
a whole row {it:row}{cmd::*}, a whole column {cmd:*:}{it:col}, or an account's
row and column ({it:account}).

{phang}
{opt tolerance(#)} sets the convergence tolerance, relative to the largest
absolute cell; every balance and target is met to {it:#} times
max(1, largest cell). The default is 1e-10.

{phang}
{opt iterate(#)} sets the maximum number of iterations: by default 10,000 for
RAS and 100 for cross entropy.

{phang}
{opt nodisplay} suppresses the table of the largest changes.


{title:Examples}

{phang2}{cmd:. cge_synthetic, clear unbalanced}{p_end}

{phang2}{cmd:. cge_sam, labels(account)}{p_end}

{phang2}{cmd:. cge_balance}{p_end}

{phang2}{cmd:. cge_sam, labels(account)}{p_end}

{phang2}{cmd:. cge_balance, method(ce) totals(act_agr:97 hhd:290) fixed(row:* hhd:lab)}{p_end}


{title:Stored results}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(iterations)}}iterations (RAS) or Newton steps (cross entropy){p_end}
{synopt:{cmd:r(maxdiff_before)}}largest row-column imbalance before{p_end}
{synopt:{cmd:r(maxdiff)}}largest row-column imbalance after{p_end}
{synopt:{cmd:r(total_before)}}sum of all cells before{p_end}
{synopt:{cmd:r(total)}}sum of all cells after{p_end}
{synopt:{cmd:r(N_changed)}}number of cells changed{p_end}
{synopt:{cmd:r(maxrelchange)}}largest relative change of a cell{p_end}
{synopt:{cmd:r(N_accounts)}}number of accounts{p_end}
{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(method)}}{cmd:ras} or {cmd:ce}{p_end}


{title:References}

{phang}
Junius, T. and J. Oosterhaven (2003). The solution of updating or regionalizing
a matrix with both positive and negative entries. {it:Economic Systems Research}
15(1): 87-96.

{phang}
Lenzen, M., R. Wood and B. Gallego (2007). Some comments on the GRAS method.
{it:Economic Systems Research} 19(4): 461-465.

{phang}
McDougall, R. A. (1999). Entropy theory and RAS are friends. GTAP Working Paper
6, Center for Global Trade Analysis, Purdue University.

{phang}
Robinson, S., A. Cattaneo and M. El-Said (2001). Updating and estimating a
social accounting matrix using cross entropy methods.
{it:Economic Systems Research} 13(1): 47-64.


{title:Also see}

{psee}
{helpb cge_sam}, {helpb cge_aggregate}, {helpb cge_samexport}, {helpb cge_map}
{p_end}
