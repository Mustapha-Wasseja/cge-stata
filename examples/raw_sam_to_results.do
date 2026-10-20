* raw_sam_to_results.do -- worked example: the whole workflow, from a raw SAM
* to results (docs/manual, chapters 2 to 9)
*
* The SAM and the household survey are SYNTHETIC: they are constructed for
* testing and describe no country. The elasticities are published values for
* Togo, applied to the synthetic SAM only to show the commands; the policy
* results illustrate the workflow and are not findings about any country.

version 13.0
clear all
set more off
tempfile roles balanced report saved

* ---------------------------------------------------------------------
* 1. Read the raw SAM: it does not balance, and it has more household and
*    institution accounts than the model needs
* ---------------------------------------------------------------------
cge_synthetic, clear unbalanced
cge_sam, labels(account)

* ---------------------------------------------------------------------
* 2. Assign roles and groups in a template (with a real SAM, edit it in Excel)
* ---------------------------------------------------------------------
cge_template using "`roles'.csv", replace
preserve
import delimited using "`roles'.csv", varnames(1) stringcols(_all) clear
replace role = "activities"  if substr(account, 1, 4) == "act_"
replace role = "commodities" if substr(account, 1, 4) == "com_"
replace role = "factors"     if inlist(account, "lab", "cap")
replace role = "households"  if inlist(account, "hhd", "npi")
replace role = "enterprises" if account == "ent"
replace role = "government"  if account == "gov"
replace role = "savinv"      if account == "sav"
replace role = "row"         if account == "row"
replace role = "dirtax"      if account == "tax_dir"
replace role = "saltax"      if account == "tax_sal"
replace role = "imptax"      if account == "tax_imp"
* Households and non-profit institutions form one household group
replace group = "hh" if inlist(account, "hhd", "npi")
export delimited using "`roles'.csv", replace
restore

* ---------------------------------------------------------------------
* 3. Aggregate and balance (cross entropy; household income is known)
* ---------------------------------------------------------------------
cge_aggregate using "`roles'.csv"
cge_balance, method(ce) totals(hh:290)
cge_samexport using "`balanced'.csv", replace

* ---------------------------------------------------------------------
* 4. Map the accounts to model roles; the report lists any flow that the
*    model cannot represent
* ---------------------------------------------------------------------
cge_map using "`roles'.csv"

* ---------------------------------------------------------------------
* 5. Elasticities from the library, with their sources
* ---------------------------------------------------------------------
cge_elasticities, country(TGO)
cge_elasticities sigmaq, country(TGO) values
local sq `r(values)'
cge_elasticities sigmat, country(TGO) values
local st `r(values)'
cge_elasticities sigmava, country(AFR) values
local va `r(values)'
cge_elasticities incelas, country(TGO) values map(com_agr:food) others(other)
local ie `r(values)'
cge_elasticities frisch, values
local fr `r(values)'

* ---------------------------------------------------------------------
* 6. Calibrate and check
* ---------------------------------------------------------------------
cge_calibrate, sigmava(`va') sigmaq(`sq') sigmat(`st') incelas(`ie') frisch(`fr')
cge_parameters, clear
list parameter element1 value if inlist(parameter, "tm", "tq", "tins0"), noobs clean
cge_check, homogeneity perturb(0.1)

* ---------------------------------------------------------------------
* 7. Policy simulations
* ---------------------------------------------------------------------
* (a) Remove all import tariffs; government savings adjust (default closure)
cge_shock tm, value(0)
cge_solve, name(notariff)
* (b) The same, with direct tax rates replacing the lost revenue
cge_closure, government(fixgsav direct)
cge_solve, name(notariff_direct)
cge_closure, government(flexgsav)
cge_shock, reset
* (c) Twenty per cent more government purchases of services
cge_shock qg, elements(com_ser) scale(1.2)
cge_solve, name(gov_services)
cge_shock, reset

* ---------------------------------------------------------------------
* 8. Results: report tables on screen and in Excel
* ---------------------------------------------------------------------
cge_report, sims(notariff notariff_direct gov_services) tables(macro government welfare)
cge_report, sims(notariff notariff_direct gov_services) tables(all) saving("`report'.xlsx", replace) nodisplay

* ---------------------------------------------------------------------
* 9. Sensitivity of the tariff removal to the elasticities
* ---------------------------------------------------------------------
capture program drop tariff_cut
program define tariff_cut
    cge_shock tm, value(0)
end
cge_sensitivity, scenario(tariff_cut) draws(50) spread(0.5) seed(2026)

* ---------------------------------------------------------------------
* 10. A dynamic baseline with 4 per cent growth, and the tariff removal from
*     period 1 with the baseline's efficiency path
* ---------------------------------------------------------------------
capture program drop tariff_from1
program define tariff_from1
    args t
    if `t' == 1 cge_shock tm, value(0)
end
cge_closure, factors(cap:specific)
local growth capital(cap) depreciation(0.05) rental(0.15) growth(lab:0.025) population(0.025) ///
    govgrowth(0.03) foreigngrowth(0.02)
cge_dynamic, name(base) periods(0/5) `growth' gdpgrowth(0.04)
cge_dynamic, name(lib) periods(0/5) `growth' baseline(base) shocks(tariff_from1)
cge_report, run(lib) tables(macro)
cge_dynresults, run(lib) baseline(base) clear
list period variable element1 value baseline dev_pct if variable == "QA", noobs sepby(period)
cge_closure, factors(cap:mobile)

* ---------------------------------------------------------------------
* 11. Poverty and inequality in a SYNTHETIC household survey
* ---------------------------------------------------------------------
clear
set seed 2026
set obs 1000
generate str2 group = "hh"
generate double hhsize = 1 + floor(6 * runiform())
generate double weight = 100 + 50 * runiform()
generate double wage = exp(rnormal(5, 0.7)) * hhsize
generate double profit = cond(runiform() < 0.3, exp(rnormal(5, 1)), 0)
generate double transfer = cond(runiform() < 0.2, 50 * runiform(), 0)
generate double cons = 0.9 * (wage + profit + transfer)
generate double food = cons * (0.6 - 0.3 * runiform())
generate double services = (cons - food) / 2
generate double goods = cons - food - services
quietly summarize cons [aweight = weight], detail
local line = r(p25) / 3
cge_microsim [pweight = weight], sim(notariff_direct) group(group) consumption(cons) size(hhsize) ///
    income(wage:lab profit:cap transfer:gov) budget(food:com_agr goods:com_man services:com_ser)   ///
    line(`line') generate(nt)

* ---------------------------------------------------------------------
* 12. Save the model, with its simulations
* ---------------------------------------------------------------------
cge_save using "`saved'.cgem", replace
cge_use using "`saved'.cgem"
cge_report, sims(notariff) tables(macro)

capture erase "`roles'.csv"
capture erase "`balanced'.csv"
capture erase "`report'.xlsx"
capture erase "`saved'.cgem"
