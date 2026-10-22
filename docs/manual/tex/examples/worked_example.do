* Chapter 4, A worked example: from a raw SAM to results.
* The SAM and the household survey are SYNTHETIC: they are constructed for
* testing and describe no country. The elasticities are published values for
* Togo, applied to the synthetic SAM only to show the commands.

*>> we_raw
cge_synthetic, clear unbalanced
cge_sam, labels(account)
*<<

*>> we_template
cge_template using roles.csv, replace
*<<
preserve
import delimited using roles.csv, varnames(1) stringcols(_all) clear
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
replace group = "hh" if inlist(account, "hhd", "npi")
export delimited using roles.csv, replace
*>> we_roles
list account role group row_total column_total difference, noobs clean
*<<
restore

*>> we_balance
cge_aggregate using roles.csv
cge_balance, method(ce) totals(hh:290)
*<<

*>> we_map
cge_map using roles.csv
*<<

*>> we_elas
quietly cge_elasticities sigmaq, country(TGO) values
local sq `r(values)'
quietly cge_elasticities sigmat, country(TGO) values
local st `r(values)'
quietly cge_elasticities sigmava, country(AFR) values
local va `r(values)'
quietly cge_elasticities incelas, country(TGO) values map(com_agr:food) others(other)
local ie `r(values)'
quietly cge_elasticities frisch, values
local fr `r(values)'
display "sigmava(`va')"
display "sigmaq(`sq') sigmat(`st')"
display "incelas(`ie') frisch(`fr')"
*<<

*>> we_calibrate
cge_calibrate, sigmava(`va') sigmaq(`sq') sigmat(`st') incelas(`ie') frisch(`fr')
cge_check, homogeneity perturb(0.1)
*<<

*>> we_parameters
cge_parameters, clear
list parameter element1 value if inlist(parameter, "tm", "tq", "tins0"), noobs clean
*<<

*>> we_sims
cge_shock tm, value(0)
cge_solve, name(notariff)
cge_closure, government(fixgsav direct)
cge_solve, name(notariff_direct)
cge_closure, government(flexgsav)
cge_shock, reset
cge_shock qg, elements(com_ser) scale(1.2)
cge_solve, name(gov_services)
cge_shock, reset
*<<

*>> we_report
cge_report, sims(notariff notariff_direct gov_services) tables(macro government welfare)
*<<

capture program drop tariff_cut
program define tariff_cut
    cge_shock tm, value(0)
end
*>> we_sens
cge_sensitivity, scenario(tariff_cut) draws(50) spread(0.5) seed(2026)
*<<

capture program drop tariff_from1
program define tariff_from1
    args t
    if `t' == 1 cge_shock tm, value(0)
end
*>> we_dynamic
cge_closure, factors(cap:specific)
local growth capital(cap) depreciation(0.05) rental(0.15) growth(lab:0.025) population(0.025) ///
    govgrowth(0.03) foreigngrowth(0.02)
cge_dynamic, name(base) periods(0/5) `growth' gdpgrowth(0.04)
cge_dynamic, name(lib) periods(0/5) `growth' baseline(base) shocks(tariff_from1)
*<<

*>> we_dynresults
cge_dynresults, run(lib) baseline(base) clear
list period element1 value baseline dev_pct if variable == "QA" & period == 5, noobs clean
cge_closure, factors(cap:mobile)
*<<

* A SYNTHETIC household survey
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

*>> we_microsim
set linesize 110
cge_microsim [pweight = weight], sim(notariff_direct) group(group) consumption(cons) size(hhsize) ///
    income(wage:lab profit:cap transfer:gov) budget(food:com_agr goods:com_man services:com_ser)   ///
    line(`line') generate(nt)
*<<
set linesize 100

*>> we_save
cge_save using worked.cgem, replace
cge_use using worked.cgem
*<<
