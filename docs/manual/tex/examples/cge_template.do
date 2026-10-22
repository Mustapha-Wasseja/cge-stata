* Examples of [CGE] cge_template. The SAMs are SYNTHETIC.
*>> tmpl_write
cge_synthetic, clear
cge_sam, labels(account)
cge_template using roles.csv, replace
type roles.csv
*<<

* Roles and groups, filled in here with Stata; in practice in a spreadsheet
*>> tmpl_fill
import delimited using roles.csv, clear stringcols(_all)
quietly replace role = "activities"  if inlist(account, "act_agr", "act_man", "act_ser")
quietly replace role = "commodities" if inlist(account, "com_agr", "com_man", "com_ser")
quietly replace role = "factors"     if inlist(account, "lab", "cap")
quietly replace role = "households"  if account == "hhd"
quietly replace role = "government"  if account == "gov"
quietly replace role = "savinv"      if account == "sav"
quietly replace role = "row"         if account == "row"
quietly replace role = "dirtax"      if account == "tax_dir"
quietly replace role = "saltax"      if account == "tax_sal"
quietly replace role = "imptax"      if account == "tax_imp"
quietly replace group = "act_nag"    if inlist(account, "act_man", "act_ser")
quietly replace group = "com_nag"    if inlist(account, "com_man", "com_ser")
export delimited account role pair group using roles.csv, replace
type roles.csv
*<<

*>> tmpl_use
cge_aggregate using roles.csv
cge_map using roles.csv
*<<

*>> tmpl_mapped
cge_synthetic, clear national
cge_sam, labels(account)
cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)       ///
    dirtax(gov) saltax(gov) imptax(tax_imp)
cge_template using roles_na.csv, replace
type roles_na.csv
*<<
