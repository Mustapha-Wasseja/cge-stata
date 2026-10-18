* sam_preparation.do -- worked example: from an unbalanced SAM to a solved model
*
* Writes a mapping template, fills it in, aggregates the SAM to two sectors and
* one household group, balances it by cross entropy and by RAS, and maps,
* calibrates and solves the model. The unbalanced SAM is SYNTHETIC: it is the
* institutions layout with fixed perturbations, and describes no country. The
* elasticities are illustrative.

version 13.0
clear all
tempfile roles

* 1. Read the SAM and write a template of its accounts
cge_synthetic, clear unbalanced
cge_sam, labels(account)
cge_template using "`roles'.csv", replace

* 2. Fill in roles and groups (with a real SAM, do this in Excel)
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
replace group = "act_nag" if inlist(account, "act_man", "act_ser")
replace group = "com_nag" if inlist(account, "com_man", "com_ser")
replace group = "hh"      if inlist(account, "hhd", "npi")
export delimited using "`roles'.csv", replace
restore

* 3. Aggregate, then balance. Cross entropy estimates every total; here the
*    household total is taken as known
cge_aggregate using "`roles'.csv"
cge_balance, method(ce) totals(hh:290)

* 4. Map from the template, calibrate and solve
cge_map using "`roles'.csv"
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_shock tm, value(0)
cge_solve, name(notariff_ce)

* 5. The same with RAS, with targets the average of row and column totals
cge_synthetic, clear unbalanced
cge_sam, labels(account)
cge_aggregate using "`roles'.csv"
cge_balance
cge_map using "`roles'.csv"
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_shock tm, value(0)
cge_solve, name(notariff_ras)
cge_report, sims(notariff_ras) tables(macro welfare)

* 6. Save the balanced SAM
cge_samexport using "`roles'_balanced.csv", replace
capture erase "`roles'.csv"
capture erase "`roles'_balanced.csv"
