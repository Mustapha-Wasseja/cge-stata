{smcl}
{* *! version 0.6.4  22oct2026}{...}
{title:Title}

{p2colset 5 23 25 2}{...}
{p2col:{bf:cge_multiplier} {hline 2}}SAM multipliers and their decomposition{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_multiplier} [{cmd:,} {opt endo:genous(accounts)} {opt exo:genous(accounts)}
{opt decomp:ose} {opt inj:ect(spec)} {opt acc:ounts(accounts)} {opt clear}]


{title:Description}

{pstd}
{cmd:cge_multiplier} computes the accounting multipliers of the SAM mapped by
{helpb cge_map} (from version 0.4.1; Reference Manual, {it:SAM tools}): the effect
of a unit injection into one account on the incomes of all the endogenous
accounts, the accounts whose spending the SAM explains, with prices fixed
(Pyatt and Round 1979). It needs no calibration.

{pstd}
The endogenous accounts are, by default, the activities, commodities and
margin accounts (the production block), the factors, and the households and
enterprises (the institutions block). The government, savings-investment, the
rest of the world, the tax accounts and the health insurance fund are
exogenous. With A the payments among endogenous accounts divided by the
paying account's column total, the multipliers are M = (I - A)^-1; column j
of M is the change in every endogenous account's income for a unit injection
into account j, including the injection itself.

{pstd}
For each injected account the command displays the total multiplier (the sum
over all endogenous accounts) and its parts: gross output (activities), value
added (factors) and household income (households).

{pstd}
With {opt decompose}, the multipliers are split into transfer, open-loop and
closed-loop effects, M = M3 M2 M1 (Pyatt and Round 1979), and displayed in the
additive form total = 1 + transfer + open loop + closed loop: effects within
the injected account's block, on the other blocks, and back to the injected
block through the circular flow production -> factors -> institutions ->
production. The decomposition requires the SAM to have no other flows among
the blocks; the command lists the flows that break the structure if it does.

{pstd}
Multipliers assume fixed prices, unused capacity and average propensities to
spend equal to marginal ones. They are upper bounds on what a CGE model with
supply constraints and price changes would find, and complement it.


{title:Options}

{phang}
{opt endogenous(accounts)} adds exogenous accounts, for example the
government, to the institutions block.

{phang}
{opt exogenous(accounts)} makes endogenous accounts exogenous, for example an
enterprise.

{phang}
{opt decompose} adds the decomposition. It requires the SAM to have no
flows among the blocks other than those of the circular flow, and is ignored
with {opt inject()}, whose effects are shown without it.

{phang}
{opt inject(spec)} gives injections into endogenous accounts,
{it:account}{cmd::}{it:value} pairs, for example {cmd:inject(com_hlt:100)} for
100 more spending on health services by an exogenous account such as the
government. The command then displays the change in each endogenous
account's income, its income in the SAM and the percentage change, and the
totals.

{phang}
{opt accounts(accounts)} chooses the injected accounts to display; by default
all endogenous accounts, or the commodities and households if there are more
than 40.

{phang}
{opt clear} replaces the data in memory with the multiplier matrix, one
observation per pair of endogenous accounts (variables {cmd:row},
{cmd:column}, {cmd:row_block}, {cmd:column_block}, {cmd:multiplier}, and with
{opt decompose} {cmd:transfer}, {cmd:open_loop} and {cmd:closed_loop}); with
{opt inject()}, the effects of the injection, one observation per endogenous
account ({cmd:account}, {cmd:block}, {cmd:base}, {cmd:change}, {cmd:pct}).
The model in memory is not changed.


{title:Examples}

{phang2}{cmd:. cge_synthetic, clear health}{p_end}
{phang2}{cmd:. cge_sam, labels(account)}{p_end}
{phang2}{cmd:. cge_map, activities(act_agr act_man act_ser act_hlt) commodities(com_agr com_man com_ser com_hlt) factors(lab cap) households(hhd) government(gov) savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) insurance(shi)}{p_end}
{phang2}{cmd:. cge_multiplier, decompose}{p_end}
{phang2}{cmd:. cge_multiplier, inject(com_hlt:100)}{p_end}
{phang2}{cmd:. cge_multiplier, endogenous(gov) clear}{p_end}


{title:Stored results}

{synoptset 22 tabbed}{...}
{p2col 5 22 26 2: Scalars}{p_end}
{synopt:{cmd:r(N_endogenous)}}number of endogenous accounts{p_end}
{synopt:{cmd:r(injection)}}total injection (with {opt inject()}){p_end}
{synopt:{cmd:r(output)}}change in gross output (with {opt inject()}){p_end}
{synopt:{cmd:r(value_added)}}change in value added (with {opt inject()}){p_end}
{synopt:{cmd:r(household_income)}}change in household income (with {opt inject()}){p_end}
{synopt:{cmd:r(total)}}change in all endogenous incomes (with {opt inject()}){p_end}
{p2col 5 22 26 2: Macros}{p_end}
{synopt:{cmd:r(endogenous)}}endogenous accounts{p_end}


{title:Reference}

{phang}
Pyatt, G. and J. I. Round. 1979. Accounting and fixed price multipliers in a
social accounting matrix framework. {it:Economic Journal} 89(356): 850-873.


{title:Also see}

{psee}
{helpb cge_spa}, {helpb cge_map}, {helpb cge_sam}, {helpb cge}
{p_end}
