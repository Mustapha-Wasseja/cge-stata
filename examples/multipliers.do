* multipliers.do -- worked example: SAM multipliers, their decomposition, the
* paths behind them, and the same injection in the CGE model
* (docs/sam_tools.md, Sections 6 and 7)
*
* The synthetic SAM is constructed for testing and describes no country; the
* elasticities are illustrative.

version 13.0
clear all

cge_synthetic, clear health
cge_sam, labels(account)
cge_map, activities(act_agr act_man act_ser act_hlt) commodities(com_agr com_man com_ser com_hlt) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)                          ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) insurance(shi)

* 1. Multipliers of every account, with the transfer, open-loop and closed-loop
*    effects
cge_multiplier, decompose

* 2. The effects of 10 more government spending on health services (about 3 per
*    cent of GDP), with prices fixed and every sector able to expand
cge_multiplier, inject(com_hlt:10)
local mult_output = r(output)
local mult_va = r(value_added)

* The paths by which health spending reaches household income
cge_spa, from(com_hlt) to(hhd)

* 3. The same spending in the CGE model: factors are fully employed, so health
*    services expand by drawing factors from other activities, prices adjust,
*    and, with government savings flexible and investment savings-driven, the
*    deficit crowds out investment
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_parameters, clear
quietly summarize value if parameter == "qg" & element1 == "com_hlt"
local qg = r(mean)
cge_shock qg, elements(com_hlt) scale(`=(`qg' + 10) / `qg'')
cge_solve, name(health10)
cge_report, sims(health10) tables(macro activities)
cge_results, sim(health10) clear nodisplay
quietly summarize value if variable == "QA"
local cge_output = r(sum)
quietly summarize base if variable == "QA"
local cge_output = `cge_output' - r(sum)
display as text "Change in gross output: " as result %8.2f `mult_output' as text " with SAM multipliers, " ///
    as result %8.2f `cge_output' as text " in the CGE model"
